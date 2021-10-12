CREATE OR REPLACE PACKAGE BODY APPS.xxhz_customer_load_pkg AS

  g_target_name         VARCHAR2(10) := 'HYBRIS';
  g_account_entity_name VARCHAR2(10) := 'ACCOUNT';
  g_site_entity_name    VARCHAR2(10) := 'SITE';
  g_contact_entity_name VARCHAR2(10) := 'CONTACT';
  ----------------------------------------------------------------------------------
  --  name:              xxhz_customer_extract_pkg
  --  create by:         Debarati Banerjee
  --  Revision:          1.0
  --  creation date:     17/07/2015
  ----------------------------------------------------------------------------------
  --  purpose :  CHANGE - CHG0035649
  --          : This package is used to load xxssys_events table with
  --           customer Account,sites and contacts information.
  --modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   17/07/2015    Debarati Banerjee  CHANGE CHG0035649     initial build
  ------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --         This function checks the customer's organization id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_org(p_cust_account_id IN NUMBER,
                     p_party_id        IN NUMBER) RETURN BOOLEAN IS
    l_org NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_org
    FROM   hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa
    WHERE  nvl(hps.status, 'A') = 'A'
    AND    hcasa.status = 'A'
    AND    hps.party_id = p_party_id
    AND    hps.party_site_id = hcasa.party_site_id
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcasa.org_id IN (SELECT hro.organization_id
                            FROM   hr_operating_units    hro,
                                   hr_organization_units hru
                            WHERE  hro.organization_id = hru.organization_id
                            AND    hru.attribute7 = 'Y');
    IF l_org > 0 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END check_org;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function checks whether customer is eCommerce customer or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ecomm_customer(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_eccom_cust NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_eccom_cust
    FROM   hz_cust_accounts      hca_ecomm,
           hz_cust_account_roles hcar_ecomm,
           hz_relationships      hr_ecomm,
           hz_parties            hp_contact_ecomm,
           hz_parties            hp_cust_ecomm,
           hz_org_contacts       hoc_ecomm,
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
    AND    nvl(hoc_ecomm.status, 'A') = 'A'
    AND    hcar_ecomm.status = 'A'
    AND    hca_ecomm.status = 'A'
    AND    hoc_ecomm.party_relationship_id = hr_ecomm.relationship_id
    AND    hoc_ecomm.attribute5 = 'Y'
    AND    nvl(hps_ecomm.status, 'A') = 'A'
    AND    hca_ecomm.cust_account_id = p_cust_account_id;
  
    IF l_eccom_cust > 0 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END check_ecomm_customer;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from ACCOUNT level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ship_acct_pl(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
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
    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
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
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END check_ship_acct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from primary BILL_TO level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ship_bill_pl(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
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
    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
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
           (SELECT hcsua.price_list_id price_list_id
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
             AND    hps.party_id = hp.party_id
             AND    hps.party_site_id = hcasa.party_site_id
             AND    hcasa.cust_account_id = hca.cust_account_id
             AND    hca.cust_account_id = p_cust_account_id
             AND    hcsua.price_list_id IS NOT NULL);
  
    IF l_pl_check > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END check_ship_bill_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           Account level pricelist is blank and different BILL_TO sites have different pricelists
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_bill_acctnull_pl(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_pl_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   hz_cust_site_uses_all  hcsua_bill,
           hz_cust_acct_sites_all hcasa_bill,
           hz_party_sites         hps_bill,
           hz_cust_accounts       hca_bill,
           hz_parties             hp_bill
    WHERE  hcsua_bill.cust_acct_site_id = hcasa_bill.cust_acct_site_id
    AND    hcsua_bill.site_use_code IN ('BILL_TO')
    AND    hcsua_bill.status = 'A'
    AND    hcasa_bill.status = 'A'
    AND    hp_bill.status = 'A'
    AND    hca_bill.status = 'A'
    AND    nvl(hps_bill.status, 'A') = 'A'
    AND    hps_bill.party_id = hp_bill.party_id
    AND    hps_bill.party_site_id = hcasa_bill.party_site_id
    AND    hcasa_bill.org_id IN (SELECT hro.organization_id
                                 FROM   hr_operating_units    hro,
                                        hr_organization_units hru
                                 WHERE  hro.organization_id = hru.organization_id
                                 AND    hru.attribute7 = 'Y')
    AND    hcasa_bill.cust_account_id = hca_bill.cust_account_id
    AND    hcasa_bill.cust_account_id IN
           (SELECT cust_account_id
             FROM   (SELECT cust_account_id,
                            party_name,
                            COUNT(*)
                     FROM   (SELECT DISTINCT hcasa.cust_account_id,
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
                             AND    flvv.lookup_code IN
                                    ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
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
                               party_name
                     HAVING COUNT(*) > 1));
  
    IF l_pl_check > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END check_bill_acctnull_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function fetch customer based on below condition-
  --           Account level pricelist is not blank and different BILL_TO sites have different pricelists
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_bill_acct_pl(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_pl_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_pl_check
    FROM   hz_cust_site_uses_all  hcsua_bill,
           hz_cust_acct_sites_all hcasa_bill,
           hz_party_sites         hps_bill,
           hz_cust_accounts       hca_bill,
           hz_parties             hp_bill
    WHERE  hcsua_bill.cust_acct_site_id = hcasa_bill.cust_acct_site_id
    AND    hcsua_bill.site_use_code IN ('BILL_TO')
    AND    hcsua_bill.status = 'A'
    AND    hcasa_bill.status = 'A'
    AND    hp_bill.status = 'A'
    AND    hca_bill.status = 'A'
    AND    nvl(hps_bill.status, 'A') = 'A'
    AND    hps_bill.party_id = hp_bill.party_id
    AND    hps_bill.party_site_id = hcasa_bill.party_site_id
    AND    hcasa_bill.org_id IN (SELECT hro.organization_id
                                 FROM   hr_operating_units    hro,
                                        hr_organization_units hru
                                 WHERE  hro.organization_id = hru.organization_id
                                 AND    hru.attribute7 = 'Y')
    AND    hcasa_bill.cust_account_id = hca_bill.cust_account_id
    AND    hcasa_bill.cust_account_id IN
           (SELECT cust_account_id
             FROM   (SELECT cust_account_id,
                            party_name,
                            COUNT(*)
                     FROM   (SELECT DISTINCT hcasa.cust_account_id,
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
                             AND    flvv.lookup_code IN
                                    ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
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
                             AND    hcsua.price_list_id IS NOT NULL
                             AND    hca.price_list_id IS NOT NULL)
                     GROUP  BY cust_account_id,
                               party_name
                     HAVING COUNT(*) > 1));
  
    IF l_pl_check > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END check_bill_acct_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used check primary BILL_TO and SHIP_TO pricelist.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_prim_bill_ship_pl(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_bill_pl_check NUMBER := 0;
    l_ship_pl_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_bill_pl_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa,
           hz_cust_accounts       hca,
           hz_parties             hp,
           fnd_lookup_values_vl   flvv
    WHERE  hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
    AND    hp.category_code = flvv.lookup_code
    AND    hcasa.org_id IN (SELECT hro.organization_id
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
    AND    hcsua.primary_flag = 'Y';
  
    SELECT COUNT(1)
    INTO   l_ship_pl_check
    FROM   hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa,
           hz_cust_accounts       hca,
           hz_parties             hp,
           fnd_lookup_values_vl   flvv
    WHERE  hca.party_id = hp.party_id
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
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
    AND    hcsua.primary_flag = 'Y';
  
    IF l_bill_pl_check = 1 AND l_ship_pl_check = 1 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END check_prim_bill_ship_pl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to check customer category.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------  

  FUNCTION check_cust_category(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_category NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_category
    FROM   hz_cust_accounts     hca,
           hz_parties           hp,
           fnd_lookup_values_vl flvv
    WHERE  hp.party_id = hca.party_id
    AND    hp.category_code = flvv.lookup_code
    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
    AND    hca.cust_account_id = p_cust_account_id;
    IF l_category > 0 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END check_cust_category;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This procedure is used for pre populating xxssys_events table with customer
  --            account,site and contact information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  24/07/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_data_load(x_errbuf     OUT VARCHAR2,
                               x_retcode    OUT NUMBER
                               --p_account_id IN NUMBER
                               ) IS
  
    -- To fetch Customer Account information
    CURSOR cur_cust_account IS
      SELECT hca.cust_account_id cust_account_id,
             hp.party_name party_name,
             hp.party_id party_id,
             hca.account_number,
             (SELECT hcsua.price_list_id
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
              AND    hps.party_id = hp.party_id
              AND    hps.party_site_id = hcasa.party_site_id
              AND    hca.cust_account_id = hcasa.cust_account_id) site_price_list,
             hca.price_list_id acc_price_list
      FROM   hz_cust_accounts     hca,
             hz_parties           hp,
             fnd_lookup_values_vl flvv
      WHERE  hca.party_id = hp.party_id
      AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
      AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
      AND    hp.category_code = flvv.lookup_code
      AND    hp.status = 'A'
      AND    hca.status = 'A';
      --AND    hca.cust_account_id = p_cust_id;
  
    -- To fetch Customer Site information
    CURSOR cur_cust_sites(p_cust_id NUMBER) IS
      SELECT hca.cust_account_id cust_account_id,
             hp.party_id party_id,
             hp.party_name party_name,
             TRIM(hl.address1 || ' ' || hl.address2 || ' ' || hl.address3 || ' ' ||
                  hl.address4) address,
             hl.city city,
             ftv.territory_short_name country,
             hl.county county,
             decode(ftv.territory_short_name, 'Canada', hl.province, (SELECT fl.meaning
                      FROM   fnd_lookup_values fl
                      WHERE  fl.lookup_type =
                             'US_STATE'
                      AND    fl.LANGUAGE = 'US'
                      AND    fl.lookup_code =
                             hl.state)) state,
             hl.postal_code postal_code,
             hca.price_list_id acc_pl,
             hcsua.price_list_id site_pl,
             hcsua.site_use_code add_type,
             hcasa.org_id org_id,
             hcsua.site_use_id site_id,
             hcsua.contact_id default_contact_id,
             hcsua.primary_flag default_site
      FROM   hz_cust_accounts       hca,
             hz_parties             hp,
             hz_party_sites         hps,
             hz_locations           hl,
             hz_cust_acct_sites_all hcasa,
             hz_cust_site_uses_all  hcsua,
             fnd_territories_vl     ftv,
             fnd_lookup_values_vl   flvv
      WHERE  hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
      AND    hp.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hca.status = 'A'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
      AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
      AND    hp.category_code = flvv.lookup_code
      AND    hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.org_id = hcsua.org_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hcasa.org_id IN (SELECT hro.organization_id
                              FROM   hr_operating_units    hro,
                                     hr_organization_units hru
                              WHERE  hro.organization_id = hru.organization_id
                              AND    hru.attribute7 = 'Y')
      AND    hca.cust_account_id = p_cust_id; 
    
  
    -- To fetch Customer contacts information
    CURSOR cur_cust_contacts(p_cust_id NUMBER) IS
      SELECT hcar.cust_account_role_id contact_id,
             hca.price_list_id price_list,
             hp_contact.party_id cont_party_id,
             hp_cust.party_id cust_party_id,
             hca.cust_account_id cust_account_id,
             hp_contact.person_pre_name_adjunct prefix,
             hp_contact.person_last_name last_name,
             hp_contact.person_first_name first_name,
             TRIM(hl.address1 || ' ' || hl.address2 || ' ' || hl.address3 || ' ' ||
                  hl.address4) address,
             hl.city city,
             hl.county county,
             decode(ftv.territory_short_name, 'Canada', hl.province, (SELECT fl.meaning
                      FROM   fnd_lookup_values fl
                      WHERE  fl.lookup_type =
                             'US_STATE'
                      AND    fl.LANGUAGE = 'US'
                      AND    fl.lookup_code =
                             hl.state)) state,
             ftv.territory_short_name country,
             hl.postal_code postal_code,
             xpcpv_phone.phone_number phone_number,
             xpcpv_phone.phone_area_code phone_area_code,
             xpcpv_phone.phone_country_code phone_country_code,
             xpcpv_mobile.phone_number mobile_number,
             xpcpv_mobile.phone_area_code mobile_area_code,
             xpcpv_mobile.phone_country_code mobile_country_code,
             xecpv.email_address email_address_contact,
             hp_cust.category_code contact_type,
             (SELECT listagg(hrr.responsibility_type, ',') within
              GROUP (
              ORDER  BY hrr.responsibility_type)
              FROM   hz_role_responsibility hrr
              WHERE  hrr.cust_account_role_id = hcar.cust_account_role_id) cont_role
      FROM   hz_cust_accounts           hca,
             hz_cust_account_roles      hcar,
             hz_relationships           hr,
             hz_parties                 hp_contact,
             hz_parties                 hp_cust,
             hz_org_contacts            hoc,
             hz_party_sites             hps,
             hz_locations               hl,
             fnd_territories_vl         ftv,
             fnd_lookup_values_vl       flvv,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_email_contact_point_v xecpv
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
      AND    hca.status = 'A'
      AND    hcar.status = 'A'
      AND    hp_contact.status = 'A'
      AND    hp_cust.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    nvl(hoc.status, 'A') = 'A'
      AND    hcar.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
      AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
      AND    hp_cust.category_code = flvv.lookup_code
      AND    hoc.party_relationship_id = hr.relationship_id
      --AND    hoc.attribute5 = 'Y'
      AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
      AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
      AND    hcar.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
      AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hca.cust_account_id = p_cust_id;  
      
    l_counter_rel    NUMBER := 0;
    l_account_count  NUMBER := 0;
    l_excluded_count NUMBER := 0;
    l_site_count     NUMBER := 0;
    l_contact_count  NUMBER := 0;
    l_acc_number     VARCHAR2(100);
    l_party_name     VARCHAR2(500);
    l_log            NUMBER := 0;
    l_count_acct         NUMBER;
    l_xxssys_event_rec       xxssys_events%ROWTYPE;
  BEGIN
    BEGIN   
      -- Open cursor for Customer Accounts
      FOR cur_rec_acc IN cur_cust_account/*(p_cust_id => l_dist_acc_cust_id(cur_count_rec))*/ LOOP
       IF check_ecomm_customer(p_cust_account_id => cur_rec_acc.cust_account_id) THEN 
        IF (cur_rec_acc.site_price_list IS NOT NULL AND
           cur_rec_acc.acc_price_list IS NULL) OR (cur_rec_acc.site_price_list IS NULL AND
           cur_rec_acc.acc_price_list IS NOT NULL) OR
           (cur_rec_acc.site_price_list IS NOT NULL AND
           cur_rec_acc.acc_price_list IS NOT NULL AND
           cur_rec_acc.acc_price_list = cur_rec_acc.site_price_list) THEN
        
          IF check_org(p_cust_account_id => cur_rec_acc.cust_account_id, p_party_id => cur_rec_acc.party_id) AND
             check_ship_acct_pl(p_cust_account_id => cur_rec_acc.cust_account_id) AND
             check_ship_bill_pl(p_cust_account_id => cur_rec_acc.cust_account_id) AND
             check_bill_acctnull_pl(p_cust_account_id => cur_rec_acc.cust_account_id) AND
             check_bill_acct_pl(p_cust_account_id => cur_rec_acc.cust_account_id) AND
             check_prim_bill_ship_pl(p_cust_account_id => cur_rec_acc.cust_account_id) THEN
          
            -- Checking for US Direct and US Distributor pricelist
            SELECT COUNT(qlha.list_header_id)
            INTO   l_count_acct
            FROM   qp_list_headers_all qlha
            WHERE  qlha.list_header_id =
                   nvl(cur_rec_acc.site_price_list, cur_rec_acc.acc_price_list)
            AND    qlha.NAME IN ('US Direct $', 'US Distributor $');
          
            IF l_count_acct > 0 THEN
              l_account_count := l_account_count + 1;
              --insert account data into xxssys_events table 
              l_xxssys_event_rec.target_name := g_target_name;
              l_xxssys_event_rec.entity_name := g_account_entity_name;
              l_xxssys_event_rec.entity_id   := cur_rec_acc.cust_account_id;
              l_xxssys_event_rec.attribute1  := 737;
              l_xxssys_event_rec.event_name  := 'INITIAL_LOAD';

              l_xxssys_event_rec.active_flag := 'Y';
              /*l_xxssys_event_rec.last_updated_by := g_user_id;
              l_xxssys_event_rec.created_by      := g_user_id;*/              
               xxssys_event_pkg.insert_event(l_xxssys_event_rec);
               
               
              -- Open cursor for Customer Sites
            FOR cur_rec_site IN cur_cust_sites(p_cust_id => cur_rec_acc.cust_account_id) LOOP
                l_xxssys_event_rec.target_name     := g_target_name;
                l_xxssys_event_rec.entity_name     := g_site_entity_name;
                l_xxssys_event_rec.entity_id       := cur_rec_site.site_id;
                l_xxssys_event_rec.attribute1      := cur_rec_site.cust_account_id; 
                l_xxssys_event_rec.active_flag     := 'Y'; 
                l_xxssys_event_rec.event_name  := 'INITIAL_LOAD';
                                
                xxssys_event_pkg.insert_event(l_xxssys_event_rec);               
            
                 -- Open cursor for Related Sites
            /*   FOR j IN cur_related_site(p_cust_account => cur_rec_acc.cust_account_id,
                                          p_site_use_id =>cur_rec_site.site_id) LOOP
                 --insert account data into xxssys_events table 
                  l_xxssys_event_rec.target_name := g_target_name;
                  l_xxssys_event_rec.entity_name := g_site_entity_name;
                  l_xxssys_event_rec.entity_id   := cur_rec_site.site_id;
                  
                    l_xxssys_event_rec.attribute1 := j.rel_cust_account_id;
                    l_xxssys_event_rec.attribute2 := j.cust_account_id;
                    l_xxssys_event_rec.active_flag := 'Y';
          --call insert pkg
                        xxssys_event_pkg.insert_event(l_xxssys_event_rec);
                \*IF cur_rec_relate.rel_cust_account_id IS NOT NULL THEN  
                  l_xxssys_event_rec.attribute1  := cur_rec_relate.rel_cust_account_id;
                  l_xxssys_event_rec.attribute2  := cur_rec_site.cust_account_id;
                ELSE 
                  l_xxssys_event_rec.attribute1  := cur_rec_site.cust_account_id;  
                END IF;
                   xxssys_event_pkg.insert_event(l_xxssys_event_rec);          *\      
                END LOOP;*/
                l_site_count := l_site_count + 1;
              END LOOP;
            
              -- Open cursor for Customer Contacts
             FOR cur_rec_cont IN cur_cust_contacts(p_cust_id => cur_rec_acc.cust_account_id) LOOP                                
                --FOR cur_rec_relate IN cur_cust_related(p_cust_account => cur_rec_acc.cust_account_id) LOOP
                 --insert account data into xxssys_events table 
                  l_xxssys_event_rec.target_name := g_target_name;
                  l_xxssys_event_rec.entity_name := g_contact_entity_name;
                  l_xxssys_event_rec.entity_id   := cur_rec_cont.contact_id;
                  l_xxssys_event_rec.attribute1  := cur_rec_cont.cust_account_id;  
                  l_xxssys_event_rec.event_name  := 'INITIAL_LOAD';
                  l_xxssys_event_rec.active_flag := 'Y';
               -- END IF;
                   xxssys_event_pkg.insert_event(l_xxssys_event_rec);                
               --END LOOP;
                l_contact_count := l_contact_count + 1;
                
                /*--insert related contacts
                FOR i IN cur_related_contact(p_cust_account => cur_rec_cont.cust_account_id,

                                             p_contact_id  =>cur_rec_cont.contact_id) LOOP
                  l_xxssys_event_rec.target_name := g_target_name;
                  l_xxssys_event_rec.entity_name := g_contact_entity_name;
                  l_xxssys_event_rec.entity_id   := cur_rec_cont.contact_id;
                  l_xxssys_event_rec.attribute1 := i.rel_cust_account_id;
                  l_xxssys_event_rec.attribute2 := i.cust_account_id;
                  l_xxssys_event_rec.active_flag := 'Y';
                  
                 xxssys_event_pkg.insert_event(l_xxssys_event_rec);                   
              
                END LOOP;*/
              END LOOP;              
             END IF;
            END IF;
          END IF;        
        END IF;
         
      END LOOP;

      
    -- printing extracted customer count into log file
 /*   dbms_output.put_line('Number of extracted Customer Accounts :' ||
                       l_account_count);
    dbms_output.put_line('Number of extracted Customer Sites :' ||
                       l_site_count);
    dbms_output.put_line('Number of extracted Customer Contacts :' ||
                       l_contact_count); */
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    
   END;
  
 END customer_data_load;
  
END xxhz_customer_load_pkg;
/


