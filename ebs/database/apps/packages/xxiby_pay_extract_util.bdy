create or replace package body xxiby_pay_extract_util IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXIBY_PAY_EXTRACT_UTIL.bdy
  Author's Name:   Sandeep Akula
  Date Written:    02-JAN-2015
  Purpose:         Payment Extract Process Utilities
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JAN-2015        1.0                  Sandeep Akula    Initial Version (CHG0032794)
  28-JUL-2015        1.1                  Sandeep Akula    Modified Function get_pmt_ext_agg  -- CHG0035411
  21-FEB-2017        1.2                  Sandeep Patel    Modified Function get_pmt_ext_agg -- CHG0040041
  19-SEP-2018    	 1.3				  Bellona(TCS)     Modified Function GET_ACK_EMAIL and GET_L2_ACK_EMAIL -- CHG0043682
														   Added new profile option
  ---------------------------------------------------------------------------------------------------*/

  g_dist_list   VARCHAR2(200) := fnd_profile.value('XXOBJT_ACK_EMAIL_DIST_LIST');  
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    IS_WELLSFARGO_BANK_ACCOUNT
  Author's Name:   Sandeep Akula
  Date Written:    02-JAN-2015
  Purpose:         This Function checks if the BankAccount associated with the Payment is listed in Lookup XXWAP_WELLSFARGO_BANK
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0032794
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION is_wellsfargo_bank_account(p_payment_id IN NUMBER) RETURN VARCHAR2 IS

    lc_flag                 VARCHAR2(1) := 'N';
    lc_pymnt_instruction_id NUMBER;
  BEGIN

    -- Code Copied from Package XXWAP_GET_PMT_EXT_AGG (Wells Fargo Adapter)
    BEGIN
      SELECT 'Y'
	 /* Added by Asma Ayesha (Sierra Atlantic) as on 6-May-09 to capture the Payments and its associated Instruction */,
	 ipa.payment_instruction_id
      INTO   lc_flag,
	 lc_pymnt_instruction_id
      FROM   fnd_lookup_values flv1,
	 ce_bank_accounts  cba,
	 iby_payments_all  ipa,
	 fnd_application   fa
      WHERE  flv1.meaning = cba.bank_account_name
      AND    flv1.lookup_type = 'XXWAP_WELLSFARGO_BANK'
      AND    cba.bank_account_id = ipa.internal_bank_account_id
      AND    flv1.enabled_flag = 'Y'
      AND    trunc(SYSDATE) BETWEEN
	 trunc(nvl(flv1.start_date_active, SYSDATE - 1)) AND
	 trunc(nvl(flv1.end_date_active, SYSDATE + 1))
      AND    ipa.payment_id = p_payment_id
      AND    flv1.language = userenv('LANG')
      AND    fa.application_id = flv1.view_application_id
      AND    fa.application_short_name = 'SQLAP';

    EXCEPTION
      WHEN OTHERS THEN
        lc_flag := 'N';
    END;

    RETURN(lc_flag);

  END is_wellsfargo_bank_account;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    IS_WELLSFARGO_PAYMENT_TYPE
  Author's Name:   Sandeep Akula
  Date Written:    02-JAN-2015
  Purpose:         This Function checks if the Payment Method associated with the Payment is listed in Lookup XXWAP_WELLSFARGO_PAYMENT_TYPES
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0032794
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION is_wellsfargo_payment_type(p_payment_id IN NUMBER) RETURN VARCHAR2 IS
    lc_pymnt_flag VARCHAR(2) := 'N';
  BEGIN

    -- Code Copied from Package XXWAP_GET_PMT_EXT_AGG (Wells Fargo Adapter)
    BEGIN
      SELECT 'Y'
      INTO   lc_pymnt_flag
      FROM   fnd_lookup_values flv,
	 iby_payments_all  ipa,
	 fnd_application   fa
      WHERE  flv.lookup_code = ipa.payment_method_code
      AND    flv.lookup_type = 'XXWAP_WELLSFARGO_PAYMENT_TYPES'
      AND    trunc(SYSDATE) BETWEEN
	 trunc(nvl(flv.start_date_active, SYSDATE - 1)) AND
	 trunc(nvl(flv.end_date_active, SYSDATE + 1))
      AND    flv.enabled_flag = 'Y'
      AND    flv.language = userenv('LANG')
      AND    fa.application_id = flv.view_application_id
      AND    fa.application_short_name = 'SQLAP'
      AND    ipa.payment_id = p_payment_id;
    EXCEPTION
      WHEN OTHERS THEN
        lc_pymnt_flag := 'N';
    END;

    RETURN(lc_pymnt_flag);

  END is_wellsfargo_payment_type;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_pmt_ext_agg
  Author's Name:   Sandeep Akula
  Date Written:    02-JAN-2015
  Purpose:         This Function generates XML Structure custom to JPMC Bank Payment File
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0032794
  28-JUL-2015        1.1                  Sandeep Akula     Added Cursor c_payment_reasons  -- CHG0035411
                                                            Added a new XML tag XXPaymentReasons under parent tag XXOutboundPayment -- CHG0035411
                                                            Added SQL to get Bank Account Type Tag from Lookup BANK_ACCOUNT_TYPE -- CHG0035411
                                                            Added a new XML tag XXBankAccountTypeTag under parent tag XXOutboundPayment -- CHG0035411
                                                            Added a new XML tag XXPayeeBankAccount under parent tag XXOutboundPayment -- CHG0035411
                                                            Added a new XML tag XXPayee under parent tag XXOutboundPayment -- CHG0035411
                                                            Added a new XML tag XXDocumentPayable under parent tag XXOutboundPayment -- CHG0035411
   21-FEB-2017        1.2                  Sandeep Patel   Changed length in variable l_invoices so that only 140 characters show up in the Unstructed XML Tag
  ----------------------------------------------------------------------------------------------------*/
  FUNCTION get_pmt_ext_agg(p_payment_id IN NUMBER) RETURN xmltype IS

  -- Added Cursor Statement 28-JUL-2015 SAkula CHG0035411
  Cursor c_payment_reasons is
  select distinct iprv.meaning
  from IBY_DOCS_PAYABLE_ALL idp,
       IBY_PAYMENT_REASONS_VL iprv
  where idp.payment_reason_code = iprv.payment_reason_code(+) and
        idp.payment_id = p_payment_id;

  -- Added Cursor Statement 20-AUG-2015 SAkula CHG0035411
  Cursor c_invoices is
  select UTL_I18N.TRANSLITERATE(calling_app_doc_ref_number,'fwkatakana_hwkatakana') calling_app_doc_ref_number
  from iby_docs_payable_all
  where payment_id = p_payment_id;


    l_pmt_ext_agg      xmltype;
    l_branch_type      VARCHAR2(50);
    l_servicelevelcode VARCHAR2(100);
    l_payment_reasons VARCHAR2(200); -- Added Variable 28-JUL-2015 SAkula CHG0035411
    l_bank_account_type fnd_lookup_values_vl.tag%type; -- Added Variable 13-AUG-2015 SAkula CHG0035411
    l_payment_info     payments_rec; -- Added Variable 20-AUG-2015 SAkula CHG0035411
    l_invoices        VARCHAR2(32767); -- Added Variable 20-AUG-2015 SAkula CHG0035411
  BEGIN

    l_branch_type := '';
    BEGIN
      SELECT cbb.bank_branch_type
      INTO   l_branch_type
      FROM   iby_payments_all      ip,
	 iby_ext_bank_accounts ieba,
	 ce_bank_branches_v    cbb
      WHERE  ip.external_bank_account_id = ieba.ext_bank_account_id
      AND    ieba.branch_id = cbb.branch_party_id
      AND    ieba.bank_id = cbb.bank_party_id
      AND    ip.payment_id = p_payment_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_branch_type := NULL;
    END;

    l_servicelevelcode := '';
    BEGIN
      SELECT pym.attribute10
      INTO   l_servicelevelcode
      FROM   iby_payments_all      pmt,
	 iby_payment_methods_b pym
      WHERE  pmt.payment_method_code = pym.payment_method_code
      AND    pym.attribute10 IS NOT NULL
      AND    pmt.payment_id = p_payment_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_branch_type := NULL;
    END;

    -- Added SQL to get Bank Account Type 13-AUG-2015 SAkula CHG0035411
    l_bank_account_type := '';
    BEGIN
      SELECT lookup.tag
      INTO l_bank_account_type
      FROM  iby_payments_all      ip,
	          iby_ext_bank_accounts ieba,
	          fnd_lookup_values_vl  lookup
      WHERE ip.external_bank_account_id = ieba.ext_bank_account_id
      AND   ieba.bank_account_type = lookup.lookup_code
      AND   lookup.lookup_type = 'BANK_ACCOUNT_TYPE'
      AND   lookup.view_application_id = 260
      AND   ip.payment_id = p_payment_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_bank_account_type := NULL;
    END;


    -- Added 28-JUL-2015 SAkula CHG0035411 START
    l_payment_reasons := '';
    FOR C_1 IN c_payment_reasons LOOP
      l_payment_reasons := l_payment_reasons||'*'||c_1.meaning;
    END LOOP;
    l_payment_reasons := SUBSTR(l_payment_reasons,2,141);
    -- Added 28-JUL-2015 SAkula CHG0035411 END

    -- Added 20-AUG-2015 SAkula CHG0035411 START
BEGIN
      SELECT UTL_I18N.TRANSLITERATE (ieba.bank_account_name,'fwkatakana_hwkatakana'),
       UTL_I18N.TRANSLITERATE (aps.vendor_name_alt,'fwkatakana_hwkatakana'),
       UTL_I18N.TRANSLITERATE (aps.vendor_name,'fwkatakana_hwkatakana'),
       UTL_I18N.TRANSLITERATE (cb.bank_name_alt,'fwkatakana_hwkatakana')
INTO   l_payment_info
FROM   iby_payments_all      ip,
     	 iby_ext_bank_accounts ieba,
       iby_external_payees_all iepa,
	     ap_suppliers    aps,
       ce_banks_v      cb
WHERE  ip.external_bank_account_id = ieba.ext_bank_account_id
AND    ip.ext_payee_id = iepa.ext_payee_id
AND    iepa.payee_party_id = aps.party_id
AND    ieba.bank_id = cb.bank_party_id
AND    ip.payment_id = p_payment_id;
EXCEPTION
WHEN OTHERS THEN
l_payment_info := null;
END;
 -- Added 20-AUG-2015 SAkula CHG0035411 END

 -- Added 20-AUG-2015 SAkula CHG0035411 START
    l_invoices := '';
    FOR c_2 IN c_invoices LOOP
      l_invoices := l_invoices||'*'||c_2.calling_app_doc_ref_number;
    END LOOP;
     --l_invoices := SUBSTR(l_invoices,2,141);  Commented 21-FEB-2017 SPatel
    l_invoices := SUBSTR(l_invoices,2,140);  -- Added(Changed the length to always restrict to 140 characters) 21-FEB-2017 SPatel
    -- Added 20-AUG-2015 SAkula CHG0035411 END

    BEGIN
      SELECT xmlconcat(xmlelement("XXOutboundPayment",
		                   xmlelement("XXPayeeBank",xmlelement("XXBankBranchType",l_branch_type)),
		                   xmlelement("XXSvcLvlCd",l_servicelevelcode),
                       xmlelement("XXPaymentReasons",l_payment_reasons), -- Added 28-JUL-2015 SAkula CHG0035411
                       xmlelement("XXBankAccountTypeTag",l_bank_account_type), -- Added 13-AUG-2015 SAkula CHG0035411
                       xmlelement("XXPayeeBankAccount",xmlelement("XXAlternateBankName",l_payment_info.bank_name_alt),
                                                       xmlelement("XXBankAccountName",l_payment_info.bank_account_name)),-- Added 20-AUG-2015 SAkula CHG0035411
                       xmlelement("XXPayee",xmlelement("XXAlternateName",l_payment_info.vendor_name_alt),
                                            xmlelement("XXName",l_payment_info.vendor_name)),-- Added 20-AUG-2015 SAkula CHG0035411
                       xmlelement("XXDocumentPayable",xmlelement("XXDocumentNumber",
                                                      xmlelement("XXReferenceNumbers",
                                                      xmlelement("XXUstrd",l_invoices)))) -- Added 20-AUG-2015 SAkula CHG0035411
                       ))
      INTO   l_pmt_ext_agg
      FROM   dual;
    EXCEPTION
      WHEN OTHERS THEN
        l_pmt_ext_agg := NULL;
    END;

    RETURN(l_pmt_ext_agg);

  END get_pmt_ext_agg;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    GET_ACK_EMAIL
  Author's Name:   Sandeep Akula
  Date Written:    31-DEC-2014
  Purpose:         This Procedure dervies Email Address to which the Acknowledgment Notification should go (Only for L0 and L1 Acknowledgments)
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  31-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032794
  19-SEP-2018        1.1                  Bellona(TCS)		CHG0043682- Added profile which holds distribution list 
															for sending acknowledgement mail.  
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_ack_email(p_ack_level  IN NUMBER,
		  p_orgnlmsgid IN NUMBER,
		  p_to_email   OUT VARCHAR2) IS
    --p_cc_email OUT VARCHAR2) IS
    l_to_email VARCHAR2(150);
  BEGIN

    l_to_email := '';
    BEGIN
      SELECT email_address
      INTO   l_to_email
      FROM   iby_pay_instructions_all ipi,
	 fnd_user                 fu
      WHERE  ipi.created_by = fu.user_id
      AND    payment_instruction_id = p_orgnlmsgid;
    EXCEPTION
      WHEN OTHERS THEN
        /* Deriving SYSADMIN Email */
        BEGIN
          SELECT email_address
          INTO   l_to_email
          FROM   fnd_user
          WHERE  user_name = 'SYSADMIN';
        EXCEPTION
          WHEN OTHERS THEN
	l_to_email := NULL;
        END;
        /* End */
    END;

    p_to_email := l_to_email ||';'||g_dist_list; 											--CHG0043682
	--';yuval.tal@stratasys.com;Sandeep.patel@stratasys.com;Erik.Morgan@stratasys.com';		--CHG0043682
    --p_cc_email := NULL;

  END get_ack_email;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_L2_ACK_EMAIL
  Author's Name:   Sandeep Akula
  Date Written:    06-FEB-2015
  Purpose:         This Procedure dervies Email Address to which the Acknowledgment Notification should go (Only for L2 Acknowledgments)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  06-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0032794
  19-SEP-2018        1.1                  Bellona(TCS)		CHG0043682- Added profile which holds distribution list 
															for sending acknowledgement mail.
  ---------------------------------------------------------------------------------------------------*/
FUNCTION get_l2_ack_email(p_ack_level  IN NUMBER  DEFAULT NULL,
                          p_OrgnlEndToEndId IN NUMBER) -- Payment Reference Number
RETURN VARCHAR2 IS
l_to_email VARCHAR2(150);
BEGIN

l_to_email := '';
    BEGIN
      SELECT email_address
      INTO   l_to_email
      FROM   iby_payments_all ip,
             fnd_user  fu
      WHERE  ip.created_by = fu.user_id
      AND    payment_reference_number = p_OrgnlEndToEndId;
    EXCEPTION
      WHEN OTHERS THEN
        /* Deriving SYSADMIN Email */
        BEGIN
          SELECT email_address
          INTO   l_to_email
          FROM   fnd_user
          WHERE  user_name = 'SYSADMIN';
        EXCEPTION
          WHEN OTHERS THEN
	        l_to_email := NULL;
        END;
        /* End */
    END;

RETURN(l_to_email ||';'||g_dist_list);												--CHG0043682
--yuval.tal@stratasys.com;Sandeep.patel@stratasys.com;Erik.Morgan@stratasys.com');	--CHG0043682

END get_l2_ack_email;
END xxiby_pay_extract_util;
/