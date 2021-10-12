CREATE OR REPLACE PACKAGE BODY xxhz_ecomm_event_pkg AS
  --------------------------------------------------------------------------------------------------------
  --  name:            xxhz_ecomm_event_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   11/06/2015
  --------------------------------------------------------------------------------------------------------
  --  purpose :  This package is used to generate events for customer and customer printer interface
  ---------------------------------------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/06/2015  Debarati Banerjee            CHG0035649 - initial build
  --       07/07/2015  Kundan Bhagat                CHG0035650 - Initial Build
  --  1.1  28/10/2015  Debarati banerjee            CHG0036659 - Adjust Ecommerce customer master interface
  --                                                Updated Function - is_ecomm_contact
  --                                                Updated Procedure - handle_account,handle_site,handle_contact
  --                                                Added Procedure   - handle_org_update
  --  1.2  26/11/2015  Kundan Bhagat                CHG0036749 -Adjust Ecommerce customer printer interface
  --                                                to send end customer printers
  --                                                Updated Procedure - customer_printer_process
  --       25/01/2016  Kundan Bhagat                CHG0036749 - Commented code related to cur_inactive_rec cursor
  --                                                to resolve performance issue.
  --  1.3  09/25/2015  Diptasurjya Chatterjee       CHG0036450 : Reseller changes
  --  1.4  08/18/2016  Tagore Sathuluri                                 CHG0036450 : Reseller changes
  --  1.5  22/12/2016  Tagore Sathuluri                                 CHG0039473 : Modified code to sync the site and contact information
  --  1.6  25/05/2017  yuval tal                    CHG0040839   modify customer_printer_process Add s/n information and printers which exist for ecom related customers
  --  1.7  07/07/2017  Diptasurjya                  INC0096393 - Pass DB trigger mode parameter to handle contact
  --  1.8  09/14/2017  Diptasurjya Chatterjee       INC0099805 - Events getting generated even though relationship is inactive
  --  1.9  09/17/2017  Diptasurjya Chatterjee       INC0102454 - Related account events not generated when new site is added to non-ecom related
  --                                                customer
  --  2.0  10/18/2017  Diptasurjya Chatterjee       INC0104197 - Variable l_related_cont_role size is low in handle_acct_relationship causing errors
  --                                                if contact has more than 2 roles
  --  2.1  21.1.18     Yuval Tal                    INC0112306  - modify is_account_related_to_ecom : rollback INC0099805
  --  3.0  05/08/2018  Diptasurjya                  CHG0042626 - Change in customer entity event generation and message preparation
  --                                                logic
  --  3.1  12/12/2018  Diptasurjya                  CHG0043798 - Change the procedures handle_contact_new, handle_site_new,
  --                                                handle_account_new and handle_acct_relationship_new to call the send_mail
  --                                                and process_event from exception block in autonomous mode
  --                                                Change the query in procedure generate_contact_data to remove usage of
  --                                                tables hz_party_sites, hz_location and fnd_territories
  --
  -- 4.0   28.3.19    Yuval tal                     INC0152106  - modify customer_printer_process
  ---------------------------------------------------------------------------------------------------------

  g_target_name               VARCHAR2(10) := 'HYBRIS';
  g_account_entity_name       VARCHAR2(10) := 'ACCOUNT';
  g_site_entity_name          VARCHAR2(10) := 'SITE';
  g_contact_entity_name       VARCHAR2(10) := 'CONTACT';
  g_printer_entity_name       VARCHAR2(20) := 'CUST_PRINT';
  g_acct_relation_entity_name VARCHAR2(10) := 'ACCT_REL'; -- CHG0036450 -- Dipta
  g_user_id                   NUMBER := 0;
  g_resp_id                   NUMBER := 0;
  g_appl_id                   NUMBER := 0;
  g_eventname                 VARCHAR2(1000);
  g_account_number            VARCHAR2(100);
  g_time                      DATE;

  g_event_rec xxssys_events%ROWTYPE;

  /*PROCEDURE writelog(p_msg IN VARCHAR2) IS
    pragma autonomous_transaction;
  BEGIN
    insert into xxdctest values (p_msg);
    commit;
  END writelog;*/

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This Procedure is used to send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  22/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail(p_program_name_to IN VARCHAR2,
	          p_program_name_cc IN VARCHAR2,
	          p_entity          IN VARCHAR2,
	          p_body            IN VARCHAR2,
	          p_api_phase       IN VARCHAR2 DEFAULT NULL) IS
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);
  
    l_api_phase VARCHAR2(240) := 'event processor';
  BEGIN
    IF p_api_phase IS NOT NULL THEN
      l_api_phase := p_api_phase;
    END IF;
  
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_to);
  
    l_mail_cc_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_cc);
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
		          p_cc_mail     => l_mail_cc_list,
		          p_subject     => 'eStore unexpected error in Oracle ' ||
				   l_api_phase || ' for - ' ||
				   p_entity,
		          p_body_text   => p_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_err_msg);
  
  END send_mail;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043798
  --          This Procedure is used to send Mail for errors and is called in autonomous transaction mode
  --          This will allow it to be called from business event rule functions exception block,
  --          and not cause the BE system to throw error due to commit being performed with the send_mail procedure
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  12/12/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail_autonomous(pa_program_name_to IN VARCHAR2,
		         pa_program_name_cc IN VARCHAR2,
		         pa_entity          IN VARCHAR2,
		         pa_body            IN VARCHAR2,
		         pa_api_phase       IN VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    send_mail(p_program_name_to => pa_program_name_to,
	  p_program_name_cc => pa_program_name_cc,
	  p_entity          => pa_entity,
	  p_body            => pa_body,
	  p_api_phase       => pa_api_phase);
  END send_mail_autonomous;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This Procedure is used to generate current time
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------
  /*FUNCTION extract_time RETURN DATE IS
  
    l_date DATE;
  
  BEGIN
    SELECT SYSDATE
    INTO   l_date
    FROM   dual;
    RETURN l_date;
  END;*/

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This Procedure is used to fetch account_number
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_accnt_num(p_cust_accnt_id NUMBER) RETURN VARCHAR2 IS
  
    l_acc_no VARCHAR2(100);
  
  BEGIN
    SELECT account_number
    INTO   l_acc_no
    FROM   hz_cust_accounts
    WHERE  cust_account_id = p_cust_accnt_id;
  
    RETURN l_acc_no;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This Procedure is used to fetch site_name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_site_name(p_site_use_id NUMBER) RETURN VARCHAR2 IS
  
    l_site_name VARCHAR2(1000);
  
  BEGIN
    SELECT hps.party_site_name
    INTO   l_site_name
    FROM   hz_cust_accounts       hca,
           hz_party_sites         hps,
           hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hps.party_id = hca.party_id
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hca.cust_account_id = hcasa.cust_account_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcsua.site_use_id = p_site_use_id;
  
    RETURN l_site_name;
  END fetch_site_name;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This Procedure is used to fetch contact_name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_contact_name(p_contact_id NUMBER) RETURN VARCHAR2 IS
  
    l_contact_name VARCHAR2(2000);
  
  BEGIN
  
    SELECT hp_contact.person_pre_name_adjunct || ' ' ||
           hp_contact.person_first_name || ' ' ||
           hp_contact.person_last_name contact_name
    INTO   l_contact_name
    FROM   hz_cust_accounts      hca,
           hz_cust_account_roles hcar,
           hz_relationships      hr,
           hz_parties            hp_contact,
           hz_parties            hp_cust,
           hz_org_contacts       hoc
    WHERE  hp_cust.party_id = hca.party_id
    AND    hca.cust_account_id = hcar.cust_account_id
    AND    hcar.role_type = 'CONTACT'
    AND    hcar.cust_acct_site_id IS NULL
    AND    hcar.party_id = hr.party_id
    AND    hr.subject_type = 'PERSON'
    AND    hr.subject_id = hp_contact.party_id
    AND    hoc.party_relationship_id = hr.relationship_id
    AND    hcar.cust_account_role_id =
           nvl(p_contact_id, hcar.cust_account_role_id);
    RETURN l_contact_name;
  END fetch_contact_name;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This Procedure is used to fetch contact_name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                         Description
  -- 1.0  08/05/2018  Diptasurjya Chatterjee       Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_pricelist_id(p_cust_account_id NUMBER,
		      p_org_id          NUMBER) RETURN NUMBER IS
  
    l_list_header_id NUMBER;
  
  BEGIN
    BEGIN
      SELECT hcsua.price_list_id
      INTO   l_list_header_id
      FROM   hz_cust_site_uses_all  hcsua,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_accounts       hca
      WHERE  hcasa.org_id = p_org_id
      AND    hcsua.org_id = hcasa.org_id
      AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
      AND    hcsua.site_use_code IN ('BILL_TO')
      AND    hcsua.primary_flag = 'Y'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hps.party_id = hca.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    p_cust_account_id = hca.cust_account_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_list_header_id := NULL;
    END;
  
    IF l_list_header_id IS NULL THEN
      SELECT hca.price_list_id
      INTO   l_list_header_id
      FROM   hz_cust_accounts hca
      WHERE  cust_account_id = p_cust_account_id;
    END IF;
  
    RETURN l_list_header_id;
  END fetch_pricelist_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure checks if email address of contacts are unique
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  05/14/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE check_email_address(p_cust_contact_id       IN NUMBER,
		        p_email_duplicate_check IN VARCHAR2,
		        x_status                OUT VARCHAR2,
		        x_status_message        OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_status         VARCHAR2(1) := 'Y';
    l_status_message VARCHAR2(4000);
  
    l_contact_number VARCHAR2(30);
    l_account_number VARCHAR2(30);
    l_contact_email  VARCHAR2(2000);
  
    l_dup_email xxhz_email_tab;
  
    l_email_cnt NUMBER;
  BEGIN
    BEGIN
      SELECT upper(xecpv.email_address),
	 hoc.contact_number,
	 hca_ecomm.account_number
      INTO   l_contact_email,
	 l_contact_number,
	 l_account_number
      FROM   hz_cust_accounts           hca_ecomm,
	 hz_cust_account_roles      hcar_ecomm,
	 hz_relationships           hr_ecomm,
	 hz_parties                 hp_contact_ecomm,
	 hz_parties                 hp_cust_ecomm,
	 hz_party_sites             hps_ecomm,
	 hz_org_contacts            hoc,
	 xxhz_email_contact_point_v xecpv
      WHERE  hp_cust_ecomm.party_id = hca_ecomm.party_id
      AND    hps_ecomm.party_id(+) = hcar_ecomm.party_id
      AND    nvl(hps_ecomm.identifying_address_flag, 'Y') = 'Y'
      AND    hca_ecomm.cust_account_id = hcar_ecomm.cust_account_id
      AND    hcar_ecomm.role_type = 'CONTACT'
      AND    hcar_ecomm.cust_acct_site_id IS NULL
      AND    hcar_ecomm.party_id = hr_ecomm.party_id
      AND    hr_ecomm.subject_type = 'PERSON'
      AND    hr_ecomm.subject_id = hp_contact_ecomm.party_id
      AND    hp_contact_ecomm.status = 'A'
      AND    hp_cust_ecomm.status = 'A'
      AND    hcar_ecomm.status = 'A'
      AND    hca_ecomm.status = 'A'
      AND    nvl(hps_ecomm.status, 'A') = 'A'
	--AND    hcar_ecomm.attribute3 = 'Y'
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    hoc.party_relationship_id = hr_ecomm.relationship_id
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hcar_ecomm.cust_account_role_id = p_cust_contact_id
      AND    xecpv.status(+) = 'A';
    EXCEPTION
      WHEN no_data_found THEN
        -- No valid ecommerce contact exists for provided contact ID. Hence returning response as success
        x_status := 'Y';
        --x_status_message := 'VALIDATION ERROR : Email address could not be determined for ecommerce contact ID: '||p_cust_contact_id;
        RETURN;
    END;
  
    IF l_contact_email IS NULL THEN
      x_status         := 'N';
      x_status_message := 'VALIDATION ERROR : Email address not defined for eCommerce contact number: ' ||
		  p_cust_contact_id || ' (Account # ' ||
		  l_account_number || ')';
      RETURN;
    END IF;
  
    IF p_email_duplicate_check = 'Y' THEN
      SELECT COUNT(1)
      INTO   l_email_cnt
      FROM   hz_contact_points
      WHERE  status = 'A'
      AND    contact_point_type = 'EMAIL'
      AND    owner_table_name = 'HZ_PARTIES'
      AND    upper(email_address) = l_contact_email;
    
      IF l_email_cnt > 1 THEN
        BEGIN
          SELECT hca_ecomm.cust_account_id,
	     hca_ecomm.account_number,
	     hp_contact_ecomm.person_pre_name_adjunct,
	     hp_contact_ecomm.person_last_name,
	     hp_contact_ecomm.person_first_name,
	     xecpv.email_address,
	     hcar_ecomm.cust_account_role_id
          BULK   COLLECT
          INTO   l_dup_email
          FROM   hz_cust_accounts      hca_ecomm,
	     hz_cust_account_roles hcar_ecomm,
	     hz_relationships      hr_ecomm,
	     hz_parties            hp_contact_ecomm,
	     hz_parties            hp_cust_ecomm,
	     --hz_party_sites             hps_ecomm,
	     hz_org_contacts            hoc,
	     xxhz_email_contact_point_v xecpv
          WHERE  hp_cust_ecomm.party_id = hca_ecomm.party_id
	    --AND    hps_ecomm.party_id = hcar_ecomm.party_id
	    --AND    nvl(hps_ecomm.identifying_address_flag, 'Y') = 'Y'
          AND    hca_ecomm.cust_account_id = hcar_ecomm.cust_account_id
          AND    hcar_ecomm.role_type = 'CONTACT'
          AND    hcar_ecomm.cust_acct_site_id IS NULL
          AND    hcar_ecomm.party_id = hr_ecomm.party_id
          AND    hr_ecomm.subject_type = 'PERSON'
          AND    hr_ecomm.subject_id = hp_contact_ecomm.party_id
          AND    hp_contact_ecomm.status = 'A'
          AND    hp_cust_ecomm.status = 'A'
          AND    hcar_ecomm.status = 'A'
          AND    hca_ecomm.status = 'A'
	    --AND    nvl(hps_ecomm.status, 'A') = 'A'
          AND    hcar_ecomm.attribute3 = 'Y'
          AND    hoc.party_relationship_id = hr_ecomm.relationship_id
          AND    hcar_ecomm.party_id = xecpv.owner_table_id
          AND    xecpv.contact_point_type = 'EMAIL'
          AND    xecpv.email_rownum = 1
          AND    upper(xecpv.email_address) = l_contact_email
          AND    hcar_ecomm.cust_account_role_id <> p_cust_contact_id
          AND    xecpv.status = 'A';
        
        EXCEPTION
          WHEN no_data_found THEN
	NULL;
        END;
      
        FOR k IN 1 .. l_dup_email.count LOOP
          l_status_message := l_status_message ||
		      'VALIDATION ERROR : Same email address exists for contacts: ' ||
		      chr(10);
          l_status_message := l_status_message || l_dup_email(k)
		     .person_first_name || ' ' || l_dup_email(k)
		     .person_last_name || '-' || '(AC# ' || l_dup_email(k)
		     .account_number || 'Contact reference# ' || l_dup_email(k)
		     .cust_account_role_id || ')' || chr(10);
          l_status         := 'N';
        END LOOP;
      ELSE
        l_status := 'Y';
      END IF;
    
      IF l_status = 'N' THEN
        x_status         := 'N';
        x_status_message := l_status_message;
      ELSE
        x_status := 'Y';
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'N';
      x_status_message := 'UNEXPECTED ERROR: While email validation: ' ||
		  SQLERRM;
  END check_email_address;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure checks if OU dff is defined for ecomm contact
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  05/14/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE check_contact_ou(p_cust_contact_id IN NUMBER,
		     x_status          OUT VARCHAR2,
		     x_status_message  OUT VARCHAR2) IS
  
    l_status         VARCHAR2(1) := 'Y';
    l_status_message VARCHAR2(4000);
  
    l_contact_reference NUMBER;
    l_account_number    VARCHAR2(30);
    l_contact_ou        VARCHAR2(240);
    l_contact_ecom      VARCHAR2(240);
  
    l_contact_name VARCHAR2(4000);
  
  BEGIN
    SELECT hca.account_number,
           hcar.cust_account_role_id,
           hcard.ecommerce,
           hcard.ecommerce_ou
    INTO   l_account_number,
           l_contact_reference,
           l_contact_ecom,
           l_contact_ou
    FROM   hz_cust_account_roles     hcar,
           hz_cust_account_roles_dfv hcard,
           hz_cust_accounts          hca
    WHERE  hcar.cust_account_role_id = p_cust_contact_id
    AND    hcar.cust_account_id = hca.cust_account_id
    AND    hcar.rowid = hcard.row_id;
  
    IF l_contact_ecom = 'Y' AND l_contact_ou IS NULL THEN
      x_status         := 'N';
      x_status_message := 'VALIDATION ERROR: eCommerce Operating Unit DFF must be provided for contact having reference# ' ||
		  l_contact_reference || ' (account# ' ||
		  l_account_number || ')';
    
      l_contact_name := fetch_contact_name(p_cust_contact_id);
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface',
	    'The following unexpected exception occurred for Customer interface event processor.' ||
	    chr(13) || chr(10) ||
	    'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Contact ID: ' || p_cust_contact_id ||
	    chr(13) || chr(10) || '  Contact Name: ' || l_contact_name ||
	    chr(13) || chr(10) || '  Error: UNEXPECTED: ' ||
	    x_status_message || chr(13) || chr(10) || '  Error Time: ' ||
	    SYSDATE);
    ELSE
      x_status := 'Y';
    END IF;
  
  END check_contact_ou;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to check if contact is ecom contact.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  28/10/2015  Debarati banerjee                  CHG0036659 : Added logic to identify an
  --                                                     ecommerce contact based on current DFF setup
  -- -----------------------------------------------------------------------------------------------
  FUNCTION is_ecomm_contact(p_contact_id NUMBER) RETURN VARCHAR2 IS
  
    l_ecom      NUMBER := 0;
    l_ecom_cust VARCHAR2(10);
  
  BEGIN
    SELECT COUNT(*)
    INTO   l_ecom
    FROM   hz_relationships      hr,
           hz_cust_accounts      hca,
           hz_cust_account_roles hcar
    WHERE  hcar.cust_account_role_id = p_contact_id
    AND    hr.subject_type = 'ORGANIZATION'
    AND    hr.subject_id = hca.party_id
    AND    hcar.role_type = 'CONTACT'
    AND    hcar.party_id = hr.party_id
    AND    hcar.cust_acct_site_id IS NULL
    AND    hcar.attribute3 = 'Y';
  
    IF l_ecom > 0 THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END is_ecomm_contact;

  -- Start Go-Live 3 Relation
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035640
  --          This function is used to check if an account exists in relationship
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             Initial Build
  -- 1.1  09/14/2017  Diptasurjya Chatterjee             INC0099805 - Status of relationship not checked
  --1.2   21.1.18     Yuval Tal                           INC0112306  - modify is_account_related_to_ecom : rollback INC0099805
  -- -----------------------------------------------------------------------------
  FUNCTION is_account_related_to_ecom(p_cust_account_id NUMBER)
    RETURN VARCHAR2 IS
  
    l_ecom_cust VARCHAR2(10);
  
    CURSOR cur_relate_exists IS
      SELECT related_cust_account_id
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.cust_account_id = p_cust_account_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hou
	  WHERE  hou.organization_id = hcara.org_id
	  AND    hou.attribute7 = 'Y')
      AND    hcara.ship_to_flag = 'Y';
    --  AND  hcara.status = 'A'; -- INC0099805
  
  BEGIN
    FOR rec_relate_exists IN cur_relate_exists LOOP
      l_ecom_cust := xxhz_util.is_ecomm_customer(rec_relate_exists.related_cust_account_id);
    
      IF l_ecom_cust = 'TRUE' THEN
        RETURN 'TRUE';
      END IF;
    END LOOP;
  
    RETURN 'FALSE';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'FALSE';
  END is_account_related_to_ecom;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035640
  --          This function is used to check if an account exists in relationship
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             Initial Build
  -- 1.1  09/14/2017  Diptasurjya Chatterjee             INC0099805 - Status of relationship not checked
  --1.2   21.1.18     Yuval Tal                           INC0112306  - modify is_account_related_to_ecom : rollback INC0099805
  -- -----------------------------------------------------------------------------
  FUNCTION is_account_being_reactivated(p_cust_account_id NUMBER)
    RETURN VARCHAR2 IS
    l_account_status_current  VARCHAR2(1);
    l_account_status_previous VARCHAR2(1);
  BEGIN
    SELECT status
    INTO   l_account_status_current
    FROM   hz_cust_accounts
    WHERE  cust_account_id = p_cust_account_id;
  
    BEGIN
      SELECT xmltype(xe.event_message).extract('//CUSTOMER_STATUS/text()')
	 .getstringval()
      INTO   l_account_status_previous
      FROM   (SELECT xe2.event_id,
	         xe2.event_message
	  FROM   (SELECT xe1.event_id,
		     xe1.event_message,
		     rank() over(PARTITION BY xe1.entity_id, xe1.entity_name, xe1.target_name ORDER BY xe1.event_id DESC) rn
	          FROM   xxssys_events xe1
	          WHERE  status = 'SUCCESS'
	          AND    entity_id = p_cust_account_id
	          AND    entity_name = 'ACCOUNT'
	          AND    target_name = 'HYBRIS') xe2
	  WHERE  xe2.rn = 1) xe;
    EXCEPTION
      WHEN no_data_found THEN
        l_account_status_previous := NULL;
    END;
  
    IF l_account_status_current = 'A' AND l_account_status_previous = 'I' THEN
      RETURN 'TRUE';
    END IF;
  
    RETURN 'FALSE';
  END is_account_being_reactivated;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the account information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  28/10/2015  Debarati banerjee                  CHG0036659 : Include logic to derive OU
  -- 1.2  09/25/2015  Diptasurjya Chatterjee             CHG0036450 : Reseller changes. Add
  --                                                     seperate section to handle non-ecom account changes which are related to ecom accounts
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_account(p_cust_account_id IN NUMBER) IS
  
    l_ecom_cust_flag   VARCHAR2(10);
    l_related_to_ecom  VARCHAR2(10); -- Start Go-Live 3 Relation
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    /*CURSOR cur_valid_ou IS
    SELECT hro.organization_id org_id
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y';*/
  
    CURSOR cur_ou IS
      SELECT DISTINCT hca.cust_account_id cust_account_id,
	          --hcsua.site_use_id   site_id,
	          hcasa.org_id org_id
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua
      WHERE  hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hp.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hca.status = 'A'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hcasa.org_id IN
	 (SELECT hro.organization_id
	   FROM   hr_operating_units    hro,
	          hr_organization_units hru
	   WHERE  hro.organization_id = hru.organization_id
	   AND    hru.attribute7 = 'Y')
      AND    hca.cust_account_id = p_cust_account_id;
  
    l_org_id NUMBER := 0;
  
  BEGIN
  
    l_ecom_cust_flag  := xxhz_util.is_ecomm_customer(p_cust_account_id);
    l_related_to_ecom := is_account_related_to_ecom(p_cust_account_id); -- Start Go-Live 3 Relation
  
    l_xxssys_event_rec.target_name := g_target_name;
    l_xxssys_event_rec.entity_name := g_account_entity_name;
    l_xxssys_event_rec.entity_id   := p_cust_account_id;
    --l_xxssys_event_rec.attribute1  := p_cust_account_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
  
    IF l_ecom_cust_flag = 'TRUE' THEN
      l_xxssys_event_rec.active_flag := 'Y';
      xxssys_event_pkg.write_log('Handle Account: ' || p_cust_account_id);
      FOR i IN cur_ou LOOP
        xxssys_event_pkg.write_log('OU : ' || i.org_id);
        l_xxssys_event_rec.attribute1 := i.org_id;
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      END LOOP;
      -- Start Go-Live 3 Relation
    ELSIF l_related_to_ecom = 'TRUE' THEN
      -- Non-Ecom customer related to ecom customer
      l_xxssys_event_rec.active_flag := 'Y';
      xxssys_event_pkg.write_log('Handle Account: ' || p_cust_account_id);
      FOR i IN cur_ou LOOP
        xxssys_event_pkg.write_log('OU : ' || i.org_id);
        l_xxssys_event_rec.attribute1 := i.org_id;
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      END LOOP;
      -- End Go-Live 3 Relation
    ELSE
      l_xxssys_event_rec.active_flag := 'N';
      xxssys_event_pkg.write_log('Handle Account: ' || p_cust_account_id);
      FOR i IN cur_ou LOOP
        xxssys_event_pkg.write_log('OU : ' || i.org_id);
        l_xxssys_event_rec.attribute1 := i.org_id;
        -- check if sync is the past
        IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
          xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        END IF;
      END LOOP;
    
      -- END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      g_account_number := fetch_accnt_num(l_xxssys_event_rec.entity_id);
      g_time           := SYSDATE;
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface',
	    'The following unexpected exception occurred for Customer interface event processor.' ||
	    chr(13) || chr(10) ||
	    'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Account ID: ' ||
	    l_xxssys_event_rec.entity_id || chr(13) || chr(10) ||
	    '  Account Number : ' || g_account_number || chr(13) ||
	    chr(10) || '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
	    chr(10) || '  Error Time: ' || g_time);
    
  END handle_account;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Site information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  25/10/2015  Debarati Banerjee                  CHG0036659 - Modified cursor cur_site_id to include
  --                                                     only ship to and bill to sites
  -- 1.2  09/25/2015  Diptasurjya Chatterjee             CHG0036450 : Reseller changes. Add seperate condition to handle
  --                                                     site add/updates for non-ecom accounts having related ecomm accounts
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_site(p_site_use_id IN NUMBER) IS
  
    l_ecom_cust_flag         VARCHAR2(10);
    l_related_to_ecom        VARCHAR2(10); -- Start Go-Live 3 Relation
    l_ecom_related_cust_flag VARCHAR2(10);
    l_xxssys_event_rec       xxssys_events%ROWTYPE;
    l_site_name              VARCHAR2(1000);
  
    l_nonecom_site_use VARCHAR2(10);
  
    CURSOR cur_site_id IS
      SELECT hca.cust_account_id cust_account_id
      FROM   hz_locations           hl,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua,
	 hz_cust_accounts       hca,
	 hz_parties             hp
      WHERE  hcsua.site_use_id = p_site_use_id
      AND    hca.party_id = hp.party_id
      AND    hp.party_id = hps.party_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcasa.org_id
	  AND    hru.attribute7 = 'Y')
      AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id;
  
    CURSOR cur_related_site(p_cust_account_id IN NUMBER) IS
      SELECT hcara.cust_account_id         cust_account_id,
	 hcara.related_cust_account_id rel_cust_account_id
      FROM   hz_cust_acct_relate_all hcara,
	 hz_cust_accounts        hca,
	 hz_party_sites          hps,
	 hz_cust_acct_sites_all  hcasa,
	 hz_cust_site_uses_all   hcsua
      --hz_parties              hp,
      --hz_locations            hl,
      --fnd_territories_vl      ftv
      WHERE  hca.cust_account_id = hcara.cust_account_id
	--AND    hca.party_id = hp.party_id
	--AND    hps.party_id = hp.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcsua.site_use_code IN ('SHIP_TO')
      AND    hcasa.org_id = hcsua.org_id
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
	--AND    hps.location_id = hl.location_id
	--AND    hl.country = ftv.territory_code(+)
	--AND    hp.status = 'A'
      AND    hca.status = 'A'
	--AND    hcara.status = 'A'
	/*AND    hcsua.status = 'A'
            AND    hcasa.status = 'A'
            AND    nvl(hps.status, 'A') = 'A'*/
      AND    hcara.ship_to_flag = 'Y'
      AND    hcasa.org_id IN
	 (SELECT hro.organization_id
	   FROM   hr_operating_units    hro,
	          hr_organization_units hru
	   WHERE  hro.organization_id = hru.organization_id
	   AND    hru.attribute7 = 'Y')
      AND    hcara.org_id IN
	 (SELECT hro.organization_id
	   FROM   hr_operating_units    hro,
	          hr_organization_units hru
	   WHERE  hro.organization_id = hru.organization_id
	   AND    hru.attribute7 = 'Y')
      AND    hcsua.site_use_id = p_site_use_id
      AND    hcara.cust_account_id = p_cust_account_id;
  
  BEGIN
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_site_entity_name;
    l_xxssys_event_rec.entity_id       := p_site_use_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
  
    FOR i IN cur_site_id LOOP
      l_xxssys_event_rec.attribute1 := i.cust_account_id;
      l_ecom_cust_flag              := xxhz_util.is_ecomm_customer(i.cust_account_id);
      l_related_to_ecom             := is_account_related_to_ecom(i.cust_account_id); -- Start Go-Live 3 Relation
    
      IF l_ecom_cust_flag = 'TRUE' THEN
        l_xxssys_event_rec.active_flag := 'Y';
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        -- Start Go-Live 3 Relation
      ELSIF l_related_to_ecom = 'TRUE' THEN
        -- Non-Ecom customer related to ecom customer
        BEGIN
          SELECT site_use_code
          INTO   l_nonecom_site_use
          FROM   hz_cust_site_uses_all hcsua
          WHERE  hcsua.site_use_id = p_site_use_id
          AND    hcsua.site_use_code = 'SHIP_TO';
        
          l_xxssys_event_rec.active_flag := 'Y';
          xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        EXCEPTION
          WHEN no_data_found THEN
	NULL;
        END;
        -- End Go-Live 3 Relation
      ELSE
        l_xxssys_event_rec.active_flag := 'N';
        -- check if sync is the past
        IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
          --call insert pkg
          xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        END IF;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      g_account_number := fetch_accnt_num(nvl(l_xxssys_event_rec.attribute2,
			          l_xxssys_event_rec.attribute1));
      g_time           := SYSDATE;
      l_site_name      := fetch_site_name(l_xxssys_event_rec.entity_id);
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface',
	    'The following unexpected exception occurred for Customer interface event processor.' ||
	    chr(13) || chr(10) ||
	    'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Site ID: ' ||
	    l_xxssys_event_rec.entity_id || chr(13) || chr(10) ||
	    '  Site Name: ' || l_site_name || chr(13) || chr(10) ||
	    '  Account ID: ' ||
	    nvl(l_xxssys_event_rec.attribute2,
	        l_xxssys_event_rec.attribute1) || chr(13) || chr(10) ||
	    '  Account Number : ' || g_account_number || chr(13) ||
	    chr(10) || '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
	    chr(10) || '  Error Time: ' || g_time);
    
  END handle_site;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Contact information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  25/10/2015  Debarati Banerjee                  CHG0036659 - Modified cursor cur_site to include
  --                                                     only ship_to and bill_to sites
  -- 1.2  09/25/2015  Diptasurjya Chatterjee             CHG0036450 : Reseller changes. Add seperate condition to handle
  --                                                     contact add/updates for non-ecom accounts having related ecomm accounts.
  --                                                     If an account is made ecom by marking contact as ecom, then existing relations
  --                                                     where this account is related will also be interfaced
  -- 1.3  07/07/2017  Diptasurjya Chatterjee             INC0096393 - add new input parameter for DB trigger mode
  --                                                     which will be passed to the insert_event procedure. It will have a default value of 'N'
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_contact(p_contact_id      IN NUMBER,
		   p_db_trigger_mode IN VARCHAR2 DEFAULT 'N') IS
  
    l_ecom_cust_flag         VARCHAR2(10);
    l_ecom_related_cust_flag VARCHAR2(10);
    l_related_to_ecom        VARCHAR2(10); -- Start Go-Live 3 Relation
    l_ecomm_contact          VARCHAR2(10);
    l_xxssys_event_rec       xxssys_events%ROWTYPE;
    l_contact_name           VARCHAR2(2000);
  
    l_related_cont_role VARCHAR2(2000); -- CHG0036450 : Tagore
  
    CURSOR cur_contact_id IS
      SELECT hca.cust_account_id cust_account_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_org_contacts       hoc,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
	/*AND    hp_contact.status = 'A'
            AND    hp_cust.status = 'A'
            AND    nvl(hps.status, 'A') = 'A'
            AND    nvl(hoc.status, 'A') = 'A'*/
	--AND    hcar.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hcar.cust_account_role_id = p_contact_id;
  
    CURSOR cur_related_contact(p_cust_account_id IN NUMBER) IS
      SELECT hcara.related_cust_account_id rel_cust_account_id,
	 hcara.cust_account_id         cust_account_id
      FROM   hz_cust_acct_relate_all hcara,
	 hz_cust_accounts        hca,
	 hz_party_sites          hps,
	 --hz_cust_acct_sites_all  hcasa,
	 --hz_cust_site_uses_all   hcsua,
	 hz_parties hp,
	 --hz_locations            hl,
	 --fnd_territories_vl      ftv,
	 hz_cust_account_roles hcar
      WHERE  hca.cust_account_id = hcara.cust_account_id
      AND    hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
	--AND    hps.party_site_id = hcasa.party_site_id
	--AND    hcsua.site_use_code IN ('SHIP_TO')
	--AND    hcasa.org_id = hcsua.org_id
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
	--AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
	--AND    hps.location_id = hl.location_id
	--AND    hl.country = ftv.territory_code(+)
      AND    hp.status = 'A'
      AND    hca.status = 'A'
	--AND    hcara.status = 'A'
	--AND    hcsua.status = 'A'
	--AND    hcasa.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hcara.ship_to_flag = 'Y'
	/*AND    hcasa.org_id IN
            (SELECT hro.organization_id
             FROM   hr_operating_units    hro,
                    hr_organization_units hru
             WHERE  hro.organization_id = hru.organization_id
             AND    hru.attribute7 = 'Y')*/
      AND    hcara.org_id IN
	 (SELECT hro.organization_id
	   FROM   hr_operating_units    hro,
	          hr_organization_units hru
	   WHERE  hro.organization_id = hru.organization_id
	   AND    hru.attribute7 = 'Y')
      AND    hcar.cust_account_id = hca.cust_account_id
      AND    hcar.cust_account_role_id = p_contact_id
      AND    hcara.cust_account_id = p_cust_account_id;
  
    CURSOR cur_site(p_cust_account_id IN NUMBER) IS
      SELECT hcsua.site_use_id site_use_id
      FROM   hz_locations           hl,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua,
	 hz_cust_accounts       hca,
	 hz_parties             hp
      WHERE  hca.cust_account_id = p_cust_account_id
      AND    hca.party_id = hp.party_id
      AND    hp.party_id = hps.party_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcasa.org_id
	  AND    hru.attribute7 = 'Y')
      AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id;
  
    CURSOR cur_contact(p_cust_account_id IN NUMBER) IS
      SELECT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_org_contacts       hoc,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
	/*AND    hp_contact.status = 'A'
            AND    hp_cust.status = 'A'
            AND    nvl(hps.status, 'A') = 'A'
            AND    nvl(hoc.status, 'A') = 'A'*/
	--AND    hcar.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hca.cust_account_id = p_cust_account_id;
  
    CURSOR cur_related_account(p_cust_account_id IN NUMBER) IS
      SELECT cust_account_id,
	 related_cust_account_id,
	 org_id
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.related_cust_account_id = p_cust_account_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcara.org_id
	  AND    hru.attribute7 = 'Y')
      AND    hcara.status = 'A';
  BEGIN
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_contact_entity_name;
    l_xxssys_event_rec.entity_id       := p_contact_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
  
    FOR i IN cur_contact_id LOOP
      l_ecom_cust_flag  := xxhz_util.is_ecomm_customer(i.cust_account_id);
      l_related_to_ecom := is_account_related_to_ecom(i.cust_account_id); -- Start Go-Live 3 Relation
    
      l_xxssys_event_rec.attribute1 := i.cust_account_id;
      IF l_ecom_cust_flag = 'TRUE' THEN
        l_xxssys_event_rec.active_flag := 'Y';
      
        /*IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN                                         -- Commented for CHG0039473
          xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        ELSE*/
        l_ecomm_contact := is_ecomm_contact(p_contact_id);
      
        IF l_ecomm_contact = 'TRUE' THEN
          -- new contact marked as ecomm , we need to sync site and account also
        
          handle_account(i.cust_account_id);
        
          /* Start Go-Live 3 Relation */
          FOR p IN cur_related_account(i.cust_account_id) LOOP
	handle_acct_relationship(p.cust_account_id,
			 p.related_cust_account_id,
			 p.org_id); -- CHG0036450 : Tagore
          -- handle_acct_relationship(p.related_cust_account_id, p.cust_account_id, p.org_id);  -- CHG0036450 : Tagore
          END LOOP;
          /* Start Go-Live 3 Relation */
        
          FOR n IN cur_site(i.cust_account_id) LOOP
	handle_site(n.site_use_id);
          END LOOP;
        
          FOR m IN cur_contact(i.cust_account_id) LOOP
	l_xxssys_event_rec.entity_id := m.contact_id;
	xxssys_event_pkg.insert_event(l_xxssys_event_rec,
			      p_db_trigger_mode);
          END LOOP;
        
        ELSE
          xxssys_event_pkg.insert_event(l_xxssys_event_rec,
			    p_db_trigger_mode);
        
        END IF;
      
        --  END IF;                           -- Commented for CHG0039473
        -- Start Go-Live 3 Relation
      ELSIF l_related_to_ecom = 'TRUE' THEN
        -- Non-Ecom customer related to ecom customer
        SELECT nvl((SELECT listagg(hrr.responsibility_type, ',') within GROUP(ORDER BY hrr.responsibility_type)
	       FROM   hz_role_responsibility hrr
	       WHERE  hrr.cust_account_role_id = p_contact_id),
	       'SHIP_TO,BILL_TO')
        INTO   l_related_cont_role
        FROM   dual;
      
        IF l_related_cont_role LIKE '%SHIP_TO%' THEN
          l_xxssys_event_rec.active_flag := 'Y';
          xxssys_event_pkg.insert_event(l_xxssys_event_rec,
			    p_db_trigger_mode);
        END IF;
        -- End Go-Live 3 Relation
        -- check if sync is the past ( contact is no longer ecomm)
      ELSE
        l_xxssys_event_rec.active_flag := 'N';
        IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
          --call insert pkg
        
          xxssys_event_pkg.insert_event(l_xxssys_event_rec,
			    p_db_trigger_mode);
          -- loop for all contacts which relate to the same account
        
          FOR x IN cur_contact(i.cust_account_id) LOOP
	l_xxssys_event_rec.entity_id := x.contact_id;
	xxssys_event_pkg.insert_event(l_xxssys_event_rec,
			      p_db_trigger_mode);
          END LOOP;
        END IF;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      g_account_number := fetch_accnt_num(nvl(l_xxssys_event_rec.attribute2,
			          l_xxssys_event_rec.attribute1));
      g_time           := SYSDATE;
      l_contact_name   := fetch_contact_name(l_xxssys_event_rec.entity_id);
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface',
	    'The following unexpected exception occurred for Customer interface event processor.' ||
	    chr(13) || chr(10) ||
	    'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Contact ID: ' ||
	    l_xxssys_event_rec.entity_id || chr(13) || chr(10) ||
	    '  Contact Name: ' || l_contact_name || chr(13) || chr(10) ||
	    '  Account ID: ' ||
	    nvl(l_xxssys_event_rec.attribute2,
	        l_xxssys_event_rec.attribute1) || chr(13) || chr(10) ||
	    '  Account Number : ' || g_account_number || chr(13) ||
	    chr(10) || '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
	    chr(10) || '  Error Time: ' || g_time);
  END handle_contact;

  -- Start Go-Live 3 Relation
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          This function is used to handle the Account Relation for any given
  --          Account_Id and Related_Cust_Account_Id (optional) and org_id (optional)
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  09/25/2015  Diptasurjya Chatterjee        CHG0036450 : Reseller changes. This procedure will
  --                                                handle add/update of account relationships and
  --                                                generate required events
  -- 1.1  10/18/2017  Diptasurjya Chatterjee        INC0104197 - Variable l_related_cont_role size is low in handle_acct_relationship causing errors
  --                                                if contact has more than 2 roles
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_acct_relationship(p_cust_account_id       IN NUMBER,
			 p_reltd_cust_account_id IN NUMBER,
			 p_org_id                IN NUMBER) IS
  
    l_xxssys_event_rec      xxssys_events%ROWTYPE;
    l_xxssys_event_acct_rec xxssys_events%ROWTYPE;
    l_ship_to_flag          VARCHAR2(10);
    l_relate_status         VARCHAR2(1);
    --l_reciprocal_flag     VARCHAR2(10);
    l_ecomm_cust        VARCHAR2(10);
    l_rel_ecomm_cust    VARCHAR2(10);
    l_related_cont_role VARCHAR2(2000); -- INC0104197 - Dipta increase size to 2000 from 20
  
    l_acct_exists_in_event_tab NUMBER := 0;
  
    CURSOR cur_site(p_cust_account_id IN NUMBER,
	        p_site_use        IN VARCHAR2) IS
      SELECT hcsua.site_use_id site_use_id
      FROM   hz_locations           hl,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua
      WHERE  hcasa.cust_account_id = p_cust_account_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hcsua.site_use_code = nvl(p_site_use, hcsua.site_use_code)
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcasa.org_id
	  AND    hru.attribute7 = 'Y');
  
    CURSOR cur_contact(p_cust_account_id IN NUMBER) IS
      SELECT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_org_contacts       hoc,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hca.cust_account_id = p_cust_account_id;
  
    /*CURSOR cur_reltd_accounts is                                          -- CHG0036450 : Tagore Commented the redundant code
    SELECT ship_to_flag,
           customer_reciprocal_flag,
           related_cust_account_id,
           org_id,
           status
    FROM hz_cust_acct_relate_all hcara
    WHERE cust_account_id                 = p_cust_account_id
    AND           related_cust_account_id         = NVL(p_reltd_cust_account_id,related_cust_account_id)
    AND           org_id                                                          = NVL(p_org_id,org_id)
    AND           org_id IN (SELECT hro.organization_id org_id
                     FROM   hr_operating_units    hro,
                            hr_organization_units hru
                     WHERE  hro.organization_id   = hru.organization_id
                     AND    hru.attribute7                = 'Y');*/
  BEGIN
    l_rel_ecomm_cust := xxhz_util.is_ecomm_customer(p_reltd_cust_account_id); -- CHG0036450 : Tagore
  
    BEGIN
      SELECT ship_to_fl,
	 rel_status
      INTO   l_ship_to_flag,
	 l_relate_status
      FROM   (SELECT nvl(ship_to_flag, 'N') ship_to_fl,
	         status rel_status
	  FROM   hz_cust_acct_relate_all hcara
	  WHERE  cust_account_id = p_cust_account_id -- CHG0036450 : Tagore
	  AND    related_cust_account_id = p_reltd_cust_account_id -- CHG0036450 : Tagore
	  AND    org_id = p_org_id
	  AND    org_id IN
	         (SELECT hro.organization_id org_id
	           FROM   hr_operating_units    hro,
		      hr_organization_units hru
	           WHERE  hro.organization_id = hru.organization_id
	           AND    hru.attribute7 = 'Y')
	  ORDER  BY cust_acct_relate_id DESC)
      WHERE  rownum = 1;
    
      l_ecomm_cust := xxhz_util.is_ecomm_customer(p_cust_account_id); -- CHG0036450 : Tagore
    
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_acct_relation_entity_name;
      l_xxssys_event_rec.entity_id       := p_reltd_cust_account_id; -- CHG0036450 : Tagore
      l_xxssys_event_rec.attribute1      := p_cust_account_id; -- CHG0036450 : Tagore
      l_xxssys_event_rec.attribute2      := p_org_id;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
    
      --if l_rel_ecomm_cust = 'TRUE' then
      IF l_rel_ecomm_cust = 'TRUE' THEN
        -- CHG0036450 : Tagore
        IF l_ship_to_flag = 'Y' THEN
          IF l_relate_status = 'A' THEN
	l_xxssys_event_rec.active_flag := 'Y';
	IF l_ecomm_cust <> 'TRUE' THEN
	  l_xxssys_event_acct_rec.target_name     := g_target_name;
	  l_xxssys_event_acct_rec.entity_id       := p_cust_account_id; -- CHG0036450 : Tagore
	  l_xxssys_event_acct_rec.attribute1      := NULL;
	  l_xxssys_event_acct_rec.attribute2      := NULL;
	  l_xxssys_event_acct_rec.entity_name     := g_account_entity_name;
	  l_xxssys_event_acct_rec.event_name      := g_eventname;
	  l_xxssys_event_acct_rec.last_updated_by := g_user_id;
	  l_xxssys_event_acct_rec.created_by      := g_user_id;
	
	  IF xxssys_event_pkg.is_sync(l_xxssys_event_acct_rec) <>
	     'TRUE' THEN
	    handle_account(p_cust_account_id); -- CHG0036450 : Tagore
	  
	    SELECT COUNT(1)
	    INTO   l_acct_exists_in_event_tab
	    FROM   xxssys_events
	    WHERE  entity_name = g_account_entity_name
	    AND    target_name = g_target_name --INC0123738
	    AND    entity_id = p_cust_account_id; -- CHG0036450 : Tagore
	  
	    IF l_acct_exists_in_event_tab > 0 THEN
	      xxssys_event_pkg.insert_event(l_xxssys_event_rec);
	    
	      FOR n IN cur_site(p_cust_account_id, 'SHIP_TO') LOOP
	        -- CHG0036450 : Tagore
	        handle_site(n.site_use_id);
	      END LOOP;
	    
	      FOR m IN cur_contact(p_cust_account_id) LOOP
	        -- CHG0036450 : Tagore
	        SELECT nvl((SELECT listagg(hrr.responsibility_type, ',') within GROUP(ORDER BY hrr.responsibility_type)
		       FROM   hz_role_responsibility hrr
		       WHERE  hrr.cust_account_role_id =
			  m.contact_id),
		       'SHIP_TO,BILL_TO')
	        INTO   l_related_cont_role
	        FROM   dual;
	      
	        IF l_related_cont_role LIKE '%SHIP_TO%' THEN
	          handle_contact(m.contact_id);
	        END IF;
	      END LOOP;
	    END IF;
	  END IF;
	ELSE
	  xxssys_event_pkg.insert_event(l_xxssys_event_rec);
	END IF;
          ELSE
	l_xxssys_event_rec.active_flag := 'N';
          
	IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	  xxssys_event_pkg.insert_event(l_xxssys_event_rec);
	END IF;
          END IF;
        ELSE
          l_xxssys_event_rec.active_flag := 'N';
          -- check if sync is the past
          IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	xxssys_event_pkg.insert_event(l_xxssys_event_rec);
          END IF;
        END IF;
      ELSE
        l_xxssys_event_rec.active_flag := 'N';
        -- check if sync is the past
        IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
          xxssys_event_pkg.insert_event(l_xxssys_event_rec);
        END IF;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  END handle_acct_relationship;
  -- End Go-Live 3 Relation

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This function generate and return customer contact data for a given cust_account_id,
  --          contact_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  05/08/2018  Diptasurjya Chatterjee             Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee             CHG0043798 - Change contact data fetch query to remove usage of tables
  --                                                     hz_party_sites, hz_locations and fnd_territores as these tables are not
  --                                                     being used for any column fetching
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_contact_data(p_cust_contact_id IN NUMBER)
    RETURN xxhz_customer_contact_rec IS
  
    l_customer_contact_rec   xxhz_customer_contact_rec;
    l_status                 VARCHAR2(1) := 'A';
    l_ecom_cust_flag         VARCHAR2(10);
    l_ecom_related_cust_flag VARCHAR2(10);
  
    l_email_status VARCHAR2(1);
    l_ou_status    VARCHAR2(1);
  
    l_email_st_msg VARCHAR2(4000);
    l_ou_st_msg    VARCHAR2(4000);
  
    l_contact_name VARCHAR2(2000);
  BEGIN
  
    /*check_email_address(p_cust_contact_id, l_email_status, l_email_st_msg);
    
    if l_email_status = 'N' then
      l_contact_name   := fetch_contact_name(p_cust_contact_id);
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
                'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
                'Customer Interface',
                'The following unexpected exception occurred for Customer interface event processor.' ||
                chr(13) || chr(10) ||
                'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
                chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
                chr(13) || chr(10) || '  Contact ID: ' ||
                p_cust_contact_id || chr(13) || chr(10) ||
                '  Contact Name: ' || l_contact_name || chr(13) || chr(10) ||
      '  Error: UNEXPECTED: ' || l_email_st_msg || chr(13) || chr(10) ||
      '  Error Time: ' || sysdate);
    end if;
    
    check_contact_ou(p_cust_contact_id, l_ou_status, l_ou_st_msg);*/
  
    SELECT xxhz_customer_contact_rec(NULL,
			 cust_account_role_id,
			 cust_account_id,
			 NULL,
			 person_pre_name_adjunct,
			 person_last_name,
			 person_first_name,
			 phone_number,
			 phone_area_code,
			 phone_country_code,
			 mob_number,
			 mob_area_code,
			 mob_country_code,
			 email_address,
			 category_code,
			 decode(instr(responsibility, 'BILL_TO'),
			        0,
			        'N',
			        'Y'),
			 decode(instr(responsibility, 'SHIP_TO'),
			        0,
			        'N',
			        'Y'),
			 nvl(attribute3, 'N'),
			 nvl((SELECT 'A'
			     FROM   dual
			     WHERE  cont_status = 'A'
			     AND    (responsibility LIKE
			           '%BILL_TO%' OR responsibility LIKE
			           '%SHIP_TO%')),
			     'I'),
			 decode(attribute3,
			        'Y',
			        attribute4,
			        NULL), -- OU
			 decode(attribute3, 'Y', pl_id, NULL), -- PL
			 (SELECT currency_code
			  FROM   qp_secu_list_headers_vl
			  WHERE  list_header_id = pl_id
			  AND    nvl(tt.attribute3, 'N') = 'Y') /*Currency*/) --BULK COLLECT
    INTO   l_customer_contact_rec
    FROM   (SELECT hcar.cust_account_role_id,
	       hca.cust_account_id,
	       hp_contact.person_pre_name_adjunct,
	       nvl(hoc.attribute8, hp_contact.person_last_name) person_last_name,
	       nvl(hoc.attribute7, hp_contact.person_first_name) person_first_name,
	       xpcpv_phone.phone_number,
	       xpcpv_phone.phone_area_code,
	       xpcpv_phone.phone_country_code,
	       xpcpv_mobile.phone_number mob_number,
	       xpcpv_mobile.phone_area_code mob_area_code,
	       xpcpv_mobile.phone_country_code mob_country_code,
	       xecpv.email_address,
	       hp_cust.category_code,
	       nvl((SELECT listagg(hrr.responsibility_type, ',') within GROUP(ORDER BY hrr.responsibility_type)
	           FROM   hz_role_responsibility hrr
	           WHERE  hrr.cust_account_role_id =
		      hcar.cust_account_role_id),
	           'SHIP_TO,BILL_TO') responsibility,
	       hcar.attribute3,
	       hcar.attribute4,
	       nvl((SELECT 'A'
	           FROM   dual
	           WHERE  hca.status = 'A'
	           AND    hcar.status = 'A'
	           AND    hp_contact.status = 'A'
	           AND    hp_cust.status = 'A'
		     --AND    nvl(hps.status, 'A') = 'A'  -- CHG0043798 commented
	           AND    nvl(hoc.status, 'A') = 'A'),
	           'I') cont_status,
	       fetch_pricelist_id(hca.cust_account_id, hcar.attribute4) pl_id -- change as per OU DFF setup
	FROM   hz_cust_accounts      hca,
	       hz_cust_account_roles hcar,
	       hz_relationships      hr,
	       hz_parties            hp_contact,
	       hz_parties            hp_cust,
	       --hz_party_sites             hps,  -- CHG0043798 commented
	       --hz_locations               hl,   -- CHG0043798 commented
	       --fnd_territories_vl         ftv,  -- CHG0043798 commented
	       hz_org_contacts            hoc,
	       xxhz_phone_contact_point_v xpcpv_phone,
	       xxhz_phone_contact_point_v xpcpv_mobile,
	       xxhz_email_contact_point_v xecpv
	WHERE  hp_cust.party_id = hca.party_id
	      --AND    hps.party_id(+) = hcar.party_id                -- CHG0043798 commented
	      --AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'   -- CHG0043798 commented
	      --AND    hl.location_id(+) = hps.location_id            -- CHG0043798 commented
	AND    hca.cust_account_id = hcar.cust_account_id
	      --AND    hl.country = ftv.territory_code(+)             -- -- CHG0043798 commented
	AND    hcar.role_type = 'CONTACT'
	AND    hcar.cust_acct_site_id IS NULL
	AND    hcar.party_id = hr.party_id
	AND    hr.subject_type = 'PERSON'
	AND    hp_cust.party_type = 'ORGANIZATION' -- yuval
	      --AND    hr.relationship_code = 'CONTACT_OF' by yuval CHG0042626
	AND    hr.subject_id = hp_contact.party_id
	AND    hoc.party_relationship_id = hr.relationship_id
	AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
	AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
	AND    hcar.party_id = xecpv.owner_table_id(+)
	AND    xpcpv_phone.phone_line_type(+) = 'GEN'
	AND    xpcpv_phone.phone_rownum(+) = 1
	AND    xpcpv_phone.status(+) = 'A'
	AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
	AND    xpcpv_mobile.phone_rownum(+) = 1
	AND    xpcpv_mobile.status(+) = 'A'
	AND    xecpv.contact_point_type(+) = 'EMAIL'
	AND    xecpv.email_rownum(+) = 1
	AND    xecpv.status(+) = 'A'
	AND    hcar.cust_account_role_id = p_cust_contact_id) tt;
    RETURN l_customer_contact_rec;
  END generate_contact_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to perform validations on customer contacts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  05/11/2018  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE validate_account_contact(p_cust_account_id      IN NUMBER DEFAULT NULL,
			 p_cust_account_role_id IN NUMBER DEFAULT NULL,
			 p_cont_attribute3      IN VARCHAR2 DEFAULT NULL,
			 p_cont_attribute4      IN VARCHAR2 DEFAULT NULL,
			 p_validate_email       IN VARCHAR2,
			 p_send_error_mail      IN VARCHAR2,
			 p_db_trigger_mode      IN VARCHAR2,
			 x_status               OUT VARCHAR2,
			 x_status_message       OUT VARCHAR2) IS
    l_status         VARCHAR2(1) := 'S';
    l_status_message VARCHAR2(4000);
  
    l_email_msg      VARCHAR2(4000);
    l_email_status   VARCHAR2(1);
    l_account_status VARCHAR2(1);
    l_account_number VARCHAR2(30);
    l_contact_name   VARCHAR2(4000);
  
    l_contact_site_id NUMBER := 0;
  
    l_pl_id        NUMBER;
    l_ship_site_id NUMBER;
    l_bill_site_id NUMBER;
  BEGIN
    --writelog('Before validate start '||p_cust_account_id||' '||p_cust_account_role_id);
  
    SELECT hcar.cust_acct_site_id
    INTO   l_contact_site_id
    FROM   hz_cust_account_roles hcar
    WHERE  hcar.cust_account_role_id = p_cust_account_role_id;
  
    -- If contact belongs to site then skip validation
    IF l_contact_site_id > 0 THEN
      RETURN;
    END IF;
  
    l_contact_name := fetch_contact_name(p_cust_account_role_id);
  
    -- Accunt active check
    SELECT nvl((SELECT 'A'
	   FROM   dual
	   WHERE  hca.status = 'A'
	   AND    hp.status = 'A'),
	   'I'),
           hca.account_number
    INTO   l_account_status,
           l_account_number
    FROM   hz_cust_accounts hca,
           hz_parties       hp
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.party_id = hp.party_id;
  
    IF l_account_status <> 'A' THEN
      l_status         := 'E';
      l_status_message := 'VALIDATION ERROR: The customer account # ' ||
		  l_account_number || ' is not active';
      --raise_application_error(-20001,'VALIDATION ERROR: The customer account is not active');
    END IF;
  
    --writelog('After account validate');
  
    -- Check email duplication and blank
    --IF p_validate_email = 'Y' THEN
    IF p_cont_attribute3 = 'Y' THEN
      apps.xxhz_ecomm_event_pkg.check_email_address(p_cust_account_role_id,
				    p_validate_email,
				    l_email_status,
				    l_email_msg);
    END IF;
  
    IF l_email_status = 'N' THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(10) || l_email_msg;
      --raise_application_error(-20001,l_email_msg);
    END IF;
    --END IF;
  
    --writelog('After validate email');
  
    -- OU DFF mandatory if eCommerce contact
    IF p_cont_attribute3 = 'Y' AND p_cont_attribute4 IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(10) ||
		  'VALIDATION ERROR: eCommerce OU must be populated for eCommerce contact: ' ||
		  l_contact_name || ' (Reference #' ||
		  p_cust_account_role_id || ' Account # ' ||
		  l_account_number || ')';
      --raise_application_error(-20001,'VALIDATION ERROR: eCommerce OU must be populated for eCommerce contacts');
    END IF;
  
    --writelog('After validate OU');
  
    -- Pricelist ID check for contact
    BEGIN
      IF p_cont_attribute3 = 'Y' AND p_cont_attribute4 IS NOT NULL THEN
        l_pl_id := xxhz_ecomm_event_pkg.fetch_pricelist_id(p_cust_account_id,
				           p_cont_attribute4);
      
        IF l_pl_id IS NULL THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(10) ||
		      'VALIDATION ERROR: Pricelist could not be derived for this contact: ' ||
		      l_contact_name || ' (Reference #' ||
		      p_cust_account_role_id || ' Account # ' ||
		      l_account_number || ')';
          --raise_application_error(-20001,'VALIDATION ERROR: Pricelist could not be derived for this contact');
        END IF;
      END IF;
    END;
  
    --writelog('After validate PL');
  
    -- Primary ship and bill site check
    BEGIN
      IF p_cont_attribute3 = 'Y' AND p_cont_attribute4 IS NOT NULL THEN
        SELECT hcsua_ship.site_use_id
        INTO   l_ship_site_id
        FROM   hz_cust_acct_sites_all hcasa,
	   hz_cust_site_uses_all  hcsua_ship
        WHERE  hcasa.cust_account_id = p_cust_account_id
        AND    hcasa.org_id = p_cont_attribute4
        AND    hcasa.cust_acct_site_id = hcsua_ship.cust_acct_site_id
        AND    hcasa.status = 'A'
        AND    hcsua_ship.status = 'A'
        AND    hcsua_ship.primary_flag = 'Y'
        AND    hcsua_ship.org_id = hcasa.org_id
        AND    hcsua_ship.site_use_code = 'SHIP_TO';
      
        SELECT hcsua_bill.site_use_id
        INTO   l_bill_site_id
        FROM   hz_cust_acct_sites_all hcasa,
	   hz_cust_site_uses_all  hcsua_bill
        WHERE  hcasa.cust_account_id = p_cust_account_id
        AND    hcasa.org_id = p_cont_attribute4
        AND    hcasa.cust_acct_site_id = hcsua_bill.cust_acct_site_id
        AND    hcasa.status = 'A'
        AND    hcsua_bill.status = 'A'
        AND    hcsua_bill.primary_flag = 'Y'
        AND    hcsua_bill.org_id = hcasa.org_id
        AND    hcsua_bill.site_use_code = 'BILL_TO';
      
        IF l_ship_site_id IS NULL AND l_bill_site_id IS NULL THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(10) ||
		      'VALIDATION ERROR: Primary shipping and billing site does not exist for account # ' ||
		      l_account_number;
          --raise_application_error(-20001,'VALIDATION ERROR: Primary shipping and billing site does not exist for account');
        ELSIF l_ship_site_id IS NULL THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(10) ||
		      'VALIDATION ERROR: Primary shipping site does not exist for account # ' ||
		      l_account_number;
          --raise_application_error(-20001,'VALIDATION ERROR: Primary shipping site does not exist for account');
        ELSIF l_bill_site_id IS NULL THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(10) ||
		      'VALIDATION ERROR: Primary billing site does not exist for account # ' ||
		      l_account_number;
          --raise_application_error(-20001,'VALIDATION ERROR: Primary billing site does not exist for account');
        END IF;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        l_status         := 'E';
        l_status_message := l_status_message || chr(10) ||
		    'VALIDATION ERROR: Primary shipping and billing site does not exist for account # ' ||
		    l_account_number;
        --raise_application_error(-20001,'VALIDATION ERROR: Primary shipping and billing site does not exist');
    END;
  
    --writelog('After validate address '||l_status);
  
    IF l_status = 'E' THEN
      x_status         := 'E';
      x_status_message := substr(l_status_message, 1, 4000);
    
      IF p_send_error_mail = 'Y' THEN
      
        xxssys_event_pkg.insert_mail_event(p_db_trigger_mode => p_db_trigger_mode,
			       p_target_name     => g_target_name,
			       p_event_name      => g_eventname,
			       p_user_id         => g_user_id,
			       p_program_name_to => 'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
			       p_program_name_cc => 'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
			       p_operating_unit  => p_cont_attribute4,
			       p_entity          => 'CONTACT',
			       p_entity_id       => p_cust_account_role_id,
			       p_subject         => 'eStore - Error in Oracle Customer Interface event processor',
			       p_body            => 'Contact ID: ' ||
					    p_cust_account_role_id ||
					    chr(13) ||
					    chr(10) ||
					    'Contact Name: ' ||
					    l_contact_name ||
					    chr(13) ||
					    chr(10) ||
					    'Account ID: ' ||
					    p_cust_account_id ||
					    chr(13) ||
					    chr(10) ||
					    'Account Number : ' ||
					    l_account_number ||
					    chr(13) ||
					    chr(10) ||
					    substr(l_status_message,
					           1,
					           4000) ||
					    chr(13) ||
					    chr(10) ||
					    'Error Time: ' ||
					    SYSDATE);
      
      END IF;
    ELSE
      x_status := 'S';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'F';
      x_status_message := 'UNEXPECTED ERROR: During contact validation. ' ||
		  SQLERRM;
    
      IF p_send_error_mail = 'Y' THEN
        xxssys_event_pkg.insert_mail_event(p_db_trigger_mode => p_db_trigger_mode,
			       p_target_name     => g_target_name,
			       p_event_name      => g_eventname,
			       p_user_id         => g_user_id,
			       p_program_name_to => 'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
			       p_program_name_cc => 'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
			       p_operating_unit  => p_cont_attribute4,
			       p_entity          => 'CONTACT',
			       p_entity_id       => p_cust_account_role_id,
			       p_subject         => 'eStore - Error in Oracle Customer Interface event processor',
			       p_body            => 'Contact ID: ' ||
					    p_cust_account_role_id ||
					    chr(13) ||
					    chr(10) ||
					    'Contact Name: ' ||
					    l_contact_name ||
					    chr(13) ||
					    chr(10) ||
					    'Account ID: ' ||
					    p_cust_account_id ||
					    chr(13) ||
					    chr(10) ||
					    'Account Number : ' ||
					    l_account_number ||
					    chr(13) ||
					    chr(10) ||
					    substr(x_status_message,
					           1,
					           4000) ||
					    chr(13) ||
					    chr(10) ||
					    'Error Time: ' ||
					    SYSDATE);
      
      END IF;
  END validate_account_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to handle site event and message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  05/11/2018  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee             CHG0043798 - Change calls to send_mail and
  --                                                     process_event in exception block to autonomous
  --                                                     mode
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_contact_new(p_contact_id      IN NUMBER,
		       p_db_trigger_mode IN VARCHAR2 DEFAULT 'N',
		       p_mode            IN VARCHAR2 DEFAULT 'UPSERT') IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_contact_name     VARCHAR2(2000);
  
    l_cust_account_id NUMBER;
  
    l_attribute3          VARCHAR2(240);
    l_attribute4          VARCHAR2(240);
    l_event_handling_prof VARCHAR(1);
  
    l_valid_status     VARCHAR2(1) := 'S';
    l_valid_status_msg VARCHAR2(4000);
  BEGIN
    --writelog('Here 1: '||p_contact_id);
    SELECT hcar.cust_account_id,
           hcar.attribute3,
           hcar.attribute4
    INTO   l_cust_account_id,
           l_attribute3,
           l_attribute4
    FROM   hz_cust_account_roles hcar
    WHERE  hcar.cust_account_role_id = p_contact_id;
  
    --writelog('Here 2: '||l_cust_account_id||' '||l_attribute3||' '||l_attribute4);
  
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_contact_entity_name;
    l_xxssys_event_rec.entity_id       := p_contact_id;
    l_xxssys_event_rec.attribute1      := l_cust_account_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
    l_xxssys_event_rec.event_message   := xmltype(generate_contact_data(p_contact_id))
			      .getclobval();
  
    --writelog('Here 3');
  
    -- Call validation for ecom contacts
    IF l_attribute3 = 'Y' THEN
      validate_account_contact(p_cust_account_id      => l_cust_account_id,
		       p_cust_account_role_id => p_contact_id,
		       p_cont_attribute3      => l_attribute3,
		       p_cont_attribute4      => l_attribute4,
		       p_validate_email       => 'Y',
		       p_send_error_mail      => 'Y',
		       p_db_trigger_mode      => p_db_trigger_mode,
		       x_status               => l_valid_status,
		       x_status_message       => l_valid_status_msg);
    END IF;
    --writelog('Here 4');
    -- Insert event record
  
    -- Per discussion with Ginat B - Always insert event even though validation fails
    --IF nvl(l_valid_status, 'N') = 'S' THEN
    xxssys_event_pkg.process_event(l_xxssys_event_rec, p_db_trigger_mode);
    --END IF;
    --writelog('Here 5');
  EXCEPTION
    WHEN OTHERS THEN
      /* Below portion will insert an event in ERR status */
      l_xxssys_event_rec.status      := 'ERR';
      l_xxssys_event_rec.err_message := substr(SQLERRM, 1, 2000);
      --xxssys_event_pkg.process_event(l_xxssys_event_rec, p_db_trigger_mode);  -- CHG0043798 commented
      xxssys_event_pkg.process_event_autonomous(l_xxssys_event_rec,
				p_db_trigger_mode); -- CHG0043798 added
    
      g_account_number := fetch_accnt_num(nvl(l_xxssys_event_rec.attribute2,
			          l_xxssys_event_rec.attribute1));
      g_time           := SYSDATE;
      l_contact_name   := fetch_contact_name(l_xxssys_event_rec.entity_id);
      --send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',  -- CHG0043798 commented
      send_mail_autonomous('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO', -- CHG0043798 added
		   'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
		   'Customer Interface',
		   'The following unexpected exception occurred for Customer interface event processor.' ||
		   chr(13) || chr(10) ||
		   'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
		   chr(13) || chr(10) || chr(10) ||
		   'Failed record details: ' || chr(13) || chr(10) ||
		   '  Contact ID: ' || l_xxssys_event_rec.entity_id ||
		   chr(13) || chr(10) || '  Contact Name: ' ||
		   l_contact_name || chr(13) || chr(10) ||
		   '  Account ID: ' ||
		   nvl(l_xxssys_event_rec.attribute2,
		       l_xxssys_event_rec.attribute1) || chr(13) ||
		   chr(10) || '  Account Number : ' ||
		   g_account_number || chr(13) || chr(10) ||
		   '  Error: UNEXPECTED: ' ||
		   substr(SQLERRM, 1, 250) || chr(13) || chr(10) ||
		   '  Error Time: ' || g_time || chr(13) || chr(10) ||
		   'Procedure :' ||
		   'xxhz_ecomm_event_pkg.handle_contact_new');
  END handle_contact_new;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to regenerate events for all ecom contacts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE regen_ecom_contact_events(p_cust_account_id IN NUMBER) IS
    CURSOR cur_ecom_contacts IS
      SELECT hcar.cust_account_role_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_org_contacts       hoc,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hp_cust.party_type = 'ORGANIZATION' -- yuval
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    nvl(hcar.attribute3, 'N') = 'Y'
      AND    hca.cust_account_id = p_cust_account_id;
  BEGIN
    FOR rec_contact IN cur_ecom_contacts LOOP
      handle_contact_new(rec_contact.cust_account_role_id);
    
    END LOOP;
  END regen_ecom_contact_events;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This function generate and return customer site data for a given cust_account_id,
  --          site_id and org_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                    Description
  -- 1.0  05/08/2018  Diptasurjya             Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee  CHG0043798 - Change site data fetch query to remove join
  --                                          for checking if the site and account party_is are same.
  --                                          Sometimes OM team is assigning site usages to existing
  --                                          contact locations causing the site to be created against the
  --                                          contact party and not the account party
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_site_data(p_cust_site_use_id IN NUMBER)
    RETURN xxhz_customer_site_rec IS
  
    l_status            VARCHAR2(2);
    l_customer_site_rec xxhz_customer_site_rec;
  
  BEGIN
  
    SELECT xxhz_customer_site_rec(NULL,
		          hca.cust_account_id,
		          NULL,
		          NULL,
		          NULL,
		          nvl(hps.attribute5,
			  TRIM(hl.address1 || ' ' || hl.address2 || ' ' ||
			       hl.address3 || ' ' || hl.address4)),
		          nvl(hps.attribute4, hl.city),
		          --nvl(hps.attribute3,ftv.territory_short_name), -- cOMMENTED LOCAL LANGUAGE CHANGE AS NOT IMPLEMENTED IN HYBRIS
		          ftv.territory_short_name,
		          hl.county,
		          (SELECT fl.meaning
		           FROM   fnd_lookup_values fl
		           WHERE  fl.lookup_type IN
			      ('US_STATE', 'CA_PROVINCE')
		           AND    fl.language = 'US'
		           AND    (fl.lookup_code = hl.state OR
			     fl.meaning = hl.state)),
		          hl.postal_code,
		          decode(hcsua.site_use_code,
			     'BILL_TO',
			     'Y',
			     'N'),
		          decode(hcsua.site_use_code,
			     'SHIP_TO',
			     'Y',
			     'N'),
		          hcasa.org_id,
		          hcsua.site_use_id,
		          hcsua.contact_id,
		          hcsua.primary_flag,
		          nvl((SELECT 'A'
			  FROM   dual
			  WHERE  hp.status = 'A'
			  AND    hca.status = 'A'
			  AND    nvl(hps.status, 'A') = 'A'
			  AND    hcsua.status = 'A'
			  AND    hcasa.status = 'A'),
			  'I')) -- BULK COLLECT
    INTO   l_customer_site_rec
    FROM   hz_cust_accounts       hca,
           hz_parties             hp,
           hz_party_sites         hps,
           hz_locations           hl,
           hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  hcsua,
           fnd_territories_vl     ftv
    WHERE  hca.party_id = hp.party_id
          --AND    hps.party_id = hp.party_id  -- CHG0043798 commented
    AND    hps.location_id = hl.location_id
    AND    hl.country = ftv.territory_code(+)
          --AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO') -- Dipta removed
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hca.cust_account_id = hcasa.cust_account_id
    AND    hcasa.org_id = hcsua.org_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcsua.site_use_id = p_cust_site_use_id;
  
    RETURN l_customer_site_rec;
  END generate_site_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to handle site event and message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee             CHG0043798 - Change calls to send_mail and
  --                                                     process_event in exception block to autonomous
  --                                                     mode
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_site_new(p_site_use_id IN NUMBER,
		    p_mode        IN VARCHAR2 DEFAULT 'UPSERT') IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_site_name        VARCHAR2(1000);
  
    l_cust_account_id NUMBER;
    l_org_id          NUMBER;
  BEGIN
    SELECT hcasa.cust_account_id,
           hcasa.org_id
    INTO   l_cust_account_id,
           l_org_id
    FROM   hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  hcsua
    WHERE  hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcsua.site_use_id = p_site_use_id;
  
    IF l_org_id <> 89 THEN
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_site_entity_name;
      l_xxssys_event_rec.entity_id       := p_site_use_id;
      l_xxssys_event_rec.attribute1      := l_cust_account_id;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
      l_xxssys_event_rec.event_message   := xmltype(generate_site_data(p_site_use_id))
			        .getclobval();
    
      IF p_mode = 'UPSERT' THEN
        xxssys_event_pkg.process_event(p_xxssys_event_rec => l_xxssys_event_rec);
      ELSIF p_mode = 'INSERT' THEN
        xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec);
      END IF;
    
      -- re-generate events for all ecom contacts. This is to make sure PL changes if any gets reflected in contacts
      regen_ecom_contact_events(l_cust_account_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      /* Below portion will insert an event in ERR status */
      l_xxssys_event_rec.status      := 'ERR';
      l_xxssys_event_rec.err_message := substr(SQLERRM, 1, 2000);
      --xxssys_event_pkg.process_event(l_xxssys_event_rec);  -- CHG0043798 commented
      xxssys_event_pkg.process_event_autonomous(l_xxssys_event_rec); -- CHG0043798 added
    
      g_account_number := fetch_accnt_num(nvl(l_xxssys_event_rec.attribute2,
			          l_xxssys_event_rec.attribute1));
      g_time           := SYSDATE;
      l_site_name      := fetch_site_name(l_xxssys_event_rec.entity_id);
    
      --send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',  -- CHG0043798 commented
      send_mail_autonomous('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO', -- CHG0043798 added
		   'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
		   'Customer Interface',
		   'The following unexpected exception occurred for Customer interface event processor.' ||
		   chr(13) || chr(10) ||
		   'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
		   chr(13) || chr(10) || chr(10) ||
		   'Failed record details: ' || chr(13) || chr(10) ||
		   '  Site ID: ' || l_xxssys_event_rec.entity_id ||
		   chr(13) || chr(10) || '  Site Name: ' ||
		   l_site_name || chr(13) || chr(10) ||
		   '  Account ID: ' ||
		   nvl(l_xxssys_event_rec.attribute2,
		       l_xxssys_event_rec.attribute1) || chr(13) ||
		   chr(10) || '  Account Number : ' ||
		   g_account_number || chr(13) || chr(10) ||
		   '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
		   chr(10) || '  Error Time: ' || g_time || chr(13) ||
		   chr(10) || 'Procedure :' ||
		   'xxhz_ecomm_event_pkg.handle_site_new');
  END handle_site_new;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          generate_account_data - This function generate and return customer account data for a given cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  05/08/2018  Diptasurjya Chatterjee        CHG0042626 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_account_data(p_cust_account_id IN NUMBER)
    RETURN xxhz_customer_account_rec IS
    l_customer_account_rec xxhz_customer_account_rec;
  BEGIN
  
    SELECT xxhz_customer_account_rec(NULL, -- event id not available at this stage
			 cust_account_id,
			 party_name,
			 account_number,
			 NULL, -- org id nullified on account level
			 NULL, -- currency code nullified on account level
			 NULL, -- price list nullified on account level data
			 (SELECT hp.jgzz_fiscal_code
			  FROM   hz_parties       hp,
			         hz_cust_accounts hca
			  WHERE  hca.party_id = hp.party_id
			  AND    hp.jgzz_fiscal_code IS NOT NULL
			  AND    hca.cust_account_id =
			         p_cust_account_id),
			 cust_status,
			 ecom_restricted_view)
    INTO   l_customer_account_rec
    FROM   (SELECT hca.cust_account_id cust_account_id,
	       nvl((SELECT hop.organization_name_phonetic
	           FROM   hz_organization_profiles hop
	           WHERE  hop.party_id = hp.party_id),
	           hp.party_name) party_name,
	       hca.account_number account_number,
	       nvl((SELECT 'A'
	           FROM   dual
	           WHERE  hca.status = 'A'
	           AND    hp.status = 'A'),
	           'I') cust_status,
	       nvl(hca.attribute20,
	           fnd_profile.value('XXOM_ECOM_RESTRICTED_VIEW')) ecom_restricted_view
	FROM   hz_cust_accounts hca,
	       hz_parties       hp
	WHERE  hca.party_id = hp.party_id
	AND    hca.cust_account_id = p_cust_account_id);
  
    RETURN l_customer_account_rec;
  END generate_account_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to handle account event and message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee             CHG0043798 - Change calls to send_mail and
  --                                                     process_event in exception block to autonomous
  --                                                     mode
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_account_new(p_cust_account_id IN NUMBER) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    l_err_message VARCHAR2(4000);
  
    l_account_reactive VARCHAR2(10);
  
    CURSOR cur_site(p_cust_account_id IN NUMBER) IS
      SELECT hcsua.site_use_id
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps,
	 hz_locations           hl,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua,
	 fnd_territories_vl     ftv
      WHERE  hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
	--AND hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hca.cust_account_id = p_cust_account_id;
  
    CURSOR cur_contact(p_cust_account_id IN NUMBER) IS
      SELECT hcar.cust_account_role_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_party_sites        hps,
	 hz_locations          hl,
	 fnd_territories_vl    ftv,
	 hz_org_contacts       hoc
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
	--AND hr.relationship_code = 'CONTACT_OF'
      AND    hp_cust.party_type = 'ORGANIZATION'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hca.cust_account_id = p_cust_account_id;
  BEGIN
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_account_entity_name;
    l_xxssys_event_rec.entity_id       := p_cust_account_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
  
    l_xxssys_event_rec.event_message := xmltype(generate_account_data(p_cust_account_id))
			    .getclobval();
  
    l_account_reactive := is_account_being_reactivated(p_cust_account_id);
  
    IF l_account_reactive = 'TRUE' THEN
      -- Event generation for account sites
      FOR site_rec IN cur_site(p_cust_account_id) LOOP
        handle_site_new(site_rec.site_use_id, 'INSERT');
      END LOOP;
    
      -- Event generation for account contacts
      FOR contact_rec IN cur_contact(p_cust_account_id) LOOP
        handle_contact_new(contact_rec.cust_account_role_id, 'INSERT');
      END LOOP;
    END IF;
  
    xxssys_event_pkg.process_event(p_xxssys_event_rec => l_xxssys_event_rec);
  
    -- re-generate events for all ecom contacts. This is to make sure PL changes if any gets reflected in contacts
    IF l_account_reactive <> 'TRUE' THEN
      regen_ecom_contact_events(p_cust_account_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      /* Below portion will insert an event in ERR status */
      l_xxssys_event_rec.status      := 'ERR';
      l_xxssys_event_rec.err_message := substr(SQLERRM, 1, 2000);
      --xxssys_event_pkg.process_event(l_xxssys_event_rec);  -- CHG0043798 commented
      xxssys_event_pkg.process_event_autonomous(l_xxssys_event_rec); -- CHG0043798 added
    
      g_account_number := fetch_accnt_num(l_xxssys_event_rec.entity_id);
      g_time           := SYSDATE;
    
      --send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',  -- CHG0043798 commented
      send_mail_autonomous('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO', -- CHG0043798 added
		   'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
		   'Customer Interface',
		   'The following unexpected exception occurred for Customer interface event processor.' ||
		   chr(13) || chr(10) ||
		   'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
		   chr(13) || chr(10) || chr(10) ||
		   'Failed record details: ' || chr(13) || chr(10) ||
		   '  Account ID: ' || l_xxssys_event_rec.entity_id ||
		   chr(13) || chr(10) || '  Account Number : ' ||
		   g_account_number || chr(13) || chr(10) ||
		   '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
		   chr(10) || '  Error Time: ' || g_time || chr(13) ||
		   chr(10) || 'Procedure :' ||
		   'xxhz_ecomm_event_pkg.handle_account_new');
  END handle_account_new;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This function generate and return Customer-Relationship data for a given cust_account_id
  --          and related_cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                        Description
  -- 1.0  08/05/2018  Diptasurjya Chatterjee      Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION generate_relationship_data(p_cust_account_id    IN NUMBER,
			  p_rltd_cust_accnt_id IN NUMBER,
			  p_org_id             IN NUMBER)
    RETURN xxhz_customer_acct_rel_rec IS
  
    l_customer_acct_rel_rec xxhz_customer_acct_rel_rec;
  BEGIN
    BEGIN
      SELECT xxhz_customer_acct_rel_rec(NULL,
			    hcara.related_cust_account_id,
			    hcara.cust_account_id,
			    hcara.org_id,
			    hcara.status) -- BULK COLLECT
      INTO   l_customer_acct_rel_rec
      FROM   hz_cust_acct_relate_all hcara
      WHERE  cust_account_id = p_cust_account_id
      AND    related_cust_account_id = p_rltd_cust_accnt_id
      AND    org_id = p_org_id;
    EXCEPTION
      WHEN too_many_rows THEN
        BEGIN
          SELECT xxhz_customer_acct_rel_rec(NULL,
			        hcara.related_cust_account_id,
			        hcara.cust_account_id,
			        hcara.org_id,
			        hcara.status) -- BULK COLLECT
          INTO   l_customer_acct_rel_rec
          FROM   hz_cust_acct_relate_all hcara
          WHERE  cust_account_id = p_cust_account_id
          AND    related_cust_account_id = p_rltd_cust_accnt_id
          AND    org_id = p_org_id
          AND    status = 'A'
          AND    rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
	SELECT xxhz_customer_acct_rel_rec(NULL,
			          aa.related_cust_account_id,
			          aa.cust_account_id,
			          aa.org_id,
			          aa.status) -- BULK COLLECT
	INTO   l_customer_acct_rel_rec
	FROM   (SELECT *
	        FROM   hz_cust_acct_relate_all hcara
	        WHERE  cust_account_id = p_cust_account_id
	        AND    related_cust_account_id = p_rltd_cust_accnt_id
	        AND    org_id = p_org_id
	        ORDER  BY last_update_date DESC) aa
	WHERE  rownum = 1;
        END;
    END;
    RETURN l_customer_acct_rel_rec;
  END generate_relationship_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will be used to handle site event and message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             CHG0042626 - Initial Build
  -- 1.1  12/12/2018  Diptasurjya Chatterjee             CHG0043798 - Change calls to send_mail and
  --                                                     process_event in exception block to autonomous
  --                                                     mode
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_acct_relationship_new(p_cust_account_id       IN NUMBER,
			     p_reltd_cust_account_id IN NUMBER,
			     p_org_id                IN NUMBER) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_acct_relation_entity_name;
    l_xxssys_event_rec.entity_id       := p_reltd_cust_account_id; -- CHG0036450 : Tagore
    l_xxssys_event_rec.attribute1      := p_cust_account_id; -- CHG0036450 : Tagore
    l_xxssys_event_rec.attribute2      := p_org_id;
    l_xxssys_event_rec.event_name      := g_eventname;
    l_xxssys_event_rec.last_updated_by := g_user_id;
    l_xxssys_event_rec.created_by      := g_user_id;
    l_xxssys_event_rec.event_message   := xmltype(generate_relationship_data(p_cust_account_id, p_reltd_cust_account_id, p_org_id))
			      .getclobval();
  
    xxssys_event_pkg.process_event(p_xxssys_event_rec => l_xxssys_event_rec);
  EXCEPTION
    WHEN OTHERS THEN
      /* Below portion will insert an event in ERR status */
      l_xxssys_event_rec.status      := 'ERR';
      l_xxssys_event_rec.err_message := substr(SQLERRM, 1, 2000);
      --xxssys_event_pkg.process_event(l_xxssys_event_rec);  -- CHG0043798 commented
      xxssys_event_pkg.process_event_autonomous(l_xxssys_event_rec); -- CHG0043798 added
    
      g_account_number := fetch_accnt_num(l_xxssys_event_rec.attribute1);
      g_time           := SYSDATE;
    
      --send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',  -- CHG0043798 commented
      send_mail_autonomous('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO', -- CHG0043798 added
		   'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
		   'Customer Interface',
		   'The following unexpected exception occurred for Customer relation interface event processor.' ||
		   chr(13) || chr(10) ||
		   'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
		   chr(13) || chr(10) || chr(10) ||
		   'Failed record details: ' || chr(13) || chr(10) ||
		   '  Account ID: ' ||
		   l_xxssys_event_rec.attribute1 || chr(13) ||
		   chr(10) || '  Related Account ID: ' ||
		   l_xxssys_event_rec.entity_id || chr(13) ||
		   chr(10) || '  Org ID: ' ||
		   l_xxssys_event_rec.attribute2 || chr(13) ||
		   chr(10) || '  Account Number : ' ||
		   g_account_number || chr(13) || chr(10) ||
		   '  Error: UNEXPECTED: ' || SQLERRM || chr(13) ||
		   chr(10) || '  Error Time: ' || g_time);
  END handle_acct_relationship_new;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This procedure will handle customer account merge event generation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                        Description
  -- 1.0  06/18/2018  Diptasurjya Chatterjee      Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_account_merge(p_customer_merge_header_id IN NUMBER) IS
  
    CURSOR cur_account_merge IS
      SELECT hca.cust_account_id,
	 hca.account_number,
	 hca_dup.cust_account_id dup_cust_account_id,
	 hca_dup.account_number  dup_account_number,
	 rcm.process_flag
      FROM   ra_customer_merge_headers rcm,
	 hz_cust_accounts          hca,
	 hz_cust_accounts          hca_dup
      WHERE  rcm.customer_id = hca.cust_account_id
      AND    rcm.duplicate_id = hca_dup.cust_account_id
      AND    rcm.customer_merge_header_id = p_customer_merge_header_id;
  
    CURSOR cur_site(p_cust_account_id IN NUMBER) IS
      SELECT hcsua.site_use_id
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps,
	 hz_locations           hl,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua,
	 fnd_territories_vl     ftv
      WHERE  hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
	--AND hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hca.cust_account_id = p_cust_account_id;
  
    CURSOR cur_contact(p_cust_account_id IN NUMBER) IS
      SELECT hcar.cust_account_role_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_party_sites        hps,
	 hz_locations          hl,
	 fnd_territories_vl    ftv,
	 hz_org_contacts       hoc
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
	--AND hr.relationship_code = 'CONTACT_OF'
      AND    hp_cust.party_type = 'ORGANIZATION'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hca.cust_account_id = p_cust_account_id;
  
    CURSOR cur_relation(p_cust_account_id IN NUMBER) IS
      SELECT hcara.related_cust_account_id,
	 hcara.cust_account_id,
	 hcara.org_id
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.cust_account_id = p_cust_account_id;
  
    CURSOR cur_rev_relation(p_cust_account_id IN NUMBER) IS
      SELECT hcara.related_cust_account_id,
	 hcara.cust_account_id,
	 hcara.org_id
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.related_cust_account_id = p_cust_account_id;
  
    l_main_acct_ecom     VARCHAR2(10);
    l_main_acct_rel_ecom VARCHAR2(10);
    l_xxssys_event_rec   xxssys_events%ROWTYPE;
  
    l_contact_id NUMBER;
  
  BEGIN
    FOR rec_account_merge IN cur_account_merge LOOP
      --dbms_output.put_line('In Loop: '||rec_account_merge.cust_account_id||' '||rec_account_merge.dup_cust_account_id||' '||rec_account_merge.process_flag);
      -- Event generation for main account
      handle_account_new(rec_account_merge.cust_account_id);
    
      -- Event generation for duplicate account
      handle_account_new(rec_account_merge.dup_cust_account_id);
    
      -- Event generation for main account sites
      FOR site_rec IN cur_site(rec_account_merge.cust_account_id) LOOP
        handle_site_new(site_rec.site_use_id);
      END LOOP;
    
      -- Event generation for duplicate account sites
      FOR site_rec IN cur_site(rec_account_merge.dup_cust_account_id) LOOP
        handle_site_new(site_rec.site_use_id);
      END LOOP;
    
      -- Event generation for main account contacts
      FOR contact_rec IN cur_contact(rec_account_merge.cust_account_id) LOOP
        handle_contact_new(contact_rec.cust_account_role_id);
      END LOOP;
    
      -- Event generation for duplicate account contacts
      FOR contact_rec IN cur_contact(rec_account_merge.dup_cust_account_id) LOOP
        handle_contact_new(contact_rec.cust_account_role_id);
      END LOOP;
    
      -- Event generation for main account relations
      FOR relation_rec IN cur_relation(rec_account_merge.cust_account_id) LOOP
        handle_acct_relationship_new(relation_rec.cust_account_id,
			 relation_rec.related_cust_account_id,
			 relation_rec.org_id);
      END LOOP;
    
      -- Generate reverse relation events
      FOR relation_rec IN cur_rev_relation(rec_account_merge.cust_account_id) LOOP
        handle_acct_relationship_new(relation_rec.cust_account_id,
			 relation_rec.related_cust_account_id,
			 relation_rec.org_id);
      END LOOP;
    
      -- Event generation for duplicate account relations
      FOR relation_rec IN cur_relation(rec_account_merge.dup_cust_account_id) LOOP
        handle_acct_relationship_new(relation_rec.cust_account_id,
			 relation_rec.related_cust_account_id,
			 relation_rec.org_id);
      END LOOP;
    
      -- Generate reverse relation events
      FOR relation_rec IN cur_rev_relation(rec_account_merge.dup_cust_account_id) LOOP
        handle_acct_relationship_new(relation_rec.cust_account_id,
			 relation_rec.related_cust_account_id,
			 relation_rec.org_id);
      END LOOP;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      g_time := SYSDATE;
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface',
	    'The following unexpected exception occurred for Customer Merge interface event processor.' ||
	    chr(13) || chr(10) ||
	    'Note that a user account will not be created for this user as long as this failure is not fixed. ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Merge Account header ID: ' ||
	    p_customer_merge_header_id || chr(13) || chr(10) ||
	    '  Error: UNEXPECTED: ' || SQLERRM || chr(13) || chr(10) ||
	    '  Error Time: ' || g_time);
  END handle_account_merge;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to find the customer account for a given site_use_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- -----------------------------------------------------------------------------
  PROCEDURE handle_site_use_account(p_site_use_id NUMBER) IS
  
    CURSOR cur_account IS
      SELECT hcasa.cust_account_id cust_account_id
      FROM   hz_locations           hl,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua
      WHERE  hcsua.site_use_id = p_site_use_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcasa.org_id
	  AND    hru.attribute7 = 'Y');
  
  BEGIN
    FOR i IN cur_account LOOP
      handle_account(i.cust_account_id);
    
    END LOOP;
  END handle_site_use_account;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - INC0102454
  --          This function is used to find ecom relations for a given site_use_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  09/19/2017  Diptasurjya Chatterjee             Initial Build
  -- -----------------------------------------------------------------------------
  PROCEDURE handle_site_use_relations(p_site_use_id NUMBER) IS
  
    CURSOR cur_relations IS
      SELECT hcara.cust_account_id,
	 hcara.related_cust_account_id,
	 hcara.org_id
      FROM   hz_cust_acct_relate_all hcara,
	 hz_cust_site_uses_all   hcsua,
	 hz_cust_acct_sites_all  hcasa
      WHERE  hcsua.site_use_id = p_site_use_id
      AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
      AND    hcasa.cust_account_id = hcara.cust_account_id
      AND    EXISTS (SELECT 1
	  FROM   hr_organization_units hru
	  WHERE  hru.organization_id = hcara.org_id
	  AND    hru.attribute7 = 'Y')
      AND    hcara.status = 'A'
      AND    hcara.ship_to_flag = 'Y'
      AND    xxhz_util.is_ecomm_customer(hcara.related_cust_account_id) =
	 'TRUE';
  
  BEGIN
    FOR i IN cur_relations LOOP
      handle_acct_relationship(i.cust_account_id,
		       i.related_cust_account_id,
		       i.org_id);
    
    END LOOP;
  END handle_site_use_relations;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Location information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_location(p_location_id IN NUMBER) IS
  
    CURSOR cur_site IS
      SELECT DISTINCT hcsua.site_use_id site_use_id
      FROM   hz_locations           hl,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua
      WHERE  hl.location_id = p_location_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      /*AND    EXISTS (SELECT 1
      FROM   hr_organization_units hru
      WHERE  hru.organization_id = hcasa.org_id
      AND    hru.attribute7 = 'Y')*/ -- CHG0042626 -- Remove OU check
      ;
  
    CURSOR cur_contact IS
      SELECT hcar.cust_account_role_id contact_id -- CHG0042626 remove distinct
      FROM   hz_locations          hl,
	 hz_party_sites        hps,
	 hz_relationships      hr,
	 hz_cust_accounts      hca,
	 hz_cust_account_roles hcar
      WHERE  hl.location_id = p_location_id
      AND    hl.location_id = hps.location_id
      AND    hps.party_id = hr.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hca.cust_account_id = hcar.cust_account_id; -- CHG0042626 - join missing
  BEGIN
    FOR i IN cur_site LOOP
      --handle_site(i.site_use_id); -- CHG0042626 commented
      handle_site_new(i.site_use_id); -- CHG0042626
    END LOOP;
  
    FOR i IN cur_contact LOOP
      --handle_contact(i.contact_id); -- CHG0042626 commented
      handle_contact_new(i.contact_id); -- CHG0042626
    END LOOP;
  
  END handle_location;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Party information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_party(p_party_id IN NUMBER) IS
  
    l_accnt_exists VARCHAR2(2) := 'T';
    l_accnt        NUMBER;
    l_cnt          NUMBER := 0;
  
    CURSOR cur_accnt IS
      SELECT hca.cust_account_id cust_account_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hp.party_id = p_party_id;
  
    CURSOR cur_contact IS
      SELECT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts      hca,
	 hz_parties            hp_cont,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hp_cont.party_id = p_party_id
      AND    hcar.cust_account_id = hca.cust_account_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hp_cont.party_id = hr.subject_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.object_type = 'ORGANIZATION'
      AND    hr.relationship_code = 'CONTACT_OF'
      AND    hca.party_id = hr.object_id;
  
  BEGIN
    /*OPEN cur_accnt;
    FETCH cur_accnt
      INTO l_accnt;
    IF cur_accnt%FOUND THEN
      handle_account(l_accnt);
    ELSE
      l_accnt_exists := 'F';
    END IF;
    CLOSE cur_accnt;
    
    IF l_accnt_exists = 'F' THEN
      FOR j IN cur_contact LOOP
        handle_contact(j.contact_id);
      END LOOP;
    END IF;
    
    FOR i IN cur_accnt LOOP
      IF cur_accnt%NOTFOUND THEN
        FOR j IN cur_contact LOOP
          handle_contact(j.contact_id);
        END LOOP;
      ELSE
        handle_account(i.cust_account_id);
      END IF;
    END LOOP;*/
  
    FOR i IN cur_accnt LOOP
      EXIT WHEN cur_accnt%NOTFOUND;
      --handle_account(i.cust_account_id);  -- CHG0042626 commented
      handle_account_new(i.cust_account_id); -- CHG0042626
      l_cnt := l_cnt + 1;
    END LOOP;
  
    IF l_cnt = 0 THEN
      FOR j IN cur_contact LOOP
        --handle_contact(j.contact_id);  -- CHG0042626 commented
        handle_contact_new(j.contact_id); -- CHG0042626
      END LOOP;
    END IF;
  
  END handle_party;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036659
  --          This function is used to handle the Party information for org_update event.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  29/01/2016  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_org_update(p_party_id IN NUMBER) IS
  
    l_accnt_exists VARCHAR2(2) := 'T';
    l_accnt        NUMBER;
    l_cnt          NUMBER := 0;
  
    CURSOR cur_accnt IS
      SELECT hca.cust_account_id cust_account_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hp.party_id = p_party_id;
  
    CURSOR cur_contact IS
      SELECT hcar.cust_account_role_id contact_id --hca.cust_account_id cust_account_id
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_org_contacts       hoc,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hp_cust.party_id = p_party_id;
  
  BEGIN
    FOR i IN cur_accnt LOOP
      --handle_account(i.cust_account_id); -- CHG0042626 commented
      handle_account_new(i.cust_account_id); -- CHG0042626
    END LOOP;
  
    -- CHG0042626 commented - category code sent at contact level , so we need to check all relevant contacts
    FOR j IN cur_contact LOOP
      handle_contact_new(j.contact_id);
    END LOOP;
  
  END handle_org_update;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Party Site information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_party_site(p_party_site_id IN NUMBER) IS
  
    l_exists_site VARCHAR2(1) := 'T';
    l_party_site  NUMBER;
    l_cnt         NUMBER := 0;
  
    CURSOR cur_party_site IS
      SELECT hcsua.site_use_id -- CHG0042626 removed unnecessary alias
      FROM   hz_cust_accounts       hca,
	 hz_party_sites         hps,
	 hz_cust_site_uses_all  hcsua,
	 hz_cust_acct_sites_all hcasa
      WHERE  hps.party_site_id = p_party_site_id
      AND    hps.party_id = hca.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      -- CHG0042626 - Commented below, so as to interface sites for all OU
      /*AND    EXISTS (SELECT 1
      FROM   hr_organization_units hru
      WHERE  hru.organization_id = hcasa.org_id
      AND    hru.attribute7 = 'Y')*/
      ;
  
    CURSOR cur_contact IS
      SELECT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts      hca,
	 hz_party_sites        hps,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hps.party_site_id = p_party_site_id
      AND    hr.party_id = hps.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hca.cust_account_id = hcar.cust_account_id; -- CHG0042626 added join
  
  BEGIN
  
    FOR i IN cur_party_site LOOP
      EXIT WHEN cur_party_site%NOTFOUND;
      --handle_site(i.party_site_id); -- CHG0042626 commented
      handle_site_new(i.site_use_id); -- CHG0042626
      l_cnt := l_cnt + 1;
    END LOOP;
  
    IF l_cnt = 0 THEN
      FOR j IN cur_contact LOOP
        --handle_contact(j.contact_id); -- CHG0042626 commented
        handle_contact_new(j.contact_id); -- CHG0042626
      END LOOP;
    END IF;
  
  END handle_party_site;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the cust_acct_site_id information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_account_site(p_cust_acct_site_id IN NUMBER) IS
  
    CURSOR cur_accnt_site_id IS
      SELECT hcsua.site_use_id
      FROM   hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  hcsua
      WHERE  hcasa.cust_acct_site_id = p_cust_acct_site_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      /*AND    EXISTS (SELECT 1
      FROM   hr_organization_units hru
      WHERE  hru.organization_id = hcasa.org_id
      AND    hru.attribute7 = 'Y')*/ -- CHG0042626 - Remove OU validation
      ;
  BEGIN
    FOR i IN cur_accnt_site_id LOOP
      --handle_site(i.site_use_id);  -- CHG0042626 Commented
      handle_site_new(i.site_use_id); -- CHG0042626 - added
    END LOOP;
  END handle_account_site;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function This function handles cust_account_role_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  07/05/2018  Diptasurjya            CHG0042626 - Interface re-design
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_cust_accnt_role(p_cust_account_role_id IN NUMBER) IS
  
    CURSOR cur_accnt_role IS
      SELECT cust_account_role_id
      FROM   hz_cust_account_roles
      WHERE  cust_account_role_id = p_cust_account_role_id
      AND    cust_acct_site_id IS NULL; -- CHG0042626 added condition
  
  BEGIN
    FOR i IN cur_accnt_role LOOP
      --handle_contact(i.cust_account_role_id);  -- CHG0042626 commented
      handle_contact_new(i.cust_account_role_id); -- CHG0042626 added
    END LOOP;
  
  END handle_cust_accnt_role;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function This function handles org_contact_id info
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_org_contact(p_org_contact_id IN NUMBER) IS
  
    CURSOR cur_org_contact IS
      SELECT hcar.cust_account_role_id cust_account_role_id
      FROM   hz_org_contacts       hoc,
	 hz_relationships      hr,
	 hz_cust_accounts      hca,
	 hz_cust_account_roles hcar
      WHERE  hoc.org_contact_id = p_org_contact_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hca.cust_account_id = hcar.cust_account_id; -- CHG0042626 missing join
  
  BEGIN
    FOR i IN cur_org_contact LOOP
      --handle_contact(i.cust_account_role_id);  -- CHG0042626 commented
      handle_contact_new(i.cust_account_role_id); -- CHG0042626
    END LOOP;
  
  END handle_org_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function This function handles org_contact_id info
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_contact_point(p_contact_point_id IN NUMBER) IS
  
    CURSOR cur_cont_point IS
      SELECT hcar.cust_account_role_id cust_account_role_id
      FROM   hz_contact_points     hcp,
	 hz_cust_accounts      hca,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hcp.contact_point_id = p_contact_point_id
      AND    hcp.owner_table_name = 'HZ_PARTIES'
      AND    hcp.owner_table_id = hr.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.cust_account_id = hca.cust_account_id; -- CHG0042626 missing join
  
  BEGIN
  
    FOR i IN cur_cont_point LOOP
      --handle_contact(i.cust_account_role_id); -- CHG0042626 commented
      handle_contact_new(i.cust_account_role_id); -- CHG0042626
    END LOOP;
  
  END handle_contact_point;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function This function handles role responsibility info
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                   Description
  -- 1.0  11/06/2015  Debarati Banerjee      Initial Build
  -- 1.1  05/08/2018  Diptasurjya            CHG0042626 - change entity handler procedures for new interface design
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_role_resp(p_responsibility_id IN NUMBER) IS
  
    CURSOR cur_role_resp IS
      SELECT hcar.cust_account_role_id cust_account_role_id
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp_cont,
	 hz_relationships       hr,
	 hz_cust_account_roles  hcar,
	 hz_role_responsibility hrr
      WHERE  hcar.cust_account_id = hca.cust_account_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hp_cont.party_id = hr.subject_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.object_type = 'ORGANIZATION'
	--AND    hr.relationship_code = 'CONTACT_OF'
      AND    hca.party_id = hr.object_id
      AND    hrr.cust_account_role_id = hcar.cust_account_role_id
      AND    hrr.responsibility_id = p_responsibility_id;
  
  BEGIN
    FOR i IN cur_role_resp LOOP
      --handle_contact(i.cust_account_role_id); -- CHG0042626 commented
      handle_contact_new(i.cust_account_role_id); -- CHG0042626
    END LOOP;
  
  END handle_role_resp;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0034944
  --          This function fetches related customer account ID for a given cust_acct_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee            Initial Build
  -- --------------------------------------------------------------------------------------------

  /*PROCEDURE handle_account_relationship(p_reltd_cust_account_id IN NUMBER,
                                        p_cust_account_id       IN NUMBER) IS
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_ship_to_flag     VARCHAR2(10);
    l_reciprocal_flag  VARCHAR2(10);
    l_ecomm_cust       VARCHAR2(10);
  
    CURSOR cur_rel_flag IS
      SELECT ship_to_flag,
             customer_reciprocal_flag
      FROM   hz_cust_acct_relate_all hcara
      WHERE  cust_account_id = p_cust_account_id
      AND    related_cust_account_id = p_reltd_cust_account_id;
  
    CURSOR cur_related_site_fwd IS
      SELECT DISTINCT hcsua.site_use_id site_use_id
      FROM   hz_cust_acct_relate_all hcara,
             hz_cust_accounts        hca,
             hz_party_sites          hps,
             hz_cust_acct_sites_all  hcasa,
             hz_cust_site_uses_all   hcsua,
             hz_parties              hp,
             hz_locations            hl,
             fnd_territories_vl      ftv
      WHERE  hca.cust_account_id = hcara.cust_account_id
      AND    hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcsua.site_use_code IN ('SHIP_TO')
      AND    hcasa.org_id = hcsua.org_id
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
      AND    hp.status = 'A'
      AND    hca.status = 'A'
            --AND    hcara.status = 'A'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hcasa.org_id IN (SELECT hro.organization_id
                              FROM   hr_operating_units    hro,
                                     hr_organization_units hru
                              WHERE  hro.organization_id = hru.organization_id
                              AND    hru.attribute7 = 'Y')
      AND    hcara.org_id IN (SELECT hro.organization_id
                              FROM   hr_operating_units    hro,
                                     hr_organization_units hru
                              WHERE  hro.organization_id = hru.organization_id
                              AND    hru.attribute7 = 'Y')
      AND    hcara.ship_to_flag = 'Y'
      AND    hcara.customer_reciprocal_flag = 'Y'
      AND    hcara.related_cust_account_id = p_reltd_cust_account_id
      AND    hcara.cust_account_id = p_cust_account_id
      AND    xxhz_util.is_ecomm_customer(p_reltd_cust_account_id) = 'TRUE';
  
    CURSOR cur_related_site_bwd IS
      SELECT DISTINCT hcsua.site_use_id site_use_id
      FROM   hz_cust_acct_relate_all hcara,
             hz_cust_accounts        hca,
             hz_party_sites          hps,
             hz_cust_acct_sites_all  hcasa,
             hz_cust_site_uses_all   hcsua,
             hz_parties              hp,
             hz_locations            hl,
             fnd_territories_vl      ftv
      WHERE  hca.cust_account_id = hcara.cust_account_id
      AND    hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcsua.site_use_code IN ('SHIP_TO')
      AND    hcasa.org_id = hcsua.org_id
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
      AND    hp.status = 'A'
      AND    hca.status = 'A'
            --AND    hcara.status = 'A'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hcasa.org_id IN (SELECT hro.organization_id
                              FROM   hr_operating_units    hro,
                                     hr_organization_units hru
                              WHERE  hro.organization_id = hru.organization_id
                              AND    hru.attribute7 = 'Y')
      AND    hcara.org_id IN (SELECT hro.organization_id
                              FROM   hr_operating_units    hro,
                                     hr_organization_units hru
                              WHERE  hro.organization_id = hru.organization_id
                              AND    hru.attribute7 = 'Y')
            --AND hcara.ship_to_flag='Y'
            --AND hcara.customer_reciprocal_flag = 'Y'
      AND    hcara.related_cust_account_id = p_cust_account_id
      AND    hcara.cust_account_id = p_reltd_cust_account_id
      AND    xxhz_util.is_ecomm_customer(p_cust_account_id) = 'TRUE';
  
    CURSOR cur_related_contact_fwd IS
      SELECT DISTINCT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts           hca,
             hz_cust_account_roles      hcar,
             hz_relationships           hr,
             hz_cust_acct_relate_all    hcara,
             hz_parties                 hp_contact,
             hz_parties                 hp_cust,
             hz_org_contacts            hoc,
             hz_party_sites             hps,
             hz_locations               hl,
             fnd_territories_vl         ftv,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_email_contact_point_v xecpv
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
      AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
      AND    hcar.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
      AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
            --AND hcara.ship_to_flag = 'Y'
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
            --AND hcara.org_id = p_org_id
            --AND hcar.cust_account_role_id = nvl(p_cust_contact_id,hcar.cust_account_role_id)
      AND    hcara.cust_account_id = p_cust_account_id
      AND    hca.cust_account_id = hcara.cust_account_id
      AND    hcara.related_cust_account_id =
             nvl(p_reltd_cust_account_id, hcara.related_cust_account_id)
      AND    xxhz_util.is_ecomm_customer(p_reltd_cust_account_id) = 'TRUE';
  
    CURSOR cur_related_contact_bwd IS
      SELECT DISTINCT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts           hca,
             hz_cust_account_roles      hcar,
             hz_relationships           hr,
             hz_cust_acct_relate_all    hcara,
             hz_parties                 hp_contact,
             hz_parties                 hp_cust,
             hz_org_contacts            hoc,
             hz_party_sites             hps,
             hz_locations               hl,
             fnd_territories_vl         ftv,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_email_contact_point_v xecpv
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
      AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
      AND    hcar.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
      AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
            --AND hcara.ship_to_flag = 'Y'
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
            --AND hcara.org_id = p_org_id
            --AND hcar.cust_account_role_id = nvl(p_cust_contact_id,hcar.cust_account_role_id)
      AND    hcara.cust_account_id = p_reltd_cust_account_id
      AND    hca.cust_account_id = hcara.cust_account_id
      AND    hcara.related_cust_account_id =
             nvl(p_cust_account_id, hcara.related_cust_account_id)
      AND    xxhz_util.is_ecomm_customer(p_cust_account_id) = 'TRUE';
  BEGIN
  
    OPEN cur_rel_flag;
    FETCH cur_rel_flag
      INTO l_ship_to_flag, l_reciprocal_flag;
    CLOSE cur_rel_flag;
  
    FOR i IN cur_related_site_fwd LOOP
  
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_site_entity_name;
      l_xxssys_event_rec.entity_id       := i.site_use_id;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
      l_xxssys_event_rec.attribute1      := p_reltd_cust_account_id;
      l_xxssys_event_rec.attribute2      := p_cust_account_id;
      l_xxssys_event_rec.active_flag     := 'Y';
  
      xxssys_event_pkg.insert_event(l_xxssys_event_rec);
    END LOOP;
  
    IF l_ship_to_flag = 'Y' AND l_reciprocal_flag = 'Y' THEN
  
      FOR m IN cur_related_site_bwd LOOP
  
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := g_site_entity_name;
        l_xxssys_event_rec.entity_id       := m.site_use_id;
        l_xxssys_event_rec.event_name      := g_eventname;
        l_xxssys_event_rec.last_updated_by := g_user_id;
        l_xxssys_event_rec.created_by      := g_user_id;
        l_xxssys_event_rec.attribute1      := p_cust_account_id;
        l_xxssys_event_rec.attribute2      := p_reltd_cust_account_id;
        l_xxssys_event_rec.active_flag     := 'Y';
  
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      END LOOP;
    END IF;
  
    FOR j IN cur_related_contact_fwd LOOP
  
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_contact_entity_name;
      l_xxssys_event_rec.entity_id       := j.contact_id;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
      l_xxssys_event_rec.attribute1      := p_reltd_cust_account_id;
      l_xxssys_event_rec.attribute2      := p_cust_account_id;
      l_xxssys_event_rec.active_flag     := 'Y';
  
      xxssys_event_pkg.insert_event(l_xxssys_event_rec);
    END LOOP;
  
    IF l_ship_to_flag = 'Y' AND l_reciprocal_flag = 'Y' THEN
  
      FOR n IN cur_related_contact_bwd LOOP
  
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := g_contact_entity_name;
        l_xxssys_event_rec.entity_id       := n.contact_id;
        l_xxssys_event_rec.event_name      := g_eventname;
        l_xxssys_event_rec.last_updated_by := g_user_id;
        l_xxssys_event_rec.created_by      := g_user_id;
        l_xxssys_event_rec.attribute1      := p_cust_account_id;
        l_xxssys_event_rec.attribute2      := p_reltd_cust_account_id;
        l_xxssys_event_rec.active_flag     := 'Y';
  
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      END LOOP;
    END IF;
  
  END handle_account_relationship;*/

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This function checks Customer-Printer status of existing records.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                           Description
  -- 1.0  07/07/2015  Kundan Bhagat                  Initial Build
  -- 1.1  8/6/2017    yuval tal                      CHG0040839   modify customer_printer_process Add s/n information and printers which exist for ecom related customers
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_printer_status(p_cust_account_id IN NUMBER,
		        p_item_id         IN NUMBER,
		        p_serial_number   VARCHAR2,
		        p_instance_id     NUMBER) RETURN VARCHAR2 IS
    l_printer_status VARCHAR2(1);
  BEGIN
    SELECT print_status.active_flag
    INTO   l_printer_status
    FROM   (SELECT xe.active_flag,
	       xe.event_id,
	       MAX(xe.event_id) over(PARTITION BY xe.entity_id, xe.attribute1) max_event_id
	FROM   xxssys_events xe
	WHERE  xe.entity_id = p_cust_account_id
	AND    xe.attribute1 = p_item_id
	AND    xe.attribute2 = p_serial_number
	AND    xe.attribute3 = to_char(p_instance_id)
	AND    xe.entity_name = g_printer_entity_name
	AND    xe.status IN ('NEW', 'SUCCESS')
	AND    target_name = g_target_name --INC0123738
	) print_status
    WHERE  print_status.event_id = print_status.max_event_id;
  
    RETURN l_printer_status;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END check_printer_status;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This function checks Account status for customer-printer interface.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  08/10/2015  Kundan Bhagat                 Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_account_status(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_acc_status VARCHAR2(10);
  BEGIN
  
    SELECT acc_status.status
    INTO   l_acc_status
    FROM   (SELECT xe.status,
	       xe.event_id,
	       MAX(xe.event_id) over(PARTITION BY xe.entity_id) max_event_id
	FROM   xxssys_events xe
	WHERE  xe.entity_id = p_cust_account_id
	AND    xe.entity_name = g_account_entity_name
	AND    target_name = g_target_name --INC0123738
	) acc_status
    WHERE  acc_status.event_id = acc_status.max_event_id;
  
    IF l_acc_status IN ('SUCCESS') THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END check_account_status;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function will be used as Rule function for all activated business events
  --          for customer creation or update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  09/25/2015  Diptasurjya Chatterjee        CHG0036450 - Add call to generate relationship events for
  --                                                relationship business events
  -- 1.2  09/19/2017  Diptasurjya Chatterjee        INC0102454 - Call the procedure handle_site_use_relations
  --                                                when CustAcctSiteUse (create/update) event is fired
  -- --------------------------------------------------------------------------------------------

  FUNCTION customer_event_process(p_subscription_guid IN RAW,
		          p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2 IS
    l_message VARCHAR2(4000);
  
    l_eventname           VARCHAR2(200);
    l_wf_parameter_list_t wf_parameter_list_t;
    l_parameter_name      VARCHAR2(30);
    l_parameter_value     VARCHAR2(4000);
    l_parameter_name1     VARCHAR2(30);
    l_parameter_value1    VARCHAR2(4000);
    l_attribute1          NUMBER;
    l_attribute2          NUMBER;
  
    n_total_number_of_parameters INTEGER;
    n_current_parameter_position NUMBER := 1;
  
  BEGIN
    l_wf_parameter_list_t        := p_event.getparameterlist();
    n_total_number_of_parameters := l_wf_parameter_list_t.count();
  
    l_eventname := p_event.geteventname();
    g_eventname := p_event.geteventname();
    g_user_id   := p_event.getvalueforparameter('USER_ID');
    g_resp_id   := p_event.getvalueforparameter('RESP_ID');
    g_appl_id   := p_event.getvalueforparameter('RESP_APPL_ID');
  
    xxssys_event_pkg.write_log('Inside event processor');
  
    IF l_eventname = 'oracle.apps.ar.hz.Person.create' OR
       l_eventname = 'oracle.apps.ar.hz.Person.update' THEN
    
      l_parameter_name  := 'PARTY_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_party(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.Organization.create' OR
          l_eventname = 'oracle.apps.ar.hz.Organization.update' THEN
    
      l_parameter_name  := 'PARTY_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_org_update(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.PartySite.create' OR
          l_eventname = 'oracle.apps.ar.hz.PartySite.update' THEN
    
      l_parameter_name  := 'PARTY_SITE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_party_site(l_parameter_value);
    
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAccount.create' OR
          l_eventname = 'oracle.apps.ar.hz.CustAccount.update' THEN
    
      l_parameter_name  := 'CUST_ACCOUNT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      --handle_account(l_parameter_value);  -- CHG0042626 - Commented
      handle_account_new(l_parameter_value); -- CHG0042626 - added
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAcctSite.create' OR
          l_eventname = 'oracle.apps.ar.hz.CustAcctSite.update' THEN
    
      l_parameter_name  := 'CUST_ACCT_SITE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_account_site(l_parameter_value);
    
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAcctSiteUse.create' OR
          l_eventname = 'oracle.apps.ar.hz.CustAcctSiteUse.update' THEN
    
      l_parameter_name  := 'SITE_USE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      --handle_site(l_parameter_value); -- CHG0042626 - Commented
      handle_site_new(l_parameter_value); -- CHG0042626 - added
    
      --handle_site_use_relations(l_parameter_value); -- INC0102454
    
      --handle_site_use_account(l_parameter_value);
    
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAcctRelate.create' OR
          l_eventname = 'oracle.apps.ar.hz.CustAcctRelate.update' THEN
    
      l_parameter_name  := 'RELATED_CUST_ACCOUNT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
      l_attribute1      := p_event.getvalueforparameter('CUST_ACCOUNT_ID');
      -- Start Go-Live 3 Relation
      l_attribute2 := p_event.getvalueforparameter('ORG_ID');
      xxssys_event_pkg.write_log('Before calling the proc');
      xxssys_event_pkg.write_log('Before calling the proc cust id : ' ||
		         l_attribute1);
      xxssys_event_pkg.write_log('Before calling the proc rel cust id : ' ||
		         l_parameter_value);
    
      -- handle_acct_relationship(l_parameter_value, l_attribute1, l_attribute2);         -- CHG0036450 : Tagore
      --handle_acct_relationship(l_attribute1, l_parameter_value, l_attribute2); -- CHG0036450 : Tagore  -- CHG0042626 commented
      -- End Go-Live 3 Relation
      handle_acct_relationship_new(l_attribute1,
		           l_parameter_value,
		           l_attribute2); -- CHG0042626
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAccountRole.create' OR
          l_eventname = 'oracle.apps.ar.hz.CustAccountRole.update' THEN
    
      l_parameter_name  := 'CUST_ACCOUNT_ROLE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_cust_accnt_role(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.OrgContact.create' OR
          l_eventname = 'oracle.apps.ar.hz.OrgContact.update' THEN
    
      l_parameter_name  := 'ORG_CONTACT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_org_contact(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.Location.create' OR
          l_eventname = 'oracle.apps.ar.hz.Location.update' THEN
    
      l_parameter_name  := 'LOCATION_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_location(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.ContactPoint.create' OR
          l_eventname = 'oracle.apps.ar.hz.ContactPoint.update' THEN
    
      l_parameter_name  := 'CONTACT_POINT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_contact_point(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.RoleResponsibility.create' OR
          l_eventname = 'oracle.apps.ar.hz.RoleResponsibility.update' THEN
    
      l_parameter_name  := 'RESPONSIBILITY_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_role_resp(l_parameter_value);
    ELSIF l_eventname = 'oracle.apps.ar.hz.CustAccount.merge' THEN
    
      l_parameter_name  := 'customer_merge_header_id';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_account_merge(l_parameter_value);
      --END IF;
    END IF;
  
    WHILE (n_current_parameter_position <= n_total_number_of_parameters) LOOP
      l_parameter_name1            := l_wf_parameter_list_t(n_current_parameter_position)
			  .getname();
      l_parameter_value1           := l_wf_parameter_list_t(n_current_parameter_position)
			  .getvalue();
      l_message                    := l_message || chr(13) ||
			  'Parameter Name: ' ||
			  l_parameter_name1 ||
			  ' Parameter Value: ' ||
			  l_parameter_value1;
      n_current_parameter_position := n_current_parameter_position + 1;
    END LOOP;
  
    RETURN 'SUCCESS';
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('xxhz_ecomm_event_pkg',
	          'function subscription',
	          p_event.geteventname(),
	          p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'ERROR');
    
      RETURN 'ERROR';
    
  END customer_event_process;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to insert records in xxssys_event table.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                      CHG0035650 - Initial Build
  -- 1.1  26/11/2015  Kundan Bhagat                      CHG0036749 -Adjust Ecommerce customer printer interface
  --                                                     to send end customer printers
  -- 1.2  25/01/2016  Kundan Bhagat                      CHG0036749 - Commented code related to cur_inactive_rec cursor
  --
  -- 1.3  25/05/2017  yuval tal                          CHG0040839   add information and printers which exist for ecom related customers
  --                                                                 to resolve performance issue.
  --                                                                 add is_account_related_to_ecom to logic ,
  --                                                                 restrict non printers item
  -- 1.4  07/09/2018  Diptasurjya                        CHG0042626 - Add a condition to check if account was interfaced earlier
  -- 1.4.1 28.3.19    Yuval tal                          INC0152106  - modify cursor to use new copyStorm tables
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_printer_process(x_errbuf  OUT VARCHAR2,
			 x_retcode OUT NUMBER) AS
    --  INC0152106
    CURSOR cur_cust_printer IS
    
      SELECT hzacc.cust_account_id,
	 aa.item_code,
	 aa.serial_number,
	 aa.instance_id,
	 SUM(decode(aa.terminated_flag, 'N', 1, 0)) active
      FROM   (SELECT nvl(sf_acc2.external_key__c,
		 sf_acc.external_key__c /*xibc.account_oeid__c*/) cust_account_number,
	         sf_prd.external_key__c item_code,
	         cis.terminated_flag terminated_flag,
	         xibc.end_customer__c,
	         xibc.serialnumber serial_number, --CHG0040839
	         xibc.external_key__c instance_id --CHG0040839
	  FROM   asset@source_sf2          xibc,
	         xxsf2_product2            sf_prd,
	         xxsf2_account             sf_acc2,
	         csi.csi_instance_statuses cis,
	         xxcs_items_printers_v     pr,
	         xxsf2_account             sf_acc
	  
	  WHERE  sf_acc.id = xibc.accountid
	  AND    pr.item = sf_prd.external_key__c
	  AND    sf_acc2.id(+) = xibc.end_customer__c
	  AND    sf_prd.id = xibc.product2id
	  AND    cis.name = xibc.status
	  AND    sf_prd.external_key__c IS NOT NULL
	  AND    xibc.external_key__c IS NOT NULL
	  AND    xibc.serialnumber IS NOT NULL
	        
	  AND    xibc.status IN ('Installed', 'Shipped')) aa -- CHG0042626 - New filter added
	,
	 hz_cust_accounts hzacc
      WHERE  hzacc.account_number = aa.cust_account_number
      AND    aa.cust_account_number != 'testAccount'
      AND    aa.cust_account_number IS NOT NULL
	-- CHG0042626 - Add below check to prevent generation of
	-- Customer printer events when account is not active in Oracle
      AND    EXISTS
       (SELECT 1
	  FROM   hz_cust_accounts hca,
	         hz_parties       hp
	  WHERE  hca.account_number = aa.cust_account_number
	        -- hca.cust_account_id = aa.cust_account_id
	  AND    hca.party_id = hp.party_id
	  AND    hca.status = 'A'
	  AND    hp.status = 'A')
      GROUP  BY cust_account_id,
	    item_code,
	    serial_number,
	    instance_id;
    -- end INC0152106
  
    /*  SELECT aa.cust_account_id,
             aa.inventory_item_id,
             aa.serial_number,
             aa.instance_id,
             SUM(decode(aa.terminated_flag, 'N', 1, 0)) active
      FROM   (SELECT nvl(sf_acc2.oe_id__c, xibc.account_oeid__c) cust_account_id,
                     sf_prd.oe_id__c inventory_item_id,
                     cis.terminated_flag terminated_flag,
                     xibc.end_customer__c,
                     xibc.serial_number__c serial_number, --CHG0040839
                     xibc.oe_id__c instance_id --CHG0040839
              FROM   xxsf_install_base__c      xibc,
                     xxsf_product2             sf_prd,
                     xxsf_account              sf_acc2,
                     csi.csi_instance_statuses cis,
                     xxcs_items_printers_v     pr
              WHERE  pr.inventory_item_id = sf_prd.oe_id__c
              AND    sf_acc2.id(+) = xibc.end_customer__c
              AND    sf_prd.id = xibc.product__c
              AND    cis.name = xibc.status__c
              AND    sf_prd.oe_id__c IS NOT NULL
              AND    xibc.oe_id__c IS NOT NULL
              AND    xibc.serial_number__c IS NOT NULL
    AND    xibc.STATUS__c in ('Installed','Shipped')) aa -- CHG0042626 - New filter added
      WHERE  aa.cust_account_id != 'testAccount'
      AND    aa.cust_account_id IS NOT NULL
      -- CHG0042626 - Add below check to prevent generation of
      -- Customer printer events when account is not active in Oracle
      AND exists (select 1
                    from hz_cust_accounts hca,
                         hz_parties hp
                   where hca.cust_account_id = aa.cust_account_id
                     and hca.party_id = hp.party_id
                     and hca.status = 'A'
                     and hp.status = 'A')
      GROUP  BY cust_account_id,
                inventory_item_id,
                serial_number,
                instance_id;*/
  
    l_ecom_cust_flag     VARCHAR2(10);
    l_xxssys_event_rec   xxssys_events%ROWTYPE;
    l_request_id         NUMBER := fnd_global.conc_request_id;
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status             VARCHAR2(1);
    l_old_status         VARCHAR2(1);
    l_eventname          VARCHAR2(20) := 'BATCH';
    l_acc_status         VARCHAR2(10);
    l_found              NUMBER := 0;
    l_rec_count          NUMBER := 1;
    l_valid_number       NUMBER;
  
    TYPE customer_printer_rec IS RECORD(
      cust_account_id   NUMBER,
      inventory_item_id NUMBER,
      serial_number     VARCHAR2(240), --CHG0040839
      instance_id       NUMBER); --CHG0040839
    TYPE customer_printer_tab IS TABLE OF customer_printer_rec;
    l_customer_printer_rec customer_printer_tab;
  
    TYPE event_rec IS RECORD(
      cust_id       NUMBER,
      item_id       NUMBER,
      event_id      NUMBER,
      serial_number VARCHAR2(240), --CHG0040839
      instance_id   VARCHAR2(240)); --CHG0040839
    TYPE event_tab IS TABLE OF event_rec;
    l_events_rec event_tab;
  BEGIN
  
    SELECT fcrsv.requested_by,
           fcrsv.program_short_name
    INTO   l_requestor,
           l_program_short_name
    FROM   fnd_conc_req_summary_v fcrsv
    WHERE  fcrsv.request_id = l_request_id;
  
    l_customer_printer_rec := customer_printer_tab();
  
    FOR i IN cur_cust_printer LOOP
      BEGIN
        l_valid_number := to_number(i.cust_account_id);
        l_customer_printer_rec.extend();
        l_customer_printer_rec(l_rec_count).cust_account_id := i.cust_account_id;
        --  l_customer_printer_rec(l_rec_count).inventory_item_id := i.inventory_item_id;--INC0152106
      
        l_customer_printer_rec(l_rec_count).inventory_item_id := xxinv_utils_pkg.get_item_id(i.item_code); ----INC0152106
      
        l_customer_printer_rec(l_rec_count).serial_number := i.serial_number; --CHG0040839
        l_customer_printer_rec(l_rec_count).instance_id := i.instance_id; --CHG0040839
        l_rec_count := l_rec_count + 1;
        l_ecom_cust_flag := xxhz_util.is_ecomm_customer(i.cust_account_id);
        IF i.active > 0 THEN
          l_status := 'Y';
        ELSE
          l_status := 'N';
        END IF;
      
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := g_printer_entity_name;
        l_xxssys_event_rec.entity_id       := i.cust_account_id;
        l_xxssys_event_rec.event_name      := l_eventname || '-' ||
			          l_program_short_name;
        l_xxssys_event_rec.last_updated_by := l_requestor;
        l_xxssys_event_rec.created_by      := l_requestor;
        --   l_xxssys_event_rec.attribute1      := i.inventory_item_id;--INC0152106
        l_xxssys_event_rec.attribute1 := xxinv_utils_pkg.get_item_id(i.item_code); --INC0152106
      
        l_xxssys_event_rec.attribute2 := i.serial_number; --CHG0040839
        l_xxssys_event_rec.attribute3 := i.instance_id; --CHG0040839
      
        IF (l_ecom_cust_flag = 'TRUE' OR
           is_account_related_to_ecom(i.cust_account_id) = 'TRUE' /*CHG0040839*/
           ) AND l_status = 'Y' THEN
          -- CHG0040839
          l_old_status := check_printer_status(i.cust_account_id,
			           /* i.inventory_item_id*/ --INC0152106
			           l_xxssys_event_rec.attribute1, --INC0152106
			           i.serial_number,
			           i.instance_id);
          --  l_acc_status := check_account_status(i.cust_account_id);
          IF nvl(l_old_status, 'X') <> l_status /*AND l_acc_status = 'TRUE'*/
           THEN
	l_xxssys_event_rec.active_flag := 'Y';
	xxssys_event_pkg.insert_event(l_xxssys_event_rec);
	fnd_file.put_line(fnd_file.log,
		      'eCommerce Customer Account ID : ' || i
		      .cust_account_id || chr(10) ||
		       'eCommerce Inventory Item ID : ' ||
		       l_xxssys_event_rec.attribute1 /* i.inventory_item_id*/); -- INC0152106
	fnd_file.put_line(fnd_file.log,
		      '--------------------------------------');
          END IF;
        ELSE
          -- check if sync is the past
          IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	l_xxssys_event_rec.active_flag := 'N';
	xxssys_event_pkg.insert_event(l_xxssys_event_rec);
	fnd_file.put_line(fnd_file.log,
		      'Non- eCommerce Customer Account ID which is marked eCommerce previously : ' || i
		      .cust_account_id || chr(10) ||
		       'eCommerce Inventory Item ID : ' ||
		       l_xxssys_event_rec.attribute1 /*i.inventory_item_id*/); -- INC0152106
	fnd_file.put_line(fnd_file.log,
		      '--------------------------------------');
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          CONTINUE;
      END;
    END LOOP;
  
    l_events_rec := event_tab();
    SELECT entity_id  cust_id,
           attribute1 item_id,
           event_id,
           attribute2 serial_number,
           attribute3 instance_id
    BULK   COLLECT
    INTO   l_events_rec
    FROM   (SELECT xe.entity_id,
	       xe.attribute1,
	       xe.attribute2,
	       xe.attribute3,
	       xe.event_id,
	       MAX(xe.event_id) over(PARTITION BY xe.entity_id, xe.attribute1, xe.attribute2, xe.attribute3) max_event_id --CHG0040839
	FROM   xxssys_events xe
	WHERE  xe.entity_name = g_printer_entity_name
	AND    xe.status = 'SUCCESS'
	AND    xe.active_flag = 'Y'
	AND    target_name = g_target_name --INC0123738
	) print_rec
    WHERE  print_rec.event_id = print_rec.max_event_id;
  
    <<outer_loop>>
    FOR j IN 1 .. l_events_rec.count LOOP
      l_found := 0;
      <<inner_loop>>
      FOR k IN 1 .. l_customer_printer_rec.count LOOP
        --CHG0040839 add serial and instance
        IF l_customer_printer_rec(k)
         .cust_account_id = l_events_rec(j).cust_id AND l_customer_printer_rec(k)
           .inventory_item_id = l_events_rec(j).item_id AND l_customer_printer_rec(k)
           .serial_number = l_events_rec(j).serial_number AND l_customer_printer_rec(k)
           .instance_id = l_events_rec(j).instance_id THEN
          l_found := 1;
        ELSE
          l_found := 0;
        END IF;
        EXIT inner_loop WHEN l_found = 1;
      END LOOP;
    
      IF l_found = 0 THEN
        UPDATE xxssys_events xe
        SET    xe.active_flag = 'N'
        WHERE  xe.entity_name = g_printer_entity_name
        AND    xe.event_id = l_events_rec(j).event_id
        AND    xe.entity_id = l_events_rec(j).cust_id
        AND    xe.attribute1 = l_events_rec(j).item_id
        AND    xe.attribute2 = l_events_rec(j).serial_number
        AND    xe.attribute3 = l_events_rec(j).instance_id
        AND    target_name = g_target_name --INC0123738
        ;
      
        COMMIT;
      
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := g_printer_entity_name;
        l_xxssys_event_rec.entity_id       := l_events_rec(j).cust_id;
        l_xxssys_event_rec.event_name      := l_eventname || '-' ||
			          l_program_short_name;
        l_xxssys_event_rec.last_updated_by := l_requestor;
        l_xxssys_event_rec.created_by      := l_requestor;
        l_xxssys_event_rec.attribute1      := l_events_rec(j).item_id;
        l_xxssys_event_rec.active_flag     := 'N';
        l_xxssys_event_rec.attribute2      := l_events_rec(j).serial_number; -- -CHG0040839
        l_xxssys_event_rec.attribute3      := l_events_rec(j).instance_id; -- -CHG0040839
      
        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      
        fnd_file.put_line(fnd_file.log,
		  'Inactivated Customer-Printer relationship : ' || l_events_rec(j)
		  .cust_id || chr(10) ||
		   'eCommerce Inventory Item ID : ' || l_events_rec(j)
		  .item_id);
        fnd_file.put_line(fnd_file.log,
		  '--------------------------------------');
      END IF;
    END LOOP;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode := SQLCODE;
      x_errbuf  := 'ERROR: ' || SQLERRM;
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUST_PRINTER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUST_PRINTER_CC',
	    'Customer-Printer',
	    'Hi,' || chr(10) || chr(10) ||
	    'The following unexpected exception occurred for Customer-Printer Interface API.' ||
	    chr(13) || chr(10) || '  Error Message: ' || SQLERRM ||
	    chr(13) || chr(13) || chr(10) || chr(10) || 'Thank you,' ||
	    chr(13) || chr(10) || 'Stratasys eCommerce team' || chr(13) ||
	    chr(13) || chr(10) || chr(10));
  END customer_printer_process;
END xxhz_ecomm_event_pkg;
/
