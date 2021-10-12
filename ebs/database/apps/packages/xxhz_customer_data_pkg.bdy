CREATE OR REPLACE PACKAGE BODY xxhz_customer_data_pkg AS

  ----------------------------------------------------------------------------------
  --  name:              xxhz_customer_data_pkg
  --  create by:         Kundan Bhagat
  --  Revision:          1.0
  --  creation date:     10/04/2015
  ----------------------------------------------------------------------------------
  --  purpose :  CHANGE - CHG0034944
  --          : This package is used to fetch customer Account,sites and contacts information.
  --modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   10/04/2015    Kundan Bhagat  CHANGE CHG0034944     initial build
  ------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0034944
  --         This function checks the customer's organization id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function checks whether customer is eCommerce customer or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from ACCOUNT level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function fetch customer based on below condition-
  --           SHIP_TO site pricelist differs from primary BILL_TO level pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function fetch customer based on below condition-
  --           Account level pricelist is blank and different BILL_TO sites have different pricelists
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function fetch customer based on below condition-
  --           Account level pricelist is not blank and different BILL_TO sites have different pricelists
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function is used check primary BILL_TO and SHIP_TO pricelist.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This function is used to check customer category.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
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
  -- Purpose: CHANGE - CHG0034944
  --          This procedure is used to fetch and create customer account,site and contacts details into resp. files
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_data_proc(x_errbuf     OUT VARCHAR2,
                               x_retcode    OUT NUMBER,
                               p_account_id IN NUMBER) IS
  
    -- To fetch Customer Account information
    CURSOR cur_cust_account(p_cust_id NUMBER) IS
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
      AND    hca.status = 'A'
      AND    hca.cust_account_id = p_cust_id;
  
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
  
    -- To fetch Related customer information
    CURSOR cur_cust_related(p_cust_account NUMBER) IS
      SELECT hcara.related_cust_account_id rel_cust_account_id,
             hcara.cust_account_id cust_account_id,
             hp.party_name party_name,
             hp.party_id party_id,
             hca.price_list_id price_list,
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
             'N' default_site
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
      AND    hcara.status = 'A'
      AND    hcsua.status = 'A'
      AND    hcasa.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hcara.ship_to_flag = 'Y'
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
      AND    hcara.related_cust_account_id = p_cust_account;
  
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
      AND    hoc.attribute5 = 'Y'
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
  
    -- To fetch incremental Customer Account information
    CURSOR cur_incremental_account(p_from_date DATE, p_to_date DATE) IS
      SELECT DISTINCT (hca.cust_account_id) cust_account_id
      FROM   hz_cust_accounts hca,
             hz_parties       hp --,
      --   fnd_lookup_values_vl flvv
      WHERE  hca.party_id = hp.party_id
            --    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
            --    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
            --    AND    hp.category_code = flvv.lookup_code
            --      AND    hp.status = 'A'
            --      AND    hca.status = 'A'
      AND    (hca.last_update_date BETWEEN p_from_date AND p_to_date OR
            hca.creation_date BETWEEN p_from_date AND p_to_date OR
            hp.last_update_date BETWEEN p_from_date AND p_to_date OR
            hp.creation_date BETWEEN p_from_date AND p_to_date);
  
    -- To fetch incremental Customer Site information
    CURSOR cur_incremental_sites(p_from_date DATE, p_to_date DATE) IS
      SELECT DISTINCT (hca.cust_account_id) cust_account_id
      FROM   hz_cust_accounts       hca,
             hz_parties             hp,
             hz_party_sites         hps,
             hz_locations           hl,
             hz_cust_acct_sites_all hcasa,
             hz_cust_site_uses_all  hcsua,
             fnd_territories_vl     ftv --,
      --     fnd_lookup_values_vl   flvv
      WHERE  hca.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
            --      AND    hp.status = 'A'
            --      AND    nvl(hps.status, 'A') = 'A'
            --      AND    hca.status = 'A'
            --      AND    hcsua.status = 'A'
            --      AND    hcasa.status = 'A'
            --    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
            --    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
            --    AND    hp.category_code = flvv.lookup_code
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
      AND    (hca.last_update_date BETWEEN p_from_date AND p_to_date OR
            hca.creation_date BETWEEN p_from_date AND p_to_date OR
            hp.last_update_date BETWEEN p_from_date AND p_to_date OR
            hp.creation_date BETWEEN p_from_date AND p_to_date OR
            hps.last_update_date BETWEEN p_from_date AND p_to_date OR
            hps.creation_date BETWEEN p_from_date AND p_to_date OR
            hl.last_update_date BETWEEN p_from_date AND p_to_date OR
            hl.creation_date BETWEEN p_from_date AND p_to_date OR
            hcasa.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcasa.creation_date BETWEEN p_from_date AND p_to_date OR
            hcsua.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcsua.creation_date BETWEEN p_from_date AND p_to_date);
  
    -- To fetch incremental related Customer ship_to site information
    CURSOR cur_incremental_rel_sites(p_from_date DATE, p_to_date DATE) IS
      SELECT DISTINCT (hca.cust_account_id) cust_account_id
      FROM   hz_cust_accounts        hca,
             hz_cust_accounts        hca_rel,
             hz_cust_site_uses_all   hcsua,
             hz_cust_acct_sites_all  hcasa,
             hz_parties              hp,
             hz_party_sites          hps,
             hz_cust_acct_relate_all hcara,
             hz_locations            hl,
             fnd_territories_vl      ftv
      WHERE  hca_rel.cust_account_id = hcasa.cust_account_id
      AND    hca_rel.party_id = hp.party_id
      AND    hps.party_id = hp.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcara.cust_account_id <> hcara.related_cust_account_id
            --      AND    hcsua.status = 'A'
            --      AND    hcasa.status = 'A'
            --      AND    hca_rel.status = 'A'
            --      AND    hca.status = 'A'
            --      AND    hp.status = 'A'
            --      AND    nvl(hps.status, 'A') = 'A'
            --      AND    hcara.status = 'A'
      AND    hcara.ship_to_flag = 'Y'
      AND    hcara.cust_account_id = hca.cust_account_id
      AND    hcara.related_cust_account_id = hca_rel.cust_account_id
      AND    hcsua.site_use_code IN ('SHIP_TO')
      AND    hcasa.org_id = hcsua.org_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    hps.location_id = hl.location_id
      AND    hl.country = ftv.territory_code(+)
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
      AND    (hca.last_update_date BETWEEN p_from_date AND p_to_date OR
            hca.creation_date BETWEEN p_from_date AND p_to_date OR
            hca_rel.last_update_date BETWEEN p_from_date AND p_to_date OR
            hca_rel.creation_date BETWEEN p_from_date AND p_to_date OR
            hcasa.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcasa.creation_date BETWEEN p_from_date AND p_to_date OR
            hcsua.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcsua.creation_date BETWEEN p_from_date AND p_to_date OR
            hp.last_update_date BETWEEN p_from_date AND p_to_date OR
            hp.creation_date BETWEEN p_from_date AND p_to_date OR
            hps.last_update_date BETWEEN p_from_date AND p_to_date OR
            hps.creation_date BETWEEN p_from_date AND p_to_date OR
            hcara.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcara.creation_date BETWEEN p_from_date AND p_to_date OR
            hl.last_update_date BETWEEN p_from_date AND p_to_date OR
            hl.creation_date BETWEEN p_from_date AND p_to_date);
  
    -- To fetch incremental Customer contacts information
    CURSOR cur_incremental_contacts(p_from_date DATE, p_to_date DATE) IS
      SELECT DISTINCT (hca.cust_account_id) cust_account_id
      FROM   hz_cust_accounts      hca,
             hz_cust_account_roles hcar,
             hz_relationships      hr,
             hz_parties            hp_contact,
             hz_parties            hp_cust,
             hz_org_contacts       hoc,
             hz_party_sites        hps,
             hz_locations          hl,
             fnd_territories_vl    ftv,
             --   fnd_lookup_values_vl       flvv,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_email_contact_point_v xecpv
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hl.location_id(+) = hps.location_id
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hl.country = ftv.territory_code(+)
            --      AND    hca.status = 'A'
            --      AND    hcar.status = 'A'
            --      AND    hp_contact.status = 'A'
            --      AND    hp_cust.status = 'A'
            --      AND    nvl(hps.status, 'A') = 'A'
            --      AND    nvl(hoc.status, 'A') = 'A'
            --      AND    hcar.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
            --    AND    flvv.lookup_type = 'CUSTOMER_CATEGORY'
            --    AND    flvv.lookup_code IN ('AGENT', 'END CUSTOMER', 'CUSTOMER', 'DISTRIBUTOR')
            --    AND    hp_cust.category_code = flvv.lookup_code
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    hoc.attribute5 = 'Y'
      AND    hcar.party_id = xpcpv_phone.owner_table_id(+)
      AND    hcar.party_id = xpcpv_mobile.owner_table_id(+)
      AND    hcar.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'MOBILE'
      AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    (hca.last_update_date BETWEEN p_from_date AND p_to_date OR
            hca.creation_date BETWEEN p_from_date AND p_to_date OR
            hcar.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcar.creation_date BETWEEN p_from_date AND p_to_date OR
            hr.last_update_date BETWEEN p_from_date AND p_to_date OR
            hr.creation_date BETWEEN p_from_date AND p_to_date OR
            hp_contact.last_update_date BETWEEN p_from_date AND p_to_date OR
            hp_contact.creation_date BETWEEN p_from_date AND p_to_date OR
            hp_cust.last_update_date BETWEEN p_from_date AND p_to_date OR
            hp_cust.creation_date BETWEEN p_from_date AND p_to_date OR
            hoc.last_update_date BETWEEN p_from_date AND p_to_date OR
            hoc.creation_date BETWEEN p_from_date AND p_to_date OR
            hps.last_update_date BETWEEN p_from_date AND p_to_date OR
            hps.creation_date BETWEEN p_from_date AND p_to_date OR
            hl.last_update_date BETWEEN p_from_date AND p_to_date OR
            hl.creation_date BETWEEN p_from_date AND p_to_date OR
            xpcpv_phone.last_update_date BETWEEN p_from_date AND p_to_date OR
            xpcpv_phone.creation_date BETWEEN p_from_date AND p_to_date OR
            xpcpv_mobile.last_update_date BETWEEN p_from_date AND p_to_date OR
            xpcpv_mobile.creation_date BETWEEN p_from_date AND p_to_date OR
            xecpv.last_update_date BETWEEN p_from_date AND p_to_date OR
            xecpv.creation_date BETWEEN p_from_date AND p_to_date);
  
    --  Customer related cust_account_id
    CURSOR cur_rel_cust(p_from_date DATE, p_to_date DATE) IS
      SELECT DISTINCT (hcara.related_cust_account_id)
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.cust_account_id <> hcara.related_cust_account_id
            --      AND    hcara.status = 'A'
      AND    hcara.ship_to_flag = 'Y'
      AND    (hcara.last_update_date BETWEEN p_from_date AND p_to_date OR
            hcara.creation_date BETWEEN p_from_date AND p_to_date);
  
    --  Customer related cust_account_id
    CURSOR cur_rel_cust_site(p_cust_account NUMBER) IS
      SELECT DISTINCT (hcara.related_cust_account_id)
      FROM   hz_cust_acct_relate_all hcara
      WHERE  hcara.cust_account_id <> hcara.related_cust_account_id
            --      AND    hcara.status = 'A'
      AND    hcara.ship_to_flag = 'Y'
      AND    hcara.cust_account_id = p_cust_account;
  
    TYPE xxom_dist_cust_tab IS TABLE OF INTEGER;
    l_dist_acc_cust_id   xxom_dist_cust_tab := xxom_dist_cust_tab();
    l_dist_site_cust_id  xxom_dist_cust_tab := xxom_dist_cust_tab();
    l_dist_cont_cust_id  xxom_dist_cust_tab := xxom_dist_cust_tab();
    l_dist_rel_cust_id   xxom_dist_cust_tab := xxom_dist_cust_tab();
    l_rel_cust_id        xxom_dist_cust_tab := xxom_dist_cust_tab();
    l_rel_cust_site      xxom_dist_cust_tab := xxom_dist_cust_tab();
    v_file_account       utl_file.file_type;
    v_file_site          utl_file.file_type;
    v_file_contact       utl_file.file_type;
    l_cust_account       VARCHAR2(1000);
    l_cust_site          VARCHAR2(1000);
    l_cust_contact       VARCHAR2(1000);
    l_cust_account_temp  VARCHAR2(1000);
    l_cust_site_temp     VARCHAR2(1000);
    l_cust_contact_temp  VARCHAR2(1000);
    l_date               VARCHAR2(200);
    l_count_acct         NUMBER;
    l_billing_flag       VARCHAR2(1);
    l_shipping_flag      VARCHAR2(1);
    l_billing_cont       VARCHAR2(1);
    l_shipping_cont      VARCHAR2(1);
    l_directory_path     VARCHAR2(60);
    l_error_message      VARCHAR2(32767) := '';
    l_mail_list          VARCHAR2(500);
    l_request_id         NUMBER := fnd_global.conc_request_id;
    l_requestor          VARCHAR2(100);
    l_program_short_name VARCHAR2(100);
    l_data               VARCHAR(2000) := '';
    l_err_code           NUMBER;
    l_err_msg            VARCHAR2(200);
    file_rename_excp EXCEPTION;
    l_cur_date       DATE;
    l_last_date      DATE;
    l_from_date      DATE;
    l_to_date        DATE;
    l_counter        NUMBER := 0;
    l_counter_rel    NUMBER := 0;
    l_account_count  NUMBER := 0;
    l_excluded_count NUMBER := 0;
    l_site_count     NUMBER := 0;
    l_contact_count  NUMBER := 0;
    l_acc_number     VARCHAR2(100);
    l_party_name     VARCHAR2(500);
    l_log            NUMBER := 0;
  BEGIN
    BEGIN
      SELECT MAX(run_date)
      INTO   l_last_date
      FROM   xxhz_incremental_change
      WHERE  program_name = 'CUSTOMER MASTER';
    
    EXCEPTION
      WHEN no_data_found THEN
        l_last_date := NULL;
    END;
    l_cur_date := SYSDATE;
    INSERT INTO xxhz_incremental_change
    VALUES
      ('CUSTOMER MASTER',
       l_cur_date);
    COMMIT;
  
    l_to_date := l_cur_date;
    IF l_last_date IS NULL THEN
      l_from_date := add_months(SYSDATE, -2500);
    ELSE
      l_from_date := l_last_date;
    END IF;
  
    l_date              := to_char(SYSDATE, 'dd-MON-rrrr-hh-mi-ss');
    l_cust_account_temp := 'cust_account_' || l_date || '.csv.tmp';
    l_cust_site_temp    := 'cust_sites_' || l_date || '.csv.tmp';
    l_cust_contact_temp := 'cust_contacts_' || l_date || '.csv.tmp';
    l_cust_account      := 'cust_account_' || l_date || '.csv';
    l_cust_site         := 'cust_sites_' || l_date || '.csv';
    l_cust_contact      := 'cust_contacts_' || l_date || '.csv';
    l_directory_path    := 'XXECOMM_OUT_DIR';
  
    l_error_message := 'Error Occured while getting Notification Details for Request ID :' ||
                       l_request_id;
    SELECT fcrsv.requestor,
           fcrsv.program_short_name
    INTO   l_requestor,
           l_program_short_name
    FROM   fnd_conc_req_summary_v fcrsv
    WHERE  fcrsv.request_id = l_request_id;
  
    l_data := 'Data Directory:' || l_directory_path || chr(10) || 'Requestor:' ||
              l_requestor;
  
    -- Generate customer accounts csv file
    l_error_message := ' Error Occured while Deriving v_file_account';
    v_file_account  := utl_file.fopen(location => l_directory_path, filename => l_cust_account_temp, open_mode => 'w');
    -- Generate customer sites csv file
    l_error_message := ' Error Occured while Deriving v_file_site';
    v_file_site     := utl_file.fopen(location => l_directory_path, filename => l_cust_site_temp, open_mode => 'w');
    -- Generate customer contacts csv file
    l_error_message := ' Error Occured while Deriving v_file_contact';
    v_file_contact  := utl_file.fopen(location => l_directory_path, filename => l_cust_contact_temp, open_mode => 'w');
  
    /* This will create the heading in Customer Account csv file */
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (v_file_account): Headers';
    utl_file.put_line(v_file_account, '"cust_account_id","party_name","acc_price_list","customer_number"');
    /* This will create the heading in Customer Site csv file */
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (v_file_site): Headers';
    utl_file.put_line(v_file_site, '"cust_account_id","address","city","country","county","state","postal_code","l_billing_flag","l_shipping_flag","org_id","site_id","default_contact_id","default_site"');
    /* This will create the heading in Customer Contact csv file */
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (v_file_contact): Headers';
    utl_file.put_line(v_file_contact, '"contact_id","cust_account_id","prefix","last_name","first_name","address","city","county","state","country","postal_code","phone_number","phone_area_code","phone_country_code","mobile_number","mobile_area_code","mobile_country_code","email_address_contact","contact_type","l_billing_cont","l_shipping_cont"');
  
    -- used to fetch Customer account incremental changes
    FOR acc_rec IN cur_incremental_account(p_from_date => l_from_date, p_to_date => l_to_date) LOOP
      IF check_ecomm_customer(p_cust_account_id => acc_rec.cust_account_id) THEN
        l_counter := l_counter + 1;
        l_dist_acc_cust_id.EXTEND;
        l_dist_acc_cust_id(l_counter) := acc_rec.cust_account_id;
      END IF;
    END LOOP;
  
    -- used to fetch Customer site incremental changes
    l_counter     := 0;
    l_counter_rel := 0;
    FOR site_rec IN cur_incremental_sites(p_from_date => l_from_date, p_to_date => l_to_date) LOOP
      FOR custrel_rec IN cur_rel_cust_site(p_cust_account => site_rec.cust_account_id) LOOP
        IF check_ecomm_customer(p_cust_account_id => custrel_rec.related_cust_account_id) THEN
          l_counter_rel := l_counter_rel + 1;
          l_rel_cust_site.EXTEND;
          l_rel_cust_site(l_counter_rel) := custrel_rec.related_cust_account_id;
        END IF;
      END LOOP;
      IF check_ecomm_customer(p_cust_account_id => site_rec.cust_account_id) THEN
        l_counter := l_counter + 1;
        l_dist_site_cust_id.EXTEND;
        l_dist_site_cust_id(l_counter) := site_rec.cust_account_id;
      END IF;
    END LOOP;
  
    -- used to fetch Customer related site incremental changes
    l_counter_rel := 0;
    FOR custrel_rec IN cur_rel_cust(p_from_date => l_from_date, p_to_date => l_to_date) LOOP
      IF check_ecomm_customer(p_cust_account_id => custrel_rec.related_cust_account_id) THEN
        l_counter_rel := l_counter_rel + 1;
        l_rel_cust_id.EXTEND;
        l_rel_cust_id(l_counter_rel) := custrel_rec.related_cust_account_id;
      END IF;
    END LOOP;
  
    -- used to fetch Customer contact incremental changes
    l_counter := 0;
    FOR cont_rec IN cur_incremental_contacts(p_from_date => l_from_date, p_to_date => l_to_date) LOOP
      IF check_ecomm_customer(p_cust_account_id => cont_rec.cust_account_id) THEN
        l_counter := l_counter + 1;
        l_dist_cont_cust_id.EXTEND;
        l_dist_cont_cust_id(l_counter) := cont_rec.cust_account_id;
      END IF;
    END LOOP;
  
    -- used to fetch Related Customer incremental changes
    l_counter := 0;
    FOR rel_rec IN cur_incremental_rel_sites(p_from_date => l_from_date, p_to_date => l_to_date) LOOP
      IF check_ecomm_customer(p_cust_account_id => rel_rec.cust_account_id) THEN
        l_counter := l_counter + 1;
        l_dist_rel_cust_id.EXTEND;
        l_dist_rel_cust_id(l_counter) := rel_rec.cust_account_id;
      END IF;
    END LOOP;
  
    -- Fetching distinct cust_account_ids from type
    l_dist_acc_cust_id := l_dist_acc_cust_id MULTISET UNION DISTINCT l_dist_site_cust_id;
    l_dist_acc_cust_id := l_dist_acc_cust_id MULTISET UNION DISTINCT l_rel_cust_id;
    l_dist_acc_cust_id := l_dist_acc_cust_id MULTISET UNION DISTINCT l_rel_cust_site;
    l_dist_acc_cust_id := l_dist_acc_cust_id MULTISET UNION DISTINCT l_dist_cont_cust_id;
    l_dist_acc_cust_id := l_dist_acc_cust_id MULTISET UNION DISTINCT l_dist_rel_cust_id;
  
    FOR cur_count_rec IN 1 .. l_dist_acc_cust_id.COUNT LOOP
      l_log := 0;
      IF NOT check_cust_category(p_cust_account_id => l_dist_acc_cust_id(cur_count_rec)) THEN
        BEGIN
          SELECT hca.account_number,
                 hp.party_name
          INTO   l_acc_number,
                 l_party_name
          FROM   hz_cust_accounts hca,
                 hz_parties       hp
          WHERE  hp.party_id = hca.party_id
          AND    hca.cust_account_id = l_dist_acc_cust_id(cur_count_rec);
        EXCEPTION
          WHEN no_data_found THEN
            l_acc_number := NULL;
            l_party_name := NULL;
        END;
        fnd_file.put_line(fnd_file.log, 'Customer excluded - Customer category not in ''AGENT'', ''END CUSTOMER'', ''CUSTOMER'', ''DISTRIBUTOR''');
        fnd_file.put_line(fnd_file.log, chr(13) || 'Excluded Customer Account Name :' ||
                           l_party_name || chr(13) ||
                           'Excluded Customer Account Number :' ||
                           l_acc_number);
        fnd_file.put_line(fnd_file.log, '---------------------------------------------------------------------');
        l_excluded_count := l_excluded_count + 1;
      END IF;
    
      -- Open cursor for Customer Accounts
      FOR cur_rec_acc IN cur_cust_account(p_cust_id => l_dist_acc_cust_id(cur_count_rec)) LOOP
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
              utl_file.put_line(v_file_account, '"' || cur_rec_acc.cust_account_id ||
                                 '","' || cur_rec_acc.party_name || '","' ||
                                 nvl(cur_rec_acc.site_price_list, cur_rec_acc.acc_price_list) ||
                                 '","' || cur_rec_acc.account_number || '"');
              l_account_count := l_account_count + 1;
              fnd_file.put_line(fnd_file.log, chr(13) || 'Customer Account Name :' ||
                                 cur_rec_acc.party_name || chr(13) ||
                                 'Customer Account Number :' ||
                                 cur_rec_acc.account_number);
              fnd_file.put_line(fnd_file.log, '---------------------------------------------------------------------');
              -- Open cursor for Related Customer
              FOR cur_rec_relate IN cur_cust_related(p_cust_account => cur_rec_acc.cust_account_id) LOOP
                BEGIN
                  SELECT decode(cur_rec_relate.add_type, 'BILL_TO', 'Y', 'N'),
                         decode(cur_rec_relate.add_type, 'SHIP_TO', 'Y', 'N')
                  INTO   l_billing_flag,
                         l_shipping_flag
                  FROM   dual;
                EXCEPTION
                  WHEN no_data_found THEN
                    l_billing_flag  := NULL;
                    l_shipping_flag := NULL;
                END;
                utl_file.put_line(v_file_site, '"' || cur_rec_relate.rel_cust_account_id ||
                                   '","' || cur_rec_relate.address || '","' ||
                                   cur_rec_relate.city || '","' ||
                                   cur_rec_relate.country || '","' ||
                                   cur_rec_relate.county || '","' ||
                                   cur_rec_relate.state || '","' ||
                                   cur_rec_relate.postal_code || '","' ||
                                   l_billing_flag || '","' || l_shipping_flag ||
                                   '","' || cur_rec_relate.org_id || '","' ||
                                   cur_rec_relate.site_id || '","' ||
                                   cur_rec_relate.default_contact_id || '","' ||
                                   cur_rec_relate.default_site || '"');
                l_site_count := l_site_count + 1;
              END LOOP;
            
              -- Open cursor for Customer Sites
              FOR cur_rec_site IN cur_cust_sites(p_cust_id => cur_rec_acc.cust_account_id) LOOP
                BEGIN
                  SELECT decode(cur_rec_site.add_type, 'BILL_TO', 'Y', 'N'),
                         decode(cur_rec_site.add_type, 'SHIP_TO', 'Y', 'N')
                  INTO   l_billing_flag,
                         l_shipping_flag
                  FROM   dual;
                EXCEPTION
                  WHEN no_data_found THEN
                    l_billing_flag  := NULL;
                    l_shipping_flag := NULL;
                END;
                utl_file.put_line(v_file_site, '"' || cur_rec_site.cust_account_id ||
                                   '","' || cur_rec_site.address || '","' ||
                                   cur_rec_site.city || '","' ||
                                   cur_rec_site.country || '","' ||
                                   cur_rec_site.county || '","' ||
                                   cur_rec_site.state || '","' ||
                                   cur_rec_site.postal_code || '","' ||
                                   l_billing_flag || '","' || l_shipping_flag ||
                                   '","' || cur_rec_site.org_id || '","' ||
                                   cur_rec_site.site_id || '","' ||
                                   cur_rec_site.default_contact_id || '","' ||
                                   cur_rec_site.default_site || '"');
                l_site_count := l_site_count + 1;
              END LOOP;
            
              -- Open cursor for Customer Contacts
              FOR cur_rec_cont IN cur_cust_contacts(p_cust_id => cur_rec_acc.cust_account_id) LOOP
                BEGIN
                  SELECT decode(cur_rec_cont.cont_role, 'BILL_TO,SHIP_TO', 'Y', 'BILL_TO', 'Y', '', 'Y', 'N'),
                         decode(cur_rec_cont.cont_role, 'BILL_TO,SHIP_TO', 'Y', 'SHIP_TO', 'Y', '', 'Y', 'N')
                  INTO   l_billing_cont,
                         l_shipping_cont
                  FROM   dual;
                EXCEPTION
                  WHEN no_data_found THEN
                    l_billing_cont  := NULL;
                    l_shipping_cont := NULL;
                END;
                utl_file.put_line(v_file_contact, '"' || cur_rec_cont.contact_id || '","' ||
                                   cur_rec_cont.cust_account_id || '","' ||
                                   cur_rec_cont.prefix || '","' ||
                                   cur_rec_cont.last_name || '","' ||
                                   cur_rec_cont.first_name || '","' ||
                                   cur_rec_cont.address || '","' ||
                                   cur_rec_cont.city || '","' ||
                                   cur_rec_cont.county || '","' ||
                                   cur_rec_cont.state || '","' ||
                                   cur_rec_cont.country || '","' ||
                                   cur_rec_cont.postal_code || '","' ||
                                   cur_rec_cont.phone_number || '","' ||
                                   cur_rec_cont.phone_area_code || '","' ||
                                   cur_rec_cont.phone_country_code ||
                                   '","' || cur_rec_cont.mobile_number ||
                                   '","' || cur_rec_cont.mobile_area_code ||
                                   '","' ||
                                   cur_rec_cont.mobile_country_code ||
                                   '","' ||
                                   cur_rec_cont.email_address_contact ||
                                   '","' || cur_rec_cont.contact_type ||
                                   '","' || l_billing_cont || '","' ||
                                   l_shipping_cont || '"');
                l_contact_count := l_contact_count + 1;
              END LOOP;
            ELSE
              l_log := 1;
            END IF;
          ELSE
            l_log := 1;
          END IF;
        ELSE
          l_log := 1;
        END IF;
        IF l_log = 1 THEN
          fnd_file.put_line(fnd_file.log, 'Customer excluded due to pricelist validations');
          fnd_file.put_line(fnd_file.log, chr(13) || 'Excluded Customer Account Name :' ||
                             cur_rec_acc.party_name || chr(13) ||
                             'Excluded Customer Account Number :' ||
                             cur_rec_acc.account_number);
          fnd_file.put_line(fnd_file.log, '---------------------------------------------------------------------');
          l_excluded_count := l_excluded_count + 1;
          l_log            := 0;
        END IF;
      END LOOP;
    END LOOP;
  
    -- printing extracted customer count into log file
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of extracted Customer Accounts :' ||
                       l_account_count);
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of excluded Customer Accounts :' ||
                       l_excluded_count);
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of extracted Customer Sites :' ||
                       l_site_count);
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of extracted Customer Contacts :' ||
                       l_contact_count);
  
    l_error_message := 'Error Occured in Closing the v_file_account';
    utl_file.fclose(v_file_account);
    l_error_message := 'Error Occured in Closing the v_file_site';
    utl_file.fclose(v_file_site);
    l_error_message := 'Error Occured in Closing the v_file_contact';
    utl_file.fclose(v_file_contact);
  
    -- Renaming the file name
    BEGIN
      utl_file.frename(l_directory_path, l_cust_contact_temp, l_directory_path, l_cust_contact, TRUE);
      utl_file.frename(l_directory_path, l_cust_site_temp, l_directory_path, l_cust_site, TRUE);
      utl_file.frename(l_directory_path, l_cust_account_temp, l_directory_path, l_cust_account, TRUE);
    EXCEPTION
      WHEN OTHERS THEN
        l_error_message := l_error_message || ' : Error while Renaming the files' ||
                           ' OTHERS Exception : ' || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_message);
        RAISE file_rename_excp;
    END;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
    WHEN no_data_found THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'NO_DATA_FOUND Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.INVALID_PATH - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.INVALID_PATH - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.INVALID_PATH Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.read_error THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.READ_ERROR - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.READ_ERROR - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.READ_ERROR Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.write_error THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.WRITE_ERROR - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : UTL_FILE.WRITE_ERROR - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.WRITE_ERROR Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN file_rename_excp THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : FILE_RENAME_EXCP - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : FILE_RENAME_EXCP - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'FILE_RENAME_EXCP Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN OTHERS THEN
      utl_file.fclose(v_file_account);
      utl_file.fclose(v_file_site);
      utl_file.fclose(v_file_contact);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := 2;
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_cust_account_temp);
        utl_file.fremove(l_directory_path, l_cust_site_temp);
        utl_file.fremove(l_directory_path, l_cust_contact_temp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : OTHERS - Error while deleting the files :' || ' | ' ||
                             SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : OTHERS - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
    
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Customer Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Customer Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Customer master Files for Hybris' ||
                                                    chr(10) ||
                                                    'OTHERS Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Customer Master Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
  END customer_data_proc;
END xxhz_customer_data_pkg;
/
