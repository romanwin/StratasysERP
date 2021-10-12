CREATE OR REPLACE PACKAGE BODY xxhz_ecomm_message_pkg
--------------------------------------------------------------------------------------------------------
--  name:            xxhz_ecomm_message_pkg
--  create by:       Debarati Banerjee
--  Revision:        1.0
--  creation date:   11/06/2015
--------------------------------------------------------------------------------------------------------
--  purpose :
---------------------------------------------------------------------------------------------------------
--  ver  date        name                         desc
--  1.0  11/06/2015  Debarati Banerjee            CHG0035649 - initial build
--       07/07/2015  Kundan Bhagat                CHG0035650 - Initial Build
--  1.1  26/10/2015  Kundan Bhagat                CHG0036750 - Call update_new procedure to update the status
--                                                Updated Procedure - retry_error_status
--  1.2  28/10/2015  Debarati banerjee            CHG0036659 - Adjust Ecommerce customer master interface
--                                                Updated Function - check_pr_bill_ship_site_exist,check_pr_bill_acct_pl_exist,
--                                                check_ship_acct_pl,generate_account_data,generate_contact_data,retry_error_status
--                                                Updated Procedure - check_email_address,validate_data
--                                                Added procedure - check_site_ou
--                                                Added procedure - check_same_bill_acct_pl
--  1.3  17/08/2016  Tagore Sathuluri         CHG0036450  - Fetch the relationship data of the customer
--                                                                    Added the function - generate_relationship_data
--                                                                    Update procedure   - generate_customer_messages
--                                                                    Update procedure   - generate_contact_data
--                                                                    Update procedure   - generate_site_data
--  1.4  19/09/2016  Diptasurjya Chattarjee       CHG0036450 - Updated the procedure generate_contact_data to fetch the accurate status of contact
--  1.5  28/09/2016  Tagore Sathuluri             CHG0036450 - Updated the procedure validate_data to check if the customer is ECOM enabled
--  1.6  22/12/2016  Tagore Sathuluri             CHG0039473 : Modified code to skip Price list Validation
--  1.7  25/05/2017  yuval tal                    CHG0040839   modify generate_printer_data : Add s/n information and printers which exist for ecom related customers
--  1.8  14/07/2017  Diptasurjya Chatterjee       INC0096393 - Add validation to check presence of at least 1 ship-to contact for a related customer
--  1.9  27.7.2017   yuval tal                     CHG0041221 - modify validate_data :
--                                                            comment out check_ship_acct_pl/check_ship_bill_pl/check_same_bill_acct_pl
--                                                            There is a need to remove the following validations which are related to price list because price list defaulting rules in Oracle were changed and are now not considering the PL which exists in the ship to address:
--                                                            Some of the SHIP_TO sites have different Pricelist than the account level pricelist for the customer
--                                                            Primary BILL_TO site have different Pricelist than the ACCOUNT level pricelist for the customer
--                                                            Some of the SHIP_TO sites have different Pricelist than the primary BILL_TO pricelist for the customer
--  2.0  30/06/2017  Lingaraj Sarangi             CHG0041064 - eCommerce - Add  'ecommerce view' information to ecommerce customer interface
--                                                New Field 'ecom_restricted_view' added to Record Type "xxhz_customer_account_rec"
--                                                The new Value fetched in the Procedure 'GENERATE_CUSTOMER_MESSAGES' Procedure
--  2.1  09/12/2017  Diptasurjya Chatterjee       INC0101904 - Account Relation error events were not reset to NEW
--  2.2  02/15/2018  Diptasurjya Chatterjee       CHG0042243 - Inactive entities should be sent to Hybris irrespective of validation failure
---------------------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This package is used to fetch customer account,site and contacts details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  17/06/2015  Debarati Banerjee         Initial Build
  -- 1.1  30/10/2015  Debarati Banerjee         CHG0036659 : Includes logic to derive currency_code,
  --                                            vat id field in account structure,modification of validation
  --                                            error message for null/duplicate emails. .Also includes
  --                                            new validation for customers belonging to multiple OU
  -- --------------------------------------------------------------------------------------------
  g_target_name VARCHAR2(20) := 'HYBRIS';
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function checks if at least 1 primary BILL_TO and 1 primary SHIP_TO site exists
  --          for given cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee                 Initial Build
  -- 1.1  30/10/2015  Debarati Banerjee                 CHG0036659: Includes OU specific validation
  --                                                    for the customers
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_pr_bill_ship_site_exist(p_cust_account_id IN NUMBER,
			     p_org_id          IN NUMBER)
    RETURN VARCHAR2 IS
    l_ship_site_check NUMBER := 0;
    l_bill_site_check NUMBER := 0;
    l_ou_count        NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_ship_site_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('SHIP_TO')
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.primary_flag = 'Y'
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A';
  
    SELECT COUNT(1)
    INTO   l_bill_site_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('BILL_TO')
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.primary_flag = 'Y'
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A';
  
    SELECT COUNT(1)
    INTO   l_ou_count
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y'
    AND    hro.organization_id = p_org_id;
  
    IF l_ship_site_check >= l_ou_count AND l_bill_site_check >= l_ou_count THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_pr_bill_ship_site_exist;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - INC0096393
  --          This function checks if at least 1 SHIP_TO contact exists for a customer account
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  13/07/2017  Diptasurjya                   Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ship_to_contact_exist(p_cust_account_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_ship_contact_chk NUMBER := 0;
  BEGIN
    SELECT COUNT(hcar.cust_account_role_id)
    INTO   l_ship_contact_chk
    FROM   hz_cust_accounts      hca,
           hz_cust_account_roles hcar,
           hz_relationships      hr,
           hz_parties            hp_contact,
           hz_parties            hp_cust,
           hz_party_sites        hps
    WHERE  hp_cust.party_id = hca.party_id
    AND    hps.party_id(+) = hcar.party_id
    AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
    AND    hca.cust_account_id = hcar.cust_account_id
    AND    hcar.role_type = 'CONTACT'
    AND    hcar.cust_acct_site_id IS NULL
    AND    hcar.party_id = hr.party_id
    AND    hr.subject_type = 'PERSON'
    AND    hr.subject_id = hp_contact.party_id
    AND    nvl((SELECT listagg(hrr.responsibility_type, ',') within GROUP(ORDER BY hrr.responsibility_type)
	   FROM   hz_role_responsibility hrr
	   WHERE  hrr.cust_account_role_id = hcar.cust_account_role_id),
	   'SHIP_TO,BILL_TO') LIKE '%SHIP_TO%'
    AND    hca.status = 'A'
    AND    hcar.status = 'A'
    AND    hr.status = 'A'
    AND    hp_contact.status = 'A'
    AND    hp_cust.status = 'A'
    AND    nvl(hps.status, 'A') = 'A'
    AND    hca.cust_account_id = p_cust_account_id;
  
    IF l_ship_contact_chk > 0 THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END check_ship_to_contact_exist;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          This function checks if at least 1 primary SHIP_TO site exists
  --          for given cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Tagore Sathuluri                   Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_pr_ship_site_exist(p_cust_account_id IN NUMBER,
			p_org_id          IN NUMBER)
    RETURN VARCHAR2 IS
    l_ship_site_check NUMBER := 0;
    l_ou_count        NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_ship_site_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('SHIP_TO')
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.primary_flag = 'Y'
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A';
  
    SELECT COUNT(1)
    INTO   l_ou_count
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y'
    AND    hro.organization_id = p_org_id;
  
    IF l_ship_site_check >= l_ou_count THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_pr_ship_site_exist;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function checks if at least 1 BILL_TO and 1 SHIP_TO site exists
  --          for given cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_bill_ship_site_exist(p_cust_account_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_ship_site_check NUMBER := 0;
    l_bill_site_check NUMBER := 0;
    l_ou_count        NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_ship_site_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('SHIP_TO')
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A';
  
    SELECT COUNT(1)
    INTO   l_bill_site_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('BILL_TO')
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A';
  
    SELECT COUNT(1)
    INTO   l_ou_count
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y';
  
    IF l_ship_site_check >= l_ou_count AND l_bill_site_check >= l_ou_count THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_bill_ship_site_exist;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function checks that pricelist should exist at account level and or primary
  --          BILl_TO site level
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                           Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  30/10/2015  Debarati Banerjee             CHG0036659: Includes OU specific validation
  --                                                for the customers
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_pr_bill_acct_pl_exist(p_cust_account_id IN NUMBER,
			   p_org_id          IN NUMBER)
    RETURN VARCHAR2 IS
    l_acct_pl_check NUMBER := 0;
    l_bill_pl_check NUMBER := 0;
    l_ou_count      NUMBER := 0;
  BEGIN
    SELECT COUNT(hca.price_list_id)
    INTO   l_acct_pl_check
    FROM   hz_cust_accounts hca
    WHERE  hca.status = 'A'
    AND    hca.cust_account_id = p_cust_account_id;
  
    SELECT COUNT(hcsua.price_list_id)
    INTO   l_bill_pl_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa
    WHERE  hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('BILL_TO')
    AND    hcsua.primary_flag = 'Y'
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A'
    AND    nvl(hps.status, 'A') = 'A'
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hcasa.cust_account_id = p_cust_account_id;
  
    SELECT COUNT(1)
    INTO   l_ou_count
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y'
    AND    hro.organization_id = p_org_id;
  
    IF l_acct_pl_check = 0 AND l_bill_pl_check < l_ou_count THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END check_pr_bill_acct_pl_exist;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from ACCOUNT level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ship_acct_pl(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_pl_check NUMBER := 0;
  BEGIN
  
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa,
           hz_cust_accounts       hca,
           hz_parties             hp,
           fnd_lookup_values_vl   flvv
    WHERE  hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
          /*AND    flvv.lookup_code IN
          ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')*/
    AND    flvv.attribute1 IS NOT NULL
    AND    hp.category_code = flvv.lookup_code
    AND    hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('SHIP_TO')
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A'
    AND    nvl(hps.status, 'A') = 'A'
    AND    hp.status = 'A'
    AND    hca.status = 'A'
    AND    hps.party_id = hp.party_id
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hcasa.cust_account_id = hca.cust_account_id
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcsua.price_list_id IS NOT NULL
    AND    hca.price_list_id IS NOT NULL
    AND    hcsua.price_list_id <> hca.price_list_id;
  
    IF l_pl_check > 0 THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END check_ship_acct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from primary BILL_TO level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ship_bill_pl(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_pl_check NUMBER := 0;
  BEGIN
  
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa,
           hz_cust_accounts       hca,
           hz_parties             hp,
           fnd_lookup_values_vl   flvv
    WHERE  hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
          /*AND    flvv.lookup_code IN
          ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')*/
    AND    flvv.attribute1 IS NOT NULL
    AND    hp.category_code = flvv.lookup_code
    AND    hcasa.org_id IN (SELECT hro.organization_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y')
    AND    hcsua.org_id = hcasa.org_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcsua.site_use_code IN ('SHIP_TO')
    AND    hcsua.status = 'A'
    AND    hcasa.status = 'A'
    AND    nvl(hps.status, 'A') = 'A'
    AND    hp.status = 'A'
    AND    hca.status = 'A'
    AND    hps.party_id = hp.party_id
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hcasa.cust_account_id = hca.cust_account_id
    AND    hca.cust_account_id = p_cust_account_id
    AND    hcsua.price_list_id IS NOT NULL
    AND    hcsua.price_list_id <>
           (SELECT hcsua_in.price_list_id price_list_id
	 FROM   hz_cust_site_uses_all  hcsua_in,
	        hz_party_sites         hps_in,
	        hz_cust_acct_sites_all hcasa_in
	 WHERE  hcasa_in.org_id = hcasa.org_id
	 AND    hcsua_in.org_id = hcasa_in.org_id
	 AND    hcsua_in.cust_acct_site_id = hcasa_in.cust_acct_site_id
	 AND    hcsua_in.site_use_code IN ('BILL_TO')
	 AND    hcsua_in.primary_flag = 'Y'
	 AND    hcsua_in.status = 'A'
	 AND    hcasa_in.status = 'A'
	 AND    nvl(hps_in.status, 'A') = 'A'
	 AND    hps_in.party_id = hp.party_id
	 AND    hps_in.party_site_id = hcasa_in.party_site_id
	 AND    hcasa_in.cust_account_id = hca.cust_account_id
	 AND    hcsua_in.price_list_id IS NOT NULL);
  
    IF l_pl_check > 0 THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END check_ship_bill_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --          Different BILL_TO sites have different pricelists
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_bill_acct_pl(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_pl_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   (SELECT cust_account_id,
	       org_id,
	       party_id,
	       party_name,
	       COUNT(*) cnt
	FROM   (SELECT DISTINCT hcasa.cust_account_id,
			hcasa.org_id,
			hp.party_id,
			hp.party_name,
			hcsua.price_list_id
	        FROM   hz_cust_site_uses_all  hcsua,
		   hz_party_sites         hps,
		   hz_cust_acct_sites_all hcasa,
		   hz_cust_accounts       hca,
		   hz_parties             hp,
		   fnd_lookup_values_vl   flvv
	        WHERE  hca.party_id = hp.party_id
	        AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
		  /*AND    flvv.lookup_code IN
                          ('AGENT',
                            'END CUSTOMER',
                            'CUSTOMER',
                            'DISTRIBUTOR')*/
	        AND    flvv.attribute1 IS NOT NULL
	        AND    hp.category_code = flvv.lookup_code
	        AND    hcasa.org_id IN
		   (SELECT hro.organization_id
		     FROM   hr_operating_units    hro,
			hr_organization_units hru
		     WHERE  hro.organization_id = hru.organization_id
		     AND    hru.attribute7 = 'Y')
	        AND    hcsua.org_id = hcasa.org_id
	        AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
	        AND    hcsua.site_use_code IN ('BILL_TO')
	        AND    hcsua.status = 'A'
	        AND    hcasa.status = 'A'
	        AND    nvl(hps.status, 'A') = 'A'
	        AND    hp.status = 'A'
	        AND    hca.status = 'A'
	        AND    hps.party_id = hp.party_id
	        AND    hps.party_site_id = hcasa.party_site_id
	        AND    hcasa.cust_account_id = hca.cust_account_id
	        AND    hca.cust_account_id = p_cust_account_id
	        AND    hcsua.price_list_id IS NOT NULL)
	GROUP  BY cust_account_id,
	          org_id,
	          party_id,
	          party_name
	HAVING COUNT(*) > 1);
  
    IF l_pl_check > 0 THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END check_bill_acct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036659
  --          This function fetch customer based on below condition-
  --          Account level pricelist differs from primary BILL_TO level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  02/02/2016  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_same_bill_acct_pl(p_cust_account_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_pl_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   hz_cust_accounts hca,
           hz_parties       hp
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.price_list_id IS NOT NULL
    AND    hca.party_id = hp.party_id
    AND    hp.status = 'A'
    AND    hca.status = 'A'
    AND    hca.price_list_id IS NOT NULL
    AND    hca.price_list_id <>
           (SELECT hcsua_in.price_list_id price_list_id
	 FROM   hz_cust_site_uses_all  hcsua_in,
	        hz_party_sites         hps_in,
	        hz_cust_acct_sites_all hcasa_in
	 WHERE  hcsua_in.org_id = hcasa_in.org_id
	 AND    hcsua_in.cust_acct_site_id = hcasa_in.cust_acct_site_id
	 AND    hcsua_in.site_use_code IN ('BILL_TO')
	 AND    hcsua_in.primary_flag = 'Y'
	 AND    hcsua_in.status = 'A'
	 AND    hcasa_in.status = 'A'
	 AND    nvl(hps_in.status, 'A') = 'A'
	 AND    hps_in.party_id = hp.party_id
	 AND    hps_in.party_site_id = hcasa_in.party_site_id
	 AND    hcasa_in.cust_account_id = hca.cust_account_id
	 AND    hcsua_in.price_list_id IS NOT NULL
	 AND    hcasa_in.org_id IN
	        (SELECT hro.organization_id
	          FROM   hr_operating_units    hro,
		     hr_organization_units hru
	          WHERE  hro.organization_id = hru.organization_id
	          AND    hru.attribute7 = 'Y'));
    IF l_pl_check > 0 THEN
    
      RETURN 'FALSE';
    ELSE
    
      RETURN 'TRUE';
    END IF;
  END check_same_bill_acct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function checks if customer category value is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_customer_category(p_cust_account_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_cust_category_check NUMBER := 0;
  BEGIN
    SELECT COUNT(flvv.attribute1)
    INTO   l_cust_category_check
    FROM   hz_cust_accounts     hca,
           hz_parties           hp,
           fnd_lookup_values_vl flvv
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    hp.category_code = flvv.lookup_code
    AND    flvv.attribute1 IS NOT NULL
    AND    hp.status = 'A';
    --AND    hca.status = 'A';
  
    /*SELECT COUNT(1)
    INTO   l_cust_category_check
    FROM   hz_cust_accounts     hca,
           hz_parties           hp,
           fnd_lookup_values_vl flvv
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    hp.category_code = flvv.lookup_code
    AND    flvv.lookup_code IN
           ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
    AND    hp.status = 'A'
    AND    hca.status = 'A';*/
  
    IF l_cust_category_check > 0 THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_customer_category;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This procedure checks if email address of contacts are unique
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  28/10/2015  Debarati Banerjee             CHG0036659: Added logic to modify validation error
  --                                                in case of duplicate or null emails.
  -- --------------------------------------------------------------------------------------------
  PROCEDURE check_email_address(p_cust_account_id IN NUMBER,
		        l_flag            OUT VARCHAR2,
		        l_message         OUT VARCHAR2) IS
  
    --Cursor to fetch the ecomm contacts and their active email addresses for a customer
    CURSOR cur_email(p_cust_account_id NUMBER) IS
      SELECT hcar_ecomm.cust_account_role_id          contact_id,
	 hp_contact_ecomm.person_pre_name_adjunct person_pre_name,
	 hp_contact_ecomm.person_last_name        person_last_name,
	 hp_contact_ecomm.person_first_name       person_first_name,
	 xecpv.email_address                      email_address,
	 hca_ecomm.account_number                 account_number
      FROM   hz_cust_accounts           hca_ecomm,
	 hz_cust_account_roles      hcar_ecomm,
	 hz_relationships           hr_ecomm,
	 hz_parties                 hp_contact_ecomm,
	 hz_parties                 hp_cust_ecomm,
	 hz_party_sites             hps_ecomm,
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
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar_ecomm.cust_account_role_id) =
	 'TRUE' -- change event pkg name
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hca_ecomm.cust_account_id = p_cust_account_id
      AND    xecpv.status = 'A';
    --AND    xecpv.email_address <> 'oradev@stratasys.com'; --912040;
  
    --cursor  to identify all ecom contacts for the customer
    CURSOR cur_ecom_contact(p_cust_account_id NUMBER) IS
      SELECT hcar_ecomm.cust_account_role_id    contact_id,
	 hp_contact_ecomm.person_first_name person_first_name,
	 hp_contact_ecomm.person_last_name  person_last_name
      FROM   hz_cust_accounts      hca_ecomm,
	 hz_cust_account_roles hcar_ecomm,
	 hz_relationships      hr_ecomm,
	 hz_parties            hp_contact_ecomm,
	 hz_parties            hp_cust_ecomm,
	 hz_party_sites        hps_ecomm
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
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar_ecomm.cust_account_role_id) =
	 'TRUE'
      AND    nvl(hps_ecomm.status, 'A') = 'A'
      AND    hca_ecomm.cust_account_id = p_cust_account_id;
  
    --cursor to check duplicate emails for all ecomm contacts across accounts
  
    CURSOR cur_duplicate_email /*(p_contact_id NUMBER, p_email_address VARCHAR2)*/
    IS
      SELECT hcar_ecomm.cust_account_role_id          dup_contact_id,
	 hca_ecomm.account_number                 account_number,
	 hp_contact_ecomm.person_pre_name_adjunct dup_person_pre_name,
	 hp_contact_ecomm.person_last_name        dup_person_last_name,
	 hp_contact_ecomm.person_first_name       dup_person_first_name,
	 xecpv.email_address                      dup_email_address
      FROM   hz_cust_accounts           hca_ecomm,
	 hz_cust_account_roles      hcar_ecomm,
	 hz_relationships           hr_ecomm,
	 hz_parties                 hp_contact_ecomm,
	 hz_parties                 hp_cust_ecomm,
	 hz_party_sites             hps_ecomm,
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
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar_ecomm.cust_account_role_id) =
	 'TRUE'
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
	--    AND    hcar_ecomm.cust_account_role_id                      <> p_contact_id
	--    AND    xecpv.email_address                                                          = p_email_address
      AND    xecpv.status = 'A';
  
    CURSOR cur_email_exist(p_contact_id IN NUMBER) IS
    -- SELECT COUNT(*)
      SELECT COUNT(1)
      FROM   xxhz_email_contact_point_v hcp,
	 hz_cust_accounts           hca,
	 hz_relationships           hr,
	 hz_cust_account_roles      hcar
      WHERE  hcar.cust_account_role_id = p_contact_id
      AND    hcp.owner_table_name = 'HZ_PARTIES'
      AND    hcp.owner_table_id = hr.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcp.status = 'A';
  
    l_email_exist    NUMBER := 0;
    l_email          VARCHAR2(1) := 'T';
    l_null_email_msg VARCHAR2(4000) := NULL;
    l_dup_message    VARCHAR2(4000) := NULL;
  
    TYPE t_email IS TABLE OF cur_email%ROWTYPE INDEX BY PLS_INTEGER;
    l_emails t_email;
  
    TYPE t_dup_email IS TABLE OF cur_duplicate_email%ROWTYPE INDEX BY PLS_INTEGER;
    l_dup_email t_dup_email;
  
  BEGIN
    BEGIN
      SELECT hcar_ecomm.cust_account_role_id          contact_id,
	 hp_contact_ecomm.person_pre_name_adjunct person_pre_name,
	 hp_contact_ecomm.person_last_name        person_last_name,
	 hp_contact_ecomm.person_first_name       person_first_name,
	 xecpv.email_address                      email_address,
	 hca_ecomm.account_number                 account_number
      BULK   COLLECT
      INTO   l_emails
      FROM   hz_cust_accounts           hca_ecomm,
	 hz_cust_account_roles      hcar_ecomm,
	 hz_relationships           hr_ecomm,
	 hz_parties                 hp_contact_ecomm,
	 hz_parties                 hp_cust_ecomm,
	 hz_party_sites             hps_ecomm,
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
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar_ecomm.cust_account_role_id) =
	 'TRUE' -- change event pkg name
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hca_ecomm.cust_account_id = p_cust_account_id
      AND    xecpv.status = 'A';
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
    BEGIN
      /*SELECT hcar_ecomm.cust_account_role_id          dup_contact_id,
             hca_ecomm.account_number                 account_number,
             hp_contact_ecomm.person_pre_name_adjunct dup_person_pre_name,
             hp_contact_ecomm.person_last_name        dup_person_last_name,
             hp_contact_ecomm.person_first_name       dup_person_first_name,
             xecpv.email_address                      dup_email_address BULK COLLECT
      INTO   l_dup_email
      FROM   hz_cust_accounts           hca_ecomm,
             hz_cust_account_roles      hcar_ecomm,
             hz_relationships           hr_ecomm,
             hz_parties                 hp_contact_ecomm,
             hz_parties                 hp_cust_ecomm,
             hz_party_sites             hps_ecomm,
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
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar_ecomm.cust_account_role_id) =
             'TRUE'
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
            --   AND    hcar_ecomm.cust_account_role_id <> p_contact_id
            --    AND    xecpv.email_address = p_email_address
      AND    xecpv.status = 'A';*/
    
      SELECT hcar_ecomm.cust_account_role_id          dup_contact_id,
	 hca_ecomm.account_number                 account_number,
	 hp_contact_ecomm.person_pre_name_adjunct dup_person_pre_name,
	 hp_contact_ecomm.person_last_name        dup_person_last_name,
	 hp_contact_ecomm.person_first_name       dup_person_first_name,
	 xecpv.email_address                      dup_email_address
      BULK   COLLECT
      INTO   l_dup_email
      FROM   hz_cust_accounts           hca_ecomm,
	 hz_cust_account_roles      hcar_ecomm,
	 hz_relationships           hr_ecomm,
	 hz_parties                 hp_contact_ecomm,
	 hz_parties                 hp_cust_ecomm,
	 hz_party_sites             hps_ecomm,
	 xxhz_email_contact_point_v xecpv,
	 xxhz_ecomm_contact_temp    gtt
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
      AND    gtt.contact_id = hcar_ecomm.cust_account_role_id
      AND    hcar_ecomm.party_id = xecpv.owner_table_id(+)
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    xecpv.status = 'A';
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    FOR i IN 1 .. l_emails.count LOOP
      FOR k IN 1 .. l_dup_email.count LOOP
        IF l_dup_email(k).dup_contact_id <> l_emails(i).contact_id AND l_dup_email(k)
           .dup_email_address = l_emails(i).email_address THEN
          l_dup_message := l_dup_message ||
		   'VALIDATION ERROR : Duplicate email address exists for contact ' || l_emails(i)
		  .person_first_name || ' ' || l_emails(i)
		  .person_last_name || '.' || '(' || l_emails(i)
		  .account_number || ')' || ':' || chr(10);
          l_dup_message := l_dup_message || l_dup_email(k)
		  .dup_person_first_name || ' ' || l_dup_email(k)
		  .dup_person_last_name || '-' || '(' || l_dup_email(k)
		  .account_number || ')' || chr(10);
          l_email       := 'F';
        END IF;
      END LOOP;
    END LOOP;
  
    FOR i IN cur_ecom_contact(p_cust_account_id) LOOP
      --check for null email
      OPEN cur_email_exist(i.contact_id);
      FETCH cur_email_exist
        INTO l_email_exist;
      CLOSE cur_email_exist;
    
      IF l_email_exist <= 0 THEN
        l_email          := 'F';
        l_null_email_msg := l_null_email_msg || i.person_first_name || ' ' ||
		    i.person_last_name || chr(10);
      END IF;
    END LOOP;
  
    IF l_null_email_msg IS NOT NULL THEN
      l_null_email_msg := 'VALIDATION ERROR: Email does not exist for below contacts: ' ||
		  chr(10) || l_null_email_msg;
    
    END IF;
  
    IF l_email = 'F' THEN
      l_message := l_dup_message || chr(10) || l_null_email_msg;
    
      l_flag := 'FALSE';
    ELSE
      l_flag := 'TRUE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_flag    := 'FALSE';
      l_message := SQLCODE || chr(10) || SQLERRM || chr(10) ||
	       l_dup_message || chr(10) || l_null_email_msg;
  END check_email_address;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036659
  --          This function checks if customer has site in multiple OUs
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  28/10/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE check_site_ou(p_cust_account_id IN NUMBER,
		  x_org_validation  OUT VARCHAR2,
		  x_org_id          OUT NUMBER) IS
    CURSOR cur_org_id(p_cust_account_id NUMBER) IS
      SELECT DISTINCT hcasa.org_id org_id
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
  
    l_org_count NUMBER := 0;
    l_org_id    NUMBER;
  BEGIN
    FOR cur_rec IN cur_org_id(p_cust_account_id) LOOP
      l_org_count := l_org_count + 1;
      l_org_id    := cur_rec.org_id;
    END LOOP;
  
    IF l_org_count = 0 THEN
      x_org_validation := 'NOTEXIST';
      x_org_id         := NULL;
    ELSIF l_org_count = 1 THEN
      x_org_validation := 'TRUE';
      x_org_id         := l_org_id;
    ELSIF l_org_count > 1 THEN
      x_org_validation := 'FALSE';
      x_org_id         := NULL;
    END IF;
  END check_site_ou;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042243
  --          This function is used to check active status of an entity event
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  01/15/2018  Diptasurjya Chatterjee    Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_entity_active(p_entity_name VARCHAR2,
		    p_entity_id   NUMBER,
		    p_attribute1  VARCHAR2,
		    p_attribute2  VARCHAR2) RETURN VARCHAR2 IS
    l_is_valid VARCHAR2(1);
  BEGIN
    IF p_entity_name = 'ACCOUNT' THEN
      BEGIN
        SELECT 'Y'
        INTO   l_is_valid
        FROM   hz_cust_accounts hca,
	   hz_parties       hp
        WHERE  hca.party_id = hp.party_id
        AND    hca.cust_account_id = p_entity_id
        AND    hca.status = 'A'
        AND    hp.status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    ELSIF p_entity_name = 'SITE' THEN
      BEGIN
        SELECT 'Y'
        INTO   l_is_valid
        FROM   hz_cust_acct_sites_all hcasa,
	   hz_cust_site_uses_all  hcsua
        WHERE  hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
        AND    hcasa.cust_account_id = p_attribute1
        AND    hcsua.site_use_id = p_entity_id
        AND    hcasa.status = 'A'
        AND    hcsua.status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    ELSIF p_entity_name = 'CONTACT' THEN
      BEGIN
        SELECT 'Y'
        INTO   l_is_valid
        FROM   hz_cust_accounts      hca,
	   hz_cust_account_roles hcar,
	   hz_relationships      hr,
	   hz_parties            hp_contact
        WHERE  hca.cust_account_id = hcar.cust_account_id
        AND    hcar.role_type = 'CONTACT'
        AND    hcar.cust_acct_site_id IS NULL
        AND    hcar.party_id = hr.party_id
        AND    hr.subject_type = 'PERSON'
        AND    hr.subject_id = hp_contact.party_id
        AND    hcar.cust_account_role_id = p_entity_id
        AND    hca.cust_account_id = p_attribute1
        AND    hcar.status = 'A'
        AND    hp_contact.status = 'A';
      
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    ELSIF p_entity_name = 'ACCT_REL' THEN
      BEGIN
        SELECT 'Y'
        INTO   l_is_valid
        FROM   hz_cust_acct_relate_all
        WHERE  cust_account_id = p_attribute1
        AND    related_cust_account_id = p_entity_id
        AND    org_id = p_attribute2
        AND    status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'N';
      END;
    END IF;
    RETURN l_is_valid;
  END is_entity_active;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to validate the customer details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  17/06/2015  Debarati Banerjee         Initial Build
  -- 1.1  28/10/2015  Debarati Banerjee         CHG0036659: Added validations for customers belonging
  --                                            to multiple OUs and primary bill to level PL differs
  --                                            from account level PL.Added exception section
  -- 1.2  2/10/2016   Tagore Sathuluri          CHG0036450: Skipped validations if the account is non ecom
  -- 1.3  14/07/2017  Diptasurjya Chatterjee    INC0096393 - Add validation to check presence of at least 1 ship-to contact for a related customer
  --  1.4  27.7.2017   yuval tal                 CHG0041221 - comment out check_ship_acct_pl/check_ship_bill_pl/check_same_bill_acct_pl

  -- --------------------------------------------------------------------------------------------

  PROCEDURE validate_data(p_cust_account_id IN NUMBER,
		  --p_bpel_instance_id IN NUMBER,
		  l_final_cust_flag OUT VARCHAR2,
		  l_status_message  OUT VARCHAR2) IS
  
    l_pr_bill_acct_pl_cust_flag VARCHAR2(10) := 'FALSE';
    l_ship_bill_site_cust_flag  VARCHAR2(10) := 'FALSE';
    --l_bill_acct_null_pl_cust_flag VARCHAR2(10) := 'FALSE';
    l_bill_acct_pl_cust_flag VARCHAR2(10) := 'FALSE';
    --l_same_bill_acct_pl_flag VARCHAR2(10) := 'FALSE'; -- Yuval
  
    l_ship_site_cust_flag VARCHAR2(10) := 'FALSE'; -- TAGORE CHG0036450
    l_ship_contact_flag   VARCHAR2(10) := 'FALSE'; -- INC0096393 - Dipta
  
    l_customer_category_flag VARCHAR2(10) := 'FALSE';
    l_customer_email_check   VARCHAR2(10) := 'FALSE';
    l_org_id                 NUMBER;
  
    l_mail_body    VARCHAR2(4000);
    l_message      VARCHAR2(4000);
    l_is_cust_ecom VARCHAR2(10) := 'FALSE'; -- TAGORE CHG0036450
  
  BEGIN
  
    -- l_final_cust_flag := 'FALSE';
    --l_status_message  VARCHAR2(4000);
    ---------------------------------------------------------------------------------------------------
    -- 1.1  28/10/2015  Debarati Banerjee         CHG0036659: Added validations for customers belonging
    --                                            to multiple OUs
    -- 1.2  22/12/2016  Tagore Sathuluri          CHG0039473 : Commented the code to skip the price list
    --                                                                                                                       validation
    -- --------------------------------------------------------------------------------------------
    check_site_ou(p_cust_account_id, l_final_cust_flag, l_org_id);
    --  l_final_cust_flag          := l_ship_bill_site_cust_flag;
  
    l_is_cust_ecom := xxhz_util.is_ecomm_customer(p_cust_account_id); -- TAGORE CHG0036450
  
    IF l_final_cust_flag = 'TRUE' THEN
    
      IF l_is_cust_ecom = 'TRUE' THEN
        -- TAGORE CHG0036450
      
        l_ship_bill_site_cust_flag := check_pr_bill_ship_site_exist(p_cust_account_id,
					        l_org_id);
        IF l_ship_bill_site_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: At least 1 primary BILL_TO and 1 primary SHIP_TO sites must exist for the customer' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'At least 1 primary BILL_TO and 1 primary SHIP_TO sites must exist for the customer.' ||
		      chr(10);
        END IF;
      
        --l_status_message := l_status_message||'Before at least one of Bill site PL or Account PL exists check'||CHR(13);
        l_pr_bill_acct_pl_cust_flag := check_pr_bill_acct_pl_exist(p_cust_account_id,
					       l_org_id);
        IF l_pr_bill_acct_pl_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: Either account level Pricelist or Primary BILL_TO site pricelist or both must exist for the customer' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'Either account level Pricelist or Primary BILL_TO site pricelist or both must exist for the customer.' ||
		      chr(10);
        END IF;
      
        --l_status_message := l_status_message||'Before Ship site and Account PL check'||CHR(13);
        --CHG0041221
        /*  l_ship_acct_pl_cust_flag := check_ship_acct_pl(p_cust_account_id);
        IF l_ship_acct_pl_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
                              'VALIDATION ERROR: Some of the SHIP_TO sites have different Pricelist than the account level pricelist for the customer' ||
                              chr(10);
          l_mail_body      := l_mail_body ||
                              'Some of the SHIP_TO sites have different Pricelist than the account level pricelist for the customer.' ||
                              chr(10);
        END IF;*/
      
        --l_status_message := l_status_message||'Before Ship site and Bill site check'||CHR(13);
        --CHG0041221
        /*   l_ship_bill_pl_cust_flag := check_ship_bill_pl(p_cust_account_id);
        
        IF l_ship_bill_pl_cust_flag = 'FALSE' THEN
        
          l_status_message := l_status_message ||
                              'VALIDATION ERROR: Some of the SHIP_TO sites have different Pricelist than the primary BILL_TO pricelist for the customer' ||
                              chr(10);
          l_mail_body      := l_mail_body ||
                              'Some of the SHIP_TO sites have different Pricelist than the primary BILL_TO pricelist for the customer.' ||
                              chr(10);
        END IF;*/
      
        --l_status_message := l_status_message||'Before Bill site and Account PL check'||CHR(13);
        l_bill_acct_pl_cust_flag := check_bill_acct_pl(p_cust_account_id);
        IF l_bill_acct_pl_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: Different BILL_TO sites have different pricelist for the customer' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'Different BILL_TO sites have different pricelist for the customer.' ||
		      chr(10);
        END IF;
      
        -------------------------------------------------------------------------------------------------------
        -- 1.1  02/02/2015  Debarati Banerjee         CHG0036659: Added validations for same pricelist
        --                                            at primary bill to and account level
        -- --------------------------------------------------------------------------------------------
        -- CHG0041221
        /* l_same_bill_acct_pl_flag := check_same_bill_acct_pl(p_cust_account_id);
        
        IF l_same_bill_acct_pl_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
                              'VALIDATION ERROR: Primary BILL_TO site have different Pricelist than the ACCOUNT level pricelist for the customer' ||
                              chr(10);
          l_mail_body      := l_mail_body ||
                              'Primary BILL_TO site have different Pricelist than the ACCOUNT level pricelist for the customer' ||
                              chr(10);
        END IF;*/
      
        l_customer_category_flag := check_customer_category(p_cust_account_id);
        IF l_customer_category_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: Customer category must be set to one of these values: Agent / End Customer / Customer / Distributor' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'Customer category must be set to one of these values: Agent / End Customer / Customer / Distributor' ||
		      chr(10);
        END IF;
      
        ---------------------------------------------------------------------------------------------------
        -- 1.1  28/10/2015  Debarati Banerjee         CHG0036659: Modified validation message
        --                                            for duplicate/null emails
        -- --------------------------------------------------------------------------------------------
        check_email_address(p_cust_account_id,
		    l_customer_email_check,
		    l_message);
        IF l_customer_email_check = 'FALSE' THEN
          /* l_status_message := l_status_message ||
                              'VALIDATION ERROR: Customer contact has null or duplicate email address' ||
                              chr(10);
          l_mail_body      := l_mail_body ||
                              'Customer contact has null or duplicate email address' ||
                              chr(10);*/
          l_status_message := l_status_message || l_message || chr(10);
          l_mail_body      := l_mail_body || l_message || chr(10);
        END IF;
      
        IF l_ship_bill_site_cust_flag = 'TRUE' AND
          -- l_ship_acct_pl_cust_flag = 'TRUE' AND --CHG0041221
          -- l_ship_bill_pl_cust_flag = 'TRUE' AND  --CHG0041221
           l_pr_bill_acct_pl_cust_flag = 'TRUE' AND
           l_bill_acct_pl_cust_flag = 'TRUE' AND
          --  l_same_bill_acct_pl_flag = 'TRUE' AND --CHG0041221
           l_customer_category_flag = 'TRUE' AND
           l_customer_email_check = 'TRUE' THEN
        
          l_final_cust_flag := 'TRUE';
        
        ELSE
          l_final_cust_flag := 'FALSE';
          --Send Mail
          --send_mail(l_mail_requestor,l_mail_subject,l_mail_body);
        END IF;
        --new change
      ELSE
        /*    TAGORE CHG0036450 STARTS       */
      
        l_ship_site_cust_flag := check_pr_ship_site_exist(p_cust_account_id,
				          l_org_id);
      
        IF l_ship_site_cust_flag = 'FALSE' THEN
        
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: At least 1 primary SHIP_TO site must exist for the customer' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'At least 1 primary SHIP_TO sites must exist for the customer.' ||
		      chr(10);
        
        END IF;
      
        -- INC0096393 - Dipta Start
        l_ship_contact_flag := check_ship_to_contact_exist(p_cust_account_id);
      
        IF l_ship_contact_flag = 'FALSE' THEN
        
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: At least 1 SHIP_TO contact must exist for the customer' ||
		      chr(10);
          l_mail_body      := l_mail_body ||
		      'At least 1 SHIP_TO contact must exist for the customer.' ||
		      chr(10);
        
        END IF;
        -- INC0096393 - Dipta End
      
        /*--Commented the below logic to skip the price list validation for non Ecom customers (CHG0039473)--*/
      
        /*l_pr_bill_acct_pl_cust_flag := check_pr_bill_acct_pl_exist(p_cust_account_id, l_org_id);
        
        IF l_pr_bill_acct_pl_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
                              'VALIDATION ERROR: Either account level Pricelist or Primary BILL_TO site pricelist or both must exist for the customer' ||
                              chr(10);
        
          l_mail_body      := l_mail_body ||
                              'Either account level Pricelist or Primary BILL_TO site pricelist or both must exist for the customer.' ||
                              chr(10);
        END IF;
        
        l_ship_acct_pl_cust_flag := check_ship_acct_pl(p_cust_account_id);
        
                        IF l_ship_acct_pl_cust_flag = 'FALSE' THEN
          l_status_message := l_status_message ||
                              'VALIDATION ERROR: Some of the SHIP_TO sites have different Pricelist than the account level pricelist for the customer' ||
                              chr(10);
          l_mail_body      := l_mail_body ||
                              'Some of the SHIP_TO sites have different Pricelist than the account level pricelist for the customer.' ||
                              chr(10);
        END IF;
                        */
        IF l_ship_site_cust_flag = 'TRUE' AND l_ship_contact_flag = 'TRUE' -- INC0096393 - Dipta
        --   l_pr_bill_acct_pl_cust_flag            = 'TRUE' AND                              -- Commented for CHG0039473
        --   l_ship_acct_pl_cust_flag         = 'TRUE'                    -- Commented for CHG0039473
         THEN
        
          l_final_cust_flag := 'TRUE';
        ELSE
          l_final_cust_flag := 'FALSE';
        END IF;
      
      END IF; /*        TAGORE CHG0036450 ENDS */
    
    ELSIF l_final_cust_flag = 'NOTEXIST' THEN
    
      l_final_cust_flag := 'FALSE';
      l_status_message  := l_status_message ||
		   'VALIDATION ERROR: Customer Account does not belong to Ecom enabled Operating unit' ||
		   chr(10);
      l_mail_body       := l_mail_body ||
		   'Customer Account does not belong to Ecom enabled Operating unit' ||
		   chr(10);
    ELSE
    
      l_final_cust_flag := 'FALSE';
    
      l_status_message := l_status_message ||
		  'VALIDATION ERROR: Customer Account has site in multiple Operating units' ||
		  chr(10);
      l_mail_body      := l_mail_body ||
		  'Customer Account has site in multiple Operating units' ||
		  chr(10);
      --Should I send Mail?
      --Send Mail
      --send_mail(l_mail_requestor,l_mail_subject,l_mail_body);
    END IF;
  
    ----------------------------------------------------------------------------------------------
    -- 1.1  02/02/2015  Debarati Banerjee         CHG0036659: Added exception
    ----------------------------------------------------------------------------------------------
  
  EXCEPTION
    WHEN OTHERS THEN
      l_final_cust_flag := 'FALSE';
      l_status_message  := SQLCODE || chr(10) || SQLERRM || chr(10) ||
		   l_status_message;
  END validate_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetches customer account ID for a given contact_point_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                         Description
  -- 1.0  18/06/2015  Debarati Banerjee            Initial Build
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
		          p_subject     => 'eStore validation error in Oracle - IMPORTANT' ||
				   l_api_phase || ' for - ' ||
				   p_entity,
		          p_body_text   => p_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_err_msg);
  
  END send_mail;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This function generate and return customer-Printer data for a given cust_account_id
  --          and inventory_item_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                  Initial Build
  -- 1.1  25.5.17     yuval tal                      CHG0040839 add serial /instance id
  -- --------------------------------------------------------------------------------------------
  FUNCTION generate_printer_data(p_event_id        IN NUMBER,
		         p_cust_account_id IN NUMBER,
		         p_item_id         IN NUMBER,
		         p_status          IN VARCHAR2)
    RETURN xxhz_customer_printer_rec IS
    l_customer_printer_rec xxhz_customer_printer_rec;
  BEGIN
    SELECT xxhz_customer_printer_rec(p_event_id,
			 p_cust_account_id,
			 msib.segment1,
			 msib.description,
			 decode(p_status, 'Y', 'A', 'I'),
			 ev.attribute2, --serial_number,CHG0040839
			 ev.attribute3, -- instance_id,CHG0040839
			 NULL,
			 NULL,
			 NULL)
    INTO   l_customer_printer_rec
    FROM   xxssys_events      ev,
           mtl_system_items_b msib,
           mtl_parameters     mp
    WHERE  ev.event_id = p_event_id
    AND    msib.inventory_item_id = p_item_id
    AND    msib.organization_id = mp.organization_id
    AND    msib.organization_id = mp.master_organization_id;
  
    RETURN l_customer_printer_rec;
  END generate_printer_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer account data for a given cust_account_id
  --          and org_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  28/10/2015  Debarati Banerjee             CHG0036659: Added logic to derive org_id,
  --                                                currency_code and vat id fields
  -- 1.2  30/06/2017  Lingaraj Sarangi(TCS)         CHG0041064:eCommerce - Add  'ecommerce view' information to ecommerce customer interface
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_account_data(p_event_id        IN NUMBER,
		         p_cust_account_id IN NUMBER,
		         --p_rltd_cust_accnt_id IN NUMBER,
		         p_org_id IN NUMBER,
		         p_status IN VARCHAR2)
    RETURN xxhz_customer_account_rec --xxhz_customer_account_tab
   IS
    --l_customer_account_tab xxhz_customer_account_tab := xxhz_customer_account_tab();
    l_customer_account_rec xxhz_customer_account_rec;
  BEGIN
  
    SELECT xxhz_customer_account_rec(p_event_id,
			 cust_account_id,
			 party_name,
			 account_number,
			 p_org_id,
			 (SELECT currency_code
			  FROM   qp_secu_list_headers_vl
			  WHERE  list_header_id = price_list_id),
			 price_list_id,
			 (SELECT hp.jgzz_fiscal_code
			  FROM   hz_parties       hp,
			         hz_cust_accounts hca
			  WHERE  hca.party_id = hp.party_id
			  AND    hp.jgzz_fiscal_code IS NOT NULL
			  AND    hca.cust_account_id =
			         p_cust_account_id),
			 cust_status,
			 ecom_restricted_view -- Added on 30.06.2017 for CHG0041064
			 )
    INTO   l_customer_account_rec
    FROM   (SELECT hca.cust_account_id cust_account_id,
	       hp.party_name party_name,
	       hca.account_number account_number,
	       nvl((SELECT hcsua.price_list_id
	           FROM   hz_cust_site_uses_all  hcsua,
		      hz_party_sites         hps,
		      hz_cust_acct_sites_all hcasa
	           WHERE  hcasa.org_id = p_org_id
	           AND    hcsua.org_id = hcasa.org_id
	           AND    hcsua.cust_acct_site_id =
		      hcasa.cust_acct_site_id
	           AND    hcsua.site_use_code IN ('BILL_TO')
	           AND    hcsua.primary_flag = 'Y'
	           AND    hcsua.status = 'A'
	           AND    hcasa.status = 'A'
	           AND    nvl(hps.status, 'A') = 'A'
	           AND    hps.party_id = hp.party_id
	           AND    hps.party_site_id = hcasa.party_site_id
	           AND    hca.cust_account_id = hcasa.cust_account_id),
	           hca.price_list_id) price_list_id,
	       decode(p_status, 'Y', 'A', 'I') cust_status,
	       nvl(hca.attribute20,
	           fnd_profile.value('XXOM_ECOM_RESTRICTED_VIEW')) ecom_restricted_view -- Added on 30.06.2017 for CHG0041064
	FROM   hz_cust_accounts hca,
	       hz_parties       hp
	WHERE  hca.party_id = hp.party_id
	AND    hca.cust_account_id = p_cust_account_id);
  
    --l_customer_account_tab.event_id := p_event_id;
  
    RETURN l_customer_account_rec;
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.update_error(p_event_id,
			'UNEXPECTED ERROR: ' || SQLERRM);
      RETURN NULL;
  END generate_account_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer site data for a given cust_account_id,
  --          site_id and org_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  17/08/2016  Tagore Sathuluri                  CHG0036450 : Included the changes to fetch the status of the account
  -- 1.2  22/12/2016  Tagore Sathuluri                  CHG0039473 : Added new logic to fetch the state value for Canadian Customers
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_site_data(p_event_id           IN NUMBER,
		      p_cust_account_id    IN NUMBER,
		      p_rltd_cust_accnt_id IN NUMBER,
		      p_cust_site_use_id   IN NUMBER,
		      p_status             IN VARCHAR2)
    RETURN xxhz_customer_site_rec IS
  
    l_rltd_cust_name VARCHAR2(360);
    l_rltd_cust_num  VARCHAR2(30);
    -- l_rel_status        VARCHAR2(2);                                      -- CHG0036450 : Tagore Start
    l_status            VARCHAR2(2);
    l_customer_site_rec xxhz_customer_site_rec;
    --l_customer_site_tab xxhz_customer_site_tab := xxhz_customer_site_tab();
  
  BEGIN
  
    /*IF p_rltd_cust_accnt_id IS NOT NULL THEN                                  -- CHG0036450 : Tagore Start
      OPEN cur_related_party;
      FETCH cur_related_party
        INTO l_rltd_cust_name, l_rltd_cust_num;
      CLOSE cur_related_party;
    
      OPEN cur_relation_status;
      FETCH cur_relation_status
        INTO l_rel_status;
      CLOSE cur_relation_status;
    
    ELSE
      l_rltd_cust_name := NULL;
      l_rltd_cust_num  := NULL;
      l_rel_status     := NULL;
    END IF;
                                                */
  
    l_rltd_cust_name := NULL;
    l_rltd_cust_num  := NULL;
    --  l_rel_status      := NULL;
  
    IF p_status = 'N' THEN
      l_status := 'I';
    END IF; -- CHG0036450 : Tagore          End
  
    SELECT xxhz_customer_site_rec(p_event_id,
		          p_cust_account_id,
		          p_rltd_cust_accnt_id,
		          l_rltd_cust_name,
		          l_rltd_cust_num,
		          TRIM(hl.address1 || ' ' || hl.address2 || ' ' ||
			   hl.address3 || ' ' || hl.address4),
		          hl.city,
		          ftv.territory_short_name,
		          hl.county,
		          /*Commented the below condition to fetch state name for Canada and US territories (CHG0039473) */
		          
		          /*  decode(ftv.territory_short_name, 'Canada', hl.province, (SELECT fl.meaning
                                  FROM   fnd_lookup_values fl
                                  WHERE  fl.lookup_type      = 'US_STATE'
                                  AND    fl.LANGUAGE       = 'US'
                                  AND    fl.lookup_code      = hl.state)), */
		          
		          /*Added the below condition to fetch state name for Canada and US territories (CHG0039473) */
		          (SELECT fl.meaning
		           FROM   fnd_lookup_values fl
		           WHERE  fl.lookup_type IN
			      ('US_STATE', 'CA_PROVINCE')
		           AND    fl.language = 'US'
		           AND    (fl.lookup_code = hl.state OR
			     fl.meaning = hl.state)),
		          /*CHG0039473 Ends*/
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
		          CASE l_status
			WHEN 'I' THEN
			 'I'
			ELSE
			 nvl((SELECT 'A'
			     FROM   dual
			     WHERE  hp.status = 'A'
			     AND    hca.status = 'A'
			     AND    nvl(hps.status, 'A') = 'A'
			     AND    hcsua.status = 'A'
			     AND    hcasa.status = 'A'),
			     'I')
		          END) -- BULK COLLECT
    INTO   l_customer_site_rec
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
    AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hca.cust_account_id = hcasa.cust_account_id
    AND    hcasa.org_id = hcsua.org_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
          --AND    hcasa.org_id = p_org_id
    AND    hcsua.site_use_id = nvl(p_cust_site_use_id, hcsua.site_use_id)
    AND    hca.cust_account_id =
           nvl(p_rltd_cust_accnt_id, p_cust_account_id);
  
    RETURN l_customer_site_rec;
  
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.update_error(p_event_id,
			'UNEXPECTED ERROR: ' || SQLERRM);
      RETURN NULL;
  END generate_site_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer contact data for a given cust_account_id,
  --          contact_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  28/10/2015  Debarati Banerjee             CHG0036659: Included changes for identifying
  --                                                ecommerce contact based on new DFF setup
  -- 1.2  17/08/2016  Tagore Sathuluri                  CHG0036450 : Included the changes to fetch the status of contact
  -- 1.3  19/09/2016  Diptasurjya Chatterjee            CHG0036450 : Included the changes to fetch the status of contact
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_contact_data(p_event_id           IN NUMBER,
		         p_cust_account_id    IN NUMBER,
		         p_rltd_cust_accnt_id IN NUMBER,
		         p_cust_contact_id    IN NUMBER,
		         p_status             IN VARCHAR2)
    RETURN xxhz_customer_contact_rec --xxhz_customer_contact_tab
   IS
  
    --l_customer_contact_tab xxhz_customer_contact_tab := xxhz_customer_contact_tab();
    l_customer_contact_rec   xxhz_customer_contact_rec;
    l_status                 VARCHAR2(1) := 'A';
    l_ecom_cust_flag         VARCHAR2(10);
    l_ecom_related_cust_flag VARCHAR2(10);
  
  BEGIN
  
    /* IF p_rltd_cust_accnt_id IS NOT NULL THEN                                                                      -- CHG0036450 : Tagore Start
      l_ecom_related_cust_flag := xxhz_util.is_ecomm_customer(p_rltd_cust_accnt_id);
    
      OPEN cur_relation_status;
      FETCH cur_relation_status
        INTO l_rel_status;
      CLOSE cur_relation_status;
    
      IF l_rel_status = 'I' OR l_ecom_related_cust_flag = 'FALSE' THEN
        l_status := 'I';
      END IF;
    
    ELSE                        */
  
    --l_rel_status     := NULL;                                                                                                                                                                           -- CHG0036450 : Tagore End
    l_ecom_cust_flag := xxhz_util.is_ecomm_customer(p_cust_account_id);
    IF p_status = 'N' THEN
      l_status := 'I';
    ELSIF l_ecom_cust_flag = 'FALSE' THEN
      l_ecom_related_cust_flag := xxhz_ecomm_event_pkg.is_account_related_to_ecom(p_cust_account_id);
    
      IF l_ecom_related_cust_flag = 'FALSE' THEN
        l_status := 'I';
      END IF;
    END IF;
    --  END IF;                                                                                                               -- CHG0036450 : Tagore
  
    SELECT xxhz_customer_contact_rec(p_event_id,
			 cust_account_role_id,
			 p_cust_account_id,
			 p_rltd_cust_accnt_id,
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
			 CASE l_status
			   WHEN 'I' THEN
			    'I'
			   ELSE
			    nvl((SELECT 'A'
			        FROM   dual
			        WHERE  cont_status = 'A'
			        AND    (responsibility LIKE
				  '%BILL_TO%' OR
				  responsibility LIKE
				  '%SHIP_TO%')),
			        'I')
			 END) --BULK COLLECT
    INTO   l_customer_contact_rec
    FROM   (SELECT hcar.cust_account_role_id,
	       hca.cust_account_id,
	       hp_contact.person_pre_name_adjunct,
	       hp_contact.person_last_name,
	       hp_contact.person_first_name,
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
	       --hoc.attribute5,
	       hcar.attribute3,
	       nvl((SELECT 'A'
	           FROM   dual
	           WHERE  hca.status = 'A'
	           AND    hcar.status = 'A'
	           AND    hp_contact.status = 'A'
	           AND    hp_cust.status = 'A'
	           AND    nvl(hps.status, 'A') = 'A'
	           /*AND    nvl(hoc.status, 'A') = 'A'*/
	           ),
	           'I') cont_status
	FROM   hz_cust_accounts      hca,
	       hz_cust_account_roles hcar,
	       hz_relationships      hr,
	       hz_parties            hp_contact,
	       hz_parties            hp_cust,
	       -- hz_org_contacts            hoc,
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
	      --  AND    hoc.party_relationship_id = hr.relationship_id
	AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
	AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
	AND    hcar.party_id = xecpv.owner_table_id(+)
	AND    xpcpv_phone.phone_line_type(+) = 'GEN'
	AND    xpcpv_phone.phone_rownum(+) = 1
	AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
	AND    xpcpv_mobile.phone_rownum(+) = 1
	AND    xecpv.contact_point_type(+) = 'EMAIL'
	AND    xecpv.email_rownum(+) = 1
	AND    hcar.cust_account_role_id =
	       nvl(p_cust_contact_id, hcar.cust_account_role_id)
	AND    hca.cust_account_id =
	       nvl(p_rltd_cust_accnt_id, p_cust_account_id));
    RETURN l_customer_contact_rec;
  
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.update_error(p_event_id,
			'UNEXPECTED ERROR: ' || SQLERRM);
      RETURN NULL;
  END generate_contact_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          This function generate and return Customer-Relationship data for a given cust_account_id
  --          and related_cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  10/08/2016  Tagore Sathuluri                   Initial Build
  -- 1.1  11/29/2017  Diptasurjya Chatterjee             INC0107834 - handle multiple relationship records for
  --                                                     same account and OU combination
  -- --------------------------------------------------------------------------------------------
  FUNCTION generate_relationship_data(p_event_id           IN NUMBER,
			  p_cust_account_id    IN NUMBER,
			  p_rltd_cust_accnt_id IN NUMBER,
			  p_org_id             IN NUMBER,
			  p_status             IN VARCHAR2)
    RETURN xxhz_customer_acct_rel_rec IS
  
    l_customer_acct_rel_rec xxhz_customer_acct_rel_rec;
  BEGIN
    BEGIN
      -- INC0107834
      SELECT xxhz_customer_acct_rel_rec(p_event_id,
			    hcara.related_cust_account_id,
			    hcara.cust_account_id,
			    hcara.org_id,
			    hcara.status) -- BULK COLLECT
      INTO   l_customer_acct_rel_rec
      FROM   hz_cust_acct_relate_all hcara
      WHERE  cust_account_id = p_cust_account_id
      AND    related_cust_account_id = p_rltd_cust_accnt_id
      AND    org_id = p_org_id
      AND    org_id IN (SELECT hro.organization_id org_id
		FROM   hr_operating_units    hro,
		       hr_organization_units hru
		WHERE  hro.organization_id = hru.organization_id
		AND    hru.attribute7 = 'Y');
      -- INC0107834 - Start dipta
    EXCEPTION
      WHEN too_many_rows THEN
        BEGIN
          SELECT xxhz_customer_acct_rel_rec(p_event_id,
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
          AND    org_id IN (SELECT hro.organization_id org_id
		    FROM   hr_operating_units    hro,
		           hr_organization_units hru
		    WHERE  hro.organization_id = hru.organization_id
		    AND    hru.attribute7 = 'Y');
        EXCEPTION
          WHEN no_data_found THEN
	SELECT xxhz_customer_acct_rel_rec(p_event_id,
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
	        AND    org_id IN
		   (SELECT hro.organization_id org_id
		     FROM   hr_operating_units    hro,
			hr_organization_units hru
		     WHERE  hro.organization_id = hru.organization_id
		     AND    hru.attribute7 = 'Y')
	        ORDER  BY last_update_date DESC) aa
	WHERE  rownum = 1;
        END;
    END;
    -- INC0107834 - End dipta
    RETURN l_customer_acct_rel_rec;
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.update_error(p_event_id,
			'UNEXPECTED ERROR: ' || SQLERRM);
      RETURN NULL;
  END generate_relationship_data;

  FUNCTION is_site_ou_valid(p_site_use_id IN NUMBER,
		    p_org_id      IN NUMBER) RETURN VARCHAR2 IS
    l_is_valid VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
    INTO   l_is_valid
    FROM   hz_cust_site_uses_all hcsua
    WHERE  hcsua.site_use_id = p_site_use_id
    AND    hcsua.org_id = p_org_id;
  
    RETURN l_is_valid;
  EXCEPTION
    WHEN no_data_found THEN
      l_is_valid := 'N';
      RETURN l_is_valid;
  END is_site_ou_valid;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to retry for events in error status.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  08/10/2015  Debarati Chakraverty               Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                      CHG0036750 - Call update_new procedure to update the status
  -- 1.2  02/02/2016  Debarati Chakraverty               CHG0036659 - Modify this procedure to avoid duplicate events
  --                                                     in ERR state
  -- 1.3  09/12/2017  Diptasurjya Chatterjee             INC0101904 - Account Relation error events were not reset to NEW
  -- 1.4  10/25/2017  Diptasurjya Chatterjee             INC0099319 - eCommerce related account issue
  -- --------------------------------------------------------------------------------------------
  PROCEDURE retry_error_status(p_cust_account_id IN NUMBER,
		       --p_entity_name      IN VARCHAR2,
		       p_event_id IN NUMBER,
		       --p_bpel_instance_id IN NUMBER,
		       p_entity_id IN NUMBER) IS
    l_acc_status VARCHAR2(10);
    l_event_id   NUMBER;
    l_org_id     NUMBER;
    l_exists     VARCHAR2(20);
  
    CURSOR cur_account_close(p_event_id IN NUMBER,
		     p_org_id   IN NUMBER) IS
      SELECT event_id event_id
      FROM   xxssys_events xe
      WHERE  xe.entity_name = 'ACCOUNT'
      AND    xe.entity_id = p_cust_account_id
      AND    xe.status = 'ERR'
      AND    xe.event_id <> p_event_id
      AND    xe.attribute1 = p_org_id;
  
    CURSOR cur_site_close IS
      SELECT event_id,
	 xe.entity_id
      FROM   xxssys_events xe
      WHERE  xe.entity_name IN ('SITE') -- INC0101904 - Dipta added 'ACCT_REL'
      AND    xe.attribute1 = p_cust_account_id
      AND    xe.status = 'ERR';
  
    CURSOR cur_contact_close IS
      SELECT event_id
      FROM   xxssys_events xe
      WHERE  xe.entity_name IN ('CONTACT') -- INC0101904 - Dipta added 'ACCT_REL'
      AND    xe.attribute1 = p_cust_account_id
      AND    xe.status = 'ERR';
  
    CURSOR cur_acct_rel_close(p_org_id IN NUMBER) IS
      SELECT event_id
      FROM   xxssys_events xe
      WHERE  xe.entity_name IN ('ACCT_REL') -- INC0101904 - Dipta added 'ACCT_REL'
      AND    xe.attribute1 = p_cust_account_id
      AND    xe.status = 'ERR'
      AND    xe.attribute2 = p_org_id;
  BEGIN
    check_site_ou(p_cust_account_id, l_exists, l_org_id);
  
    IF l_exists = 'TRUE' THEN
      SELECT acc_status.status,
	 acc_status.event_id
      INTO   l_acc_status,
	 l_event_id
      FROM   (SELECT xe.status,
	         xe.event_id,
	         MAX(xe.event_id) over(PARTITION BY xe.entity_id) max_event_id
	  FROM   xxssys_events xe
	  WHERE  xe.entity_id = p_cust_account_id
	  AND    xe.entity_name = 'ACCOUNT'
	  AND    xe.event_id <> p_event_id
	  AND    xe.attribute1 = l_org_id) acc_status
      WHERE  acc_status.event_id = acc_status.max_event_id;
    
      IF l_acc_status IN ('ERR') THEN
        xxssys_event_pkg.update_new(p_event_id => l_event_id /*, p_closed_flag => NULL*/);
      
        FOR i IN cur_account_close(l_event_id, l_org_id) LOOP
          xxssys_event_pkg.update_new(p_event_id => i.event_id /*, p_closed_flag => NULL*/);
        END LOOP;
      
        /*FOR j IN cur_site_cont_close LOOP
          if (j.entity_name = 'ACCT_REL' and j.attribute2 = l_org_id)
             or (j.entity_name = 'SITE' and is_site_ou_valid(j.entity_id,l_org_id) = 'Y')
             or j.entity_name = 'CONTACT' then
            xxssys_event_pkg.update_new(p_event_id => j.event_id \*, p_closed_flag => NULL*\);
          end if;
        END LOOP;*/
      
        FOR j IN cur_site_close LOOP
          IF is_site_ou_valid(j.entity_id, l_org_id) = 'Y' THEN
	xxssys_event_pkg.update_new(p_event_id => j.event_id /*, p_closed_flag => NULL*/);
          END IF;
        END LOOP;
      
        FOR k IN cur_contact_close LOOP
          xxssys_event_pkg.update_new(p_event_id => k.event_id /*, p_closed_flag => NULL*/);
        END LOOP;
      
        FOR m IN cur_acct_rel_close(l_org_id) LOOP
          xxssys_event_pkg.update_new(p_event_id => m.event_id /*, p_closed_flag => NULL*/);
        END LOOP;
        -- INC0099319 - Start
      ELSE
        FOR j IN cur_site_close LOOP
          IF is_site_ou_valid(j.entity_id, l_org_id) = 'Y' THEN
	xxssys_event_pkg.update_new(p_event_id => j.event_id /*, p_closed_flag => NULL*/);
          END IF;
        END LOOP;
      
        FOR k IN cur_contact_close LOOP
          xxssys_event_pkg.update_new(p_event_id => k.event_id /*, p_closed_flag => NULL*/);
        END LOOP;
      
        FOR m IN cur_acct_rel_close(l_org_id) LOOP
          xxssys_event_pkg.update_new(p_event_id => m.event_id /*, p_closed_flag => NULL*/);
        END LOOP;
        -- INC0099319 - End
      END IF;
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
  END retry_error_status;

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
	AND    xe.entity_name = 'ACCOUNT') acc_status
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
  --          This procedure is used to fetch customer account,site,contacts and relation details   -- CHG0036450 : Tagore
  --  BPEL process:Account- http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customeraccountprocessbpel_client_ep?wsdl
  --              Contact - http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customercontactprocessbpel_client_ep?WSDL
  --              Site - http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customersiteprocessbpel_client_ep?WSDL
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  17/06/2015  Debarati Banerjee         Initial Build
  -- 1.1  16/08/2016  Tagore Sathuluri              CHG0036450 : Reseller changes.Add function to generate and return customer
  --                                                            relation data for a given cust_account_id,related_cust_acct_id
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_customer_messages(p_max_records      IN NUMBER,
			   p_entity_name      IN VARCHAR2,
			   p_bpel_instance_id IN NUMBER,
			   p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			   x_errbuf           OUT VARCHAR2,
			   x_retcode          OUT NUMBER,
			   x_accounts         OUT xxecom.xxhz_customer_account_tab,
			   x_sites            OUT xxecom.xxhz_customer_site_tab,
			   x_contacts         OUT xxecom.xxhz_customer_contact_tab,
			   x_relation         OUT xxecom.xxhz_customer_acct_rel_tab) IS
    -- CHG0036450 : Tagore
  
    l_account_data  xxhz_customer_account_tab := xxhz_customer_account_tab();
    l_site_data     xxhz_customer_site_tab := xxhz_customer_site_tab();
    l_contact_data  xxhz_customer_contact_tab := xxhz_customer_contact_tab();
    l_relation_data xxhz_customer_acct_rel_tab := xxhz_customer_acct_rel_tab(); -- CHG0036450 : Tagore
  
    l_account_data_tmp  xxhz_customer_account_rec; --xxhz_customer_account_tab := xxhz_customer_account_tab();
    l_site_data_tmp     xxhz_customer_site_rec; --xxhz_customer_site_tab      := xxhz_customer_site_tab();
    l_contact_data_tmp  xxhz_customer_contact_rec; --xxhz_customer_contact_tab := xxhz_customer_contact_tab();
    l_relation_data_tmp xxhz_customer_acct_rel_rec; -- CHG0036450 : Tagore
  
    l_final_cust_flag VARCHAR2(10) := 'FALSE';
  
    l_status_message VARCHAR2(4000);
    l_mail_body      VARCHAR2(4000);
  
    l_event_update_status VARCHAR2(1);
    l_cust_account_id     NUMBER;
  
    l_org_id NUMBER;
    l_exists VARCHAR2(20);
  
    l_is_entity_valid VARCHAR2(1); -- CHG0042243 Dipta added
  BEGIN
    DELETE FROM xxhz_ecomm_contact_temp;
  
    INSERT INTO xxhz_ecomm_contact_temp
      SELECT DISTINCT hcar.cust_account_role_id
      FROM   hz_relationships      hr,
	 hz_cust_accounts      hca,
	 hz_cust_account_roles hcar
      WHERE  hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.attribute3 = 'Y';
  
    l_final_cust_flag := 'FALSE';
  
    IF p_event_id_tab IS NULL OR p_event_id_tab.count = 0 THEN
    
      l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_max_records,
						p_entity_name,
						g_target_name,
						p_bpel_instance_id);
      IF l_event_update_status = 'Y' THEN
        FOR entity_rec IN (SELECT xe.event_id,
		          xe.entity_name,
		          xe.entity_id,
		          xe.attribute1,
		          xe.attribute2,
		          xe.active_flag
		   FROM   xxssys_events xe
		   WHERE  bpel_instance_id = p_bpel_instance_id
		   AND    status = 'NEW') LOOP
          BEGIN
          
	xxssys_event_pkg.update_success(entity_rec.event_id);
          
	/* CHG0042243 - start */
	l_is_entity_valid := NULL;
	l_final_cust_flag := NULL;
	l_is_entity_valid := is_entity_active(entity_rec.entity_name,
				  entity_rec.entity_id,
				  entity_rec.attribute1,
				  entity_rec.attribute2);
  
  dbms_output.put_line('Here: '||l_is_entity_valid);
        
	IF l_is_entity_valid = 'N' THEN
	  l_final_cust_flag := 'TRUE';
	ELSE
	  /* CHG0042243 - end */
	
	  IF entity_rec.entity_name = 'ACCOUNT' THEN
	    BEGIN
	      validate_data(entity_rec.entity_id,
		        l_final_cust_flag,
		        l_status_message);
	      --l_cust_account_id := entity_rec.entity_id;
	    
	      NULL;
	    EXCEPTION
	      WHEN OTHERS THEN
	        xxssys_event_pkg.update_error(entity_rec.event_id,
				  'UNEXPECTED ERROR: ' ||
				  SQLERRM);
	    END;
	  
	    /* CHG0036450 : Tagore Changes Start */
	  
	  ELSIF entity_rec.entity_name = 'ACCT_REL' THEN
	    BEGIN
	    
	      validate_data(entity_rec.attribute1,
		        l_final_cust_flag,
		        l_status_message);
	      l_cust_account_id := entity_rec.attribute1;
	    
	    EXCEPTION
	      WHEN OTHERS THEN
	        xxssys_event_pkg.update_error(entity_rec.event_id,
				  'UNEXPECTED ERROR: ' ||
				  SQLERRM);
	    END;
	  
	    /* CHG0036450 : Tagore Changes Ends */
	  
	  ELSE
	    BEGIN
	    
	      validate_data(entity_rec.attribute1, /*nvl(entity_rec.attribute2, entity_rec.attribute1)*/
		        l_final_cust_flag,
		        l_status_message);
	    
	      l_cust_account_id := nvl(entity_rec.attribute2,
			       entity_rec.attribute1);
	    EXCEPTION
	      WHEN OTHERS THEN
	        xxssys_event_pkg.update_error(entity_rec.event_id,
				  'UNEXPECTED ERROR: ' ||
				  SQLERRM);
	    END;
	  END IF;
	END IF; -- CHG0042243 - end l_is_entity_valid
          
	IF l_final_cust_flag = 'FALSE' THEN
	
	  xxssys_event_pkg.update_error(entity_rec.event_id,
			        l_status_message);
	ELSE
	
	  IF entity_rec.entity_name = 'ACCOUNT' THEN
	    retry_error_status(p_cust_account_id => entity_rec.entity_id, /*p_entity_name => entity_rec.entity_name,*/
		           p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		           p_entity_id       => entity_rec.entity_id);
	  
	    l_account_data_tmp := generate_account_data(entity_rec.event_id,
					entity_rec.entity_id,
					entity_rec.attribute1,
					entity_rec.active_flag);
	    /*l_account_data     := l_account_data MULTISET UNION ALL
                                      l_account_data_tmp;
                l_account_data_tmp := xxhz_customer_account_tab();*/
	    l_account_data.extend();
	    l_account_data(l_account_data.count) := l_account_data_tmp;
	  
	  ELSIF entity_rec.entity_name = 'SITE' THEN
	  
	    retry_error_status(p_cust_account_id => entity_rec.attribute1, /*p_entity_name => entity_rec.entity_name,*/
		           p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		           p_entity_id       => entity_rec.entity_id);
	    
      if l_is_entity_valid <> 'N' then  -- CHG0042243
        /* INC0099319 - Start - Mark event as error if site does not belong to proper OU */
        check_site_ou(entity_rec.attribute1, l_exists, l_org_id);
        IF l_exists = 'TRUE' AND
           is_site_ou_valid(entity_rec.entity_id, l_org_id) = 'Y' THEN
          l_site_data_tmp := generate_site_data(entity_rec.event_id,
                  entity_rec.attribute1,
                  entity_rec.attribute2,
                  entity_rec.entity_id,
                  entity_rec.active_flag);
          /*l_site_data     := l_site_data MULTISET UNION ALL l_site_data_tmp;
                    l_site_data_tmp := xxhz_customer_site_tab();*/
          l_site_data.extend();
          l_site_data(l_site_data.count) := l_site_data_tmp;
        ELSE
          xxssys_event_pkg.update_error(entity_rec.event_id,
          'VALIDATION ERROR: Site is not assigned to proper Operating Unit');
        END IF;
        /* INC0099319 - End */
      /* CHG0042243 - Start */
      else
        l_site_data_tmp := generate_site_data(entity_rec.event_id,
                  entity_rec.attribute1,
                  entity_rec.attribute2,
                  entity_rec.entity_id,
                  entity_rec.active_flag);
                  
        l_site_data.extend();
        l_site_data(l_site_data.count) := l_site_data_tmp;
      end if;
	    /* CHG0042243 - End */
	  
	  ELSIF entity_rec.entity_name = 'CONTACT' THEN
	  
	    retry_error_status(p_cust_account_id => entity_rec.attribute1, /*p_entity_name => entity_rec.entity_name,*/
		           p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		           p_entity_id       => entity_rec.entity_id);
	  
	    l_contact_data_tmp := generate_contact_data(entity_rec.event_id,
					entity_rec.attribute1,
					entity_rec.attribute2,
					entity_rec.entity_id,
					entity_rec.active_flag);
	    /*l_contact_data     := l_contact_data MULTISET UNION ALL
                                      l_contact_data_tmp;
                l_contact_data_tmp := xxhz_customer_contact_tab();*/
	    l_contact_data.extend();
	    l_contact_data(l_contact_data.count) := l_contact_data_tmp;
	  
	    /*CHG0036450 : Tagore Changes Start */
	  
	  ELSIF entity_rec.entity_name = 'ACCT_REL' THEN
	  
	    retry_error_status(p_cust_account_id => entity_rec.entity_id,
		           p_event_id        => entity_rec.event_id,
		           p_entity_id       => entity_rec.entity_id);
	  
	    l_relation_data_tmp := generate_relationship_data(entity_rec.event_id,
					      entity_rec.attribute1,
					      entity_rec.entity_id,
					      entity_rec.attribute2,
					      entity_rec.active_flag);
	  
	    l_relation_data.extend();
	    l_relation_data(l_relation_data.count) := l_relation_data_tmp;
	  
	    /* CHG0036450 : Tagore Changes End */
	  END IF;
	END IF;
          
          EXCEPTION
	WHEN OTHERS THEN
	  xxssys_event_pkg.update_error(entity_rec.event_id,
			        'UNEXPECTED ERROR: ' || SQLERRM);
          END;
        END LOOP;
      END IF;
    ELSE
      FOR i IN 1 .. p_event_id_tab.count LOOP
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i)
						      .event_id,
						      p_entity_name,
						      g_target_name,
						      p_bpel_instance_id);
      END LOOP;
    
      FOR entity_rec IN (SELECT xe.event_id,
		        xe.entity_name,
		        xe.entity_id,
		        xe.attribute1,
		        xe.attribute2,
		        xe.active_flag
		 FROM   xxssys_events xe
		 WHERE  bpel_instance_id = p_bpel_instance_id) LOOP
        BEGIN
          xxssys_event_pkg.update_success(entity_rec.event_id);
        
          /* CHG0042243 - start */
          l_is_entity_valid := NULL;
          l_final_cust_flag := NULL;
          l_is_entity_valid := is_entity_active(entity_rec.entity_name,
				entity_rec.entity_id,
				entity_rec.attribute1,
				entity_rec.attribute2);
        dbms_output.put_line('Here: '||l_is_entity_valid);
          IF l_is_entity_valid = 'N' THEN
	l_final_cust_flag := 'TRUE';
          ELSE
	/* CHG0042243 - end */
          
	IF entity_rec.entity_name = 'ACCOUNT' THEN
	  BEGIN
	    validate_data(entity_rec.entity_id,
		      l_final_cust_flag,
		      l_status_message);
	    l_cust_account_id := entity_rec.entity_id;
	  EXCEPTION
	    WHEN OTHERS THEN
	      xxssys_event_pkg.update_error(entity_rec.event_id,
				'UNEXPECTED ERROR: ' ||
				SQLERRM);
	  END;
	
	  /* CHG0036450 : Tagore Changes Start */
	
	ELSIF entity_rec.entity_name = 'ACCT_REL' THEN
	  BEGIN
	  
	    validate_data(entity_rec.attribute1,
		      l_final_cust_flag,
		      l_status_message);
	    l_cust_account_id := entity_rec.attribute1;
	  
	  EXCEPTION
	    WHEN OTHERS THEN
	      xxssys_event_pkg.update_error(entity_rec.event_id,
				'UNEXPECTED ERROR: ' ||
				SQLERRM);
	  END;
	
	  /* CHG0036450 : Tagore Changes End */
	
	ELSE
	  BEGIN
	    validate_data( /*nvl(entity_rec.attribute2, entity_rec.attribute1)*/entity_rec.attribute1,
		      l_final_cust_flag,
		      l_status_message);
	    l_cust_account_id := nvl(entity_rec.attribute2,
			     entity_rec.attribute1);
	  EXCEPTION
	    WHEN OTHERS THEN
	      xxssys_event_pkg.update_error(entity_rec.event_id,
				'UNEXPECTED ERROR: ' ||
				SQLERRM);
	  END;
	END IF;
          END IF; -- CHG0042243 - end l_is_entity_valid
        
          IF l_final_cust_flag = 'FALSE' THEN
	xxssys_event_pkg.update_error(entity_rec.event_id,
			      l_status_message);
          ELSE
          
	IF entity_rec.entity_name = 'ACCOUNT' THEN
	
	  retry_error_status(p_cust_account_id => entity_rec.entity_id, /*p_entity_name => entity_rec.entity_name,*/
		         p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		         p_entity_id       => entity_rec.entity_id);
	
	  l_account_data_tmp := generate_account_data(entity_rec.event_id,
				          entity_rec.entity_id,
				          entity_rec.attribute1,
				          entity_rec.active_flag);
	  /*l_account_data     := l_account_data MULTISET UNION ALL
                                    l_account_data_tmp;
              l_account_data_tmp := xxhz_customer_account_tab();*/
	  l_account_data.extend();
	  l_account_data(l_account_data.count) := l_account_data_tmp;
	
	ELSIF entity_rec.entity_name = 'SITE' THEN
	  retry_error_status(p_cust_account_id => entity_rec.attribute1, /*p_entity_name => entity_rec.entity_name,*/
		         p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		         p_entity_id       => entity_rec.entity_id);
	  
    if l_is_entity_valid <> 'N' then  -- CHG0042243
	    /* INC0099319 - Start - Mark event as error if site does not belong to proper OU */
      check_site_ou(entity_rec.attribute1, l_exists, l_org_id);
      IF l_exists = 'TRUE' AND
         is_site_ou_valid(entity_rec.entity_id, l_org_id) = 'Y' THEN
        l_site_data_tmp := generate_site_data(entity_rec.event_id,
                entity_rec.attribute1,
                entity_rec.attribute2,
                entity_rec.entity_id,
                entity_rec.active_flag);
        /*l_site_data     := l_site_data MULTISET UNION ALL l_site_data_tmp;
                  l_site_data_tmp := xxhz_customer_site_tab();*/
        l_site_data.extend();
        l_site_data(l_site_data.count) := l_site_data_tmp;
      ELSE
        xxssys_event_pkg.update_error(entity_rec.event_id,
                  'VALIDATION ERROR: Site is not assigned to proper Operating Unit');
      END IF;
	    /* INC0099319 - End */
    /* CHG0042243 - Start */
    else
      l_site_data_tmp := generate_site_data(entity_rec.event_id,
                                            entity_rec.attribute1,
                                            entity_rec.attribute2,
                                            entity_rec.entity_id,
                                            entity_rec.active_flag);

      l_site_data.extend();
      l_site_data(l_site_data.count) := l_site_data_tmp;
	  end if;
    /* CHG0042243 - End */
	ELSIF entity_rec.entity_name = 'CONTACT' THEN
	
	  retry_error_status(p_cust_account_id => entity_rec.attribute1, /*p_entity_name => entity_rec.entity_name,*/
		         p_event_id        => entity_rec.event_id, /*p_bpel_instance_id => p_bpel_instance_id,*/
		         p_entity_id       => entity_rec.entity_id);
	
	  l_contact_data_tmp := generate_contact_data(entity_rec.event_id,
				          entity_rec.attribute1,
				          entity_rec.attribute2,
				          entity_rec.entity_id,
				          entity_rec.active_flag);
	  /*l_contact_data     := l_contact_data MULTISET UNION ALL
                                    l_contact_data_tmp;
              l_contact_data_tmp := xxhz_customer_contact_tab();*/
	  l_contact_data.extend();
	  l_contact_data(l_contact_data.count) := l_contact_data_tmp;
	
	  /* CHG0036450 : Tagore Changes Start */
	
	ELSIF entity_rec.entity_name = 'ACCT_REL' THEN
	
	  retry_error_status(p_cust_account_id => entity_rec.entity_id,
		         p_event_id        => entity_rec.event_id,
		         p_entity_id       => entity_rec.entity_id);
	
	  l_relation_data_tmp := generate_relationship_data(entity_rec.event_id,
					    entity_rec.attribute1,
					    entity_rec.entity_id,
					    entity_rec.attribute2,
					    entity_rec.active_flag);
	
	  l_relation_data.extend();
	  l_relation_data(l_relation_data.count) := l_relation_data_tmp;
	
	  /* CHG0036450 : Tagore Changes End */
	
	END IF;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
	xxssys_event_pkg.update_error(entity_rec.event_id,
			      'UNEXPECTED ERROR: ' || SQLERRM);
        END;
      END LOOP;
    END IF;
  
    COMMIT;
  
    x_accounts := l_account_data;
    x_sites    := l_site_data;
    x_contacts := l_contact_data;
    x_relation := l_relation_data; /* CHG0036450 : Tagore Changes */
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode := 2;
      x_errbuf  := 'ERROR: ' || SQLERRM;
    
      l_mail_body := 'The following unexpected exception occurred for Customer Interface API.' ||
	         chr(13) || chr(10) || 'Failed records : ' || chr(13) ||
	         chr(10);
      l_mail_body := l_mail_body || '  Error Message: ' || SQLERRM ||
	         chr(13) || chr(13) || chr(10) || chr(10);
      l_mail_body := l_mail_body || 'Thank you,' || chr(13) || chr(10);
      l_mail_body := l_mail_body || 'Stratasys eCommerce team' || chr(13) ||
	         chr(13) || chr(10) || chr(10);
    
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUSTOMER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUSTOMER_CC',
	    'Customer Interface Error',
	    l_mail_body,
	    'message preparation');
    
  END generate_customer_messages;

  --------------------------------------------------------------------
  --  name:           generate_cust_printer_messages
  --  create by:      Kundan Bhagat
  --  Revision:       1.0
  --  creation date:  07/07/2015
  --  BPEL process:   http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessPrinterDetailsCmp/customerprinterprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This procedure is used to fetch customer-Printer details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                  Initial Build

  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_cust_printer_messages(p_max_records      IN NUMBER,
			       p_bpel_instance_id IN NUMBER,
			       p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			       x_errbuf           OUT VARCHAR2,
			       x_retcode          OUT NUMBER,
			       x_cust_printers    OUT xxecom.xxhz_customer_printer_tab) AS
  
    l_printer_data        xxhz_customer_printer_tab := xxhz_customer_printer_tab();
    l_printer_data_tmp    xxhz_customer_printer_rec;
    l_event_update_status VARCHAR2(1);
    l_mail_body           VARCHAR2(4000);
    l_mail_entity         VARCHAR2(4000) := NULL;
    l_entity_name         VARCHAR2(10) := 'CUST_PRINT';
    l_acc_status          VARCHAR2(10);
  BEGIN
  
    IF p_event_id_tab IS NULL OR p_event_id_tab.count = 0 THEN
      l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_max_records,
						l_entity_name,
						g_target_name,
						p_bpel_instance_id);
    
      IF l_event_update_status = 'Y' THEN
        FOR entity_rec IN (SELECT event_id,
		          entity_id,
		          attribute1,
		          active_flag
		   FROM   xxssys_events
		   WHERE  bpel_instance_id = p_bpel_instance_id
		   AND    status = 'NEW') LOOP
          BEGIN
	l_acc_status := check_account_status(entity_rec.entity_id);
	IF l_acc_status = 'TRUE' THEN
	  xxssys_event_pkg.update_success(entity_rec.event_id);
	  l_printer_data_tmp := generate_printer_data(entity_rec.event_id,
				          entity_rec.entity_id,
				          entity_rec.attribute1,
				          entity_rec.active_flag);
	
	  l_printer_data.extend();
	  l_printer_data(l_printer_data.count) := l_printer_data_tmp;
	ELSE
	  xxssys_event_pkg.update_error(entity_rec.event_id,
			        'VALIDATION ERROR: Account event of ' ||
			        entity_rec.entity_id ||
			        ' customer is in ERROR status ');
	END IF;
          EXCEPTION
	WHEN OTHERS THEN
	  xxssys_event_pkg.update_error(entity_rec.event_id,
			        'UNEXPECTED ERROR: ' || SQLERRM);
          END;
        END LOOP;
      END IF;
    ELSE
      FOR i IN 1 .. p_event_id_tab.count LOOP
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i)
						      .event_id,
						      l_entity_name,
						      g_target_name,
						      p_bpel_instance_id);
      END LOOP;
    
      FOR entity_rec IN (SELECT event_id,
		        entity_id,
		        attribute1,
		        active_flag
		 FROM   xxssys_events
		 WHERE  bpel_instance_id = p_bpel_instance_id) LOOP
        BEGIN
          l_acc_status := check_account_status(entity_rec.entity_id);
          IF l_acc_status = 'TRUE' THEN
	xxssys_event_pkg.update_success(entity_rec.event_id);
	l_printer_data_tmp := generate_printer_data(entity_rec.event_id,
				        entity_rec.entity_id,
				        entity_rec.attribute1,
				        entity_rec.active_flag);
	l_printer_data.extend();
	l_printer_data(l_printer_data.count) := l_printer_data_tmp;
          ELSE
	xxssys_event_pkg.update_error(entity_rec.event_id,
			      'VALIDATION ERROR: Account event of ' ||
			      entity_rec.entity_id ||
			      ' customer is in ERROR status ');
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
	xxssys_event_pkg.update_error(entity_rec.event_id,
			      'UNEXPECTED ERROR: ' || SQLERRM);
        END;
      END LOOP;
    END IF;
  
    COMMIT;
    x_cust_printers := l_printer_data;
    x_retcode       := 0;
    x_errbuf        := 'COMPLETE';
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode   := 2;
      x_errbuf    := 'ERROR';
      l_mail_body := 'Hi,' || chr(10) || chr(10) ||
	         'The following unexpected exception occurred for Customer-Printer Interface API.' ||
	         chr(13) || chr(10) || 'Failed records : ' || chr(13) ||
	         chr(10);
      l_mail_body := l_mail_body || '  Error Message: ' || SQLERRM ||
	         chr(13) || chr(13) || chr(10) || chr(10);
      l_mail_body := l_mail_body || 'Thank you,' || chr(13) || chr(10);
      l_mail_body := l_mail_body || 'Stratasys eCommerce team' || chr(13) ||
	         chr(13) || chr(10) || chr(10);
      send_mail('XXHZ_ECOMM_EVENT_PKG_CUST_PRINTER_TO',
	    'XXHZ_ECOMM_EVENT_PKG_CUST_PRINTER_CC',
	    'Customer-Printer',
	    l_mail_body,
	    'message preparation');
  END generate_cust_printer_messages;
END xxhz_ecomm_message_pkg;
/
