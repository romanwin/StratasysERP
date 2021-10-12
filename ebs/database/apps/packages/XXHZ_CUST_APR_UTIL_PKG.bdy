CREATE OR REPLACE PACKAGE BODY xxhz_cust_apr_util_pkg IS
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_APR_UTIL_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.1
  --  creation date:   07.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0031856- SOD-Customer Update Workflow
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07.2014     Michal Tzvik      initial build
  --  1.1  05/02/2015  Dalit A. Raviv    CHG0034518 change code in get_region
  --  1.2  15/06/2015  Michal Tzvik      CHG0034590:
  --                                     1. use "tag" instead of "meaning" field in lookup in Procedures:
  --                                      get_credit_limit_fyi,get_credit_limit_approver,get_payment_term_approver,get_credit_ch_hold_approver
  --                                     2. New function: get_credit_insurance_amount
  --                                     3. Modify procedure is_approval_required
  -- 1.3   28.8.17     Yuval tal         INC0100687 modify generate_need_approval_msg_wf                                                
  --------------------------------------------------------------------

  c_corporate         CONSTANT VARCHAR2(15) := 'CORPORATE';
  c_cust_credit_chk   CONSTANT VARCHAR2(50) := 'CUST_CREDIT_CHK';
  c_cust_credit_hold  CONSTANT VARCHAR2(50) := 'CUST_CREDIT_HOLD';
  c_cust_credit_limit CONSTANT VARCHAR2(50) := 'CUST_CREDIT_LIMIT';
  c_cust_pay_term     CONSTANT VARCHAR2(50) := 'CUST_PAY_TERM';

  c_debug_module CONSTANT VARCHAR2(100) := 'xxar.customer_approval.xxhz_cust_apr_util_pkg.';
  g_debug_ind VARCHAR2(15);

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_dsp_value
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      23/07/2014
  --  Purpose :           Use to display values of new_value and old_value
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_dsp_value(p_entity_code VARCHAR2,
		 p_value       VARCHAR2) RETURN VARCHAR2 IS
    l_dsp_value VARCHAR2(150);
  BEGIN
  
    IF p_entity_code = c_cust_pay_term THEN
      SELECT rt.name
      INTO   l_dsp_value
      FROM   ra_terms rt
      WHERE  rt.term_id = p_value;
    ELSE
      l_dsp_value := p_value;
    END IF;
  
    RETURN l_dsp_value;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_value;
  END get_dsp_value;
  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               generate_need_approval_msg_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      07/07/2014
  --  Purpose :           Build message body for "Need Aproval" notification
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/07/2014    Michal Tzvik    initial build
  --  1.1   28.8.17       Yuval tal       INC0100687 add status='A' to query
  -----------------------------------------------------------------------
  PROCEDURE generate_need_approval_msg_wf(document_id   IN VARCHAR2,
			      display_type  IN VARCHAR2,
			      document      IN OUT NOCOPY CLOB,
			      document_type IN OUT NOCOPY VARCHAR2) IS
    l_history_clob CLOB;
  
    l_requestor      VARCHAR2(150);
    l_account_number hz_cust_accounts.account_number%TYPE;
    l_account_name   hz_cust_accounts.account_name%TYPE;
    l_field_code     xxobjt_wf_docs.doc_code%TYPE;
    l_field_name     xxobjt_wf_docs.doc_name%TYPE;
    l_old_value      xxobjt_wf_doc_instance.attribute4%TYPE;
    l_new_value      xxobjt_wf_doc_instance.attribute5%TYPE;
    l_attribute1     xxobjt_wf_doc_instance.attribute1%TYPE;
    l_org            hr_operating_units.name%TYPE;
    l_level          VARCHAR2(50);
    l_itemkey        VARCHAR2(25);
    l_country        fnd_territories_vl.territory_short_name%TYPE;
    l_wf_error       VARCHAR2(2500);
  
    -- Find other pending changes for the same data
    l_pend_changes CLOB;
    CURSOR c_pend(p_document_id NUMBER) IS
      SELECT xwdi.doc_instance_id,
	 hr_general.decode_person_name(xwdi.requestor_person_id) requestor,
	 xwdi.creation_date,
	 xwd.doc_name,
	 xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				  xwdi.attribute4) old_value,
	 xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				  xwdi.attribute5) new_value
      FROM   xxobjt_wf_doc_instance xwdi,
	 xxobjt_wf_docs         xwd
      WHERE  xwdi.doc_instance_id != p_document_id
      AND    xwdi.doc_status IN ('IN_PROCESS', 'ERROR')
      AND    xwdi.end_date IS NULL
      AND    xwd.doc_id = xwdi.doc_id
      AND    EXISTS (SELECT 1
	  FROM   xxobjt_wf_doc_instance xwdi_1
	  WHERE  xwdi_1.doc_instance_id = p_document_id
	  AND    xwdi_1.doc_id = xwdi.doc_id
	  AND    xwdi_1.n_attribute1 = xwdi.n_attribute1 -- cust_account_id
	  AND    nvl(xwdi_1.n_attribute2, -1) = -- party_site_id
	         nvl(xwdi.n_attribute2, -1)
	  AND    nvl(xwdi_1.attribute1, '-1') = -- currency
	         nvl(xwdi.attribute1, '-1')
	  AND    nvl(xwdi_1.n_attribute3, -1) = -- site_use_id
	         nvl(xwdi.n_attribute3, -1))
      ORDER  BY xwdi.doc_instance_id DESC;
  BEGIN
    document_type := 'text/html';
  
    SELECT hr_general.decode_person_name(xwdi.requestor_person_id) requestor,
           hca.account_number,
           hp.party_name,
           xwd.doc_code,
           xwd.doc_name field_name,
           (SELECT hou.name
	FROM   hr_operating_units hou
	WHERE  hou.organization_id = nvl(hcas.org_id, hcsu.org_id)) org,
           decode(xwdi.n_attribute3,
	      NULL,
	      decode(xwdi.n_attribute2, NULL, 'Customer', 'Site'),
	      (SELECT MAX(flv.meaning)
	       FROM   fnd_lookup_values_vl flv
	       WHERE  flv.lookup_type = 'SITE_USE_CODE'
	       AND    flv.enabled_flag = 'Y'
	       AND    SYSDATE BETWEEN
		  nvl(flv.start_date_active, SYSDATE - 1) AND
		  nvl(flv.end_date_active, SYSDATE + 1)
	       AND    flv.lookup_code = hcsu.site_use_code)) change_level,
           xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				xwdi.attribute4) old_value,
           xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				xwdi.attribute5) new_value,
           xwdi.attribute1,
           xwdi.wf_item_key,
           (SELECT ft.territory_short_name
	FROM   hz_locations       hl,
	       hz_party_sites     hps,
	       fnd_territories_vl ft
	WHERE  hl.location_id = hps.location_id
	AND    ft.territory_code = hl.country
	AND    hps.party_site_id =
	       nvl(hcas.party_site_id, hps.party_site_id)
	AND    hps.party_id = hca.party_id
	AND    hps.status = 'A'
	AND    rownum = 1) country
    INTO   l_requestor,
           l_account_number,
           l_account_name,
           l_field_code,
           l_field_name,
           l_org,
           l_level,
           l_old_value,
           l_new_value,
           l_attribute1,
           l_itemkey,
           l_country
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd,
           hz_cust_accounts       hca,
           hz_cust_acct_sites_all hcas,
           hz_cust_site_uses_all  hcsu,
           hz_parties             hp
    WHERE  1 = 1
    AND    xwdi.doc_instance_id = document_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    hcsu.status(+) = 'A' --INC0100687
    AND    hcas.status(+) = 'A' -- INC0100687
    AND    hca.cust_account_id(+) = xwdi.n_attribute1
    AND    hcas.party_site_id(+) = xwdi.n_attribute2
    AND    hcas.org_id(+) = xwdi.attribute6
    AND    hcsu.site_use_id(+) = xwdi.n_attribute3
    AND    hp.party_id(+) = hca.party_id;
    document := ' ';
    dbms_lob.append(document,
	        '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Change Request Details</strong> </font> </p>');
  
    ------- Body
    l_wf_error := wf_engine.getitemattrtext(itemtype => 'XXWFDOC',
			        itemkey  => l_itemkey,
			        aname    => 'ERR_MESSAGE');
    IF l_wf_error IS NOT NULL THEN
      dbms_lob.append(document,
	          '<b><font style="color:red" size="2">' || l_wf_error ||
	          '</font></b><br><br>');
    END IF;
  
    dbms_lob.append(document,
	        'The following change was done by <b>' || l_requestor ||
	        '</b> to customer <b>' || l_account_name || ' (' ||
	        l_account_number || ')</b>: <br><br>');
  
    dbms_lob.append(document, 'Field name: ' || l_field_name || '<br>');
    IF l_level != 'Customer' THEN
      dbms_lob.append(document, 'Organization:      ' || l_org || '<br>');
    END IF;
    dbms_lob.append(document, 'Level:      ' || l_level || '<br>');
    dbms_lob.append(document, 'Country:    ' || l_country || '<br>');
  
    IF l_field_code = c_cust_credit_limit THEN
      dbms_lob.append(document,
	          'Currency:      ' || l_attribute1 || '<br>');
    END IF;
    dbms_lob.append(document, 'Old value:  ' || l_old_value || '<br>');
    dbms_lob.append(document, 'New value:  ' || l_new_value || '<br>');
  
    -- Pending Changes
    l_pend_changes := ' ';
  
    FOR r_change IN c_pend(document_id) LOOP
      dbms_lob.append(l_pend_changes,
	          '<tr>  <td> ' || r_change.doc_instance_id ||
	          ' </td><td> ' || r_change.requestor || ' </td>' ||
	          ' <td> ' || r_change.creation_date || ' </td>' ||
	          ' <td> ' || r_change.doc_name || ' </td>' || ' <td> ' ||
	          nvl(r_change.old_value, chr(38) || 'nbsp') ||
	          ' </td>' || ' <td> ' || r_change.new_value ||
	          ' </td> </tr>');
    END LOOP;
  
    IF length(l_pend_changes) > 1 THEN
      dbms_lob.append(document,
	          '<BR><BR> There exist pending changes for the same data: <BR>' ||
	          '<div align="left"><TABLE BORDER=1 cellPadding=2>' ||
	          '<tr> <th>  Doc Id  </th> <th> Requestor </th>' ||
	          ' <th>  Date       </th>' ||
	          ' <th>  Field Name </th>' ||
	          ' <th>  Old Value  </th>' ||
	          ' <th>  New Value  </th> </tr>');
      dbms_lob.append(document, l_pend_changes);
      dbms_lob.append(document, '</TABLE>');
    END IF;
  
    dbms_lob.append(document,
	        '<BR><BR>Document Instance Id: ' || document_id);
    ------- History
    l_history_clob := NULL;
    dbms_lob.append(document,
	        '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
			display_type  => '',
			document      => l_history_clob,
			document_type => document_type);
  
    dbms_lob.append(document, l_history_clob);
  
  END generate_need_approval_msg_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_period_length
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      10/07/2014
  --  Purpose :           Get value of DFF Period Length from payment terms definition
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_period_length(p_term_id NUMBER) RETURN NUMBER IS
    l_period_length NUMBER;
  
  BEGIN
  
    SELECT attribute1
    INTO   l_period_length
    FROM   ra_terms rt
    WHERE  rt.term_id = p_term_id;
  
    RETURN l_period_length;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_period_length;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_credit_limit_usd
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      10/07/2014
  --  Purpose :           Get value of DFF Period Length from payment terms definition
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_credit_limit_usd(p_new_credit_limit  IN VARCHAR2,
		         p_new_currency_code IN VARCHAR2,
		         x_usd_credit_limit  OUT VARCHAR2,
		         x_err_code          OUT NUMBER,
		         x_err_msg           OUT VARCHAR2) IS
    l_prog_name VARCHAR2(30) := 'get_credit_limit_usd';
  BEGIN
    x_err_code  := '0';
    x_err_msg   := '';
    g_debug_ind := 'GCLU1';
  
    IF p_new_currency_code = 'USD' THEN
      x_usd_credit_limit := p_new_credit_limit;
    ELSE
      -- Convert credit limit to USD
      g_debug_ind := 'GCLU2';
      BEGIN
        SELECT gdr.conversion_rate * p_new_credit_limit
        INTO   x_usd_credit_limit
        FROM   gl_daily_rates gdr
        WHERE  gdr.to_currency = 'USD'
        AND    gdr.conversion_type = 'Corporate'
        AND    gdr.from_currency = p_new_currency_code
        AND    gdr.conversion_date =
	   (SELECT MAX(conversion_date)
	     FROM   gl_daily_rates gdr1
	     WHERE  gdr1.conversion_date < SYSDATE
	     AND    gdr1.from_currency = gdr.from_currency
	     AND    gdr1.conversion_type = gdr.conversion_type
	     AND    gdr1.to_currency = gdr.to_currency);
      
        fnd_log.string(log_level => fnd_log.level_statement,
	           module    => c_debug_module || l_prog_name,
	           message   => 'get_credit_limit_usd=' ||
			x_usd_credit_limit);
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code  := '1';
          x_err_msg   := 'Error: cannot convert credit limit from ' ||
		 p_new_currency_code || ' to USD: ' || SQLERRM;
          g_debug_ind := 'GCLU3';
          fnd_log.string(log_level => fnd_log.level_unexpected,
		 module    => c_debug_module || l_prog_name,
		 message   => x_err_msg);
          RETURN;
      END;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code  := '1';
      x_err_msg   := 'Unexpected error in get_credit_limit_usd: ' ||
	         SQLERRM;
      g_debug_ind := 'GCLU4';
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => x_err_msg);
  END get_credit_limit_usd;

  --------------------------------------------------------------------
  --  customization code: CHG0034590- Customer Workflow Additions V2
  --  name:               get_credit_insurance_amount
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      16/06/2015
  --  Purpose :           Get CI decision amount
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/06/2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_credit_insurance_amount(p_cust_acct_profile_amt_id NUMBER)
    RETURN NUMBER IS
    l_amount NUMBER;
  BEGIN
    SELECT hcpa.attribute4
    INTO   l_amount
    FROM   hz_cust_profile_amts hcpa
    WHERE  1 = 1
    AND    hcpa.cust_acct_profile_amt_id = p_cust_acct_profile_amt_id;
  
    RETURN nvl(l_amount, 0);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_credit_insurance_amount;
  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               is_approval_required
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      07/07/2014
  --  Purpose :           Indicates wether the approval WF should run or not
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/07/2014    Michal Tzvik    initial build
  --  1.1   15/06/2015    Michal Tzvik    CHG0034590 - Changes in credit limit approval:
  --                                      1. If credit limit is changed to null then it require approval
  -----------------------------------------------------------------------
  PROCEDURE is_approval_required(p_entity_code          IN VARCHAR2,
		         p_old_value            IN VARCHAR2,
		         p_new_value            IN VARCHAR2,
		         p_cust_acct_id         IN NUMBER,
		         p_site_id              IN NUMBER,
		         p_site_use_id          IN NUMBER,
		         p_attribute1           IN VARCHAR2 DEFAULT NULL, -- Used for currency code in case of credit limit update
		         p_attribute2           IN VARCHAR2 DEFAULT NULL,
		         p_attribute3           IN VARCHAR2 DEFAULT NULL,
		         x_is_approval_required OUT VARCHAR2, -- Y / N
		         x_err_code             OUT NUMBER,
		         x_err_msg              OUT VARCHAR2) IS
    l_credit_limit_threshold  NUMBER := fnd_profile.value('XXAR_CREDIT_LIMIT_THRESHOLD');
    l_credit_limit_usd        NUMBER;
    l_period_length_threshold NUMBER := fnd_profile.value('XXAR_PERIOD_LENGTH_THRESHOLD');
    l_old_period_length       NUMBER;
    l_new_period_length       NUMBER;
    l_customer_type           hz_cust_accounts_all.customer_type%TYPE;
    --l_prog_name               VARCHAR2(30) := 'is_approval_required';
  BEGIN
    x_err_code             := '0';
    x_err_msg              := '';
    x_is_approval_required := 'N';
  
    g_debug_ind := 'IAR1';
    IF nvl(fnd_profile.value('XXAR_CUST_WF_ENABLED'), 'Y') = 'N' THEN
      x_is_approval_required := 'N';
      RETURN;
    END IF;
  
    IF nvl(p_old_value, '-1') = nvl(p_new_value, '-1') THEN
      x_is_approval_required := 'N';
      RETURN;
    END IF;
  
    g_debug_ind := 'IAR2';
    -- If it is an INTERNAL customer, approval is not needed
    SELECT customer_type
    INTO   l_customer_type
    FROM   hz_cust_accounts_all hca
    WHERE  hca.cust_account_id = p_cust_acct_id;
  
    IF l_customer_type = 'I' THEN
      x_is_approval_required := 'N';
      RETURN;
    END IF;
  
    --------------------------------------------------
    IF p_entity_code = c_cust_credit_chk THEN
      g_debug_ind := 'IAR2';
      IF p_new_value = 'N' THEN
        x_is_approval_required := 'Y';
      END IF;
    
      --------------------------------------------------
    ELSIF p_entity_code = c_cust_credit_hold THEN
      g_debug_ind := 'IAR3';
      IF p_new_value = 'N' AND p_old_value = 'Y' THEN
        x_is_approval_required := 'Y';
      END IF;
    
      --------------------------------------------------
    ELSIF p_entity_code = c_cust_credit_limit THEN
      g_debug_ind := 'IAR4';
      IF l_credit_limit_threshold IS NULL THEN
        g_debug_ind := 'IAR4.1';
        x_err_code  := '1';
        x_err_msg   := 'Error: no value is defined for profile XXAR_CREDIT_LIMIT_THRESHOLD';
        RETURN;
      END IF;
    
      --1.1   15/06/2015  Michal Tzvik: start
      -- If the user changes the credit limit amount to NULL, it actually means that the customer gets
      -- unlimited credit. This is why an approval is required.
      IF p_new_value IS NULL AND p_old_value IS NOT NULL THEN
        g_debug_ind            := 'IAR4.11';
        x_is_approval_required := 'Y';
        --1.1: end
      
      ELSIF to_number(p_new_value) > to_number(nvl(p_old_value, 0)) THEN
        g_debug_ind := 'IAR4.2';
        get_credit_limit_usd(p_new_credit_limit  => p_new_value,
		     p_new_currency_code => p_attribute1,
		     x_usd_credit_limit  => l_credit_limit_usd,
		     x_err_code          => x_err_code,
		     x_err_msg           => x_err_msg);
      
        g_debug_ind := 'IAR4.3';
        IF x_err_code != '0' THEN
          RETURN;
        END IF;
      
        IF l_credit_limit_usd > l_credit_limit_threshold THEN
          x_is_approval_required := 'Y';
        END IF;
      END IF;
    
      g_debug_ind := 'IAR5';
      --------------------------------------------------
    ELSIF p_entity_code = c_cust_pay_term THEN
      g_debug_ind := 'IAR6';
      -- 01.02.2014 Michal Tzvik: fix bug: no approval is required when new payment term IS NULL
      IF p_new_value IS NOT NULL THEN
        IF l_period_length_threshold IS NULL THEN
          x_err_code := '1';
          x_err_msg  := 'Error: no value is defined for profile XXAR_PERIOD_LENGTH_THRESHOLD';
          RETURN;
        END IF;
      
        l_new_period_length := get_period_length(p_new_value);
        IF l_new_period_length IS NULL THEN
          x_err_code := '1';
          x_err_msg  := 'Error: period length is not defined for new payment term.';
          RETURN;
        END IF;
      
        IF p_old_value IS NULL THEN
          l_old_period_length := 0;
        ELSE
          l_old_period_length := get_period_length(p_old_value);
          IF l_old_period_length IS NULL THEN
	x_err_code := '1';
	x_err_msg  := 'Error: period length is not defined for old payment term.';
	RETURN;
          END IF;
        END IF;
      
        g_debug_ind := 'IAR7';
        IF l_new_period_length > l_period_length_threshold AND
           l_new_period_length > l_old_period_length THEN
          x_is_approval_required := 'Y';
        END IF;
      END IF;
    
    ELSE
      x_err_code  := '1';
      x_err_msg   := 'Error: invalid document: ' || p_entity_code;
      g_debug_ind := 'IAR8';
    END IF;
  
  END is_approval_required;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               submit_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      07/07/2014
  --  Purpose :           This procedure is been called when saving changes in Customer
  --                      or customer site use screens. It is doing the following:
  --                      1.  Check if current change requires approval.
  --                      2.  Save data in table xxobjt_wf_doc_instance.
  --                      3.  Submit WF XXWFDOC in case when approval is needed.
  --                      Used for the following documents (p_entity_code):
  --                      CUST_CREDIT_LIMIT
  --                      CUST_PAY_TERM
  --                      CUST_CREDIT_CHK
  --                      CUST_CREDIT_HOLD
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/07/2014    Michal Tzvik    initial build
  --  1.1   01/07/2015    Michal Tzvik    CHG0034590 - Show a different message when automatic approval is needed
  -----------------------------------------------------------------------
  PROCEDURE submit_wf(p_entity_code              IN VARCHAR2,
	          p_old_value                IN VARCHAR2,
	          p_new_value                IN VARCHAR2,
	          p_cust_acct_id             IN NUMBER,
	          p_site_id                  IN NUMBER, -- party_site_id
	          p_site_use_id              IN NUMBER,
	          p_cust_account_profile_id  IN NUMBER,
	          p_cust_acct_profile_amt_id IN NUMBER,
	          p_attribute1               IN VARCHAR2 DEFAULT NULL, -- Used for currency code in case of credit limit update
	          p_attribute2               IN VARCHAR2 DEFAULT NULL,
	          p_attribute3               IN VARCHAR2 DEFAULT NULL,
	          x_err_code                 OUT NUMBER,
	          x_err_msg                  OUT VARCHAR2,
	          x_itemkey                  OUT VARCHAR2,
	          x_appr_needed              OUT VARCHAR2) IS
    l_err_code             NUMBER;
    l_err_msg              VARCHAR2(1000);
    l_doc_instance_header  xxobjt_wf_doc_instance%ROWTYPE;
    l_person_id            NUMBER := fnd_global.employee_id;
    l_is_approval_required VARCHAR2(1);
    l_is_in_process        VARCHAR2(1);
    l_in_process_msg       VARCHAR2(350);
    l_prog_name            VARCHAR2(30) := 'submit_wf';
  
    l_credit_limit_usd NUMBER; -- 1.1 Michal Tzvik
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
    x_itemkey  := '';
  
    g_debug_ind := 'SW1';
    is_approval_required(p_entity_code,
		 p_old_value,
		 p_new_value,
		 p_cust_acct_id,
		 p_site_id,
		 p_site_use_id,
		 p_attribute1, -- Used for currency code in case of credit limit update
		 p_attribute2,
		 p_attribute3,
		 l_is_approval_required,
		 l_err_code,
		 l_err_msg);
  
    g_debug_ind := 'SW2';
    IF l_err_code != 0 THEN
      x_err_code := 1;
      x_err_msg  := l_err_msg;
      RETURN;
    END IF;
  
    --- debug
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || l_prog_name,
	       message   => 'p_entity_code=' || p_entity_code ||
		        ' p_old_value=' || p_old_value ||
		        ' p_new_value=' || p_new_value ||
		        ' is_approval_required=' ||
		        l_is_approval_required || ' p_attribute1=' ||
		        p_attribute1 ||
		        ' p_cust_acct_profile_amt_id=' ||
		        p_cust_acct_profile_amt_id ||
		        ' p_cust_acct_id=' || p_cust_acct_id ||
		        ' p_cust_account_profile_id=' ||
		        p_cust_account_profile_id ||
		        ' p_site_use_id=' || p_site_use_id ||
		        ' p_site_id=' || p_site_id || ' org_id=' ||
		        fnd_global.org_id);
    g_debug_ind := 'SW3';
  
    -- Check that same change is not IN PROCESS already
    SELECT nvl(MAX('Y'), 'N'),
           MAX('Attention: This change is already in Process: ' ||
	   xwd.doc_name || ' (New Value: ' ||
	   xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				    xwdi.attribute5) ||
	   ', Approver: ' ||
	   hr_general.decode_person_name(xwdi.approver_person_id) || ')')
    INTO   l_is_in_process,
           l_in_process_msg
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  1 = 1
    AND    xwdi.doc_status IN ('IN_PROCESS', 'ERROR')
    AND    xwdi.end_date IS NULL
    AND    xwdi.n_attribute1 = p_cust_acct_id
    AND    nvl(xwdi.n_attribute2, -1) = nvl(p_site_id, -1)
    AND    nvl(xwdi.n_attribute3, -1) = nvl(p_site_use_id, -1)
    AND    xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code = nvl(p_entity_code, xwd.doc_code)
    AND    nvl(xwdi.attribute4, '-1') = nvl(p_old_value, '-1')
    AND    nvl(xwdi.attribute5, '-1') = nvl(p_new_value, '-1');
  
    IF l_is_in_process = 'Y' THEN
      -- Avoid saving the record, and avoid send WF for the same change again
      x_err_msg     := l_in_process_msg;
      x_appr_needed := 'Y'; -- Avoid saving the record
      RETURN;
    END IF;
  
    IF l_is_approval_required = 'N' THEN
      dbms_output.put_line('XXHZ_CUST_APR_UTIL_PKG.submit_wf: no approval is needed. ');
      x_err_msg     := 'No approval is needed, Your changes will be saved.';
      x_appr_needed := 'N';
      RETURN;
    ELSE
      x_appr_needed := 'Y';
    END IF;
  
    IF nvl(l_person_id, -1) = -1 THEN
      dbms_output.put_line('XXHZ_CUST_APR_UTIL_PKG.submit_wf: invalid person. user name = ' ||
		   fnd_global.user_name);
      x_err_code := 1;
      x_err_msg  := 'invalid person. user name = ' || fnd_global.user_name;
      RETURN;
    END IF;
  
    g_debug_ind := 'SW4';
  
    l_doc_instance_header.user_id             := fnd_global.user_id;
    l_doc_instance_header.resp_id             := fnd_global.resp_id;
    l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
    l_doc_instance_header.requestor_person_id := l_person_id;
    l_doc_instance_header.creator_person_id   := l_person_id;
    l_doc_instance_header.n_attribute1        := p_cust_acct_id;
    l_doc_instance_header.n_attribute2        := p_site_id;
    l_doc_instance_header.n_attribute3        := p_site_use_id;
    l_doc_instance_header.n_attribute4        := p_cust_account_profile_id;
    l_doc_instance_header.n_attribute5        := p_cust_acct_profile_amt_id;
  
    --
    l_doc_instance_header.attribute1 := p_attribute1;
    l_doc_instance_header.attribute2 := p_attribute2;
    l_doc_instance_header.attribute3 := p_attribute3;
  
    -- set new/old value
    l_doc_instance_header.attribute4 := p_old_value;
    l_doc_instance_header.attribute5 := p_new_value;
    l_doc_instance_header.attribute6 := fnd_global.org_id;
  
    g_debug_ind := 'SW5';
  
    -- Get value of site_use_id
    IF p_site_use_id IS NULL AND p_site_id IS NOT NULL THEN
      BEGIN
      
        SELECT hcsu.site_use_id
        INTO   l_doc_instance_header.n_attribute3
        FROM   hz_parties             hp,
	   hz_party_sites         hps,
	   hz_party_site_uses     hpsu,
	   hz_cust_accounts       hca,
	   hz_cust_acct_sites_all hcas,
	   hz_cust_site_uses_all  hcsu
        WHERE  hp.party_id = hps.party_id
        AND    hp.party_id = hca.party_id
        AND    hps.party_site_id = hcas.party_site_id
        AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
        AND    hps.party_site_id = hpsu.party_site_id
        AND    hcsu.site_use_code = hpsu.site_use_type
        AND    hcsu.site_use_code = 'BILL_TO'
        AND    hcsu.status = 'A'
        AND    hcsu.org_id = fnd_profile.value('org_id')
        AND    hcas.party_site_id = p_site_id
        AND    hca.cust_account_id = p_cust_acct_id;
      
        g_debug_ind := 'SW6';
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code    := 1;
          x_err_msg     := 'Submit_WF : unable to get site_use_id: ' ||
		   SQLERRM;
          x_appr_needed := 'Y'; -- Avoid saving the record
          RETURN;
      END;
    END IF;
  
    -- Get currency code if needed
    IF p_entity_code = c_cust_credit_limit AND p_attribute1 IS NULL THEN
      BEGIN
        SELECT pam.currency_code
        INTO   l_doc_instance_header.attribute1
        FROM   hz_cust_profile_amts pam
        WHERE  pam.cust_acct_profile_amt_id = p_cust_acct_profile_amt_id;
      
        g_debug_ind := 'SW7';
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code := '1';
          x_err_msg  := 'Error: cannot get profile amount currency: ' ||
		SQLERRM;
          RETURN;
      END;
    END IF;
  
    BEGIN
      SELECT doc_id
      INTO   l_doc_instance_header.doc_id
      FROM   xxobjt_wf_docs xwd
      WHERE  xwd.doc_code = p_entity_code;
    
      g_debug_ind := 'SW8';
    EXCEPTION
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'invalid entity code ' || p_entity_code;
        RETURN;
    END;
  
    g_debug_ind := 'SW9';
  
    xxobjt_wf_doc_util.create_instance(p_err_code            => l_err_code,
			   p_err_msg             => l_err_msg,
			   p_doc_instance_header => l_doc_instance_header,
			   p_doc_code            => p_entity_code);
  
    IF l_err_code = 1 THEN
      x_err_code := 1;
      x_err_msg  := ('Error in create_instance: ' || l_err_msg);
    ELSE
      g_debug_ind := 'SW10';
      xxobjt_wf_doc_util.initiate_approval_process(p_err_code        => l_err_code,
				   p_err_msg         => l_err_msg,
				   p_doc_instance_id => l_doc_instance_header.doc_instance_id,
				   p_wf_item_key     => x_itemkey);
    
      IF l_err_code = 1 THEN
        x_err_code := 1;
        x_err_msg  := ('Error in initiate_approval_process: ' || l_err_msg);
      ELSE
        -- 1.1 Michal Tzvik: Do not show message when auto approval is needed
        IF p_entity_code = c_cust_credit_limit THEN
          get_credit_limit_usd(p_new_credit_limit  => p_new_value, --
		       p_new_currency_code => p_attribute1, --
		       x_usd_credit_limit  => l_credit_limit_usd, --
		       x_err_code          => x_err_code,
		       x_err_msg           => x_err_msg);
        END IF;
      
        IF p_entity_code = c_cust_credit_limit AND get_credit_insurance_amount(p_cust_acct_profile_amt_id) >=
           l_credit_limit_usd THEN
          x_err_msg := 'Your changes will be saved automatically.';
        
        ELSE
          x_err_msg := 'Your request for ' ||
	           xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id) ||
	           ' change was sent for approval. doc_instance_id=' ||
	           l_doc_instance_header.doc_instance_id;
        END IF;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := ('XXHZ_CUST_APR_UTIL_PKG.submit_wf: Unexpected error: ' ||
	        SQLERRM || ' [' || g_debug_ind || ']');
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => x_err_msg);
  END submit_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_wf_info
  --  create by:          Yuval tal
  --  Revision:           1.0
  --  creation date:      07/07/2014
  --  Purpose :           This procedure is been called from Customer / Site / Site Use screens.
  --                      It returns an informative message that lists existing pending changes
  --                      that were not approved yet for current customer / site.
  --                      The message appears in top of the screen.
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/07/2014    Yuval tal     initial build
  -----------------------------------------------------------------------

  PROCEDURE get_wf_info(p_cust_acct_id      IN NUMBER,
		p_site_id           IN NUMBER,
		p_site_use_id       IN NUMBER,
		p_entity_code       IN VARCHAR2,
		x_err_code          OUT NUMBER,
		x_err_msg           OUT VARCHAR2,
		x_exists_pending_wf OUT VARCHAR2,
		x_info              OUT VARCHAR2
		
		) IS
    l_cnt_chng      NUMBER := 0;
    l_customer_name hz_parties.party_name%TYPE;
    l_changes       VARCHAR2(3500);
  
    CURSOR c_chng(p_cust_acct_id NUMBER,
	      p_site_id      NUMBER,
	      p_site_use_id  NUMBER,
	      p_entity_code  VARCHAR2) IS
      SELECT xwd.doc_name,
	 xwdi.doc_instance_id,
	 xxhz_cust_apr_util_pkg.get_dsp_value(xwd.doc_code,
				  xwdi.attribute5) new_value,
	 hr_general.decode_person_name(xwdi.approver_person_id) approver
      FROM   xxobjt_wf_doc_instance xwdi,
	 xxobjt_wf_docs         xwd
      WHERE  1 = 1
      AND    xwdi.doc_status = 'IN_PROCESS'
      AND    xwdi.n_attribute1 = p_cust_acct_id
      AND    (nvl(xwdi.n_attribute2, -1) = nvl(p_site_id, -1) OR
	p_site_id IS NULL)
      AND    (nvl(xwdi.n_attribute3, -1) = nvl(p_site_use_id, -1) OR
	(p_site_use_id IS NULL AND
	xwdi.attribute6 = fnd_global.org_id))
      AND    xwd.doc_id = xwdi.doc_id
      AND    xwd.doc_code = nvl(p_entity_code, xwd.doc_code)
      ORDER  BY xwdi.doc_instance_id DESC;
  
  BEGIN
    x_err_code          := 0;
    x_exists_pending_wf := 'N';
    x_info              := '';
  
    SELECT hp.party_name
    INTO   l_customer_name
    FROM   hz_cust_accounts hca,
           hz_parties       hp
    WHERE  hca.cust_account_id = p_cust_acct_id
    AND    hp.party_id = hca.party_id;
  
    FOR r_chng IN c_chng(p_cust_acct_id,
		 p_site_id,
		 p_site_use_id,
		 p_entity_code) LOOP
      l_cnt_chng := l_cnt_chng + 1;
      l_changes  := l_changes || ', ' || r_chng.doc_name || ' (Value: ' ||
	        r_chng.new_value || ', Approver: ' || r_chng.approver || ')';
    END LOOP;
  
    IF l_cnt_chng = 1 THEN
      x_exists_pending_wf := 'Y';
      x_info              := 'Attention: There is a pending Approval Process for customer ' ||
		     l_customer_name || ': ' ||
		     substr(l_changes, 3);
    ELSIF l_cnt_chng > 1 THEN
      x_exists_pending_wf := 'Y';
      x_info              := 'Attention: There are pending Approval Processes for customer ' ||
		     l_customer_name || ': ' ||
		     substr(l_changes, 3);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Error in xxhz_cust_apr_util_pkg.get_wf_info: ' ||
	        SQLERRM;
  END get_wf_info;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               call_apps_initialize
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      17/07/2014
  --  Purpose :           call fnd_global.apps_initialize. use to run api with requestor values
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE call_apps_initialize(p_doc_instance_id IN NUMBER) IS
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    l_org_id       NUMBER;
  BEGIN
  
    xxobjt_wf_doc_util.get_apps_initialize_params(p_doc_instance_id,
				  l_user_id,
				  l_resp_id,
				  l_resp_appl_id);
  
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    SELECT xwdi.attribute6
    INTO   l_org_id
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
    mo_global.set_policy_context('S', l_org_id);
    mo_global.init('AR');
    dbms_output.put_line('org_id=' || l_org_id);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END call_apps_initialize;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_cust_site_use
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      27/07/2014
  --  Purpose :           Update customer site use

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE update_cust_site_use(p_doc_instance_id  IN NUMBER,
		         p_site_use_id      IN NUMBER,
		         p_payment_terms_id IN NUMBER,
		         x_err_code         OUT NUMBER,
		         x_err_msg          OUT VARCHAR2) IS
    l_object_version_number hz_cust_site_uses_all.object_version_number%TYPE;
    l_cust_site_use_rec     hz_cust_account_site_v2pub.cust_site_use_rec_type;
    x_return_status         VARCHAR2(2000);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    mo_global.init('AR');
    call_apps_initialize(p_doc_instance_id);
  
    SELECT hcsu.object_version_number,
           hcsu.cust_acct_site_id,
           hcsu.org_id
    INTO   l_object_version_number,
           l_cust_site_use_rec.cust_acct_site_id,
           l_cust_site_use_rec.org_id
    FROM   hz_cust_site_uses_all hcsu
    WHERE  hcsu.site_use_id = p_site_use_id;
  
    l_cust_site_use_rec.site_use_id     := p_site_use_id;
    l_cust_site_use_rec.payment_term_id := p_payment_terms_id;
  
    hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => fnd_api.g_true,
				    p_cust_site_use_rec     => l_cust_site_use_rec,
				    p_object_version_number => l_object_version_number,
				    x_return_status         => x_return_status,
				    x_msg_count             => x_msg_count,
				    x_msg_data              => x_msg_data);
  
    IF x_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
    ELSE
      -- ROLLBACK;
      x_err_code := '1';
    
      IF x_msg_count > 0 THEN
        x_err_msg := 'Error in Update Cust Site Use API:';
        FOR i IN 1 .. x_msg_count LOOP
          x_err_msg := x_err_msg || ' ' || i || '.' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
        
        END LOOP;
      ELSE
        x_err_msg := 'Undocumented error from Update Cust Site Use API is: ' ||
	         x_return_status || ' ,msg count: ' || x_msg_count ||
	         ' ,message: ' || x_msg_data;
      END IF;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected Error in xxhz_cust_apr_util_pkg.update_cust_site_use: ' ||
	        SQLERRM;
  END update_cust_site_use;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               create_customer_profile
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      10/07/2014
  --  Purpose :           create customer profile

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE create_customer_profile(p_customer_profile_rec    IN hz_customer_profile_v2pub.customer_profile_rec_type,
			p_create_profile_amt      IN VARCHAR2,
			x_cust_account_profile_id OUT NUMBER,
			x_err_code                OUT NUMBER,
			x_err_msg                 OUT VARCHAR2) IS
    l_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
    x_return_status        VARCHAR2(2000);
    x_msg_count            NUMBER;
    x_msg_data             VARCHAR2(2000);
    l_tmp                  NUMBER;
    l_err_msg              VARCHAR2(2000);
    l_prog_name            VARCHAR2(30) := 'create_customer_profile';
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    l_customer_profile_rec                   := p_customer_profile_rec;
    l_customer_profile_rec.created_by_module := 'CUST_INTERFACE';
  
    hz_customer_profile_v2pub.create_customer_profile(p_init_msg_list           => fnd_api.g_true,
				      p_customer_profile_rec    => l_customer_profile_rec,
				      p_create_profile_amt      => p_create_profile_amt,
				      x_cust_account_profile_id => x_cust_account_profile_id,
				      x_return_status           => x_return_status,
				      x_msg_count               => x_msg_count,
				      x_msg_data                => x_msg_data);
    dbms_output.put_line('create_customer_profile x_return_status: ' ||
		 x_return_status);
  
    IF x_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
    ELSE
      x_err_code := 1;
      IF x_msg_count > 0 THEN
        x_err_msg := 'Error in Create Customer Profile API:';
        FOR i IN 1 .. x_msg_count LOOP
        
          fnd_msg_pub.get(i, 'F', l_err_msg, l_tmp);
          x_err_msg := x_err_msg || ' ' || l_err_msg;
        
        END LOOP;
      ELSE
        x_err_msg := 'Undocumented error from Create Customer Profile API is: ' ||
	         x_return_status || ' ,msg count: ' || x_msg_count ||
	         ' ,message: ' || x_msg_data;
      END IF;
    
      fnd_log.string(log_level => fnd_log.level_statement,
	         module    => c_debug_module || l_prog_name,
	         message   => 'Create Customer Profile x_return_status=' ||
		          x_return_status);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'create_customer_profile: ' || SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END create_customer_profile;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_customer_profile
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      10/07/2014
  --  Purpose :           Update the following fields: credit_checking/ credit_hold/ standard_terms (payment term)

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------

  PROCEDURE update_customer_profile(p_doc_instance_id           IN NUMBER,
			p_customer_profile_rec_type hz_customer_profile_v2pub.customer_profile_rec_type,
			x_cust_account_profile_id   OUT NUMBER,
			x_err_code                  OUT NUMBER,
			x_err_msg                   OUT VARCHAR2) IS
    l_customer_profile_rec  hz_customer_profile_v2pub.customer_profile_rec_type;
    l_object_version_number hz_customer_profiles.object_version_number%TYPE;
    x_return_status         VARCHAR2(2000);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    l_profile_exists        VARCHAR2(1) := 'Y';
    l_cust_account_id       NUMBER;
    l_site_use_id           NUMBER;
    l_prog_name             VARCHAR2(30) := 'update_customer_profile';
  
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT xwdi.n_attribute1,
           xwdi.n_attribute3
    INTO   l_cust_account_id,
           l_site_use_id
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
    BEGIN
    
      SELECT hcp.object_version_number
      INTO   l_object_version_number
      FROM   hz_customer_profiles hcp
      WHERE  hcp.cust_account_profile_id =
	 p_customer_profile_rec_type.cust_account_profile_id
      AND    hcp.status = 'A';
    
    EXCEPTION
      WHEN no_data_found THEN
        l_profile_exists := 'N';
    END;
  
    IF l_profile_exists = 'N' THEN
      BEGIN
        SELECT h.object_version_number
        INTO   l_object_version_number
        FROM   hz_customer_profiles h
        WHERE  h.cust_account_id = l_cust_account_id
        AND    nvl(h.site_use_id, -1) = nvl(l_site_use_id, -1);
      
      EXCEPTION
        WHEN no_data_found THEN
          l_profile_exists := 'N';
      END;
    END IF;
  
    mo_global.init('AR');
    call_apps_initialize(p_doc_instance_id);
    IF l_profile_exists = 'Y' THEN
      -- UPDATE PROFILE
      hz_customer_profile_v2pub.update_customer_profile(p_init_msg_list         => 'T',
				        p_customer_profile_rec  => p_customer_profile_rec_type,
				        p_object_version_number => l_object_version_number,
				        x_return_status         => x_return_status,
				        x_msg_count             => x_msg_count,
				        x_msg_data              => x_msg_data);
    
      IF x_return_status = fnd_api.g_ret_sts_success THEN
        COMMIT;
      ELSE
        x_err_code := '1';
      
        IF x_msg_count > 0 THEN
          x_err_msg := 'Error in Update Customer Profile API:';
          FOR i IN 1 .. x_msg_count LOOP
	x_err_msg := x_err_msg || ' ' || i || '.' ||
		 substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		        1,
		        255);
          END LOOP;
        ELSE
          x_err_msg := 'Undocumented error from Update Customer Profile API is: ' ||
	           x_return_status || ' ,msg count: ' || x_msg_count ||
	           ' ,message: ' || x_msg_data;
        END IF;
      
      END IF;
    ELSE
      -- CREATE PROFILE
    
      l_customer_profile_rec                         := p_customer_profile_rec_type;
      l_customer_profile_rec.cust_account_profile_id := fnd_api.g_miss_num;
      l_customer_profile_rec.cust_account_id         := l_cust_account_id;
      l_customer_profile_rec.site_use_id             := l_site_use_id;
    
      create_customer_profile(p_customer_profile_rec    => l_customer_profile_rec,
		      p_create_profile_amt      => fnd_api.g_false,
		      x_cust_account_profile_id => x_cust_account_profile_id,
		      x_err_code                => x_err_code,
		      x_err_msg                 => x_err_msg);
      IF x_err_code = '1' THEN
        RETURN;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected Error in xxhz_cust_apr_util_pkg.update_customer_profile: ' ||
	        SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END update_customer_profile;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_cust_profile_amt
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      10/07/2014
  --  Purpose :           Update the following field: overall_credit_limit

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE update_cust_profile_amt(p_doc_instance_id IN NUMBER,
			x_err_code        OUT NUMBER,
			x_err_msg         OUT VARCHAR2) IS
    l_prof_amt_rec             hz_customer_profile_v2pub.cust_profile_amt_rec_type;
    l_customer_profile_rec     hz_customer_profile_v2pub.customer_profile_rec_type;
    l_object_version_number    NUMBER;
    x_return_status            VARCHAR2(2000);
    l_profile_amt_exists       VARCHAR2(1);
    x_msg_count                NUMBER;
    x_msg_data                 VARCHAR2(2000);
    x_cust_acct_profile_amt_id NUMBER;
    l_tmp                      NUMBER;
    l_err_msg                  VARCHAR2(2000);
    CURSOR c IS
      SELECT doc_instance_id,
	 xwdi.n_attribute5 cust_account_profile_amt_id,
	 xwdi.n_attribute4 cust_account_profile_id,
	 xwdi.attribute5   credit_limit,
	 xwdi.n_attribute1 cust_acct_id,
	 xwdi.n_attribute2 cust_acct_site_id,
	 xwdi.n_attribute3 site_use_id,
	 xwdi.attribute1   curr_code
      FROM   xxobjt_wf_doc_instance xwdi
      WHERE  xwdi.doc_instance_id = p_doc_instance_id;
    i           c%ROWTYPE;
    l_prog_name VARCHAR2(30) := 'update_cust_profile_amt';
  BEGIN
    x_err_code := '0';
    x_err_msg  := 'success';
  
    OPEN c;
    FETCH c
      INTO i;
    CLOSE c;
    IF i.doc_instance_id IS NULL THEN
      RETURN;
    END IF;
  
    --
    BEGIN
      SELECT pam.object_version_number
      INTO   l_object_version_number
      FROM   hz_cust_profile_amts pam
      WHERE  pam.cust_acct_profile_amt_id = i.cust_account_profile_amt_id;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_profile_amt_exists := 'N';
    END;
  
    call_apps_initialize(p_doc_instance_id);
  
    IF l_profile_amt_exists = 'N' THEN
    
      BEGIN
        SELECT h.cust_account_profile_id
        INTO   l_prof_amt_rec.cust_account_profile_id
        FROM   hz_customer_profiles h
        WHERE  h.cust_account_profile_id = i.cust_account_profile_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN
	SELECT h.cust_account_profile_id
	INTO   l_prof_amt_rec.cust_account_profile_id
	FROM   hz_customer_profiles h
	WHERE  h.cust_account_id = i.cust_acct_id
	AND    nvl(h.site_use_id, -1) = nvl(i.site_use_id, -1);
          EXCEPTION
	WHEN no_data_found THEN
	  l_customer_profile_rec.cust_account_id := i.cust_acct_id;
	  l_customer_profile_rec.site_use_id     := i.site_use_id;
	  create_customer_profile(p_customer_profile_rec    => l_customer_profile_rec,
			  p_create_profile_amt      => fnd_api.g_false,
			  x_cust_account_profile_id => l_prof_amt_rec.cust_account_profile_id,
			  x_err_code                => x_err_code,
			  x_err_msg                 => x_err_msg);
	  IF x_err_code = '1' THEN
	    RETURN;
	  END IF;
          END;
        
        WHEN OTHERS THEN
          x_err_code := '1';
          x_err_msg  := 'Failed to get cust_account_profile_id: ' ||
		SQLERRM;
          fnd_log.string(log_level => fnd_log.level_unexpected,
		 module    => c_debug_module || l_prog_name,
		 message   => x_err_msg);
          RETURN;
      END;
      -- create profile amount
      l_prof_amt_rec.cust_account_id      := i.cust_acct_id;
      l_prof_amt_rec.site_use_id          := i.site_use_id;
      l_prof_amt_rec.currency_code        := nvl(i.curr_code,
				 fnd_api.g_miss_char);
      l_prof_amt_rec.overall_credit_limit := i.credit_limit;
    
      hz_customer_profile_v2pub.create_cust_profile_amt(p_init_msg_list            => fnd_api.g_true,
				        p_check_foreign_key        => fnd_api.g_true,
				        p_cust_profile_amt_rec     => l_prof_amt_rec,
				        x_cust_acct_profile_amt_id => x_cust_acct_profile_amt_id,
				        x_return_status            => x_return_status,
				        x_msg_count                => x_msg_count,
				        x_msg_data                 => x_msg_data);
    
      IF x_return_status = fnd_api.g_ret_sts_success THEN
        COMMIT;
      ELSE
        x_err_code := 1;
        IF x_msg_count > 0 THEN
          x_err_msg := 'Error in Create Cust Profile Amt API:';
          FOR i IN 1 .. x_msg_count LOOP
          
	fnd_msg_pub.get(i, 'F', l_err_msg, l_tmp);
	x_err_msg := x_err_msg || ' ' || l_err_msg;
          
          END LOOP;
        ELSE
          x_err_msg := 'Undocumented error from Create Cust Profile Amt API is: ' ||
	           x_return_status || ' ,msg count: ' || x_msg_count ||
	           ' ,message: ' || x_msg_data;
        END IF;
      
        fnd_log.string(log_level => fnd_log.level_statement,
	           module    => c_debug_module || l_prog_name,
	           message   => 'update_cust_profile_amt Create x_return_status=' ||
			x_return_status);
      END IF;
    
    ELSE
    
      -- update amount profile
      l_prof_amt_rec.cust_acct_profile_amt_id := i.cust_account_profile_amt_id;
      l_prof_amt_rec.overall_credit_limit     := i.credit_limit;
      call_apps_initialize(p_doc_instance_id);
    
      hz_customer_profile_v2pub.update_cust_profile_amt(p_init_msg_list         => fnd_api.g_true,
				        p_cust_profile_amt_rec  => l_prof_amt_rec,
				        p_object_version_number => l_object_version_number,
				        x_return_status         => x_return_status,
				        x_msg_count             => x_msg_count,
				        x_msg_data              => x_msg_data);
    
      fnd_log.string(log_level => fnd_log.level_statement,
	         module    => c_debug_module || l_prog_name,
	         message   => 'update_cust_profile_amt x_return_status=' ||
		          x_return_status || ' ' || x_msg_data);
    
      IF x_return_status = fnd_api.g_ret_sts_success THEN
        COMMIT;
      ELSE
        x_err_code := 1;
        IF x_msg_count > 0 THEN
          x_err_msg := 'Error in Update Cust Profile Amt API:';
          FOR i IN 1 .. x_msg_count LOOP
          
	fnd_msg_pub.get(i, 'F', l_err_msg, l_tmp);
	x_err_msg := x_err_msg || ' ' || l_err_msg;
          
          END LOOP;
        ELSE
          x_err_msg := 'Undocumented error from Update Cust Profile Amt API is: ' ||
	           x_return_status || ' ,msg count: ' || x_msg_count ||
	           ' ,message: ' || x_msg_data;
        END IF;
      END IF;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      x_err_code := 1;
      x_err_msg  := 'update_cust_profile_amt:' || SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END update_cust_profile_amt;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_credit_checking
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      13/07/2014
  --  Purpose :           Update customer credit_checking

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE update_credit_checking(p_doc_instance_id         IN NUMBER,
		           p_cust_account_profile_id IN NUMBER,
		           p_credit_checking         IN VARCHAR2,
		           x_err_code                OUT NUMBER,
		           x_err_msg                 OUT VARCHAR2) IS
    l_customer_profile_rec_type hz_customer_profile_v2pub.customer_profile_rec_type;
    l_cust_account_profile_id   NUMBER;
    l_prog_name                 VARCHAR2(30) := 'update_credit_checking';
  
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    l_customer_profile_rec_type.cust_account_profile_id := p_cust_account_profile_id;
    l_customer_profile_rec_type.credit_checking         := p_credit_checking;
  
    update_customer_profile(p_doc_instance_id           => p_doc_instance_id,
		    p_customer_profile_rec_type => l_customer_profile_rec_type,
		    x_cust_account_profile_id   => l_cust_account_profile_id,
		    x_err_code                  => x_err_code,
		    x_err_msg                   => x_err_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in update_credit_checking: ' ||
	        SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END update_credit_checking;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_credit_checking
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      13/07/2014
  --  Purpose :           Update customer credit_hold

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE update_credit_hold(p_doc_instance_id         IN NUMBER,
		       p_cust_account_profile_id IN NUMBER,
		       p_credit_hold             IN VARCHAR2,
		       x_err_code                OUT NUMBER,
		       x_err_msg                 OUT VARCHAR2) IS
    l_customer_profile_rec_type hz_customer_profile_v2pub.customer_profile_rec_type;
    l_cust_account_profile_id   NUMBER;
    l_prog_name                 VARCHAR2(30) := 'update_credit_hold';
  
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    l_customer_profile_rec_type.cust_account_profile_id := p_cust_account_profile_id;
    l_customer_profile_rec_type.credit_hold             := p_credit_hold;
  
    update_customer_profile(p_doc_instance_id           => p_doc_instance_id,
		    x_cust_account_profile_id   => l_cust_account_profile_id,
		    p_customer_profile_rec_type => l_customer_profile_rec_type,
		    x_err_code                  => x_err_code,
		    x_err_msg                   => x_err_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in update_credit_hold: ' || SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END update_credit_hold;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               update_credit_checking
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      13/07/2014
  --  Purpose :           Update customer payment term

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE update_payment_terms(p_doc_instance_id         IN NUMBER,
		         p_cust_account_profile_id IN NUMBER,
		         p_payment_terms_id        IN NUMBER,
		         x_err_code                OUT NUMBER,
		         x_err_msg                 OUT VARCHAR2) IS
    l_customer_profile_rec_type hz_customer_profile_v2pub.customer_profile_rec_type;
    x_cust_account_profile_id   NUMBER;
    l_site_use_id               NUMBER;
    l_prog_name                 VARCHAR2(30) := 'update_payment_terms';
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    IF p_cust_account_profile_id IS NOT NULL THEN
      l_customer_profile_rec_type.cust_account_profile_id := p_cust_account_profile_id;
      l_customer_profile_rec_type.standard_terms          := p_payment_terms_id;
    
      update_customer_profile(p_doc_instance_id           => p_doc_instance_id,
		      x_cust_account_profile_id   => x_cust_account_profile_id,
		      p_customer_profile_rec_type => l_customer_profile_rec_type,
		      x_err_code                  => x_err_code,
		      x_err_msg                   => x_err_msg);
    ELSE
      SELECT n_attribute3
      INTO   l_site_use_id
      FROM   xxobjt_wf_doc_instance xwdi
      WHERE  xwdi.doc_instance_id = p_doc_instance_id;
    
      update_cust_site_use(p_doc_instance_id,
		   l_site_use_id,
		   p_payment_terms_id,
		   x_err_code,
		   x_err_msg);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in update_payment_terms: ' || SQLERRM;
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => c_debug_module || l_prog_name,
	         message   => SQLERRM);
  END update_payment_terms;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_region
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      21/07/2014
  --  Purpose :           get user region, used for approval hirarchy
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/07/2014    Michal Tzvik    initial build
  --  1.1   05/02/2015    Dalit A. Raviv  CHG0034518 is latam customer select will handle in function - get_region
  -----------------------------------------------------------------------
  PROCEDURE get_region(p_user_id     IN NUMBER,
	           p_customer_id IN NUMBER,
	           p_site_id     IN NUMBER,
	           p_site_use_id IN NUMBER,
	           x_region      OUT VARCHAR2,
	           x_err_code    OUT NUMBER,
	           x_err_msg     OUT VARCHAR2) IS
  
    l_is_latam VARCHAR2(10) := 'N';
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    -- 1.1 05/02/2015 Dalit A. Raviv CHG0034518
    -- check if region is LATAM
    l_is_latam := xxhz_util.is_latam_customer(p_site_use_id => p_site_use_id,
			          p_site_id     => p_site_id,
			          p_customer_id => p_customer_id);
    IF l_is_latam = 'Y' THEN
      x_region := 'LATAM';
      RETURN;
    END IF;
  
    -- check if region is IL
    SELECT MAX('IL')
    INTO   x_region
    FROM   hz_parties             hp,
           hz_party_sites         hps,
           hz_party_site_uses     hpsu,
           hz_cust_accounts       hca,
           hz_cust_acct_sites_all hcas,
           hz_cust_site_uses_all  hcsu,
           hr_operating_units     hou
    WHERE  hp.party_id = hps.party_id
    AND    hp.party_id = hca.party_id
    AND    hps.party_site_id = hcas.party_site_id
    AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
    AND    hps.party_site_id = hpsu.party_site_id
    AND    hcsu.site_use_code = hpsu.site_use_type
    AND    hcsu.site_use_code = 'BILL_TO'
    AND    hcsu.status = 'A'
    AND    hcas.party_site_id = nvl(p_site_id, hcas.party_site_id)
    AND    hcsu.site_use_id = nvl(p_site_use_id, hcsu.site_use_id)
    AND    hca.cust_account_id = p_customer_id
    AND    hou.organization_id = nvl(hcas.org_id, hcsu.org_id)
    AND    hou.name = 'OBJET IL (OU)';
  
    IF x_region IS NOT NULL THEN
      RETURN;
    END IF;
  
    -- get user region
  
    SELECT ffv_dfv.region_code
    INTO   x_region
    FROM   fnd_flex_values_vl  ffvv,
           fnd_flex_values_dfv ffv_dfv,
           fnd_flex_value_sets t
    WHERE  ffvv.flex_value_set_id = t.flex_value_set_id
    AND    t.flex_value_set_name LIKE 'XXGL_COMPANY_SEG'
    AND    ffvv.enabled_flag = 'Y'
    AND    ffvv.end_date_active IS NULL
    AND    ffv_dfv.row_id = ffvv.row_id
    AND    to_char(flex_value) =
           (SELECT gcc.segment1
	 FROM   per_all_assignments_f pav,
	        gl_code_combinations  gcc,
	        fnd_user              u
	 WHERE  gcc.code_combination_id = pav.default_code_comb_id
	 AND    u.employee_id = pav.person_id
	 AND    SYSDATE BETWEEN
	        nvl(pav.effective_start_date, SYSDATE - 1) AND
	        nvl(pav.effective_end_date, SYSDATE + 1)
	 AND    u.user_id = p_user_id);
  
    IF x_region IS NULL THEN
      x_err_code := '1';
      x_err_msg  := 'No region is defined to requestor.';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in get_region: ' || SQLERRM;
  END get_region;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_credit_limit_fyi
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      21/07/2014
  --  Purpose :           get credit limit fyi list

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/07/2014    Michal Tzvik    initial build
  --  1.1   15/06/2015    Michal Tzvik    CHG0034590 -
  --                                      1. use "tag" instead of "meaning" field in lookup
  --                                      2. Handle case when credit limit is null.(should be approved by the lowest regional approver)
  --                                      3. If CI Decision amount is equal or greater than requested
  --                                         credit limit amount in USD, no need to send FYI notification
  -----------------------------------------------------------------------
  PROCEDURE get_credit_limit_fyi(p_doc_instance_id IN NUMBER,
		         x_err_code        OUT NUMBER,
		         x_err_msg         OUT VARCHAR2) IS
    l_user_id                  NUMBER;
    l_customer_id              NUMBER;
    l_site_id                  NUMBER;
    l_site_use_id              NUMBER;
    l_credit_limit             NUMBER;
    l_credit_limit_usd         NUMBER;
    l_region                   VARCHAR2(50);
    l_cust_acct_profile_amt_id NUMBER;
    l_new_currency_code        VARCHAR2(15);
  
    CURSOR c_fyi(p_credit_limit NUMBER,
	     p_region       VARCHAR2) IS
      SELECT MAX(fu.user_name) user_name -- currently WF support only one user for FYI notification
      FROM   fnd_lookup_values_vl  flv,
	 fnd_lookup_values_dfv flv_dfv,
	 fnd_user              fu
      WHERE  1 = 1
      AND    flv.lookup_type = 'XXAR_CREDIT_LIMIT_APPR_HIR'
      AND    flv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
	 nvl(flv.end_date_active, SYSDATE + 1)
      AND    flv.rowid = flv_dfv.row_id
      AND    fu.employee_id = flv_dfv.approver_name
      AND    p_credit_limit BETWEEN flv_dfv.from_credit_limit AND
	 flv_dfv.to_credit_limit
      AND    (flv.tag /*meaning*/
	LIKE 'FYI%' OR flv.tag /*meaning*/
	= p_region) -- 1.1   15/06/2015    Michal Tzvik
      AND    flv.lookup_code LIKE 'FYI%';
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    -- Get values of current doc instance
    SELECT xwdi.user_id,
           xwdi.attribute5,
           xwdi.n_attribute5,
           xwdi.attribute1,
           xwdi.n_attribute1,
           xwdi.n_attribute2,
           xwdi.n_attribute3
    INTO   l_user_id,
           l_credit_limit,
           l_cust_acct_profile_amt_id,
           l_new_currency_code,
           l_customer_id,
           l_site_id,
           l_site_use_id
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  xwdi.doc_instance_id = p_doc_instance_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code = c_cust_credit_limit;
  
    IF l_credit_limit IS NOT NULL THEN
      -- 1.1: run get_credit_limit_usd only if  l_credit_limit is not null
      get_credit_limit_usd(p_new_credit_limit  => l_credit_limit,
		   p_new_currency_code => l_new_currency_code,
		   x_usd_credit_limit  => l_credit_limit_usd,
		   x_err_code          => x_err_code,
		   x_err_msg           => x_err_msg);
    ELSE
      l_credit_limit_usd := 1; -- 1.1: this will cause to get lowest regional approver
    END IF;
  
    IF x_err_code != '0' THEN
      RETURN;
    END IF;
  
    -- 1.1  no need to send FYI notification if CI is graeter than credit limit
    IF get_credit_insurance_amount(l_cust_acct_profile_amt_id) >
       l_credit_limit_usd THEN
      x_err_msg  := '';
      x_err_code := '0';
      RETURN;
    END IF;
  
    get_region(p_user_id     => l_user_id,
	   p_customer_id => l_customer_id,
	   p_site_id     => l_site_id,
	   p_site_use_id => l_site_use_id,
	   x_region      => l_region,
	   x_err_code    => x_err_code,
	   x_err_msg     => x_err_msg);
  
    -- Get approver user name
    --if x_err_code = '0' then
    FOR r_fyi IN c_fyi(l_credit_limit_usd, l_region) LOOP
      -- x_fyi := x_fyi || ',' || r_fyi.user_name;
      x_err_msg := x_err_msg || ',' || r_fyi.user_name;
    END LOOP;
    --end if;
    x_err_msg := substr(x_err_msg, 2);
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := substr('get_credit_limit_fyi: ' || SQLERRM, 1, 50);
    
  END get_credit_limit_fyi;
  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_credit_limit_approver
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      21/07/2014
  --  Purpose :           get credit limit approver name

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/07/2014    Michal Tzvik    initial build
  --  1.1   15/06/2015    Michal Tzvik    CHG0034590 -
  --                                      1. Use "tag" instead of "meaning" field in lookup
  --                                      2. Handle case when credit limit is null.(should be approved by the lowest regional approver)
  --                                      3. If CI Decision amount is equal or greater than requested
  --                                         credit limit amount in USD, it should be automatically approved
  -----------------------------------------------------------------------
  PROCEDURE get_credit_limit_approver(p_doc_instance_id IN NUMBER,
			  x_approver        OUT VARCHAR2,
			  x_err_code        OUT NUMBER,
			  x_err_msg         OUT VARCHAR2) IS
    l_user_id                  NUMBER;
    l_requestor_person_id      NUMBER;
    l_customer_id              NUMBER;
    l_site_id                  NUMBER;
    l_site_use_id              NUMBER;
    l_credit_limit             NUMBER;
    l_credit_limit_usd         NUMBER;
    l_region                   VARCHAR2(50);
    l_cust_acct_profile_amt_id NUMBER;
    l_approver_person_id       NUMBER;
    l_new_currency_code        VARCHAR2(15);
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    -- Get values of current doc instance
    SELECT xwdi.user_id,
           xwdi.requestor_person_id,
           xwdi.attribute5,
           xwdi.n_attribute5,
           xwdi.attribute1,
           xwdi.n_attribute1,
           xwdi.n_attribute2,
           xwdi.n_attribute3
    INTO   l_user_id,
           l_requestor_person_id,
           l_credit_limit,
           l_cust_acct_profile_amt_id,
           l_new_currency_code,
           l_customer_id,
           l_site_id,
           l_site_use_id
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  xwdi.doc_instance_id = p_doc_instance_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code = c_cust_credit_limit;
  
    IF l_credit_limit IS NOT NULL THEN
      -- 1.1: run get_credit_limit_usd only if  l_credit_limit is not null
      get_credit_limit_usd(p_new_credit_limit  => l_credit_limit,
		   p_new_currency_code => l_new_currency_code,
		   x_usd_credit_limit  => l_credit_limit_usd,
		   x_err_code          => x_err_code,
		   x_err_msg           => x_err_msg);
    ELSE
      l_credit_limit_usd := 1; -- 1.1: this will cause getting the lowest regional approver
    END IF;
  
    IF x_err_code != '0' THEN
      RETURN;
    END IF;
  
    -- if CI is greter than credit limit, it should be approved automatically with
    -- an appropriate message.
    IF get_credit_insurance_amount(l_cust_acct_profile_amt_id) >=
       l_credit_limit_usd AND l_credit_limit IS NOT NULL THEN
      x_approver := '-2';
      UPDATE xxobjt_wf_doc_history h
      SET    h.note = fnd_message.get_string('XXOBJT',
			         'XXHZ_AUTO_APPR_CRDT_LMT_BY_CI')
      WHERE  h.doc_instance_id = p_doc_instance_id
      AND    h.seq_no =
	 (SELECT MAX(h1.seq_no)
	   FROM   xxobjt_wf_doc_history h1
	   WHERE  h1.doc_instance_id = h.doc_instance_id);
      COMMIT;
      RETURN;
    END IF;
  
    get_region(p_user_id     => l_user_id,
	   p_customer_id => l_customer_id,
	   p_site_id     => l_site_id,
	   p_site_use_id => l_site_use_id,
	   x_region      => l_region,
	   x_err_code    => x_err_code,
	   x_err_msg     => x_err_msg);
  
    -- Get approver user name
    SELECT fu.user_name,
           fu.employee_id
    INTO   x_approver,
           l_approver_person_id
    FROM   fnd_lookup_values_vl  flv,
           fnd_lookup_values_dfv flv_dfv,
           fnd_user              fu
    WHERE  1 = 1
    AND    flv.lookup_type = 'XXAR_CREDIT_LIMIT_APPR_HIR'
    AND    flv.enabled_flag = 'Y'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    flv.rowid = flv_dfv.row_id
    AND    fu.employee_id = decode(flv_dfv.approver_name,
		           l_requestor_person_id,
		           flv_dfv.alternate_approver,
		           flv_dfv.approver_name)
    AND    l_credit_limit_usd BETWEEN flv_dfv.from_credit_limit AND
           flv_dfv.to_credit_limit
    AND    (flv.tag /*meaning*/
          = c_corporate OR flv.tag /*meaning*/
          = l_region) -- 1.1 replace meanning with tag
    AND    flv.lookup_code NOT LIKE 'FYI%';
  
    IF x_approver IS NULL THEN
      x_err_code := '1';
      x_err_msg  := 'Error: no approver is defined to credit limit update.';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in get_credit_limit_approver: ' ||
	        SQLERRM;
  END get_credit_limit_approver;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_payment_term_approver
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      21/07/2014
  --  Purpose :           get payment term approver name

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/07/2014    Michal Tzvik    initial build
  --  1.1   15/06/2015    Michal Tzvik    CHG0034590 - use "tag" instead of "meaning" field in lookup
  -----------------------------------------------------------------------
  PROCEDURE get_payment_term_approver(p_doc_instance_id IN NUMBER,
			  x_approver        OUT VARCHAR2,
			  x_err_code        OUT NUMBER,
			  x_err_msg         OUT VARCHAR2) IS
    l_region              VARCHAR2(50);
    l_user_id             NUMBER;
    l_requestor_person_id NUMBER;
    l_customer_id         NUMBER;
    l_site_id             NUMBER;
    l_site_use_id         NUMBER;
    l_period_length       NUMBER;
    l_approver_person_id  NUMBER;
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    -- Get values of current doc instance
    SELECT xwdi.user_id,
           xwdi.requestor_person_id,
           xxhz_cust_apr_util_pkg.get_period_length(xwdi.attribute5),
           xwdi.n_attribute1,
           xwdi.n_attribute2,
           xwdi.n_attribute3
    INTO   l_user_id,
           l_requestor_person_id,
           l_period_length,
           l_customer_id,
           l_site_id,
           l_site_use_id
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  xwdi.doc_instance_id = p_doc_instance_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code = c_cust_pay_term;
  
    get_region(p_user_id     => l_user_id,
	   p_customer_id => l_customer_id,
	   p_site_id     => l_site_id,
	   p_site_use_id => l_site_use_id,
	   x_region      => l_region,
	   x_err_code    => x_err_code,
	   x_err_msg     => x_err_msg);
  
    -- Get approver user name
    SELECT fu.user_name,
           fu.employee_id
    INTO   x_approver,
           l_approver_person_id
    FROM   fnd_lookup_values_vl  flv,
           fnd_lookup_values_dfv flv_dfv,
           fnd_user              fu
    WHERE  1 = 1
    AND    flv.lookup_type = 'XXAR_PAY_TERM_APPR_HIR'
    AND    flv.enabled_flag = 'Y'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    (flv.tag /*meaning*/
          = c_corporate OR flv.tag /*meaning*/
          = l_region) -- 1.1   15/06/2015    Michal Tzvik
    AND    flv.rowid = flv_dfv.row_id
    AND    fu.employee_id = decode(flv_dfv.approver_name,
		           l_requestor_person_id,
		           flv_dfv.alternate_approver,
		           flv_dfv.approver_name)
    AND    l_period_length BETWEEN flv_dfv.from_period_length AND
           flv_dfv.to_period_length
    AND    flv.lookup_code NOT LIKE 'FYI%';
  
    IF x_approver IS NULL THEN
      x_err_code := '1';
      x_err_msg  := 'Error: no approver is defined to payment term update.';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in get_payment_term_approver: ' ||
	        SQLERRM;
  END get_payment_term_approver;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_credit_ch_hold_approver
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      21/07/2014
  --  Purpose :           get credit check / credit hold approver name

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/07/2014    Michal Tzvik    initial build
  --  1.1   15/06/2015    Michal Tzvik    CHG0034590 - use "tag" instead of "meaning" field in lookup
  -----------------------------------------------------------------------
  PROCEDURE get_credit_ch_hold_approver(p_doc_instance_id IN NUMBER,
			    x_approver        OUT VARCHAR2,
			    x_err_code        OUT NUMBER,
			    x_err_msg         OUT VARCHAR2) IS
    l_region              VARCHAR2(50);
    l_user_id             NUMBER;
    l_requestor_person_id NUMBER;
    l_customer_id         NUMBER;
    l_site_id             NUMBER;
    l_site_use_id         NUMBER;
    l_approver_person_id  NUMBER;
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    -- Get values of current doc instance
    SELECT xwdi.user_id,
           xwdi.requestor_person_id,
           xwdi.n_attribute1,
           xwdi.n_attribute2,
           xwdi.n_attribute3
    INTO   l_user_id,
           l_requestor_person_id,
           l_customer_id,
           l_site_id,
           l_site_use_id
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  xwdi.doc_instance_id = p_doc_instance_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code IN (c_cust_credit_hold, c_cust_credit_chk);
  
    get_region(p_user_id     => l_user_id,
	   p_customer_id => l_customer_id,
	   p_site_id     => l_site_id,
	   p_site_use_id => l_site_use_id,
	   x_region      => l_region,
	   x_err_code    => x_err_code,
	   x_err_msg     => x_err_msg);
  
    IF x_err_code != '0' THEN
      RETURN;
    ELSE
      -- Get approver user name
      SELECT fu.user_name,
	 fu.employee_id
      INTO   x_approver,
	 l_approver_person_id
      FROM   fnd_lookup_values_vl  flv,
	 fnd_lookup_values_dfv flv_dfv,
	 fnd_user              fu
      WHERE  1 = 1
      AND    flv.lookup_type = 'XXAR_CREDIT_CH_HOLD_APPR_HIR'
      AND    flv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
	 nvl(flv.end_date_active, SYSDATE + 1)
      AND    flv.tag /*meaning*/
	= l_region -- 1.1   15/06/2015    Michal Tzvik
      AND    flv.rowid = flv_dfv.row_id
      AND    fu.employee_id =
	 decode(flv_dfv.approver_name,
	         l_requestor_person_id,
	         flv_dfv.alternate_approver,
	         flv_dfv.approver_name)
      AND    flv.lookup_code NOT LIKE 'FYI%';
    
    END IF;
  
    IF x_approver IS NULL THEN
      x_err_code := '1';
      x_err_msg  := 'Error: no approver is defined to credit hold / credit check update.';
    END IF;
  EXCEPTION
  
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in get_credit_ch_hold_approver: ' ||
	        SQLERRM;
  END get_credit_ch_hold_approver;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_party_name
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      07/01/2015
  --  Purpose :           get party name of current doc_instance_id.
  --                      used for notificstion subject in setup form
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/01/2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_party_name(p_doc_instance_id NUMBER) RETURN VARCHAR2 IS
    l_party_name hz_parties.party_name%TYPE;
  BEGIN
    SELECT hp.party_name
    INTO   l_party_name
    FROM   xxobjt_wf_doc_instance xwdi,
           hz_cust_accounts       hca,
           hz_cust_acct_sites_all hcas,
           hz_cust_site_uses_all  hcsu,
           hz_parties             hp
    WHERE  xwdi.doc_instance_id = p_doc_instance_id
    AND    hca.cust_account_id(+) = xwdi.n_attribute1
    AND    hcas.party_site_id(+) = xwdi.n_attribute2
    AND    hcas.org_id(+) = xwdi.attribute6
    AND    hcsu.site_use_id(+) = xwdi.n_attribute3
    AND    hp.party_id(+) = hca.party_id;
  
    RETURN l_party_name;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_party_name;
END xxhz_cust_apr_util_pkg;
/
