CREATE OR REPLACE PACKAGE BODY xxiby_process_cust_paymt_pkg IS
  -----------------------------------------------------------------------------------------------------------------------------------------
  --  name:               XXIBY_PROCESS_CUST_PAYMT_PKG
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Customize iPayments process to capture Token data instead of Credit Card.
  ------------------------------------------------------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  ---   ----------    -------------   --------------------------------------------------------------------------------------------------
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Customize iPayments process to capture Token data instead of Credit Card.
  --  1.1   31/08/2016    Sujoy Das       CHG0039336 - Changes in Procedure 'send_email_notification' for Refund notification.
  --                                      New Functions added 'get_merchantid','get_binvalue','get_terminalid','get_industrytype'
  --                                      New Procedures added 'send_smtp_mail'
  --  1.2   15/09/2016    Sujoy Das       CHG0039376 - Changes in below procedures/function for split shipment scenarios.
  --                                      New Functions added 'get_line_remitted_flag', 'get_line_pson', 'get_so_header_id'
  --                                      New Procedures added 'get_so_tangibleid', 'update_orb_trn_mapping', 'new_auth_orbital',
  --                                                           'cancel_void_orbital', 'cancel_full_orbital_so', 'cancel_partial_orbital_so',
  --                                                           'split_void_new_orbital_auth', 'main'
  --  1.3   12/10/2016    Sujoy Das       CHG0039481 - Changes in below procedures/function for integration with eStore.
  --                                      Updated Procedure 'set_cc_token_assignment'
  --                                      New Functions added 'g_miss_token_rec'
  --                                      New Procedures added 'get_cctoken_list', 'update_estore_pson', 'create_new_creditcard'
  --  1.4   09/11/2016    Saar Nagar      INC0079952 - resize l_body to 32767 in send_email_notification().
  --  1.5   19/12/2016    Sujoy Das       CHG0040031 - used sql fuction last_day() to pick CC expiry_date in get_cc_detail().
  --  1.6   05.06.17      Lingaraj(TCS)   INC0094556 - Error when sending CC receipt
  --                                        Procedure send_smtp_mail and send_email_notification Modified
  --  1.7   04/12/2018    Diptasurjya     INC0118924 - Add extra conditions while selecting CC tokens to GET_CCTOKEN_LIST procedure
  --  1.8   20/09/2018   Dan Melamed     CHG0043983 - Close connections on exception
  --  1.9   27-Sep-2018  Lingaraj        CHG0043914-Previously used token list for eStore limited to uniqueness by card type,
  --                                       last 4 and expiration date
  --  1.3   18/09/2019    Roman W         CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.3.1 03/10/2019    Roman W.        CHG0046328 - coder review
  --  1.3.2 24/11/2019    Roman W.        CHG0046328 - added print_message when error_code =:2
  --  1.4   2019/12/10    Roman W.        CHG0046663 - Show connection error
  --                                          or credit card processor rejection reason - part 2
  --  1.5   05/02/2020    Roman W.        CHG0046663 - CHG0047311 - Change the email sending approach
  --                                           through PLSQL from on premises "smtp.stratasys.com"
  --                                           to cloud based "stratasysinc.mail.protection.outlook.com"

  -- 1.6    08/07/2020    yuval tal       CHG0048217 - modify get_cctoken_list
  -- 1.7    09/05/2021    Roman W.        CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  -- 1.8    23/05/2021    Roman W.        CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  -- 1.9    14/06/2021                                  in get_ccExp  cahnged SQL
  -- 2.0    03.08.2021    yuval tal       INC0238219 - modify get_l2_l3_json
  -- 2.1    10.08.2021    yuval tal       CHG0050514-  modify get_l2_l3_json
  ---------------------------------------------------------------------
  g_instrument_id NUMBER := 0;
  g_cc_card_type  VARCHAR2(30) := NULL;

  g_debug_module CONSTANT VARCHAR2(100) := 'iby.plsql.IBY_FNDCPT_SETUP_PUB';
  g_pkg_name     CONSTANT VARCHAR2(30) := 'IBY_FNDCPT_SETUP_PUB';
  g_debug        VARCHAR2(1) := 'Y';
  g_merchantid   VARCHAR2(50);
  g_bin          VARCHAR2(50);
  g_terminalid   VARCHAR2(50);
  g_industrytype VARCHAR2(50);

  -----------------------------------
  -- message
  -----------------------------------

  PROCEDURE message(p_msg VARCHAR2) IS
  
    l_msg VARCHAR2(30000);
  BEGIN
  
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' : ' || p_msg;
  
    IF fnd_global.conc_request_id != -1 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  
  END message;

  -----------------------------------------------------------------------
  --  name:               add_cc_token
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to add data into IBY_CREDITCARD table by calling API.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  ----  ------------  -------------   ------------------------------
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to add data into IBY_CREDITCARD table by calling API.
  ----------------------------------------------------------------------

  PROCEDURE add_cc_token(p_err_code    OUT NUMBER,
		 p_err_message OUT VARCHAR2,
		 --     p_instr_id           OUT NUMBER,
		 p_owner_id           NUMBER,
		 p_card_holder_name   VARCHAR2,
		 p_billing_address_id VARCHAR2,
		 p_card_number        VARCHAR2,
		 p_expiration_date    VARCHAR2,
		 p_instrument_type    VARCHAR2,
		 p_purchasecard_flag  VARCHAR2,
		 p_card_issuer        VARCHAR2,
		 p_single_use_flag    VARCHAR2,
		 p_info_only_flag     VARCHAR2,
		 p_card_purpose       VARCHAR2,
		 p_active_flag        VARCHAR2,
		 p_cc_last4digit      VARCHAR2,
		 p_billto_contact_id  VARCHAR2) IS
  
    l_return_status   VARCHAR2(1000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(4000);
    l_card_id         NUMBER;
    l_response        iby_fndcpt_common_pub.result_rec_type;
    l_card_instrument xxiby_process_cust_paymt_pkg.creditcard_rec_type;
    l_card_number     VARCHAR2(16);
  
    l_json_tbl apex_json.t_values;
  BEGIN
  
    SELECT lpad(p_card_number, 16, '0')
    INTO   l_card_number
    FROM   dual;
  
    p_err_code := 0;
  
    l_card_instrument.owner_id           := p_owner_id;
    l_card_instrument.card_holder_name   := p_card_holder_name;
    l_card_instrument.billing_address_id := p_billing_address_id;
    l_card_instrument.card_number        := l_card_number;
    l_card_instrument.expiration_date    := p_expiration_date;
    l_card_instrument.instrument_type    := p_instrument_type;
    l_card_instrument.purchasecard_flag  := p_purchasecard_flag;
    l_card_instrument.card_issuer        := p_card_issuer;
    l_card_instrument.single_use_flag    := p_single_use_flag;
    l_card_instrument.info_only_flag     := p_info_only_flag;
    l_card_instrument.card_purpose       := p_card_purpose;
    --l_card_instrument.Card_Description      := 'Card for BW Corporate Purchases';
    l_card_instrument.active_flag := p_active_flag;
    --l_card_instrument.attribute1  := p_cc_last4digit;
    --l_card_instrument.attribute2  := p_billto_contact_id;
    xxiby_process_cust_paymt_pkg.create_card(p_api_version     => 1.0,
			         p_init_msg_list   => fnd_api.g_true,
			         x_return_status   => l_return_status,
			         x_msg_count       => l_msg_count,
			         x_msg_data        => l_msg_data,
			         p_card_instrument => l_card_instrument,
			         x_card_id         => l_card_id,
			         x_response        => l_response);
    IF l_return_status = 'E' THEN
      p_err_code    := 1;
      p_err_message := l_response.result_message;
    END IF;
  
    g_instrument_id := l_card_id;
  
    --updating attribute1,attribute2,CARD_ISSUER_CODE in table IBY_CREDITCARD.
    UPDATE iby_creditcard
    SET    attribute1       = p_cc_last4digit,
           attribute2       = p_billto_contact_id,
           card_issuer_code = g_cc_card_type
    WHERE  instrid = g_instrument_id;
    COMMIT; -- this procedure called from 'ADDCCTOKEN' custom Form, so commiting the updated data.
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
      --dbms_output.put_line('SQl ERROR:' || SQLERRM);
  END add_cc_token;
  -----------------------------------------------------------------------
  --  name:               set_cc_token_assignment
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to add data into IBY_PMT_INSTR_USES_ALL table by calling API IBY_FNDCPT_SETUP_PUB.set_payer_instr_assignment.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to add data into IBY_PMT_INSTR_USES_ALL table by calling API IBY_FNDCPT_SETUP_PUB.set_payer_instr_assignment.
  --  1.1   12/10/2016    Sujoy Das       CHG0039481 - Parameter p_instrument_id is added.
  -----------------------------------------------------------------------
  PROCEDURE set_cc_token_assignment(p_err_code        OUT NUMBER,
			p_err_message     OUT VARCHAR2,
			p_party_id        NUMBER,
			p_cust_account_id NUMBER,
			p_account_site_id NUMBER,
			p_org_id          NUMBER,
			p_instrument_id   NUMBER DEFAULT NULL, --added for CHG0039481
			p_start_date      DATE,
			p_end_date        DATE) IS
  
    l_return_status      VARCHAR2(1000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(4000);
    l_assign_id          NUMBER;
    l_response           iby_fndcpt_common_pub.result_rec_type;
    l_payer              iby_fndcpt_common_pub.payercontext_rec_type;
    l_assignment_attribs iby_fndcpt_setup_pub.pmtinstrassignment_rec_type;
    l_cust_account_id    NUMBER;
  
  BEGIN
    p_err_code := 0;
  
    l_payer.payment_function := 'CUSTOMER_PAYMENT';
    l_payer.party_id         := p_party_id;
    l_payer.cust_account_id  := p_cust_account_id; -- cust_account_id for BILL_TO
  
    --------------------------------------------------------------
    l_payer.account_site_id := p_account_site_id; -- site_use_id for BILL_TO
    l_payer.org_type        := 'OPERATING_UNIT';
    l_payer.org_id          := p_org_id; -- org_id for 'Stratasys US OU'
    --------------------------------------------------------------
    l_assignment_attribs.instrument.instrument_type := 'CREDITCARD';
    IF p_instrument_id IS NOT NULL THEN
      -- added IF block for CHG0039481
      l_assignment_attribs.instrument.instrument_id := p_instrument_id;
    ELSE
      l_assignment_attribs.instrument.instrument_id := g_instrument_id; --Instrument_Id_returned_by_prior_API
    END IF;
    l_assignment_attribs.priority   := 1;
    l_assignment_attribs.start_date := p_start_date;
    l_assignment_attribs.end_date   := p_end_date;
    iby_fndcpt_setup_pub.set_payer_instr_assignment(p_api_version        => 1.0,
				    x_return_status      => l_return_status,
				    x_msg_count          => l_msg_count,
				    x_msg_data           => l_msg_data,
				    p_payer              => l_payer,
				    p_assignment_attribs => l_assignment_attribs,
				    x_assign_id          => l_assign_id,
				    x_response           => l_response);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'WORNING : ' || fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
    
  END set_cc_token_assignment;
  -----------------------------------------------------------------------
  --  name:               get_credit_card_type
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Function to get Credit Card TYPE from Credit Card number.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Function to get Credit Card TYPE from Credit Card number.
  -----------------------------------------------------------------------
  FUNCTION get_credit_card_type(p_cc_num VARCHAR2) RETURN VARCHAR2 IS
  
    l_cc_tpye VARCHAR2(100);
  BEGIN
  
    IF p_cc_num IS NULL THEN
      l_cc_tpye := NULL;
    ELSIF regexp_like(p_cc_num, '^5[1-5]\d{14}$') THEN
      --l_cc_tpye := 'MASTERCARD';
      l_cc_tpye := 'OTMASTERCARD';
    ELSIF regexp_like(p_cc_num,
	          '(^4\d{12}$)|(^4[0-8]\d{14}$)|(^(49)[^013]\d{13}$)|(^(49030)[0-1]\d{10}$)|(^(49033)[0-4]\d{10}$)|(^(49110)[^12]\d{10}$)|(^(49117)[0-3]\d{10}$)|(^(49118)[^0-2]\d{10}$)|(^(493)[^6]\d{12}$)') THEN
      --l_cc_tpye := 'VISA';
      l_cc_tpye := 'OTVISA';
    ELSIF regexp_like(p_cc_num,
	          '(^(352)[8-9](\d{11}$|\d{12}$))|(^(35)[3-8](\d{12}$|\d{13}$))') THEN
      --l_cc_tpye := 'JCB';
      l_cc_tpye := 'OTJCB';
    ELSIF regexp_like(p_cc_num, '(^(6011)\d{12}$)|(^(65)\d{14}$)') THEN
      --l_cc_tpye := 'DISCOVER';
      l_cc_tpye := 'OTDISCOVER';
    ELSIF regexp_like(p_cc_num,
	          '(^(30)[0-5]\d{11}$)|(^(36)\d{12}$)|(^(38[0-8])\d{11}$)') THEN
      --l_cc_tpye := 'DINERS';
      l_cc_tpye := 'OTDINERS';
      /*ELSIF regexp_like(p_cc_num,
                      '^(389)[0-9]{11}$') THEN
      l_cc_tpye := 'CARTE';*/
    ELSIF regexp_like(p_cc_num, '(^3[47])((\d{11}$)|(\d{13}$))') THEN
      --l_cc_tpye := 'AMEX';
      l_cc_tpye := 'OTAMEX';
      /*ELSIF regexp_like(p_cc_num,
                      '(^(2014)|^(2149))\d{11}$') THEN
      l_cc_tpye := 'ENROUTE';*/
    ELSE
      --l_cc_tpye := 'INVALID_CC_TYPE';
      l_cc_tpye := 'OTUNKNOWN';
    END IF;
  
    RETURN l_cc_tpye;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_credit_card_type;
  -----------------------------------------------------------------------
  --  name:               get_cc_detail
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to call servlet and fetch Credit Card data against Token.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to call servlet and fetch Credit Card data against Token.
  --  1.1   19/12/2016    Sujoy Das       CHG0040031 - used sql fuction last_day() to pick CC expiry_date.
  --  1.2   18/09/2019    Roman W         CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.3   19/09/2019    Roman W         CHG0046328 - l_msg  VARCHAR2(80) -> VARCHAR2(500)
  --  1.4   4.5.21        yuval tal       CHG0049588 - support oic : Credit Card Chase Payment - add data required for level 2 and 3
  -----------------------------------------------------------------------
  PROCEDURE get_cc_detail(p_err_code    OUT NUMBER,
		  p_err_message OUT VARCHAR2,
		  --use these once servlet part done
		  p_customerrefnum          NUMBER, --Use Token Value here
		  p_customername            OUT VARCHAR2, --from XML response
		  p_ccexp                   OUT DATE, --from XML response
		  p_ccaccountnum            OUT VARCHAR2, --from XML response
		  p_card_type               OUT VARCHAR2, --from XML response p_ccAccountNum value
		  p_cc_last4digit           OUT VARCHAR2, --from XML response p_ccAccountNum value
		  p_orderdefaultdescription OUT NUMBER) IS
    --from XML response
  
    l_debug_mode BOOLEAN := FALSE;
    l_req        utl_http.req;
    l_resp       utl_http.resp;
    --    l_msg        VARCHAR2(80);
    l_msg        VARCHAR2(500);
    l_entire_msg VARCHAR2(32767) := NULL;
    l_cc_detail  xxiby_cc_detail_row_type;
  
    --use these once servlet part done
    l_url VARCHAR2(256) := fnd_profile.value('APPS_FRAMEWORK_AGENT') ||
		   '/OA_HTML/CreditCardProcessingServlet/?token=' ||
		   p_customerrefnum;
  
    l_customername            VARCHAR2(100) := NULL;
    l_ccexp                   VARCHAR2(8);
    l_ccaccountnum            VARCHAR2(20);
    l_orderdefaultdescription NUMBER;
    l_ccaccountnum_mod        VARCHAR2(100) := NULL;
    l_charset                 VARCHAR2(2000);
    l_reason_phrase           VARCHAR2(2000);
  
    --CHG0049588
    l_enable_flag        VARCHAR2(1);
    l_wallet_loc         VARCHAR2(500);
    l_url2               VARCHAR2(500);
    l_wallet_pwd         VARCHAR2(500);
    l_auth_user          VARCHAR2(50);
    l_auth_pwd           VARCHAR2(50);
    l_resp2              CLOB;
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
    --CHG0049588
  BEGIN
    p_err_code := 0;
  
    --- Debug --
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.request_json := to_clob(p_customerrefnum);
      l_xxiby_cc_debug_tbl.step         := '1';
      l_xxiby_cc_debug_tbl.db_location  := 'xxiby_process_cust_paymt_pkg.get_cc_detail';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_message);
    END IF;
  
    -- CHG0049588
  
    xxssys_oic_util_pkg.get_service_details('CC_PROFILE_FETCH',
			        l_enable_flag,
			        l_url2,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        p_err_code,
			        p_err_message);
    IF l_enable_flag = 'Y' THEN
      cc_profile_fetch(p_customerrefnum => p_customerrefnum,
	           p_resp           => l_resp2,
	           p_err_code       => p_err_code,
	           p_err_msg        => p_err_message,
	           p_customername   => p_customername,
	           p_ccexp          => p_ccexp,
	           p_ccaccountnum   => p_ccaccountnum,
	           p_card_type      => p_card_type,
	           p_cc_last4digit  => p_cc_last4digit);
    
      RETURN;
    END IF;
  
    -- end CHG0049588
  
    --dbms_output.put_line('l_url:' || l_url);
    l_req  := utl_http.begin_request(url => l_url, method => 'GET');
    l_resp := utl_http.get_response(r => l_req);
  
    IF 200 != l_resp.status_code THEN
      IF 404 = l_resp.status_code THEN
        p_err_code    := 1;
        p_err_message := 'Orbital service is not responding (404)';
      
      ELSE
        p_err_code    := 1;
        p_err_message := l_resp.status_code || ' - ' ||
		 l_resp.reason_phrase;
      END IF;
    
      utl_http.end_response(r => l_resp);
    
    ELSE
      BEGIN
        LOOP
          utl_http.read_text(r => l_resp, data => l_msg, len => 500);
          l_entire_msg := substr(l_entire_msg || l_msg, 1, 32766);
        END LOOP;
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          NULL;
      END;
    
      utl_http.end_response(r => l_resp);
    
      -- CHG0046328
      get_xxiby_cc_detail_row(p_responce_clob => to_clob(l_entire_msg),
		      p_cc_detail     => l_cc_detail,
		      p_error_code    => p_err_code,
		      p_error_desc    => p_err_message);
    
      IF 0 != p_err_code THEN
        RETURN;
      END IF;
    
      IF '0' != l_cc_detail.errorcode THEN
        p_err_code    := 1;
        p_err_message := l_cc_detail.errordesc;
        RETURN;
      END IF;
    
      IF l_cc_detail.ccaccountnum IS NULL THEN
        p_err_code    := 1;
        p_err_message := 'Account number is empty for TOKEN ( ' ||
		 p_customerrefnum || ' )';
        RETURN;
      END IF;
    
      --use these once servlet part done
      p_customername := l_cc_detail.customername;
      p_ccaccountnum := l_cc_detail.ccaccountnum;
    
      --l_ccexp := '201712';
      SELECT last_day(to_date(l_cc_detail.ccexp, 'YYYYMM')) --Modified CHG0040031
      INTO   p_ccexp
      FROM   dual;
      --p_customername            := 'Daniel C'; --l_customerName;
      --p_ccexp := '31-DEC-2016'; --l_ccExp;
      --p_ccaccountnum            := '5454XXXXXXXX5454'; --l_ccAccountNum;
      --p_orderdefaultdescription := 166041; --l_orderDefaultDescription;
      --p_cc_last4digit     := '5554';
    
      SELECT REPLACE(p_ccaccountnum, 'X', '0')
      INTO   l_ccaccountnum_mod
      FROM   dual;
    
      SELECT xxiby_process_cust_paymt_pkg.get_credit_card_type(l_ccaccountnum_mod)
      INTO   p_card_type
      FROM   dual;
    
      g_cc_card_type := p_card_type;
    
      SELECT substr(to_char(p_ccaccountnum), -4, 4)
      INTO   p_cc_last4digit
      FROM   dual;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      --p_factor := NULL;
      p_err_code    := 1;
      p_err_message := 'WARNING :' || fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
    
  END get_cc_detail;
  -----------------------------------------------------------------------
  --  name:               create_card
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to create Credit Card. Taking copy from API IBY_FNDCPT_SETUP_PUB.Create_Card
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to create Credit Card. Taking copy from API IBY_FNDCPT_SETUP_PUB.Create_Card
  -----------------------------------------------------------------------
  PROCEDURE create_card(p_api_version     IN NUMBER,
		p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
		p_commit          IN VARCHAR2 := fnd_api.g_true,
		x_return_status   OUT NOCOPY VARCHAR2,
		x_msg_count       OUT NOCOPY NUMBER,
		x_msg_data        OUT NOCOPY VARCHAR2,
		p_card_instrument IN creditcard_rec_type,
		x_card_id         OUT NOCOPY NUMBER,
		x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type) IS
  
    l_api_version CONSTANT NUMBER := 1.0;
    l_module      CONSTANT VARCHAR2(30) := 'Create_Card';
    l_prev_msg_count NUMBER;
  
    lx_result_code VARCHAR2(30);
    lx_result      iby_fndcpt_common_pub.result_rec_type;
    lx_card_rec    creditcard_rec_type;
  
    l_info_only iby_creditcard.information_only_flag%TYPE := NULL;
    l_sec_mode  iby_sys_security_options.cc_encryption_mode%TYPE;
    l_cc_reg    iby_instrreg_pub.creditcardinstr_rec_type;
    l_instr_reg iby_instrreg_pub.pmtinstr_rec_type;
  
    l_billing_site hz_party_site_uses.party_site_use_id%TYPE;
  
    l_dbg_mod VARCHAR2(100) := g_debug_module || '.' || l_module;
  
    CURSOR c_sec_mode IS
      SELECT cc_encryption_mode
      FROM   iby_sys_security_options;
  
  BEGIN
    iby_debug_pub.add('Enter', iby_debug_pub.g_level_procedure, l_dbg_mod);
  
    IF NOT fnd_api.compatible_api_call(l_api_version,
			   p_api_version,
			   l_module,
			   g_pkg_name) THEN
      iby_debug_pub.add(debug_msg   => 'Incorrect API Version:=' ||
			   p_api_version,
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      fnd_message.set_name('IBY', 'IBY_204400_API_VER_MISMATCH');
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    IF (c_sec_mode%ISOPEN) THEN
      CLOSE c_sec_mode;
    END IF;
  
    IF fnd_api.to_boolean(p_init_msg_list) THEN
      fnd_msg_pub.initialize;
    END IF;
    l_prev_msg_count := fnd_msg_pub.count_msg;
  
    --SAVEPOINT Create_Card;
  
    card_exists(1.0,
	    fnd_api.g_false,
	    x_return_status,
	    x_msg_count,
	    x_msg_data,
	    p_card_instrument.owner_id,
	    p_card_instrument.card_number,
	    lx_card_rec,
	    lx_result,
	    nvl(p_card_instrument.instrument_type,
	        iby_fndcpt_common_pub.g_instr_type_creditcard));
  
    iby_debug_pub.add('fetched card id:=' || lx_card_rec.card_id,
	          iby_debug_pub.g_level_info,
	          l_dbg_mod);
  
    IF (lx_card_rec.card_id IS NULL) THEN
    
      iby_debug_pub.add('p_card_instrument.Register_Invalid_Card: ' ||
		p_card_instrument.register_invalid_card,
		iby_debug_pub.g_level_info,
		l_dbg_mod);
    
      -- validate billing address information
      IF (NOT validate_cc_billing(fnd_api.g_false, p_card_instrument)) THEN
        x_response.result_code := iby_creditcard_pkg.g_rc_invalid_address;
        iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			         x_return_status,
			         x_msg_count,
			         x_msg_data,
			         x_response);
        RETURN;
      END IF;
    
      -- lmallick (bug# 8721435)
      -- These validations have been moved from iby_creditcard_pkg because the TCA
      -- data might not have been committed to the db before invoking the Create_card API
      iby_debug_pub.add('Starting address validation ..',
		iby_debug_pub.g_level_info,
		l_dbg_mod);
    
      -- If Site use id is already provied then no need to call get_billing address
      iby_debug_pub.add('p_card_instrument.Address_Type = ' ||
		p_card_instrument.address_type,
		iby_debug_pub.g_level_info,
		l_dbg_mod);
      IF (p_card_instrument.address_type =
         iby_creditcard_pkg.g_party_site_use_id) AND
         (NOT (p_card_instrument.billing_address_id IS NULL)) THEN
        l_billing_site := p_card_instrument.billing_address_id;
      ELSE
        IF (p_card_instrument.billing_address_id = fnd_api.g_miss_num) THEN
          l_billing_site := fnd_api.g_miss_num;
        ELSIF (NOT (p_card_instrument.billing_address_id IS NULL)) THEN
          l_billing_site := iby_creditcard_pkg.get_billing_site(p_card_instrument.billing_address_id,
					    p_card_instrument.owner_id);
          IF (l_billing_site IS NULL) THEN
	x_response.result_code := iby_creditcard_pkg.g_rc_invalid_address;
	iby_debug_pub.add('Invalid Billing site.',
		      iby_debug_pub.g_level_info,
		      l_dbg_mod);
	iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
				 x_return_status,
				 x_msg_count,
				 x_msg_data,
				 x_response);
	RETURN;
          END IF;
        END IF;
      END IF;
    
      iby_debug_pub.add('l_billing_site = ' || l_billing_site,
		iby_debug_pub.g_level_info,
		l_dbg_mod);
    
      IF (NOT ((p_card_instrument.billing_address_territory IS NULL) OR
          (p_card_instrument.billing_address_territory =
          fnd_api.g_miss_char))) THEN
        IF (NOT
	iby_utility_pvt.validate_territory(p_card_instrument.billing_address_territory)) THEN
          x_response.result_code := iby_creditcard_pkg.g_rc_invalid_address;
          iby_debug_pub.add('Invalid Territory ' ||
		    p_card_instrument.billing_address_territory,
		    iby_debug_pub.g_level_info,
		    l_dbg_mod);
          iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			           x_return_status,
			           x_msg_count,
			           x_msg_data,
			           x_response);
          RETURN;
        END IF;
      END IF;
    
      IF (NOT p_card_instrument.owner_id IS NULL) THEN
        IF (NOT
	iby_utility_pvt.validate_party_id(p_card_instrument.owner_id)) THEN
          x_response.result_code := iby_creditcard_pkg.g_rc_invalid_party;
          iby_debug_pub.add('Invalid Owner party ' ||
		    p_card_instrument.owner_id,
		    iby_debug_pub.g_level_info,
		    l_dbg_mod);
          iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			           x_return_status,
			           x_msg_count,
			           x_msg_data,
			           x_response);
          RETURN;
        END IF;
      END IF;
      -- End of Bug fix for 8721435 --
    
      OPEN c_sec_mode;
      FETCH c_sec_mode
        INTO l_sec_mode;
      CLOSE c_sec_mode;
    
      IF (l_sec_mode = iby_security_pkg.g_encrypt_mode_instant) THEN
        -- comment out for CHG0031464
        --IF (l_sec_mode <> iby_security_pkg.g_encrypt_mode_instant) THEN
        -- added for CHG0031464
        iby_debug_pub.add('online registration',
		  iby_debug_pub.g_level_info,
		  l_dbg_mod);
      
        l_cc_reg.finame             := p_card_instrument.fi_name;
        l_cc_reg.cc_type            := p_card_instrument.card_issuer;
        l_cc_reg.cc_num             := p_card_instrument.card_number;
        l_cc_reg.cc_expdate         := p_card_instrument.expiration_date;
        l_cc_reg.instrument_type    := nvl(p_card_instrument.instrument_type,
			       iby_fndcpt_common_pub.g_instr_type_creditcard);
        l_cc_reg.owner_id           := p_card_instrument.owner_id;
        l_cc_reg.cc_holdername      := p_card_instrument.card_holder_name;
        l_cc_reg.cc_desc            := p_card_instrument.card_description;
        l_cc_reg.billing_address_id := l_billing_site;
        l_cc_reg.billing_postalcode := p_card_instrument.billing_postal_code;
        l_cc_reg.billing_country    := p_card_instrument.billing_address_territory;
        l_cc_reg.single_use_flag    := p_card_instrument.single_use_flag;
        l_cc_reg.info_only_flag     := p_card_instrument.info_only_flag;
        l_cc_reg.card_purpose       := p_card_instrument.card_purpose;
        l_cc_reg.cc_desc            := p_card_instrument.card_description;
        l_cc_reg.active_flag        := p_card_instrument.active_flag;
        l_cc_reg.inactive_date      := p_card_instrument.inactive_date;
      
        -- lmallick
        -- New parameter introduced to allow registration of invalid credit cards
        -- This is currently used by the OIE product and its only this product that
        -- passes the value as 'Y'
        l_cc_reg.register_invalid_card := p_card_instrument.register_invalid_card;
      
        l_instr_reg.creditcardinstr := l_cc_reg;
        l_instr_reg.instrumenttype  := iby_instrreg_pub.c_instrtype_creditcard;
      
        iby_debug_pub.add('before calling OraInstrAdd',
		  iby_debug_pub.g_level_info,
		  l_dbg_mod);
      
        iby_instrreg_pub.orainstradd(1.0,
			 fnd_api.g_false,
			 fnd_api.g_false,
			 fnd_api.g_valid_level_full,
			 l_instr_reg,
			 x_return_status,
			 x_msg_count,
			 x_msg_data,
			 x_card_id,
			 lx_result);
      
        -- should not be a validation error at this point
        IF ((nvl(x_card_id, -1) < 0))
        --OR (x_return_status <> FND_API.G_RET_STS_ERROR))
         THEN
          iby_debug_pub.add('instrument reg failed',
		    iby_debug_pub.g_level_info,
		    l_dbg_mod);
          iby_debug_pub.add('result code:=' || lx_result.result_code,
		    iby_debug_pub.g_level_info,
		    l_dbg_mod);
          IF (lx_result.result_code IS NULL) THEN
	x_response.result_code := 'COMMUNICATION_ERROR';
	--IBY_FNDCPT_COMMON_PUB.G_RC_GENERIC_SYS_ERROR;
	iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
				 x_return_status,
				 x_msg_count,
				 x_msg_data,
				 x_response);
          ELSE
	x_response.result_code := lx_result.result_code;
          
	iby_fndcpt_common_pub.prepare_result(iby_instrreg_pub.g_interface_code,
				 lx_result.result_message,
				 l_prev_msg_count,
				 x_return_status,
				 x_msg_count,
				 x_msg_data,
				 x_response);
          END IF;
          RETURN;
        END IF;
      ELSE
        iby_debug_pub.add('database registration',
		  iby_debug_pub.g_level_info,
		  l_dbg_mod);
      
        iby_creditcard_pkg.create_card(fnd_api.g_false,
			   p_card_instrument.owner_id,
			   p_card_instrument.card_holder_name,
			   l_billing_site,
			   p_card_instrument.address_type,
			   p_card_instrument.billing_postal_code,
			   p_card_instrument.billing_address_territory,
			   p_card_instrument.card_number,
			   p_card_instrument.expiration_date,
			   nvl(p_card_instrument.instrument_type,
			       iby_fndcpt_common_pub.g_instr_type_creditcard),
			   p_card_instrument.purchasecard_flag,
			   p_card_instrument.purchasecard_subtype,
			   p_card_instrument.card_issuer,
			   p_card_instrument.fi_name,
			   p_card_instrument.single_use_flag,
			   p_card_instrument.info_only_flag,
			   p_card_instrument.card_purpose,
			   p_card_instrument.card_description,
			   p_card_instrument.active_flag,
			   p_card_instrument.inactive_date,
			   NULL,
			   p_card_instrument.attribute_category,
			   p_card_instrument.attribute1,
			   p_card_instrument.attribute2,
			   p_card_instrument.attribute3,
			   p_card_instrument.attribute4,
			   p_card_instrument.attribute5,
			   p_card_instrument.attribute6,
			   p_card_instrument.attribute7,
			   p_card_instrument.attribute8,
			   p_card_instrument.attribute9,
			   p_card_instrument.attribute10,
			   p_card_instrument.attribute11,
			   p_card_instrument.attribute12,
			   p_card_instrument.attribute13,
			   p_card_instrument.attribute14,
			   p_card_instrument.attribute15,
			   p_card_instrument.attribute16,
			   p_card_instrument.attribute17,
			   p_card_instrument.attribute18,
			   p_card_instrument.attribute19,
			   p_card_instrument.attribute20,
			   p_card_instrument.attribute21,
			   p_card_instrument.attribute22,
			   p_card_instrument.attribute23,
			   p_card_instrument.attribute24,
			   p_card_instrument.attribute25,
			   p_card_instrument.attribute26,
			   p_card_instrument.attribute27,
			   p_card_instrument.attribute28,
			   p_card_instrument.attribute29,
			   p_card_instrument.attribute30,
			   lx_result_code,
			   x_card_id,
			   p_card_instrument.register_invalid_card,
			   fnd_global.user_id,
			   fnd_global.login_id);
      END IF;
    
    ELSE
    
      -- card cannot become info only once this flag is turned off
      IF (NOT p_card_instrument.info_only_flag = 'Y') THEN
        l_info_only := p_card_instrument.info_only_flag;
      END IF;
    
      -- validate billing address information
      IF (NOT validate_cc_billing(fnd_api.g_true, p_card_instrument)) THEN
        x_response.result_code := iby_creditcard_pkg.g_rc_invalid_address;
        iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			         x_return_status,
			         x_msg_count,
			         x_msg_data,
			         x_response);
        RETURN;
      END IF;
      -- validate expiration date
      IF (trunc(p_card_instrument.expiration_date, 'DD') <
         trunc(SYSDATE, 'DD')) THEN
        x_response.result_code := iby_creditcard_pkg.g_rc_invalid_ccexpiry;
        iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			         x_return_status,
			         x_msg_count,
			         x_msg_data,
			         x_response);
        RETURN;
      END IF;
    
      iby_creditcard_pkg.update_card(fnd_api.g_false,
			 lx_card_rec.card_id,
			 p_card_instrument.owner_id,
			 p_card_instrument.card_holder_name,
			 p_card_instrument.billing_address_id,
			 p_card_instrument.address_type,
			 p_card_instrument.billing_postal_code,
			 p_card_instrument.billing_address_territory,
			 p_card_instrument.expiration_date,
			 p_card_instrument.instrument_type,
			 p_card_instrument.purchasecard_flag,
			 p_card_instrument.purchasecard_subtype,
			 p_card_instrument.fi_name,
			 p_card_instrument.single_use_flag,
			 l_info_only,
			 p_card_instrument.card_purpose,
			 p_card_instrument.card_description,
			 p_card_instrument.active_flag,
			 nvl(p_card_instrument.inactive_date,
			     fnd_api.g_miss_date),
			 p_card_instrument.attribute_category,
			 p_card_instrument.attribute1,
			 p_card_instrument.attribute2,
			 p_card_instrument.attribute3,
			 p_card_instrument.attribute4,
			 p_card_instrument.attribute5,
			 p_card_instrument.attribute6,
			 p_card_instrument.attribute7,
			 p_card_instrument.attribute8,
			 p_card_instrument.attribute9,
			 p_card_instrument.attribute10,
			 p_card_instrument.attribute11,
			 p_card_instrument.attribute12,
			 p_card_instrument.attribute13,
			 p_card_instrument.attribute14,
			 p_card_instrument.attribute15,
			 p_card_instrument.attribute16,
			 p_card_instrument.attribute17,
			 p_card_instrument.attribute18,
			 p_card_instrument.attribute19,
			 p_card_instrument.attribute20,
			 p_card_instrument.attribute21,
			 p_card_instrument.attribute22,
			 p_card_instrument.attribute23,
			 p_card_instrument.attribute24,
			 p_card_instrument.attribute25,
			 p_card_instrument.attribute26,
			 p_card_instrument.attribute27,
			 p_card_instrument.attribute28,
			 p_card_instrument.attribute29,
			 p_card_instrument.attribute30,
			 lx_result_code,
			 NULL,
			 NULL);
      x_card_id := lx_card_rec.card_id;
    END IF;
  
    x_response.result_code := nvl(lx_result_code,
		          iby_fndcpt_common_pub.g_rc_success);
    iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			     x_return_status,
			     x_msg_count,
			     x_msg_data,
			     x_response);
  
    IF fnd_api.to_boolean(p_commit) THEN
      COMMIT;
    END IF;
  
  EXCEPTION
  
    WHEN fnd_api.g_exc_error THEN
      ROLLBACK TO create_card;
      iby_debug_pub.add(debug_msg   => 'In G_EXC_ERROR Exception',
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN fnd_api.g_exc_unexpected_error THEN
      --ROLLBACK TO Create_Card;
      iby_debug_pub.add(debug_msg   => 'In G_EXC_UNEXPECTED_ERROR Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN OTHERS THEN
      --ROLLBACK TO Create_Card;
      iby_debug_pub.add(debug_msg   => 'In OTHERS Exception' || SQLERRM,
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
    
      iby_fndcpt_common_pub.clear_msg_stack(l_prev_msg_count);
    
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name,
		        l_module,
		        substr(SQLERRM, 1, 100));
      END IF;
    
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    
      iby_debug_pub.add(debug_msg   => 'x_return_status=' ||
			   x_return_status,
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      iby_debug_pub.add(debug_msg   => 'Exit Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
    
  END create_card;
  -----------------------------------------------------------------------
  --  name:               card_exists
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to check Credit Card exist or not. Taking copy from API IBY_FNDCPT_SETUP_PUB.card_exists
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to check Credit Card exist or not. Taking copy from API IBY_FNDCPT_SETUP_PUB.card_exists
  -----------------------------------------------------------------------
  PROCEDURE card_exists(p_api_version     IN NUMBER,
		p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
		x_return_status   OUT NOCOPY VARCHAR2,
		x_msg_count       OUT NOCOPY NUMBER,
		x_msg_data        OUT NOCOPY VARCHAR2,
		p_owner_id        NUMBER,
		p_card_number     VARCHAR2,
		x_card_instrument OUT NOCOPY creditcard_rec_type,
		x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type,
		p_card_instr_type VARCHAR2 DEFAULT NULL) IS
    l_api_version CONSTANT NUMBER := 1.0;
    l_module      CONSTANT VARCHAR2(30) := 'Card_Exists';
    l_prev_msg_count NUMBER;
  
    l_card_id        iby_creditcard.instrid%TYPE;
    l_cc_hash1       iby_creditcard.cc_number_hash1%TYPE;
    l_cc_hash2       iby_creditcard.cc_number_hash2%TYPE;
    l_char_allowed   VARCHAR2(1) := 'N';
    lx_return_status VARCHAR2(1);
    lx_msg_count     NUMBER;
    lx_msg_data      VARCHAR2(200);
    lx_cc_number     iby_creditcard.ccnumber%TYPE;
    lx_result        iby_fndcpt_common_pub.result_rec_type;
  
    CURSOR c_card(ci_cc_hash1   IN iby_creditcard.cc_number_hash1%TYPE,
	      ci_cc_hash2   IN iby_creditcard.cc_number_hash2%TYPE,
	      ci_card_owner IN iby_creditcard.card_owner_id%TYPE) IS
      SELECT instrid
      FROM   iby_creditcard
      WHERE  (cc_number_hash1 = ci_cc_hash1)
      AND    (cc_number_hash2 = ci_cc_hash2)
      AND    ((card_owner_id = nvl(ci_card_owner, card_owner_id)) OR
	(card_owner_id IS NULL AND ci_card_owner IS NULL)); --Removed singleUseFlag validation to avoid duplicate singleusecard creation.
  
  BEGIN
  
    IF (c_card%ISOPEN) THEN
      CLOSE c_card;
    END IF;
  
    IF NOT fnd_api.compatible_api_call(l_api_version,
			   p_api_version,
			   l_module,
			   g_pkg_name) THEN
      iby_debug_pub.add(debug_msg   => 'Incorrect API Version:=' ||
			   p_api_version,
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      fnd_message.set_name('IBY', 'IBY_204400_API_VER_MISMATCH');
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    IF fnd_api.to_boolean(p_init_msg_list) THEN
      fnd_msg_pub.initialize;
    END IF;
    l_prev_msg_count := fnd_msg_pub.count_msg;
    IF (nvl(p_card_instr_type,
	iby_fndcpt_common_pub.g_instr_type_creditcard) =
       iby_fndcpt_common_pub.g_instr_type_paymentcard) THEN
      l_char_allowed := 'Y';
    END IF;
  
    iby_cc_validate.stripcc(1.0,
		    fnd_api.g_false,
		    p_card_number,
		    lx_return_status,
		    lx_msg_count,
		    lx_msg_data,
		    lx_cc_number);
  
    IF (lx_cc_number IS NULL) THEN
      x_response.result_code := iby_creditcard_pkg.g_rc_invalid_ccnumber;
      iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			       x_return_status,
			       x_msg_count,
			       x_msg_data,
			       x_response);
      RETURN;
    END IF;
  
    l_cc_hash1 := iby_security_pkg.get_hash(lx_cc_number, 'F');
    l_cc_hash2 := iby_security_pkg.get_hash(lx_cc_number, 'T');
  
    OPEN c_card(l_cc_hash1, l_cc_hash2, p_owner_id);
    FETCH c_card
      INTO l_card_id;
    CLOSE c_card;
  
    IF (l_card_id IS NULL) THEN
      x_response.result_code := g_rc_unknown_card;
    ELSE
      get_card(1.0,
	   fnd_api.g_false,
	   x_return_status,
	   x_msg_count,
	   x_msg_data,
	   l_card_id,
	   x_card_instrument,
	   lx_result);
      x_response.result_code := iby_fndcpt_common_pub.g_rc_success;
    END IF;
    iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			     x_return_status,
			     x_msg_count,
			     x_msg_data,
			     x_response);
  
  EXCEPTION
  
    WHEN fnd_api.g_exc_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_ERROR Exception',
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN fnd_api.g_exc_unexpected_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_UNEXPECTED_ERROR Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN OTHERS THEN
    
      iby_debug_pub.add(debug_msg   => 'In OTHERS Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
    
      iby_fndcpt_common_pub.clear_msg_stack(l_prev_msg_count);
    
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name,
		        l_module,
		        substr(SQLERRM, 1, 100));
      END IF;
    
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    
      iby_debug_pub.add(debug_msg   => 'x_return_status=' ||
			   x_return_status,
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      iby_debug_pub.add(debug_msg   => 'Exit Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
  END card_exists;
  -----------------------------------------------------------------------
  --  name:               validate_cc_billing
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Function to Validates the billing address passed for a credit card instrument. Taking copy from API IBY_FNDCPT_SETUP_PUB.validate_cc_billing
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Function to Validates the billing address passed for a credit card instrument. Taking copy from API IBY_FNDCPT_SETUP_PUB.validate_cc_billing
  -----------------------------------------------------------------------
  FUNCTION validate_cc_billing(p_is_update  IN VARCHAR2,
		       p_creditcard IN creditcard_rec_type)
    RETURN BOOLEAN IS
  
    lx_return_status   VARCHAR2(1);
    lx_msg_count       NUMBER;
    lx_msg_data        VARCHAR2(3000);
    lx_result          iby_fndcpt_common_pub.result_rec_type;
    lx_channel_attribs pmtchannel_attribuses_rec_type;
  
    l_addressid    iby_creditcard.addressid%TYPE;
    l_billing_zip  iby_creditcard.billing_addr_postal_code%TYPE;
    l_billing_terr iby_creditcard.bill_addr_territory_code%TYPE;
  
  BEGIN
  
    IF (p_creditcard.info_only_flag = 'Y') THEN
      RETURN TRUE;
    END IF;
  
    l_addressid    := p_creditcard.billing_address_id;
    l_billing_zip  := p_creditcard.billing_postal_code;
    l_billing_terr := p_creditcard.billing_address_territory;
  
    IF fnd_api.to_boolean(p_is_update) THEN
      IF (l_addressid = fnd_api.g_miss_num) THEN
        l_addressid := NULL;
      ELSIF (l_addressid IS NULL) THEN
        l_addressid := fnd_api.g_miss_num;
      END IF;
      IF (l_billing_zip = fnd_api.g_miss_char) THEN
        l_billing_zip := NULL;
      ELSIF (l_billing_zip IS NULL) THEN
        l_billing_zip := fnd_api.g_miss_char;
      END IF;
      IF (l_billing_terr = fnd_api.g_miss_char) THEN
        l_billing_terr := NULL;
      ELSIF (l_billing_terr IS NULL) THEN
        l_billing_terr := fnd_api.g_miss_char;
      END IF;
    END IF;
  
    IF ((NOT (l_addressid IS NULL OR l_addressid = fnd_api.g_miss_num)) AND
       (NOT (l_billing_zip IS NULL OR l_billing_zip = fnd_api.g_miss_char))) THEN
      RETURN FALSE;
    END IF;
  
    IF ((NOT (l_billing_zip IS NULL OR l_billing_zip = fnd_api.g_miss_char)) AND
       (l_billing_terr IS NULL OR l_billing_terr = fnd_api.g_miss_char)) THEN
      RETURN FALSE;
    ELSIF ((NOT
           (l_billing_terr IS NULL OR l_billing_terr = fnd_api.g_miss_char))
          
          AND
          (l_billing_zip IS NULL OR l_billing_zip = fnd_api.g_miss_char)) THEN
      RETURN FALSE;
    END IF;
  
    get_payment_channel_attribs(1.0,
		        fnd_api.g_false,
		        lx_return_status,
		        lx_msg_count,
		        lx_msg_data,
		        g_channel_credit_card,
		        lx_channel_attribs,
		        lx_result);
  
    IF ((lx_channel_attribs.instr_billing_address =
       g_chnnl_attrib_use_required) AND
       ((l_addressid IS NULL) AND (l_billing_zip IS NULL))) THEN
      RETURN FALSE;
    END IF;
  
    IF ((lx_channel_attribs.instr_billing_address =
       g_chnnl_attrib_use_disabled) AND
       ((NOT l_addressid IS NULL) OR (NOT l_billing_zip IS NULL))) THEN
      RETURN FALSE;
    END IF;
  
    RETURN TRUE;
  END validate_cc_billing;
  -----------------------------------------------------------------------
  --  name:               get_card
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get credit card detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_card
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get credit card detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_card
  -----------------------------------------------------------------------
  PROCEDURE get_card(p_api_version     IN NUMBER,
	         p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
	         x_return_status   OUT NOCOPY VARCHAR2,
	         x_msg_count       OUT NOCOPY NUMBER,
	         x_msg_data        OUT NOCOPY VARCHAR2,
	         p_card_id         NUMBER,
	         x_card_instrument OUT NOCOPY creditcard_rec_type,
	         x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type) IS
    l_api_version CONSTANT NUMBER := 1.0;
    l_module      CONSTANT VARCHAR2(30) := 'Get_Card';
    l_prev_msg_count NUMBER;
  
    l_card_count NUMBER;
  
    CURSOR c_card(ci_card_id IN iby_creditcard.instrid%TYPE) IS
      SELECT card_owner_id,
	 chname,
	 addressid,
	 masked_cc_number,
	 expirydate,
	 decode(expirydate,
	        NULL,
	        expired_flag,
	        decode(sign(expirydate - SYSDATE), -1, 'Y', 'N')),
	 instrument_type,
	 purchasecard_subtype,
	 card_issuer_code,
	 finame,
	 single_use_flag,
	 information_only_flag,
	 card_purpose,
	 description,
	 inactive_date
      FROM   iby_creditcard
      WHERE  (instrid = ci_card_id);
  BEGIN
    IF (c_card%ISOPEN) THEN
      CLOSE c_card;
    END IF;
  
    IF NOT fnd_api.compatible_api_call(l_api_version,
			   p_api_version,
			   l_module,
			   g_pkg_name) THEN
      iby_debug_pub.add(debug_msg   => 'Incorrect API Version:=' ||
			   p_api_version,
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      fnd_message.set_name('IBY', 'IBY_204400_API_VER_MISMATCH');
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    IF fnd_api.to_boolean(p_init_msg_list) THEN
      fnd_msg_pub.initialize;
    END IF;
    l_prev_msg_count := fnd_msg_pub.count_msg;
  
    OPEN c_card(p_card_id);
    FETCH c_card
      INTO x_card_instrument.owner_id,
           x_card_instrument.card_holder_name,
           x_card_instrument.billing_address_id,
           x_card_instrument.card_number,
           x_card_instrument.expiration_date,
           x_card_instrument.expired_flag,
           x_card_instrument.instrument_type,
           x_card_instrument.purchasecard_subtype,
           x_card_instrument.card_issuer,
           x_card_instrument.fi_name,
           x_card_instrument.single_use_flag,
           x_card_instrument.info_only_flag,
           x_card_instrument.card_purpose,
           x_card_instrument.card_description,
           x_card_instrument.inactive_date;
  
    IF (c_card%NOTFOUND) THEN
      x_response.result_code := g_rc_invalid_instrument;
    ELSE
      x_response.result_code    := iby_fndcpt_common_pub.g_rc_success;
      x_card_instrument.card_id := p_card_id;
    END IF;
  
    iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			     x_return_status,
			     x_msg_count,
			     x_msg_data,
			     x_response);
  
  EXCEPTION
  
    WHEN fnd_api.g_exc_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_ERROR Exception',
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN fnd_api.g_exc_unexpected_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_UNEXPECTED_ERROR Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN OTHERS THEN
    
      iby_debug_pub.add(debug_msg   => 'In OTHERS Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
    
      iby_fndcpt_common_pub.clear_msg_stack(l_prev_msg_count);
    
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name,
		        l_module,
		        substr(SQLERRM, 1, 100));
      END IF;
    
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    
      iby_debug_pub.add(debug_msg   => 'x_return_status=' ||
			   x_return_status,
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      iby_debug_pub.add(debug_msg   => 'Exit Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
  END get_card;
  -----------------------------------------------------------------------
  --  name:               get_payment_channel_attribs
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get payment channel detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_payment_channel_attribs
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get payment channel detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_payment_channel_attribs
  -----------------------------------------------------------------------
  PROCEDURE get_payment_channel_attribs(p_api_version         IN NUMBER,
			    p_init_msg_list       IN VARCHAR2 := fnd_api.g_false,
			    x_return_status       OUT NOCOPY VARCHAR2,
			    x_msg_count           OUT NOCOPY NUMBER,
			    x_msg_data            OUT NOCOPY VARCHAR2,
			    p_channel_code        IN VARCHAR2,
			    x_channel_attrib_uses OUT NOCOPY pmtchannel_attribuses_rec_type,
			    x_response            OUT NOCOPY iby_fndcpt_common_pub.result_rec_type) IS
    l_api_version CONSTANT NUMBER := 1.0;
    l_module      CONSTANT VARCHAR2(30) := 'Get_Payment_Channel_Attribs';
    l_prev_msg_count NUMBER;
  
    CURSOR c_appl_attribs(ci_pmt_channel iby_fndcpt_pmt_chnnls_b.payment_channel_code%TYPE) IS
      SELECT nvl(isec.attribute_applicability, g_chnnl_attrib_use_optional),
	 nvl(ibill.attribute_applicability, g_chnnl_attrib_use_optional),
	 nvl(vaflag.attribute_applicability,
	     g_chnnl_attrib_use_optional),
	 nvl(vacode.attribute_applicability,
	     g_chnnl_attrib_use_optional),
	 nvl(vadate.attribute_applicability,
	     g_chnnl_attrib_use_optional),
	 nvl(ponum.attribute_applicability, g_chnnl_attrib_use_optional),
	 nvl(poline.attribute_applicability,
	     g_chnnl_attrib_use_optional),
	 nvl(addinfo.attribute_applicability,
	     g_chnnl_attrib_use_optional)
      FROM   iby_fndcpt_pmt_chnnls_b  pc,
	 iby_pmt_mthd_attrib_appl isec,
	 iby_pmt_mthd_attrib_appl ibill,
	 iby_pmt_mthd_attrib_appl vaflag,
	 iby_pmt_mthd_attrib_appl vacode,
	 iby_pmt_mthd_attrib_appl vadate,
	 iby_pmt_mthd_attrib_appl ponum,
	 iby_pmt_mthd_attrib_appl poline,
	 iby_pmt_mthd_attrib_appl addinfo
      WHERE  (pc.payment_channel_code = ci_pmt_channel)
	-- instrument security
      AND    (pc.payment_channel_code = isec.payment_method_code(+))
      AND    (isec.payment_flow(+) = 'FUNDS_CAPTURE')
      AND    (isec.attribute_code(+) = 'INSTR_SECURITY_CODE')
	-- instrument billing address
      AND    (pc.payment_channel_code = ibill.payment_method_code(+))
      AND    (ibill.attribute_code(+) = 'INSTR_BILLING_ADDRESS')
      AND    (ibill.payment_flow(+) = 'FUNDS_CAPTURE')
	-- voice auth flag
      AND    (pc.payment_channel_code = vaflag.payment_method_code(+))
      AND    (vaflag.attribute_code(+) = 'VOICE_AUTH_FLAG')
      AND    (vaflag.payment_flow(+) = 'FUNDS_CAPTURE')
	-- voice auth code
      AND    (pc.payment_channel_code = vacode.payment_method_code(+))
      AND    (vacode.attribute_code(+) = 'VOICE_AUTH_CODE')
      AND    (vacode.payment_flow(+) = 'FUNDS_CAPTURE')
	-- voice auth date
      AND    (pc.payment_channel_code = vadate.payment_method_code(+))
      AND    (vadate.attribute_code(+) = 'VOICE_AUTH_DATE')
      AND    (vadate.payment_flow(+) = 'FUNDS_CAPTURE')
	-- purcharse order number
      AND    (pc.payment_channel_code = ponum.payment_method_code(+))
      AND    (ponum.attribute_code(+) = 'PO_NUMBER')
      AND    (ponum.payment_flow(+) = 'FUNDS_CAPTURE')
	-- purchase order line
      AND    (pc.payment_channel_code = poline.payment_method_code(+))
      AND    (poline.attribute_code(+) = 'PO_LINE_NUMBER')
      AND    (poline.payment_flow(+) = 'FUNDS_CAPTURE')
	-- additional info
      AND    (pc.payment_channel_code = addinfo.payment_method_code(+))
      AND    (addinfo.attribute_code(+) = 'ADDITIONAL_INFO')
      AND    (addinfo.payment_flow(+) = 'FUNDS_CAPTURE');
  
  BEGIN
  
    IF (c_appl_attribs%ISOPEN) THEN
      CLOSE c_appl_attribs;
    END IF;
  
    IF NOT fnd_api.compatible_api_call(l_api_version,
			   p_api_version,
			   l_module,
			   g_pkg_name) THEN
      iby_debug_pub.add(debug_msg   => 'Incorrect API Version:=' ||
			   p_api_version,
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      fnd_message.set_name('IBY', 'IBY_204400_API_VER_MISMATCH');
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    IF fnd_api.to_boolean(p_init_msg_list) THEN
      fnd_msg_pub.initialize;
    END IF;
    l_prev_msg_count := fnd_msg_pub.count_msg;
  
    OPEN c_appl_attribs(p_channel_code);
    FETCH c_appl_attribs
      INTO x_channel_attrib_uses.instr_seccode_use,
           x_channel_attrib_uses.instr_billing_address,
           x_channel_attrib_uses.instr_voiceauthflag_use,
           x_channel_attrib_uses.instr_voiceauthcode_use,
           x_channel_attrib_uses.instr_voiceauthdate_use,
           x_channel_attrib_uses.po_number_use,
           x_channel_attrib_uses.po_line_number_use,
           x_channel_attrib_uses.addinfo_use;
  
    IF (c_appl_attribs%NOTFOUND) THEN
      x_response.result_code := g_rc_invalid_chnnl;
    ELSE
      x_response.result_code := iby_fndcpt_common_pub.g_rc_success;
    END IF;
  
    CLOSE c_appl_attribs;
  
    iby_fndcpt_common_pub.prepare_result(l_prev_msg_count,
			     x_return_status,
			     x_msg_count,
			     x_msg_data,
			     x_response);
  
  EXCEPTION
  
    WHEN fnd_api.g_exc_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_ERROR Exception',
		debug_level => fnd_log.level_error,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN fnd_api.g_exc_unexpected_error THEN
    
      iby_debug_pub.add(debug_msg   => 'In G_EXC_UNEXPECTED_ERROR Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
    WHEN OTHERS THEN
    
      iby_debug_pub.add(debug_msg   => 'In OTHERS Exception',
		debug_level => fnd_log.level_unexpected,
		module      => g_debug_module || l_module);
    
      iby_fndcpt_common_pub.clear_msg_stack(l_prev_msg_count);
    
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name,
		        l_module,
		        substr(SQLERRM, 1, 100));
      END IF;
    
      fnd_msg_pub.count_and_get(p_count => x_msg_count,
		        p_data  => x_msg_data);
  END get_payment_channel_attribs;
  -----------------------------------------------------------------------
  --  name:               Get_Customer_Email
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Function to get Email Address of customer.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Function to get Email Address of customer.
  --  1.1   27/09/2016    Sujoy Das       CHG0039336 - Change in logic to get Email Address of customer.
  ----------------------------------------------------------------------
  FUNCTION get_customer_email(p_customer_number IN VARCHAR2,
		      p_cash_receipt_id VARCHAR2,
		      p_ibycc_attr2     VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_contact_email VARCHAR2(1000);
  BEGIN
    --1st Primary email address of credit card Bill To Contact, if no Bill To Contact then
    -- added on 27-SEP-2016
    BEGIN
      SELECT hzcp.email_address
      INTO   l_contact_email
      FROM   hz_contact_points hzcp,
	 ar_contacts_v     acv
      WHERE  hzcp.owner_table_id = acv.rel_party_id
      AND    hzcp.owner_table_name = 'HZ_PARTIES'
      AND    hzcp.status = 'A'
      AND    hzcp.contact_point_type = 'EMAIL'
      AND    hzcp.primary_flag = 'Y'
      AND    acv.contact_id = p_ibycc_attr2
      AND    hzcp.email_address IS NOT NULL;
    
      print_message('From Step_1 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email; -- Return if Found Value
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --2nd Primary email address of contact assigned as the Primary Bill To, if no contact set as Bill To primary then
  
    BEGIN
      /*SELECT hzcp.email_address
      INTO   l_contact_email
      FROM   hz_cust_accounts       a,
             hz_cust_acct_sites_all b,
             hz_cust_site_uses_all  c,
             hz_contact_points      hzcp
      WHERE  a.cust_account_id = b.cust_account_id
      AND    b.cust_acct_site_id = c.cust_acct_site_id
      AND    c.site_use_code = 'BILL_TO'
      AND    c.status = 'A'
      AND    b.org_id = c.org_id
      AND    c.primary_flag = 'Y'
      AND    hzcp.owner_table_name = 'HZ_PARTY_SITES'
      AND    hzcp.status = 'A'
      AND    hzcp.contact_point_type = 'EMAIL'
      AND    hzcp.primary_flag = 'Y'
      AND    hzcp.owner_table_id = b.party_site_id
      AND    b.org_id = fnd_profile.VALUE('ORG_ID')
      AND    a.account_number = p_customer_number;*/
    
      -- added on 27-SEP-2016
      SELECT hcp.email_address
      INTO   l_contact_email
      FROM   hz_cust_accounts       hca,
	 hz_cust_account_roles  car,
	 hz_parties             hpr,
	 hz_role_responsibility hrr,
	 hz_relationships       hr,
	 hz_contact_points      hcp
      WHERE  hca.account_number = p_customer_number
      AND    hca.cust_account_id = car.cust_account_id
      AND    hca.status = 'A' --active
      AND    car.status = 'A' --active
      AND    car.party_id = hpr.party_id
      AND    hpr.party_type = 'PARTY_RELATIONSHIP'
      AND    car.cust_account_role_id = hrr.cust_account_role_id
      AND    hrr.responsibility_type = 'BILL_TO' --Bill-To contact role
      AND    hrr.primary_flag = 'Y' --Primmary Bill-To role for customer
      AND    car.party_id = hr.party_id
      AND    hr.subject_table_name = 'HZ_PARTIES'
      AND    hr.subject_type = 'PERSON'
      AND    hr.relationship_code = 'CONTACT_OF'
      AND    hr.party_id = hcp.owner_table_id
      AND    hcp.owner_table_name = 'HZ_PARTIES'
      AND    hcp.primary_flag = 'Y'
      AND    hcp.contact_point_type = 'EMAIL'
      AND    hcp.status = 'A'
      AND    hcp.email_address IS NOT NULL;
    
      print_message('From Step_2 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email; -- Return if Found Value
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --3rd Primary email address of designated contact for Primary Bill To site
    BEGIN
      SELECT ocv.email_address
      INTO   l_contact_email
      FROM   hz_cust_accounts       a,
	 hz_cust_acct_sites_all b,
	 hz_cust_site_uses_all  c,
	 oe_contacts_v          ocv
      WHERE  a.cust_account_id = b.cust_account_id
      AND    b.cust_acct_site_id = c.cust_acct_site_id
      AND    c.site_use_code = 'BILL_TO'
      AND    c.status = 'A'
      AND    b.org_id = c.org_id
      AND    c.primary_flag = 'Y'
      AND    ocv.contact_id = c.contact_id
      AND    b.org_id = fnd_profile.value('ORG_ID') --737
      AND    a.account_number = p_customer_number
      AND    ocv.email_address IS NOT NULL;
    
      print_message('From Step_3 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email; -- Return if Found Value
    
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --4th Debit Notification email for Primary Bill To site,
    BEGIN
      SELECT iby_epa.debit_advice_email
      INTO   l_contact_email
      FROM   hz_cust_accounts        a,
	 hz_cust_acct_sites_all  b,
	 hz_cust_site_uses_all   c,
	 iby_external_payers_all iby_epa
      WHERE  a.cust_account_id = b.cust_account_id
      AND    b.cust_acct_site_id = c.cust_acct_site_id
      AND    c.site_use_code = 'BILL_TO'
      AND    c.status = 'A'
      AND    b.org_id = c.org_id
      AND    c.primary_flag = 'Y'
      AND    iby_epa.debit_advice_delivery_method = 'EMAIL'
      AND    iby_epa.org_id = fnd_profile.value('ORG_ID') --737
      AND    iby_epa.org_type = 'OPERATING_UNIT'
      AND    iby_epa.payment_function = 'CUSTOMER_PAYMENT'
      AND    iby_epa.acct_site_use_id = c.site_use_id
      AND    b.org_id = fnd_profile.value('ORG_ID') --737
      AND    a.account_number = p_customer_number
      AND    iby_epa.debit_advice_email IS NOT NULL;
    
      print_message('From Step_4 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email; -- Return if Found Value
    
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --  5th account level Debit Notification email, if no value then
    BEGIN
      SELECT iby_epa.debit_advice_email
      INTO   l_contact_email
      FROM   hz_cust_accounts        a,
	 hz_cust_acct_sites_all  b,
	 hz_cust_site_uses_all   c,
	 iby_external_payers_all iby_epa
      WHERE  a.cust_account_id = b.cust_account_id
      AND    b.cust_acct_site_id = c.cust_acct_site_id
      AND    c.site_use_code = 'BILL_TO'
      AND    c.status = 'A'
      AND    b.org_id = c.org_id
      AND    c.primary_flag = 'Y'
      AND    iby_epa.debit_advice_delivery_method = 'EMAIL'
      AND    iby_epa.payment_function = 'CUSTOMER_PAYMENT'
      AND    iby_epa.cust_account_id = a.cust_account_id
      AND    iby_epa.acct_site_use_id IS NULL
      AND    b.org_id = fnd_profile.value('ORG_ID') --737
      AND    a.account_number = p_customer_number
      AND    iby_epa.debit_advice_email IS NOT NULL;
    
      print_message('From Step_5 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email; -- Return if Found Value
    
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --6th Primary email address of bill to contact for first saved receipt application (based on apply date & record id),
    BEGIN
      SELECT oecv.email_address
      INTO   l_contact_email
      FROM   ra_customer_trx_partial_v    racv,
	 oe_contacts_v                oecv,
	 ar_receivable_applications_v arav
      WHERE  1 = 1
      AND    oecv.contact_id = racv.bill_to_contact_id
      AND    racv.trx_number = arav.trx_number
      AND    arav.cash_receipt_id = p_cash_receipt_id
      AND    oecv.email_address IS NOT NULL -- added on 27-SEP-2016
      AND    rownum = 1;
    
      print_message('From Step_6 l_contact_email: ' || l_contact_email);
    
      RETURN l_contact_email;
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_email := NULL;
      WHEN OTHERS THEN
        l_contact_email := NULL;
        RETURN l_contact_email; -- Return if any Other query error
    END;
  
    --7th send to creditcardprocessing@stratasys.com
    l_contact_email := 'creditcardprocessing@stratasys.com';
  
    print_message('From Step_7 l_contact_email: ' || l_contact_email);
  
    RETURN l_contact_email;
  END get_customer_email;
  ---------------------------------------------------------------
  --  name:               get_customer_phone
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - function to get customer phone number whom to send credit card receipts.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - function to get customer phone number whom to send credit card receipts.
  -----------------------------------------------------------------------
  FUNCTION get_customer_phone(p_customer_number IN VARCHAR2,
		      p_ibycc_attr2     VARCHAR2) RETURN VARCHAR2 IS
    l_contact_phone VARCHAR2(1000) := NULL;
  BEGIN
    --1st Primary phone assigned with creditcard holder contact_id
    IF p_ibycc_attr2 IS NOT NULL THEN
      BEGIN
      
        SELECT hzcp.raw_phone_number
        INTO   l_contact_phone
        FROM   hz_contact_points hzcp,
	   ar_contacts_v     acv
        WHERE  hzcp.owner_table_id = acv.rel_party_id
        AND    hzcp.owner_table_name = 'HZ_PARTIES'
        AND    hzcp.status = 'A'
        AND    hzcp.contact_point_type = 'PHONE'
        AND    hzcp.primary_flag = 'Y'
        AND    acv.contact_id = p_ibycc_attr2;
      
        RETURN l_contact_phone; -- Return if Found Value
      
      EXCEPTION
        WHEN no_data_found THEN
          l_contact_phone := NULL;
        WHEN OTHERS THEN
          l_contact_phone := NULL;
          RETURN l_contact_phone; -- Return if any Other query error
      END;
    END IF;
    --2nd Primary phone assigned as the Primary Bill To site
    BEGIN
    
      SELECT hzcp.raw_phone_number
      INTO   l_contact_phone
      FROM   hz_cust_accounts       a,
	 hz_cust_acct_sites_all b,
	 hz_cust_site_uses_all  c,
	 hz_contact_points      hzcp
      WHERE  a.cust_account_id = b.cust_account_id
      AND    b.cust_acct_site_id = c.cust_acct_site_id
      AND    c.site_use_code = 'BILL_TO'
      AND    c.status = 'A'
      AND    b.org_id = c.org_id
      AND    c.primary_flag = 'Y'
      AND    hzcp.owner_table_name = 'HZ_PARTY_SITES'
      AND    hzcp.status = 'A'
      AND    hzcp.contact_point_type = 'PHONE'
      AND    hzcp.primary_flag = 'Y'
      AND    hzcp.owner_table_id = b.party_site_id
      AND    b.org_id = fnd_profile.value('ORG_ID')
      AND    a.account_number = p_customer_number;
    
      RETURN l_contact_phone; -- Return if Found Value
    
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_phone := NULL;
      WHEN OTHERS THEN
        l_contact_phone := NULL;
        RETURN l_contact_phone; -- Return if any Other query error
    END;
  
    RETURN l_contact_phone;
  END get_customer_phone;
  -----------------------------------------------------------------------
  --  name:               update_Receipt_MailFlag
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to update customer mail notification.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to update customer mail notification.
  -----------------------------------------------------------------------
  PROCEDURE update_receipt_mailflag(p_cash_receipt_id NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE ar_cash_receipts
    SET    attribute15 = 'Y' -- Receipt notificaton Send to Customer
    WHERE  cash_receipt_id = p_cash_receipt_id;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      print_message('Error During Update attribute15 in AR_CASH_RECEIPTS Table:' ||
	        SQLERRM);
  END update_receipt_mailflag;
  -----------------------------------------------------------------------
  --  name:               send_email_notification
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to send Email Notification to customer.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to send Email Notification to customer.
  --  1.1   31/08/2016    Sujoy Das       CHG0039336 - To send Refund notification.
  --  1.2   27/09/2016    Sujoy Das       CHG0039336 - Change in logic to get Email Address of customer.
  --  1.3   09/11/2016    Saar Nagar      INC0079952 - resize l_body to 32767
  --  1.4   05.06.17      Lingaraj(TCS)   INC0094556 - Error when sending CC receipt
  --                                       resize l_body to CLOB
  -----------------------------------------------------------------------
  PROCEDURE send_email_notification(p_err_message         OUT VARCHAR2,
			p_err_code            OUT NUMBER, -- INC0094556 05.06.17
			p_rec_date_low        IN VARCHAR2,
			p_rec_date_high       IN VARCHAR2,
			p_remit_batch         IN VARCHAR2 DEFAULT NULL,
			p_receipt_class       IN VARCHAR2 DEFAULT NULL,
			p_payment_method      IN VARCHAR2 DEFAULT NULL,
			p_rec_num_low         IN VARCHAR2 DEFAULT NULL,
			p_rec_num_high        IN VARCHAR2 DEFAULT NULL,
			p_customer_number     IN VARCHAR2 DEFAULT NULL,
			p_resend_notification IN VARCHAR2 DEFAULT 'N') IS
  
    l_subject        VARCHAR2(250);
    l_subject2       VARCHAR2(250);
    l_subject3       VARCHAR2(250);
    l_to             VARCHAR2(500);
    l_ind            NUMBER(1) := 0;
    l_body           CLOB; /*VARCHAR2(32767); -- INC0079952*/ -- l_body data type change to CLOB - INC0094556
    l_db             VARCHAR2(50) := sys_context('userenv', 'db_name'); --Modified on 05.06.17 for INC0094556
    l_email          VARCHAR2(500);
    l_phone          VARCHAR2(500);
    l_mailheader     VARCHAR2(500);
    l_mailfooter     VARCHAR2(500);
    l_recfound       NUMBER := 0;
    l_rec_mailsent   NUMBER := 0;
    l_error_code     NUMBER;
    l_recfound_inner NUMBER := 0;
    l_table_row      CLOB; --Added INC0094556 05.06.17
    l_email_from     VARCHAR2(50) := 'creditcardprocessing@stratasys.com'; --Added INC0094556 05.06.17
  
    CURSOR c_receipt_lines(p_rec_date_low        VARCHAR2,
		   p_rec_date_high       VARCHAR2,
		   p_remit_batch         VARCHAR2,
		   p_receipt_class       VARCHAR2,
		   p_payment_method      VARCHAR2,
		   p_rec_num_low         VARCHAR2,
		   p_rec_num_high        VARCHAR2,
		   p_customer_number     VARCHAR2,
		   p_resend_notification VARCHAR2) IS
      SELECT acrv.receipt_date trx_rcpt_date,
	 (CASE
	   WHEN acrv.amount < 0 THEN
	    '(' || abs(acrv.amount) || ')'
	   ELSE
	    to_char(abs(acrv.amount))
	 END) trx_rcpt_amount,
	 acrv.receipt_number,
	 acrv.receipt_number trx_number,
	 acrv.state_dsp,
	 acrv.receipt_status_dsp,
	 contact_tab.account_number customer_number,
	 contact_tab.party_name company_name,
	 '' phone_country_code,
	 '' phone_area_code,
	 '' phone_number,
	 iby_ext.card_holder_name NAME,
	 (xxiby_process_cust_paymt_pkg.get_masked_ccnumber(iby_ext.instrument_id)) card_number,
	 (xxiby_process_cust_paymt_pkg.get_ibycc_attr2(iby_ext.instrument_id)) ibycc_attr2,
	 iby_ext.trxn_extension_id,
	 acrv.cash_receipt_id
      FROM   ar_cash_receipts_v acrv,
	 iby_trxn_extensions_v iby_ext,
	 (SELECT hca.account_number,
	         hp.party_name
	  FROM   apps.hz_cust_accounts hca,
	         apps.hz_parties       hp
	  WHERE  hca.party_id = hp.party_id) contact_tab
      WHERE  1 = 1
      AND    trunc(acrv.receipt_date) >= p_rec_date_low
      AND    trunc(acrv.receipt_date) <= p_rec_date_high
      AND    acrv.customer_number = contact_tab.account_number
      AND    acrv.payment_trxn_extension_id = iby_ext.trxn_extension_id
      AND    iby_ext.payment_channel_code = 'CREDIT_CARD'
      AND    acrv.state_dsp IN ('Remitted', 'Cleared')
	--AND    acrv.receipt_status_dsp <> 'Unapplied'
      AND    acrv.org_id = fnd_profile.value('ORG_ID')
      AND    acrv.remit_batch = nvl(p_remit_batch, acrv.remit_batch) -- Remittance Batch (optional)
      AND    acrv.receipt_class_dsp =
	 nvl(p_receipt_class, acrv.receipt_class_dsp) -- Receipt Class (optional)
      AND    acrv.payment_method_dsp =
	 nvl(p_payment_method, acrv.payment_method_dsp) -- Payment Method (optional)
      AND    acrv.receipt_number BETWEEN
	 nvl(p_rec_num_low, acrv.receipt_number) AND
	 nvl(p_rec_num_high, acrv.receipt_number) --Receipt range low to high (optional)
      AND    acrv.customer_number =
	 nvl(p_customer_number, acrv.customer_number) --Customer (optional)
      AND    nvl(acrv.attribute15, 'N') =
	 decode(p_resend_notification,
	         'Y',
	         nvl(acrv.attribute15, 'N'),
	         'N'); --  Resend (optional, default = No)
  
    CURSOR c_invoice_lines(l_invoice_num     VARCHAR2,
		   l_cash_receipt_id VARCHAR2) IS
      SELECT decode(rctpv.interface_header_context,
	        'OKL_CONTRACTS',
	        rctpv.interface_header_attribute6,
	        rctpv.interface_header_attribute1) order_number,
	 arav.trx_number invoice,
	 arav.amount_line_items_original charges,
	 arav.tax_original tax,
	 arav.freight_original freight,
	 arav.amount_due_original invoice_total,
	 arav.amount_applied amount_paid
      FROM   ar_receivable_applications_v arav,
	 ra_customer_trx_partial_v    rctpv
      WHERE  arav.trx_number = rctpv.trx_number(+)
      AND    arav.applied_flag = 'Y'
      AND    arav.receipt_number = l_invoice_num
      AND    arav.cash_receipt_id = l_cash_receipt_id
      ORDER  BY arav.trx_number;
  
    CURSOR c_invoice_lines_refund(l_cash_receipt_id VARCHAR2) IS
      SELECT decode(rctpv.interface_header_context,
	        'OKL_CONTRACTS',
	        rctpv.interface_header_attribute6,
	        rctpv.interface_header_attribute1) order_number,
	 arav.trx_number invoice,
	 arav.amount_line_items_original charges,
	 arav.tax_original tax,
	 arav.freight_original freight,
	 arav.amount_due_original invoice_total,
	 arav.amount_applied amount_paid
      FROM   ar_receivable_applications_v arav,
	 ra_customer_trx_partial_v    rctpv
      WHERE  arav.trx_number = rctpv.trx_number(+)
      AND    arav.applied_flag = 'Y'
      AND    arav.application_ref_id = l_cash_receipt_id --for refund line application_ref_num present
      ORDER  BY arav.trx_number;
  
  BEGIN
    print_message('Step 1');
    ----------------------------------------------
    --#Input Parameter Values
    print_message('Receipt Date range low            :' || p_rec_date_low);
    print_message('Receipt Date range High           :' || p_rec_date_high);
    print_message('Remittance Batch(optional)        :' || p_remit_batch);
    print_message('Receipt Class (optional)          :' || p_receipt_class);
    print_message('Payment Method (optional)         :' ||
	      p_payment_method);
    print_message('Receipt range low (optional)      :' || p_rec_num_low);
    print_message('Receipt range high (optional)     :' || p_rec_num_high);
    print_message('Customer Account Number (optional):' ||
	      p_customer_number);
    print_message('Resend (optional, default = No)   :' ||
	      p_resend_notification);
    print_message('Operating Uint Id (System Value)  :' ||
	      fnd_profile.value('ORG_ID'));
    print_message('G_Debug                           :' || g_debug);
    ----------------------------------------------
  
    /*-- Get Session Details
    SELECT (sys_context('userenv',
                        'db_name'))
    INTO   l_db
    FROM   dual;*/ --Commented on 05.06.17 for INC0094556
    print_message('Instance Name                     :' || l_db);
  
    --l_subject := 'Your credit card has been charged';
    fnd_message.set_name('XXOBJT', 'XXAR_CREDIT_CARD_MAIL_SUBJECT');
    l_subject2 := fnd_message.get;
    --l_subject := 'FYI: Your credit card amount has been Refunded';
    fnd_message.set_name('XXOBJT', 'XXAR_CC_REFUND_MAIL_SUBJECT');
    l_subject3 := fnd_message.get;
    print_message('Step 2');
  
    --Get Mail Body & Footer
    /*SELECT xxobjt_wf_mail_support.get_header_html,
           xxobjt_wf_mail_support.get_footer_html
    INTO   l_mailheader,
           l_mailfooter
    FROM   dual;*/
    l_mailheader := xxobjt_wf_mail_support.get_header_html;
    l_mailfooter := xxobjt_wf_mail_support.get_footer_html;
  
    print_message('');
    --Process Each receipt and Send mail to Customer
    FOR i IN c_receipt_lines(p_rec_date_low,
		     p_rec_date_high,
		     p_remit_batch,
		     p_receipt_class,
		     p_payment_method,
		     p_rec_num_low,
		     p_rec_num_high,
		     p_customer_number,
		     p_resend_notification)
    LOOP
      l_recfound := l_recfound + 1;
      print_message('Record number :' || l_recfound);
      print_message('Customer Number / TRX_NUMBER / Receipt Number :' ||
	        i.customer_number || '/' || i.trx_number || '/' ||
	        i.receipt_number);
      l_error_code := 0;
      l_to         := NULL;
      l_email      := NULL;
      --print_message('Step 2.1');
      -- get Customer email
      l_email := get_customer_email(i.customer_number,
			i.cash_receipt_id,
			i.ibycc_attr2); -- added on 27-sep-2016
      print_message('Email Notification needs to Send to:' || l_email);
      --print_message('Step 2.2');
      -- get Customer phone
      l_phone := get_customer_phone(i.customer_number, i.ibycc_attr2);
      print_message('Customer phone:' || l_phone);
      print_message('Customer Number:' || i.customer_number);
      --If the instance is not Production
      IF l_db = 'PROD' THEN
        l_to := l_email;
      ELSE
        --If Non Prod Env
        l_to := fnd_profile.value('XXAR_CREDITCARD_NONPROD_EMAIL');
        IF TRIM(l_to) = '' OR l_to IS NULL THEN
          l_to := NULL;
          print_message('XXAR_CREDITCARD_NONPROD_EMAIL Profile - Email Id Not Set Properly.Please Provide a valid email Id');
        END IF;
      END IF;
    
      --l_subject := l_subject2 || '-Email To:' || l_email;
      l_subject := l_subject2;
    
      --print_message('Step 2.3');
      IF l_to IS NULL OR TRIM(l_to) = '' THEN
        CONTINUE;
      END IF;
      --print_message('Step 2.4');
      print_message('Email Notification Sent to:' || l_to);
      --print_message('Step 2.5');
      l_body :=  --'<HTML><head><style type="text/css">h3 {color:red;}</style></head>' ||
      --'<p><img alt="Objet" height="50" width="130" src="http://usnj01erp01t.stratasys.dmn:8010//OA_MEDIA/XXLOGO.gif"></img></br></p>' ||
       '<p><font face="Tohoma" color="black" size="3">7665 Commerce Way<br>Eden Prairie, MN 55344<br>1.800.801.6491<br>
	    URL: http://www.stratasys.com<br>creditcardprocessing@stratasys.com</font></p>' ||
	    '<p><font face="Tohoma" color="blue" size="3">Transaction Date : ' ||
	    i.trx_rcpt_date || ' <br>' || 'Charge Amount : ' ||
	    i.trx_rcpt_amount || ' </font></p>' ||
	    '<p><font face="Tohoma" color="black" size="4"><strong>Cardholder Information</strong></font></p>' ||
	    '<p><font face="Tohoma" color="black" size="3">Name : ' ||
	    i.name || ' <br>' || 'Card Number : ' || i.card_number ||
	    ' </font></p>' ||
	    '<p><font face="Tohoma" color="black" size="3">Customer Number : ' ||
	    i.customer_number || ' <br>' || 'Company Name : ' ||
	    i.company_name || ' <br>' || 'Phone Number : ' || l_phone ||
	    ' </font></p>' ||
	   --i.phone_country_code || ' ' || i.phone_area_code || ' ' ||
	   --i.phone_number || ' </p>' ||
	    '<p><font face="Tohoma" color="black" size="4"><strong>Order Information</strong></font></p>' ||
	    '<TABLE cellpadding="5"  style="color:blue" BORDER =1 > ' ||
	    '<TR><TH>Order Number</TH><TH>Invoice</TH><TH>Charges</TH><TH>Tax</TH><TH>Freight</TH><TH>Invoice Total</TH><TH>Amount Paid</TH></TR>';
    
      FOR j IN c_invoice_lines_refund(i.cash_receipt_id)
      LOOP
        l_recfound_inner := l_recfound_inner + 1;
        l_subject        := l_subject3;
      
        --l_body := l_body || -- Commented on 05.06.17 for INC0094556
        l_table_row := '<TR><font face="Tohoma" color="black" size="3"><TD>' ||
	           j.order_number || '</TD> <TD>' || j.invoice ||
	           '</TD><TD><p align="right">' || j.charges ||
	           '</p></TD><TD><p align="right">' || j.tax ||
	           '</p></TD><TD><p align="right">' || j.freight ||
	           '</p></TD><TD><p align="right">' || j.invoice_total ||
	           '</p></TD><TD><p align="right">' || j.amount_paid ||
	           '</p></TD></font></TR>';
      
        l_body := l_body || l_table_row; -- Added on 05.06.17 for  INC0094556
      END LOOP; --end inner invoice loop for refund lines
    
      IF l_recfound_inner = 0 THEN
        -- no Refund receipt found
        FOR k IN c_invoice_lines(i.receipt_number, i.cash_receipt_id)
        LOOP
          l_subject := l_subject2;
        
          --l_body := l_body || -- Commented on 05.06.17 for INC0094556
          l_table_row := '<TR><font face="Tohoma" color="black" size="3"><TD>' ||
		 k.order_number || '</TD> <TD>' || k.invoice ||
		 '</TD><TD><p align="right">' || k.charges ||
		 '</p></TD><TD><p align="right">' || k.tax ||
		 '</p></TD><TD><p align="right">' || k.freight ||
		 '</p></TD><TD><p align="right">' ||
		 k.invoice_total ||
		 '</p></TD><TD><p align="right">' || k.amount_paid ||
		 '</p></TD></font></TR>';
          l_body      := l_body || l_table_row; -- Added on 05.06.17 for  INC0094556
        END LOOP; --end inner invoice loop
      END IF;
    
      l_recfound_inner := 0; --reassigning this to 0, so it will again take fresh value
    
      IF i.receipt_status_dsp = 'Unapplied' THEN
        -- for Unapplied receipts, forming mail body for 'On Account'
      
        l_subject := l_subject2;
      
        --l_body := l_body ||-- Commented on 05.06.17 for INC0094556
        l_table_row := '<TR><font face="Tohoma" color="black" size="3"><TD>' || NULL ||
	           '</TD> <TD>' || 'On Account' ||
	           '</TD><TD><p align="right">' || NULL ||
	           '</p></TD><TD><p align="right">' || NULL ||
	           '</p></TD><TD><p align="right">' || NULL ||
	           '</p></TD><TD><p align="right">' || '0' ||
	           '</p></TD><TD><p align="right">' ||
	           i.trx_rcpt_amount || '</p></TD></font></TR>';
        l_body      := l_body || l_table_row; -- Added on 05.06.17 for  INC0094556
      END IF;
    
      l_body := l_body || '</table>' ||
	    '<p><font face="Tohoma" color="black" size="3">CONFIDENTIALITY NOTICE: This message, including any attachments, is the property of Stratasys and is solely for the use of the individual or entity intended to receive it. It may contain
	  Stratasys confidential, proprietary and/or privileged information, and any unauthorized review, use, disclosure or distribution is prohibited. If you are not the intended recipient or if you
	  have received this message in error, please permanently delete it and contact the sender by reply e-mail.  it and contact the sender by reply e-mail.</font></p>';
    
      l_body := l_mailheader || l_body || '</html>';
    
      /*IF g_debug = 'Y' THEN
        --Print Mail HTML string in the Concurrent log
        print_message(l_body);
      END IF;*/ -- Commented on 05.06.17 for INC0094556 , if the mail body length more then 32767 , print gives error
    
      /* xxobjt_wf_mail.send_mail_html(p_to_role     => fnd_profile.VALUE('XXAR_CREDITCARD_WFMAILER_USER_ADMIN'), --'CREDITCARDPROCESSING',
      p_cc_mail     => l_to,
      p_bcc_mail    => '',
      p_subject     => l_subject,
      p_body_html   => l_body,
      p_err_code    => l_error_code,
      p_err_message => p_err_message);*/
      print_message('Before Sending Mail , Mail Body Length :' ||
	        dbms_lob.getlength(l_body));
      -- START of code block for CHG0039336
      xxiby_process_cust_paymt_pkg.send_smtp_mail(p_msg_to        => l_to,
				  p_msg_from      => l_email_from, --'creditcardprocessing@stratasys.com', --fnd_profile.VALUE('XXAR_CREDITCARD_WFMAILER_USER_ADMIN'),
				  p_msg_subject   => l_subject,
				  p_msg_text_html => l_body,
				  p_err_code      => l_error_code,
				  p_err_message   => p_err_message);
    
      -- END of code block for CHG0039336
    
      --Update the Receipt Table Attribute15 for the Mail notificfation Send as Y
      IF l_error_code = 0 THEN
        l_rec_mailsent := l_rec_mailsent + 1;
        update_receipt_mailflag(i.cash_receipt_id);
      ELSE
        --Else Part Added on 05.06.17 for INC0094556
        print_message('Error During Mail Send : ' || p_err_message);
      END IF;
      print_message('');
    END LOOP; --end outer receipt loop
    print_message('No Of Customer Records Fetched for Recipt Mail Send:' ||
	      l_recfound);
    print_message('No Of Customer Recipt Mail Sent:' || l_rec_mailsent);
    --Below Condition Added on 05.06.17 for INC0094556
    -- If Records eligiable to mail send and actual mail send are different , Program will complete with Warning
    IF l_recfound != l_rec_mailsent THEN
      p_err_code := 1;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      --p_factor := NULL;
      p_err_code    := 2;
      p_err_message := 'SQl ERROR:' || fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
  END send_email_notification;
  ---------------------------------------------------------------
  --  name:               print_message
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to Print messages to output.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to Print messages to output.
  -----------------------------------------------------------------------
  PROCEDURE print_message(p_msg         VARCHAR2,
		  p_destination VARCHAR2 DEFAULT fnd_file.log) IS
  
    l_msg VARCHAR2(2000);
    ----------------------------
    --     Code Section
    ----------------------------
  BEGIN
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' ' || p_msg;
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(p_destination, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  END print_message;
  ---------------------------------------------------------------
  --  name:               get_orb_ccno
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get orbital connection parameters.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get orbital connection parameters.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_ccno(p_ordernumber IN VARCHAR2,
		 p_ccnumber    OUT VARCHAR2,
		 p_err_code    OUT NUMBER,
		 p_err_message OUT VARCHAR2) IS
  
    l_ordernumber VARCHAR2(20);
    l_ccnumber    VARCHAR2(50);
    data_not_found EXCEPTION;
  
  BEGIN
    l_ordernumber := p_ordernumber;
  
    SELECT ic.ccnumber
    INTO   l_ccnumber
    FROM   iby_fndcpt_tx_extensions ifte,
           iby_pmt_instr_uses_all   ipua,
           iby_creditcard           ic
    WHERE  ifte.instr_assignment_id = ipua.instrument_payment_use_id(+)
    AND    ipua.instrument_id = ic.instrid(+)
    AND    ifte.payment_system_order_number = l_ordernumber;
  
    IF l_ccnumber IS NOT NULL THEN
    
      p_ccnumber := l_ccnumber;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      p_err_code    := 1;
      p_err_message := 'WARNING xxiby_process_cust_paymt_pkg.get_orb_ccno' ||
	           fnd_message.get || ' ' || SQLERRM;
    
      print_message(p_err_message);
      --dbms_output.put_line('SQl ERROR:' || SQLERRM);
  END get_orb_ccno;

  ---------------------------------------------------------------
  --  name:               get_orb_trnrefnum
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get orbital trxn ref number.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get orbital trxn ref number.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_trnrefnum(p_ordernumber IN VARCHAR2,
		      p_trnrefnum   OUT VARCHAR2,
		      p_err_code    OUT NUMBER,
		      p_err_message OUT VARCHAR2) IS
  
    /*l_ordernumber VARCHAR2(40);*/
    l_trnrefnum VARCHAR2(50);
  BEGIN
    p_err_code := 0;
    /*l_ordernumber := p_ordernumber;*/
    SELECT omx.txrefnum
    INTO   l_trnrefnum
    FROM   apps.xxiby_orbital_order_mapping omx
    WHERE  omx.order_id = p_ordernumber;
  
    IF l_trnrefnum IS NOT NULL THEN
      p_trnrefnum := l_trnrefnum;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      --p_err_message := fnd_message.get || ' ' || SQLERRM;
      print_message('SQl ERROR:' || SQLERRM);
      p_err_message := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_orb_trnrefnum(' ||
	           p_ordernumber || ') - ' || SQLERRM;
  END get_orb_trnrefnum;
  ---------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  ------------------------------------------
  -- 1.0   26/04/2021  Roman W.    CHG0049588 - cc
  ---------------------------------------------------------------------------
  PROCEDURE get_orb_cc_level(p_ordernumber              IN VARCHAR2,
		     p_ctilevel3eligible        OUT VARCHAR2,
		     p_cardbrand                OUT VARCHAR2,
		     p_mitreceivedtransactionid OUT VARCHAR2,
		     p_error_code               OUT VARCHAR2,
		     p_error_desc               OUT VARCHAR2) IS
    ---------------------------
    --   Local Definition
    ---------------------------
  
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT omx.ctilevel3eligible,
           omx.cardbrand,
           omx.mitreceivedtransactionid
    INTO   p_ctilevel3eligible,
           p_cardbrand,
           p_mitreceivedtransactionid
    FROM   apps.xxiby_orbital_order_mapping omx
    WHERE  omx.order_id = p_ordernumber;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_ctilevel3eligible        := NULL;
      p_cardbrand                := NULL;
      p_mitreceivedtransactionid := NULL;
      p_error_code               := '0';
      p_error_desc               := NULL;
    
    WHEN too_many_rows THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_TOO_MANY_ROWS xxiby_process_cust_paymt_pkg.get_orb_cc_level(' ||
	          p_ordernumber || ') - ' || SQLERRM;
    
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_orb_cc_level(' ||
	          p_ordernumber || ') - ' || SQLERRM;
  END get_orb_cc_level;
  ---------------------------------------------------------------------------
  -- Ver   Who        When         Descr
  -- ----  ---------  -----------  ------------------------------------------
  -- 1.0   Roman W.   2021/04/26   CHG0049588 - cc
  ---------------------------------------------------------------------------

  ---------------------------------------------------------------
  --  name:               get_merchantid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch merchantid for payee orb.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch merchantid for payee orb.It is called from Java Servlet.
  -----------------------------------------------------------------------
  FUNCTION get_merchantid RETURN VARCHAR2 IS
    l_merchantid VARCHAR2(50);
  BEGIN
    --selecting merchantid value
    SELECT ibaov.account_option_value
    INTO   l_merchantid
    FROM   iby.iby_bepinfo           info,
           iby.iby_bep_acct_opt_vals ibaov,
           iby.iby_bepkeys           keys
    WHERE  keys.bepid = info.bepid
    AND    info.bepid = ibaov.bepid
    AND    keys.ownertype = 'PAYEE'
    AND    info.activestatus = 'Y'
    AND    keys.ownerid = 'orb'
    AND    ibaov.account_option_code = 'merchantID'
    AND    rownum = 1;
  
    RETURN l_merchantid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_merchantid;
  ---------------------------------------------------------------
  --  name:               get_binvalue
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch bin value for payee orb.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch bin value for payee orb.It is called from Java Servlet.
  -----------------------------------------------------------------------
  FUNCTION get_binvalue RETURN VARCHAR2 IS
    l_bin VARCHAR2(50);
  BEGIN
    --selecting bin value
    SELECT ibaov.account_option_value
    INTO   l_bin
    FROM   iby.iby_bepinfo           info,
           iby.iby_bep_acct_opt_vals ibaov,
           iby.iby_bepkeys           keys
    WHERE  keys.bepid = info.bepid
    AND    info.bepid = ibaov.bepid
    AND    keys.ownertype = 'PAYEE'
    AND    info.activestatus = 'Y'
    AND    keys.ownerid = 'orb'
    AND    ibaov.account_option_code = 'bin'
    AND    rownum = 1;
  
    RETURN l_bin;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_binvalue;
  ---------------------------------------------------------------
  --  name:               get_terminalid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch terminalid value for payee orb.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch terminalid value for payee orb.It is called from Java Servlet.
  -----------------------------------------------------------------------
  FUNCTION get_terminalid RETURN VARCHAR2 IS
    l_terminalid VARCHAR2(50);
  BEGIN
    --selecting bin value
    SELECT ibaov.account_option_value
    INTO   l_terminalid
    FROM   iby.iby_bepinfo           info,
           iby.iby_bep_acct_opt_vals ibaov,
           iby.iby_bepkeys           keys
    WHERE  keys.bepid = info.bepid
    AND    info.bepid = ibaov.bepid
    AND    keys.ownertype = 'PAYEE'
    AND    info.activestatus = 'Y'
    AND    keys.ownerid = 'orb'
    AND    ibaov.account_option_code = 'terminalID'
    AND    rownum = 1;
  
    RETURN l_terminalid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_terminalid;
  ---------------------------------------------------------------
  --  name:               get_industrytype
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch industrytype value for payee orb.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch industrytype value for payee orb.It is called from Java Servlet.
  -----------------------------------------------------------------------
  FUNCTION get_industrytype RETURN VARCHAR2 IS
    l_industrytype VARCHAR2(50);
  BEGIN
    --selecting industrytype value
    SELECT ibaov.account_option_value
    INTO   l_industrytype
    FROM   iby.iby_bepinfo           info,
           iby.iby_bep_acct_opt_vals ibaov,
           iby.iby_bepkeys           keys
    WHERE  keys.bepid = info.bepid
    AND    info.bepid = ibaov.bepid
    AND    keys.ownertype = 'PAYEE'
    AND    info.activestatus = 'Y'
    AND    keys.ownerid = 'orb'
    AND    ibaov.account_option_code = 'industryType'
    AND    rownum = 1;
  
    RETURN l_industrytype;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_industrytype;
  ---------------------------------------------------------------
  --  name:               get_line_remitted_flag
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Function to check order line Remitted or not.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Function to check order line Remitted or not.
  -----------------------------------------------------------------------
  FUNCTION get_line_remitted_flag(p_line_id VARCHAR2) RETURN VARCHAR2 IS
    l_remitted_flag VARCHAR2(1) := NULL;
    l_count         NUMBER;
  BEGIN
  
    SELECT COUNT(arcv.cash_receipt_id)
    INTO   l_count
    FROM   oe_order_lines_all           ol,
           ra_customer_trx_lines_all    rctl,
           ra_customer_trx_all          rcta,
           ar_payment_schedules_all     apsa,
           ar_receivable_applications_v arav,
           ar_cash_receipts_v           arcv
    WHERE  to_char(ol.line_id) = rctl.interface_line_attribute6
    AND    rctl.customer_trx_id = rcta.customer_trx_id
    AND    rcta.customer_trx_id = apsa.customer_trx_id
    AND    rctl.customer_trx_id = apsa.customer_trx_id
    AND    rcta.customer_trx_id = arav.customer_trx_id
    AND    rctl.customer_trx_id = arav.customer_trx_id
    AND    arav.cash_receipt_id = arcv.cash_receipt_id
    AND    ol.line_id = p_line_id
    AND    ol.org_id = fnd_profile.value('ORG_ID') --737
    AND    apsa.class = 'INV'
    AND    apsa.status = 'CL'
    AND    arcv.state_dsp IN ('Remitted', 'Cleared')
    AND    arcv.payment_type_code = 'CREDIT_CARD';
  
    IF l_count = 0 THEN
      l_remitted_flag := 'N';
    ELSIF l_count > 0 THEN
      l_remitted_flag := 'Y';
    END IF;
    print_message('l_remitted_flag/p_line_id =>' || l_remitted_flag || '/' ||
	      p_line_id);
    RETURN l_remitted_flag;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_line_remitted_flag;
  ---------------------------------------------------------------
  --  name:               get_line_pson
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Function to get TangibleID(PSON) for a order line.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Function to get TangibleID(PSON) for a order line.
  -----------------------------------------------------------------------
  FUNCTION get_line_pson(p_line_id VARCHAR2) RETURN VARCHAR2 IS
    l_tangibleid VARCHAR2(50) := NULL;
  BEGIN
  
    SELECT itsa.tangibleid
    INTO   l_tangibleid
    FROM   ar_cash_receipts_v           acrv,
           iby_trxn_extensions_v        iby_ext,
           iby_trxn_summaries_all       itsa,
           ar_receivable_applications_v arav,
           ra_customer_trx_lines_all    rctl,
           oe_order_lines_all           ol
    WHERE  1 = 1
    AND    acrv.payment_trxn_extension_id = iby_ext.trxn_extension_id
    AND    iby_ext.payment_channel_code = 'CREDIT_CARD'
    AND    acrv.state_dsp IN ('Remitted', 'Cleared')
    AND    acrv.org_id = fnd_profile.value('ORG_ID') --737
    AND    itsa.tangibleid = iby_ext.payment_system_order_number
    AND    itsa.status = 0
    AND    itsa.reqtype = 'ORAPMTCAPTURE'
    AND    acrv.cash_receipt_id = arav.cash_receipt_id
    AND    arav.customer_trx_id = rctl.customer_trx_id
    AND    rctl.interface_line_attribute6 = to_char(ol.line_id)
    AND    ol.line_id = p_line_id;
  
    print_message('l_tangibleid from Function get_line_pson =>' ||
	      l_tangibleid);
  
    RETURN l_tangibleid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_line_pson;
  ---------------------------------------------------------------
  --  name:               get_so_tangibleid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to fetch tangibleid(PSON) from Sales Order.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to fetch tangibleid(PSON) from Sales Order.
  -----------------------------------------------------------------------
  PROCEDURE get_so_tangibleid(p_so_header_id IN OUT NUMBER, -- SO Header ID
		      p_tangibleid   IN OUT VARCHAR2, -- iby_trxn_summaries_all.TANGIBLEID
		      p_errorcode    OUT NUMBER,
		      p_error        OUT VARCHAR2) IS
    l_tangibleid   VARCHAR2(100);
    l_so_header_id NUMBER;
  BEGIN
    p_errorcode := 0;
    IF g_debug = 'Y' THEN
      print_message('Inside xxiby_process_cust_paymt_pkg.get_so_tangibleid');
      print_message('p_so_header_id =>' || p_so_header_id);
      print_message('p_tangibleid =>' || p_tangibleid);
    END IF;
    --print_message('p_errorCode =>' || p_errorcode);
    print_message('------------------------------------------');
  
    IF p_so_header_id IS NOT NULL THEN
      -- Fetch the  tangibleid and Return that Value
      SELECT pts.tangibleid
      INTO   l_tangibleid
      FROM   oe_order_headers_all   oeh,
	 oe_payments            opt,
	 iby_trxn_summaries_all pts
      WHERE  1 = 1
      AND    oeh.header_id = opt.header_id
      AND    opt.trxn_extension_id = pts.initiator_extension_id
      AND    oeh.header_id = p_so_header_id
      AND    oeh.org_id = fnd_profile.value('ORG_ID'); --737 -- added on 19-OCT-2016
    
      p_tangibleid := l_tangibleid;
    
    ELSIF p_tangibleid IS NOT NULL THEN
      -- Fetch the  SO Header Id and Return that Value
      SELECT oeh.header_id
      INTO   l_so_header_id
      FROM   oe_order_headers_all   oeh,
	 oe_payments            opt,
	 iby_trxn_summaries_all pts
      WHERE  1 = 1
      AND    oeh.header_id = opt.header_id
      AND    opt.trxn_extension_id = pts.initiator_extension_id
      AND    pts.tangibleid = p_tangibleid
      AND    oeh.org_id = fnd_profile.value('ORG_ID'); --737 -- added on 19-OCT-2016
    
      p_so_header_id := l_so_header_id;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_errorcode := 1; -- Error in Fetching data
      p_error     := 'WARNING : xxiby_process_cust_paymt_pkg.get_so_tangibleid =>' ||
	         SQLERRM;
    
      print_message(p_error);
    
  END get_so_tangibleid;
  ---------------------------------------------------------------
  --  name:               get_so_header_id
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Function to fetch header_id from Sales Order.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Function to fetch header_id from Sales Order.
  -----------------------------------------------------------------------
  FUNCTION get_so_header_id(p_tangibleid IN VARCHAR2) RETURN NUMBER IS
    l_so_header_id NUMBER := NULL;
    l_error_code   NUMBER;
    l_error        VARCHAR2(1000);
    l_tangibleid   VARCHAR2(100) := p_tangibleid;
  BEGIN
    IF p_tangibleid IS NULL THEN
      RETURN - 1;
    END IF;
    get_so_tangibleid(p_so_header_id => l_so_header_id --in & Out Param
	         ,
	          p_tangibleid   => l_tangibleid --in & Out Param
	         ,
	          p_errorcode    => l_error_code --Out Param
	         ,
	          p_error        => l_error --Out Param
	          );
  
    IF l_error_code = 0 THEN
      RETURN l_so_header_id;
    ELSE
      RETURN - 1;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END get_so_header_id;
  ---------------------------------------------------------------
  --  name:               update_orb_trn_mapping
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to update so_header_id in table xxiby_orbital_order_mapping.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to update so_header_id in table xxiby_orbital_order_mapping.
  --  1.1   18/09/2019    Roman W         CHG0046328
  -----------------------------------------------------------------------
  PROCEDURE update_orb_trn_mapping(p_error_code OUT NUMBER,
		           p_error_desc OUT VARCHAR) IS
  BEGIN
  
    p_error_code := 0;
    p_error_desc := NULL;
  
    IF g_debug = 'Y' THEN
      print_message('Inside xxiby_process_cust_paymt_pkg.update_orb_trn_mapping ');
      print_message('Updating the SO Header ID in the xxiby_orbital_order_mapping Table');
    END IF;
  
    UPDATE oe_order_lines_all
    SET    attribute18 = NULL
    WHERE  header_id IN
           (SELECT get_so_header_id(order_id)
	FROM   xxiby_orbital_order_mapping
	WHERE  (so_header_id IS NULL OR so_header_id = -9999)
	AND    order_id NOT LIKE 'AR%') -- updated on 21-OCT-2016 to select 'ONT%' and eStore order
    AND    attribute18 IS NOT NULL
    AND    org_id = fnd_profile.value('ORG_ID'); --737 -- added on 19-OCT-2016
  
    UPDATE xxiby_orbital_order_mapping
    SET    so_header_id =
           (get_so_header_id(order_id))
    WHERE  (so_header_id IS NULL OR so_header_id = -9999)
    AND    order_id NOT LIKE 'AR%'; -- updated on 21-OCT-2016 to select 'ONT%' and eStore order
  
    print_message('EXIT xxiby_process_cust_paymt_pkg.update_orb_trn_mapping ');
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := substr('EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.update_orb_trn_mapping() - ' ||
		     SQLERRM,
		     1,
		     2000);
      print_message(p_error_desc);
    
  END update_orb_trn_mapping;
  ---------------------------------------------------------------
  --  name:               new_auth_orbital
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to call PlaceNewOrderServlet for new order creation in Orbital.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to call PlaceNewOrderServlet for new order creation in Orbital.
  --  1.1   25/09/2019    Roman W.        CHG0046328
  --  1.2   4.5.21        yuval tal       CHG0049588 - support oic : Credit Card Chase Payment - add data required for level 2 and 3
  -----------------------------------------------------------------------
  PROCEDURE new_auth_orbital(p_err_code     OUT NUMBER,
		     p_err_message  OUT VARCHAR2,
		     p_merchantid   IN VARCHAR2,
		     p_bin          IN VARCHAR2,
		     p_terminalid   IN VARCHAR2,
		     p_industrytype IN VARCHAR2,
		     p_pson         IN VARCHAR2,
		     p_auth_amount  IN NUMBER,
		     p_orb_token    IN VARCHAR2) IS
  
    --l_debug_mode BOOLEAN := TRUE;
    l_req             utl_http.req;
    l_resp            utl_http.resp;
    l_msg             VARCHAR2(500);
    l_entire_msg      VARCHAR2(32767) := NULL;
    l_url             VARCHAR2(500) := NULL;
    l_place_new_order xxiby_place_new_order_row_type := NULL;
  
    --
    --CHG0049588
    l_enable_flag VARCHAR2(1);
    l_wallet_loc  VARCHAR2(500);
    l_url2        VARCHAR2(500);
    l_wallet_pwd  VARCHAR2(500);
    l_auth_user   VARCHAR2(50);
    l_auth_pwd    VARCHAR2(50);
    l_req2        CLOB;
    l_resp2       CLOB;
  
    p_error_code         VARCHAR2(10);
    p_error_desc         VARCHAR2(2000);
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
  
  BEGIN
    p_err_code := 0;
  
    --- Debug --
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.request_json := 'p_merchantid    => ' ||
			       p_merchantid || ',' || chr(10) ||
			       'p_bin           => ' || p_bin || ',' ||
			       chr(10) || 'p_terminalid    => ' ||
			       p_terminalid || ',' || chr(10) ||
			       'p_industrytype  => ' ||
			       p_industrytype || ',' || chr(10) ||
			       'p_pson         => ' || p_pson || ',' ||
			       chr(10) || 'p_auth_amount  => ' ||
			       p_auth_amount || ',' || chr(10) ||
			       'p_orb_token    => ' ||
			       p_orb_token;
    
      l_xxiby_cc_debug_tbl.step        := '1';
      l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.new_auth_orbital';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_error_code,
	p_error_desc         => p_error_desc);
    END IF;
    -- CHG0049588
  
    xxssys_oic_util_pkg.get_service_details('CC_NEW_ORDER',
			        l_enable_flag,
			        l_url2,
			        l_wallet_loc,
			        l_wallet_pwd,
			        l_auth_user,
			        l_auth_pwd,
			        p_err_code,
			        p_err_message);
    IF l_enable_flag = 'Y' THEN
    
      l_req2 := '"ccNewOrderReq": {
        "header": {' || '
          "source"  : "EBS"' || ',
          "sourceId": "",
          "token": "",
          "bin": "",
          "merchantID": "",
          "terminalID":"",
          "user": "",
          "pass": ""
        },
        "newOrderDetailsReq": {"newOrderDetailsReq": {
        "orderID" : "' || p_pson || '",
        "transType": "' || 'A' || '",
        "customerRefNum": "' || TRIM(p_orb_token) || '",
        "amount": "' || p_auth_amount || '",
        "industryType":"' || p_industrytype || '" } } }';
    
      cc_new_order(p_req      => l_req2,
	       p_resp     => l_resp2,
	       p_err_code => p_err_code,
	       p_err_msg  => p_err_message);
      RETURN;
    END IF;
  
    -- end CHG0049588
  
    --
    print_message('inside new_auth_orbital Procedure, Going to Hit Orbital');
  
    IF p_pson IS NOT NULL AND p_auth_amount IS NOT NULL AND
       p_orb_token IS NOT NULL AND p_merchantid IS NOT NULL AND
       p_bin IS NOT NULL AND p_terminalid IS NOT NULL AND
       p_industrytype IS NOT NULL THEN
    
      l_url := fnd_profile.value('APPS_FRAMEWORK_AGENT') ||
	   '/OA_HTML/PlaceNewOrderServlet/?OapfOrderId=' || p_pson ||
	   '&&OapfPrice=' || p_auth_amount || '&&OapfPmtInstrID=' ||
	   p_orb_token || '&&merchantID=' || p_merchantid || '&&bin=' ||
	   p_bin || '&&terminalID=' || p_terminalid ||
	   '&&industryType=' || p_industrytype;
    
      print_message('Orbital_Existing_Order_ID(PSON): ' || p_pson);
      print_message('l_url: ' || l_url);
      l_req  := utl_http.begin_request(url => l_url, method => 'GET');
      l_resp := utl_http.get_response(r => l_req);
    
      IF g_debug = 'Y' THEN
        print_message('HTTP Status Return code: ' || l_resp.status_code);
      END IF;
    
      BEGIN
        LOOP
          utl_http.read_text(r => l_resp, data => l_msg, len => 500);
          l_entire_msg := substr(l_entire_msg || l_msg, 1, 32766);
        END LOOP;
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          NULL;
      END;
    
      utl_http.end_response(r => l_resp);
    
      get_xxiby_place_new_order_row(p_responce_clob   => to_clob(l_entire_msg),
			p_place_new_order => l_place_new_order,
			p_error_code      => p_err_code,
			p_error_desc      => p_err_message);
    
      IF 0 != p_err_code THEN
        RETURN;
      END IF;
    
    ELSE
      p_err_code    := 2;
      p_err_message := 'ERROR : some values in NEW AUTH URL is null, so URL not formed correctly';
      print_message(p_err_message);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.new_auth_orbital() - ' ||
	           SQLERRM;
    
      print_message(p_err_message);
    
  END new_auth_orbital;
  ---------------------------------------------------------------
  --  name:               cancel_void_orbital
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to call CreditCardTranxReversalServlet for void/reduce amount in Orbital.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to call CreditCardTranxReversalServlet for void/reduce amount in Orbital.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.2   29/09/2019    Roman W.        CHG0046328
  --  1.3   4.5.21        yuval tal       CHG0049588 - support oic : Credit Card Chase Payment - add data required for level 2 and 3
  -----------------------------------------------------------------------
  PROCEDURE cancel_void_orbital(p_err_code    OUT NUMBER,
		        p_err_message OUT VARCHAR2,
		        p_merchantid  IN VARCHAR2,
		        p_bin         IN VARCHAR2,
		        p_terminalid  IN VARCHAR2,
		        p_pson        IN VARCHAR2,
		        p_can_amount  IN NUMBER,
		        p_txrefnum    IN VARCHAR2) IS
  
    ---------------------------
    --    Local Definition
    ---------------------------
    l_req                 utl_http.req;
    l_resp                utl_http.resp;
    l_msg                 VARCHAR2(80);
    l_entire_msg          VARCHAR2(32767) := NULL;
    l_url                 VARCHAR2(500) := NULL;
    l_cc_tranx_revers_row xxiby_cc_tranx_revers_row_type;
  
    --CHG0049588
    l_enable_flag VARCHAR2(1);
    l_wallet_loc  VARCHAR2(500);
    l_url2        VARCHAR2(500);
    l_wallet_pwd  VARCHAR2(500);
    l_auth_user   VARCHAR2(50);
    l_auth_pwd    VARCHAR2(50);
    l_token       VARCHAR2(50);
    --
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
    -- CHG0049588
    --
    xxssys_oic_util_pkg.get_service_details2('CC_REVERSAL',
			         l_enable_flag,
			         l_url2,
			         l_wallet_loc,
			         l_wallet_pwd,
			         l_auth_user,
			         l_auth_pwd,
			         l_token,
			         p_err_code,
			         p_err_message);
    IF l_enable_flag = 'Y' THEN
      cc_reversal(p_merchantid    => p_merchantid,
	      p_bin           => p_bin,
	      p_terminalid    => p_terminalid,
	      p_pson          => p_pson,
	      p_cancel_amount => p_can_amount,
	      p_txrefnum      => p_txrefnum,
	      p_err_code      => p_err_code,
	      p_err_msg       => p_err_message);
      RETURN;
    END IF;
  
    --       end if ;-- end CHG0049588
    p_err_code    := 0;
    p_err_message := NULL;
    print_message('inside cancel_void_orbital');
  
    IF p_pson IS NOT NULL AND p_txrefnum IS NOT NULL AND
       p_can_amount IS NOT NULL AND p_merchantid IS NOT NULL AND
       p_bin IS NOT NULL AND p_terminalid IS NOT NULL THEN
      l_url := fnd_profile.value('APPS_FRAMEWORK_AGENT') ||
	   '/OA_HTML/CreditCardTranxReversalServlet/?OapfOrderId=' ||
	   p_pson || '&&OapfPrice=' || p_can_amount || '&&merchantID=' ||
	   p_merchantid || '&&bin=' || p_bin || '&&terminalID=' ||
	   p_terminalid || '&&trnsRefNo=' || p_txrefnum;
    
      print_message('Orbital_Order_ID(PSON): ' || p_pson);
      print_message('URL : ' || l_url);
    
      l_req  := utl_http.begin_request(url => l_url, method => 'GET');
      l_resp := utl_http.get_response(r => l_req);
    
      IF g_debug = 'Y' THEN
        print_message('HTTP Status Return code: ' || l_resp.status_code);
      END IF;
    
      BEGIN
        LOOP
          utl_http.read_text(r => l_resp, data => l_msg);
          l_entire_msg := l_entire_msg || l_msg;
        END LOOP;
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          NULL;
      END;
    
      utl_http.end_response(r => l_resp);
    
      get_creditcardtranxrevers_row(p_responce_clob => to_clob(l_entire_msg),
			p_out_row       => l_cc_tranx_revers_row,
			p_error_code    => p_err_code,
			p_error_desc    => p_err_message);
    
    ELSE
      p_err_code    := 2;
      p_err_message := substr('WARNING xxiby_process_cust_paymt_pkg.cancel_void_orbital( ' ||
		      p_merchantid || ',' || p_bin || ',' ||
		      p_terminalid || ',' || p_pson || ',' ||
		      p_can_amount || ',' || p_txrefnum ||
		      ') - some values in CANCEL URL is null, so URL not formed correctly',
		      1,
		      2000);
      print_message(p_err_message);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := substr('EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.cancel_void_orbital(' ||
		      p_merchantid || ',' || p_bin || ',' ||
		      p_terminalid || ',' || p_pson || ',' ||
		      p_can_amount || ',' || p_txrefnum || ') - ' ||
		      fnd_message.get || ' ' || SQLERRM,
		      1,
		      2000);
    
      print_message(p_err_message);
  END cancel_void_orbital;
  ---------------------------------------------------------------
  --  name:               cancel_full_orbital_so
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to handle Cancel Full Order cases for Orbital.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to handle Cancel Full Order cases for Orbital.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.2   02/10/2019    Roman W.        CHG0046328 - added error handling after call to cancel_void_orbital
  -----------------------------------------------------------------------
  PROCEDURE cancel_full_orbital_so(p_error_code OUT NUMBER,
		           p_error_desc OUT VARCHAR) IS
  
    -------------------------------
    --    Local Definition
    -------------------------------
    CURSOR cur_full_ord_cancel IS
      SELECT pts.tangibleid,
	 xoom.txrefnum,
	 oh.header_id,
	 pts.amount,
	 oh.order_number
      FROM   oe_order_headers_all        oh,
	 xxiby_orbital_order_mapping xoom,
	 iby_trxn_summaries_all      pts
      WHERE  xoom.is_full_ord_can IS NULL
      AND    nvl(xoom.so_header_id, 0) > 0
      AND    oh.header_id = xoom.so_header_id
      AND    pts.tangibleid = xoom.order_id
      AND    oh.flow_status_code IN ('CANCELLED')
      AND    oh.org_id = fnd_profile.value('ORG_ID') --737
      AND    nvl(oh.cancelled_flag, 'N') = 'Y'
      AND    pts.status = 0
      AND    pts.reqtype = 'ORAPMTREQ';
  
    l_errcode NUMBER;
    l_errmsg  VARCHAR2(2000);
    -------------------------------
    --      Code Section
    -------------------------------
  BEGIN
  
    p_error_code := 0;
    p_error_desc := NULL;
    l_errcode    := 0;
    l_errmsg     := NULL;
  
    IF g_debug = 'Y' THEN
      print_message('');
      print_message(' Inside cancel_full_orbital_SO');
    END IF;
  
    --Find the SO, for which at least One Line is Closed
    -- Update the Flag to 'No', No Action required for Full Order Cancel
    UPDATE xxiby_orbital_order_mapping
    SET    is_full_ord_can = 'N'
    WHERE  so_header_id IN
           (SELECT DISTINCT xoom.so_header_id
	FROM   oe_order_headers_all        oh,
	       oe_order_lines_all          ol,
	       xxiby_orbital_order_mapping xoom
	WHERE  xoom.is_full_ord_can IS NULL
	AND    nvl(xoom.so_header_id, 0) > 0
	AND    oh.header_id = xoom.so_header_id
	AND    oh.header_id = ol.header_id
	AND    oh.org_id = fnd_profile.value('ORG_ID') --737
	AND    ol.flow_status_code IN ('CLOSED', 'SHIPPED') -- We Can add SHIP Status also
	);
  
    FOR rec IN cur_full_ord_cancel
    LOOP
      print_message('order_number/amount:' || rec.order_number || '/' ||
	        rec.amount);
      cancel_void_orbital(p_err_code    => l_errcode,
		  p_err_message => l_errmsg,
		  p_merchantid  => g_merchantid,
		  p_bin         => g_bin,
		  p_terminalid  => g_terminalid,
		  p_pson        => rec.tangibleid,
		  p_can_amount  => rec.amount,
		  p_txrefnum    => rec.txrefnum);
    
      IF l_errcode = 0 THEN
        UPDATE xxiby_orbital_order_mapping
        SET    is_full_ord_can       = 'Y',
	   last_cancel_date_time = SYSDATE
        WHERE  order_id = rec.tangibleid
        AND    so_header_id = rec.header_id;
      
        UPDATE oe_order_lines_all
        SET    attribute18 = 'Y' /*  Full Order Cancelled , Marking allLines Processed , No furthur Processing required */
        WHERE  header_id = rec.header_id;
      ELSE
        p_error_code := greatest(p_error_code, l_errcode);
        p_error_desc := substr(p_error_desc || ' , ' || l_errmsg, 1, 2000);
        print_message(l_errmsg);
      END IF;
    
    END LOOP;
  
    IF g_debug = 'Y' THEN
      print_message(' EXIT cancel_full_orbital_SO');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := substr('EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.cancel_full_orbital_so() - ' ||
		     SQLERRM,
		     1,
		     2000);
      print_message(p_error_desc);
    
  END cancel_full_orbital_so;
  --------------------------------------------------------------------------------------------------------------------
  --  name:               cancel_partial_orbital_so
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to handle Cancel Partial Order cases for Orbital.
  --------------------------------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to handle Cancel Partial Order cases for Orbital.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  ---------------------------------------------------------------------------------------------------------------------
  PROCEDURE cancel_partial_orbital_so(p_error_code OUT NUMBER,
			  p_error_desc OUT VARCHAR2) IS
    ------------------------------
    --     Local Definitiion
    ------------------------------
    CURSOR cur_partial_ord_cancel IS
      SELECT tangibleid,
	 txrefnum,
	 header_id,
	 order_number,
	 firstshipment,
	 SUM(canceled_amount) amount
      FROM   (SELECT xoom.order_id tangibleid,
	         xoom.txrefnum,
	         oh.header_id,
	         oh.order_number,
	         ((ol.cancelled_quantity * ol.unit_selling_price) +
	         (ol.tax_value)) canceled_amount,
	         (SELECT COUNT(1)
	          FROM   iby_trxn_summaries_all
	          WHERE  tangibleid = xoom.order_id
	          AND    org_id = fnd_profile.value('ORG_ID') --737
	          AND    status = 0
	          AND    reqtype = 'ORAPMTCAPTURE') firstshipment
	  FROM   xxiby_orbital_order_mapping xoom,
	         oe_order_headers_all        oh,
	         oe_order_lines_all          ol
	  WHERE  1 = 1
	  AND    oh.header_id = ol.header_id
	  AND    nvl(xoom.so_header_id, 0) = oh.header_id
	  AND    oh.flow_status_code <> 'CLOSED' -- remark for test 02/10/2019
	  AND    oh.org_id = fnd_profile.value('ORG_ID') --737
	  AND    nvl(ol.cancelled_flag, 'N') = 'Y' -- remark for test 02/10/2019
	  AND    nvl(ol.attribute18, 'N') = 'N' -- Not processed For Orbital process
	  )
      GROUP  BY tangibleid,
	    txrefnum,
	    header_id,
	    order_number,
	    firstshipment;
  
    l_error_code NUMBER;
    l_error_desc VARCHAR2(2000);
    ------------------------------
    --     Code Section
    ------------------------------
  BEGIN
  
    p_error_code := 0;
    p_error_desc := NULL;
  
    IF g_debug = 'Y' THEN
      print_message('');
      print_message(' Inside cancel_partial_orbital_so');
    END IF;
    --Select TANGIBLEID,TXREFNUM,header_id , FirstShipment , sum(Canceled_Amount)  Canceled_Amount
    FOR rec IN cur_partial_ord_cancel
    LOOP
    
      IF rec.firstshipment = 0 THEN
        -- remark for test 02/10/2019
        print_message('order_number/amount:' || rec.order_number || '/' ||
	          rec.amount);
      
        cancel_void_orbital(p_err_code    => l_error_code,
		    p_err_message => l_error_desc,
		    p_merchantid  => g_merchantid,
		    p_bin         => g_bin,
		    p_terminalid  => g_terminalid,
		    p_pson        => rec.tangibleid,
		    p_can_amount  => rec.amount,
		    p_txrefnum    => rec.txrefnum);
      
        IF l_error_code = 0 THEN
          UPDATE xxiby_orbital_order_mapping
          SET    last_cancel_date_time = SYSDATE,
	     is_full_ord_can       = 'N'
          WHERE  order_id = rec.tangibleid
          AND    so_header_id = rec.header_id;
        
          UPDATE oe_order_lines_all
          SET    attribute18 = 'Y' -- Cancelled Line Value revered in orbital
          WHERE  header_id = rec.header_id
          AND    nvl(attribute18, 'N') = 'N' -- not Processed for Orbital cancellation
          AND    nvl(cancelled_flag, 'N') = 'Y'; -- Cancelled Line
        ELSE
          p_error_code := l_error_code;
          p_error_desc := substr(p_error_desc || chr(10) || l_error_desc,
		         1,
		         2000);
          print_message(l_error_desc);
        END IF;
      
      END IF; -- remark for test 02/10/2019
    END LOOP;
  
    IF g_debug = 'Y' THEN
      print_message(' EXIT cancel_partial_orbital_so');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := substr('EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.cancel_partial_orbital_so() - ' ||
		     SQLERRM,
		     1,
		     2000);
      print_message(p_error_desc);
    
  END cancel_partial_orbital_so;
  ---------------------------------------------------------------
  --  name:               split_void_new_orbital_auth
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to handle Split Shipment cases for Orbital.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to handle Split Shipment cases for Orbital.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  -----------------------------------------------------------------------
  PROCEDURE split_void_new_orbital_auth(p_error_code OUT VARCHAR2,
			    p_error_desc OUT VARCHAR2) IS
    --------------------------------
    --     Local Definition
    --------------------------------
    CURSOR cur_split_ord_cancel IS
      SELECT xoom.order_id tangibleid,
	 xoom.txrefnum,
	 nvl(xoom.split_void_flag, 'N') split_void_flag,
	 xoom.orbital_token,
	 oh.header_id,
	 oh.order_number,
	 (SELECT COUNT(1)
	  FROM   iby_trxn_summaries_all
	  WHERE  tangibleid = xoom.order_id
	  AND    org_id = fnd_profile.value('ORG_ID') --737
	  AND    status = 0
	  AND    reqtype = 'ORAPMTCAPTURE') firstshipment,
	 (SELECT SUM(amount)
	  FROM   iby_trxn_summaries_all
	  WHERE  tangibleid = xoom.order_id
	  AND    org_id = fnd_profile.value('ORG_ID') --737
	  AND    status = 0
	  AND    reqtype = 'ORAPMTCAPTURE') firstshipmentvalue
      FROM   xxiby_orbital_order_mapping xoom,
	 oe_order_headers_all        oh
      WHERE  1 = 1
      AND    nvl(xoom.so_header_id, 0) = oh.header_id
	--AND    oh.flow_status_code <> 'CLOSED' /*Commented on 22SEP2016 , Orders Which are closed, should be considered*/
      AND    oh.org_id = fnd_profile.value('ORG_ID') --737
      AND    nvl(xoom.is_full_ord_process, 'N') = 'N'; -- SO Not Fully processed yet
  
    CURSOR cur_order_line(v_header_id NUMBER) IS
      SELECT ol.line_id,
	 ol.flow_status_code,
	 (CASE nvl(ol.cancelled_flag, 'N')
	   WHEN 'Y' THEN
	    ((nvl(ol.cancelled_quantity, 0) *
	    nvl(ol.unit_selling_price, 0)) + (nvl(ol.tax_value, 0)))
	   ELSE
	    ((nvl(ol.ordered_quantity, 0) *
	    nvl(ol.unit_selling_price, 0)) + (nvl(ol.tax_value, 0)))
	 END) amount
      FROM   oe_order_headers_all oh,
	 oe_order_lines_all   ol
      WHERE  oh.header_id = v_header_id
      AND    ol.header_id = oh.header_id
      AND    oh.org_id = fnd_profile.value('ORG_ID') --737
      AND    nvl(ol.attribute18, 'N') = 'N'; --Not processed for Orbital
  
    CURSOR cur_order_line_reduce(v_header_id NUMBER) IS
      SELECT ol.line_id,
	 ol.flow_status_code,
	 (CASE nvl(ol.cancelled_flag, 'N')
	   WHEN 'Y' THEN
	    ((nvl(ol.cancelled_quantity, 0) *
	    nvl(ol.unit_selling_price, 0)) + (nvl(ol.tax_value, 0)))
	   ELSE
	    ((nvl(ol.ordered_quantity, 0) *
	    nvl(ol.unit_selling_price, 0)) + (nvl(ol.tax_value, 0)))
	 END) amount
      FROM   oe_order_headers_all oh,
	 oe_order_lines_all   ol
      WHERE  oh.header_id = v_header_id
      AND    ol.header_id = oh.header_id
      AND    oh.org_id = fnd_profile.value('ORG_ID') --737
      AND    ol.flow_status_code IN ('CLOSED', 'CANCELLED')
      AND    nvl(ol.attribute18, 'N') = 'S'; -- will give lines which need to processed after first shipment for voiding remaining amount
  
    l_errcode           NUMBER;
    l_errmsg            VARCHAR2(2000);
    l_void_amt          NUMBER := 0;
    l_reduce_amt        NUMBER := 0;
    l_line_amt          NUMBER := 0;
    l_new_auth_amt      NUMBER := 0;
    l_is_line_rec_found VARCHAR2(1);
    l_line_pson_remited VARCHAR2(20);
    l_line_amt_ont      NUMBER := 0; /*28-SEP-2016 addition*/
    --------------------------------
    --     Code Section
    --------------------------------
  BEGIN
  
    p_error_code := 0;
    p_error_desc := NULL;
    l_errcode    := 0;
    l_errmsg     := NULL;
  
    print_message(' Inside split_void_new_orbital_auth PROCEDURE');
  
    FOR rec IN cur_split_ord_cancel
    LOOP
      l_void_amt          := 0;
      l_new_auth_amt      := 0;
      l_line_pson_remited := NULL;
      l_line_amt_ont      := 0; /*28-SEP-2016 addition*/
      l_reduce_amt        := 0; /*04-OCT-2016 addition*/
    
      IF rec.firstshipment > 0 AND rec.split_void_flag = 'N' THEN
        l_is_line_rec_found := 'N'; /* 22SEP16 Variable to Check is there any record found to Process in the Order Line*/
        l_line_amt          := 0; /* 22SEP16*/
      
        IF g_debug = 'Y' THEN
          print_message('');
          print_message('------------------------------------------------------------------------');
          print_message('order_number[This is a First Shipment Split Case]:' ||
		rec.order_number);
        END IF;
      
        -- How Much amount need to Cancel
      
        FOR rec1 IN cur_order_line(rec.header_id)
        LOOP
          print_message(' Line Id / Line Total Amount : ' || rec1.line_id || '/' ||
		rec1.amount);
          l_line_amt          := rec1.amount;
          l_is_line_rec_found := 'Y';
          l_line_pson_remited := NULL;
        
          UPDATE oe_order_lines_all
          SET    attribute18 = 'P' -- In Process
          WHERE  line_id = rec1.line_id;
        
          IF rec1.flow_status_code = 'CLOSED' THEN
	l_line_pson_remited := get_line_pson(rec1.line_id); /*22SEP16 Get the PSON number if the Line is remited*/
	print_message(' Remitted Line(closed status) PSON : ' ||
		  l_line_pson_remited);
	IF rec1.amount = 0 THEN
	  /*22SEP16 IF any line amount is zero and Closed , then no need to consider for VOID and AUTH */
	  UPDATE oe_order_lines_all
	  SET    attribute18 = 'Y'
	  WHERE  line_id = rec1.line_id;
	  -- Find is the Capture is available for this Line
	  -- if Capture found -- will not Consider for new Auth
	  --ELSIF get_line_remitted_flag(rec1.line_id) = 'N' THEN /*22SEP16 COMMNTED*/
	ELSIF l_line_pson_remited IS NULL THEN
	  l_void_amt     := l_void_amt + l_line_amt;
	  l_new_auth_amt := l_new_auth_amt + l_line_amt;
	  -- ELSIF get_line_remitted_flag(rec1.line_id) = 'Y' THEN /*22SEP16 commented*/
	ELSIF l_line_pson_remited IS NOT NULL THEN
	  UPDATE oe_order_lines_all
	  SET    attribute18 = 'Y' -- Line already Remitted, no need to consider for next run
	  WHERE  line_id = rec1.line_id;
	
	  IF l_line_pson_remited LIKE 'AR%' THEN
	    -- as 2nd shipmemt onwards with PSON will be 'AR%', so add line_amount with total_void_amount.
	    l_void_amt := l_void_amt + l_line_amt;
	  ELSIF l_line_pson_remited NOT LIKE 'AR%' THEN
	    -- updated on 21-OCT-2016 to select 'ONT%' and eStore order
	    l_line_amt_ont := l_line_amt_ont + l_line_amt; /*28-SEP-2016 addition*/
	  END IF;
	
	END IF;
          
          ELSIF rec1.flow_status_code = 'CANCELLED' THEN
	l_void_amt := l_void_amt + l_line_amt;
          
	UPDATE oe_order_lines_all
	SET    attribute18 = 'Y' -- Line already Cancelled, no need to consider next run
	WHERE  line_id = rec1.line_id;
          ELSE
	l_void_amt     := l_void_amt + l_line_amt;
	l_new_auth_amt := l_new_auth_amt + l_line_amt;
          END IF;
        END LOOP; -- Line Loop
      
        IF l_is_line_rec_found = 'Y' THEN
          /*22SEP16 IF any record found for Process then Only do Void an New Auth*/
          IF l_void_amt <> 0 THEN
	l_void_amt := (l_void_amt -
		  (rec.firstshipmentvalue - nvl(l_line_amt_ont, 0))); /*28-SEP-2016 addition for Extra Charges calculation*/
	--Call Void Program
	IF g_debug = 'Y' THEN
	  print_message('1st Shipment value/Total ONT line amount without Charges:' ||
		    rec.firstshipmentvalue || '/' ||
		    nvl(l_line_amt_ont, 0)); /*28-SEP-2016 addition*/
	  print_message('Split void amount:' || l_void_amt);
	  print_message('        =>going to call cancel_void_orbital');
	END IF;
	cancel_void_orbital(p_err_code    => l_errcode,
		        p_err_message => l_errmsg,
		        p_merchantid  => g_merchantid,
		        p_bin         => g_bin,
		        p_terminalid  => g_terminalid,
		        p_pson        => rec.tangibleid,
		        p_can_amount  => l_void_amt,
		        p_txrefnum    => rec.txrefnum);
          
	-- Addd by Roman W. 02/10/2019 --
	IF 0 != l_errcode THEN
	  p_error_code := greatest(p_error_code, l_errcode);
	  p_error_desc := substr(p_error_desc || ' , ' || l_errmsg,
			 1,
			 2000);
	  print_message(l_errcode);
	END IF;
          END IF;
        
          --After Void program sucessfully executed , create new Auth
          IF l_new_auth_amt <> 0 THEN
	--NULL;
	--Call New Auth Program
	IF g_debug = 'Y' THEN
	  print_message('New Auth amount:' || l_new_auth_amt);
	  print_message('           =>going to call new_auth_orbital');
	END IF;
          
	COMMIT; /*During New Auth update xxiby_orbital_order_mapping from JAVA servlet call, so committing all previous transaction in this table. To avoid below error:*/
	/*SQl ERROR:ORA-29273: HTTP request failed
            ORA-06512: at "SYS.UTL_HTTP", line 1369
            ORA-29276: transfer timeout*/
          
	new_auth_orbital(p_err_code     => l_errcode,
		     p_err_message  => l_errmsg,
		     p_merchantid   => g_merchantid,
		     p_bin          => g_bin,
		     p_terminalid   => g_terminalid,
		     p_industrytype => g_industrytype,
		     p_pson         => rec.tangibleid,
		     p_auth_amount  => l_new_auth_amt,
		     p_orb_token    => rec.orbital_token);
          
	IF 0 != l_errcode THEN
	  p_error_code := greatest(p_error_code, l_errcode);
	  p_error_desc := substr(p_error_desc || ' , ' || l_errmsg,
			 1,
			 2000);
	  print_message(l_errmsg);
	ELSE
	  -- updating split_void_flag to 'Y' in xxiby_orbital_order_mapping
	  UPDATE xxiby_orbital_order_mapping
	  SET    split_void_flag = 'Y'
	  WHERE  order_id = rec.tangibleid
	  AND    so_header_id = rec.header_id;
	
	END IF;
          
          ELSIF l_new_auth_amt = 0 THEN
	UPDATE xxiby_orbital_order_mapping
	SET    is_full_ord_can     = 'N',
	       is_full_ord_process = 'Y'
	WHERE  order_id = rec.tangibleid
	AND    so_header_id = rec.header_id;
          
          END IF;
        
          UPDATE oe_order_lines_all
          SET    attribute18 = 'S' -- Split line, need to consider next run
          WHERE  header_id = rec.header_id
          AND    nvl(attribute18, 'N') = 'P';
        END IF; --l_is_line_rec_found Check end
      
        --------------Case 3.2 Already Split Cases, Marked in the Table----------------------------------------------------------------------
      ELSIF rec.split_void_flag = 'Y' THEN
        IF g_debug = 'Y' THEN
          print_message('');
          print_message('------------------------------------------------------------------------');
          print_message('order_number[This is a already Splitted Case, need to reduce Auth amount only]:' ||
		rec.order_number);
          print_message('Reduction Only part');
        END IF;
      
        l_is_line_rec_found := 'N';
        l_line_pson_remited := NULL; /*22SEP16*/
        l_line_amt          := 0; /*22SEP16*/
        l_reduce_amt        := 0; /*04-OCT-2016 addition*/
        -- Calculate and Do the Reduction Only
        ---------------------------------------------------
        FOR rec2 IN cur_order_line_reduce(rec.header_id)
        LOOP
          l_is_line_rec_found := 'Y';
          l_line_pson_remited := NULL; /*22SEP16*/
        
          /*IF g_debug = 'Y' THEN
            print_message('Reduction Only part');
            print_message('order_number:' || rec.order_number);
          END IF;*/
        
          l_line_amt := rec2.amount;
        
          IF rec2.flow_status_code = 'CLOSED' THEN
	l_line_pson_remited := get_line_pson(rec2.line_id); /*22SEP16 If only the Line is remited function will return the PSON number*/
          
	IF rec2.amount = 0 THEN
	  /*22SEP16 IF any line amount is zero and Closed , then no need to consider for VOID and AUTH */
	  UPDATE oe_order_lines_all
	  SET    attribute18 = 'Y'
	  WHERE  line_id = rec2.line_id;
	  --            IF get_line_remitted_flag(rec2.line_id) = 'Y' THEN /*22SEP16 COMMENTED */
	ELSIF l_line_pson_remited IS NOT NULL THEN
	  l_reduce_amt := l_reduce_amt + l_line_amt;
	
	  UPDATE oe_order_lines_all
	  SET    attribute18 = 'Y' -- Line already Remitted, no need to consider next run
	  WHERE  line_id = rec2.line_id;
	
	END IF;
          
          ELSIF rec2.flow_status_code = 'CANCELLED' THEN
	l_reduce_amt := l_reduce_amt + l_line_amt;
          
	UPDATE oe_order_lines_all
	SET    attribute18 = 'Y' -- Line already Cancelled, no need to consider next run
	WHERE  line_id = rec2.line_id;
          
          END IF;
        END LOOP; -- Line Loop
      
        IF l_reduce_amt <> 0 THEN
          --NULL;
          --Call Void Program
          print_message('Reduce void amount:' || l_reduce_amt);
          print_message('           =>going to call cancel_void_orbital after 1st shipment');
          cancel_void_orbital(p_err_code    => l_errcode,
		      p_err_message => l_errmsg,
		      p_merchantid  => g_merchantid,
		      p_bin         => g_bin,
		      p_terminalid  => g_terminalid,
		      p_pson        => rec.tangibleid,
		      p_can_amount  => l_reduce_amt,
		      p_txrefnum    => rec.txrefnum);
        
          IF 0 != l_errcode THEN
          
	p_error_code := greatest(p_error_code, l_errcode);
	p_error_desc := substr(p_error_desc || ' , ' || l_errmsg,
		           1,
		           2000);
	print_message(l_errmsg);
          END IF;
        END IF;
      
        --After Void program sucessfully executed , no need to create new Auth
      
        --COMMIT; -- commented out on 20-sep-2016
        --------------------
      END IF;
    
    END LOOP;
  
    print_message(' EXIT split_void_new_orbital_auth');
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := substr('EXCEPTION_OTHER xxiby_process_cust_paymt_pkg.split_void_new_orbital_auth() - ' ||
		     SQLERRM,
		     1,
		     2000);
      print_message(p_error_desc);
    
  END split_void_new_orbital_auth;
  ---------------------------------------------------------------
  --  name:               main
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to call Full Cancel, Partial Cancel and Split Shipment processes.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to call Full Cancel, Partial Cancel and Split Shipment processes.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.2   02/10/2019    Roman W.        CHG0046328 - added wrinting to conurrent log
  -----------------------------------------------------------------------
  --Main Program Called by Scheduler
  PROCEDURE main(p_errorcode OUT NUMBER,
	     p_error     OUT VARCHAR2) IS
    ----------------------------
    --     Code Section
    ----------------------------
    l_error_code NUMBER;
    l_error_desc VARCHAR2(2000);
    ----------------------------
    --     Local Definition
    ----------------------------
  BEGIN
  
    p_errorcode  := 0;
    p_error      := NULL;
    l_error_code := 0;
    l_error_desc := NULL;
  
    print_message('START(1) : xxiby_process_cust_paymt_pkg.main');
  
    g_merchantid   := get_merchantid;
    g_bin          := get_binvalue;
    g_terminalid   := get_terminalid;
    g_industrytype := get_industrytype;
  
    --Update the 'xxiby_orbital_order_mapping' Table where SO Header Id is not available
    print_message('--------------------------------------------------------------');
    print_message('START(2) : xxiby_process_cust_paymt_pkg.update_orb_trn_mapping');
    print_message('--------------------------------------------------------------');
  
    update_orb_trn_mapping(l_error_code, l_error_desc);
  
    IF 0 != l_error_code THEN
      p_errorcode := greatest(p_errorcode, l_error_code);
      p_error     := l_error_desc;
    END IF;
  
    --#CASE 01 : Full Order cancellation in Orbital
    l_error_code := 0;
    l_error_desc := NULL;
  
    print_message('--------------------------------------------------------------');
    print_message('START(3) : xxiby_process_cust_paymt_pkg.cancel_full_orbital_so');
    print_message('--------------------------------------------------------------');
  
    cancel_full_orbital_so(l_error_code, l_error_desc);
  
    IF l_error_code != 0 THEN
      p_errorcode := greatest(p_errorcode, l_error_code);
      p_error     := l_error_desc;
    END IF;
  
    --#CASE 02 :
    /*
      SO Booked.
      One or Multiple Line Cancelled.
      One or Multiple Line Shipped.
      But No Capture Found for ONT Tangableid in  "iby_trxn_summaries_all"
    */
    l_error_code := 0;
    l_error_desc := NULL;
  
    print_message('-----------------------------------------------------------------');
    print_message('START(4) : xxiby_process_cust_paymt_pkg.cancel_partial_orbital_so');
    print_message('-----------------------------------------------------------------');
  
    cancel_partial_orbital_so(l_error_code, l_error_desc);
    print_message('afer cancel_partial_orbital_so');
    print_message('l_error_code ' || l_error_code);
    print_message('l_error_desc ' || l_error_desc);
    IF l_error_code != 0 THEN
      p_errorcode := greatest(p_errorcode, l_error_code);
      p_error     := l_error_desc;
    END IF;
    print_message('afer l_error_code');
    -- #CASE 03 : If the SO having a 1st capture, then Void the Record and create a new Auth
    -- 3.1 : After the Split Void the split amount and Create a new Auth
    -- 3.2 : If the Split amount is already voided and created a new Auth, then for the Future Cnacelled and remited Lines , reduce the amount from the New auth amount in Step 3.1
  
    print_message('-------------------------------------------------------------------');
    print_message('START(5) : xxiby_process_cust_paymt_pkg.split_void_new_orbital_auth');
    print_message('-------------------------------------------------------------------');
  
    split_void_new_orbital_auth(l_error_code, l_error_desc); --CHG0046328
  
    IF l_error_code != 0 THEN
      p_errorcode := greatest(p_errorcode, l_error_code);
      p_error     := l_error_desc;
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      p_errorcode := 2;
      p_error     := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.main() - ' ||
	         SQLERRM;
    
      print_message(p_error);
    
  END main;
  ---------------------------------------------------------------
  --  name:               insert_orb_trn_mapping
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to insert data reated to orbital.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to insert data reated to orbital.It is called from Java Servlet.
  --  1.1   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  --  1.2   26/04/2021    Roman W.        CHG0049588 - cc
  --  2.0   07/06/2021    Roman W.
  -----------------------------------------------------------------------
  PROCEDURE insert_orb_trn_mapping(p_ordernumber              IN VARCHAR2, --PSON Number
		           p_trnrefnum                IN VARCHAR2, --40 Digit Transaction Number
		           p_orbital_token            IN VARCHAR2, -- Token or Orbital Profile Number,not 16 Digit
		           p_ctilevel3eligible        IN VARCHAR2 DEFAULT NULL, -- CHG0049588
		           p_cardbrand                IN VARCHAR2 DEFAULT NULL, -- CHG0049588
		           p_mitreceivedtransactionid IN VARCHAR2 DEFAULT NULL, -- CHG0049588
		           p_err_code                 OUT NUMBER,
		           p_err_message              OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    /* l_ordernumber    VARCHAR2(50);
    l_trnrefnumber   VARCHAR2(100);
    l_orbital_token  VARCHAR2(16);
    l_so_header_id   NUMBER := NULL;
    l_error_code     NUMBER;
    l_error          VARCHAR2(1000);*/
    l_order_id_count NUMBER := NULL;
  BEGIN
    p_err_code := 0;
    SELECT COUNT(1)
    INTO   l_order_id_count
    FROM   apps.xxiby_orbital_order_mapping
    WHERE  order_id = p_ordernumber;
  
    IF l_order_id_count > 0 THEN
      -- updating txrefnum for existing order_id
      UPDATE apps.xxiby_orbital_order_mapping xoom
      SET    xoom.txrefnum                 = p_trnrefnum,
	 xoom.last_update_date         = SYSDATE,
	 xoom.ctilevel3eligible        = nvl(p_ctilevel3eligible,
				 xoom.ctilevel3eligible), -- CHG0049588
	 xoom.cardbrand                = nvl(p_cardbrand, xoom.cardbrand), -- CHG0049588
	 xoom.mitreceivedtransactionid = nvl(p_mitreceivedtransactionid,
				 xoom.mitreceivedtransactionid) -- CHG0049588
      WHERE  order_id = p_ordernumber;
    
    ELSE
      -- inserting new record in xxiby_orbital_order_mapping
    
      INSERT INTO apps.xxiby_orbital_order_mapping
        (order_id,
         txrefnum,
         orbital_token,
         --  so_header_id,
         split_void_flag,
         --------------------------------
         ctilevel3eligible, -- CHG0049588
         cardbrand, -- CHG0049588
         mitreceivedtransactionid, -- CHG0049588
         --------------------------------
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login)
      VALUES
        (p_ordernumber,
         p_trnrefnum,
         p_orbital_token,
         --         l_so_header_id,
         'N',
         --------------------------------
         p_ctilevel3eligible, -- CHG0049588
         p_cardbrand, -- CHG0049588
         p_mitreceivedtransactionid, -- CHG0049588
         --------------------------------
         SYSDATE,
         -1,
         SYSDATE,
         -1,
         -1);
    
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.insert_orb_trn_mapping(' ||
	           p_ordernumber || ',' || p_trnrefnum || ',' ||
	           p_orbital_token || ',' || p_ctilevel3eligible ||
	           ') - ' || SQLERRM;
      message(p_err_message);
  END insert_orb_trn_mapping;

  ---------------------------------------------------------------
  --  name:               get_orb_req_param
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to fetch orbital related data.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to fetch orbital related data.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_req_param(p_tangibleid  IN VARCHAR2,
		      p_option_det  OUT SYS_REFCURSOR,
		      p_err_code    OUT NUMBER,
		      p_err_message OUT VARCHAR2) IS
  
    l_tangibleid VARCHAR2(20);
    l_option_det SYS_REFCURSOR;
    no_data_found EXCEPTION;
  
  BEGIN
    l_tangibleid := p_tangibleid;
  
    OPEN l_option_det FOR
      SELECT ibaov.account_option_code,
	 ibaov.account_option_value
      FROM   apps.iby_bepinfo info,
	 apps.iby_bep_acct_opt_vals ibaov,
	 apps.iby_bepkeys keys,
	 (SELECT DISTINCT itsa.payeeid
	  FROM   apps.iby_trxn_summaries_all itsa
	  WHERE  itsa.tangibleid = l_tangibleid) summall
      WHERE  summall.payeeid = keys.ownerid
      AND    keys.bepid = info.bepid
      AND    info.bepid = ibaov.bepid
      AND    keys.ownertype = 'PAYEE'
      AND    info.activestatus = 'Y';
  
    IF l_option_det%NOTFOUND THEN
      RAISE no_data_found;
    END IF;
  
    p_option_det := l_option_det;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
    
  END get_orb_req_param;
  ---------------------------------------------------------------
  --  name:               get_masked_ccnumber
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Get Masked CC Number
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to fetch orbital related data.
  -----------------------------------------------------------------------
  FUNCTION get_masked_ccnumber(p_instrument_id NUMBER) RETURN VARCHAR2 IS
    l_masked_cc_number VARCHAR2(16);
  BEGIN
    SELECT 'XXXXXXXXXXXX' || attribute1
    INTO   l_masked_cc_number
    FROM   iby_creditcard
    WHERE  instrid = p_instrument_id
    AND    nvl(attribute1, '-999') <> '-999';
  
    RETURN l_masked_cc_number;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '';
  END get_masked_ccnumber;
  ---------------------------------------------------------------
  --  name:               get_ibycc_attr2
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Get attribute2 from iby_creditcard.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Get attribute2 from iby_creditcard.
  -----------------------------------------------------------------------
  FUNCTION get_ibycc_attr2(p_instrument_id NUMBER) RETURN VARCHAR2 IS
    l_attribute2 VARCHAR2(100);
  BEGIN
    SELECT attribute2
    INTO   l_attribute2
    FROM   iby_creditcard
    WHERE  instrid = p_instrument_id;
  
    RETURN l_attribute2;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_ibycc_attr2;
  ---------------------------------------------------------------
  --  name:               send_smtp_mail
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      31/08/2016
  --  Purpose :           CHG0031464 - Procedure to send mail using SMTP.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/2016    Sujoy Das       CHG0031464 - Procedure to send mail using SMTP.
  --  1.1   05.06.2017    Lingaraj(TCS)   INC0094556 - Error when sending CC receipt
  --  1.2   20/Sep/2018   Dan Melamed     CHG0043983 - Close connections on exception
  --  1.3   06/02/2020    Roman W.        CHG0046663 - CHG0047311 - Change the email sending approach
  --                                           through PLSQL from on premises "smtp.stratasys.com"
  --                                           to cloud based "stratasysinc.mail.protection.outlook.com"
  -----------------------------------------------------------------------
  PROCEDURE send_smtp_mail(p_msg_to        IN VARCHAR2,
		   p_msg_from      IN VARCHAR2,
		   p_msg_to1       IN VARCHAR2 DEFAULT NULL,
		   p_msg_to2       IN VARCHAR2 DEFAULT NULL,
		   p_msg_to3       IN VARCHAR2 DEFAULT NULL,
		   p_msg_to4       IN VARCHAR2 DEFAULT NULL,
		   p_msg_to5       IN VARCHAR2 DEFAULT NULL,
		   p_msg_subject   IN VARCHAR2,
		   p_msg_text      IN VARCHAR2 DEFAULT NULL,
		   p_msg_text_html IN CLOB /*VARCHAR2*/ DEFAULT NULL, --05.06.17 Datatype Modifiedto CLOB , INC0094556
		   p_err_code      OUT NUMBER,
		   p_err_message   OUT VARCHAR2) IS
    c          utl_smtp.connection;
    l_boundary VARCHAR2(50) := '----=*#abc1234321cba#*=';
    rc         INTEGER;
    ---p_msg_from varchar2(50) := 'sujoy.das@stratasys.com';
    mailhost          fnd_profile_option_values.profile_option_value%TYPE; --'srv-ire-ex02.stratasys.dmn'
    l_to              VARCHAR2(1000) := NULL;
    l_delim           VARCHAR2(1) := ';';
    l_clob_length     INTEGER := dbms_lob.getlength(p_msg_text_html); --Added on 05.06.17 for INC0094556
    l_index           INTEGER := 1; --Added on 05.06.17 for INC0094556
    l_wr_no_of_char   INTEGER := 32000; --Added on 05.06.17 for INC0094556
    l_connection_open BOOLEAN := FALSE; -- CHG0043983 : danm, 20/09/2018 Close connections on exception
  BEGIN
    mailhost := fnd_profile.value('XXOBJT_MAIL_SERVER_NAME');
    c        := utl_smtp.open_connection(mailhost, 25); -- SMTP on port 25
  
    l_connection_open := TRUE; -- CHG0043983 : danm, 20/09/2018 Close connections on exception
    utl_smtp.helo(c, mailhost);
    utl_smtp.mail(c, p_msg_from);
    utl_smtp.rcpt(c, p_msg_to);
    l_to := p_msg_to;
    IF p_msg_to1 IS NOT NULL THEN
      utl_smtp.rcpt(c, p_msg_to1);
      l_to := l_to || l_delim || p_msg_to1;
    END IF;
    IF p_msg_to2 IS NOT NULL THEN
      utl_smtp.rcpt(c, p_msg_to2);
      l_to := l_to || l_delim || p_msg_to2;
    END IF;
    IF p_msg_to3 IS NOT NULL THEN
      utl_smtp.rcpt(c, p_msg_to3);
      l_to := l_to || l_delim || p_msg_to3;
    END IF;
    IF p_msg_to4 IS NOT NULL THEN
      utl_smtp.rcpt(c, p_msg_to4);
      l_to := l_to || l_delim || p_msg_to4;
    END IF;
    IF p_msg_to5 IS NOT NULL THEN
      utl_smtp.rcpt(c, p_msg_to5);
      l_to := l_to || l_delim || p_msg_to5;
    END IF;
    utl_smtp.open_data(c);
  
    utl_smtp.write_data(c,
		'Date: ' ||
		to_char(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
		utl_tcp.crlf);
    utl_smtp.write_data(c, 'To: ' || l_to || utl_tcp.crlf);
    utl_smtp.write_data(c, 'From: ' || p_msg_from || utl_tcp.crlf);
    utl_smtp.write_data(c, 'Subject: ' || p_msg_subject || utl_tcp.crlf);
    utl_smtp.write_data(c, 'Reply-To: ' || p_msg_from || utl_tcp.crlf);
    utl_smtp.write_data(c, 'MIME-Version: 1.0' || utl_tcp.crlf);
    utl_smtp.write_data(c,
		'Content-Type: multipart/alternative; boundary="' ||
		l_boundary || '"' || utl_tcp.crlf || utl_tcp.crlf);
  
    IF p_msg_text IS NOT NULL THEN
      utl_smtp.write_data(c, '--' || l_boundary || utl_tcp.crlf);
      utl_smtp.write_data(c,
		  'Content-Type: text/plain; charset="iso-8859-1"' ||
		  utl_tcp.crlf || utl_tcp.crlf);
    
      utl_smtp.write_data(c, p_msg_text);
      utl_smtp.write_data(c, utl_tcp.crlf || utl_tcp.crlf);
    END IF;
    IF p_msg_text_html IS NOT NULL THEN
      utl_smtp.write_data(c, '--' || l_boundary || utl_tcp.crlf);
      utl_smtp.write_data(c,
		  'Content-Type: text/html; charset="iso-8859-1"' ||
		  utl_tcp.crlf || utl_tcp.crlf);
    
      /*utl_smtp.write_data(c,
      p_msg_text_html);*/ -- Commented on 05.06.17 for INC0094556
      -----------------------------------------
      -- Code added on 05.06.17 for INC0094556
      -- If the Mail body Length more then 32767
      -- write the data multiple times
      -----------------------------------------
      IF l_clob_length <= l_wr_no_of_char THEN
        utl_smtp.write_data(c, p_msg_text_html);
      ELSE
        -- Write Data multiple Times
        WHILE l_index <= l_clob_length
        LOOP
          utl_smtp.write_data(c,
		      dbms_lob.substr(p_msg_text_html,
			          l_wr_no_of_char,
			          l_index));
          l_index := l_index + l_wr_no_of_char;
        END LOOP;
      END IF;
      ----------End INC0094556--------------------
      utl_smtp.write_data(c, utl_tcp.crlf || utl_tcp.crlf);
    END IF;
  
    utl_smtp.write_data(c, '--' || l_boundary || '--' || utl_tcp.crlf);
    utl_smtp.close_data(c);
    utl_smtp.quit(c);
  
    p_err_code := 0;
  
  EXCEPTION
    WHEN utl_smtp.invalid_operation THEN
      IF l_connection_open THEN
        -- CHG0043983 : danm, 20/09/2018 Close connections on exception
        BEGIN
          utl_smtp.quit(c);
        EXCEPTION
          WHEN OTHERS THEN
	p_err_code    := 1;
	p_err_message := 'Unable to close open SMTP Connection' || ' ' ||
		     SQLERRM;
        END;
      END IF;
      dbms_output.put_line(' Invalid Operation in Mail attempt using UTL_SMTP.');
    WHEN utl_smtp.transient_error THEN
      IF l_connection_open THEN
        -- CHG0043983 : danm, 20/09/2018 Close connections on exception
        BEGIN
          utl_smtp.quit(c);
        EXCEPTION
          WHEN OTHERS THEN
	p_err_code    := 1;
	p_err_message := 'Unable to close open SMTP Connection' || ' ' ||
		     SQLERRM;
        END;
      END IF;
      dbms_output.put_line(' Temporary e-mail issue - try again');
    WHEN utl_smtp.permanent_error THEN
      IF l_connection_open THEN
        -- CHG0043983 : danm, 20/09/2018 Close connections on exception
        BEGIN
          utl_smtp.quit(c);
        EXCEPTION
          WHEN OTHERS THEN
	p_err_code    := 1;
	p_err_message := 'Unable to close open SMTP Connection' || ' ' ||
		     SQLERRM;
        END;
      END IF;
      dbms_output.put_line(' Permanent Error Encountered.');
    WHEN OTHERS THEN
      -- general exception
      IF l_connection_open THEN
        -- CHG0043983 : danm, 20/09/2018 Close connections on exception
        BEGIN
          utl_smtp.quit(c);
        EXCEPTION
          WHEN OTHERS THEN
	p_err_code    := 1;
	p_err_message := 'Unable to close open SMTP Connection' || ' ' ||
		     SQLERRM;
        END;
      END IF;
    
      p_err_code    := 1;
      p_err_message := 'WARNING : xxiby_process_cust_paymt_pkg.send_smtp_mail() - ' ||
	           fnd_message.get || ' ' || SQLERRM;
      print_message(p_err_message);
    
  END send_smtp_mail;
  ---------------------------------------------------------------
  --  name:               g_miss_token_rec
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Function to asign blank values to the rec type.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Function to asign blank values to the rec type.
  -----------------------------------------------------------------------
  FUNCTION g_miss_token_rec RETURN xxiby_cctoken_rec_type IS
    l_token_record xxiby_cctoken_rec_type;
  BEGIN
  
    l_token_record := xxiby_cctoken_rec_type(fnd_api.g_miss_char,
			         fnd_api.g_miss_num,
			         fnd_api.g_miss_char,
			         fnd_api.g_miss_char,
			         fnd_api.g_miss_char,
			         fnd_api.g_miss_char);
  
    RETURN l_token_record;
  END;
  ---------------------------------------------------------------
  --  name:               get_cctoken_list
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to get List of Token Information.This will be requested By eStore.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to get List of Token Information.This will be requested By eStore.
  --  1.1   04/12/2018    Diptasurjya     INC0118924 - Add extra conditions while selecting CC tokens
  --  1.2   27-Sep-2018   Lingaraj        CHG0043914-Previously used token list for eStore limited to uniqueness by card type, last 4 and expiration date
  --                                      "c_token_list" Cursor code modified to get the Distinct Credit Card
  -----------------------------------------------------------------------
  PROCEDURE get_cctoken_list(p_source         IN VARCHAR2,
		     p_pmt_type       IN VARCHAR2,
		     p_cust_acc_id    IN NUMBER,
		     p_account_number IN VARCHAR2 DEFAULT NULL,
		     p_site_id        IN NUMBER,
		     p_contact_id     IN NUMBER,
		     p_org_id         IN NUMBER DEFAULT NULL,
		     x_list_of_token  OUT xxiby_cctoken_tab_type,
		     x_error_code     OUT VARCHAR2,
		     x_error          OUT VARCHAR2) IS
    --Cursor SQL modified to get distinct Card detail on 27 Sep 18 for #CHG0043914
    l_account_number VARCHAR2(200); -- CHG0048217
  
    CURSOR c_token_list IS
      SELECT ccnumber,
	 token,
	 instrid,
	 card_holder_name,
	 cc_last_four_digit,
	 card_issuer,
	 expirydate
      FROM   (SELECT ibycc.ccnumber,
	         ltrim(ibycc.ccnumber, '0') token,
	         ibycc.instrid,
	         ibycc.chname card_holder_name,
	         ibycc.attribute1 cc_last_four_digit,
	         ibycc.card_issuer_code card_issuer,
	         to_char(ibycc.expirydate, 'MM/YYYY') expirydate,
	         row_number() over(PARTITION BY ibycc.attribute1, ibycc.card_issuer_code, ibycc.expirydate ORDER BY ibycc.instrid DESC) AS row_num
	  FROM   iby_creditcard   ibycc,
	         hz_cust_accounts acct
	  WHERE  ibycc.card_owner_id = acct.party_id
	        --AND    rownum < 10;
	        --  AND    acct.cust_account_id = p_cust_acc_id --'2213127' -- CUST_ACCOUNT_ID
	  AND    acct.account_number = l_account_number -- CHG0048217
	  AND    acct.status = 'A'
	  AND    ibycc.attribute2 =
	         to_char(nvl(p_contact_id, ibycc.attribute2))
	        --INC0118924 - Active Card conditions check
	  AND    ibycc.active_flag = 'Y'
	  AND    ibycc.single_use_flag = 'N'
	  AND    ibycc.information_only_flag = 'N'
	  AND    ibycc.expired_flag = 'N'
	  AND    trunc(nvl(ibycc.inactive_date, SYSDATE + 1)) >=
	         trunc(SYSDATE)
	        --INC0118924 - Condition check for active account/address assignment
	  AND    EXISTS
	   (SELECT 'x'
	          FROM   apps.iby_pmt_instr_uses_all piu
	          WHERE  piu.start_date <= SYSDATE
	          AND    trunc(nvl(end_date, SYSDATE + 1)) >=
		     trunc(SYSDATE)
	          AND    piu.instrument_id = ibycc.instrid))
      WHERE  row_num = 1;
  
    l_token_rec_out xxiby_cctoken_rec_type;
    l_index         NUMBER := 0;
    l_list_of_token xxiby_cctoken_tab_type := xxiby_cctoken_tab_type();
  BEGIN
  
    x_error_code := 0;
    -- CHG0048217
    IF p_account_number IS NOT NULL THEN
      l_account_number := p_account_number;
    ELSIF p_cust_acc_id IS NOT NULL THEN
      BEGIN
        SELECT account_number
        INTO   l_account_number
        FROM   hz_cust_accounts ac
        WHERE  cust_account_id = p_cust_acc_id;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;
    -- end -- CHG0048217
    IF p_pmt_type = 'CC' THEN
    
      FOR cc_token_rec IN c_token_list
      LOOP
        l_index         := l_index + 1;
        l_token_rec_out := g_miss_token_rec;
        l_list_of_token.extend;
      
        l_token_rec_out.token              := cc_token_rec.token;
        l_token_rec_out.instrid            := cc_token_rec.instrid;
        l_token_rec_out.card_holder_name   := cc_token_rec.card_holder_name;
        l_token_rec_out.cc_last_four_digit := cc_token_rec.cc_last_four_digit;
        l_token_rec_out.card_issuer        := cc_token_rec.card_issuer;
        l_token_rec_out.expirydate         := cc_token_rec.expirydate;
      
        l_list_of_token(l_list_of_token.count) := l_token_rec_out;
      END LOOP;
    
      IF l_index = 0 THEN
        x_error_code := 0;
        x_error      := 'NO_CARD_FOUND';
      ELSE
        -- x_list_of_token := xxiby_ccToken_tab_type();
        x_list_of_token := l_list_of_token;
      
      END IF;
    
    END IF;
  
  EXCEPTION
    WHEN no_data_found THEN
      x_error_code := 0;
      x_error      := 'NO_CARD_FOUND';
    WHEN OTHERS THEN
      x_error_code := 1;
      x_error      := 'WARNING : xxiby_process_cust_paymt_pkg.get_cctoken_list() - ' ||
	          SQLERRM;
      print_message(x_error);
  END get_cctoken_list;

  ---------------------------------------------------------------
  --  name:               update_estore_pson
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to Update the auto generated oracle PSON/Tangable id in Oracle IBY Tables with eStore provided PSON.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to Update the auto generated oracle PSON/Tangable id in Oracle IBY Tables with eStore provided PSON.
  -----------------------------------------------------------------------
  PROCEDURE update_estore_pson(p_estore_pson     IN VARCHAR2, --Required
		       p_iby_trxn_ext_id IN NUMBER DEFAULT NULL,
		       p_so_header_id    IN NUMBER, --Sales Order Header ID
		       p_oracle_pson     IN VARCHAR2 DEFAULT NULL,
		       --Out Parameters
		       x_error_code OUT VARCHAR2,
		       x_error      OUT VARCHAR2) IS
    l_iby_trxn_ext_id NUMBER;
    l_oracle_pson     VARCHAR2(100);
  BEGIN
    x_error_code := 0;
    --Update the auto generated oracle PSON/Tangable id in Oracle IBY Tables with eStore provided PSON.
    SELECT trxn_extension_id,
           payment_system_order_number
    INTO   l_iby_trxn_ext_id,
           l_oracle_pson
    FROM   iby_fndcpt_tx_extensions
    WHERE  1 = 1
    AND    order_id = to_char(p_so_header_id);
  
    IF l_oracle_pson IS NULL THEN
      x_error_code := 1;
      x_error      := 'ORACLE Generated PSON should not be Blank.';
      RETURN;
    END IF;
  
    UPDATE iby_trxn_summaries_all
    SET    tangibleid = p_estore_pson
    WHERE  1 = 1
    AND    initiator_extension_id = l_iby_trxn_ext_id
    AND    tangibleid = l_oracle_pson;
  
    UPDATE iby_tangible
    SET    tangibleid = p_estore_pson
    WHERE  tangibleid = l_oracle_pson
    AND    l_oracle_pson IS NOT NULL;
  
    UPDATE iby_fndcpt_tx_extensions
    SET    payment_system_order_number = p_estore_pson,
           voice_authorization_flag    = NULL,
           voice_authorization_date    = NULL,
           voice_authorization_code    = NULL
    WHERE  trxn_extension_id = l_iby_trxn_ext_id;
  
    -- COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_error_code := 1;
      x_error      := 'WARNING xxiby_process_cust_paymt_pkg.update_estore_pson() ' ||
	          SQLERRM;
      print_message(x_error);
  END update_estore_pson;
  ---------------------------------------------------------------
  --  name:               create_new_creditcard
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to create CreditCard entry in IBY_CREDITCARD table. This is called from eStore side.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to create CreditCard entry in IBY_CREDITCARD table. This is called from eStore side.
  -----------------------------------------------------------------------
  PROCEDURE create_new_creditcard(p_token               IN VARCHAR2,
		          p_cust_number         IN VARCHAR2,
		          p_cust_account_id     IN VARCHAR2,
		          p_bill_to_contact_id  IN NUMBER,
		          p_org_id              IN NUMBER,
		          p_bill_to_site_use_id IN NUMBER,
		          --Out Parameters
		          x_instr_id       OUT NUMBER,
		          x_chname         OUT VARCHAR2,
		          x_expiry_date    OUT DATE,
		          x_cc_issuer_code OUT VARCHAR2,
		          x_cc_number      OUT VARCHAR2,
		          x_error_code     OUT VARCHAR2,
		          x_error          OUT VARCHAR2) IS
    ---
    PRAGMA AUTONOMOUS_TRANSACTION;
    ---
    l_party_id    NUMBER;
    l_card_count  NUMBER := 0;
    l_err_code    NUMBER := 0;
    l_err_message VARCHAR2(10000);
  
    l_customername            VARCHAR2(100);
    l_ccexp                   DATE;
    l_ccaccountnum            VARCHAR2(100);
    l_card_type               VARCHAR2(100);
    l_cc_last4digit           VARCHAR2(4);
    l_orderdefaultdescription NUMBER;
    l_cus_conct_id            VARCHAR2(20);
    l_customer_nm             VARCHAR2(240);
    l_location_nm             VARCHAR2(240);
    l_count                   NUMBER := 0;
    l_instr_id                NUMBER;
    l_cust_number             VARCHAR2(100);
    l_xxiby_cc_debug_tbl      xxiby_cc_debug_tbl%ROWTYPE;
    l_error_code              VARCHAR2(10);
    l_error_desc              VARCHAR2(2000);
  BEGIN
    x_error_code := 0;
  
    IF g_debug = 'Y' THEN
      print_message('Inside create_new_creditcard Procedure');
    END IF;
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.request_json := 'p_token => ' || p_token || ',' ||
			       'p_cust_number => ' ||
			       p_cust_number || ',' ||
			       'p_cust_account_id => ' ||
			       p_cust_account_id || ',' ||
			       'p_bill_to_contact_id => ' ||
			       p_bill_to_contact_id || ',' ||
			       'p_org_id => ' || p_org_id || ',' ||
			       'p_bill_to_site_use_id => ' ||
			       p_bill_to_site_use_id;
    
      l_xxiby_cc_debug_tbl.step        := '1';
      l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.create_new_creditcard';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => l_error_code,
	p_error_desc         => l_error_desc);
    END IF;
  
    IF p_cust_number IS NULL THEN
      SELECT account_number
      INTO   l_cust_number
      FROM   hz_cust_accounts
      WHERE  cust_account_id = p_cust_account_id;
    ELSE
      l_cust_number := p_cust_number;
    END IF;
  
    -- Get Party_id
    BEGIN
      SELECT hca.party_id
      INTO   l_party_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hca.account_number = l_cust_number;
    
    EXCEPTION
      WHEN OTHERS THEN
        x_error_code := 1;
        x_error      := 'Part Id Not found,' || SQLERRM;
        RETURN;
    END;
  
    -- checking Credit Card Token exits or not
    BEGIN
      SELECT COUNT(1)
      INTO   l_card_count
      FROM   iby_creditcard          cc,
	 iby_pmt_instr_uses_all  ipiua,
	 iby_external_payers_all iepa
      WHERE  cc.instrid = ipiua.instrument_id
      AND    ipiua.ext_pmt_party_id = iepa.ext_payer_id
      AND    cc.card_owner_id = l_party_id
      AND    cc.ccnumber = (SELECT lpad(p_token, 16, 0)
		    FROM   dual)
      AND    iepa.payment_function = 'CUSTOMER_PAYMENT'
      AND    iepa.party_id = l_party_id
      AND    iepa.org_type = 'OPERATING_UNIT'
      AND    iepa.org_id = p_org_id
      AND    iepa.cust_account_id = p_cust_account_id
      AND    iepa.acct_site_use_id = p_bill_to_site_use_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        l_card_count := 0;
    END;
  
    IF l_card_count = 0 THEN
      -- Get CC Details
      --print_message('Before xxiby_process_cust_paymt_pkg.get_cc_detail Call');
      xxiby_process_cust_paymt_pkg.get_cc_detail(p_err_code                => l_err_code,
				 p_err_message             => l_err_message,
				 p_customerrefnum          => p_token, -- IN
				 p_customername            => l_customername,
				 p_ccexp                   => l_ccexp,
				 p_ccaccountnum            => l_ccaccountnum,
				 p_card_type               => l_card_type,
				 p_cc_last4digit           => l_cc_last4digit,
				 p_orderdefaultdescription => l_orderdefaultdescription);
    
      IF l_err_code = 0 AND l_ccexp >= trunc(SYSDATE) THEN
        -- Create Card with the fetched details
        l_err_code    := NULL;
        l_err_message := NULL;
        --print_message('Before xxiby_process_cust_paymt_pkg.add_cc_token Call');
        xxiby_process_cust_paymt_pkg.add_cc_token(p_err_code           => l_err_code,
				  p_err_message        => l_err_message,
				  p_owner_id           => l_party_id,
				  p_card_holder_name   => l_customername,
				  p_billing_address_id => NULL,
				  p_card_number        => p_token,
				  p_expiration_date    => l_ccexp,
				  p_instrument_type    => 'CREDITCARD',
				  p_purchasecard_flag  => 'N',
				  p_card_issuer        => NULL,
				  p_single_use_flag    => 'N',
				  p_info_only_flag     => 'N',
				  p_card_purpose       => 'S',
				  p_active_flag        => 'Y',
				  p_cc_last4digit      => l_cc_last4digit,
				  p_billto_contact_id  => p_bill_to_contact_id
				  --p_instr_id => l_instr_id
				  );
      
        IF l_err_code = 0 THEN
          l_err_code    := NULL;
          l_err_message := NULL;
          x_instr_id    := g_instrument_id;
          --print_message('Before xxiby_process_cust_paymt_pkg.set_cc_token_assignment Call');
          xxiby_process_cust_paymt_pkg.set_cc_token_assignment(p_err_code        => l_err_code,
					   p_err_message     => l_err_message,
					   p_party_id        => l_party_id,
					   p_cust_account_id => p_cust_account_id,
					   p_account_site_id => p_bill_to_site_use_id,
					   p_org_id          => p_org_id,
					   p_start_date      => trunc(SYSDATE),
					   p_end_date        => l_ccexp,
					   p_instrument_id   => g_instrument_id);
        
          IF l_err_code = 0 THEN
	COMMIT; -- Commit the Creadit Card Creation and Assignment
	SELECT ibycc.ccnumber,
	       ibycc.instrid,
	       ibycc.chname,
	       ibycc.card_issuer_code,
	       ibycc.expirydate
	INTO   x_cc_number,
	       x_instr_id,
	       x_chname,
	       x_cc_issuer_code,
	       x_expiry_date
	FROM   iby_creditcard ibycc
	WHERE  1 = 1
	AND    ibycc.instrid = g_instrument_id;
          
          END IF;
        ELSE
          --Exception During Card Creation In Oracle
          x_error_code := l_err_code;
          x_error      := l_err_message;
          RETURN;
        END IF;
      
      ELSE
        --CARD Expired or Any Other Exception
        x_error_code := 1;
        IF l_err_code = 0 AND l_ccexp < trunc(SYSDATE) THEN
          x_error := 'CARD_EXPIRED';
        ELSE
          x_error := l_err_message;
        END IF;
      
        RETURN;
      
      END IF;
    
    ELSE
      --Provided Token is available for the Party
      IF l_card_count = 1 THEN
        SELECT ibycc.ccnumber,
	   ibycc.instrid,
	   ibycc.chname,
	   ibycc.card_issuer_code,
	   ibycc.expirydate
        INTO   x_cc_number,
	   x_instr_id,
	   x_chname,
	   x_cc_issuer_code,
	   x_expiry_date
        FROM   iby_creditcard          ibycc,
	   iby_pmt_instr_uses_all  ipiua,
	   iby_external_payers_all iepa
        WHERE  ibycc.instrid = ipiua.instrument_id
        AND    ipiua.ext_pmt_party_id = iepa.ext_payer_id
        AND    ibycc.card_owner_id = l_party_id
        AND    ibycc.ccnumber = (SELECT lpad(p_token, 16, 0)
		         FROM   dual)
        AND    iepa.payment_function = 'CUSTOMER_PAYMENT'
        AND    iepa.party_id = l_party_id
        AND    iepa.org_type = 'OPERATING_UNIT'
        AND    iepa.org_id = p_org_id
        AND    iepa.cust_account_id = p_cust_account_id
        AND    iepa.acct_site_use_id = p_bill_to_site_use_id;
      
        x_error := 'EXISTING_CARD';
      ELSIF l_card_count > 1 THEN
        x_error_code := 1;
        x_error      := 'MULTIPLE_RECORD_FOUND';
      END IF;
    END IF;
  
    IF g_debug = 'Y' THEN
      print_message('Exit create_new_creditcard Procedure');
    END IF;
  
    IF g_debug = 'Y' THEN
      print_message('x_cc_number :' || x_cc_number);
      print_message('x_instr_id:' || x_instr_id);
      print_message('x_chname :' || x_chname);
      print_message('x_cc_issuer_code:' || x_cc_issuer_code);
      print_message('x_expiry_date:' || x_expiry_date);
      print_message('x_error_code:' || x_error_code);
      print_message('x_error:' || x_error);
    END IF;
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.response_json := 'x_instr_id => ' || x_instr_id || ',' ||
			        'x_chname => ' || x_chname || ',' ||
			        'x_expiry_date => ' ||
			        x_expiry_date || ',' ||
			        'x_cc_issuer_code => ' ||
			        x_cc_issuer_code || ',' ||
			        'x_cc_number => ' ||
			        x_cc_number || ',' ||
			        'x_error_code => ' ||
			        x_error_code || ',' ||
			        'x_error => ' || x_error;
    
      l_xxiby_cc_debug_tbl.step        := '2';
      l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.create_new_creditcard';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => l_error_code,
	p_error_desc         => l_error_desc);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_error_code := 1;
      x_error      := 'WARNING xxiby_process_cust_paymt_pkg.create_new_creditcard()' ||
	          SQLERRM;
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.response_json := 'x_instr_id => ' ||
			          x_instr_id || ',' ||
			          'x_chname => ' || x_chname || ',' ||
			          'x_expiry_date => ' ||
			          x_expiry_date || ',' ||
			          'x_cc_issuer_code => ' ||
			          x_cc_issuer_code || ',' ||
			          'x_cc_number => ' ||
			          x_cc_number || ',' ||
			          'x_error_code => ' ||
			          x_error_code || ',' ||
			          'x_error => ' || x_error;
      
        l_xxiby_cc_debug_tbl.step        := '3';
        l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.create_new_creditcard';
        l_xxiby_cc_debug_tbl.error_msg   := x_error;
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => l_error_code,
	  p_error_desc         => l_error_desc);
      END IF;
    
  END create_new_creditcard;

  --------------------------------------------------------------------------------------------------------------------
  -- Ver     When        Who            Description
  -- ------  ----------  -------------  ------------------------------------------------------------------------------
  -- 1.0     18/09/2019  Roman W.       CHG0046328 - get servlet data: PlaceNewOrderServlet
  --------------------------------------------------------------------------------------------------------------------
  PROCEDURE get_xxiby_place_new_order_row(p_responce_clob   IN CLOB,
			      p_place_new_order OUT xxiby_place_new_order_row_type,
			      p_error_code      OUT NUMBER,
			      p_error_desc      OUT VARCHAR2) IS
    --------------------------------
    --      Local Definition
    --------------------------------
    l_xmltype xmltype;
    --------------------------------
    --      Code Section
    --------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    l_xmltype := xmltype.createxml(p_responce_clob);
  
    p_place_new_order := xxiby_place_new_order_row_type(NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL,
				        NULL);
  
    SELECT t.extract('/PlaceNewOrderServlet/Version/text()').getstringval() version,
           t.extract('/PlaceNewOrderServlet/IndustryType/text()')
           .getstringval() industrytype,
           t.extract('/PlaceNewOrderServlet/TransType/text()')
           .getstringval() transtype,
           t.extract('/PlaceNewOrderServlet/MerchantID/text()')
           .getstringval() merchantid,
           t.extract('/PlaceNewOrderServlet/TerminalID/text()')
           .getstringval() terminalid,
           t.extract('/PlaceNewOrderServlet/CardBrand/text()')
           .getstringval() cardbrand,
           t.extract('/PlaceNewOrderServlet/OrderID/text()').getstringval() orderid,
           t.extract('/PlaceNewOrderServlet/TxRefNum/text()').getstringval() txrefnum,
           t.extract('/PlaceNewOrderServlet/TxRefIdx/text()').getstringval() txrefidx,
           t.extract('/PlaceNewOrderServlet/RespDateTime/text()')
           .getstringval() respdatetime,
           t.extract('/PlaceNewOrderServlet/ProcStatus/text()')
           .getstringval() procstatus,
           t.extract('/PlaceNewOrderServlet/ApprovalStatus/text()')
           .getstringval() approvalstatus,
           t.extract('/PlaceNewOrderServlet/RespCode/text()').getstringval() respcode,
           t.extract('/PlaceNewOrderServlet/AvsRespCode/text()')
           .getstringval() avsrespcode,
           t.extract('/PlaceNewOrderServlet/CvvRespCode/text()')
           .getstringval() cvvrespcode,
           t.extract('/PlaceNewOrderServlet/AuthorizationCode/text()')
           .getstringval() authorizationcode,
           t.extract('/PlaceNewOrderServlet/McRecurringAdvCode/text()')
           .getstringval() mcrecurringadvcode,
           t.extract('/PlaceNewOrderServlet/VisaVbVRespCode/text()')
           .getstringval() visavbvrespcode,
           t.extract('/PlaceNewOrderServlet/ProcStatusMessage/text()')
           .getstringval() procstatusmessage,
           t.extract('/PlaceNewOrderServlet/RespCodeMessage/text()')
           .getstringval() respcodemessage,
           t.extract('/PlaceNewOrderServlet/HostRespCode/text()')
           .getstringval() hostrespcode,
           t.extract('/PlaceNewOrderServlet/HostAVSRespCode/text()')
           .getstringval() hostavsrespcode,
           t.extract('/PlaceNewOrderServlet/HostCVVRespCode/text()')
           .getstringval() hostcvvrespcode,
           t.extract('/PlaceNewOrderServlet/RetryTrace/text()')
           .getstringval() retrytrace,
           t.extract('/PlaceNewOrderServlet/RetryAttempCount/text()')
           .getstringval() retryattempcount,
           t.extract('/PlaceNewOrderServlet/LastRetryDate/text()')
           .getstringval() lastretrydate,
           t.extract('/PlaceNewOrderServlet/CustomerRefNum/text()')
           .getstringval() customerrefnum,
           t.extract('/PlaceNewOrderServlet/CustomerName/text()')
           .getstringval() customername,
           t.extract('/PlaceNewOrderServlet/ProfileProcStatus/text()')
           .getstringval() profileprocstatus,
           t.extract('/PlaceNewOrderServlet/ProfileProcStatusMsg/text()')
           .getstringval() profileprocstatusmsg,
           t.extract('/PlaceNewOrderServlet/GiftCardInd/text()')
           .getstringval() giftcardind,
           t.extract('/PlaceNewOrderServlet/RemainingBalance/text()')
           .getstringval() remainingbalance,
           t.extract('/PlaceNewOrderServlet/RequestAmount/text()')
           .getstringval() requestamount,
           t.extract('/PlaceNewOrderServlet/RedeemedAmount/text()')
           .getstringval() redeemedamount,
           t.extract('/PlaceNewOrderServlet/CcAccountNum/text()')
           .getstringval() ccaccountnum,
           t.extract('/PlaceNewOrderServlet/DebitBillerReferenceNumber/text()')
           .getstringval() debitbillerreferencenumber,
           t.extract('/PlaceNewOrderServlet/MbMicroPaymentDaysLeft/text()')
           .getstringval() mbmicropaymentdaysleft,
           t.extract('/PlaceNewOrderServlet/MbMicroPaymentDollarsLeft/text()')
           .getstringval() mbmicropaymentdollarsleft,
           t.extract('/PlaceNewOrderServlet/MbStatus    /text()')
           .getstringval() mbstatus,
           t.extract('/PlaceNewOrderServlet/DebitPinSurchargeAmount/text()')
           .getstringval() debitpinsurchargeamount,
           t.extract('/PlaceNewOrderServlet/DebitPinTraceNumber/text()')
           .getstringval() debitpintracenumber,
           t.extract('/PlaceNewOrderServlet/DebitPinNetworkID/text()')
           .getstringval() debitpinnetworkid,
           t.extract('/PlaceNewOrderServlet/PartialAuthOccurred/text()')
           .getstringval() partialauthoccurred,
           t.extract('/PlaceNewOrderServlet/CountryFraudFilterStatus/text()')
           .getstringval() countryfraudfilterstatus,
           t.extract('/PlaceNewOrderServlet/IsoCountryCode/text()')
           .getstringval() isocountrycode,
           t.extract('/PlaceNewOrderServlet/FraudScoreProcStatus/text()')
           .getstringval() fraudscoreprocstatus,
           t.extract('/PlaceNewOrderServlet/FraudScoreProcMsg/text()')
           .getstringval() fraudscoreprocmsg,
           t.extract('/PlaceNewOrderServlet/FraudAnalysisResponse/text()')
           .getstringval() fraudanalysisresponse,
           t.extract('/PlaceNewOrderServlet/CtiAffluentCard/text()')
           .getstringval() ctiaffluentcard,
           t.extract('/PlaceNewOrderServlet/CtiCommercialCard/text()')
           .getstringval() cticommercialcard,
           t.extract('/PlaceNewOrderServlet/CtiDurbinExemption/text()')
           .getstringval() ctidurbinexemption,
           t.extract('/PlaceNewOrderServlet/CtiHealthcareCard/text()')
           .getstringval() ctihealthcarecard,
           t.extract('/PlaceNewOrderServlet/CtiLevel3Eligible/text()')
           .getstringval() ctilevel3eligible,
           t.extract('/PlaceNewOrderServlet/CtiPayrollCard/text()')
           .getstringval() ctipayrollcard,
           t.extract('/PlaceNewOrderServlet/CtiPrepaidCard/text()')
           .getstringval() ctiprepaidcard,
           t.extract('/PlaceNewOrderServlet/CtiPINlessDebitCard/text()')
           .getstringval() ctipinlessdebitcard,
           t.extract('/PlaceNewOrderServlet/CtiSignatureDebitCard/text()')
           .getstringval() ctisignaturedebitcard,
           t.extract('/PlaceNewOrderServlet/CtiIssuingCountry/text()')
           .getstringval() ctiissuingcountry,
           t.extract('/PlaceNewOrderServlet/EuddBankSortCode/text()')
           .getstringval() euddbanksortcode,
           t.extract('/PlaceNewOrderServlet/EuddCountryCode/text()')
           .getstringval() euddcountrycode,
           t.extract('/PlaceNewOrderServlet/EuddRibCode/text()')
           .getstringval() euddribcode,
           t.extract('/PlaceNewOrderServlet/EuddBankBranchCode/text()')
           .getstringval() euddbankbranchcode,
           t.extract('/PlaceNewOrderServlet/EuddIBAN/text()').getstringval() euddiban,
           t.extract('/PlaceNewOrderServlet/EuddBIC/text()').getstringval() euddbic,
           t.extract('/PlaceNewOrderServlet/EuddMandateSignatureDate/text()')
           .getstringval() euddmandatesignaturedate,
           t.extract('/PlaceNewOrderServlet/EuddMandateID/text()')
           .getstringval() euddmandateid,
           t.extract('/PlaceNewOrderServlet/EuddMandateType/text()')
           .getstringval() euddmandatetype,
           t.extract('/PlaceNewOrderServlet/TokenAssuranceLevel/text()')
           .getstringval() tokenassurancelevel,
           t.extract('/PlaceNewOrderServlet/DpanAccountStatus/text()')
           .getstringval() dpanaccountstatus,
           t.extract('/PlaceNewOrderServlet/ChipCardData/text()')
           .getstringval() chipcarddata,
           t.extract('/PlaceNewOrderServlet/ActualRespCd/text()')
           .getstringval() actualrespcd,
           t.extract('/PlaceNewOrderServlet/ErrorCode/text()')
           .getstringval() errorcode,
           t.extract('/PlaceNewOrderServlet/ErrorDesc/text()')
           .getstringval() errordesc
    INTO   p_place_new_order.version,
           p_place_new_order.industrytype,
           p_place_new_order.transtype,
           p_place_new_order.merchantid,
           p_place_new_order.terminalid,
           p_place_new_order.cardbrand,
           p_place_new_order.orderid,
           p_place_new_order.txrefnum,
           p_place_new_order.txrefidx,
           p_place_new_order.respdatetime,
           p_place_new_order.procstatus,
           p_place_new_order.approvalstatus,
           p_place_new_order.respcode,
           p_place_new_order.avsrespcode,
           p_place_new_order.cvvrespcode,
           p_place_new_order.authorizationcode,
           p_place_new_order.mcrecurringadvcode,
           p_place_new_order.visavbvrespcode,
           p_place_new_order.procstatusmessage,
           p_place_new_order.respcodemessage,
           p_place_new_order.hostrespcode,
           p_place_new_order.hostavsrespcode,
           p_place_new_order.hostcvvrespcode,
           p_place_new_order.retrytrace,
           p_place_new_order.retryattempcount,
           p_place_new_order.lastretrydate,
           p_place_new_order.customerrefnum,
           p_place_new_order.customername,
           p_place_new_order.profileprocstatus,
           p_place_new_order.profileprocstatusmsg,
           p_place_new_order.giftcardind,
           p_place_new_order.remainingbalance,
           p_place_new_order.requestamount,
           p_place_new_order.redeemedamount,
           p_place_new_order.ccaccountnum,
           p_place_new_order.debitbillerreferencenumber,
           p_place_new_order.mbmicropaymentdaysleft,
           p_place_new_order.mbmicropaymentdollarsleft,
           p_place_new_order.mbstatus,
           p_place_new_order.debitpinsurchargeamount,
           p_place_new_order.debitpintracenumber,
           p_place_new_order.debitpinnetworkid,
           p_place_new_order.partialauthoccurred,
           p_place_new_order.countryfraudfilterstatus,
           p_place_new_order.isocountrycode,
           p_place_new_order.fraudscoreprocstatus,
           p_place_new_order.fraudscoreprocmsg,
           p_place_new_order.fraudanalysisresponse,
           p_place_new_order.ctiaffluentcard,
           p_place_new_order.cticommercialcard,
           p_place_new_order.ctidurbinexemption,
           p_place_new_order.ctihealthcarecard,
           p_place_new_order.ctilevel3eligible,
           p_place_new_order.ctipayrollcard,
           p_place_new_order.ctiprepaidcard,
           p_place_new_order.ctipinlessdebitcard,
           p_place_new_order.ctisignaturedebitcard,
           p_place_new_order.ctiissuingcountry,
           p_place_new_order.euddbanksortcode,
           p_place_new_order.euddcountrycode,
           p_place_new_order.euddribcode,
           p_place_new_order.euddbankbranchcode,
           p_place_new_order.euddiban,
           p_place_new_order.euddbic,
           p_place_new_order.euddmandatesignaturedate,
           p_place_new_order.euddmandateid,
           p_place_new_order.euddmandatetype,
           p_place_new_order.tokenassurancelevel,
           p_place_new_order.dpanaccountstatus,
           p_place_new_order.chipcarddata,
           p_place_new_order.actualrespcd,
           p_place_new_order.errorcode,
           p_place_new_order.errordesc
    FROM   TABLE(xmlsequence(l_xmltype)) t;
  
    IF p_place_new_order.errorcode != '0' THEN
      p_error_code := 2;
      p_error_desc := p_place_new_order.errordesc;
      print_message(p_error_desc);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_xxiby_place_new_order_row() - ' ||
	          SQLERRM;
      print_message(p_error_desc);
    
  END get_xxiby_place_new_order_row;

  --------------------------------------------------------------------------------------------------------------------
  -- Ver     When        Who            Description
  -- ------  ----------  -------------  ------------------------------------------------------------------------------
  -- 1.0     18/09/2019  Roman W.       CHG0046328 - Show connection error or credit card processor rejection reason
  --------------------------------------------------------------------------------------------------------------------
  PROCEDURE get_xxiby_cc_detail_row(p_responce_clob IN CLOB,
			p_cc_detail     OUT xxiby_cc_detail_row_type,
			p_error_code    OUT NUMBER,
			p_error_desc    OUT VARCHAR2) IS
    -----------------------------
    --     Local Definition
    -----------------------------
    l_xmltype xmltype;
    --    p_cc_detail XXIBY_CC_DETAIL_ROW_TYPE;
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
    l_xmltype    := xmltype.createxml(p_responce_clob);
    p_error_code := 0;
    p_error_desc := NULL;
  
    p_cc_detail := xxiby_cc_detail_row_type(NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL,
			        NULL);
  
    SELECT t.extract('/ProfileResponseElement/Version/text()')
           .getstringval() version,
           t.extract('/ProfileResponseElement/Bin/text()').getstringval() bin,
           t.extract('/ProfileResponseElement/MerchantID/text()')
           .getstringval() merchantid,
           t.extract('/ProfileResponseElement/CustomerName/text()')
           .getstringval() customername,
           t.extract('/ProfileResponseElement/CustomerRefNum/text()')
           .getstringval() customerrefnum,
           t.extract('/ProfileResponseElement/ProfileAction/text()')
           .getstringval() profileaction,
           t.extract('/ProfileResponseElement/ProcStatus/text()')
           .getstringval() procstatus,
           t.extract('/ProfileResponseElement/ProcStatusMessage/text()')
           .getstringval() procstatusmessage,
           t.extract('/ProfileResponseElement/CustomerAddress1/text()')
           .getstringval() customeraddress1,
           t.extract('/ProfileResponseElement/CustomerAddress2/text()')
           .getstringval() customeraddress2,
           t.extract('/ProfileResponseElement/CustomerCity/text()')
           .getstringval() customercity,
           t.extract('/ProfileResponseElement/CustomerState/text()')
           .getstringval() customerstate,
           t.extract('/ProfileResponseElement/CustomerZIP/text()')
           .getstringval() customerzip,
           t.extract('/ProfileResponseElement/CustomerEmail/text()')
           .getstringval() customeremail,
           t.extract('/ProfileResponseElement/CustomerPhone/text()')
           .getstringval() customerphone,
           t.extract('/ProfileResponseElement/CustomerCountryCode/text()')
           .getstringval() customercountrycode,
           t.extract('/ProfileResponseElement/ProfileOrderOverideInd/text()')
           .getstringval() profileorderoverideind,
           t.extract('/ProfileResponseElement/OrderDefaultDescription/text()')
           .getstringval() orderdefaultdescription,
           t.extract('/ProfileResponseElement/OrderDefaultAmount/text()')
           .getstringval() orderdefaultamount,
           t.extract('/ProfileResponseElement/CustomerAccountType/text()')
           .getstringval() customeraccounttype,
           t.extract('/ProfileResponseElement/CcAccountNum/text()')
           .getstringval() ccaccountnum,
           t.extract('/ProfileResponseElement/CcExp/text()').getstringval() ccexp,
           t.extract('/ProfileResponseElement/EcpCheckDDA/text()')
           .getstringval() ecpcheckdda,
           t.extract('/ProfileResponseElement/EcpBankAcctType/text()')
           .getstringval() ecpbankaccttype,
           t.extract('/ProfileResponseElement/EcpCheckRT/text()')
           .getstringval() ecpcheckrt,
           t.extract('/ProfileResponseElement/EcpDelvMethod/text()')
           .getstringval() ecpdelvmethod,
           t.extract('/ProfileResponseElement/SwitchSoloCardStartDate/text()')
           .getstringval() switchsolocardstartdate,
           t.extract('/ProfileResponseElement/SwitchSoloIssueNum/text()')
           .getstringval() switchsoloissuenum,
           t.extract('/ProfileResponseElement/MbType/text()').getstringval() mbtype,
           t.extract('/ProfileResponseElement/MbOrderIdGenerationMethod/text()')
           .getstringval() mborderidgenerationmethod,
           t.extract('/ProfileResponseElement/MbRecurringStartDate/text()')
           .getstringval() mbrecurringstartdate,
           t.extract('/ProfileResponseElement/MbRecurringEndDate/text()')
           .getstringval() mbrecurringenddate,
           t.extract('/ProfileResponseElement/MbRecurringNoEndDateFlag/text()')
           .getstringval() mbrecurringnoenddateflag,
           t.extract('/ProfileResponseElement/MbRecurringMaxBillings/text()')
           .getstringval() mbrecurringmaxbillings,
           t.extract('/ProfileResponseElement/MbRecurringFrequency/text()')
           .getstringval() mbrecurringfrequency,
           t.extract('/ProfileResponseElement/MbMicroPaymentMaxDollarValue/text()')
           .getstringval() mbmicropaymentmaxdollarvalue,
           t.extract('/ProfileResponseElement/MbMicroPaymentMaxBillingDays/text()')
           .getstringval() mbmicropaymentmaxbillingdays,
           t.extract('/ProfileResponseElement/MbMicroPaymentMaxTransactions/text()')
           .getstringval() mbmicropaymentmaxtransactions,
           t.extract('/ProfileResponseElement/MbDeferredBillDate/text()')
           .getstringval() mbdeferredbilldate,
           t.extract('/ProfileResponseElement/MbMicroPaymentDaysLeft/text()')
           .getstringval() mbmicropaymentdaysleft,
           t.extract('/ProfileResponseElement/MbMicroPaymentDollarsLeft/text()')
           .getstringval() mbmicropaymentdollarsleft,
           t.extract('/ProfileResponseElement/MbStatus/text()')
           .getstringval() mbstatus,
           t.extract('/ProfileResponseElement/McSecureCodeAAV/text()')
           .getstringval() mcsecurecodeaav,
           t.extract('/ProfileResponseElement/SoftDescMercName/text()')
           .getstringval() softdescmercname,
           t.extract('/ProfileResponseElement/SoftDescProdDesc/text()')
           .getstringval() softdescproddesc,
           t.extract('/ProfileResponseElement/SoftDescMercCity/text()')
           .getstringval() softdescmerccity,
           t.extract('/ProfileResponseElement/SoftDescMercPhone/text()')
           .getstringval() softdescmercphone,
           t.extract('/ProfileResponseElement/SoftDescMercURL/text()')
           .getstringval() softdescmercurl,
           t.extract('/ProfileResponseElement/SoftDescMercEmail/text()')
           .getstringval() softdescmercemail,
           t.extract('/ProfileResponseElement/EuddBankSortCode/text()')
           .getstringval() euddbanksortcode,
           t.extract('/ProfileResponseElement/EuddCountryCode/text()')
           .getstringval() euddcountrycode,
           t.extract('/ProfileResponseElement/EuddRibCode/text()')
           .getstringval() euddribcode,
           t.extract('/ProfileResponseElement/EuddBankBranchCode/text()')
           .getstringval() euddbankbranchcode,
           t.extract('/ProfileResponseElement/EuddIBAN/text()')
           .getstringval() euddiban,
           t.extract('/ProfileResponseElement/EuddBIC/text()')
           .getstringval() euddbic,
           t.extract('/ProfileResponseElement/EuddMandateSignatureDate/text()')
           .getstringval() euddmandatesignaturedate,
           t.extract('/ProfileResponseElement/EuddMandateID/text()')
           .getstringval() euddmandateid,
           t.extract('/ProfileResponseElement/EuddMandateType/text()')
           .getstringval() euddmandatetype,
           t.extract('/ProfileResponseElement/Status/text()').getstringval() status,
           t.extract('/ProfileResponseElement/DebitBillerReferenceNumber/text()')
           .getstringval() debitbillerreferencenumber,
           t.extract('/ProfileResponseElement/AccountUpdaterEligibility/text()')
           .getstringval() accountupdatereligibility,
           t.extract('/ProfileResponseElement/DpanInd/text()')
           .getstringval() dpanind,
           t.extract('/ProfileResponseElement/TokenRequestorID/text()')
           .getstringval() tokenrequestorid,
           t.extract('/ProfileResponseElement/ErrorCode/text()')
           .getstringval() errorcode,
           t.extract('/ProfileResponseElement/ErrorDesc/text()')
           .getstringval() errordesc
    INTO   p_cc_detail.version,
           p_cc_detail.bin,
           p_cc_detail.merchantid,
           p_cc_detail.customername,
           p_cc_detail.customerrefnum,
           p_cc_detail.profileaction,
           p_cc_detail.procstatus,
           p_cc_detail.procstatusmessage,
           p_cc_detail.customeraddress1,
           p_cc_detail.customeraddress2,
           p_cc_detail.customercity,
           p_cc_detail.customerstate,
           p_cc_detail.customerzip,
           p_cc_detail.customeremail,
           p_cc_detail.customerphone,
           p_cc_detail.customercountrycode,
           p_cc_detail.profileorderoverideind,
           p_cc_detail.orderdefaultdescription,
           p_cc_detail.orderdefaultamount,
           p_cc_detail.customeraccounttype,
           p_cc_detail.ccaccountnum,
           p_cc_detail.ccexp,
           p_cc_detail.ecpcheckdda,
           p_cc_detail.ecpbankaccttype,
           p_cc_detail.ecpcheckrt,
           p_cc_detail.ecpdelvmethod,
           p_cc_detail.switchsolocardstartdate,
           p_cc_detail.switchsoloissuenum,
           p_cc_detail.mbtype,
           p_cc_detail.mborderidgenerationmethod,
           p_cc_detail.mbrecurringstartdate,
           p_cc_detail.mbrecurringenddate,
           p_cc_detail.mbrecurringnoenddateflag,
           p_cc_detail.mbrecurringmaxbillings,
           p_cc_detail.mbrecurringfrequency,
           p_cc_detail.mbmicropaymentmaxdollarvalue,
           p_cc_detail.mbmicropaymentmaxbillingdays,
           p_cc_detail.mbmicropaymentmaxtransactions,
           p_cc_detail.mbdeferredbilldate,
           p_cc_detail.mbmicropaymentdaysleft,
           p_cc_detail.mbmicropaymentdollarsleft,
           p_cc_detail.mbstatus,
           p_cc_detail.mcsecurecodeaav,
           p_cc_detail.softdescmercname,
           p_cc_detail.softdescproddesc,
           p_cc_detail.softdescmerccity,
           p_cc_detail.softdescmercphone,
           p_cc_detail.softdescmercurl,
           p_cc_detail.softdescmercemail,
           p_cc_detail.euddbanksortcode,
           p_cc_detail.euddcountrycode,
           p_cc_detail.euddribcode,
           p_cc_detail.euddbankbranchcode,
           p_cc_detail.euddiban,
           p_cc_detail.euddbic,
           p_cc_detail.euddmandatesignaturedate,
           p_cc_detail.euddmandateid,
           p_cc_detail.euddmandatetype,
           p_cc_detail.status,
           p_cc_detail.debitbillerreferencenumber,
           p_cc_detail.accountupdatereligibility,
           p_cc_detail.dpanind,
           p_cc_detail.tokenrequestorid,
           p_cc_detail.errorcode,
           p_cc_detail.errordesc
    FROM   TABLE(xmlsequence(l_xmltype)) t;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_servlet_data() - ' ||
	          SQLERRM;
      print_message(p_error_desc);
    
  END get_xxiby_cc_detail_row;
  --------------------------------------------------------------------------------
  -- Ver    When        Who       Description
  -- -----  ----------  --------  -------------------------------------------------
  -- 1.0    29/09/2019  Roman W.  CHG0046328
  --------------------------------------------------------------------------------
  PROCEDURE get_creditcardtranxrevers_row(p_responce_clob IN CLOB,
			      p_out_row       OUT xxiby_cc_tranx_revers_row_type,
			      p_error_code    OUT NUMBER,
			      p_error_desc    OUT VARCHAR2) IS
    -------------------------------
    --     Local Definition
    -------------------------------
    l_xmltype xmltype;
    -------------------------------
    --     Code Section
    -------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    l_xmltype := xmltype.createxml(p_responce_clob);
  
    p_out_row := xxiby_cc_tranx_revers_row_type(NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL);
  
    SELECT t.extract('/CreditCardTranxReversalServlet/Version/text()')
           .getstringval() version,
           t.extract('/CreditCardTranxReversalServlet/Bin/text()')
           .getstringval() bin,
           t.extract('/CreditCardTranxReversalServlet/MerchantID/text()')
           .getstringval() merchantid,
           t.extract('/CreditCardTranxReversalServlet/TerminalID/text()')
           .getstringval() terminalid,
           t.extract('/CreditCardTranxReversalServlet/OrderID/text()')
           .getstringval() orderid,
           t.extract('/CreditCardTranxReversalServlet/TxRefNum/text()')
           .getstringval() txrefnum,
           t.extract('/CreditCardTranxReversalServlet/TxRefIdx/text()')
           .getstringval() txrefidx,
           t.extract('/CreditCardTranxReversalServlet/RespDateTime/text()')
           .getstringval() respdatetime,
           t.extract('/CreditCardTranxReversalServlet/ProcStatus/text()')
           .getstringval() procstatus,
           t.extract('/CreditCardTranxReversalServlet/ProcStatusMessage/text()')
           .getstringval() procstatusmessage,
           t.extract('/CreditCardTranxReversalServlet/RetryTrace/text()')
           .getstringval() retrytrace,
           t.extract('/CreditCardTranxReversalServlet/RetryAttempCount/text()')
           .getstringval() retryattempcount,
           t.extract('/CreditCardTranxReversalServlet/LastRetryDate/text()')
           .getstringval() lastretrydate,
           t.extract('/CreditCardTranxReversalServlet/ApprovalStatus/text()')
           .getstringval() approvalstatus,
           t.extract('/CreditCardTranxReversalServlet/RespCode/text()')
           .getstringval() respcode,
           t.extract('/CreditCardTranxReversalServlet/HostRespCode/text()')
           .getstringval() hostrespcode,
           t.extract('/CreditCardTranxReversalServlet/ChipCardData/text()')
           .getstringval() chipcarddata,
           t.extract('/CreditCardTranxReversalServlet/ErrorCode/text()')
           .getstringval() errorcode,
           t.extract('/CreditCardTranxReversalServlet/ErrorDesc/text()')
           .getstringval() errordesc
    INTO   p_out_row.version,
           p_out_row.bin,
           p_out_row.merchantid,
           p_out_row.terminalid,
           p_out_row.orderid,
           p_out_row.txrefnum,
           p_out_row.txrefidx,
           p_out_row.respdatetime,
           p_out_row.procstatus,
           p_out_row.procstatusmessage,
           p_out_row.retrytrace,
           p_out_row.retryattempcount,
           p_out_row.lastretrydate,
           p_out_row.approvalstatus,
           p_out_row.respcode,
           p_out_row.hostrespcode,
           p_out_row.chipcarddata,
           p_out_row.errorcode,
           p_out_row.errordesc
    FROM   TABLE(xmlsequence(l_xmltype)) t;
  
    IF '0' != p_out_row.errorcode THEN
      p_error_code := 2;
      p_error_desc := substr(p_out_row.errordesc, 1, 2000);
      print_message(p_error_desc);
    ELSIF p_out_row.procstatus IS NOT NULL AND '1' = p_out_row.procstatus THEN
      p_error_code := 2;
      p_error_desc := substr(p_out_row.procstatusmessage, 1, 2000);
      print_message(p_error_desc);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := substr('EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_CreditCardTranxRevers_row() - ' ||
		     SQLERRM,
		     1,
		     2000);
    
      print_message(p_error_desc);
  END get_creditcardtranxrevers_row;

  ----------------------------------------------------------------------------------------------
  -- Ver     When          Who              Descr
  -- ------  ------------  ---------------  ----------------------------------------------------
  -- 1.0     2019/12/10    Roman W.         CHG0046663 - Show connection error
  --                                          or credit card processor rejection reason - part 2
  ----------------------------------------------------------------------------------------------
  PROCEDURE get_resp_code_oraauth(p_servlet_action    IN VARCHAR2, -- oraauth / oracapture / orareturn
		          p_approval_status   IN VARCHAR2, -- <ApprovalStatus> : 0-Declined,1-Approved,2-Message/System Error
		          p_resp_code         IN VARCHAR2, -- RespCode
		          p_resp_code_message IN VARCHAR2, -- RespCodeMessage
		          p_oapfstatus        OUT VARCHAR2, -- Approved - 0000 | Decline / Error - 0001
		          p_oapfvenderrcode   OUT VARCHAR2,
		          p_oapfvenderrmsg    OUT VARCHAR2,
		          p_error_code        OUT VARCHAR2,
		          p_error_desc        OUT VARCHAR2) IS
  
    -----------------------------
    --    Local Definition
    -----------------------------
    l_resp_code_message VARCHAR2(1000);
    l_position          NUMBER;
  
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
  
    p_oapfstatus      := NULL;
    p_oapfvenderrcode := NULL;
    p_oapfvenderrmsg  := NULL;
    p_error_code      := '0';
    p_error_desc      := NULL;
  
    IF '1' = p_approval_status THEN
      p_oapfstatus      := '0000';
      p_oapfvenderrcode := '0';
      p_oapfvenderrmsg  := 'N/A';
    ELSIF 'oraauth' = p_servlet_action AND
          ('0' = p_approval_status OR '0' = nvl(p_approval_status, '0')) THEN
    
      p_oapfstatus := '0001';
    
      IF p_resp_code_message IS NOT NULL THEN
        l_resp_code_message := TRIM(p_resp_code_message);
        l_position          := instr(l_resp_code_message, ' ', 1);
        p_oapfvenderrcode   := TRIM(substr(l_resp_code_message,
			       1,
			       l_position - 1));
        p_oapfvenderrmsg    := TRIM(substr(l_resp_code_message, l_position));
      ELSE
        SELECT xorl.resp_code,
	   xorl.definition
        INTO   p_oapfvenderrcode,
	   p_oapfvenderrmsg
        FROM   xxiby_orb_respcode_list xorl
        WHERE  xorl.resp_code = p_resp_code
        AND    xorl.servlet_action = p_servlet_action;
      END IF;
    
    ELSIF 'orareturn' = p_servlet_action AND
          ('0' = p_approval_status OR '0' = nvl(p_approval_status, '0')) THEN
    
      p_oapfstatus := '0001';
    
      IF p_resp_code_message IS NOT NULL THEN
        l_resp_code_message := TRIM(p_resp_code_message);
        l_position          := instr(l_resp_code_message, ' ', 1);
        p_oapfvenderrcode   := TRIM(substr(l_resp_code_message,
			       1,
			       l_position - 1));
        p_oapfvenderrmsg    := TRIM(substr(l_resp_code_message, l_position));
      ELSE
        SELECT xorl.resp_code,
	   xorl.definition
        INTO   p_oapfvenderrcode,
	   p_oapfvenderrmsg
        FROM   xxiby_orb_respcode_list xorl
        WHERE  xorl.resp_code = p_resp_code;
        --   and xorl.servlet_action = p_servlet_action;
      END IF;
    
    ELSIF 'oracapture' = p_servlet_action AND
          ('0' = p_approval_status OR '0' = nvl(p_approval_status, '0')) THEN
    
      p_oapfstatus := '0001';
    
      IF p_resp_code_message IS NOT NULL THEN
        l_resp_code_message := TRIM(p_resp_code_message);
        l_position          := instr(l_resp_code_message, ' ', 1);
        p_oapfvenderrcode   := TRIM(substr(l_resp_code_message,
			       1,
			       l_position - 1));
        p_oapfvenderrmsg    := TRIM(substr(l_resp_code_message, l_position));
      ELSE
        SELECT xorl.resp_code,
	   xorl.definition
        INTO   p_oapfvenderrcode,
	   p_oapfvenderrmsg
        FROM   xxiby_orb_respcode_list xorl
        WHERE  xorl.resp_code = p_resp_code;
      END IF;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_oapfstatus      := '0001';
      p_oapfvenderrcode := '66';
      p_oapfvenderrmsg  := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_resp_code_oraauth(' ||
		   p_servlet_action || ',' || p_approval_status || ',' ||
		   p_resp_code || ',' || p_resp_code_message ||
		   ') - ' || SQLERRM;
      p_error_code      := '2';
      p_error_desc      := p_oapfvenderrmsg;
    
  END get_resp_code_oraauth;

  ------------------------------------------------------
  -- Level 2                  Amex  Visa  Mastercard
  -- --------------------     ----  ----  ----------
  -- pCardOrderID             Y     Y     Y
  -- pCardDestZip             Y     Y     Y
  -- pCardDestAddress         Y     --    --
  -- pCardDestAddress2        Y     --    --
  -- pCardDestCity            Y     --    --
  -- pCardDestStateCd         Y     --    --
  ------------------------------------------------------
  -- Level 3- Header level    Amex  Visa  Mastercard
  -- ---------------------    ----  ----  ----------
  -- pCard3FreightAmt         --    Y     Y
  -- pCard3DutyAmt            --    Y     Y
  -- pCard3ShipFromZip        --    Y     Y
  -- pCard3DestCountryCd      --    Y     Y
  -- pCard3DiscAmt            --    Y     --
  -- pCard3VATtaxRate         --    Y     --
  -- pCard3VATtaxAmt          --    Y     --
  -- pCard3LineItemCount      --    Y     Y
  ------------------------------------------------------
  -- Level 3- Line item level Amex  Visa  Mastercard
  -- -----------------------  ----- ----- --------------
  -- pCard3DtlDesc            --    Y     Y
  -- pCard3DtlIndex           --    Y     Y
  -- pCard3DtlQty             --    Y     Y
  -- pCard3DtlUOM             --    Y     Y
  -- pCard3DtlProdCd          --    Y     Y
  -- pCard3DtlTaxRate         --    Y     Y
  -- pCard3DtlTaxAmt          --    Y     Y
  -- pCard3Dtllinetot         --    Y     Y
  -- pCard3DtlCommCd          --    Y     --
  -- pCard3DtlUnitCost        --    Y     Y
  -- pCard3DtlDisc            --    Y     Y
  -- pCard3DtlGrossNet        --    Y     Y
  -------------------------------------------------------

  -------------------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  -------------------------------------------
  -- 1.0   08/06/2021   Roman W.      CHG0049588 -Credit Card Chase Payment
  --                                     - add data required for level 2 and 3
  -------------------------------------------------------------------------------
  PROCEDURE validate_markforcapturetype(p_cardbrand          IN VARCHAR2,
			    p_markforcapturetype IN OUT markforcapturetype,
			    p_error_code         OUT VARCHAR2,
			    p_error_desc         OUT VARCHAR2) IS
    ---------------------------
    --   Local Definition
    ---------------------------
  
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := '';
  
    IF g_ax = p_cardbrand THEN
      -- Amex
      --- Level 3
      p_markforcapturetype.l3_pcard3freightamt    := '';
      p_markforcapturetype.l3_pcard3dutyamt       := '';
      p_markforcapturetype.l3_pcard3shipfromzip   := '';
      p_markforcapturetype.l3_pcard3destcountrycd := '';
      p_markforcapturetype.l3_pcard3discamt       := '';
      p_markforcapturetype.l3_pcard3vattaxrate    := '';
      p_markforcapturetype.l3_pcard3vattaxamt     := '';
      p_markforcapturetype.l3_pcard3lineitemcount := '';
    
    ELSIF g_mc = p_cardbrand THEN
      --- Level 3
      p_markforcapturetype.l3_pcard3discamt    := '';
      p_markforcapturetype.l3_pcard3vattaxrate := '';
      p_markforcapturetype.l3_pcard3vattaxamt  := '';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '0';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.validate_markForCaptureType() - ' ||
	          SQLERRM;
      message(p_error_desc);
  END validate_markforcapturetype;

  -------------------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  -------------------------------------------
  -- 1.0   08/06/2021   Roman W.      CHG0049588 -Credit Card Chase Payment
  --                                     - add data required for level 2 and 3
  -------------------------------------------------------------------------------
  PROCEDURE validate_pc3lineitemtype(p_cardbrand       IN VARCHAR2,
			 p_pc3lineitemtype IN OUT pc3lineitemtype,
			 p_error_code      OUT VARCHAR2,
			 p_error_desc      OUT VARCHAR2) IS
    ---------------------------
    --   Local Definition
    ---------------------------
  
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := '';
  
    IF g_mc = p_cardbrand THEN
      p_pc3lineitemtype.l3_pcard3dtlcommcd := '';
    ELSIF g_ax = p_cardbrand THEN
      p_pc3lineitemtype.l3_pcard3dtlindex    := '';
      p_pc3lineitemtype.l3_pcard3dtldesc     := '';
      p_pc3lineitemtype.l3_pcard3dtlprodcd   := '';
      p_pc3lineitemtype.l3_pcard3dtluom      := '';
      p_pc3lineitemtype.l3_pcard3dtlqty      := '';
      p_pc3lineitemtype.l3_pcard3dtltaxrate  := '';
      p_pc3lineitemtype.l3_pcard3dtltaxamt   := '';
      p_pc3lineitemtype.l3_pcard3dtllinetot  := '';
      p_pc3lineitemtype.l3_pcard3dtlcommcd   := '';
      p_pc3lineitemtype.l3_pcard3dtlunitcost := '';
      p_pc3lineitemtype.l3_pcard3dtldisc     := '';
      p_pc3lineitemtype.l3_pcard3dtlgrossnet := '';
      p_pc3lineitemtype.l3_pcard3dtldiscind  := '';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '0';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.validate_PC3LineItemType() - ' ||
	          SQLERRM;
      message(p_error_desc);
  END validate_pc3lineitemtype;

  -------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  ---------------------------------------------
  -- 1.0   22/04/2021   Roman W.    CHG0049588 -Credit Card Chase Payment
  --                                     - add data required for level 2 and 3
  --                    Ofer S. add l_markForCaptureType.l2_pCardRequestorName
  -- 1.1   10/06/2021   Roman W.    CHG0049588 - added "ORDER BY" to pCard3LineItems_cur
  -- 1.2   03.08.21     Yuval Tal   INC0238219  add new logic 
  -- 1.3   10.08.2021   yuval tal   CHG0050514 regexp on pcardorderid
  -------------------------------------------------------------------------------
  PROCEDURE get_l2_l3_json(p_orderid    IN VARCHAR2,
		   p_out_json   OUT VARCHAR2,
		   p_error_code OUT VARCHAR2,
		   p_error_desc OUT VARCHAR2) IS
    -----------------------------
    --    Local Definition
    -----------------------------
    CURSOR pcard3lineitems_cur(c_orderid VARCHAR2) IS
      SELECT rla.line_number pcard3dtlindex, --Visa Mastercard Discover
	 substr(rla.description, 1, 26) pcard3dtldesc --Visa Mastercard Discove
      FROM   oe_order_headers_all      oeh,
	 oe_payments               opt,
	 iby_trxn_summaries_all    pts,
	 oe_order_lines_all        oel,
	 ra_customer_trx_lines_all rla,
	 ra_customer_trx_all       rt
      WHERE  oeh.header_id = opt.header_id
      AND    opt.trxn_extension_id = pts.initiator_extension_id
      AND    pts.tangibleid = c_orderid
      AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
      AND    oel.header_id = oeh.header_id
      AND    rla.interface_line_attribute6 = to_char(oel.line_id)
      AND    rt.customer_trx_id = rla.customer_trx_id
      ORDER  BY rla.line_number;
  
    l_ctilevel3eligible        VARCHAR2(10);
    l_cardbrand                VARCHAR2(10);
    l_mitreceivedtransactionid VARCHAR2(120);
    l_markforcapturetype       markforcapturetype;
    l_pc3lineitemtype          pc3lineitemtype;
  
    l_markforcapturejson VARCHAR2(32000);
    l_pc3lineitemjson    VARCHAR2(32000);
    l_itemjson           VARCHAR2(32000);
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    BEGIN
      SELECT nvl(omx.ctilevel3eligible, 'N'),
	 omx.cardbrand,
	 omx.mitreceivedtransactionid
      INTO   l_ctilevel3eligible,
	 l_cardbrand,
	 l_mitreceivedtransactionid
      FROM   apps.xxiby_orbital_order_mapping omx
      WHERE  omx.order_id = p_orderid;
    EXCEPTION
      WHEN no_data_found THEN
        p_error_code := '1';
        p_error_desc := 'EXCEPTION_NO_DATA_FOUND xxiby_process_cust_paymt_pkg.get_l2_l3_json(' ||
		p_orderid || ') - ' || SQLERRM;
        message(p_error_desc);
      WHEN OTHERS THEN
        l_ctilevel3eligible := 'N';
        l_cardbrand         := NULL;
    END;
  
    -- LEVEL 2
  
    BEGIN
      SELECT
      
       regexp_replace(substr(nvl(oeh.cust_po_number, oeh.order_number),
		     1,
		     17),
	          '[^(A-Za-z0-9$@\&\,-\ )]|\?|<|>|\/|\\|[|]')
       
       pcardorderid, --INC0238219 -- All CardBrand -- CHG0050514
       substr(hl.postal_code, 1, 10) pcarddestzip, -- All CardBrand
       substr(hl.address1, 1, 30) pcarddestaddress, -- Amex
       substr(hl.address2, 1, 30) pcarddestaddress2, -- Amex
       substr(hl.city, 1, 20) pcarddestcity, -- Amex
       --    hl.state pCardDestStateCd, -- Amex INC0238219 
       -- INC0238219 
       CASE hl.country
         WHEN 'US' THEN
          hl.state
         ELSE
          NULL
       END pcarddeststatecd, -- end INC0238219 
       substr(hp.party_name, 1, 30) pcardrequestorname -- INC0238219
      
      INTO   l_markforcapturetype.l2_pcardorderid,
	 l_markforcapturetype.l2_pcarddestzip, -- All CardBrand
	 l_markforcapturetype.l2_pcarddestaddress, -- Amex
	 l_markforcapturetype.l2_pcarddestaddress2, -- Amex
	 l_markforcapturetype.l2_pcarddestcity, -- Amex
	 l_markforcapturetype.l2_pcarddeststatecd, -- Amex
	 l_markforcapturetype.l2_pcardrequestorname
      FROM   oe_order_headers_all   oeh,
	 oe_payments            opt,
	 iby_trxn_summaries_all pts,
	 hz_cust_site_uses_all  hcu,
	 hz_cust_acct_sites_all hcs,
	 hz_party_sites         hps,
	 hz_locations           hl,
	 hz_parties             hp
      WHERE  oeh.header_id = opt.header_id
      AND    opt.trxn_extension_id = pts.initiator_extension_id
      AND    pts.tangibleid = p_orderid -- p_tangibleid
      AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
      AND    hcu.site_use_id = oeh.ship_to_org_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hps.party_site_id = hcs.party_site_id
      AND    hl.location_id = hps.location_id
      AND    hp.party_id = hps.party_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_markforcapturetype.l2_pcardorderid       := NULL;
        l_markforcapturetype.l2_pcarddestzip       := NULL;
        l_markforcapturetype.l2_pcarddestaddress   := NULL;
        l_markforcapturetype.l2_pcarddestaddress2  := NULL;
        l_markforcapturetype.l2_pcarddestcity      := NULL;
        l_markforcapturetype.l2_pcarddeststatecd   := NULL;
        l_markforcapturetype.l2_pcardrequestorname := NULL;
      
    END;
  
    BEGIN
      SELECT SUM(va.tax_amt) * 100 taxamount --Mastercard
      INTO   l_markforcapturetype.l2_taxamount
      FROM   zx_lines va
      WHERE  va.application_id = 222
      AND    va.entity_code = 'TRANSACTIONS'
      AND    (va.trx_line_id, va.trx_id) IN
	 (SELECT rla.customer_trx_line_id,
	          rla.customer_trx_id
	   FROM   oe_order_headers_all      oeh,
	          oe_payments               opt,
	          iby_trxn_summaries_all    pts,
	          oe_order_lines_all        oel,
	          ra_customer_trx_lines_all rla,
	          ra_customer_trx_all       rt
	   WHERE  oeh.header_id = opt.header_id
	   AND    opt.trxn_extension_id = pts.initiator_extension_id
	   AND    pts.tangibleid = p_orderid -- p_tangibleid
	   AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
	   AND    oel.header_id = oeh.header_id
	   AND    rla.interface_line_attribute6 = to_char(oel.line_id)
	   AND    rt.customer_trx_id = rla.customer_trx_id);
    
      IF l_markforcapturetype.l2_taxamount > 0 THEN
        l_markforcapturetype.l2_taxind := '1';
      ELSE
        l_markforcapturetype.l2_taxind := '2';
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        l_markforcapturetype.l2_taxind    := 2;
        l_markforcapturetype.l2_taxamount := 0;
    END;
  
    -- LEVEL 3
    IF 'Y' = l_ctilevel3eligible THEN
      BEGIN
        SELECT SUM(rla.extended_amount) * 100 pcard3freightamt, -- Visa Mastercard
	   0 pcard3dutyamt -- Visa Mastercard
        INTO   l_markforcapturetype.l3_pcard3freightamt,
	   l_markforcapturetype.l3_pcard3dutyamt
        FROM   oe_order_headers_all      oeh,
	   oe_payments               opt,
	   iby_trxn_summaries_all    pts,
	   oe_order_lines_all        oel,
	   ra_customer_trx_lines_all rla,
	   ra_customer_trx_all       rt,
	   mtl_system_items_b        msi
        WHERE  oeh.header_id = opt.header_id
        AND    opt.trxn_extension_id = pts.initiator_extension_id
        AND    pts.tangibleid = p_orderid -- p_tangibleid
        AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
        AND    oel.header_id = oeh.header_id
        AND    rla.interface_line_attribute6 = to_char(oel.line_id)
        AND    rt.customer_trx_id = rla.customer_trx_id
        AND    msi.organization_id =
	   xxinv_utils_pkg.get_master_organization_id
        AND    msi.inventory_item_id = rla.inventory_item_id
        AND    msi.item_type = fnd_profile.value('XXAR_FREIGHT_AR_ITEM');
      EXCEPTION
        WHEN OTHERS THEN
          l_markforcapturetype.l3_pcard3freightamt := NULL;
          l_markforcapturetype.l3_pcard3dutyamt    := NULL;
      END;
    
      BEGIN
        SELECT -- hl.postal_code pcard3shipfromzip -- Visa Mastercard
         substr(hl.postal_code, 1, 10) pcard3shipfromzip -- INC0238219 
        INTO   l_markforcapturetype.l3_pcard3shipfromzip
        FROM   oe_order_headers_all   oeh,
	   oe_payments            opt,
	   iby_trxn_summaries_all pts,
	   oe_order_lines_all     oel,
	   hr_organization_units  odf,
	   hr_locations_all       hl
        WHERE  oeh.header_id = opt.header_id
        AND    opt.trxn_extension_id = pts.initiator_extension_id
        AND    pts.tangibleid = p_orderid -- p_tangibleid
        AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
        AND    oel.header_id = oeh.header_id
        AND    odf.organization_id = oel.ship_from_org_id
        AND    hl.location_id = odf.location_id
        AND    rownum = 1;
      EXCEPTION
        WHEN OTHERS THEN
          l_markforcapturetype.l3_pcard3shipfromzip := NULL;
      END;
    
      BEGIN
        SELECT ftv.iso_territory_code pcard3destcountrycd --Visa Mastercard
        INTO   l_markforcapturetype.l3_pcard3destcountrycd
        FROM   oe_order_headers_all   oeh,
	   oe_payments            opt,
	   iby_trxn_summaries_all pts,
	   hz_cust_site_uses_all  hcu,
	   hz_cust_acct_sites_all hcs,
	   hz_party_sites         hps,
	   hz_locations           hl,
	   fnd_territories_vl     ftv
        WHERE  oeh.header_id = opt.header_id
        AND    opt.trxn_extension_id = pts.initiator_extension_id
        AND    pts.tangibleid = p_orderid -- p_tangibleid
        AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
        AND    hcu.site_use_id = oeh.ship_to_org_id
        AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
        AND    hps.party_site_id = hcs.party_site_id
        AND    hl.location_id = hps.location_id
        AND    hl.country = ftv.territory_code;
      EXCEPTION
        WHEN OTHERS THEN
          l_markforcapturetype.l3_pcard3destcountrycd := NULL;
      END;
    
      BEGIN
        SELECT SUM((rla.unit_standard_price - rla.unit_selling_price) *
	       rla.quantity_invoiced) * 100 pcard3discamt --Visa
        INTO   l_markforcapturetype.l3_pcard3discamt
        FROM   oe_order_headers_all      oeh,
	   oe_payments               opt,
	   iby_trxn_summaries_all    pts,
	   oe_order_lines_all        oel,
	   ra_customer_trx_lines_all rla,
	   ra_customer_trx_all       rt
        WHERE  oeh.header_id = opt.header_id
        AND    opt.trxn_extension_id = pts.initiator_extension_id
        AND    pts.tangibleid = p_orderid -- p_tangibleid
        AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
        AND    oel.header_id = oeh.header_id
        AND    rla.interface_line_attribute6 = to_char(oel.line_id)
        AND    rt.customer_trx_id = rla.customer_trx_id;
      
        IF l_markforcapturetype.l3_pcard3discamt < 0 THEN
          l_markforcapturetype.l3_pcard3discamt := 0;
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_markforcapturetype.l3_pcard3discamt := NULL;
      END;
    
      BEGIN
        SELECT SUM(va.tax_rate) * 100 pcard3vattaxrate, --Visa
	   SUM(va.tax_amt) * 100 pcard3vattaxamt --Visa
        INTO   l_markforcapturetype.l3_pcard3vattaxrate,
	   l_markforcapturetype.l3_pcard3vattaxamt
        FROM   zx_lines va
        WHERE  va.application_id = 222
        AND    va.entity_code = 'TRANSACTIONS'
        AND    (va.trx_line_id, va.trx_id) IN
	   (SELECT rla.customer_trx_line_id,
		rla.customer_trx_id
	     FROM   oe_order_headers_all      oeh,
		oe_payments               opt,
		iby_trxn_summaries_all    pts,
		oe_order_lines_all        oel,
		ra_customer_trx_lines_all rla,
		ra_customer_trx_all       rt
	     WHERE  oeh.header_id = opt.header_id
	     AND    opt.trxn_extension_id = pts.initiator_extension_id
	     AND    pts.tangibleid = p_orderid -- p_tangibleid
	     AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
	     AND    oel.header_id = oeh.header_id
	     AND    rla.interface_line_attribute6 = to_char(oel.line_id)
	     AND    rt.customer_trx_id = rla.customer_trx_id);
      EXCEPTION
        WHEN OTHERS THEN
          l_markforcapturetype.l3_pcard3vattaxrate := NULL;
          l_markforcapturetype.l3_pcard3vattaxamt  := NULL;
      END;
    
      --- pCard3LineItemCount
      SELECT COUNT(*) pcard3lineitemcount --Visa Mastercard Discover
      INTO   l_markforcapturetype.l3_pcard3lineitemcount
      FROM   oe_order_headers_all      oeh,
	 oe_payments               opt,
	 iby_trxn_summaries_all    pts,
	 oe_order_lines_all        oel,
	 ra_customer_trx_lines_all rla,
	 ra_customer_trx_all       rt
      WHERE  oeh.header_id = opt.header_id
      AND    opt.trxn_extension_id = pts.initiator_extension_id
      AND    pts.tangibleid = p_orderid
      AND    oeh.org_id = pts.org_id
      AND    oel.header_id = oeh.header_id
      AND    rla.interface_line_attribute6 = to_char(oel.line_id)
      AND    rt.customer_trx_id = rla.customer_trx_id;
    
      IF 0 = l_markforcapturetype.l3_pcard3lineitemcount THEN
        l_markforcapturetype.l3_pcard3lineitemcount := 1;
      END IF;
    
      FOR pcard3lineitems_ind IN pcard3lineitems_cur(p_orderid)
      LOOP
      
        BEGIN
          SELECT --msi.segment1 pcard3dtlprodcd, --Visa Mastercard Discover
           substr(msi.segment1, 1, 12) pcard3dtlprodcd, -- INC0238219 
           --msi.primary_unit_of_measure pCard3DtlUOM, --Visa Mastercard Discover ---------------------------Check if match chase codes
           mmm.attribute2 pcard3dtluom,
           nvl(rla.quantity_invoiced, rla.quantity_credited) * 10000 pcard3dtlqty --Visa Mastercard Discover -
          INTO   l_pc3lineitemtype.l3_pcard3dtlprodcd,
	     l_pc3lineitemtype.l3_pcard3dtluom,
	     l_pc3lineitemtype.l3_pcard3dtlqty
          FROM   oe_order_headers_all      oeh,
	     oe_payments               opt,
	     iby_trxn_summaries_all    pts,
	     oe_order_lines_all        oel,
	     ra_customer_trx_lines_all rla,
	     ra_customer_trx_all       rt,
	     mtl_system_items_b        msi,
	     mtl_units_of_measure      mmm
          WHERE  oeh.header_id = opt.header_id
          AND    opt.trxn_extension_id = pts.initiator_extension_id
          AND    pts.tangibleid = p_orderid -- p_tangibleid
          AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
          AND    oel.header_id = oeh.header_id
          AND    rla.interface_line_attribute6 = to_char(oel.line_id)
          AND    rt.customer_trx_id = rla.customer_trx_id
          AND    msi.organization_id =
	     xxinv_utils_pkg.get_master_organization_id
          AND    msi.inventory_item_id = rla.inventory_item_id
          AND    mmm.uom_code =
	     nvl(msi.weight_uom_code, msi.primary_uom_code)
          AND    rla.line_number = pcard3lineitems_ind.pcard3dtlindex;
        
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtlprodcd := NULL;
	l_pc3lineitemtype.l3_pcard3dtluom    := NULL;
	l_pc3lineitemtype.l3_pcard3dtlqty    := NULL;
        END;
      
        BEGIN
          SELECT SUM(va.tax_rate) * 100 pcard3dtltaxrate, --Visa Mastercard Discover
	     SUM(va.tax_amt) * 100 pcard3dtltaxamt --Visa Mastercard Discover
          INTO   l_pc3lineitemtype.l3_pcard3dtltaxrate,
	     l_pc3lineitemtype.l3_pcard3dtltaxamt
          FROM   zx_lines va
          WHERE  va.application_id = 222
          AND    va.entity_code = 'TRANSACTIONS'
          AND    (va.trx_line_id, va.trx_id) IN
	     (SELECT rla.customer_trx_line_id,
		  rla.customer_trx_id
	       FROM   oe_order_headers_all      oeh,
		  oe_payments               opt,
		  iby_trxn_summaries_all    pts,
		  oe_order_lines_all        oel,
		  ra_customer_trx_lines_all rla,
		  ra_customer_trx_all       rt
	       WHERE  oeh.header_id = opt.header_id
	       AND    opt.trxn_extension_id = pts.initiator_extension_id
	       AND    pts.tangibleid = p_orderid -- p_tangibleid
	       AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
	       AND    oel.header_id = oeh.header_id
	       AND    rla.interface_line_attribute6 =
		  to_char(oel.line_id)
	       AND    rt.customer_trx_id = rla.customer_trx_id
	       AND    rla.line_number =
		  pcard3lineitems_ind.pcard3dtlindex); --&Index_Line;
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtltaxrate := NULL;
	l_pc3lineitemtype.l3_pcard3dtltaxamt  := NULL;
        END;
      
        BEGIN
          SELECT rla.extended_amount * 100 pcard3dtllinetot --Visa Mastercard Discover
          INTO   l_pc3lineitemtype.l3_pcard3dtllinetot
          FROM   oe_order_headers_all      oeh,
	     oe_payments               opt,
	     iby_trxn_summaries_all    pts,
	     oe_order_lines_all        oel,
	     ra_customer_trx_lines_all rla,
	     ra_customer_trx_all       rt
          WHERE  oeh.header_id = opt.header_id
          AND    opt.trxn_extension_id = pts.initiator_extension_id
          AND    pts.tangibleid = p_orderid -- p_tangibleid
          AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
          AND    oel.header_id = oeh.header_id
          AND    rla.interface_line_attribute6 = to_char(oel.line_id)
          AND    rt.customer_trx_id = rla.customer_trx_id
          AND    rla.line_number = pcard3lineitems_ind.pcard3dtlindex; --&Index_Line;
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtllinetot := NULL;
        END;
      
        BEGIN
          SELECT rla.unit_selling_price * 10000 pcard3dtlunitcost --Visa Mastercard Discover
          INTO   l_pc3lineitemtype.l3_pcard3dtlunitcost
          FROM   oe_order_headers_all      oeh,
	     oe_payments               opt,
	     iby_trxn_summaries_all    pts,
	     oe_order_lines_all        oel,
	     ra_customer_trx_lines_all rla,
	     ra_customer_trx_all       rt
          WHERE  oeh.header_id = opt.header_id
          AND    opt.trxn_extension_id = pts.initiator_extension_id
          AND    pts.tangibleid = p_orderid -- p_tangibleid
          AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
          AND    oel.header_id = oeh.header_id
          AND    rla.interface_line_attribute6 = to_char(oel.line_id)
          AND    rt.customer_trx_id = rla.customer_trx_id
          AND    rla.line_number = pcard3lineitems_ind.pcard3dtlindex; --&Index_Line;
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtlunitcost := NULL;
        END;
      
        BEGIN
          SELECT SUM((rla.unit_standard_price - rla.unit_selling_price) *
	         rla.quantity_invoiced) * 100 pcard3dtldisc --Visa Mastercard
          INTO   l_pc3lineitemtype.l3_pcard3dtldisc
          FROM   oe_order_headers_all      oeh,
	     oe_payments               opt,
	     iby_trxn_summaries_all    pts,
	     oe_order_lines_all        oel,
	     ra_customer_trx_lines_all rla,
	     ra_customer_trx_all       rt
          WHERE  oeh.header_id = opt.header_id
          AND    opt.trxn_extension_id = pts.initiator_extension_id
          AND    pts.tangibleid = p_orderid -- p_tangibleid
          AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
          AND    oel.header_id = oeh.header_id
          AND    rla.interface_line_attribute6 = to_char(oel.line_id)
          AND    rt.customer_trx_id = rla.customer_trx_id
          AND    rla.line_number = pcard3lineitems_ind.pcard3dtlindex; --&Index_Line;
        
          IF 0 > l_pc3lineitemtype.l3_pcard3dtldisc THEN
	l_pc3lineitemtype.l3_pcard3dtldisc := 0;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtldisc := NULL;
        END;
      
        BEGIN
          SELECT -- decode(nvl(rla.attribute10, '0'), '0', 'N', 'Y') pCard3DtlDiscInd -- Mastercard
           decode(sign(nvl(rla.attribute10, '0')), '1', 'Y', 'N') pcard3dtldiscind -- Mastercard
          INTO   l_pc3lineitemtype.l3_pcard3dtldiscind
          FROM   oe_order_headers_all      oeh,
	     oe_payments               opt,
	     iby_trxn_summaries_all    pts,
	     oe_order_lines_all        oel,
	     ra_customer_trx_lines_all rla,
	     ra_customer_trx_all       rt
          WHERE  oeh.header_id = opt.header_id
          AND    opt.trxn_extension_id = pts.initiator_extension_id
          AND    pts.tangibleid = p_orderid -- p_tangibleid
          AND    oeh.org_id = pts.org_id -- fnd_profile.value('ORG_ID')
          AND    oel.header_id = oeh.header_id
          AND    rla.interface_line_attribute6 = to_char(oel.line_id)
          AND    rt.customer_trx_id = rla.customer_trx_id
          AND    rla.line_number = pcard3lineitems_ind.pcard3dtlindex; --&Index_Line;
        EXCEPTION
          WHEN OTHERS THEN
	l_pc3lineitemtype.l3_pcard3dtldiscind := NULL;
        END;
      
        l_pc3lineitemtype.l3_pcard3dtlcommcd   := '5072';
        l_pc3lineitemtype.l3_pcard3dtlgrossnet := 'N';
        l_pc3lineitemtype.l3_pcard3dtlindex    := pcard3lineitems_ind.pcard3dtlindex;
        l_pc3lineitemtype.l3_pcard3dtldesc     := substr(pcard3lineitems_ind.pcard3dtldesc,
				         1,
				         35);
      
        IF l_itemjson IS NOT NULL THEN
          l_itemjson := l_itemjson || ',';
        END IF;
      
        validate_pc3lineitemtype(p_cardbrand       => l_cardbrand,
		         p_pc3lineitemtype => l_pc3lineitemtype,
		         p_error_code      => p_error_code,
		         p_error_desc      => p_error_desc);
      
        l_itemjson := l_itemjson || '{"pCard3DtlIndex":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlindex || '"
		,"pCard3DtlDesc":"' ||
	          l_pc3lineitemtype.l3_pcard3dtldesc || '"
		,"pCard3DtlProdCd":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlprodcd || '"
		,"pCard3DtlUOM":"' ||
	          l_pc3lineitemtype.l3_pcard3dtluom || '"
		,"pCard3DtlQty":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlqty || '"
		,"pCard3DtlTaxRate":"' ||
	          l_pc3lineitemtype.l3_pcard3dtltaxrate || '"
		,"pCard3DtlTaxAmt":"' ||
	          l_pc3lineitemtype.l3_pcard3dtltaxamt || '"
		,"pCard3Dtllinetot":"' ||
	          l_pc3lineitemtype.l3_pcard3dtllinetot || '"
		,"pCard3DtlCommCd":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlcommcd || '"
		,"pCard3DtlUnitCost":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlunitcost || '"
		,"pCard3DtlDisc":"' ||
	          l_pc3lineitemtype.l3_pcard3dtldisc || '"
		,"pCard3DtlGrossNet":"' ||
	          l_pc3lineitemtype.l3_pcard3dtlgrossnet || '"
		,"pCard3DtlDiscInd":"' ||
	          l_pc3lineitemtype.l3_pcard3dtldiscind || '"}';
      
      END LOOP;
    
      IF l_itemjson IS NULL THEN
        l_itemjson := '{
          "pCard3DtlIndex" : "",
          "pCard3DtlDesc" : "",
          "pCard3DtlProdCd" : "",
          "pCard3DtlUOM" : "",
          "pCard3DtlQty" : "",
          "pCard3DtlTaxRate" : "",
          "pCard3DtlTaxAmt" : "",
          "pCard3Dtllinetot" : "",
          "pCard3DtlCommCd" : "",
          "pCard3DtlUnitCost" : "",
          "pCard3DtlDisc" : "",
          "pCard3DtlGrossNet" : "",
          "pCard3DtlDiscInd" : ""
        }';
      END IF;
    
      validate_markforcapturetype(p_cardbrand          => l_cardbrand,
		          p_markforcapturetype => l_markforcapturetype,
		          p_error_code         => p_error_code,
		          p_error_desc         => p_error_desc);
    
      l_markforcapturejson := '"pCardOrderID":"' ||
		      l_markforcapturetype.l2_pcardorderid || '",
		       "pCardDestZip":"' ||
		      l_markforcapturetype.l2_pcarddestzip || '",
		       "pCardDestAddress":"' ||
		      l_markforcapturetype.l2_pcarddestaddress || '",
		       "pCardDestAddress2":"' ||
		      l_markforcapturetype.l2_pcarddestaddress2 || '",
		       "pCardDestCity":"' ||
		      l_markforcapturetype.l2_pcarddestcity || '",
		       "pCardDestStateCd":"' ||
		      l_markforcapturetype.l2_pcarddeststatecd || '",
		       "taxInd":"' ||
		      l_markforcapturetype.l2_taxind || '",
		       "pCardRequestorName":"' ||
		      l_markforcapturetype.l2_pcardrequestorname || '",
		       "taxAmount":"' ||
		      l_markforcapturetype.l2_taxamount || '",
		       "pCard3FreightAmt":"' ||
		      l_markforcapturetype.l3_pcard3freightamt || '",
		       "pCard3DutyAmt":"' ||
		      l_markforcapturetype.l3_pcard3dutyamt || '",
		       "pCard3ShipFromZip":"' ||
		      l_markforcapturetype.l3_pcard3shipfromzip || '",
		       "pCard3DestCountryCd":"' ||
		      l_markforcapturetype.l3_pcard3destcountrycd || '",
		       "pCard3DiscAmt":"' ||
		      l_markforcapturetype.l3_pcard3discamt || '",
		       "pCard3VATtaxRate":"' ||
		      l_markforcapturetype.l3_pcard3vattaxrate || '",
		       "pCard3VATtaxAmt":"' ||
		      l_markforcapturetype.l3_pcard3vattaxamt || '",
		       "pCard3LineItemCount":"' ||
		      l_markforcapturetype.l3_pcard3lineitemcount || '",
		       "PC3LineItemType":{"item":[' ||
		      l_itemjson || ']}';
    ELSE
      l_markforcapturejson := '"pCardOrderID":"' ||
		      l_markforcapturetype.l2_pcardorderid || '",
       "pCardDestZip":"' ||
		      l_markforcapturetype.l2_pcarddestzip || '",
       "pCardDestAddress":"' ||
		      l_markforcapturetype.l2_pcarddestaddress || '",
       "pCardDestAddress2":"' ||
		      l_markforcapturetype.l2_pcarddestaddress2 || '",
       "pCardDestCity":"' ||
		      l_markforcapturetype.l2_pcarddestcity || '",
       "pCardDestStateCd":"' ||
		      l_markforcapturetype.l2_pcarddeststatecd || '",
       "taxInd":"' ||
		      l_markforcapturetype.l2_taxind || '",
       "pCardRequestorName":"' ||
		      l_markforcapturetype.l2_pcardrequestorname || '",
       "taxAmount":"' ||
		      l_markforcapturetype.l2_taxamount || '",
       "pCard3FreightAmt":"",
       "pCard3DutyAmt":"",
       "pCard3ShipFromZip":"",
       "pCard3DestCountryCd":"",
       "pCard3DiscAmt":"",
       "pCard3VATtaxRate":"",
       "pCard3VATtaxAmt":"",
       "pCard3LineItemCount":"",
       "PC3LineItemType":{"item":[{"pCard3DtlIndex":""
		          ,"pCard3DtlDesc":""
		          ,"pCard3DtlProdCd":""
		          ,"pCard3DtlUOM":""
		          ,"pCard3DtlQty":""
		          ,"pCard3DtlTaxRate":""
		          ,"pCard3DtlTaxAmt":""
		          ,"pCard3Dtllinetot":""
		          ,"pCard3DtlCommCd":""
		          ,"pCard3DtlUnitCost":""
		          ,"pCard3DtlDisc":""
		          ,"pCard3DtlGrossNet":""
		          ,"pCard3DtlDiscInd":""}
		          ]}';
    END IF;
  
    p_out_json := l_markforcapturejson;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_l2_l3_json(' ||
	          p_orderid || ') - ' || SQLERRM;
      message(p_error_desc);
  END get_l2_l3_json;
  ------------------------
  -- cc_new_order
  -----------------------------
  --
  -- calling oic services
  -- will replace  procedure new_auth_orbital

  --  tranType A : send additional 2 param to insert_orb_trn_mapping
  --  ctiLevel3Eligible
  --  cardBrand

  /*
      -- req
      {
    "ccNewOrderReq": {
      "header": {
        "source": "source",
        "sourceId": "sourceId",
        "token": "token",
        "bin": "bin",
        "merchantID": "merchantID",
        "user": "user",
        "pass": "pass"
      },
      "newOrderDetailsReq": {
        "orderID" : "orderID",
        "transType": "TransType",
        "customerRefNum": "customerRefNum",
        "amount": "Amount",
        "industryType":"IndustryType"
      }
    }
  }
     --  resp
      {
    "ccNewOrderResp": {
      "header": {
        "source": "source",
        "sourceId": "sourceId",
        "isSuccess": "true/false",
        "message": "general message"
      },
      "newOrderDetailsResp": {
        "procStatus": "0 success",
        "procStatusMessag": "procStatusMessag",
        "respCode":"respCode",
        "txRefNum":"txRefNum",
        "approvalStatus":"approvalStatus",
        "authorizationCode":"authorizationCode",
        "profileProcStatus":"profileProcStatus",
        "profileProcStatusMsg":"profileProcStatusMsg",
        "ctiLevel3Eligible":"ctiLevel3Eligible",
        "cardBrand?:?cardBrand?,
        "respDateTime":"respDateTime",
        "orderID":"OrderID"
      }
    }
  }
  
      */
  --------------------------------------------------------------------------
  -- Procedure called from : net.payment.servlet.AuthorizationServlet.java
  --------------------------------------------------------------------------
  --  name:               cc_new_order
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      4.5.21
  --------------------------------------------------------------------------
  --  Ver   When          Who        Desc
  --  ----  ------------  ----------  --------------------------------------
  --  1.0   4.5.21        yuval tal   CHG0031464 - Procedure to check Credit Card exist or not. Taking copy from API IBY_FNDCPT_SETUP_PUB.card_exists
  --  1.1   06/04/2021    Roman W.    CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  --  1.2   23/05/2021    Roman W.    CHG0049588 - added tag "ccExp"
  --------------------------------------------------------------------------
  PROCEDURE cc_new_order(p_req      IN VARCHAR2,
		 p_resp     OUT VARCHAR2,
		 p_err_code OUT VARCHAR2,
		 p_err_msg  OUT VARCHAR2) IS
  
    l_enable_flag   VARCHAR2(1);
    l_wallet_loc    VARCHAR2(500);
    l_url           VARCHAR2(500);
    l_wallet_pwd    VARCHAR2(500);
    l_auth_user     VARCHAR2(50);
    l_auth_pwd      VARCHAR2(50);
    l_token         VARCHAR2(50);
    l_request_json  VARCHAR2(2000);
    l_http_request  utl_http.req;
    l_http_response utl_http.resp;
    l_resp          VARCHAR2(32767);
  
    l_retcode VARCHAR2(5);
  
    l_errbuf             VARCHAR2(2000);
    l_neworderdetailsreq VARCHAR2(2000);
    l_transtype          VARCHAR2(1);
    l_source             VARCHAR2(100);
    l_source_id          VARCHAR2(100);
    l_order_id           VARCHAR2(100);
    l_customerrefnum     VARCHAR2(100);
    l_trnrefnum          VARCHAR2(100);
    l_amount             VARCHAR2(100);
    l_industry_type      VARCHAR2(100);
    l_trx_err_code       VARCHAR2(1);
    l_trx_err_message    VARCHAR2(1000);
  
    exception_resp_not200          EXCEPTION;
    exception_req_not_valid        EXCEPTION;
    exception_trxrefnum_not_found  EXCEPTION;
    exception_insert_trx_in_oracle EXCEPTION;
    exception_oic_fatal            EXCEPTION;
    exception_ccexp_missing        EXCEPTION;
  
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
  
    l_ctilevel3eligible         VARCHAR2(120); -- CHG0049588
    l_cardbrand                 VARCHAR2(120); -- CHG0049588
    l_mitreceivedtransactionid  VARCHAR2(120); -- CHG0049588
    l_mitsubmittedtransactionid VARCHAR2(120); -- CHG0049588
    l_ccexp                     VARCHAR2(120); -- CHG0049588
  BEGIN
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
    
      l_xxiby_cc_debug_tbl.request_json := p_req;
      l_xxiby_cc_debug_tbl.step         := '1';
      l_xxiby_cc_debug_tbl.db_location  := 'xxiby_process_cust_paymt_pkg.cc_new_order';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
    BEGIN
      SELECT newordreq,
	 SOURCE,
	 transtype,
	 source_id,
	 customerrefnum,
	 amount,
	 industry_type,
	 order_id
      INTO   l_neworderdetailsreq,
	 l_source,
	 l_transtype,
	 l_source_id,
	 l_customerrefnum,
	 l_amount,
	 l_industry_type,
	 l_order_id
      
      FROM   json_table(p_req,
		'$.ccNewOrderReq'
		columns(newordreq format json path
		        '$.newOrderDetailsReq',
		        SOURCE VARCHAR2(100) path '$.header.source',
		        source_id VARCHAR2(100) path
		        '$.header.sourceId',
		        transtype VARCHAR2(50) path
		        '$.newOrderDetailsReq.transType',
		        customerrefnum VARCHAR2(100) path
		        '$.newOrderDetailsReq.customerRefNum',
		        amount VARCHAR2(100) path
		        '$.newOrderDetailsReq.amount',
		        industry_type VARCHAR2(100) path
		        '$.newOrderDetailsReq.industryType',
		        order_id VARCHAR2(100) path
		        '$.newOrderDetailsReq.orderID')) AS jt;
    
      -- validate
      IF l_neworderdetailsreq IS NULL THEN
        p_err_msg := 'l_neworderdetailsreq is null:' || p_req;
        RAISE exception_req_not_valid;
      END IF;
    
      IF l_order_id IS NULL THEN
        p_err_msg := 'order_id is null:' || p_req;
        RAISE exception_req_not_valid;
      END IF;
    
      IF l_transtype IS NULL THEN
        p_err_msg := 'transtype is null:' || p_req;
        RAISE exception_req_not_valid;
      END IF;
    
      IF l_customerrefnum IS NULL AND 'oraauth' = l_source THEN
        p_err_msg := 'customerRefNum is null:' || p_req;
        RAISE exception_req_not_valid;
      END IF;
    
      IF 'R' = l_transtype THEN
        get_orb_trnrefnum(p_ordernumber => l_order_id,
		  p_trnrefnum   => l_trnrefnum,
		  p_err_code    => p_err_code,
		  p_err_message => p_err_msg);
      
        IF l_trnrefnum IS NULL OR p_err_code = 1 THEN
          p_err_msg := 'trnrefnum is null or failed to get its value' ||
	           p_err_msg;
          RAISE exception_trxrefnum_not_found;
          -- ELSE
          --     l_customerrefnum := l_trnrefnum;
        END IF;
      
        get_ccexp(p_order_id   => l_order_id,
	      p_ccexp      => l_ccexp,
	      p_error_code => p_err_code,
	      p_error_desc => p_err_msg);
      
        IF p_err_code != 0 THEN
          RAISE exception_ccexp_missing;
        END IF;
      
      END IF;
    
      IF l_industry_type IS NULL THEN
        l_industry_type := get_industry_type;
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        p_err_msg := 'Error parsing reqest:' || p_req;
        RAISE exception_req_not_valid;
    END;
  
    xxssys_oic_util_pkg.get_service_details2('CC_NEW_ORDER',
			         l_enable_flag,
			         l_url,
			         l_wallet_loc,
			         l_wallet_pwd,
			         l_auth_user,
			         l_auth_pwd,
			         l_token,
			         l_retcode,
			         l_errbuf);
  
    message('get_service_details' || ' ' || l_retcode || ' ' || l_url);
  
    IF 0 != l_retcode THEN
      p_resp := get_ccneworderresp_err_json(p_orderid          => l_order_id,
			        p_sourceid         => l_source_id,
			        p_procstatusmessag => l_errbuf);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.source_name   := l_source;
        l_xxiby_cc_debug_tbl.step          := '2';
        l_xxiby_cc_debug_tbl.db_location   := 'xxiby_process_cust_paymt_pkg.cc_new_order';
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      
      END IF;
    
      RETURN;
    
    END IF;
  
    BEGIN
    
      SELECT xoom.mitreceivedtransactionid
      INTO   l_mitsubmittedtransactionid
      FROM   xxiby_orbital_order_mapping xoom
      WHERE  xoom.order_id = l_order_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_mitsubmittedtransactionid := '';
    END;
  
    --  parse params from p_req
  
    -- get trnsRefNo from order id
  
    --- buile new req json for oic
  
    l_request_json := '{"ccNewOrderReq": ' || '{"header": {' ||
	          '"source"  : "EBS"' || ',"sourceId": "' ||
	          l_source_id || '","token": "' || l_token ||
	          '","bin": "' || get_binvalue || '","merchantID": "' ||
	          get_merchantid || '","terminalID":"' ||
	          get_terminalid || '","user": "user"' ||
	          ',"pass": "pass"},' || '"newOrderDetailsReq": ' ||
	          '{"orderID" : "' || l_order_id || '","transType": "' ||
	          l_transtype || '","customerRefNum": "' ||
	          ltrim(TRIM(l_customerrefnum), '0') ||
	          '","txRefNum": "' || l_trnrefnum || '","amount": "' ||
	          l_amount || '","industryType":"' || l_industry_type ||
	          '","ccExp":"' || l_ccexp ||
	          '","mitSubmittedTransactionID":"' ||
	          l_mitsubmittedtransactionid || '"' || '}}}';
  
    message(l_request_json);
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.source_name      := l_source;
      l_xxiby_cc_debug_tbl.request_json_oic := l_request_json;
      l_xxiby_cc_debug_tbl.step             := '3';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
    --- call oic
  
    utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
    l_http_request := utl_http.begin_request(l_url, 'POST');
  
    utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
  
    utl_http.set_header(l_http_request,
		'Content-Length',
		length(l_request_json));
    utl_http.set_header(l_http_request, 'Content-Type', 'application/json');
  
    ---------------------
  
    utl_http.write_text(r => l_http_request, data => l_request_json);
  
    ---------------------------
    l_http_response := utl_http.get_response(l_http_request);
  
    message(' ------------------------');
    message('Http.status_code=' || l_http_response.status_code);
    message('------------------------');
  
    /*
    IF l_http_response.status_code != '200' THEN
      p_err_msg := 'http response =' || l_http_response.status_code;
      RAISE exception_resp_not200;
    END IF;
    --
    */
    BEGIN
      -- LOOP
      utl_http.read_text(l_http_response, l_resp, 32766);
      message(l_resp);
      --  END LOOP;
      utl_http.end_response(l_http_response);
    EXCEPTION
      WHEN utl_http.end_of_body THEN
        utl_http.end_response(l_http_response);
      WHEN OTHERS THEN
        message('EXCEPTION_OTHERS :' || SQLERRM);
    END;
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
    
      l_xxiby_cc_debug_tbl.response_json_oic := l_resp;
      l_xxiby_cc_debug_tbl.step              := '4';
    
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
    parse_ccneworderresp_json_resp(p_responcein  => l_resp,
		           p_responceout => l_resp,
		           p_error_code  => l_retcode,
		           p_error_desc  => l_errbuf);
    /*
    IF instr(l_resp, '<TITLE>Error') > 0 THEN
      p_err_msg := l_resp;
      RAISE exception_oic_fatal;
    END IF;
    */
    SELECT decode(nvl(issuccess, 'true'), 'true', '0', '1'),
           'flow_id=' || flowid || ' ' || substr(message, 1, 200),
           trnrefnum,
           ctilevel3eligible,
           cardbrand,
           mitreceivedtransactionid
    INTO   p_err_code,
           p_err_msg,
           l_trnrefnum,
           l_ctilevel3eligible, -- CHG0049588
           l_cardbrand, -- CHG0049588
           l_mitreceivedtransactionid -- CHG0049588
    FROM   json_table(l_resp,
	          '$.ccNewOrderResp.header[*]'
	          columns(issuccess VARCHAR2(50) path '$.isSuccess',
		      message VARCHAR2(3000) path '$.message',
		      flowid VARCHAR2(30) path '$.flowId')) jt,
           
           json_table(l_resp,
	          '$.ccNewOrderResp.newOrderDetailsResp[*]'
	          columns(trnrefnum VARCHAR2(3000) path '$.txRefNum',
		      ctilevel3eligible VARCHAR2(10) path
		      '$.ctiLevel3Eligible',
		      cardbrand VARCHAR2(10) path '$.cardBrand',
		      mitreceivedtransactionid VARCHAR2(120) path
		      '$.mitReceivedTransactionID')) d;
  
    p_resp := l_resp;
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
    
      l_xxiby_cc_debug_tbl.response_json := p_resp;
      l_xxiby_cc_debug_tbl.step          := '5';
    
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
    IF p_err_code = 1 THEN
      RETURN;
    END IF;
  
    IF p_err_code = '0' AND l_transtype = 'A' THEN
    
      xxiby_process_cust_paymt_pkg.insert_orb_trn_mapping(p_ordernumber              => l_order_id, --PSON Number
				          p_trnrefnum                => l_trnrefnum, --40 Digit Transaction Number
				          p_orbital_token            => l_customerrefnum,
				          p_ctilevel3eligible        => l_ctilevel3eligible,
				          p_cardbrand                => l_cardbrand,
				          p_mitreceivedtransactionid => l_mitreceivedtransactionid,
				          p_err_code                 => l_trx_err_code,
				          p_err_message              => l_trx_err_message);
    
      -- pass response to invoker
      IF l_trx_err_code != 0 THEN
        -- return err json
        p_err_msg := 'insert_orb_trn_mapping failed ' || l_trx_err_message;
        RAISE exception_insert_trx_in_oracle;
      
      END IF;
    
    END IF;
  
    ---
  
    utl_http.end_response(l_http_response);
  
  EXCEPTION
    WHEN exception_ccexp_missing THEN
      p_resp := get_ccneworderresp_err_json(p_orderid          => l_order_id,
			        p_sourceid         => l_source_id,
			        p_procstatusmessag => p_err_msg);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.step          := '6';
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
    WHEN exception_trxrefnum_not_found THEN
      p_resp := get_ccneworderresp_err_json(p_orderid          => l_order_id,
			        p_sourceid         => l_source_id,
			        p_procstatusmessag => p_err_msg);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.step          := '6';
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
    WHEN exception_req_not_valid THEN
      p_resp := get_ccneworderresp_err_json(p_orderid          => l_order_id,
			        p_sourceid         => l_source_id,
			        p_procstatusmessag => p_err_msg);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.step          := '6';
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
    WHEN OTHERS THEN
    
      utl_http.end_response(l_http_response);
    
      p_err_code := '2';
      p_err_msg  := 'EXCEPTION_OTHERS in xxiby_process_cust_paymt_pkg.cc_new_order: ' ||
	        substr(p_err_msg || SQLERRM, 1, 500);
    
      p_resp := get_ccneworderresp_err_json(p_orderid          => l_order_id,
			        p_sourceid         => l_source_id,
			        p_procstatusmessag => p_err_msg);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.step          := '5';
        l_xxiby_cc_debug_tbl.error_msg     := p_err_msg;
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
  END cc_new_order;

  ---------------------------------
  -- Procedure called from : net.payment.servlet.AuthorizationServlet.java
  --
  -- L3 check
  -- Fx( TxRefNum) - xxiby_mapping???? --> Y/N + brand
  -- in case Y
  -- per card brand we need to send diff additional data
  -- visa : x,y,z
  -- american express  : x,f,g
  --
  ----------------------------------------------------------------------
  -- Ver   Date          Name            Desc
  -- ----  ------------  --------------  -------------------------------
  -- 1.0   4.5.21        yuval tal       CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  -- 1.0   06/04/2021    Roman W.        CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  -----------------------------------------------------------------------
  PROCEDURE cc_mfc(p_req      IN CLOB,
	       p_resp     OUT CLOB,
	       p_err_code OUT VARCHAR2,
	       p_err_msg  OUT VARCHAR2) IS
  
    l_enable_flag   VARCHAR2(1);
    l_wallet_loc    VARCHAR2(500);
    l_url           VARCHAR2(500);
    l_wallet_pwd    VARCHAR2(500);
    l_auth_user     VARCHAR2(50);
    l_auth_pwd      VARCHAR2(50);
    l_token         VARCHAR2(50);
    l_request_json  VARCHAR2(32000);
    l_http_request  utl_http.req;
    l_http_response utl_http.resp;
    l_resp          VARCHAR2(32767);
  
    l_retcode VARCHAR2(5);
  
    l_errbuf             VARCHAR2(2000);
    l_servlet_mfcreq_req VARCHAR2(2000);
    l_source_id          VARCHAR2(100);
    exception_resp_not200   EXCEPTION;
    exception_req_not_valid EXCEPTION;
  
    l_headerreq headerreq;
    l_mfcreq    mfcreq;
    l_ccmfcreq  ccmfcreq;
  
    l_ccmfcresp          ccmfcresp;
    l_headerresp         headerresp;
    l_mfcresp            mfcresp;
    l_row_id             NUMBER;
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
  BEGIN
    p_err_code := '0';
    p_err_msg  := NULL;
  
    --- Debug --
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.request_json := p_req;
      l_xxiby_cc_debug_tbl.step         := '1';
      l_xxiby_cc_debug_tbl.db_location  := 'xxiby_process_cust_paymt_pkg.cc_mfc';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
    ---------------------------------------
    -----      GET OIC DETAILS      -------
    ---------------------------------------
    xxssys_oic_util_pkg.get_service_details2(p_service     => 'CC_MFC',
			         p_enable_flag => l_enable_flag,
			         p_url         => l_url,
			         p_wallet_loc  => l_wallet_loc,
			         p_wallet_pwd  => l_wallet_pwd,
			         p_auth_user   => l_auth_user,
			         p_auth_pwd    => l_auth_pwd,
			         p_token       => l_token,
			         p_error_code  => l_retcode,
			         p_error_desc  => l_errbuf);
  
    IF l_retcode != 0 THEN
      l_ccmfcresp                := NULL;
      l_headerresp               := NULL;
      l_mfcresp                  := NULL;
      l_mfcresp.procstatus       := '1';
      l_mfcresp.procstatusmessag := l_errbuf;
    
      l_ccmfcresp.pheaderresp := l_headerresp;
      l_ccmfcresp.pmfcresp    := l_mfcresp;
    
      p_resp := get_mfc_responce_json(p_ccmfcresp => l_ccmfcresp);
    
      utl_http.end_response(l_http_response);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.step          := '2';
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.error_msg     := l_errbuf;
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      RETURN;
    END IF;
  
    ---------------------------------------
    -------- REQUEST JSON PARSING  -------
    ---------------------------------------
    parse_ccmfcreq_json_request(p_json       => p_req,
		        p_ccmfcreq   => l_ccmfcreq,
		        p_error_code => p_err_code,
		        p_error_desc => p_err_msg);
  
    IF '0' != p_err_code THEN
      l_ccmfcresp                := NULL;
      l_headerresp               := NULL;
      l_mfcresp                  := NULL;
      l_mfcresp.procstatus       := '1';
      l_mfcresp.procstatusmessag := p_err_msg;
    
      l_ccmfcresp.pheaderresp := l_headerresp;
      l_ccmfcresp.pmfcresp    := l_mfcresp;
    
      p_resp := get_mfc_responce_json(p_ccmfcresp => l_ccmfcresp);
    
      utl_http.end_response(l_http_response);
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.step          := '3';
        l_xxiby_cc_debug_tbl.response_json := p_resp;
        l_xxiby_cc_debug_tbl.error_msg     := p_err_msg;
      
        IF l_ccmfcreq.pheaderreq.source IS NOT NULL THEN
          l_xxiby_cc_debug_tbl.source_name := l_ccmfcreq.pheaderreq.source;
        END IF;
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      RETURN;
    
    ELSE
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.step         := '4';
        l_xxiby_cc_debug_tbl.source_name  := l_ccmfcreq.pheaderreq.source;
        l_xxiby_cc_debug_tbl.request_json := l_request_json;
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      --- Set Header --
      l_ccmfcreq.pheaderreq.source   := 'EBS';
      l_ccmfcreq.pheaderreq.sourceid := l_source_id;
      --l_ccMFCReq.pHeaderReq.token      := 'dev';
      l_ccmfcreq.pheaderreq.bin        := get_binvalue;
      l_ccmfcreq.pheaderreq.merchantid := get_merchantid;
      l_ccmfcreq.pheaderreq.terminalid := get_terminalid;
      l_ccmfcreq.pheaderreq.token      := l_token;
      l_ccmfcreq.pheaderreq.user       := 'user';
      l_ccmfcreq.pheaderreq.pass       := 'pass';
    
      get_mfc_request_json(p_ccmfcreq         => l_ccmfcreq,
		   p_out_json_request => l_request_json,
		   p_error_code       => p_err_code,
		   p_error_desc       => p_err_msg);
    
      IF '0' != p_err_code THEN
        p_resp := get_mfc_error_responce_json(p_err_msg);
        RETURN;
      END IF;
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.step             := '5';
        l_xxiby_cc_debug_tbl.request_json_oic := l_request_json;
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      message(l_request_json);
    END IF;
  
    utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
    l_http_request := utl_http.begin_request(l_url, 'POST');
  
    utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
  
    -- utl_http.set_header(l_http_request, 'Proxy-Connection', 'Keep-Alive');
    utl_http.set_header(l_http_request,
		'Content-Length',
		length(l_request_json));
    utl_http.set_header(l_http_request, 'Content-Type', 'application/json');
  
    utl_http.write_text(r => l_http_request, data => l_request_json);
  
    l_http_response := utl_http.get_response(l_http_request);
  
    message('------------------------');
    message('Http.status_code=' || l_http_response.status_code);
    message('------------------------');
    /*
    IF l_http_response.status_code != '200' THEN
      p_err_msg := 'http response =' || l_http_response.status_code;
      RAISE exception_resp_not200;
    END IF;
    */
    BEGIN
      -- LOOP
      utl_http.read_text(l_http_response, l_resp, 32766);
      message(l_resp);
      --  END LOOP;
      utl_http.end_response(l_http_response);
    EXCEPTION
      WHEN utl_http.end_of_body THEN
        utl_http.end_response(l_http_response);
    END;
  
    p_resp := get_mfc_responce_json(l_resp);
    utl_http.end_response(l_http_response);
  
    --- Debug --
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      l_xxiby_cc_debug_tbl.step          := '6';
      l_xxiby_cc_debug_tbl.response_json := p_resp;
    
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '1';
      p_err_msg  := 'Error in xxiby_process_cust_paymt_pkg.cc_mfc: ' ||
	        substr(p_err_msg || SQLERRM, 1, 500);
    
      l_ccmfcresp                           := NULL;
      l_ccmfcresp.pmfcresp.procstatus       := '1';
      l_ccmfcresp.pmfcresp.procstatusmessag := p_err_msg;
    
      p_resp := get_mfc_responce_json(l_ccmfcresp);
    
      utl_http.end_response(l_http_response);
    
      --- Debug --
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        l_xxiby_cc_debug_tbl.step          := '7';
        l_xxiby_cc_debug_tbl.response_json := p_resp;
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
  END cc_mfc;

  --------------------------------------------
  -- cc_reversal
  -- purpose : oic replace of  cancel_void_orbital
  ----------------------------------------------------------------------
  --  ver   date          name          desc
  --  ---   ----------    -----------   --------------------------------
  --  1.0   4.5.21        yuval tal     CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  --  1.1   16/06/2021    Roman W.                        Addedd debug
  -----------------------------------------------------------------------
  PROCEDURE cc_reversal(p_merchantid    IN VARCHAR2,
		p_bin           IN VARCHAR2,
		p_terminalid    IN VARCHAR2,
		p_pson          IN VARCHAR2,
		p_cancel_amount IN NUMBER,
		p_txrefnum      IN VARCHAR2,
		p_err_code      OUT VARCHAR2,
		p_err_msg       OUT VARCHAR2) IS
  
    l_enable_flag   VARCHAR2(1);
    l_wallet_loc    VARCHAR2(500);
    l_url           VARCHAR2(500);
    l_wallet_pwd    VARCHAR2(500);
    l_auth_user     VARCHAR2(50);
    l_auth_pwd      VARCHAR2(50);
    l_token         VARCHAR2(50);
    l_request_json  VARCHAR2(2000);
    l_http_request  utl_http.req;
    l_http_response utl_http.resp;
    l_resp          VARCHAR2(32767);
  
    l_retcode VARCHAR2(5);
  
    l_errbuf VARCHAR2(2000);
    exception_resp_not200 EXCEPTION;
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
  
  BEGIN
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
    
      l_xxiby_cc_debug_tbl.request_json := 'p_merchantid =' || p_merchantid || ',' ||
			       'p_bin = ' || p_bin || ',' ||
			       'p_terminalid = ' ||
			       p_terminalid || ',' ||
			       'p_pson = ' || p_pson || ',' ||
			       'p_cancel_amount = ' ||
			       p_cancel_amount || ',' ||
			       'p_txrefnum = ' || p_txrefnum;
    
      l_xxiby_cc_debug_tbl.step        := '1';
      l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.cc_reversal';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
  
    /*
    -- resp
    
    {
      "ccReversalResp": {
        "header": {
          "source": "source",
          "sourceId": "sourceId",
          "isSuccess": "true/false",
          "message": "general message"
        },
        "ReversalDetailsResp": {
          "procStatus":"0 success",
          "procStatusMessag":  "procStatusMessag"
        }
      }
    }
    
    
    */
  
    xxssys_oic_util_pkg.get_service_details2('CC_REVERSAL',
			         l_enable_flag,
			         l_url,
			         l_wallet_loc,
			         l_wallet_pwd,
			         l_auth_user,
			         l_auth_pwd,
			         l_token,
			         l_retcode,
			         l_errbuf);
  
    message('get_service_details' || ' ' || l_retcode || ' ' || l_url);
    IF l_retcode = 0 THEN
      -- log file tag used for download and currentDate used for upload
      l_request_json := ' {
      "ccReversalReq": {
        "header": {' || '
           "source"  : "EBS"' || ',
          "sourceId": "",
          "token": "' || l_token || '",
          "bin": "' || p_bin || '",
          "merchantID": "' || p_merchantid || '",
          "terminalID":"' || p_terminalid || '",
          "user": "user",
          "pass": "pass"
        },
        "reversalDetailsReq": {
          "orderId": "' || p_pson || '",
          "cancelAamount": "' || p_cancel_amount || '",
          "trnsRefNo":"' || p_txrefnum || '"
        }
      }
    }';
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json_oic := l_request_json;
      
        l_xxiby_cc_debug_tbl.step := '2';
      
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      message(l_request_json);
      --- call oic
    
      utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
      l_http_request := utl_http.begin_request(l_url, 'POST');
    
      utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
    
      -- utl_http.set_header(l_http_request, 'Proxy-Connection', 'Keep-Alive');
      utl_http.set_header(l_http_request,
		  'Content-Length',
		  length(l_request_json));
      utl_http.set_header(l_http_request,
		  'Content-Type',
		  'application/json');
    
      ---------------------
    
      utl_http.write_text(r => l_http_request, data => l_request_json);
    
      ---------------------------
      l_http_response := utl_http.get_response(l_http_request);
    
      message('------------------------');
      message('Http.status_code=' || l_http_response.status_code);
      message('------------------------');
      IF l_http_response.status_code != '200' THEN
        p_err_msg := 'http response =' || l_http_response.status_code;
        RAISE exception_resp_not200;
      END IF;
      --
    
      BEGIN
        -- LOOP
        utl_http.read_text(l_http_response, l_resp, 32766);
        message(l_resp);
        --  END LOOP;
        utl_http.end_response(l_http_response);
      
        IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        
          l_xxiby_cc_debug_tbl.response_json_oic := l_resp;
        
          l_xxiby_cc_debug_tbl.step := '3';
        
          debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	    p_error_code         => p_err_code,
	    p_error_desc         => p_err_msg);
        
        END IF;
      
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          utl_http.end_response(l_http_response);
      END;
    
      IF instr(l_resp, '<TITLE>Error') > 0 THEN
        p_err_code := 2;
        p_err_msg  := l_resp;
      ELSE
      
        SELECT decode(nvl(issuccess, 'true'), 'true', '0', '2'),
	   'flow_id=' || flowid || ' ' || substr(message, 1, 200)
        
        INTO   p_err_code,
	   p_err_msg
        
        FROM   json_table(l_resp,
		  '$.ccReversalResp.header[*]'
		  columns(issuccess VARCHAR2(50) path '$.isSuccess',
		          message VARCHAR2(3000) path '$.message',
		          flowid VARCHAR2(3000) path '$.flowId')) jt,
	   json_table(l_resp,
		  --'$.ccProfileFetchResp.ReversalDetailsResp[*]'
		  '$.ccReversalResp.ReversalDetailsResp[*]'
		  columns(procstatus VARCHAR2(50) path
		          '$.procStatus',
		          procstatusmessag VARCHAR2(2000) path
		          '$.procStatusMessag')) resp;
      
        -- p_resp := l_resp;
      
        --- validations
      
        IF p_err_code = '2' THEN
          RETURN;
        END IF;
      
        ---
      END IF;
    
      utl_http.end_response(l_http_response);
    ELSE
    
      p_err_code := '2';
      p_err_msg  := l_errbuf;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      message('get_detailed_sqlerrm' || utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      p_err_code := '2';
      p_err_msg  := 'Error in xxiby_process_cust_paymt_pkg.cc_reversal: ' ||
	        substr(p_err_msg || SQLERRM, 1, 250);
    
  END;
  ------------------------------------
  -- cc_profile_fetch
  -- will replace get_cc_details
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   4.5.21        yuval tal       CHG0049588 -Credit Card Chase Payment - add data required for level 2 and 3
  -----------------------------------------------------------------------
  PROCEDURE cc_profile_fetch(p_customerrefnum IN NUMBER, --Use Token Value here
		     p_resp           OUT CLOB,
		     p_err_code       OUT VARCHAR2,
		     p_err_msg        OUT VARCHAR2,
		     p_customername   OUT VARCHAR2, --from XML response
		     p_ccexp          OUT DATE, --from XML response
		     p_ccaccountnum   OUT VARCHAR2, --from XML response
		     p_card_type      OUT VARCHAR2, --from XML response
		     p_cc_last4digit  OUT VARCHAR2 --from XML response
		     ) IS
    l_enable_flag VARCHAR2(1);
    l_wallet_loc  VARCHAR2(500);
    l_url         VARCHAR2(500);
    l_wallet_pwd  VARCHAR2(500);
    l_auth_user   VARCHAR2(50);
    l_auth_pwd    VARCHAR2(50);
  
    l_request_json  VARCHAR2(2000);
    l_http_request  utl_http.req;
    l_http_response utl_http.resp;
    l_resp          VARCHAR2(32767);
    l_token         VARCHAR2(50);
    l_retcode       VARCHAR2(5);
  
    l_errbuf VARCHAR2(2000);
    exception_resp_not200 EXCEPTION;
  
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
  
    l_json_tbl       apex_json.t_values;
    l_source         VARCHAR2(300);
    l_sourceid       VARCHAR2(300);
    l_flowid         VARCHAR2(300);
    l_issuccess      VARCHAR2(300);
    l_customerrefnum VARCHAR2(300);
    l_profileaction  VARCHAR2(300);
    l_procstatus     VARCHAR2(300);
    l_ccexp          VARCHAR2(300);
    l_ccaccountnum   VARCHAR2(300);
  BEGIN
  
    IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
    
      l_xxiby_cc_debug_tbl.request_json := 'p_customerrefnum = ' ||
			       p_customerrefnum;
    
      l_xxiby_cc_debug_tbl.step        := '1';
      l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.cc_profile_fetch';
      debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	p_error_code         => p_err_code,
	p_error_desc         => p_err_msg);
    END IF;
    /*
    --Payload  - response
    
    { "ccProfileFetchResp" : { "header":
     {     "source"  : "source","sourceId"    : "sourceId",
    "isSuccess"   : "true/false",
    "flowId":"flowId",
    "message"  :     "general message"},
    "profileDetailsResp" :
    {"customerRefNum"   : "??"      ,
    "customerName":"customername",
    "profileAction"   : "??" ,
    "procStatus"   : "??" ,
    "ccExp"   : "??" ,
    "ccAccountNum"   : "xx "}}}
    */
  
    xxssys_oic_util_pkg.get_service_details2('CC_PROFILE_FETCH',
			         l_enable_flag,
			         l_url,
			         l_wallet_loc,
			         l_wallet_pwd,
			         l_auth_user,
			         l_auth_pwd,
			         l_token,
			         l_retcode,
			         l_errbuf);
  
    message('get_service_details' || ' ' || l_retcode || ' ' || l_url);
    IF l_retcode = 0 THEN
    
      -- log file tag used for download and currentDate used for upload
      l_request_json := '
    { "ccProfileFetchReq" : { "header": {
     "source"  : "EBS","sourceId":"' ||
		p_customerrefnum || '","token": "' || l_token || '",
    "bin"  :"' || get_binvalue || '",
    "merchantID"  : "' || get_merchantid ||
		'","user" : "user",
        "pass" : "pass"},
        "profileDetailsReq" :{"customerRefNum"   : "' ||
		p_customerrefnum || '"}}}';
    
      message(l_request_json);
      --- call oic
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.request_json_oic := l_request_json;
      
        l_xxiby_cc_debug_tbl.step        := '2';
        l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.cc_profile_fetch';
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
      l_http_request := utl_http.begin_request(l_url, 'POST');
    
      utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
    
      -- utl_http.set_header(l_http_request, 'Proxy-Connection', 'Keep-Alive');
      utl_http.set_header(l_http_request,
		  'Content-Length',
		  length(l_request_json));
      utl_http.set_header(l_http_request,
		  'Content-Type',
		  'application/json');
    
      ---------------------
    
      utl_http.write_text(r => l_http_request, data => l_request_json);
    
      ---------------------------
      l_http_response := utl_http.get_response(l_http_request);
    
      message('------------------------');
      message('Http.status_code=' || l_http_response.status_code);
      message('------------------------');
      /*
      IF l_http_response.status_code != '200' THEN
        p_err_msg := 'http response =' || l_http_response.status_code;
        RAISE exception_resp_not200;
      END IF;
      */
      --
    
      BEGIN
        -- LOOP
        utl_http.read_text(l_http_response, l_resp, 32766);
        message(l_resp);
        --  END LOOP;
        utl_http.end_response(l_http_response);
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          utl_http.end_response(l_http_response);
      END;
    
      IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
      
        l_xxiby_cc_debug_tbl.response_json_oic := l_resp;
      
        l_xxiby_cc_debug_tbl.step        := '3';
        l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.cc_profile_fetch';
        debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	  p_error_code         => p_err_code,
	  p_error_desc         => p_err_msg);
      END IF;
    
      IF instr(l_resp, '<TITLE>Error') > 0 THEN
        p_err_code := 1;
        p_err_msg  := l_resp;
      ELSE
        /*
        apex_json.parse(p_values => l_json_tbl, p_source => l_resp);
        l_source         := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.header.source',
                                                   p_values => l_json_tbl);
        l_sourceId       := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.header.sourceId',
                                                   p_values => l_json_tbl);
        l_flowId         := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.header.flowId',
                                                   p_values => l_json_tbl);
        l_isSuccess      := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.header.isSuccess',
                                                   p_values => l_json_tbl);
        l_customerRefNum := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.profileDetailsResp.customerRefNum',
                                                   p_values => l_json_tbl);
        l_profileAction  := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.profileDetailsResp.profileAction',
                                                   p_values => l_json_tbl);
        l_procStatus     := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.profileDetailsResp.procStatus',
                                                   p_values => l_json_tbl);
        l_ccExp          := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.profileDetailsResp.ccExp',
                                                   p_values => l_json_tbl);
        l_ccAccountNum   := apex_json.get_varchar2(p_path   => 'ccProfileFetchResp.profileDetailsResp.ccAccountNum',
        
        p_values => l_json_tbl);
        */
      
        SELECT decode(nvl(issuccess, 'true'), 'true', '0', '1'),
	   'flow_id=' || flowid || ' ' || substr(message, 1, 200),
	   last_day(to_date(ccexp, 'YYYYMM')),
	   ccaccountnum,
	   substr(to_char(ccaccountnum), -4, 4),
	   customername
        
        INTO   p_err_code,
	   p_err_msg,
	   p_ccexp,
	   p_ccaccountnum,
	   p_cc_last4digit,
	   p_customername
        
        FROM   json_table(l_resp,
		  '$.ccProfileFetchResp.header[*]'
		  columns(issuccess VARCHAR2(50) path '$.isSuccess',
		          message VARCHAR2(3000) path '$.message',
		          flowid VARCHAR2(3000) path '$.flowId')) jt,
	   json_table(l_resp,
		  '$.ccProfileFetchResp.profileDetailsResp[*]'
		  columns(customerrefnum VARCHAR2(50) path
		          '$.customerRefNum',
		          customername VARCHAR2(500) path
		          '$.customerName',
		          profileaction VARCHAR2(50) path
		          '$.profileAction',
		          ccexp VARCHAR2(50) path '$.ccExp',
		          ccaccountnum VARCHAR2(50) path
		          '$.ccAccountNum')) resp;
        p_resp := l_resp;
      
        IF 'Y' = fnd_profile.value('XXIBY_CC_DEBUG') THEN
        
          l_xxiby_cc_debug_tbl.response_json := l_resp;
        
          l_xxiby_cc_debug_tbl.step        := '4';
          l_xxiby_cc_debug_tbl.db_location := 'xxiby_process_cust_paymt_pkg.cc_profile_fetch';
          debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
	    p_error_code         => p_err_code,
	    p_error_desc         => p_err_msg);
        END IF;
        --- validations
      
        IF p_err_code = '1' THEN
          RETURN;
        END IF;
      
        IF p_ccaccountnum IS NULL THEN
          p_err_code := 1;
          p_err_msg  := 'Account number is empty for TOKEN ( ' ||
		p_customerrefnum || ' )';
          RETURN;
        END IF;
      
        ---
      
        p_card_type    := xxiby_process_cust_paymt_pkg.get_credit_card_type(REPLACE(p_ccaccountnum,
							'X',
							'0'));
        g_cc_card_type := p_card_type; -- copied from get_cc_details
        --
      
      END IF;
      utl_http.end_response(l_http_response);
    ELSE
    
      p_err_code := '1';
      p_err_msg  := l_errbuf;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      message('get_detailed_sqlerrm' || utl_http.get_detailed_sqlerrm);
      utl_http.end_response(l_http_response);
      p_err_code := '1';
      p_err_msg  := 'Error in xxiby_process_cust_paymt_pkg.cc_profile_fetch: ' ||
	        substr(p_err_msg || SQLERRM, 1, 250);
    
  END cc_profile_fetch;
  -------------------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  --------------------------------------------------
  -- 1.0   04/04/2021   Roman W.     CHG0049588 - cc
  -------------------------------------------------------------------------------------
  PROCEDURE get_mfc_request_json(p_ccmfcreq         IN ccmfcreq,
		         p_out_json_request OUT VARCHAR2,
		         p_error_code       OUT VARCHAR2,
		         p_error_desc       OUT VARCHAR2) IS
    ---------------------------
    --    Local Definition
    ---------------------------
    l_json_request              VARCHAR2(32000);
    l_headerreq                 headerreq;
    l_mfcreq                    mfcreq;
    l_markforcapturetypereqjson VARCHAR(32000);
    l_error_code                VARCHAR2(100);
    l_error_desc                VARCHAR2(4000);
    ---------------------------
    --    Code Section
    ---------------------------
  BEGIN
    l_headerreq := p_ccmfcreq.pheaderreq;
    l_mfcreq    := p_ccmfcreq.pmfcreq;
  
    get_l2_l3_json(p_orderid    => l_mfcreq.orderid,
	       p_out_json   => l_markforcapturetypereqjson,
	       p_error_code => p_error_code,
	       p_error_desc => p_error_desc);
    IF 0 != p_error_code THEN
      RETURN;
    END IF;
  
    p_out_json_request := '{"ccMFCReq":{
"header":{
"source":"' || nvl(l_headerreq.source, '') || '",
"sourceId":"' || nvl(l_headerreq.sourceid, '') || '",
"token":"' || nvl(l_headerreq.token, '') || '",
"bin":"' || nvl(l_headerreq.bin, '') || '",
"merchantID":"' || nvl(l_headerreq.merchantid, '') || '",
"terminalID":"' || nvl(l_headerreq.terminalid, '') || '",
"user":"' || nvl(l_headerreq.user, '') || '",
"pass":"' || nvl(l_headerreq.pass, '') || '"
},
"MFCReq":{
"txRefNum":"' || nvl(l_mfcreq.txrefnum, '') || '",
"version": "' || nvl(l_mfcreq.version, '') || '",
"amount":"' || nvl(l_mfcreq.amount, '') || '",
"orderID":"' || nvl(l_mfcreq.orderid, '') || '",' ||
		  l_markforcapturetypereqjson || '}}}';
  
  END get_mfc_request_json;
  -----------------------------------------------------------------------------------------
  -- Ver    When         Who          Descr
  -- -----  -----------  ----------   -----------------------------------------------------
  -- 1.0    2021/04/04   Roman W.     CHG0049588 - cc
  -----------------------------------------------------------------------------------------
  PROCEDURE parse_ccmfcreq_json_request(p_json       IN VARCHAR2,
			    p_ccmfcreq   OUT ccmfcreq,
			    p_error_code OUT VARCHAR2,
			    p_error_desc OUT VARCHAR2) IS
    --------------------------
    --   Local Definition
    --------------------------
    l_json_tbl apex_json.t_values;
    l_json     VARCHAR2(32676);
    --------------------------
    --     Codec Section
    --------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
    l_json       := p_json;
  
    apex_json.parse(p_values => l_json_tbl, p_source => l_json);
    ------ ccMFCReq.header
    p_ccmfcreq.pheaderreq.source     := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.source',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.sourceid   := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.sourceId',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.token      := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.token',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.bin        := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.bin',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.merchantid := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.merchantID',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.user       := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.user',
					   p_values => l_json_tbl);
    p_ccmfcreq.pheaderreq.pass       := apex_json.get_varchar2(p_path   => 'ccMFCReq.header.pass',
					   p_values => l_json_tbl);
  
    ------ ccMFCReq.MFCReq
    IF apex_json.does_exist(p_values => l_json_tbl,
		    p_path   => 'ccMFCReq.mfcreq') THEN
    
      p_ccmfcreq.pmfcreq.txrefnum := apex_json.get_varchar2(p_path   => 'ccMFCReq.mfcreq.txRefNum',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.version  := apex_json.get_varchar2(p_path   => 'ccMFCReq.mfcreq.version',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.amount   := apex_json.get_varchar2(p_path   => 'ccMFCReq.mfcreq.amount',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.orderid  := apex_json.get_varchar2(p_path   => 'ccMFCReq.mfcreq.orderID',
					p_values => l_json_tbl);
    ELSIF apex_json.does_exist(p_values => l_json_tbl,
		       p_path   => 'ccMFCReq.MFCReq') THEN
      p_ccmfcreq.pmfcreq.txrefnum := apex_json.get_varchar2(p_path   => 'ccMFCReq.MFCReq.txRefNum',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.version  := apex_json.get_varchar2(p_path   => 'ccMFCReq.MFCReq.version',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.amount   := apex_json.get_varchar2(p_path   => 'ccMFCReq.MFCReq.amount',
					p_values => l_json_tbl);
      p_ccmfcreq.pmfcreq.orderid  := apex_json.get_varchar2(p_path   => 'ccMFCReq.MFCReq.orderID',
					p_values => l_json_tbl);
    
    END IF;
  
    IF p_ccmfcreq.pmfcreq.txrefnum IS NULL AND
       p_ccmfcreq.pmfcreq.orderid IS NOT NULL THEN
      xxiby_process_cust_paymt_pkg.get_orb_trnrefnum(p_ordernumber => p_ccmfcreq.pmfcreq.orderid,
				     p_trnrefnum   => p_ccmfcreq.pmfcreq.txrefnum,
				     p_err_code    => p_error_code,
				     p_err_message => p_error_desc);
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.parse_ccMFCReq_json_request(' ||
	          p_json || ') - ' || SQLERRM;
  END parse_ccmfcreq_json_request;

  ------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  -------------------------------------
  -- 1.0   29/04/2021   Roman W.     CHG0049588 - cc
  ------------------------------------------------------------------------
  FUNCTION get_mfc_error_responce_json(p_error_desc VARCHAR2) RETURN VARCHAR2 IS
  
    -------------------------
    --    Local Definition
    -------------------------
    l_json_response VARCHAR2(2000);
    -------------------------
    --    Code Section
    -------------------------
  BEGIN
    l_json_response := '{"ccMFCResp":{
    "header":{
    "source":"' || '",
    "sourceId":"' || '",
    "isSuccess":"' || '",
    "message":"' || '"
    },
    "mfcresp":{
    "procStatus":"1",
    "procStatusMessag":"' || p_error_desc || '",
    "respCode":"",
    "txRefNum":"",
    "approvalStatus":"",
    "authorizationCode":"",
    "profileProcStatus":"",
    "profileProcStatusMsg":""
    }}}';
    RETURN l_json_response;
  
  END get_mfc_error_responce_json;
  ------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  -------------------------------------
  -- 1.0   29/04/2021   Roman W.     CHG0049588 - cc
  ------------------------------------------------------------------------
  FUNCTION get_mfc_responce_json(p_resp VARCHAR2) RETURN VARCHAR2 IS
    -------------------------
    --   Local Definition
    -------------------------
    l_json_response VARCHAR2(32000);
    l_headerresp    headerresp;
    l_ccmfcresp     ccmfcresp;
    l_mfcresp       mfcresp;
    l_error_code    VARCHAR2(10);
    l_error_desc    VARCHAR2(32000);
    -------------------------
    --   Code Section
    -------------------------
  BEGIN
    l_json_response := NULL;
  
    parse_ccmfcresp_json_responce(p_json       => p_resp,
		          p_ccmfcresp  => l_ccmfcresp,
		          p_error_code => l_error_code,
		          p_error_desc => l_error_desc);
  
    IF '0' != l_error_code THEN
      l_json_response := get_mfc_error_responce_json(l_error_desc);
    ELSE
    
      l_json_response := '{"ccMFCResp":{
"header":{
"source":"' ||
		 nvl(l_ccmfcresp.pheaderresp.source, '') || '",
"sourceId":"' ||
		 nvl(l_ccmfcresp.pheaderresp.sourceid, '') || '",
"isSuccess":"' ||
		 nvl(l_ccmfcresp.pheaderresp.issuccess, '') || '",
"message":"' ||
		 nvl(l_ccmfcresp.pheaderresp.message, '') || '"
},
"mfcresp":{
"procStatus":"' ||
		 nvl(l_ccmfcresp.pmfcresp.procstatus, '') || '",
"procStatusMessag":"' ||
		 nvl(l_ccmfcresp.pmfcresp.procstatusmessag, '') || '",
"respCode":"' ||
		 nvl(l_ccmfcresp.pmfcresp.respcode, '') || '",
"txRefNum":"' ||
		 nvl(l_ccmfcresp.pmfcresp.txrefnum, '') || '",
"approvalStatus":"' ||
		 nvl(l_ccmfcresp.pmfcresp.approvalstatus, '') || '",
"authorizationCode":"' ||
		 nvl(l_ccmfcresp.pmfcresp.authorizationcode, '') || '",
"profileProcStatus":"' ||
		 nvl(l_ccmfcresp.pmfcresp.profileprocstatus, '') || '",
"profileProcStatusMsg":"' ||
		 nvl(l_ccmfcresp.pmfcresp.profileprocstatusmsg, '') || '"
}}}';
    END IF;
    RETURN l_json_response;
  
  END get_mfc_responce_json;
  ----------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  -----------------------------------------
  -- 1.0   04/04/2021   Roman W.     CHG0049588 - cc
  ----------------------------------------------------------------------------
  FUNCTION get_mfc_responce_json(p_ccmfcresp ccmfcresp) RETURN VARCHAR2 IS
    ----------------------------
    --    Local Definition
    ----------------------------
    l_json_response VARCHAR2(2000);
    l_headerresp    headerresp;
    l_mfcresp       mfcresp;
    ----------------------------
    --    Code Section
    ----------------------------
  BEGIN
    l_headerresp := p_ccmfcresp.pheaderresp;
    l_mfcresp    := p_ccmfcresp.pmfcresp;
  
    l_json_response := '{"ccMFCResp":{
"header":{
"source":"' || nvl(l_headerresp.source, '') || '",
"sourceId":"' || nvl(l_headerresp.sourceid, '') || '",
"isSuccess":"' || nvl(l_headerresp.issuccess, '') || '",
"message":"' || nvl(l_headerresp.message, '') || '"
},
"mfcresp":{
"procStatus":"' || nvl(l_mfcresp.procstatus, '') || '",
"procStatusMessag":"' ||
	           nvl(l_mfcresp.procstatusmessag, '') || '",
"respCode":"' || nvl(l_mfcresp.respcode, '') || '",
"txRefNum":"' || nvl(l_mfcresp.txrefnum, '') || '",
"approvalStatus":"' ||
	           nvl(l_mfcresp.approvalstatus, '') || '",
"authorizationCode":"' ||
	           nvl(l_mfcresp.authorizationcode, '') || '",
"profileProcStatus":"' ||
	           nvl(l_mfcresp.profileprocstatus, '') || '",
"profileProcStatusMsg":"' ||
	           nvl(l_mfcresp.profileprocstatusmsg, '') || '"
}}}';
  
    RETURN l_json_response;
  END get_mfc_responce_json;
  --------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  -----------------------------------------
  -- 1.0   05/04/2021   Roman W.   CHG0049588 - cc
  --------------------------------------------------------------------------
  PROCEDURE parse_ccmfcresp_json_responce(p_json       IN VARCHAR2,
			      p_ccmfcresp  OUT ccmfcresp,
			      p_error_code OUT VARCHAR2,
			      p_error_desc OUT VARCHAR2) IS
    ---------------------------
    --    Local Definition
    ---------------------------
    l_json_tbl   apex_json.t_values;
    l_json       VARCHAR2(32676);
    l_headerresp headerresp := NULL;
    l_mfcresp    mfcresp;
    l_json_flag  VARCHAR2(10);
    l_body_index NUMBER;
    l_html       VARCHAR2(32000);
    ---------------------------
    --    Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
    l_json       := p_json;
  
    --------------------------------------------------------
    /*
    {ccMFCResp":{
    "header":{
    "source":"",
    "sourceId":"",
    "isSuccess":"",
    "message":""
    },
    "MFCResp":{
    "procStatus":"",
    "procStatusMessag":"",
    "respCode":"",
    "txRefNum":"",
    "approvalStatus":"",
    "authorizationCode":"",
    "profileProcStatus":"",
    "profileProcStatusMsg":""
    }}}
    */
    --------------------------------------------------------
    l_json_flag := 'Y';
    BEGIN
      apex_json.parse(p_values => l_json_tbl, p_source => l_json);
    EXCEPTION
      WHEN OTHERS THEN
        l_json_flag := 'N';
    END;
  
    IF 'Y' = l_json_flag THEN
      ------ ccMFCReq.header
      p_ccmfcresp.pheaderresp.source    := apex_json.get_varchar2(p_path   => 'ccMFCResp.header.source',
					      p_values => l_json_tbl);
      p_ccmfcresp.pheaderresp.sourceid  := apex_json.get_varchar2(p_path   => 'ccMFCResp.header.sourceId',
					      p_values => l_json_tbl);
      p_ccmfcresp.pheaderresp.issuccess := apex_json.get_varchar2(p_path   => 'ccMFCResp.header.isSuccess',
					      p_values => l_json_tbl);
      p_ccmfcresp.pheaderresp.message   := apex_json.get_varchar2(p_path   => 'ccMFCResp.header.message',
					      p_values => l_json_tbl);
    
      ------ ccMFCReq.MFCReq
      p_ccmfcresp.pmfcresp.procstatus       := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.procStatus',
					          p_values => l_json_tbl);
      p_ccmfcresp.pmfcresp.procstatusmessag := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.procStatusMessag',
					          p_values => l_json_tbl);
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.respCode',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.respcode := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.respCode',
					    p_values => l_json_tbl);
      END IF;
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.txRefNum',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.txrefnum := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.txRefNum',
					    p_values => l_json_tbl);
      END IF;
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.approvalStatus',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.approvalstatus := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.approvalStatus',
					          p_values => l_json_tbl);
      END IF;
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.authorizationCode',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.authorizationcode := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.authorizationCode',
						 p_values => l_json_tbl);
      END IF;
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.profileProcStatus',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.profileprocstatus := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.profileProcStatus',
						 p_values => l_json_tbl);
      END IF;
    
      IF apex_json.does_exist(p_path   => 'ccMFCResp.MFCResp.profileProcStatusMsg',
		      p_values => l_json_tbl) THEN
        p_ccmfcresp.pmfcresp.profileprocstatusmsg := apex_json.get_varchar2(p_path   => 'ccMFCResp.MFCResp.profileProcStatusMsg',
						    p_values => l_json_tbl);
      END IF;
    
    ELSE
      l_body_index := instr(upper(l_json), '<BODY');
      l_html       := substr(str1 => l_json,
		     pos  => 1,
		     len  => l_body_index - 1) || '</HTML>';
    
      l_html := regexp_replace(l_html, '<[^>]*>', '');
      l_html := regexp_replace(l_html, '[[:cntrl:]]', '');
      l_html := TRIM(l_html);
    
      l_mfcresp                  := NULL;
      l_mfcresp.procstatus       := '1';
      l_mfcresp.procstatusmessag := l_html;
      p_ccmfcresp.pheaderresp    := NULL;
      p_ccmfcresp.pmfcresp       := l_mfcresp;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.parse_ccMFCResp_json_responce(' ||
	          p_json || ') - ' || SQLERRM;
  END parse_ccmfcresp_json_responce;
  ---------------------------------------------------------------------------
  --
  ---------------------------------------------------------------------------
  PROCEDURE parse_ccneworderresp_json_resp(p_responcein  IN VARCHAR2,
			       p_responceout OUT VARCHAR2,
			       p_error_code  OUT VARCHAR2,
			       p_error_desc  OUT VARCHAR2) IS
    ---------------------------
    --   Local Definition
    ---------------------------
    l_json_tbl   apex_json.t_values;
    l_json_flag  VARCHAR2(10);
    l_json       VARCHAR2(32000);
    l_body_index NUMBER;
    l_html       VARCHAR2(32000);
    l_error_code VARCHAR2(100);
    l_error_desc VARCHAR2(2000);
    l_order_id   VARCHAR2(100);
    l_trnrefnum  VARCHAR2(100);
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
    l_json       := p_responcein;
    l_json_flag  := 'Y';
    BEGIN
      apex_json.parse(p_values => l_json_tbl, p_source => l_json);
    EXCEPTION
      WHEN OTHERS THEN
        l_json_flag := 'N';
    END;
  
    IF 'Y' = l_json_flag THEN
      p_responceout := p_responcein;
      /*
      SELECT decode(nvl(issuccess, 'true'), 'true', '0', '1'),
             'flow_id=' || flowid || ' ' || substr(message, 1, 200),
             orderid,
             trnrefnum
        INTO l_error_code, l_error_desc, l_order_id, l_trnrefnum
        FROM json_table(l_json,
                        '$.ccNewOrderResp.header[*]'
                        columns(issuccess VARCHAR2(50) path '$.isSuccess',
                                message VARCHAR2(3000) path '$.message',
                                flowid VARCHAR2(30) path '$.flowId')) jt,
             json_table(l_json,
                        '$.ccNewOrderResp.newOrderDetailsResp[*]'
                        columns(orderid VARCHAR2(50) path '$.orderId',
                                trnrefnum VARCHAR2(3000) path '$.txRefNum')) d;
      */
    
    ELSE
      l_body_index := instr(upper(l_json), '<BODY');
      l_html       := substr(str1 => l_json,
		     pos  => 1,
		     len  => l_body_index - 1) || '</HTML>';
    
      l_html := regexp_replace(l_html, '<[^>]*>', '');
      l_html := regexp_replace(l_html, '[[:cntrl:]]', '');
      l_html := TRIM(l_html);
    
      p_responceout := get_ccneworderresp_err_json(p_orderid          => '',
				   p_sourceid         => '',
				   p_procstatusmessag => l_html);
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_responceout := get_ccneworderresp_err_json(p_orderid          => '',
				   p_sourceid         => '',
				   p_procstatusmessag => 'EXCEPTION_OTHERS parse_ccNewOrderResp_json_resp()-' ||
						 SQLERRM);
    
  END parse_ccneworderresp_json_resp;
  ---------------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  ---------------------------------------
  -- 1.0   13/04/2021   Roman W.      CHG0049588 - cc
  ---------------------------------------------------------------------------
  FUNCTION get_ccneworderresp_err_json(p_orderid          IN VARCHAR2,
			   p_sourceid         IN VARCHAR2,
			   p_procstatusmessag IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_json VARCHAR2(32000) := NULL;
  BEGIN
  
    l_json := '{
      "ccNewOrderResp": {
        "header": {
          "source": "EBS",
          "sourceId": "' || p_sourceid || '",
          "isSuccess": "false",
          "message": "' || p_procstatusmessag || '"
        },
        "newOrderDetailsResp": {
          "procStatus": "1",
          "procStatusMessag": "' || p_procstatusmessag || '",
          "respCode":"",
          "txRefNum":"",
          "approvalStatus":"",
          "authorizationCode":"",
          "profileProcStatus":"",
          "profileProcStatusMsg":"",
          "cardBrand":"",
          "respDateTime":"",
          "orderID":"' || p_orderid || '",
          "ctiLevel3Eligible":"",
          "cardBrand":""
        }
      }
    }';
  
    RETURN l_json;
  
  END get_ccneworderresp_err_json;
  ------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ---------  --------------------------------------
  -- 1.0   2021/04/20   Roman W.   CHG0049588 - cc
  ------------------------------------------------------------------------
  PROCEDURE debug(p_msg        IN VARCHAR2,
	      p_error_code OUT VARCHAR2,
	      p_error_desc OUT VARCHAR2) IS
    ------------------------
    --   Local Definition
    ------------------------
    l_xxiby_cc_debug_tbl xxiby_cc_debug_tbl%ROWTYPE;
    ------------------------
    --   Code Section
    ------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    l_xxiby_cc_debug_tbl.step        := '1';
    l_xxiby_cc_debug_tbl.db_location := p_msg;
  
    debug(p_xxiby_cc_debug_tbl => l_xxiby_cc_debug_tbl,
          p_error_code         => p_error_code,
          p_error_desc         => p_error_desc);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.debug(' ||
	          p_msg || ') - ' || SQLERRM;
    
  END debug;
  ---------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  ------------------------------------------
  -- 1.0   07/04/2021  Roman W.    CHG0049588 - cc
  ---------------------------------------------------------------------------
  PROCEDURE debug(p_xxiby_cc_debug_tbl IN OUT xxiby_cc_debug_tbl%ROWTYPE,
	      p_error_code         OUT VARCHAR2,
	      p_error_desc         OUT VARCHAR2) IS
    -------------------------
    --   Local Definition
    -------------------------
  
    -------------------------
    --     Code Section
    -------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    IF p_xxiby_cc_debug_tbl.row_id IS NULL THEN
      INSERT INTO xxiby_cc_debug_tbl
        (step,
         db_location,
         source_name,
         request_json,
         response_json,
         error_msg)
      VALUES
        (p_xxiby_cc_debug_tbl.step,
         p_xxiby_cc_debug_tbl.db_location,
         p_xxiby_cc_debug_tbl.source_name,
         p_xxiby_cc_debug_tbl.request_json,
         p_xxiby_cc_debug_tbl.response_json,
         p_xxiby_cc_debug_tbl.error_msg)
      RETURNING row_id INTO p_xxiby_cc_debug_tbl.row_id;
    ELSE
      UPDATE xxiby_cc_debug_tbl xcdt
      SET    xcdt.step             = p_xxiby_cc_debug_tbl.step,
	 xcdt.source_name      = p_xxiby_cc_debug_tbl.source_name,
	 xcdt.request_json_oic = p_xxiby_cc_debug_tbl.request_json_oic,
	 xcdt.response_json    = p_xxiby_cc_debug_tbl.response_json,
	 xcdt.error_msg        = p_xxiby_cc_debug_tbl.error_msg
      WHERE  xcdt.row_id = p_xxiby_cc_debug_tbl.row_id;
    END IF;
    COMMIT;
  END debug;

  --------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  -----------------------------------
  -- 1.0   13/05/2021  Roman W.    CHG0049588 - cc
  --------------------------------------------------------------------
  FUNCTION get_industry_type RETURN VARCHAR2 IS
    -------------------------
    --   Local Definition
    -------------------------
    l_industry_type VARCHAR2(120);
    -------------------------
    --   Code Section
    -------------------------
  BEGIN
    SELECT ibv.account_option_value
    INTO   l_industry_type
    FROM   iby_bepinfo           ibb,
           iby_bep_acct_opt_vals ibv
    WHERE  ibb.name = 'OrbitalPaymentSystem'
    AND    ibv.bepid = ibb.bepid
    AND    ibv.account_option_code = 'industryType';
  
    RETURN l_industry_type;
  
  END get_industry_type;

  ---------------------------------------------------------------------
  -- Ver   When         Who            Descr
  -- ----  -----------  -------------  --------------------------------
  -- 1.0   20/05/2021   Roman W.       CHG0049588 - cc
  -- 1.1   14/06/2021   Roman W.       CHG0049588 - cc
  --                                      cahnged to new SQL
  ---------------------------------------------------------------------
  PROCEDURE get_ccexp(p_order_id   IN VARCHAR2,
	          p_ccexp      OUT VARCHAR2,
	          p_error_code OUT VARCHAR,
	          p_error_desc OUT VARCHAR) IS
    ---------------------------
    --    Code Section
    ---------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
    /*
    SELECT to_char(ic.expirydate, 'YYYYMM')
      into p_ccExp
      FROM apps.xxiby_orbital_order_mapping omx, iby_creditcard ic
     WHERE omx.order_id = p_order_id --'AR1145187'
       and ic.ccnumber = omx.orbital_token;
     */
  
    SELECT to_char(ic.expirydate, 'YYYYMM')
    INTO   p_ccexp
    FROM   apps.xxiby_orbital_order_mapping omx,
           iby_creditcard                   ic,
           iby_trxn_summaries_all           ats
    WHERE  omx.order_id = p_order_id --'ONT1103216' --*\'AR1145187'
    AND    ic.ccnumber = lpad(omx.orbital_token, 16, '0')
    AND    ats.tangibleid = omx.order_id
    AND    ic.card_owner_id = ats.payerid
    AND    rownum = 1;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_ccexp      := NULL;
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxiby_process_cust_paymt_pkg.get_ccExp(' ||
	          p_order_id || ') - ' || SQLERRM;
      message(p_error_desc);
    
  END get_ccexp;

END xxiby_process_cust_paymt_pkg;
/
