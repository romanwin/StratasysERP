create or replace package body xxiby_pay_aprroval_util IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXIBY_PAY_APRROVAL_UTIL.bdy
  Author's Name:   Sandeep Akula
  Date Written:    24-DEC-2014
  Purpose:         Payment Approval Process Utilities
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  24-DEC-2014        1.0                  Sandeep Akula    Initial Version (CHG0033620)
  18-MAR-2015        1.1                  Sandeep Akula    Added a new condition to cursors in Procedures get_notification_body and get_notification_subject -- CHG0034886
  30-MAR-2015        1.2                  Sandeep Akula    Changed Function IS_REQ_APPROVER_UPDATABLE_SL6 logic to always return a value of Y -- CHG0034462
  13-AUG-2015        1.3                  Sandeep Akula    CHG0035411 - 1. Added New Function get_approval_currency_code
                                                                        2. Added New Function get_approval_curr_conv_rate
                                                                        3. Added New Function get_currency_conv_info
                                                                        4. Changed function GET_HIGHEST_PAYMENT_REC to return extra columns in the record type
                                                                        5. Changed Function get_default_required_appvr_sl6 to always return a value
                                                                        6. Changed Procedure SUBMIT_APPROVAL_WORKFLOW_SL6 to pass notes when initiating workflow approval process
                                                                        7. Changed Function GET_DEFAULT_REQUIRED_APPVR_SL6 to always return a value
                                                                        8. Changed Function GET_NOTIFICATION_BODY by adding payment currency, masked account number to the body and formatting all Numeric values
                                                                        9. Changed Function get_notification_subject
                                                                        10. Added additonal Validations in Procedure BEFORE_APPROVAL_VALIDATIONS
                                                                        11. Added New Function get_currency_conversion_detail
  17-SEP-2015        1.3                  Michal Tzvik     CHG0035411 - 1. generate_reference_link: Change from procedure to function and change logic
                                                                        2. get_notification_body: add href link by calling generate_reference_link
                                                                        
  2.7.17          1.4                     Yuval tal         INC0096481 - modify get_approval_curr_conv_rate add cache
  31-OCT-2017        1.5                  Piyali Bhowmick   CHG0040948 - 1. Adding   status for column document status in  GET_HIGHEST_PAYMENT_REC  
                                                                         2. Adding a  status in payment status of CURSOR c_body_msg1 in GET_NOTIFICATION_BODY
                                                                         3. Adding the status in document status of CURSOR c_body_msg2 in GET_NOTIFICATION_BODY
                                                                         4. Adding the following status in payment status of CURSOR c_body_msg1 in GET_NOTIFICATION_SUBJECT
                                                                         
                                                                                                                                      
  ---------------------------------------------------------------------------------------------------*/
  g_doc_code  xxobjt_wf_docs.doc_code%TYPE := 'IBY_PAY';
  g_item_type VARCHAR2(100) := 'XXWFDOC';
  c_debug_module CONSTANT VARCHAR2(100) := 'xxap.payment_approval.xxiby_pay_aprroval_util.';

  
  TYPE t_payment_rate_tbl IS TABLE OF NUMBER INDEX BY VARCHAR2(10); --INC0096481

  g_payment_rate_tbl t_payment_rate_tbl;
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_approval_currency_code
  Author's Name:   Sandeep Akula
  Date Written:    13-AUG-2015
  Purpose:         This Function returns Approval Currency for the Internal Bank Account for a Payment. Assumption here is all Lines in the signing Limits forms have the same currency code
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-AUG-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035411
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_approval_currency_code(p_payment_id IN NUMBER) RETURN VARCHAR2 IS
    l_currency VARCHAR2(10);
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_approval_currency_code',
	       message   => 'Inside the Function get_approval_currency_code' ||
		        ' p_payment_id:' || p_payment_id);
  
    l_currency := '';
    SELECT DISTINCT cbs.attribute2 -- Approval Currency
    INTO   l_currency
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = p_payment_id
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_currency);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_approval_currency_code',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_approval_currency_code;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_approval_curr_conv_rate
  Author's Name:   Sandeep Akula
  Date Written:    13-AUG-2015
  Purpose:         This Function returns currency conversion rate to convert from Payment currency to Approval Currency for a Payment
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-AUG-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035411
  -- 2.7.17          1.1                  Yuval tal         INC0096481 - add cache of curr rate (g_payment_rate_tbl)
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_approval_curr_conv_rate(p_payment_id       IN NUMBER,
			   p_payment_currency IN VARCHAR2)
    RETURN NUMBER IS
    l_rate                      NUMBER;
    l_get_payment_currency_code VARCHAR2(5);
  BEGIN
  
    l_get_payment_currency_code := get_approval_currency_code(p_payment_id);
    --INC0096481
  
    IF g_payment_rate_tbl.exists(p_payment_currency || '|' ||
		         l_get_payment_currency_code) THEN
      RETURN g_payment_rate_tbl(p_payment_currency || '|' ||
		        l_get_payment_currency_code);
    END IF;
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_approval_curr_conv_rate',
	       message   => 'Inside the Function get_approval_curr_conv_rate' ||
		        ' p_payment_id:' || p_payment_id ||
		        ' p_payment_currency:' || p_payment_currency);
  
    IF p_payment_currency = l_get_payment_currency_code /*get_approval_currency_code(p_payment_id)*/
     THEN
      l_rate := 1;
    
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_approval_curr_conv_rate',
	         message   => 'Inside IF Condition' || ' p_payment_id:' ||
		          p_payment_id || ' p_payment_currency:' ||
		          p_payment_currency ||
		          ' Approval Currency :' ||
		          get_approval_currency_code(p_payment_id));
    
    ELSE
    
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_approval_curr_conv_rate',
	         message   => 'Inside ELSE Condition' ||
		          ' p_payment_id:' || p_payment_id ||
		          ' p_payment_currency:' ||
		          p_payment_currency ||
		          ' Approval Currency :' ||
		          get_approval_currency_code(p_payment_id));
    
      SELECT conversion_rate
      INTO   l_rate
      FROM   (SELECT conversion_rate,
	         row_number() over(ORDER BY conversion_date DESC) rnk
	  FROM   gl_daily_rates
	  WHERE  from_currency = p_payment_currency
	  AND    to_currency = l_get_payment_currency_code --   --INC0096481 get_approval_currency_code(p_payment_id) -- yuval 
	  AND    conversion_type = 'Corporate'
	  AND    trunc(conversion_date) - trunc(creation_date) <= 3
	  AND    trunc(conversion_date) < = trunc(SYSDATE))
      WHERE  rnk = '1';
    
    END IF;
    g_payment_rate_tbl(p_payment_currency || '|' || l_get_payment_currency_code) := l_rate; --INC0096481
    RETURN(l_rate);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_approval_curr_conv_rate',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_approval_curr_conv_rate;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_currency_conv_info
  Author's Name:   Sandeep Akula
  Date Written:    17-AUG-2015
  Purpose:         This Function returns currency conversion rate and conversion date to convert from Payment currency to Approval Currency for a Payment
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-AUG-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035411
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_currency_conv_info(p_payment_id       IN NUMBER,
		          p_payment_currency IN VARCHAR2)
    RETURN currency_conversion_rec IS
    l_currency_info currency_conversion_rec;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'get_currency_conv_info',
	       message   => 'Inside the Function get_currency_conv_info' ||
		        ' p_payment_id:' || p_payment_id ||
		        ' p_payment_currency:' || p_payment_currency);
  
    IF p_payment_currency = get_approval_currency_code(p_payment_id) THEN
    
      l_currency_info.conversion_rate := 1;
      l_currency_info.conversion_date := to_char(SYSDATE, 'DD-MON-RR');
    
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'get_currency_conv_info',
	         message   => 'Inside IF Condition' || ' p_payment_id:' ||
		          p_payment_id || ' p_payment_currency:' ||
		          p_payment_currency ||
		          ' Approval Currency :' ||
		          get_approval_currency_code(p_payment_id));
    
    ELSE
    
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'get_currency_conv_info',
	         message   => 'Inside ELSE Condition' ||
		          ' p_payment_id:' || p_payment_id ||
		          ' p_payment_currency:' ||
		          p_payment_currency ||
		          ' Approval Currency :' ||
		          get_approval_currency_code(p_payment_id));
    
      SELECT conversion_rate,
	 conversion_date
      INTO   l_currency_info
      FROM   (SELECT conversion_rate,
	         to_char(conversion_date, 'DD-MON-RR') conversion_date,
	         row_number() over(ORDER BY conversion_date DESC) rnk
	  FROM   gl_daily_rates
	  WHERE  from_currency = p_payment_currency
	  AND    to_currency = get_approval_currency_code(p_payment_id)
	  AND    conversion_type = 'Corporate'
	  AND    trunc(conversion_date) - trunc(creation_date) <= 3
	  AND    trunc(conversion_date) < = trunc(SYSDATE))
      WHERE  rnk = '1';
    
    END IF;
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'get_currency_conv_info',
	       message   => 'Inside the Function get_currency_conv_info' ||
		        ' p_payment_id:' || p_payment_id ||
		        ' p_payment_currency:' || p_payment_currency ||
		        ' Approval Currency:' ||
		        get_approval_currency_code(p_payment_id) ||
		        ' Rate :' || l_currency_info.conversion_rate ||
		        ' Conversion Date :' ||
		        l_currency_info.conversion_date);
  
    RETURN(l_currency_info);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'get_currency_conv_info',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_currency_conv_info;
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_PAY_PROCESS_REQ_STATUS
  Author's Name:   Sandeep Akula
  Date Written:    30-DEC-2014
  Purpose:         This Function returns Payment Process Request Status of a Payment Batch based on the Checkrun Name (Payment Batch)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  30-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_pay_process_req_status(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_status_code         VARCHAR2(200) := '';
    l_status_code_meaning VARCHAR2(200) := '';
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'GET_PAY_PROCESS_REQ_STATUS',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    -- Code derived from Payment OAF Page
    SELECT decode(ipsr.payment_service_request_id,
	      NULL,
	      aisc.status,
	      ap_payment_util_pkg.get_psr_status(ipsr.payment_service_request_id,
				     ipsr.payment_service_request_status)) status_code,
           decode(ipsr.payment_service_request_id,
	      NULL,
	      alc.displayed_field,
	      decode(ap_payment_util_pkg.get_psr_status(ipsr.payment_service_request_id,
					ipsr.payment_service_request_status),
		 'FORMATTING',
		 alc.displayed_field,
		 'CONFIRMED',
		 alc.displayed_field,
		 'TERMINATED',
		 alc.displayed_field,
		 'BUILDING',
		 alc.displayed_field,
		 'BUILT',
		 alc.displayed_field,
		 'BUILD_ERROR',
		 alc.displayed_field,
		 fl.meaning)) AS status_code_meaning
    INTO   l_status_code,
           l_status_code_meaning
    FROM   ap_inv_selection_criteria_all aisc,
           iby_pay_service_requests      ipsr,
           ap_lookup_codes               alc,
           fnd_lookups                   fl
    WHERE  aisc.checkrun_name = ipsr.call_app_pay_service_req_code(+)
    AND    alc.lookup_type = 'CHECK BATCH STATUS'
    AND    alc.lookup_code = decode(ipsr.payment_service_request_id,
			NULL,
			aisc.status,
			decode(ap_payment_util_pkg.get_psr_status(ipsr.payment_service_request_id,
						      ipsr.payment_service_request_status),
			       'FORMATTING',
			       'FORMATTING',
			       'CONFIRMED',
			       'CONFIRMED',
			       'TERMINATED',
			       'TERMINATED',
			       'BUILDING',
			       'BUILDING',
			       'BUILT',
			       'BUILT',
			       'BUILD_ERROR',
			       'BUILD_ERROR',
			       'SELECTED'))
    AND    fl.lookup_type(+) = 'IBY_REQUEST_STATUSES'
    AND    fl.lookup_code(+) = ipsr.payment_service_request_status
    AND    ipsr.payment_service_request_id = p_payment_service_request_id;
  
    RETURN(l_status_code_meaning);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_PAY_PROCESS_REQ_STATUS',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_pay_process_req_status;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_FIRST_APPROVER
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns First Approver of the Payment. This is used in SL7
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION get_first_approver(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1       fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2       fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3       fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4       fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5       fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_tmp_role  VARCHAR2(100);
    l_hist_role VARCHAR2(100);
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_FIRST_APPROVER',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    /*Deriving First Approver from Temp Table */
    SELECT role_name
    INTO   l_tmp_role
    FROM   xxobjt_wf_docs            a,
           xxobjt_wf_doc_instance    b,
           xxobjt_wf_doc_history_tmp c
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.doc_instance_id = c.doc_instance_id
    AND    b.n_attribute1 = p_payment_service_request_id
    AND    c.seq_no IN
           (SELECT MIN(seq_no)
	 FROM   xxobjt_wf_doc_history_tmp d
	 WHERE  d.doc_instance_id = c.doc_instance_id);
  
    RETURN(l_tmp_role);
  
  EXCEPTION
    WHEN OTHERS THEN
      /* Deriving First Approver from History Table.*/
      BEGIN
        SELECT role_name
        INTO   l_hist_role
        FROM   xxobjt_wf_docs         a,
	   xxobjt_wf_doc_instance b,
	   xxobjt_wf_doc_history  c
        WHERE  a.doc_id = b.doc_id
        AND    a.doc_code = g_doc_code
        AND    b.doc_instance_id = c.doc_instance_id
        AND    b.n_attribute1 = p_payment_service_request_id
        AND    c.action_code IN ('APPROVE', 'WAITING')
        AND    c.seq_no IN
	   (SELECT MIN(seq_no)
	     FROM   xxobjt_wf_doc_history d
	     WHERE  d.doc_instance_id = c.doc_instance_id
	     AND    d.action_code = c.action_code);
      
        RETURN(l_hist_role);
      
      EXCEPTION
        WHEN OTHERS THEN
          fnd_log.string(log_level => fnd_log.level_event,
		 module    => c_debug_module || 'GET_FIRST_APPROVER',
		 message   => 'OTHERS Exception SQL Error :' ||
			  SQLERRM);
          l_hist_role := NULL;
          RETURN(l_hist_role);
      END;
    
  END get_first_approver;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_HIGHEST_PAYMENT_REC
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Highest Payment Amt and Associated Payment ID for a PPR
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  13-AUG-2015        1.1                  Sandeep Akula     CHG0035411 - 1. Added following new columns to the Select statement:
                                                                              a. payment_amt
                                                                              b. converted_payment_amt
                                                                              c. payment_currency_code
                                                                              d. converted_payment_currency
                                                                         2. Changed Group By clause of the select statement 
  31-OCT-2017        1.2                  Piyali Bhowmick   CHG0040948 - Adding the following  status for column document status
                                                                         1.VOID_BY_OVERFLOW_REPRINT 
                                                                         2.VOID_BY_SETUP_REPRINT 
                                                                         3.REJECTED
                                                                         4.FAILED_BY_CALLING_APP
                                                                         5.FAILED_BY_REJECTION_LEVEL
                                                                         6.FAILED_VALIDATION
                                                                         7.PAYMENT_FAILED_VALIDATION 
                                                                                                                                            
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_highest_payment_rec(p_payment_service_request_id IN NUMBER)
    RETURN highest_payment_amt_rec IS
  
    l_np1  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_info highest_payment_amt_rec;
  BEGIN
  
  
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_HIGHEST_PAYMENT_REC',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    SELECT *
    INTO   l_info
    FROM   (SELECT payment_amt, -- Payment Amount -- In Payment Currency  -- Added column 13-AUG-2015 SAkula CHG0035411
	       converted_payment_amt, -- Converted Payment Amount -- In Approval Currency  -- Added column 13-AUG-2015 SAkula CHG0035411
	       payment_id,
	       payment_currency_code, -- Added column 10-AUG-2015 SAkula CHG0035411
	       converted_payment_currency, -- Added column 10-AUG-2015 SAkula CHG0035411
	       -- MMAZANET 11-MAY-2015 CHG0034462
	       -- Used row_number() instead of dense_rank because if two
	       -- amounts were the same and ranked 1, and we take dense_rnk = '1'
	       -- this will eventually lead to a TOO_MANY_ROWS exception.  Using
	       -- rownum ensures we will only have one value = 1
	       --dense_rank() over(ORDER BY amt DESC) AS dense_rnk
	       row_number() over(ORDER BY converted_payment_amt DESC) AS dense_rnk
	FROM   (SELECT payment_id,
		   round(SUM((idp.payment_amount +
			 nvl(idp.amount_withheld, 0)) *
			 get_approval_curr_conv_rate(payment_id,
					     payment_currency_code)),
		         2) converted_payment_amt, -- Added amount_withheld so that Approval process is based on the Highest Payment amount Including Withholding 10-AUG-2015 SAkula CHG0035411
		   payment_currency_code, -- Added column 10-AUG-2015 SAkula CHG0035411
		   get_approval_currency_code(payment_id) converted_payment_currency, -- Added column 10-AUG-2015 SAkula CHG0035411
		   round(SUM(idp.payment_amount +
			 nvl(idp.amount_withheld, 0)),
		         2) payment_amt -- Added column 13-AUG-2015 SAkula CHG0035411
	        FROM   iby_docs_payable_all idp,
		   fnd_lookups          lut
	        WHERE  idp.document_status NOT IN
		   ('REMOVED',
		    'REMOVED_PAYMENT_REMOVED',
		    'REMOVED_PAYMENT_STOPPED',
		    'REMOVED_PAYMENT_VOIDED',
		    'REMOVED_REQUEST_TERMINATED',
		    'REMOVED_INSTRUCTION_TERMINATED',
            'VOID_BY_OVERFLOW_REPRINT', -- Added by Piyali for  CHG0040948
            'VOID_BY_SETUP_REPRINT',  
            'REJECTED',
            'FAILED_BY_CALLING_APP',
            'FAILED_BY_REJECTION_LEVEL',
            'FAILED_VALIDATION',
            'PAYMENT_FAILED_VALIDATION'--Added by Piyali for  CHG0040948 
            )
	        AND    idp.document_type = lut.lookup_code
	        AND    lut.lookup_type = 'IBY_DOCUMENT_TYPES'
	        AND    idp.payment_service_request_id =
		   p_payment_service_request_id
		  -- MMAZANET 11-MAY-2015 CHG0034462
		  -- Without this we got non-payments in this query meaning the payment_id would be NULL
	        AND    idp.payment_id IS NOT NULL
	        GROUP  BY payment_id,
		      payment_currency_code)) -- Added 10-AUG-2015 SAkula CHG0035411
    WHERE  dense_rnk = '1'; -- Highest Payment Amount
  
   
    RETURN(l_info);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_HIGHEST_PAYMENT_REC',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_highest_payment_rec;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_NO_OF_ACTIVE_GROUPS
  Author's Name:   Sandeep Akula
  Date Written:    17-FEB-2015
  Purpose:         This Function returns the number of Active Signer Groups for the Payment
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_no_of_active_groups(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
    l_pmt_rec highest_payment_amt_rec;
    l_count   NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_NO_OF_ACTIVE_GROUPS',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    l_count := '';
    SELECT COUNT(*)
    INTO   l_count
    FROM   (SELECT DISTINCT cbs.signer_group
	FROM   iby_payments_all  ip,
	       ce_ba_signatories cbs
	WHERE  ip.internal_bank_account_id = cbs.bank_account_id
	AND    ip.payment_id = l_pmt_rec.payment_id
	AND    cbs.deleted_flag = 'N'
	AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	       trunc(nvl(cbs.end_date, SYSDATE)));
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_NO_OF_ACTIVE_GROUPS',
	       message   => 'l_count :' || l_count);
  
    RETURN(l_count);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_NO_OF_ACTIVE_GROUPS',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_no_of_active_groups;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_LOWEST_GROUP
  Author's Name:   Sandeep Akula
  Date Written:    17-FEB-2015
  Purpose:         This Function returns the singer group with Lowest Single Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_lowest_group(p_payment_service_request_id IN NUMBER)
    RETURN signer_group_rec IS
    l_pmt_rec     highest_payment_amt_rec;
    l_signer_info signer_group_rec;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_LOWEST_GROUP',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_LOWEST_GROUP',
	       message   => 'l_pmt_rec.payment_id :' ||
		        l_pmt_rec.payment_id);
  
    SELECT *
    INTO   l_signer_info
    FROM   (SELECT DISTINCT nvl(cbs.single_limit_amount, 999999999999),
		    cbs.signer_group,
		    nvl(cbs.joint_limit_amount, 9999999999999999)
	FROM   iby_payments_all  ip,
	       ce_ba_signatories cbs
	WHERE  ip.internal_bank_account_id = cbs.bank_account_id
	AND    ip.payment_id = l_pmt_rec.payment_id
	AND    cbs.deleted_flag = 'N'
	AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	       trunc(nvl(cbs.end_date, SYSDATE))
	AND    nvl(cbs.single_limit_amount, '999999999999') IN
	       (SELECT MIN(nvl(cbs2.single_limit_amount, '999999999999'))
	         FROM   ce_ba_signatories cbs2
	         WHERE  cbs2.bank_account_id = cbs.bank_account_id
	         AND    cbs2.deleted_flag = cbs.deleted_flag
	         AND    trunc(SYSDATE) BETWEEN trunc(cbs2.start_date) AND
		    trunc(nvl(cbs2.end_date, SYSDATE))));
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_LOWEST_GROUP',
	       message   => 'l_signer_info Record :' ||
		        l_signer_info.single_limit_amount || '-' ||
		        l_signer_info.signer_group);
  
    RETURN(l_signer_info);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'GET_LOWEST_GROUP',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_lowest_group;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_HIGHEST_GROUP
  Author's Name:   Sandeep Akula
  Date Written:    17-FEB-2015
  Purpose:         This Function returns the singer group with Highest Single Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_highest_group(p_payment_service_request_id IN NUMBER)
    RETURN signer_group_rec IS
    l_pmt_rec     highest_payment_amt_rec;
    l_signer_info signer_group_rec;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_HIGHEST_GROUP',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT *
    INTO   l_signer_info
    FROM   (SELECT DISTINCT nvl(cbs.single_limit_amount, 999999999999),
		    cbs.signer_group,
		    nvl(cbs.joint_limit_amount, 9999999999999999)
	FROM   iby_payments_all  ip,
	       ce_ba_signatories cbs
	WHERE  ip.internal_bank_account_id = cbs.bank_account_id
	AND    ip.payment_id = l_pmt_rec.payment_id
	AND    cbs.deleted_flag = 'N'
	AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	       trunc(nvl(cbs.end_date, SYSDATE))
	AND    nvl(cbs.single_limit_amount, '999999999999') IN
	       (SELECT MAX(nvl(cbs2.single_limit_amount, '999999999999'))
	         FROM   ce_ba_signatories cbs2
	         WHERE  cbs2.bank_account_id = cbs.bank_account_id
	         AND    cbs2.deleted_flag = cbs.deleted_flag
	         AND    trunc(SYSDATE) BETWEEN trunc(cbs2.start_date) AND
		    trunc(nvl(cbs2.end_date, SYSDATE))));
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_HIGHEST_GROUP',
	       message   => 'l_signer_info Record :' ||
		        l_signer_info.single_limit_amount || '-' ||
		        l_signer_info.signer_group);
  
    RETURN(l_signer_info);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'GET_HIGHEST_GROUP',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_highest_group;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPA_PRIMARY_APPROVER
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns primary Group A Approver based on the setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group A will have only One Primary Approver (DFF)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupa_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec          highest_payment_amt_rec;
    l_primary_approver NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'GET_GROUPA_PRIMARY_APPROVER',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.person_id
    INTO   l_primary_approver
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP A'
    AND    cbs.attribute1 = 'Y' -- Primary Approver Flag  (DFF on Bank Account Signing Authority Form)
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_primary_approver); -- Returns person_id
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPA_PRIMARY_APPROVER',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupa_primary_approver;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPA_SINGLE_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group A Single Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group A will not have different single limits. All Approvers in Group A should have the same Single Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupa_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPA_SINGLE_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT nvl(cbs.single_limit_amount, '999999999999')
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP A'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPA_SINGLE_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupa_single_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPA_JOINT_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group A Joint Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group A will not have different Joint limits. All Approvers in Group A should have the same Joint Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupa_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPA_JOINT_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT nvl(cbs.joint_limit_amount, '9999999999999999')
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP A'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'GET_GROUPA_JOINT_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupa_joint_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPB_SINGLE_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group B Single Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group B will not have different single limits. All Approvers in Group B should have the same Single Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupb_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPB_SINGLE_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.single_limit_amount
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP B'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPB_SINGLE_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupb_single_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPB_JOINT_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group B Joint Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group B will not have different Joint limits. All Approvers in Group B should have the same Joint Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupb_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPB_JOINT_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.joint_limit_amount
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP B'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'GET_GROUPB_JOINT_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupb_joint_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPB_PRIMARY_APPROVER
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns primary Group B Approver based on the setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group B will have only One Primary Approver (DFF)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupb_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec          highest_payment_amt_rec;
    l_primary_approver NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'GET_GROUPB_PRIMARY_APPROVER',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.person_id
    INTO   l_primary_approver
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP B'
    AND    cbs.attribute1 = 'Y' -- Primary Approver Flag
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_primary_approver); -- Returns person_id
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPB_PRIMARY_APPROVER',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupb_primary_approver;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPC_SINGLE_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group C Single Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group C will not have different single limits. All Approvers in Group C should have the same Single Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupc_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPC_SINGLE_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.single_limit_amount
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP C'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPC_SINGLE_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupc_single_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPC_JOINT_LIMIT
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Group C Joint Limit as per setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group C will not have different Joint limits. All Approvers in Group C should have the same Joint Limit
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupc_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_GROUPC_JOINT_LIMIT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.joint_limit_amount
    INTO   l_amt
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP C'
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_amt);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'GET_GROUPC_JOINT_LIMIT',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupc_joint_limit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_GROUPC_PRIMARY_APPROVER
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns primary Group C Approver based on the setups in Cash Management Bank Account Signing Authority Form
  Assumption:      Assumption here is that Group C will have only One Primary Approver (DFF)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_groupc_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5              fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec          highest_payment_amt_rec;
    l_primary_approver NUMBER;
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'GET_GROUPC_PRIMARY_APPROVER',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    SELECT DISTINCT cbs.person_id
    INTO   l_primary_approver
    FROM   iby_payments_all  ip,
           ce_ba_signatories cbs
    WHERE  ip.internal_bank_account_id = cbs.bank_account_id
    AND    ip.payment_id = l_pmt_rec.payment_id
    AND    cbs.signer_group = 'GROUP C'
    AND    cbs.attribute1 = 'Y' -- Primary Approver Flag
    AND    cbs.deleted_flag = 'N'
    AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
           trunc(nvl(cbs.end_date, SYSDATE));
  
    RETURN(l_primary_approver); -- Returns person_id
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_GROUPC_PRIMARY_APPROVER',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_groupc_primary_approver;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    PAY_TEMPLATE_VALIDATIONS_SL1
  Author's Name:   Sandeep Akula
  Date Written:    24-DEC-2014
  Purpose:         This Function returns a value of Y or N based on the Profile option NP1 and NP2 Values
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  24-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION pay_template_validations_sl1 RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'PAY_TEMPLATE_VALIDATIONS_SL1',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || 'L_NP2 :' || l_np2 ||
		        'L_NP1 :' || l_np1);
  
    IF (l_np2 IS NULL OR l_np2 = 'N') AND l_np1 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'PAY_TEMPLATE_VALIDATIONS_SL1',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END pay_template_validations_sl1;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    PPR_PROCESSING_TAB_VALDATN_SL2
  Author's Name:   Sandeep Akula
  Date Written:    30-DEC-2014
  Purpose:         This Function returns a value of Y or N based on the Profile option NP1 and NP2 Values
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  30-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION ppr_processing_tab_valdatn_sl2(p_checkrun_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'PPR_PROCESSING_TAB_VALDATN_SL2',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || 'L_NP2 :' || l_np2 ||
		        'L_NP1 :' || l_np1);
  
    IF (l_np2 IS NULL OR l_np2 = 'N') AND l_np1 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'PPR_PROCESSING_TAB_VALDATN_SL2',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END ppr_processing_tab_valdatn_sl2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    PPR_SHOW_APPROVE_BUTTON_SL3
  Author's Name:   Sandeep Akula
  Date Written:    30-DEC-2014
  Purpose:         This Function returns a value of Y or N based on the Profile option NP1 Value
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  30-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION ppr_show_approve_button_sl3 RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'PPR_SHOW_APPROVE_BUTTON_SL3',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || ' L_NP1 :' ||
		        l_np1);
  
    IF l_np1 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'PPR_SHOW_APPROVE_BUTTON_SL3',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END ppr_show_approve_button_sl3;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    PAY_WORKFLOW_STATUS_SL5
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns the status of the Custom Payment Approval Workflow
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION pay_workflow_status_sl5(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_doc_status xxobjt_wf_doc_instance.doc_status%TYPE;
    l_doc_id     NUMBER;
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'PAY_WORKFLOW_STATUS_SL5',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        'p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_doc_id := '';
    l_doc_id := xxobjt_wf_doc_util.get_doc_id(p_doc_code => g_doc_code);
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'PAY_WORKFLOW_STATUS_SL5',
	       message   => 'l_doc_id :' || l_doc_id);
  
    l_doc_status := '';
    l_doc_status := get_doc_status(p_payment_service_request_id, l_doc_id);
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'PAY_WORKFLOW_STATUS_SL5',
	       message   => 'l_doc_status :' || l_doc_status);
  
    IF nvl(l_doc_status, '-1') IN ('NEW', 'CANCELLED', 'REJECTED') THEN
      RETURN('NEW'); -- Workflow Not Started
    ELSIF l_doc_status IN ('APPROVED') THEN
      RETURN('APPROVED'); -- Payment is Approved (Final Approver has approved)
    ELSIF l_doc_status IN ('IN_PROCESS', 'ERROR') THEN
      RETURN('IN_PROCESS'); -- Workflow Active
    ELSE
      RETURN('NEW'); -- For Unknown status
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'PAY_WORKFLOW_STATUS_SL5',
	         message   => 'OTHERS Exception SQL Error : p_payment_service_request_id=' ||
		          p_payment_service_request_id ||
		          ' l_doc_status :' || l_doc_status || ' ;' ||
		          SQLERRM);
      RETURN('IN_PROCESS');
  END pay_workflow_status_sl5;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    ACTIVATE_PPR_APPROVAL_SL5
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns Y or N based on NP1 Profile and PPR status
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION activate_ppr_approval_sl5(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'ACTIVATE_PPR_APPROVAL_SL5',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id || ' L_NP1 :' ||
		        l_np1 || ' GET_PAY_PROCESS_REQ_STATUS :' ||
		        get_pay_process_req_status(p_payment_service_request_id));
  
    IF l_np1 = 'Y' AND get_pay_process_req_status(p_payment_service_request_id) =
       'Pending Proposed Payment Review' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'ACTIVATE_PPR_APPROVAL_SL5',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END activate_ppr_approval_sl5;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_HIGHEST_PAYMENT_AMT_SL6
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         Returns Payment Amount of the Payment with Highest Value in PPR
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_highest_payment_amt_sl6(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_np1     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_pmt_rec highest_payment_amt_rec;
    l_amt     NUMBER := '';
  
  BEGIN
  
    /*SELECT amt
    INTO l_amt
    FROM
      (SELECT amt,
        payment_id,
        dense_rank() over (order by amt DESC) AS dense_rnk
      FROM
        (SELECT payment_id,
          SUM(idp.payment_amount) amt
        FROM iby_docs_payable_all idp,
          fnd_lookups lut
        WHERE idp.document_status NOT IN('REMOVED', 'REMOVED_PAYMENT_REMOVED', 'REMOVED_PAYMENT_STOPPED', 'REMOVED_PAYMENT_VOIDED', 'REMOVED_REQUEST_TERMINATED', 'REMOVED_INSTRUCTION_TERMINATED')
        AND idp.document_type   = lut.lookup_code
        AND lut.lookup_type     = 'IBY_DOCUMENT_TYPES'
        AND idp.payment_service_request_id = p_payment_service_request_id
        GROUP BY payment_id
        )
      )
    WHERE dense_rnk = '1';  -- Highest Payment Amount*/
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_highest_payment_amt_sl6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    RETURN(l_pmt_rec.converted_payment_amount);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_HIGHEST_PAYMENT_AMT_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN(NULL);
  END get_highest_payment_amt_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    SUBMIT_APPROVAL_WORKFLOW_SL6
  Author's Name:   Sandeep Akula
  Date Written:    7-JAN-2015
  Purpose:         This Procedure will create Workflow Instance, Inserts User choosen Approvers in xxobjt_wf_doc_history_tmp table AND Initiates the Workflow Approval Process
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  07-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  10-AUG-2015        1.1                  Sandeep Akula     CHG0035411 - Added new parameter to store Conversion rate, currency and Date in workflow history table when calling package xxobjt_wf_doc_util.initiate_approval_process
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE submit_approval_workflow_sl6(p_payment_service_request_id IN NUMBER,
			     p_approvers                  IN VARCHAR2,
			     --p_final_approver_flag IN VARCHAR2, -- Final Approver Flag
			     p_err_code    OUT VARCHAR2,
			     p_err_message OUT VARCHAR2) IS
  
    l_doc_instance_header xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(1000);
    l_itemkey             VARCHAR2(25);
    l_np1                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'SUBMIT_APPROVAL_WORKFLOW_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id ||
		        ' p_approvers :' || p_approvers);
  
    -- Initiating Workflow Document Instance
    l_doc_instance_header.user_id             := fnd_global.user_id;
    l_doc_instance_header.resp_id             := fnd_global.resp_id;
    l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
    l_doc_instance_header.requestor_person_id := fnd_global.employee_id;
    l_doc_instance_header.creator_person_id   := fnd_global.employee_id;
    l_doc_instance_header.n_attribute1        := p_payment_service_request_id;
  
    -- For each payment service request, only one doc_instance_id should exists
    BEGIN
      SELECT xwdi.doc_instance_id
      INTO   l_doc_instance_header.doc_instance_id
      FROM   xxobjt_wf_doc_instance xwdi,
	 xxobjt_wf_docs         xwd
      WHERE  xwd.doc_code = g_doc_code
      AND    xwdi.doc_id = xwd.doc_id
      AND    xwdi.n_attribute1 = p_payment_service_request_id
      AND    rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
    -- Deriving the Doc ID for creating a Workflow Instance
    l_doc_instance_header.doc_id := xxobjt_wf_doc_util.get_doc_id(p_doc_code => g_doc_code);
    IF l_doc_instance_header.doc_id IS NULL THEN
      p_err_code    := 'F';
      p_err_message := 'invalid entity code ' || g_doc_code;
      RETURN;
    END IF;
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'SUBMIT_APPROVAL_WORKFLOW_SL6',
	       message   => 'Before create_instance' || 'G_DOC_CODE :' ||
		        g_doc_code);
  
    l_err_code := '';
    l_err_msg  := '';
    -- Calling Package to create Workflow Instance
    xxobjt_wf_doc_util.create_instance(p_err_code            => l_err_code,
			   p_err_msg             => l_err_msg,
			   p_doc_instance_header => l_doc_instance_header,
			   p_doc_code            => g_doc_code);
  
    IF l_err_code = 1 THEN
      p_err_code    := 'F';
      p_err_message := ('Error in create_instance: ' || l_err_msg);
    ELSE
      dbms_output.put_line('doc_instance_id: ' ||
		   l_doc_instance_header.doc_instance_id);
      /*   l_final_approver_order := '';
      l_err_code := '';
      l_err_msg := '';
      -- Calling Procedure to Validate the Approver String Passed by OAF Page. A Final Approver String in correct order will be the output of the procedure
      GET_APPROVERS_ORDER(p_approvers_string => p_approvers,
                          p_flag => p_final_approver_flag,
                          p_final_approvers => l_final_approver_order,
                          p_err_code => l_err_code,
                          p_err_msg => l_err_msg);
      
        IF l_err_code = 'F' THEN
            p_err_code := 'F';
            p_err_message  := l_err_msg;
        ELSE */
    
      -- Michal: debug
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'SUBMIT_APPROVAL_WORKFLOW_SL6',
	         message   => 'Before insert_custom_approvals' ||
		          'doc_instance_id: ' ||
		          l_doc_instance_header.doc_instance_id ||
		          'p_approvers :' || p_approvers);
    
      l_err_code := '';
      l_err_msg  := '';
      -- Calling Package to Insert the Approvers selected by the User before submitting the workflow
      xxobjt_wf_doc_util.insert_custom_approvals(p_err_msg                 => l_err_msg,
				 p_err_code                => l_err_code,
				 p_doc_instance_id         => l_doc_instance_header.doc_instance_id,
				 p_approval_person_id_list => p_approvers);
    
      IF l_err_code = 1 THEN
        p_err_code    := 'F';
        p_err_message := ('Error in insert_custom_approvals: ' || l_err_msg);
      ELSE
      
        -- Debug Message
        fnd_log.string(log_level => fnd_log.level_event,
	           module    => c_debug_module ||
			'SUBMIT_APPROVAL_WORKFLOW_SL6',
	           message   => 'Before initiate_approval_process' ||
			'doc_instance_id: ' ||
			l_doc_instance_header.doc_instance_id ||
			'l_itemkey :' || l_itemkey);
      
        l_err_code := '';
        l_err_msg  := '';
        -- Starting Workflow Process
        xxobjt_wf_doc_util.initiate_approval_process(p_err_code        => l_err_code,
				     p_err_msg         => l_err_msg,
				     p_doc_instance_id => l_doc_instance_header.doc_instance_id,
				     p_wf_item_key     => l_itemkey,
				     p_note            => get_currency_conversion_detail(p_payment_service_request_id)); -- Added new parameter to store Conversion rate, currency and Date in workflow history table 10-AUG-2015 SAkula CHG0035411
      
        IF l_err_code = 1 THEN
          p_err_code    := 'F';
          p_err_message := ('Error in initiate_approval_process: ' ||
		   l_err_msg);
        ELSE
          p_err_code    := 'S';
          p_err_message := 'Approval was successfully submited for ' ||
		   xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id) ||
		   '. doc_instance_id=' ||
		   l_doc_instance_header.doc_instance_id;
        END IF;
      END IF;
      /*END IF;*/
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'SUBMIT_APPROVAL_WORKFLOW_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      p_err_code    := 'F';
      p_err_message := SQLERRM;
  END submit_approval_workflow_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_DEFAULT_REQUIRED_APPVR_SL6
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         Defaults a Value in Required Approver field. This Function returns person_id of the defaulted person
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  20-AUG-2015        1.1                  Sandeep Akula     CHG0035411 - Added RETURN(NULL) statement so that function always returns somevalue
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_default_required_appvr_sl6(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER IS
  
    l_pmt_rec             highest_payment_amt_rec;
    l_groupa_single_limit NUMBER;
    l_groupb_single_limit NUMBER;
    l_groupc_single_limit NUMBER;
    l_groupa_primary      NUMBER;
    l_groupb_primary      NUMBER;
    l_groupc_primary      NUMBER;
    l_highest_pay_amt     NUMBER;
    l_active_grp          NUMBER;
    l_highest_signer_rec  signer_group_rec;
    l_lowest_signer_rec   signer_group_rec;
    l_np1                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'GET_DEFAULT_REQUIRED_APPVR_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec             := get_highest_payment_rec(p_payment_service_request_id);
    l_groupa_single_limit := get_groupa_single_limit(p_payment_service_request_id);
    l_groupb_single_limit := get_groupb_single_limit(p_payment_service_request_id);
    l_groupc_single_limit := get_groupc_single_limit(p_payment_service_request_id);
    l_groupa_primary      := get_groupa_primary_approver(p_payment_service_request_id);
    l_groupb_primary      := get_groupb_primary_approver(p_payment_service_request_id);
    l_groupc_primary      := get_groupc_primary_approver(p_payment_service_request_id);
    l_highest_pay_amt     := l_pmt_rec.converted_payment_amount;
    l_highest_signer_rec  := get_highest_group(p_payment_service_request_id);
    l_lowest_signer_rec   := get_lowest_group(p_payment_service_request_id);
  
    l_active_grp := '';
    l_active_grp := get_no_of_active_groups(p_payment_service_request_id);
  
    IF l_active_grp = '3' THEN
    
      IF l_highest_pay_amt <= l_groupc_single_limit THEN
        RETURN(l_groupc_primary);
      ELSIF l_highest_pay_amt <= l_groupb_single_limit AND
	l_highest_pay_amt >= l_groupc_single_limit THEN
        RETURN(l_groupb_primary);
      ELSIF l_highest_pay_amt <= l_groupa_single_limit AND
	l_highest_pay_amt >= l_groupb_single_limit THEN
        RETURN(l_groupa_primary);
      ELSIF l_highest_pay_amt > l_groupa_single_limit THEN
        RETURN(NULL);
      END IF;
    
    ELSIF l_active_grp = '2' THEN
    
      IF l_highest_pay_amt <= l_lowest_signer_rec.single_limit_amount THEN
        RETURN(CASE WHEN l_lowest_signer_rec.signer_group LIKE '%C%' THEN
	   l_groupc_primary WHEN
	   l_lowest_signer_rec.signer_group LIKE '%B%' THEN
	   l_groupb_primary WHEN
	   l_lowest_signer_rec.signer_group LIKE '%A%' THEN
	   l_groupa_primary ELSE NULL END);
      ELSIF l_highest_pay_amt <= l_highest_signer_rec.single_limit_amount AND
	l_highest_pay_amt >= l_lowest_signer_rec.single_limit_amount THEN
      
        RETURN(CASE WHEN l_highest_signer_rec.signer_group LIKE '%C%' THEN
	   l_groupc_primary WHEN
	   l_highest_signer_rec.signer_group LIKE '%B%' THEN
	   l_groupb_primary WHEN
	   l_highest_signer_rec.signer_group LIKE '%A%' THEN
	   l_groupa_primary ELSE NULL END);
      
      ELSIF l_highest_pay_amt > l_highest_signer_rec.single_limit_amount THEN
        RETURN(NULL);
      END IF;
    
    ELSIF l_active_grp = '1' THEN
    
      IF l_highest_pay_amt <= l_groupa_single_limit THEN
        RETURN(l_groupa_primary);
      ELSIF l_highest_pay_amt > l_groupa_single_limit THEN
        RETURN(NULL);
      END IF;
    
    ELSE
    
      RETURN(NULL); -- Added ELSE statement so that function always returns somevalue. Change made as per Michal Tzvik recommendation -- 10-AUG-2015 CHG0035411 SAkula
    
    END IF;
  
    RETURN(NULL); -- Added RETURN(NULL) statement so that function always returns somevalue. Change made as per Michal Tzvik recommendation -- 20-AUG-2015 CHG0035411 SAkula
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'GET_DEFAULT_REQUIRED_APPVR_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      --RAISE;
      RETURN(NULL);
  END get_default_required_appvr_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    IS_REQ_APPROVER_UPDATABLE_SL6
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns a value of Y or N based on the Profile option NP4 Value
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  30-MAR-2015        1.1                  Sandeep Akula     Changed Function to always return a value of Y -- CHG0034462
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION is_req_approver_updatable_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'IS_REQ_APPROVER_UPDATABLE_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || ' L_NP4 :' ||
		        l_np4);
  
    /*   IF l_np4 = 'Y' THEN
      RETURN('N');
    ELSE
      RETURN('Y');
    END IF; */
  
    RETURN('Y'); -- Required Approver should always be editable 03/30/2015 SAkula (CHG0034462)
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'IS_REQ_APPROVER_UPDATABLE_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END is_req_approver_updatable_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    REQUIRED_APPROVER_LOV_SL6
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns List of Values for Required Approver Field
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION required_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
    RETURN required_approver_tbl
    PIPELINED IS
  
    l_pmt_rec                highest_payment_amt_rec;
    unassgn_req_approver_rec required_approver_rec;
  
    l_groupa_single_limit NUMBER;
    l_groupb_single_limit NUMBER;
    l_groupc_single_limit NUMBER;
    l_groupa_primary      NUMBER;
    l_groupb_primary      NUMBER;
    l_groupc_primary      NUMBER;
    l_highest_pay_amt     NUMBER;
    l_groups              VARCHAR2(150);
    l_active_grp          NUMBER;
    l_highest_signer_rec  signer_group_rec;
    l_lowest_signer_rec   signer_group_rec;
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
    CURSOR c_approvers(cp_payment_id IN NUMBER,
	           cp_group      IN VARCHAR2) IS
      SELECT ppx.full_name,
	 cbs.person_id,
	 cbs.signer_group
      FROM   iby_payments_all  ip,
	 ce_ba_signatories cbs,
	 per_people_x      ppx
      WHERE  ip.internal_bank_account_id = cbs.bank_account_id
      AND    cbs.person_id = ppx.person_id
      AND    ip.payment_id = cp_payment_id
      AND    cbs.deleted_flag = 'N'
      AND    cbs.signer_group IN
	 (SELECT *
	   FROM   TABLE(xx_in_list(cp_group)))
      AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	 trunc(nvl(cbs.end_date, SYSDATE));
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'REQUIRED_APPROVER_LOV_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec             := get_highest_payment_rec(p_payment_service_request_id);
    l_groupa_single_limit := get_groupa_single_limit(p_payment_service_request_id);
    l_groupb_single_limit := get_groupb_single_limit(p_payment_service_request_id);
    l_groupc_single_limit := get_groupc_single_limit(p_payment_service_request_id);
    l_groupa_primary      := get_groupa_primary_approver(p_payment_service_request_id);
    l_groupb_primary      := get_groupb_primary_approver(p_payment_service_request_id);
    l_groupc_primary      := get_groupc_primary_approver(p_payment_service_request_id);
    l_highest_pay_amt     := l_pmt_rec.converted_payment_amount;
    l_highest_signer_rec  := get_highest_group(p_payment_service_request_id);
    l_lowest_signer_rec   := get_lowest_group(p_payment_service_request_id);
  
    l_groups     := '';
    l_active_grp := '';
    l_active_grp := get_no_of_active_groups(p_payment_service_request_id);
  
    IF l_active_grp = '3' THEN
    
      IF l_highest_pay_amt <= l_groupc_single_limit THEN
        l_groups := 'GROUP A,GROUP B,GROUP C';
      ELSIF l_highest_pay_amt <= l_groupb_single_limit AND
	l_highest_pay_amt >= l_groupc_single_limit THEN
        l_groups := 'GROUP B,GROUP A';
      ELSIF l_highest_pay_amt <= l_groupa_single_limit AND
	l_highest_pay_amt >= l_groupb_single_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_single_limit THEN
        l_groups := NULL;
      END IF;
    
    ELSIF l_active_grp = '2' THEN
    
      IF l_highest_pay_amt <= l_lowest_signer_rec.single_limit_amount THEN
        l_groups := l_lowest_signer_rec.signer_group || ',' ||
	        l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt <= l_highest_signer_rec.single_limit_amount AND
	l_highest_pay_amt >= l_lowest_signer_rec.single_limit_amount THEN
        l_groups := l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt > l_highest_signer_rec.single_limit_amount THEN
        l_groups := NULL;
      END IF;
    
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'REQUIRED_APPROVER_LOV_SL6',
	         message   => 'l_active_grp :' || l_active_grp || '-' ||
		          'l_groups :' || l_groups);
    
    ELSIF l_active_grp = '1' THEN
    
      IF l_highest_pay_amt <= l_groupa_single_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_single_limit THEN
        l_groups := NULL;
      END IF;
    
    END IF;
  
    IF c_approvers%ISOPEN THEN
      CLOSE c_approvers;
    END IF;
    OPEN c_approvers(l_pmt_rec.payment_id, l_groups);
    LOOP
      FETCH c_approvers
        INTO unassgn_req_approver_rec.approver_name,
	 unassgn_req_approver_rec.approver_id,
	 unassgn_req_approver_rec.approver_group;
      EXIT WHEN c_approvers%NOTFOUND;
      PIPE ROW(unassgn_req_approver_rec);
    END LOOP;
    CLOSE c_approvers;
  
    RETURN;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'REQUIRED_APPROVER_LOV_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN;
  END required_approver_lov_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    SHOW_OPTIONAL_APPROVER_SL6
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns a value of Y or N based on the Profile option NP4 Value
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION show_optional_approver_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'SHOW_OPTIONAL_APPROVER_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || ' L_NP4 :' ||
		        l_np4);
  
    IF l_np4 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'SHOW_OPTIONAL_APPROVER_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END show_optional_approver_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    OPTIONAL_APPROVER_LOV_SL6
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns List of Values for Optional/Additional Approver Field
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION optional_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
    RETURN optional_approver_tbl
    PIPELINED IS
  
    l_pmt_rec                highest_payment_amt_rec;
    unassgn_opt_approver_rec optional_approver_rec;
  
    l_groupa_joint_limit NUMBER;
    l_groupb_joint_limit NUMBER;
    l_groupc_joint_limit NUMBER;
    l_groupa_primary     NUMBER;
    l_groupb_primary     NUMBER;
    l_groupc_primary     NUMBER;
    l_highest_pay_amt    NUMBER;
    l_active_grp         NUMBER;
    l_highest_signer_rec signer_group_rec;
    l_lowest_signer_rec  signer_group_rec;
    l_groups             VARCHAR2(150);
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
    CURSOR c_approvers(cp_payment_id IN NUMBER,
	           cp_in_group   IN VARCHAR2
	           --cp_out_group  IN VARCHAR2
	           ) IS
      SELECT ppx.full_name,
	 cbs.person_id,
	 cbs.signer_group
      FROM   iby_payments_all  ip,
	 ce_ba_signatories cbs,
	 per_people_x      ppx
      WHERE  ip.internal_bank_account_id = cbs.bank_account_id
      AND    cbs.person_id = ppx.person_id
      AND    ip.payment_id = cp_payment_id
      AND    cbs.deleted_flag = 'N'
      AND    cbs.signer_group IN
	 (SELECT *
	   FROM   TABLE(xx_in_list(cp_in_group)))
	--AND    cbs.person_id NOT IN (SELECT * FROM   TABLE(xx_in_list(cp_out_group)))
      AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	 trunc(nvl(cbs.end_date, SYSDATE));
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'OPTIONAL_APPROVER_LOV_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    l_groupa_joint_limit := get_groupa_joint_limit(p_payment_service_request_id);
    l_groupb_joint_limit := get_groupb_joint_limit(p_payment_service_request_id);
    l_groupc_joint_limit := get_groupc_joint_limit(p_payment_service_request_id);
    l_groupa_primary     := get_groupa_primary_approver(p_payment_service_request_id);
    l_groupb_primary     := get_groupb_primary_approver(p_payment_service_request_id);
    l_groupc_primary     := get_groupc_primary_approver(p_payment_service_request_id);
    l_highest_pay_amt    := l_pmt_rec.converted_payment_amount;
    l_highest_signer_rec := get_highest_group(p_payment_service_request_id);
    l_lowest_signer_rec  := get_lowest_group(p_payment_service_request_id);
  
    l_groups     := '';
    l_active_grp := '';
    l_active_grp := get_no_of_active_groups(p_payment_service_request_id);
  
    IF l_active_grp = '3' THEN
    
      IF l_highest_pay_amt <= l_groupc_joint_limit THEN
        l_groups := 'GROUP A,GROUP B,GROUP C';
      ELSIF l_highest_pay_amt <= l_groupb_joint_limit AND
	l_highest_pay_amt >= l_groupc_joint_limit THEN
        l_groups := 'GROUP B,GROUP A';
      ELSIF l_highest_pay_amt <= l_groupa_joint_limit AND
	l_highest_pay_amt >= l_groupb_joint_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_joint_limit THEN
        l_groups := NULL;
      END IF;
    
    ELSIF l_active_grp = '2' THEN
    
      IF l_highest_pay_amt <= l_lowest_signer_rec.joint_limit_amount THEN
        l_groups := l_lowest_signer_rec.signer_group || ',' ||
	        l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt <= l_highest_signer_rec.joint_limit_amount AND
	l_highest_pay_amt >= l_lowest_signer_rec.joint_limit_amount THEN
        l_groups := l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt > l_highest_signer_rec.joint_limit_amount THEN
        l_groups := NULL;
      END IF;
    
    ELSIF l_active_grp = '1' THEN
    
      IF l_highest_pay_amt <= l_groupa_joint_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_joint_limit THEN
        l_groups := NULL;
      END IF;
    
    END IF;
  
    IF c_approvers%ISOPEN THEN
      CLOSE c_approvers;
    END IF;
    OPEN c_approvers(l_pmt_rec.payment_id, l_groups);
    LOOP
      FETCH c_approvers
        INTO unassgn_opt_approver_rec.approver_name,
	 unassgn_opt_approver_rec.approver_id,
	 unassgn_opt_approver_rec.approver_group;
      EXIT WHEN c_approvers%NOTFOUND;
      PIPE ROW(unassgn_opt_approver_rec);
    END LOOP;
    CLOSE c_approvers;
  
    RETURN;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'OPTIONAL_APPROVER_LOV_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN;
  END optional_approver_lov_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    SHOW_SUPPLEMENTAL_APPROVER_SL6
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns a value of Y or N based on the Profile option NP4 and NP5 Value
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION show_supplemental_approver_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'SHOW_SUPPLEMENTAL_APPROVER_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id || 'L_NP4 :' ||
		        l_np4 || 'L_NP5 :' || l_np5);
  
    IF l_np4 = 'Y' AND l_np5 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'SHOW_SUPPLEMENTAL_APPROVER_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END show_supplemental_approver_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    SUPPLEMENTAL_APPROVER_LOV_SL6
  Author's Name:   Sandeep Akula
  Date Written:    22-JAN-2015
  Purpose:         This Function returns List of Values for Supplemental Approver Field
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION supplemental_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
    RETURN suppl_approver_tbl
    PIPELINED IS
  
    l_pmt_rec                 highest_payment_amt_rec;
    unassgn_supp_approver_rec suppl_approver_rec;
    l_np1                     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                     fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
    l_groupa_joint_limit NUMBER;
    l_groupb_joint_limit NUMBER;
    l_groupc_joint_limit NUMBER;
    l_groupa_primary     NUMBER;
    l_groupb_primary     NUMBER;
    l_groupc_primary     NUMBER;
    l_highest_pay_amt    NUMBER;
    l_active_grp         NUMBER;
    l_highest_signer_rec signer_group_rec;
    l_lowest_signer_rec  signer_group_rec;
    l_groups             VARCHAR2(150);
  
    CURSOR c_approvers(cp_payment_id IN NUMBER,
	           cp_in_group   IN VARCHAR2
	           --cp_out_group  IN VARCHAR2
	           ) IS
      SELECT ppx.full_name,
	 cbs.person_id,
	 cbs.signer_group
      FROM   iby_payments_all  ip,
	 ce_ba_signatories cbs,
	 per_people_x      ppx
      WHERE  ip.internal_bank_account_id = cbs.bank_account_id
      AND    cbs.person_id = ppx.person_id
      AND    ip.payment_id = cp_payment_id
      AND    cbs.deleted_flag = 'N'
      AND    cbs.signer_group IN
	 (SELECT *
	   FROM   TABLE(xx_in_list(cp_in_group)))
	--AND    cbs.person_id NOT IN (SELECT * FROM   TABLE(xx_in_list(cp_out_group)))
      AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	 trunc(nvl(cbs.end_date, SYSDATE));
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'SUPPLEMENTAL_APPROVER_LOV_SL6',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    l_groupa_joint_limit := get_groupa_joint_limit(p_payment_service_request_id);
    l_groupb_joint_limit := get_groupb_joint_limit(p_payment_service_request_id);
    l_groupc_joint_limit := get_groupc_joint_limit(p_payment_service_request_id);
    l_groupa_primary     := get_groupa_primary_approver(p_payment_service_request_id);
    l_groupb_primary     := get_groupb_primary_approver(p_payment_service_request_id);
    l_groupc_primary     := get_groupc_primary_approver(p_payment_service_request_id);
    l_highest_pay_amt    := l_pmt_rec.converted_payment_amount;
    l_highest_signer_rec := get_highest_group(p_payment_service_request_id);
    l_lowest_signer_rec  := get_lowest_group(p_payment_service_request_id);
  
    l_groups     := '';
    l_active_grp := '';
    l_active_grp := get_no_of_active_groups(p_payment_service_request_id);
  
    IF l_active_grp = '3' THEN
    
      IF l_highest_pay_amt <= l_groupc_joint_limit THEN
        l_groups := 'GROUP A,GROUP B,GROUP C';
      ELSIF l_highest_pay_amt <= l_groupb_joint_limit AND
	l_highest_pay_amt >= l_groupc_joint_limit THEN
        l_groups := 'GROUP B,GROUP A';
      ELSIF l_highest_pay_amt <= l_groupa_joint_limit AND
	l_highest_pay_amt >= l_groupb_joint_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_joint_limit THEN
        l_groups := NULL;
      END IF;
    
    ELSIF l_active_grp = '2' THEN
    
      IF l_highest_pay_amt <= l_lowest_signer_rec.joint_limit_amount THEN
        l_groups := l_lowest_signer_rec.signer_group || ',' ||
	        l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt <= l_highest_signer_rec.joint_limit_amount AND
	l_highest_pay_amt >= l_lowest_signer_rec.joint_limit_amount THEN
        l_groups := l_highest_signer_rec.signer_group;
      ELSIF l_highest_pay_amt > l_highest_signer_rec.joint_limit_amount THEN
        l_groups := NULL;
      END IF;
    
    ELSIF l_active_grp = '1' THEN
    
      IF l_highest_pay_amt <= l_groupa_joint_limit THEN
        l_groups := 'GROUP A';
      ELSIF l_highest_pay_amt > l_groupa_joint_limit THEN
        l_groups := NULL;
      END IF;
    
    END IF;
  
    IF c_approvers%ISOPEN THEN
      CLOSE c_approvers;
    END IF;
    OPEN c_approvers(l_pmt_rec.payment_id, l_groups);
    LOOP
      FETCH c_approvers
        INTO unassgn_supp_approver_rec.approver_name,
	 unassgn_supp_approver_rec.approver_id,
	 unassgn_supp_approver_rec.approver_group;
      EXIT WHEN c_approvers%NOTFOUND;
      PIPE ROW(unassgn_supp_approver_rec);
    END LOOP;
    CLOSE c_approvers;
  
    RETURN;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'SUPPLEMENTAL_APPROVER_LOV_SL6',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN;
  END supplemental_approver_lov_sl6;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    REMOVE_PROPOSED_PAY_BUTTON_SL7
  Author's Name:   Sandeep Akula
  Date Written:    20-JAN-2015
  Purpose:         This Function returns a value of Y or N based on the Profile option NP1 Value, Payment Batch Status, First Approver and Workflow Status
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-JAN-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION remove_proposed_pay_button_sl7(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_current_user fnd_user.user_name%TYPE := fnd_global.user_name;
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'REMOVE_PROPOSED_PAY_BUTTON_SL7',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id || 'L_NP1 :' ||
		        l_np1 || 'l_current_user :' ||
		        l_current_user || 'Workflow Status :' ||
		        pay_workflow_status_sl5(p_payment_service_request_id));
  
    IF l_np1 = 'Y' AND get_pay_process_req_status(p_payment_service_request_id) =
       'Pending Proposed Payment Review' AND
       get_first_approver(p_payment_service_request_id) <> l_current_user AND
       pay_workflow_status_sl5(p_payment_service_request_id) = 'IN_PROCESS' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'REMOVE_PROPOSED_PAY_BUTTON_SL7',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
  END remove_proposed_pay_button_sl7;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    REMOVE_REJECT_ITEMS_BUTTON_SL8
  Author's Name:   Sandeep Akula
  Date Written:    30-DEC-2014
  Purpose:         This Function returns a value of Y or N based on the Profile option NP1 Value
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  30-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION remove_reject_items_button_sl8(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'REMOVE_REJECT_ITEMS_BUTTON_SL8',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id || 'L_NP1 :' ||
		        l_np1);
  
    IF l_np1 = 'Y' THEN
      RETURN('Y');
    ELSE
      RETURN('N');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'REMOVE_REJECT_ITEMS_BUTTON_SL8',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      RETURN('N');
  END remove_reject_items_button_sl8;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    GET_ACK_EMAIL
  Author's Name:   Sandeep Akula
  Date Written:    31-DEC-2014
  Purpose:         This Procedure dervies Email Address to which the Acknowledgment Notification should go
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  31-DEC-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_ack_email(p_ack_level  IN NUMBER,
		  p_orgnlmsgid IN NUMBER,
		  p_to_email   OUT VARCHAR2,
		  p_cc_email   OUT VARCHAR2) IS
  
    l_to_email VARCHAR2(150);
    l_np1      fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2      fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3      fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4      fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5      fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_ACK_EMAIL',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || ' p_ack_level :' ||
		        p_ack_level || 'p_orgnlmsgid :' ||
		        p_orgnlmsgid);
  
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
  
    p_to_email := l_to_email;
    p_cc_email := NULL;
  
  END get_ack_email;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    GET_DOC_STATUS
  Author's Name:   Sandeep Akula
  Date Written:    08-JAN-2015
  Purpose:         This Function returns the Current status of Payment Workflow
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  08-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_doc_status(p_payment_service_request_id IN NUMBER,
		  p_doc_id                     IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_doc_status xxobjt_wf_doc_instance.doc_status%TYPE;
    l_np1        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5        fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'GET_DOC_STATUS',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id || 'p_doc_id :' ||
		        p_doc_id);
  
    BEGIN
      SELECT doc_status
      INTO   l_doc_status
      FROM   xxobjt_wf_doc_instance di1
      WHERE  di1.doc_id = p_doc_id
      AND    di1.n_attribute1 = p_payment_service_request_id
      AND    EXISTS
       (SELECT MAX(di2.doc_instance_id)
	  FROM   xxobjt_wf_doc_instance di2
	  WHERE  di2.doc_id = di1.doc_id
	  AND    di2.n_attribute1 = di1.n_attribute1);
    EXCEPTION
      WHEN OTHERS THEN
        l_doc_status := '';
    END;
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'get_doc_status',
	       message   => 'l_doc_status :' || l_doc_status);
  
    RETURN(l_doc_status);
  
  END get_doc_status;

  /* Procedure GET_APPROVERS_ORDER not used. Kept it for History */
  PROCEDURE get_approvers_order(p_approvers_string IN VARCHAR2,
		        p_flag             IN VARCHAR2,
		        p_final_approvers  OUT VARCHAR2,
		        p_err_code         OUT VARCHAR2,
		        p_err_msg          OUT VARCHAR2) IS
  
    l_req_approver          VARCHAR2(100) := '';
    l_opt_approver          VARCHAR2(100) := '';
    l_supp_approver         VARCHAR2(100) := '';
    l_final_approvers_order VARCHAR2(500) := '';
    l_np1                   fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                   fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                   fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                   fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                   fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    l_req_approver  := substr(p_approvers_string,
		      1,
		      instr(p_approvers_string, ',', 1) - 1); -- Required Approver
    l_opt_approver  := substr(p_approvers_string,
		      instr(p_approvers_string, ',', 1, 1) + 1,
		      instr(p_approvers_string, ',', 1, 2) -
		      instr(p_approvers_string, ',', 1, 1) - 1); -- Optional Approver
    l_supp_approver := substr(p_approvers_string,
		      instr(p_approvers_string, ',', 1, 2) + 1); -- Supplemental Approver
  
    IF p_flag = 'Y' THEN
      l_final_approvers_order := rtrim(l_opt_approver || ',' ||
			   l_supp_approver || ',' ||
			   l_req_approver,
			   ',');
    ELSE
      l_final_approvers_order := rtrim(l_req_approver || ',' ||
			   l_opt_approver || ',' ||
			   l_supp_approver,
			   ',');
    END IF;
  
    IF l_final_approvers_order IS NULL OR
       substr(l_final_approvers_order, 1, 1) = ',' OR
       substr(l_final_approvers_order,
	  length(l_final_approvers_order) - 1,
	  1) = ',' THEN
      p_final_approvers := NULL;
      p_err_code        := 'F';
      p_err_msg         := 'Error Occured while validating Approver List :' ||
		   p_approvers_string ||
		   '. Final Approver String :' ||
		   l_final_approvers_order || ' is Invalid';
    ELSE
      p_final_approvers := l_final_approvers_order;
      p_err_code        := 'S';
      p_err_msg         := NULL;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 'F';
      p_err_msg  := 'Error Occured while validating Approver List.' ||
	        'SQL Error is :' || SQLERRM;
  END get_approvers_order;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    SUBMIT_REPORT
  Author's Name:   Sandeep Akula
  Date Written:    26-JAN-2015
  Purpose:         This Procedure submits report "Payment Process Request Status Report" and waits till the report completes and returns the appropriate error codes.
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  26-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE submit_report(p_doc_instance_id IN NUMBER,
		  p_err_code        OUT NUMBER,
		  p_err_message     OUT VARCHAR2) IS
  
    l_payment_process_request iby_pay_service_requests.call_app_pay_service_req_code%TYPE;
    l_instance_rec            xxobjt_wf_doc_instance%ROWTYPE;
    l_doc_instance_id         NUMBER;
    rpt_submit_excp EXCEPTION;
    rpt_error       EXCEPTION;
    rpt_warning     EXCEPTION;
    l_request_id        NUMBER;
    l_completed         BOOLEAN;
    l_phase             VARCHAR2(200);
    l_vstatus           VARCHAR2(200);
    l_dev_phase         VARCHAR2(200);
    l_dev_status        VARCHAR2(200);
    l_message           VARCHAR2(200);
    l_status_code       VARCHAR2(1);
    l_prg_exe_counter   VARCHAR2(10);
    l_error_message     VARCHAR2(2000);
    l_user_id           NUMBER;
    l_responsibility_id NUMBER;
    l_application_id    NUMBER;
    l_np3               fnd_profile_option_values.profile_option_value%TYPE;
    l_move_msg          VARCHAR2(32767);
    move_file_excp EXCEPTION;
    l_file_name VARCHAR2(1000);
  
  BEGIN
    l_prg_exe_counter := '1';
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'SUBMIT_REPORT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id);
  
    l_prg_exe_counter := '2';
    l_error_message   := 'Error Occured while deriving l_instance_rec';
    l_instance_rec    := xxobjt_wf_doc_util.get_doc_instance_info(p_doc_instance_id);
  
    l_prg_exe_counter := '3';
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'SUBMIT_REPORT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id ||
		        ' l_instance_rec.user_id :' ||
		        l_instance_rec.user_id ||
		        ' l_instance_rec.resp_id :' ||
		        l_instance_rec.resp_id ||
		        ' l_instance_rec.resp_appl_id :' ||
		        l_instance_rec.resp_appl_id);
  
    l_prg_exe_counter         := '4';
    l_payment_process_request := '';
    l_error_message           := 'Error Occured while deriving l_payment_process_request';
    SELECT c.call_app_pay_service_req_code
    INTO   l_payment_process_request
    FROM   xxobjt_wf_docs           a,
           xxobjt_wf_doc_instance   b,
           iby_pay_service_requests c
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.n_attribute1 = c.payment_service_request_id
    AND    b.doc_instance_id = p_doc_instance_id;
  
    l_prg_exe_counter := '5';
    l_error_message   := 'Error Occured while Initializing Apps Session';
    fnd_global.apps_initialize(user_id      => l_instance_rec.user_id,
		       resp_id      => l_instance_rec.resp_id,
		       resp_appl_id => l_instance_rec.resp_appl_id);
  
    l_prg_exe_counter := '6';
  
    l_np3           := '';
    l_error_message := 'Error Occured while assigned value for L_NP3';
    l_np3           := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
  
    l_prg_exe_counter := '6.1';
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'SUBMIT_REPORT',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id ||
		        ' L_NP3 :' || l_np3 || 'l_item_key :' ||
		        l_instance_rec.wf_item_key);
  
    l_prg_exe_counter := '7';
    l_error_message   := 'Error Occured while submitting Payment Process Request Status Report Concurrent request';
    l_request_id      := fnd_request.submit_request(application => 'IBY',
				    program     => 'IBY_FD_PPR_STATUS_PRT', -- Payment Process Request Status Report
				    argument1   => 'SQLAP', -- Source Product
				    argument2   => l_payment_process_request, -- Payment Process Request
				    argument3   => l_np3 -- Format
				    );
    COMMIT;
  
    l_prg_exe_counter := '8';
    IF l_request_id = 0 THEN
      l_prg_exe_counter := '5';
      RAISE rpt_submit_excp;
    END IF;
  
    l_prg_exe_counter := '9';
  
    l_error_message := 'Error Occured while assigning value for attribute REQUEST_ID, Value:' ||
	           l_request_id;
    wf_engine.setitemattrnumber(itemtype => g_item_type,
		        itemkey  => l_instance_rec.wf_item_key,
		        aname    => 'REQUEST_ID',
		        avalue   => l_request_id);
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'SUBMIT_REPORT',
	       message   => 'l_request_id' || l_request_id);
  
    l_prg_exe_counter := '10';
    --Wait for the completion of the concurrent request (if submitted successfully)
    l_error_message := 'Error Occured while Waiting for the completion of the Payment Process Request Status Report concurrent request';
    l_completed     := apps.fnd_concurrent.wait_for_request(request_id => l_request_id,
					INTERVAL   => 10,
					max_wait   => 3600, -- 60 Minutes
					phase      => l_phase,
					status     => l_vstatus,
					dev_phase  => l_dev_phase,
					dev_status => l_dev_status,
					message    => l_message);
  
    l_prg_exe_counter := '11';
  
    /*---------------------------------------------------------------------------------------
      -- Check for the Concurrent Program status
    ------------------------------------------------------------------------------------*/
    l_error_message := 'Error Occured while deriving the status code of the Payment Process Request Status Report';
    SELECT status_code
    INTO   l_status_code
    FROM   fnd_concurrent_requests
    WHERE  request_id = l_request_id;
  
    l_prg_exe_counter := '12';
  
    IF l_status_code = 'E' -- Error
     THEN
      l_prg_exe_counter := '13';
      l_error_message   := 'Payment Process Request Status Report Request with Request ID :' ||
		   l_request_id || ' completed in Error';
      RAISE rpt_error;
    
    ELSIF l_status_code = 'G' -- Warning
     THEN
      l_prg_exe_counter := '14';
      l_error_message   := 'Payment Process Request Status Report Request with Request ID :' ||
		   l_request_id || ' completed in Warning';
      RAISE rpt_warning;
    
    ELSIF l_status_code = 'C' -- Sucess
     THEN
      l_prg_exe_counter := '15';
      l_file_name       := 'o' || l_request_id || '.out';
      l_move_msg        := '';
    
      l_error_message   := 'Error Occured in function move_output_file';
      l_move_msg        := move_output_file(l_file_name);
      l_prg_exe_counter := '16';
      IF l_move_msg IS NOT NULL THEN
        l_error_message   := l_move_msg;
        l_prg_exe_counter := '17';
        RAISE move_file_excp;
      END IF;
    
      p_err_code    := '0';
      p_err_message := NULL;
    
      l_prg_exe_counter := '18';
    
    END IF;
  
    l_prg_exe_counter := '19';
  
  EXCEPTION
    WHEN rpt_submit_excp THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN rpt_error THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN rpt_warning THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN move_file_excp THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN OTHERS THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter || '-' ||
	           SQLERRM;
      -- Debug Message
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'SUBMIT_REPORT',
	         message   => 'OTHERS EXCEPTION' || ' p_err_message :' ||
		          p_err_message);
  END submit_report;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function  Name:    move_output_file
  Author's Name:   Sandeep Akula
  Date Written:    23-FEB-2015
  Purpose:         This Function moves the report output file from Standard Oracle Directory to a shared directory
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  23-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION move_output_file(p_file_name IN VARCHAR2) RETURN VARCHAR2 IS
    l_error_message    VARCHAR2(2000);
    l_dest_directory   VARCHAR2(1000);
    l_source_directory VARCHAR2(1000);
    l_request_id       NUMBER;
    l_prg_exe_counter  VARCHAR2(10);
    l_completed        BOOLEAN;
    l_phase            VARCHAR2(200);
    l_vstatus          VARCHAR2(200);
    l_dev_phase        VARCHAR2(200);
    l_dev_status       VARCHAR2(200);
    l_message          VARCHAR2(200);
    l_status_code      VARCHAR2(1);
    move_submit_excp EXCEPTION;
    move_error       EXCEPTION;
    move_warning     EXCEPTION;
  
  BEGIN
  
    l_prg_exe_counter := '1';
    l_error_message   := 'Error Occured while deriving Source Directory';
    SELECT directory_path
    INTO   l_source_directory
    FROM   all_directories
    WHERE  directory_name IN ('XXFND_OUT_DIR');
  
    l_prg_exe_counter := '2';
    l_error_message   := 'Error Occured while deriving Destination Directory';
    SELECT directory_path
    INTO   l_dest_directory
    FROM   all_directories
    WHERE  directory_name IN ('XXIBY_PAY_APPROVAL_ATTMNT_DIR');
  
    l_prg_exe_counter := '3';
  
    l_error_message := 'Error Occured while Calling the Move Host Program';
    l_request_id    := fnd_request.submit_request(application => 'XXOBJT',
				  program     => 'XXCPFILE',
				  argument1   => l_source_directory, -- from_dir
				  argument2   => p_file_name, -- from_file_name
				  argument3   => l_dest_directory, -- to_dir
				  argument4   => p_file_name -- to_file_name
				  );
    COMMIT;
    l_prg_exe_counter := '4';
  
    IF l_request_id = 0 THEN
      l_prg_exe_counter := '5';
      l_error_message   := 'Move Program Could not be submitted.' ||
		   ' Error Message :' || l_error_message;
      RAISE move_submit_excp;
    
    ELSE
      l_prg_exe_counter := '6';
      apps.fnd_file.put_line(apps.fnd_file.log,
		     'Submitted the Move concurrent program with request_id :' ||
		     l_request_id);
    END IF;
  
    l_prg_exe_counter := '7';
    --Wait for the completion of the concurrent request (if submitted successfully)
    l_error_message := 'Error Occured while Waiting for the completion of the Move concurrent request';
    l_completed     := apps.fnd_concurrent.wait_for_request(request_id => l_request_id,
					INTERVAL   => 10,
					max_wait   => 3600, -- 60 Minutes
					phase      => l_phase,
					status     => l_vstatus,
					dev_phase  => l_dev_phase,
					dev_status => l_dev_status,
					message    => l_message);
  
    l_prg_exe_counter := '8';
  
    /*---------------------------------------------------------------------------------------
      -- Check for the Concurrent Program status
    ------------------------------------------------------------------------------------*/
    l_error_message := 'Error Occured while deriving the status code of the submitted program';
    SELECT status_code
    INTO   l_status_code
    FROM   fnd_concurrent_requests
    WHERE  request_id = l_request_id;
  
    l_prg_exe_counter := '9';
  
    IF l_status_code = 'E' -- Error
     THEN
      l_prg_exe_counter := '10';
      l_error_message   := 'Move Program Request with Request ID :' ||
		   l_request_id || ' completed in Error';
      RAISE move_error;
    
    ELSIF l_status_code = 'G' -- Warning
     THEN
      l_prg_exe_counter := '11';
      l_error_message   := 'Move Program Request with Request ID :' ||
		   l_request_id || ' completed in Warning';
      RAISE move_warning;
    
    ELSIF l_status_code = 'C' -- Sucess
     THEN
      l_prg_exe_counter := '12';
      fnd_file.put_line(fnd_file.log, 'Move Program Completed Sucessfully');
      l_error_message := NULL;
    END IF;
  
    l_prg_exe_counter := '13';
    RETURN(l_error_message);
  
  EXCEPTION
    WHEN move_submit_excp THEN
      RETURN(l_error_message);
    WHEN move_error THEN
      RETURN(l_error_message);
    WHEN move_warning THEN
      RETURN(l_error_message);
    WHEN OTHERS THEN
      RETURN(l_error_message || '-' || l_prg_exe_counter || '-' || SQLERRM);
  END move_output_file;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_notification_attachment
  Author's Name:   Sandeep Akula
  Date Written:    26-JAN-2015
  Purpose:         This Procedure gets the output of program "Payment Process Request Status Report" into a BLOB Variable.
                   To get the report file; first custom code in "Before Approval" should execute sucessfully (Refer to Objet Doc Approval Set Up)
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  26-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_notification_attachment(document_id   IN VARCHAR2,
			    display_type  IN VARCHAR2,
			    document      IN OUT BLOB,
			    document_type IN OUT VARCHAR2) IS
  
    l_payment_process_request iby_pay_service_requests.call_app_pay_service_req_code%TYPE;
    l_doc_instance_id         NUMBER;
    source_bfile              BFILE;
    dest_lob                  BLOB := NULL; --empty_blob();
    offset                    NUMBER := 1;
    l_file_name               VARCHAR2(200);
    l_directory               VARCHAR2(100) := 'XXIBY_PAY_APPROVAL_ATTMNT_DIR';
    l_error_message           VARCHAR2(2000);
    l_request_id              NUMBER;
    l_prg_exe_counter         VARCHAR2(20);
    l_item_key                VARCHAR2(100);
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_notification_attachment',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || 'document_id :' ||
		        document_id || 'display_type :' ||
		        display_type);
  
    l_prg_exe_counter := '1';
  
    l_error_message   := 'Error Occured while deriving l_doc_instance_id';
    l_doc_instance_id := to_number(document_id);
  
    l_prg_exe_counter := '2';
    l_item_key        := '';
    l_error_message   := 'get_notification_attachment: Error Occured while deriving l_item_key';
    SELECT b.wf_item_key
    INTO   l_item_key
    FROM   xxobjt_wf_docs         a,
           xxobjt_wf_doc_instance b
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.doc_instance_id = l_doc_instance_id;
  
    l_prg_exe_counter := '3';
    l_error_message   := 'Error Occured while deriving l_request_id';
    l_request_id      := wf_engine.getitemattrnumber(itemtype => g_item_type,
				     itemkey  => l_item_key,
				     aname    => 'REQUEST_ID');
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_notification_attachment',
	       message   => 'l_request_id' || l_request_id);
  
    l_prg_exe_counter := '4';
  
    l_file_name       := '';
    l_error_message   := 'Error Occured while deriving l_file_name';
    l_file_name       := 'o' || l_request_id || '.out';
    l_prg_exe_counter := '5';
  
    /* loading data from a file into BLOB variable */
  
    l_error_message := 'Error Occured in dbms_lob.createtemporary';
    -- Creates a temporary BLOB or CLOB and its corresponding index in the user's default temporary tablespace
    dbms_lob.createtemporary(dest_lob, TRUE, dbms_lob.session);
  
    l_prg_exe_counter := '6';
  
    l_error_message := 'Error Occured in bfilename';
    -- BFILE Returns a BFILE locator that is associated with a physical LOB binary file on the server file system.
    source_bfile := bfilename(l_directory, l_file_name);
  
    l_prg_exe_counter := '7';
  
    l_error_message := 'Error Occured in dbms_lob.fileopen';
    -- procedure opens a BFILE for read-only access. BFILE data may not be written through the database.
    dbms_lob.fileopen(source_bfile, dbms_lob.file_readonly);
  
    l_prg_exe_counter := '8';
  
    l_error_message := 'Error Occured in dbms_lob.loadblobfromfile';
    -- loads data from BFILE to internal BLOB.
    dbms_lob.loadblobfromfile(dest_lob    => dest_lob,
		      src_bfile   => source_bfile,
		      amount      => dbms_lob.getlength(source_bfile),
		      dest_offset => offset,
		      src_offset  => offset);
  
    l_prg_exe_counter := '9';
  
    l_error_message := 'Error Occured in dbms_lob.fileclose';
    -- closes a BFILE that has already been opened through the input locator.
    dbms_lob.fileclose(source_bfile);
  
    l_prg_exe_counter := '10';
    l_error_message   := 'Error Occured in document_type';
    document_type     := 'application/pdf' || ';name=' || l_request_id ||
		 '.pdf'; --|| filename;
    l_prg_exe_counter := '11';
    l_error_message   := 'Error Occured in dbms_lob.copy';
    dbms_lob.copy(document, dest_lob, dbms_lob.getlength(dest_lob));
    l_prg_exe_counter := '12';
  
    l_prg_exe_counter := '13';
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_notification_attachment',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      wf_core.context('XXIBY_PAY_APRROVAL_UTIL',
	          'GET_NOTIFICATION_ATTACHMENT',
	          document_id,
	          display_type,
	          l_error_message || '-' || l_prg_exe_counter || '-' ||
	          SQLERRM);
      RAISE;
  END get_notification_attachment;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_notification_body
  Author's Name:   Sandeep Akula
  Date Written:    26-JAN-2015
  Purpose:         This Procedure builds the content of the Approval Notification
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  26-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  18-MAR-2015        1.1                  Sandeep Akula     Added a new condition to cursor c_body_msg1 -- CHG0034886
  25-AUG-2015        1.2                  Sandeep Akula     CHG0035411 - Changed Notification body content by adding payment currency, masked account number and formatting all Numeric values
                                                                       - Added Additional Details Link
  31-OCT-2017        1.3                  Piyali Bhowmick   CHG0040948 - Adding a following status in payment status of  CURSOR c_body_msg1
                                                                        1. PAYMENT_FAILED_VALIDATION
                                                                       - Adding the following status in document status of  CURSOR c_body_msg2
                                                                         1.  VOID_BY_OVERFLOW_REPRINT 
                                                                         2.  VOID_BY_SETUP_REPRINT
                                                                         3.  REJECTED
                                                                         4.  FAILED_BY_CALLING_APP
                                                                         5.  FAILED_BY_REJECTION_LEVEL
                                                                         6.  FAILED_VALIDATION
                                                                         7.  PAYMENT_FAILED_VALIDATION
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_notification_body(document_id   IN VARCHAR2,
		          display_type  IN VARCHAR2,
		          document      IN OUT NOCOPY CLOB,
		          document_type IN OUT NOCOPY VARCHAR2) IS
  
    CURSOR c_body_msg1(cp_doc_instance_id IN NUMBER) IS
      SELECT cba.bank_account_name internal_bank_account_name,
	 cba.masked_account_num,
	 ipsr.call_app_pay_service_req_code,
	 ip.payment_currency_code,
	 COUNT(ip.payment_id) payment_count,
	 SUM(ip.payment_amount) payment_amount
      FROM   iby_payments_all         ip,
	 ce_bank_accounts         cba,
	 iby_pay_service_requests ipsr,
	 xxobjt_wf_docs           doc,
	 xxobjt_wf_doc_instance   inst
      WHERE  ip.internal_bank_account_id = cba.bank_account_id
      AND    ip.payment_service_request_id =
	 ipsr.payment_service_request_id
      AND    inst.n_attribute1 = ip.payment_service_request_id
      AND    doc.doc_id = inst.doc_id
      AND    doc.doc_code = g_doc_code
      AND    inst.doc_instance_id = cp_doc_instance_id
      AND    ip.payment_status NOT IN
	 ('REMOVED',
	   'REMOVED_DOCUMENT_SPOILED',
	   'REMOVED_INSTRUCTION_TERMINATED',
	   'VOID_BY_OVERFLOW_REPRINT',
	   'VOID_BY_SETUP_REPRINT',
	   'REJECTED',
	   'FAILED_BY_CALLING_APP',
	   'FAILED_BY_REJECTION_LEVEL',
	   'FAILED_VALIDATION',
	   'REMOVED_REQUEST_TERMINATED',
       'PAYMENT_FAILED_VALIDATION',--Added by Piyali for  CHG0040948 
	   'REMOVED_PAYMENT_STOPPED') -- Added Condition 03/18/2015 SAkula CHG0034886
      GROUP  BY cba.bank_account_name,
	    cba.masked_account_num,
	    ipsr.call_app_pay_service_req_code,
	    ip.payment_currency_code;
  
    CURSOR c_body_msg2(cp_doc_instance_id IN NUMBER) IS
      SELECT idp.payment_id,
	 nvl(ip.payee_party_name, hp.party_name) payee_name,
	 SUM(idp.payment_amount) amt,
	 ip.payment_currency_code -- Added 18-AUG-2015 SAkula CHG0035411
      FROM   iby_docs_payable_all   idp,
	 fnd_lookups            lut,
	 iby_payments_all       ip,
	 hz_parties             hp,
	 xxobjt_wf_docs         doc,
	 xxobjt_wf_doc_instance inst
      WHERE  idp.document_status NOT IN
	 ('REMOVED',
	  'REMOVED_PAYMENT_REMOVED',
	  'REMOVED_PAYMENT_STOPPED',
	  'REMOVED_PAYMENT_VOIDED',
	  'REMOVED_REQUEST_TERMINATED',
	  'REMOVED_INSTRUCTION_TERMINATED',
      'VOID_BY_OVERFLOW_REPRINT',  -- Added by Piyali for CHG0040948 
      'VOID_BY_SETUP_REPRINT',
      'REJECTED',
      'FAILED_BY_CALLING_APP',
      'FAILED_BY_REJECTION_LEVEL',
      'FAILED_VALIDATION',
      'PAYMENT_FAILED_VALIDATION')--Added by Piyali for  CHG0040948 
      AND    idp.document_type = lut.lookup_code
      AND    lut.lookup_type = 'IBY_DOCUMENT_TYPES'
      AND    idp.payment_id = ip.payment_id
      AND    ip.payee_party_id = hp.party_id(+)
      AND    idp.payment_service_request_id = inst.n_attribute1
      AND    doc.doc_id = inst.doc_id
      AND    doc.doc_code = g_doc_code
      AND    inst.doc_instance_id = cp_doc_instance_id
      GROUP  BY idp.payment_id,
	    ip.payee_party_name,
	    hp.party_name,
	    ip.payment_currency_code -- Added 18-AUG-2015 SAkula CHG0035411
      ORDER  BY nvl(ip.payee_party_name, hp.party_name) ASC,
	    SUM(idp.payment_amount) ASC;
  
    l_doc_instance_id     NUMBER;
    l_np1                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5                 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
    l_history_clob        CLOB;
    l_cnt                 NUMBER; -- Added variable 25-AUG-2015 SAkula CHG0035411
    l_bank_account_name   ce_bank_accounts.bank_account_name%TYPE; -- Added variable 25-AUG-2015 SAkula CHG0035411
    l_masked_account_num  ce_bank_accounts.masked_account_num%TYPE; -- Added variable 25-AUG-2015 SAkula CHG0035411
    l_numeric_format_mask fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXOBJT_NUMERIC_FORMAT_MASK'); -- Added variable 26-AUG-2015 SAkula CHG0035411
    l_body_msg            VARCHAR2(32767); -- Added variable 26-AUG-2015 SAkula CHG0035411
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'get_notification_body',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || ' document_id :' ||
		        document_id || ' display_type :' ||
		        display_type || ' l_numeric_format_mask :' ||
		        l_numeric_format_mask);
  
    l_doc_instance_id := to_number(document_id);
  
    document_type := 'text/html';
    document      := ' ';
    dbms_lob.append(document,
	        '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Payment workflow</strong> </font> </p>');
    dbms_lob.append(document,
	        '<font face="arial" style="color:black;" size="2">');
  
    /* FOR c_1 IN c_body_msg1(l_doc_instance_id) LOOP
      dbms_lob.append(document,
            'Payment Batch ' || c_1.call_app_pay_service_req_code ||
            ' with ' || c_1.payment_count ||
            ' Payments totaling ' || c_1.payment_currency_code || ' ' ||
            c_1.payment_amount || ' from Account ' ||
            c_1.masked_account_num || ' ' ||
            c_1.internal_bank_account_name ||
            ' requires your approval'||chr(10));
    END LOOP;*/
  
    -- Added Code to derive notification body 25-AUG-2015 SAkula CHG0035411 START
    l_cnt      := '0';
    l_body_msg := '';
    FOR c_1 IN c_body_msg1(l_doc_instance_id) LOOP
    
      l_cnt                := l_cnt + 1;
      l_bank_account_name  := c_1.internal_bank_account_name;
      l_masked_account_num := c_1.masked_account_num;
    
      IF l_cnt = '1' THEN
        l_body_msg := 'Payment Batch ' || c_1.call_app_pay_service_req_code ||
	          ' with ' || c_1.payment_count ||
	          ' Payments totaling ' || c_1.payment_currency_code || ' ' ||
	          to_char(c_1.payment_amount, l_numeric_format_mask) ||
	          ' and ';
      ELSE
      
        l_body_msg := l_body_msg || c_1.payment_count ||
	          ' Payments totaling ' || c_1.payment_currency_code || ' ' ||
	          to_char(c_1.payment_amount, l_numeric_format_mask) ||
	          ' and ';
      
      END IF;
    
    END LOOP;
  
    dbms_lob.append(document, rtrim(l_body_msg, ' and '));
    dbms_lob.append(document,
	        '  from Account ' || l_masked_account_num || ' ' ||
	        l_bank_account_name || ' requires your approval' ||
	        chr(10));
  
    -- Added Code to derive notification body 25-AUG-2015 SAkula CHG0035411 END
  
    dbms_lob.append(document, '</font> </p>');
    dbms_lob.append(document,
	        '<p> <font face="arial" style="color:#336699" size="3"> <strong>Payment Details:</strong> </font> </p>');
    dbms_lob.append(document, '<div align="left">');
    dbms_lob.append(document,
	        '<table BORDER=1 cellpadding=2 cellspacing=1>');
    dbms_lob.append(document, '<thead>');
    dbms_lob.append(document, '<tr>');
    dbms_lob.append(document,
	        '<th WIDTH=50% style="background-color:#CFE0F1;" align="left"><font color=#336699 >Payee</font></th>');
    dbms_lob.append(document,
	        '<th WIDTH=30% style="background-color:#CFE0F1;" align="left"><font color=#336699 >Amount</font></th>');
    dbms_lob.append(document,
	        '<th WIDTH=20% style="background-color:#CFE0F1;" align="left"><font color=#336699 >Payment Currency</font></th>'); -- Added 18-AUG-2015 SAkula CHG0035411
    dbms_lob.append(document, '</thead></tr><tbody>');
  
    FOR c_2 IN c_body_msg2(l_doc_instance_id) LOOP
    
      dbms_lob.append(document, '<tr>');
    
      dbms_lob.append(document, '<td>' || c_2.payee_name || '</td>');
      dbms_lob.append(document,
	          '<td>' || to_char(c_2.amt, l_numeric_format_mask) ||
	          '</td>'); -- Added TO_CHAR to format Numeric values 26-AUG-2015 SAkula CHG0035411
      dbms_lob.append(document,
	          '<td>' || c_2.payment_currency_code || '</td>'); -- Added 18-AUG-2015 SAkula CHG0035411
    
      dbms_lob.append(document, '</tr>');
    END LOOP;
  
    dbms_lob.append(document, '</tbody>');
    dbms_lob.append(document, '</table>');
  
    dbms_lob.append(document,
	        '<BR><BR>Document Instance Id: ' || document_id);
  
    -- add history
    l_history_clob := NULL;
    dbms_lob.append(document,
	        '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
			display_type  => '',
			document      => l_history_clob,
			document_type => document_type);
  
    dbms_lob.append(document, l_history_clob);
  
    --- CHG0035411 Michal Tzvik 17.09.2015
    --dbms_lob.append(document, '<br></br><A HREF="' ||get_reference_link(p_doc_instance_id => l_doc_instance_id) ||'"> View Additional Details </A>');
    /*    dbms_lob.append(document, '<br></br><A HREF="' ||
                         fnd_run_function.get_run_function_url(p_function_id => 29993, -- IBY_FD_REQUEST_DETAIL
                                                               p_resp_appl_id => 200, --NULL, --
                                                               p_resp_id => 50637, --NULL,--
                                                               p_security_group_id => NULL, --
                                                               p_parameters => 'checkrunId=31324-&org_id=737&retainAM=Y-&OAMC=K-&addBreadCrumb=Y-&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG-&PaymentServiceRequestId=150352-&forceQuery=Y') ||
                         '"> View Additional Details </A>');
    */
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'get_notification_body',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
  END get_notification_body;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_notification_subject
  Author's Name:   Sandeep Akula
  Date Written:    27-JAN-2015
  Purpose:         This Procedure builds the subject message of the Approval Notification
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  27-JAN-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  18-MAR-2015        1.1                  Sandeep Akula     Added a new condition to cursor c_body_msg1 -- CHG0034886
  20-AUG-2015        1.2                  Sandeep Akula     Commented few columns in cursor c_body_msg1 -- CHG0035411
                                                            Commented verbiage in variable p_subject -- CHG0035411 
  31-OCT-2017        1.3                  Piyali Bhowmick   CHG0040948 - Adding the following status in payment status of   CURSOR c_body_msg1
                                                            1.PAYMENT_FAILED_VALIDATION
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_notification_subject(p_doc_instance_id IN NUMBER,
			 p_subject         OUT VARCHAR2,
			 p_err_code        OUT NUMBER,
			 p_err_message     OUT VARCHAR2) IS
  
    CURSOR c_body_msg1(cp_doc_instance_id IN NUMBER) IS
      SELECT cba.bank_account_name internal_bank_account_name,
	 cba.masked_account_num,
	 ipsr.call_app_pay_service_req_code,
	 hou.name,
	 --ip.payment_currency_code, -- Commented 20-AUG-2015 SAkula CHG0035411
	 COUNT(ip.payment_id) payment_count
      --SUM(ip.payment_amount) payment_amount -- Commented 20-AUG-2015 SAkula CHG0035411
      FROM   iby_payments_all         ip,
	 ce_bank_accounts         cba,
	 iby_pay_service_requests ipsr,
	 xxobjt_wf_docs           doc,
	 xxobjt_wf_doc_instance   inst,
	 hr_operating_units       hou
      WHERE  ip.internal_bank_account_id = cba.bank_account_id
      AND    ip.payment_service_request_id =
	 ipsr.payment_service_request_id
      AND    inst.n_attribute1 = ip.payment_service_request_id
      AND    doc.doc_id = inst.doc_id
      AND    doc.doc_code = 'IBY_PAY'
      AND    ip.org_id = hou.organization_id
      AND    inst.doc_instance_id = cp_doc_instance_id
      AND    ip.payment_status NOT IN
	 ('REMOVED',
	   'REMOVED_DOCUMENT_SPOILED',
	   'REMOVED_INSTRUCTION_TERMINATED',
	   'VOID_BY_OVERFLOW_REPRINT',
	   'VOID_BY_SETUP_REPRINT',
	   'REJECTED',
	   'FAILED_BY_CALLING_APP',
	   'FAILED_BY_REJECTION_LEVEL',
	   'FAILED_VALIDATION',
	   'REMOVED_REQUEST_TERMINATED',
       'PAYMENT_FAILED_VALIDATION',--Added by Piyali for  CHG0040948 
	   'REMOVED_PAYMENT_STOPPED') -- Added Condition 03/18/2015 SAkula CHG0034886
      GROUP  BY cba.bank_account_name,
	    cba.masked_account_num,
	    ipsr.call_app_pay_service_req_code,
	    hou.name;
    --ip.payment_currency_code; -- Commented 20-AUG-2015 SAkula CHG0035411
  
    l_np1 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_INSTALLED');
    l_np2 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_SUPER_USER');
    l_np3 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_APPROVAL_REPORT_TEMPLATE');
    l_np4 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_2ND_SIGNER_REQUIRED');
    l_np5 fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXIBY_SSYS_PAYMENT_APPROVAL_3RD_SIGNER_REQUIRED');
  
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'get_notification_subject',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id);
  
    FOR c_1 IN c_body_msg1(p_doc_instance_id) LOOP
      p_subject := 'Payment Batch ' || c_1.call_app_pay_service_req_code ||
	       ' for ' || c_1.name || ' from Bank Account ' ||
	       c_1.masked_account_num; -- ||
    --' totaling ' ||c_1.payment_currency_code || ' ' || c_1.payment_amount; -- Commented 20-AUG-2015 SAkula CHG0035411
    END LOOP;
  
    p_err_code    := '0';
    p_err_message := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_notification_subject',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      p_err_code    := '1';
      p_err_message := SQLERRM;
      p_subject     := 'Error Occured in Payment Workflow Subject';
  END get_notification_subject;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    generate_reference_link
  Author's Name:   Michal Tzvik
  Date Written:    01-FEB-2015
  Purpose:         This Procedure builds the reference link ("View Additional Details") of the Approval Notification
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  01-FEB-2015        1.0                  Michal Tzvik     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE generate_reference_link(p_doc_instance_id IN NUMBER,
			p_err_code        OUT NUMBER,
			p_err_message     OUT VARCHAR2) IS
  
    l_doc_instance_rec xxobjt_wf_doc_instance%ROWTYPE;
    l_itemtype         VARCHAR2(30) := 'XXWFDOC';
    l_reference_link   VARCHAR2(300);
    l_checkrunid       NUMBER;
  BEGIN
    p_err_code    := 0;
    p_err_message := '';
  
    SELECT *
    INTO   l_doc_instance_rec
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
    SELECT aisc.checkrun_id
    INTO   l_checkrunid
    FROM   ap_inv_selection_criteria_all aisc,
           iby_pay_service_requests      ipsr
    WHERE  aisc.checkrun_name = ipsr.call_app_pay_service_req_code
    AND    ipsr.payment_service_request_id =
           l_doc_instance_rec.n_attribute1;
  
    l_reference_link := 'JSP:/OA_HTML/OA.jsp?OAFunc=IBY_FD_REQUEST_DETAIL&checkrunId=' ||
		to_char(l_checkrunid) || '&org_id=' ||
		l_doc_instance_rec.org_id ||
		'&retainAM=Y&OAMC=K&addBreadCrumb=Y&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG&PaymentServiceRequestId=' ||
		to_char(l_doc_instance_rec.n_attribute1) ||
		'&forceQuery=Y';
  
    --   l_reference_link := 'JSP:/OA_HTML/OA.jsp?OAFunc=IBY_FD_REQUEST_DETAIL&checkrunId=30307-&retainAM=Y-&OAMC=K-&addBreadCrumb=Y-&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG-&PaymentServiceRequestId=138293-&forceQuery=Y';
  
    wf_engine.setitemattrtext(itemtype => l_itemtype,
		      itemkey  => l_doc_instance_rec.wf_item_key,
		      aname    => 'REFERENCE_LINK',
		      avalue   => l_reference_link);
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error in generate_reference_link: ' || SQLERRM;
  END generate_reference_link;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    generate_reference_link
  Author's Name:   Michal Tzvik
  Date Written:    01-FEB-2015
  Purpose:         This Function builds the reference link ("View Additional Details") of the Approval Notification
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  01-FEB-2015        1.0                  Michal Tzvik     Initial Version -- CHG0033620
  17-SEP-2015        1.1                  Michal Tzvik     CHG0035411 - 1.generate url by using fnd_run_function.get_run_function_url
                                                           2. Change from procedure to function. Call this function from get_notification_body instead of populating WF attribute.
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_reference_link(p_doc_instance_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_doc_instance_rec xxobjt_wf_doc_instance%ROWTYPE;
    l_itemtype         VARCHAR2(30) := 'XXWFDOC';
    l_reference_link   VARCHAR2(3000);
    l_checkrunid       NUMBER;
  
    p_err_code    NUMBER;
    p_err_message VARCHAR2(1000);
  BEGIN
    p_err_code    := 0;
    p_err_message := '';
  
    SELECT *
    INTO   l_doc_instance_rec
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
    SELECT aisc.checkrun_id
    INTO   l_checkrunid
    FROM   ap_inv_selection_criteria_all aisc,
           iby_pay_service_requests      ipsr
    WHERE  aisc.checkrun_name = ipsr.call_app_pay_service_req_code
    AND    ipsr.payment_service_request_id =
           l_doc_instance_rec.n_attribute1;
  
    --CHG0035411 Michal Tzvik 17.09.2015
    /*l_reference_link := 'JSP:/OA_HTML/OA.jsp?OAFunc=IBY_FD_REQUEST_DETAIL&checkrunId=' ||
                        to_char(l_checkrunid) || '&org_id=' ||
                        l_doc_instance_rec.org_id ||
                        '&retainAM=Y&OAMC=K&addBreadCrumb=Y&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG&PaymentServiceRequestId=' ||
                        to_char(l_doc_instance_rec.n_attribute1) ||
                        '&forceQuery=Y';
    
    -- l_reference_link := 'JSP:/OA_HTML/OA.jsp?OAFunc=IBY_FD_REQUEST_DETAIL&checkrunId=30307-&retainAM=Y-&OAMC=K-&addBreadCrumb=Y-&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG-&PaymentServiceRequestId=138293-&forceQuery=Y';
    
     wf_engine.setitemattrtext(itemtype => l_itemtype, itemkey => l_doc_instance_rec.wf_item_key, aname => 'REFERENCE_LINK', avalue => l_reference_link);
    */
  
    l_reference_link := fnd_run_function.get_run_function_url(p_function_id       => 29993, -- IBY_FD_REQUEST_DETAIL
					  p_resp_appl_id      => NULL, --l_doc_instance_rec.resp_appl_id, --
					  p_resp_id           => NULL, -- if this parameter is null and function exists in several responsibilities of the user, then the url will open a page of relevant responsibilities links
					  p_security_group_id => 0, --NULL, --
					  p_override_agent    => NULL, --
					  p_org_id            => NULL, --
					  p_lang_code         => NULL, --
					  p_encryptparameters => FALSE, --
					  p_parameters        => 'checkrunId=' ||
							 to_char(l_checkrunid) ||
							--'-&org_id=' ||
							--l_doc_instance_rec.org_id ||
							 '&retainAM=Y-&OAMC=K-&addBreadCrumb=Y-&IbyReturnLinkURL=OA.jsp?page=/oracle/apps/ap/payments/psr/webui/PsrSearchPG-&PaymentServiceRequestId=' ||
							 to_char(l_doc_instance_rec.n_attribute1) ||
							 '-&forceQuery=Y');
    -- remove this code!!! for tests only!!!
    wf_engine.setitemattrtext(itemtype => l_itemtype,
		      itemkey  => l_doc_instance_rec.wf_item_key,
		      aname    => 'REFERENCE_LINK',
		      avalue   => l_reference_link);
    -- remove: end
  
    RETURN l_reference_link;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error in generate_reference_link: ' || SQLERRM;
      -- CHG0035411 Michal Tzvik 17.09.2015
      fnd_log.string(log_level => fnd_log.level_event, --
	         module    => c_debug_module ||
		          'generate_reference_link', --
	         message   => p_err_message);
      RETURN NULL;
  END get_reference_link;
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    abort_workflow
  Author's Name:   Sandeep Akula
  Date Written:    13-FEB-2015
  Purpose:         This Procedure aborts the XXWFDOC workflow for a Workflow Instance ID (Used in Terminate Button of PPR Form)
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE abort_workflow(p_err_code                   OUT NUMBER,
		   p_err_message                OUT VARCHAR2,
		   p_payment_service_request_id IN NUMBER DEFAULT NULL,
		   p_checkrun_id                IN NUMBER DEFAULT NULL) IS
  
    l_doc_instance_id NUMBER;
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(32767);
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'abort_workflow',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_doc_instance_id := '';
  
    BEGIN
      p_err_code    := 0;
      p_err_message := '';
    
      IF p_payment_service_request_id IS NOT NULL THEN
      
        SELECT b.doc_instance_id
        INTO   l_doc_instance_id
        FROM   xxobjt_wf_docs         a,
	   xxobjt_wf_doc_instance b
        WHERE  a.doc_id = b.doc_id
        AND    a.doc_code = g_doc_code
        AND    b.n_attribute1 = p_payment_service_request_id;
      
      ELSE
      
        SELECT b.doc_instance_id
        INTO   l_doc_instance_id
        FROM   xxobjt_wf_docs                a,
	   xxobjt_wf_doc_instance        b,
	   iby_pay_service_requests      c,
	   ap_inv_selection_criteria_all d
        WHERE  a.doc_id = b.doc_id
        AND    a.doc_code = g_doc_code
        AND    b.n_attribute1 = c.payment_service_request_id
        AND    c.call_app_pay_service_req_code = d.checkrun_name
        AND    d.checkrun_id = p_checkrun_id;
      
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code := '0';
        RETURN;
    END;
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'abort_workflow',
	       message   => 'l_doc_instance_id :' || l_doc_instance_id);
  
    l_err_code    := '';
    l_err_message := '';
    xxobjt_wf_doc_util.abort_process(p_err_code        => l_err_code,
			 p_err_msg         => l_err_message,
			 p_doc_instance_id => l_doc_instance_id);
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'abort_workflow',
	       message   => 'l_err_code :' || l_err_code ||
		        'l_err_message :' || l_err_message);
  
    p_err_code    := l_err_code;
    p_err_message := l_err_message;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := '1';
      p_err_message := 'Payment abort_workflow OTHERS Exception :' ||
	           SQLERRM;
  END abort_workflow;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    BEFORE_APPROVAL_VALIDATIONS
  Author's Name:   Sandeep Akula
  Date Written:    19-FEB-2015
  Purpose:         This Procedure performs Validations on the Payment setup and data. If anything is missing then it will return error code and a error messaage otherwise the message will be Blank.
                   This procedure will be called when user clicks on the Approve button. If Error Code is 0 then the custom OAF Page will Open.
                   If error code is 1 then custom page will not open and an error message is displayed.
  
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  19-FEB-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033620
  18-AUG-2015        1.1                  Sandeep Akula     CHG0035411 -  1. Added logic to check if Approval currency is setup for Bank Account
                                                                          2. Added Custom Exception highest_payment_rec_excp
                                                                          3. Added Additional validations to check currency conversion rate and Highest Payment Record
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE before_approval_validations(p_err_code                   OUT NUMBER,
			    p_err_message                OUT VARCHAR2,
			    p_payment_service_request_id IN NUMBER) IS
  
    l_pmt_rec      highest_payment_amt_rec;
    l_cnt          NUMBER;
    l_currency_cnt NUMBER; -- Added Variable 18-AUG-2015 SAkula CHG0035411
    l_account_name ce_bank_accounts.bank_account_name%TYPE;
    highest_payment_rec_excp EXCEPTION; -- Added Exception 18-AUG-2015 SAkula CHG0035411
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_pmt_rec := get_highest_payment_rec(p_payment_service_request_id);
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'Payment ID:' || l_pmt_rec.payment_id ||
		        ' p_payment_service_request_id:' ||
		        p_payment_service_request_id);
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'Before l_cnt');
  
    l_cnt := '';
    BEGIN
      SELECT COUNT(cbs.signatory_id)
      INTO   l_cnt
      FROM   iby_payments_all  ip,
	 ce_ba_signatories cbs
      WHERE  ip.internal_bank_account_id = cbs.bank_account_id
      AND    ip.payment_id = l_pmt_rec.payment_id
      AND    cbs.deleted_flag = 'N'
      AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	 trunc(nvl(cbs.end_date, SYSDATE));
    EXCEPTION
      WHEN OTHERS THEN
        l_cnt := '0';
    END;
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'l_cnt:' || l_cnt);
  
    l_account_name := '';
    SELECT cba.bank_account_name
    INTO   l_account_name
    FROM   iby_payments_all ip,
           ce_bank_accounts cba
    WHERE  ip.payment_id = l_pmt_rec.payment_id
    AND    ip.internal_bank_account_id = cba.bank_account_id;
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'l_account_name:' || l_account_name);
  
    -- Added logic to check if Approval currency is setup for Bank Account 18-AUG-2015 SAkula CHG0035411  START
    BEGIN
      l_currency_cnt := '';
      SELECT COUNT(*)
      INTO   l_currency_cnt
      FROM   (SELECT DISTINCT cbs.attribute2 -- Approval Currency
	  FROM   iby_payments_all  ip,
	         ce_ba_signatories cbs
	  WHERE  ip.internal_bank_account_id = cbs.bank_account_id
	  AND    ip.payment_id = l_pmt_rec.payment_id
	  AND    cbs.deleted_flag = 'N'
	  AND    trunc(SYSDATE) BETWEEN trunc(cbs.start_date) AND
	         trunc(nvl(cbs.end_date, SYSDATE)));
    EXCEPTION
      WHEN OTHERS THEN
        l_currency_cnt := '0';
    END;
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'l_currency_cnt:' || l_currency_cnt);
  
    -- Added logic to check if Approval currency ic setup for Bank Account 18-AUG-2015 SAkula CHG0035411  END
  
    -- Added Additional Validations 18-AUG-2015 SAkula CHG0035411  START
    IF l_cnt > '0' THEN
    
      IF l_currency_cnt = 1 THEN
      
        IF get_approval_curr_conv_rate(l_pmt_rec.payment_id,
			   l_pmt_rec.payment_currency) IS NULL THEN
          p_err_code    := '1';
          p_err_message := 'Could not derive conversion Rate for Highest Payment. Payment ID:' ||
		   l_pmt_rec.payment_id || ', Payment Currency :' ||
		   l_pmt_rec.payment_currency ||
		   ', Approval Currency :' ||
		   l_pmt_rec.converted_payment_currency;
        ELSE
        
          -- Validating Highest Payment Record 18-AUG-2015 SAkula CHG0035411 START
          IF l_pmt_rec.payment_amount IS NULL OR
	 l_pmt_rec.converted_payment_amount IS NULL OR
	 l_pmt_rec.payment_id IS NULL OR
	 l_pmt_rec.payment_currency IS NULL OR
	 l_pmt_rec.converted_payment_currency IS NULL THEN
	RAISE highest_payment_rec_excp;
          END IF;
          -- Validating Highest Payment Record 18-AUG-2015 SAkula CHG0035411 END
        
          p_err_code    := '0';
          p_err_message := NULL;
        
        END IF;
      
      ELSE
        p_err_code    := '1';
        p_err_message := 'Either Approval Currency is not Setup for Bank Account : ' ||
		 l_account_name || ' OR Bank Account :' ||
		 l_account_name ||
		 ' is setup with Multiple Approval Currencies. Please check Bank Account Signing Authority Limits Setup ';
      END IF;
    
    ELSE
      p_err_code    := '1';
      p_err_message := 'Bank Account Signing Authority Limits are not setup for Bank Account : ' ||
	           l_account_name;
    END IF;
  
    -- Added Additional Validations 18-AUG-2015 SAkula CHG0035411  END
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'before_approval_validations',
	       message   => 'End of Procedure');
  
  EXCEPTION
    -- Added Exception 18-AUG-2015 SAkula CHG0035411
    WHEN highest_payment_rec_excp THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'before_approval_validations',
	         message   => 'BEFORE_APPROVAL_VALIDATIONS Proc *highest_payment_rec_excp* Exception' ||
		          ' Payment Amount :' ||
		          l_pmt_rec.payment_amount ||
		          ' Converted Payment Amount: ' ||
		          l_pmt_rec.converted_payment_amount ||
		          ' Payment ID :' || l_pmt_rec.payment_id ||
		          ' Payment Currency :' ||
		          l_pmt_rec.payment_currency ||
		          ' Converted Payment Currency :' ||
		          l_pmt_rec.converted_payment_currency);
      p_err_code    := '1';
      p_err_message := 'One/All of the Records elements in Highest Payment Rec are NULL. Cannot proceed further. Check Log messages for further details';
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'before_approval_validations',
	         message   => 'BEFORE_APPROVAL_VALIDATIONS Proc OTHERS Exception. SQL Error is :' ||
		          SQLERRM);
      p_err_code    := '1';
      p_err_message := SQLERRM;
  END before_approval_validations;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_currency_conversion_detail
  Author's Name:   Sandeep Akula
  Date Written:    17-AUG-2015
  Purpose:         This Function returns a string which contains the currency conversion rate details to the OAF Page.
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-AUG-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035411
  -------------------------------------------------------------------------------------------------- */
  FUNCTION get_currency_conversion_detail(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_payment_info        highest_payment_amt_rec;
    l_rate_info           currency_conversion_rec;
    l_numeric_format_mask fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXOBJT_NUMERIC_FORMAT_MASK');
  BEGIN
  
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_currency_conversion_detail',
	       message   => ' p_payment_service_request_id :' ||
		        p_payment_service_request_id);
  
    l_payment_info := get_highest_payment_rec(p_payment_service_request_id);
    l_rate_info    := get_currency_conv_info(l_payment_info.payment_id,
			         l_payment_info.payment_currency);
  
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_currency_conversion_detail',
	       message   => ' Payment Amount :' ||
		        l_payment_info.payment_amount ||
		        ' Payment Currency :' ||
		        l_payment_info.payment_currency ||
		        ' Converted Payment Amount :' ||
		        l_payment_info.converted_payment_amount ||
		        ' Converted Payment Currency :' ||
		        l_payment_info.converted_payment_currency ||
		        ' Conversion Date :' ||
		        l_rate_info.conversion_date ||
		        ' Conversion Rate :' ||
		        l_rate_info.conversion_rate);
  
    IF l_rate_info.conversion_date IS NOT NULL AND
       l_payment_info.converted_payment_amount IS NOT NULL THEN
    
      RETURN(TRIM(to_char(l_payment_info.payment_amount,
		  l_numeric_format_mask)) || ' ' ||
	 l_payment_info.payment_currency || ';' ||
	 TRIM(to_char(l_payment_info.converted_payment_amount,
		  l_numeric_format_mask)) || ' ' ||
	 l_payment_info.converted_payment_currency || ';' ||
	 'Converted Using ' || l_rate_info.conversion_date || ' ' ||
	 'rate of ' || round(l_rate_info.conversion_rate, 2));
    
    ELSE
    
      RETURN(NULL);
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_currency_conversion_detail',
	         message   => 'OTHERS Exception. SQL Error is :' ||
		          SQLERRM);
      RETURN(NULL);
  END get_currency_conversion_detail;
END xxiby_pay_aprroval_util;
/