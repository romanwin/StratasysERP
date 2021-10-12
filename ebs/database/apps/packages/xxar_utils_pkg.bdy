CREATE OR REPLACE PACKAGE BODY XXAR_UTILS_PKG IS

--------------------------------------------------------------------
--  name:            XXAR_UTILS_PKG
--  create by:       MAOZ.DEKEL & GABRIEL JERUSALMI
--  Revision:        1.0
--  creation date:   31/08/2009 11:41:48 AM
--------------------------------------------------------------------
--  purpose :        AR generic package
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.x  14.4.2013   yuval tal        CR-724 get_term_name_tl,add get_op_name , modify get_company_name
--                                           add get_print_inv_uom_tl
--  1.1  20.8.13     yuval tal        CR-970 add function is_account_dist
--  1.2  21.8.13     vitaly           CR-983 get_customer_open_balance and get_customer_credit_limit_amt added
--  1.3  4-aug-2015  Sandeep Akula    CHG0035932 - Added Function get_company_WEEE_num
--  1.4  02-Aug-2015 Dalit A. RAviv   CHG0035495 - Workflow for credit check Hold on SO
--                                    Modify function get_exposure_amt, add function get_usd_overdue_amount, get_location_territory
--  1.5  18-Oct-2015 Dalit A. RAviv   INC0049601 change logic at get_location_territory function.
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_company_name
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   31/08/2009
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   view that show customer profile details
  --                   will use at FRW od the orderstatus
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/08/2009  XXX               initial build
  --  1.1  07-03-2013  Ofer Suad         Get ship to name from party insted of site
  --  1.2  25.4.2013   Yuval tal         CR 724 support japan description
  --------------------------------------------------------------------
  FUNCTION get_company_name(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2 AS

    v_name VARCHAR2(150);

  BEGIN
    BEGIN
      SELECT nvl(decode(xxhz_util.get_ou_lang(p_org_id),
                        'JA', lep.attribute2,lep.name), lep.name)
        INTO v_name
        FROM xle_entity_profiles lep, hr_operating_units opu
       WHERE lep.transacting_entity_flag = 'Y'
         AND lep.legal_entity_id = opu.default_legal_context_id
         AND opu.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND lep.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_name := NULL;
    END;

    RETURN v_name;
  EXCEPTION
    WHEN OTHERS THEN
      v_name := NULL;
      RETURN v_name;
  END get_company_name;

  --------------------------------------------------------------------
  --  name:            get_company_reg_number
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_reg_number(p_legal_entity_id NUMBER,
                                  p_org_id          NUMBER) RETURN VARCHAR2 AS

    v_reg_num VARCHAR2(150);

  BEGIN

    BEGIN
      SELECT reg.registration_number
        INTO v_reg_num
        FROM xle_entity_profiles lep7,
             xle_registrations   reg,
             hr_operating_units  opu
       WHERE lep7.transacting_entity_flag = 'Y'
         AND lep7.legal_entity_id = reg.source_id
         AND lep7.legal_entity_id = opu.default_legal_context_id
         AND opu.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND reg.source_table = 'XLE_ENTITY_PROFILES'
         AND reg.identifying_flag = 'Y'
         AND lep7.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_reg_num := NULL;
    END;

    RETURN v_reg_num;
  EXCEPTION
    WHEN OTHERS THEN
      v_reg_num := NULL;
      RETURN v_reg_num;
  END get_company_reg_number;

  --------------------------------------------------------------------
  --  name:            get_company_add_reg_num
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_add_reg_num(p_legal_entity_id NUMBER,
                                   p_org_id          NUMBER) RETURN VARCHAR2 AS

    v_reg_add VARCHAR2(150);

  BEGIN

    BEGIN
      SELECT reg.attribute1
        INTO v_reg_add
        FROM xle_entity_profiles lep7,
             xle_registrations   reg,
             hr_operating_units  opu
       WHERE lep7.transacting_entity_flag = 'Y'
         AND lep7.legal_entity_id = reg.source_id
         AND lep7.legal_entity_id = opu.default_legal_context_id
         AND opu.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND reg.source_table = 'XLE_ENTITY_PROFILES'
         AND reg.identifying_flag = 'Y'
         AND lep7.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_reg_add := NULL;
    END;

    RETURN v_reg_add;

  EXCEPTION
    WHEN OTHERS THEN
      v_reg_add := NULL;
      RETURN v_reg_add;

  END get_company_add_reg_num;

  --------------------------------------------------------------------
  --  name:            get_company_url
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_url(p_legal_entity_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 AS

    v_url VARCHAR2(150);

  BEGIN

    BEGIN
      SELECT url.url
        INTO v_url
        FROM xle_entity_profiles lep2,
             hz_parties          hzp,
             hz_contact_points   url,
             hr_operating_units  opu2
       WHERE lep2.transacting_entity_flag = 'Y'
         AND lep2.party_id = hzp.party_id
         AND lep2.legal_entity_id = opu2.default_legal_context_id
         AND opu2.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND hzp.party_id = url.owner_table_id
         AND url.owner_table_name = 'HZ_PARTIES'
         AND url.contact_point_type = 'WEB'
         AND lep2.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_url := NULL;
    END;

    RETURN v_url;
  EXCEPTION
    WHEN OTHERS THEN
      v_url := NULL;
      RETURN v_url;
  END get_company_url;

  --------------------------------------------------------------------
  --  name:            get_company_email
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_email(p_legal_entity_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 AS

    v_email VARCHAR2(150);

  BEGIN
    BEGIN
      SELECT email.email_address
        INTO v_email
        FROM xle_entity_profiles lep3,
             hz_parties          hzp2,
             hz_contact_points   email,
             hr_operating_units  opu3
       WHERE lep3.transacting_entity_flag = 'Y'
         AND lep3.party_id = hzp2.party_id
         AND hzp2.party_id = email.owner_table_id
         AND lep3.legal_entity_id = opu3.default_legal_context_id
         AND opu3.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND email.owner_table_name = 'HZ_PARTIES'
         AND email.contact_point_type = 'EMAIL'
         AND lep3.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_email := NULL;
    END;

    RETURN v_email;
  EXCEPTION
    WHEN OTHERS THEN
      v_email := NULL;
      RETURN v_email;

  END get_company_email;

  --------------------------------------------------------------------
  --  name:            get_company_phone
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_phone(p_legal_entity_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 AS

    v_phone VARCHAR2(150);

  BEGIN
    BEGIN
      SELECT phone.phone_country_code ||
             decode(phone.phone_country_code, NULL, NULL, '-') ||
             phone.phone_area_code ||
             decode(phone.phone_area_code, NULL, NULL, '-') ||
             phone.phone_number phone_number
        INTO v_phone
        FROM xle_entity_profiles lep4,
             hz_parties          hzp3,
             hz_contact_points   phone,
             hr_operating_units  opu4
       WHERE lep4.transacting_entity_flag = 'Y'
         AND lep4.party_id = hzp3.party_id
         AND hzp3.party_id = phone.owner_table_id
         AND lep4.legal_entity_id = opu4.default_legal_context_id
         AND opu4.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND phone.owner_table_name = 'HZ_PARTIES'
         AND phone.contact_point_type = 'PHONE'
         AND phone.phone_line_type = 'GEN'
         AND lep4.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_phone := NULL;
    END;

    RETURN v_phone;
  EXCEPTION
    WHEN OTHERS THEN
      v_phone := NULL;
      RETURN v_phone;
  END get_company_phone;

  --------------------------------------------------------------------
  --  name:            get_company_fax
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_fax(p_legal_entity_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 AS

    v_fax VARCHAR2(150);

  BEGIN
    BEGIN
      SELECT fax.phone_country_code ||
             decode(fax.phone_country_code, NULL, NULL, '-') ||
             fax.phone_area_code ||
             decode(fax.phone_area_code, NULL, NULL, '-') ||
             fax.phone_number fax_number
        INTO v_fax
        FROM xle_entity_profiles lep5,
             hz_parties          hzp4,
             hz_contact_points   fax,
             hr_operating_units  opu5
       WHERE lep5.transacting_entity_flag = 'Y'
         AND lep5.party_id = hzp4.party_id
         AND lep5.legal_entity_id = opu5.default_legal_context_id
         AND opu5.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND hzp4.party_id = fax.owner_table_id
         AND fax.owner_table_name = 'HZ_PARTIES'
         AND fax.contact_point_type = 'PHONE'
         AND fax.phone_line_type = 'FAX'
         AND lep5.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_fax := NULL;
    END;

    RETURN v_fax;
  EXCEPTION
    WHEN OTHERS THEN
      v_fax := NULL;
      RETURN v_fax;
  END get_company_fax;

  --------------------------------------------------------------------
  --  name:            get_company_address
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_company_address(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2 AS

    v_address VARCHAR2(200);

  BEGIN
    BEGIN
      SELECT hrl.address_line_1 || ' ' || hrl.address_line_2 || ' ' ||
             hrl.address_line_3 || ' ' || hrl.town_or_city || ' ' ||
             hrl.postal_code || ' ' || ter.territory_short_name company_address
        INTO v_address
        FROM xle_entity_profiles lep6,
             xle_registrations   reg,
             hz_parties          hzp5,
             hr_operating_units  opu6,
             hr_locations_all    hrl,
             fnd_territories_vl  ter
       WHERE lep6.transacting_entity_flag = 'Y'
         AND lep6.party_id = hzp5.party_id
         AND lep6.legal_entity_id = reg.source_id
         AND lep6.legal_entity_id = opu6.default_legal_context_id
         AND opu6.organization_id = p_org_id --fnd_profile.VALUE('ORG_ID')
         AND reg.source_table = 'XLE_ENTITY_PROFILES'
         AND hrl.location_id = reg.location_id
         AND reg.identifying_flag = 'Y'
         AND ter.territory_code = hrl.country
         AND lep6.legal_entity_id = p_legal_entity_id; --23274

    EXCEPTION
      WHEN OTHERS THEN
        v_address := NULL;
    END;

    RETURN v_address;
  EXCEPTION
    WHEN OTHERS THEN
      v_address := NULL;
      RETURN v_address;
  END get_company_address;

  --------------------------------------------------------------------
  --  name:            sum_prepayment
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION sum_prepayment(p_trx_number VARCHAR2, p_profile_prepay VARCHAR2)
    RETURN NUMBER IS
    v_sum_prepay NUMBER;
  BEGIN

    SELECT SUM(ctl.extended_amount)
      INTO v_sum_prepay
      FROM ra_customer_trx_lines ctl,
           ra_customer_trx_all   cta,
           mtl_system_items_b    msi
     WHERE cta.customer_trx_id = ctl.customer_trx_id
       AND ctl.inventory_item_id = msi.inventory_item_id
       AND msi.item_type = p_profile_prepay
       AND cta.trx_number = p_trx_number
       AND msi.organization_id = 82;

    RETURN nvl(v_sum_prepay, 0);

  EXCEPTION
    WHEN OTHERS THEN
      v_sum_prepay := 0;
      RETURN v_sum_prepay;
  END;

  --------------------------------------------------------------------
  --  name:            xxar_create_code_assignment
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE xxar_create_code_assignment(p_class VARCHAR2) IS
    p_init_msg_list       VARCHAR2(32767);
    p_code_assignment_rec apps.hz_classification_v2pub.code_assignment_rec_type;
    x_return_status       VARCHAR2(32767);
    x_msg_count           NUMBER;
    x_msg_data            VARCHAR2(32767);
    x_code_assignment_id  NUMBER;

  BEGIN

    p_init_msg_list                             := NULL;
    p_code_assignment_rec.code_assignment_id    := NULL;
    p_code_assignment_rec.owner_table_name      := 'HZ_CLASS_CATEGORIES';
    p_code_assignment_rec.owner_table_id        := NULL;
    p_code_assignment_rec.owner_table_key_1     := p_class;
    p_code_assignment_rec.owner_table_key_2     := NULL;
    p_code_assignment_rec.owner_table_key_3     := NULL;
    p_code_assignment_rec.owner_table_key_4     := NULL;
    p_code_assignment_rec.owner_table_key_5     := NULL;
    p_code_assignment_rec.class_category        := 'CLASS_CATEGORY_GROUP';
    p_code_assignment_rec.class_code            := 'INDUSTRIAL_GROUP';
    p_code_assignment_rec.primary_flag          := 'N';
    p_code_assignment_rec.content_source_type   := 'USER_ENTERED';
    p_code_assignment_rec.start_date_active     := trunc(SYSDATE);
    p_code_assignment_rec.end_date_active       := NULL;
    p_code_assignment_rec.status                := NULL;
    p_code_assignment_rec.created_by_module     := 'TCA_V2_API'; --'USER_ENTERED';
    p_code_assignment_rec.rank                  := NULL;
    p_code_assignment_rec.application_id        := NULL;
    p_code_assignment_rec.actual_content_source := 'USER_ENTERED';

    -- Now call the stored program
    -- Note: You have to use SQL Editor to edit and run this program.
    -- Therefore you cannot use bind variables to pass arguments.
    hz_classification_v2pub.create_code_assignment(p_init_msg_list,
                                                   p_code_assignment_rec,
                                                   x_return_status,
                                                   x_msg_count,
                                                   x_msg_data,
                                                   x_code_assignment_id);
    COMMIT;
    -- Output the results
    dbms_output.put_line(substr('x_return_status = ' || x_return_status,1,255));
    dbms_output.put_line(substr('x_code_assignment_id = ' ||to_char(x_code_assignment_id),1,255));
    dbms_output.put_line(substr('x_msg_count = ' || to_char(x_msg_count), 1, 255));
    dbms_output.put_line(substr('x_msg_data = ' || x_msg_data, 1, 255));

    IF x_msg_count > 1 THEN
      IF x_msg_count > 10 THEN
        x_msg_count := 10;
      END IF;
      FOR i IN 1 .. x_msg_count LOOP
        dbms_output.put_line(' Debug ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false), 1, 255));
      END LOOP;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(substr('Error ' || to_char(SQLCODE) || ': ' || SQLERRM,1,255));
      RAISE;
  END xxar_create_code_assignment;

  --------------------------------------------------------------------
  --  name:            check_tax_lines
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION check_tax_lines(p_cust_trx_id NUMBER) RETURN NUMBER AS
    v_num NUMBER;
  BEGIN
    -- Changed by Maoz 02/08/09
    SELECT COUNT(1)
      INTO v_num
      FROM (SELECT 1
              FROM ra_customer_trx_all rc,
                   (SELECT customer_trx_id
                      FROM (SELECT SUM(z.tax_rate) tax_rate,
                                   z.line_amt,
                                   z.trx_line_id,
                                   z.tax_type_code,
                                   z.trx_id customer_trx_id,
                                   SUM(z.tax_amt) tax_amt
                              FROM zx_lines z, ra_customer_trx_lines_all rcl
                             WHERE z.trx_line_id = rcl.customer_trx_line_id
                               AND z.trx_id = rcl.customer_trx_id
                            --and z.entity_code not in ('ADJUSTMENTS')
                             GROUP BY z.trx_line_id,
                                      z.line_amt,
                                      z.tax_type_code,
                                      z.trx_id)
                     GROUP BY tax_rate, tax_type_code, customer_trx_id) zx
             WHERE rc.customer_trx_id = zx.customer_trx_id
               AND rc.customer_trx_id = p_cust_trx_id);

    RETURN v_num;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END check_tax_lines;

  --------------------------------------------------------------------
  --  name:            get_currency_symbol
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_currency_symbol(p_currency VARCHAR2) RETURN VARCHAR2 AS
    v_symbol VARCHAR2(12);
    v_curr   VARCHAR2(5);
  BEGIN

    v_curr := p_currency;

    SELECT a.symbol
      INTO v_symbol
      FROM fnd_currencies a
     WHERE a.currency_code = v_curr;

    IF v_symbol IS NULL THEN
      RETURN v_curr;
    ELSE
      RETURN v_symbol;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN v_curr;
  END get_currency_symbol;

  --------------------------------------------------------------------
  --  name:            get_cont_phone
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_cont_phone(p_contact_id IN NUMBER) RETURN VARCHAR2 IS
    l_phone VARCHAR2(240) := NULL;
  BEGIN

    SELECT cont_point.phone_country_code ||
           decode(cont_point.phone_country_code, NULL, NULL, '-') ||
           cont_point.phone_area_code ||
           decode(cont_point.phone_area_code, NULL, NULL, '-') ||
           cont_point.phone_number contact_phone
      INTO l_phone
      FROM hz_contact_points cont_point, hz_cust_account_roles acct_role
     WHERE acct_role.cust_account_role_id = p_contact_id
       AND acct_role.party_id = cont_point.owner_table_id
       AND cont_point.owner_table_name = 'HZ_PARTIES'
       AND cont_point.primary_flag = 'Y'
       AND nvl(cont_point.phone_line_type, cont_point.contact_point_type) = 'GEN';

    RETURN l_phone;

  EXCEPTION
    WHEN no_data_found THEN
      SELECT cont_point.phone_country_code ||
             decode(cont_point.phone_country_code, NULL, NULL, '-') ||
             cont_point.phone_area_code ||
             decode(cont_point.phone_area_code, NULL, NULL, '-') ||
             cont_point.phone_number contact_phone
        INTO l_phone
        FROM hz_contact_points cont_point, hz_cust_account_roles acct_role
       WHERE acct_role.cust_account_role_id = p_contact_id
         AND acct_role.party_id = cont_point.owner_table_id
         AND cont_point.owner_table_name = 'HZ_PARTIES'
         AND nvl(cont_point.phone_line_type, cont_point.contact_point_type) = 'GEN'
         AND rownum = 1;

      RETURN l_phone;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_cont_phone;

  --------------------------------------------------------------------
  --  name:            get_cont_fax
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        Return contact fax
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_cont_fax(p_contact_id IN NUMBER) RETURN VARCHAR2 IS

    l_fax VARCHAR2(240) := NULL;
  BEGIN
    SELECT cont_point.phone_country_code ||
           decode(cont_point.phone_country_code, NULL, NULL, '-') ||
           cont_point.phone_area_code ||
           decode(cont_point.phone_area_code, NULL, NULL, '-') ||
           cont_point.phone_number contact_fax
      INTO l_fax
      FROM hz_contact_points cont_point, hz_cust_account_roles acct_role
     WHERE acct_role.cust_account_role_id = p_contact_id
       AND acct_role.party_id = cont_point.owner_table_id
       AND cont_point.owner_table_name = 'HZ_PARTIES'
       AND cont_point.primary_flag = 'Y'
       AND nvl(cont_point.phone_line_type, cont_point.contact_point_type) =  'FAX';

    RETURN l_fax;

  EXCEPTION
    WHEN no_data_found THEN
      SELECT cont_point.phone_country_code ||
             decode(cont_point.phone_country_code, NULL, NULL, '-') ||
             cont_point.phone_area_code ||
             decode(cont_point.phone_area_code, NULL, NULL, '-') ||
             cont_point.phone_number contact_phone
        INTO l_fax
        FROM hz_contact_points cont_point, hz_cust_account_roles acct_role
       WHERE acct_role.cust_account_role_id = p_contact_id
         AND acct_role.party_id = cont_point.owner_table_id
         AND cont_point.owner_table_name = 'HZ_PARTIES'
         AND nvl(cont_point.phone_line_type, cont_point.contact_point_type) = 'FAX'
         AND rownum = 1;

      RETURN l_fax;

    WHEN OTHERS THEN
      RETURN NULL;
  END get_cont_fax;

  --------------------------------------------------------------------
  --  name:            get_party_name
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        Return contact fax
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_party_name(p_site_use_id NUMBER) RETURN VARCHAR2 AS

    v_party_name VARCHAR2(150);

  BEGIN
    --  07-03-2013 Ofer Suad       Get ship to name from party insted of site
    BEGIN
      SELECT hp.party_name --nvl(hps.party_site_name, hp.party_name)
        INTO v_party_name
        FROM ar.hz_cust_site_uses_all t,
             hz_cust_acct_sites_all   hca,
             hz_party_sites           hps,
             hz_parties               hp
       WHERE t.cust_acct_site_id = hca.cust_acct_site_id
         AND hca.party_site_id = hps.party_site_id
         AND hps.party_id = hp.party_id
         AND t.site_use_id = p_site_use_id;

    EXCEPTION
      WHEN OTHERS THEN
        v_party_name := NULL;
    END;

    RETURN v_party_name;
  EXCEPTION
    WHEN OTHERS THEN
      v_party_name := NULL;
      RETURN v_party_name;
  END get_party_name;

  --------------------------------------------------------------------
  --  name:            get_item_cost
  --  create by:       daniel katz
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        for sales report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  daniel katz       initial build
  --------------------------------------------------------------------
  FUNCTION get_item_cost(p_organization_id NUMBER,
                         p_inventory_item  NUMBER,
                         p_date_as_of      DATE) RETURN NUMBER AS

    v_cost NUMBER;
  BEGIN
    BEGIN
      SELECT cost
        INTO v_cost
        FROM (SELECT ccc.new_cost cost
                FROM cst_cg_cost_history_v ccc
               WHERE ccc.inventory_item_id = p_inventory_item
                 AND ccc.organization_id = p_organization_id
                 AND ccc.change = 'Y'
                 AND trunc(ccc.transaction_date) <= p_date_as_of
               ORDER BY ccc.transaction_date DESC)
       WHERE rownum = 1;

    EXCEPTION
      WHEN OTHERS THEN
        BEGIN
          SELECT cost
            INTO v_cost
            FROM (SELECT ccc.new_cost cost
                    FROM cst_cg_cost_history_v ccc
                   WHERE ccc.inventory_item_id = p_inventory_item
                     AND ccc.organization_id = p_organization_id
                     AND ccc.change = 'Y'
                   ORDER BY ccc.transaction_date)
           WHERE rownum = 1;
        EXCEPTION
          WHEN OTHERS THEN
            v_cost := NULL;
            RETURN v_cost;
        END;
    END;

    RETURN v_cost;
  EXCEPTION
    WHEN OTHERS THEN
      v_cost := NULL;
      RETURN v_cost;
  END get_item_cost;

  --------------------------------------------------------------------
  --  name:            get_item_last_il_cost_ic_trx
  --  create by:       daniel katz
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        for ratam report
  --                   it finds the last cost of the item from internal shipping from IL
  --                   to the relevant Operating Unit before the date in the parameter.
  --                   if it doesn't find then it looks for the cost as of 31-aug-09.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  daniel katz       initial build
  --------------------------------------------------------------------
  FUNCTION get_item_last_il_cost_ic_trx(p_transfer_organization_id NUMBER,
                                        p_inventory_item           NUMBER,
                                        p_before_date              DATE) RETURN NUMBER AS

    v_cost NUMBER;

  BEGIN
    BEGIN
      SELECT cost
        INTO v_cost
        FROM (SELECT mmt.prior_cost cost
                FROM mtl_material_transactions   mmt,
                     hr_organization_information hoi,
                     hr_organization_information hoi_transfer
               WHERE mmt.transaction_source_type_id = 8 --internal
                 AND mmt.transaction_type_id = 62 --Int Order Intr Ship
                 AND mmt.transaction_action_id = 21 --Intransit shipment
                 AND hoi.organization_id = mmt.organization_id
                 AND hoi.org_information_context = 'Accounting Information'
                 AND hoi.org_information3 = '81' --IL Operating Unit
                 AND hoi_transfer.organization_id =
                     mmt.transfer_organization_id
                 AND hoi_transfer.org_information_context =
                     'Accounting Information'
                 AND hoi_transfer.org_information3 =
                     to_char(p_transfer_organization_id)
                 AND mmt.inventory_item_id = p_inventory_item
                 AND mmt.transaction_date <= p_before_date + 1
               ORDER BY mmt.transaction_date DESC)
       WHERE rownum = 1;

    EXCEPTION
      WHEN OTHERS THEN
        BEGIN
          SELECT AVG(xrqs.item_cost) cost
            INTO v_cost
            FROM xxobjt_ratam_qty_subs xrqs --table of RATAM Program.
           WHERE xrqs.item_id = p_inventory_item
             AND xrqs.org_id = '81' --IL OU
             AND xrqs.date_as_of = to_date('2009/08/31', 'YYYY/MM/DD');
        EXCEPTION
          WHEN OTHERS THEN
            v_cost := NULL;
            RETURN v_cost;
        END;
    END;

    RETURN v_cost;
  EXCEPTION
    WHEN OTHERS THEN
      v_cost := NULL;
      RETURN v_cost;
  END get_item_last_il_cost_ic_trx;

  --------------------------------------------------------------------
  --  name:            set_rev_reco_main_busin_type
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION set_rev_reco_main_busin_type RETURN NUMBER IS

    CURSOR c_busin_lines IS
      SELECT MIN(al.meaning) customer_main_business_type,
             hcodeass.owner_table_id
        FROM hz_code_assignments hcodeass, ar_lookups al
       WHERE hcodeass.class_category = al.lookup_type
         AND hcodeass.class_code = al.lookup_code
         AND hcodeass.class_category = 'Objet Business Type'
         AND hcodeass.status = 'A'
         AND hcodeass.start_date_active <= SYSDATE
         AND nvl(hcodeass.end_date_active, SYSDATE) >= SYSDATE
         AND hcodeass.owner_table_name = 'HZ_PARTIES'
       GROUP BY hcodeass.owner_table_id;
  BEGIN
    FOR i IN c_busin_lines LOOP
      busin_type(i.owner_table_id) := i.customer_main_business_type;
    END LOOP;
    RETURN 1;
  END set_rev_reco_main_busin_type;

  --------------------------------------------------------------------
  --  name:            set_rev_reco_cust_loc_parent
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION set_rev_reco_cust_loc_parent RETURN NUMBER IS
    CURSOR cust_loc_parent_lines IS
      SELECT MIN(ffv.description) dist_cust_location_parent,
             ffvc.flex_value
        FROM fnd_flex_value_children_v ffvc,
             fnd_flex_values_vl        ffv,
             fnd_flex_hierarchies      ffh
       WHERE ffvc.flex_value_set_id = 1013892
         AND ffvc.flex_value_set_id = ffh.flex_value_set_id
         AND ffh.flex_value_set_id = ffv.flex_value_set_id
         AND ffh.hierarchy_id = ffv.structured_hierarchy_level
         AND ffvc.parent_flex_value = ffv.flex_value
         AND ffh.hierarchy_code = 'ACCOUNTING'
       GROUP BY ffvc.flex_value;
  BEGIN
    FOR i IN cust_loc_parent_lines LOOP
      cust_loc_parent(i.flex_value) := i.dist_cust_location_parent;
    END LOOP;
    RETURN 1;
    RETURN 1;
  END set_rev_reco_cust_loc_parent;

  --------------------------------------------------------------------
  --  name:            get_rev_reco_main_busin_type
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_rev_reco_main_busin_type(p_party_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN busin_type(p_party_id);
  END get_rev_reco_main_busin_type;

  --------------------------------------------------------------------
  --  name:            get_rev_reco_cust_loc_parent
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXX  XXX               initial build
  --------------------------------------------------------------------
  FUNCTION get_rev_reco_cust_loc_parent(p_segment6 VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN cust_loc_parent(p_segment6);
  END get_rev_reco_cust_loc_parent;

  --------------------------------------------------------------------
  --  name:            get_print_inv_qty
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   01-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for printed invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01-mar-2012 Ofer Suad          initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_qty(p_sales_order_source      VARCHAR2,
                             p_contract_item_type_code VARCHAR2,
                             p_quantity                NUMBER,
                             p_oe_line_id              NUMBER) RETURN NUMBER IS
    l_dur NUMBER;
  BEGIN
    IF p_sales_order_source = 'ORDER ENTRY' AND
       p_contract_item_type_code = 'SERVICE' THEN

      SELECT service_duration
        INTO l_dur
        FROM oe_order_lines_all
       WHERE line_id = p_oe_line_id;
      IF l_dur IS NULL THEN
        RETURN p_quantity;
      ELSE
        RETURN l_dur;
      END IF;
    ELSE
      RETURN p_quantity;

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_quantity;
  END;

  --------------------------------------------------------------------
  --  name:            get_print_inv_uom
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   01-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for printed invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01-mar-2012 Ofer Suad          initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_uom(p_sales_order_source      VARCHAR2,
                             p_contract_item_type_code VARCHAR2,
                             p_quantity                NUMBER,
                             p_uom_code                VARCHAR2,
                             p_oe_line_id              NUMBER)
    RETURN VARCHAR2 IS
    l_uom mtl_units_of_measure.uom_code%TYPE;
  BEGIN
    IF p_sales_order_source = 'ORDER ENTRY' AND
       p_contract_item_type_code = 'SERVICE' THEN
      SELECT service_period
        INTO l_uom
        FROM oe_order_lines_all
       WHERE line_id = p_oe_line_id;
      IF l_uom IS NOT NULL THEN
        RETURN l_uom;
      ELSE
        IF p_quantity IS NULL THEN
          RETURN NULL;
        ELSE
          RETURN p_uom_code;
        END IF;
      END IF;
    ELSE

      IF p_quantity IS NULL THEN
        RETURN NULL;
      ELSE
        RETURN p_uom_code;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF p_quantity IS NULL THEN
        RETURN NULL;
      ELSE
        RETURN p_uom_code;
      END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get_print_inv_uom_tl
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   13/05/2013
  --------------------------------------------------------------------
  --  purpose :        cr 724 support japan description
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2013  Vitaly K.         initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_uom_tl(p_sales_order_source      VARCHAR2,
                                p_contract_item_type_code VARCHAR2,
                                p_quantity                NUMBER,
                                p_uom_code                VARCHAR2,
                                p_oe_line_id              NUMBER,
                                p_item_id                 NUMBER,
                                p_organization_id         NUMBER,
                                p_org_id                  NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_language   mtl_system_items_tl.language%TYPE;
    l_result_uom VARCHAR2(50); ----mtl_units_of_measure.uom_code%TYPE;
    l_uom_jpn    VARCHAR2(50);

  BEGIN

    ---Get UOM Code for Japan---------
    l_language := xxhz_util.get_ou_lang(nvl(p_org_id,
                                            xxhz_util.get_inv_org_ou(p_organization_id)));
    IF l_language = 'JA' THEN
      -----
      BEGIN
        SELECT t.description
          INTO l_uom_jpn
          FROM mtl_categories_v t, mtl_item_categories_v ic
         WHERE t.structure_name = 'SSYS Japan UOM sign'
           AND ic.category_id = t.category_id
           AND ic.inventory_item_id = p_item_id ---
           AND ic.organization_id = p_organization_id; ----
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      -----
    END IF;

    IF l_uom_jpn IS NULL THEN
      ---Get UOM Code by old logic------
      l_result_uom := get_print_inv_uom(p_sales_order_source,
                                        p_contract_item_type_code,
                                        p_quantity,
                                        p_uom_code,
                                        p_oe_line_id);

      IF l_language = 'JA' THEN
        ---Translate Japan----
        SELECT t.unit_of_measure_tl
          INTO l_result_uom
          FROM mtl_units_of_measure_tl t
         WHERE t.uom_code = l_result_uom ----
           AND t.language = 'JA';
      END IF;

    END IF;
    RETURN nvl(l_uom_jpn, l_result_uom);

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_print_inv_uom_tl;

  --------------------------------------------------------------------
  --  name:            get_exposure_amt
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   08-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for credit limit_report get customer exposure according to balance type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08-mar-2012 Ofer Suad         initial build
  --  1.1  02/08/2015  Dalit A. RAviv    add parameter org_id (CHG0035495, WF for credit check Hold on SO)
  --------------------------------------------------------------------
  FUNCTION get_exposure_amt(p_cust_account_id NUMBER,
                            p_balance_types   VARCHAR2,
                            p_base_cauurency  VARCHAR2,
                            p_org_id          number default null) RETURN NUMBER IS
    l_balance_amt NUMBER;
  BEGIN
    SELECT round(SUM(t.balance *
                     gl_currency_api.get_closest_rate(t.currency_code,
                                                      nvl(p_base_cauurency,
                                                          t.currency_code),
                                                      SYSDATE,
                                                      'Corporate',
                                                      10)))
      INTO l_balance_amt
      FROM ont.oe_credit_summaries t
     WHERE t.bucket_duration =
           (SELECT MAX(t1.bucket_duration)
              FROM oe_credit_summaries t1
             WHERE t1.cust_account_id = p_cust_account_id
               AND t1.balance_type = t.balance_type)
       AND t.cust_account_id = p_cust_account_id
       and (t.org_id = p_org_id or p_org_id is null) --  1.1  02/08/2015  Dalit A. RAviv
       AND instr(p_balance_types, t.balance_type) != 0;
    RETURN l_balance_amt;
  END;

  --------------------------------------------------------------------
  --  name:            get_usd_overdue_amount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/08/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   get customer credit profile - overdue amount in USD
  --                   function can get the overdue amt by ou
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/08/2015  Dalit A. RAviv    initial build
  --------------------------------------------------------------------
  function get_usd_overdue_amount (p_cust_account_id in number,
                                   p_org_id          in number) return number is
  l_usd_amount number := 0;
  begin
    select round(SUM(ps.amount_due_remaining *
                     gl_currency_api.get_closest_rate(ps.invoice_currency_code,
                                                      'USD',
                                                      SYSDATE,
                                                      'Corporate',
                                                      10)))
    into   l_usd_amount
    from   ar_payment_schedules_all ps
    where  ps.customer_id = p_cust_account_id--is not null
    and    (ps.org_id     = p_org_id or p_org_id is null)
    and    ps.due_date    < sysdate
    and    ps.class       <> 'PMT' -- Take only invoices (old payment not interest)
    group by ps.customer_id;

    return l_usd_amount;

  exception
    when others then
      return null;
  end get_usd_overdue_amount;

  --------------------------------------------------------------------
  --  name:            create_and_apply_receipt
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   25-jun-2012
  --------------------------------------------------------------------
  --  purpose :        for i store with CC payemnrts
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25-jun-2012 Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE create_and_apply_receipt(errbuf  OUT VARCHAR2,
                                     retcode OUT NUMBER) IS
    CURSOR c_cc_lines IS
      SELECT op.payment_amount,
             op.trxn_extension_id,
             op.header_id,
             trunc(op.creation_date) creation_date,
             op.receipt_method_id,
             oha.order_number
        FROM oe_payments op, oe_order_headers oha --, ra_customer_trx_all rta
       WHERE op.header_id = oha.header_id
         AND op.payment_type_code = 'CREDIT_CARD'
         AND EXISTS (SELECT 1
                FROM ra_customer_trx_all rta
               WHERE rta.interface_header_attribute1 =
                     to_char(oha.order_number))
         AND NOT EXISTS
       (SELECT 1
                FROM ar_cash_receipts_all rca
               WHERE rca.attribute1 = to_char(op.header_id));

    CURSOR c_invoices(p_sale_order_num VARCHAR2) IS
      SELECT SUM(rla.extended_amount) amount,
             rta.customer_trx_id,
             rta.trx_number,
             rta.invoice_currency_code,
             rta.bill_to_customer_id,
             rta.bill_to_site_use_id
        FROM ra_customer_trx_all rta, ra_customer_trx_lines_all rla
       WHERE p_sale_order_num = rta.interface_header_attribute1
         AND rta.customer_trx_id = rla.customer_trx_id
       GROUP BY rta.customer_trx_id,
                rta.trx_number,
                rta.invoice_currency_code,
                rta.bill_to_customer_id,
                rta.bill_to_site_use_id;

    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(240);
    ---l_count              NUMBER;
    l_cash_receipt_id NUMBER;
    ---l_msg_data_out       VARCHAR2(240);
    ---l_mesg               VARCHAR2(240);
    l_ledger_currency    VARCHAR2(15);
    l_exchange_rate_type VARCHAR2(25);
    l_exchange_rate_date DATE;
    l_inv_cnt            NUMBER;
    l_inv_tot_amount     NUMBER;
    l_msg_text           VARCHAR2(2000);
    ---TYPE err_order_numbers_type IS TABLE OF VARCHAR2(15) INDEX BY BINARY_INTEGER;
    TYPE err_txt_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;
    TYPE succsess_txt_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;
    -- l_err_ord_err    err_order_numbers_type;
    l_err_txt          err_txt_type;
    l_suc_txt          succsess_txt_type;
    l_err_count        NUMBER;
    l_suc_count        NUMBER;
    l_customer_id      NUMBER;
    l_currency_code    VARCHAR2(5);
    l_receipt_number   VARCHAR2(15);
    l_found            NUMBER;
    l_request_id       NUMBER;
    l_batch_id         NUMBER;
    l_batch_name       VARCHAR2(30);
    l_receipt_class_id NUMBER;

  BEGIN
    l_msg_text := xxobjt_wf_mail.get_header_html ||
                  '<p style="color:darkblue">Hello,</p><p style="color:darkblue">Receipts created for Credit Card payments </p>';
    l_msg_text := l_msg_text ||
                  '<table border="0" cellpadding="2" cellspacing="2" width="100%" style="color:darkblue">';
    SELECT gs.currency_code
      INTO l_ledger_currency
      FROM hr_operating_units hop, gl_sets_of_books gs
     WHERE hop.set_of_books_id = gs.set_of_books_id
       AND hop.organization_id = fnd_global.org_id;
    l_err_count := 0;
    l_suc_count := 0;
    l_found     := 0;
    FOR i IN c_cc_lines LOOP
      l_found := 1;
      SELECT SUM(aps.amount_due_remaining) amount,
             COUNT(DISTINCT rta.trx_number),
             rta.bill_to_customer_id,
             rta.invoice_currency_code
        INTO l_inv_tot_amount, l_inv_cnt, l_customer_id, l_currency_code
        FROM ra_customer_trx_all rta, ar_payment_schedules_all aps
       WHERE to_char(i.order_number) = rta.interface_header_attribute1
         AND rta.customer_trx_id = aps.customer_trx_id
       GROUP BY rta.bill_to_customer_id, rta.invoice_currency_code;

      IF l_inv_tot_amount != i.payment_amount THEN
        l_err_count := l_err_count + 1;
        -- l_err_ord_err(l_err_count) := i.order_number;
        l_err_txt(l_err_count) := 'Amount of order #' || i.order_number ||
                                  ' does not match invoice amount';
      ELSIF l_inv_cnt > 1 THEN
        ar_receipt_api_pub.create_cash(p_api_version      => 1.0,
                                       p_init_msg_list    => fnd_api.g_true,
                                       p_commit           => fnd_api.g_true,
                                       p_validation_level => fnd_api.g_valid_level_full,
                                       x_return_status    => l_return_status,
                                       x_msg_count        => l_msg_count,
                                       x_msg_data         => l_msg_data,
                                       p_currency_code    => l_currency_code,
                                       p_amount           => i.payment_amount,
                                       p_receipt_date     => i.creation_date,
                                       p_gl_date          => trunc(SYSDATE),
                                       --  p_payment_trxn_extension_id => i.trxn_extension_id,
                                       p_customer_id       => l_customer_id,
                                       p_receipt_method_id => fnd_profile.value('XXAR_CC_PAYMENT_METHOD'),
                                       p_cr_id             => l_cash_receipt_id);
        IF l_cash_receipt_id IS NULL THEN
          l_err_count := l_err_count + 1;
          -- l_err_ord_err(l_err_count) := i.order_number;
          l_err_txt(l_err_count) := 'Error in create cash for order #' ||
                                    i.order_number;
        ELSE
          /*select aca.receipt_number
           into l_receipt_number
           from ar_cash_receipts_all aca
          where aca.cash_receipt_id = l_cash_receipt_id;*/

          UPDATE ar_cash_receipts_all aca
             SET aca.attribute1 = i.header_id
           WHERE aca.cash_receipt_id = l_cash_receipt_id
          RETURNING aca.receipt_number INTO l_receipt_number;
        END IF;
        FOR j IN c_invoices(i.order_number) LOOP
          ar_receipt_api_pub.apply(p_api_version          => 1.0,
                                   p_init_msg_list        => fnd_api.g_true,
                                   p_commit               => fnd_api.g_true,
                                   p_validation_level     => fnd_api.g_valid_level_full,
                                   x_return_status        => l_return_status,
                                   x_msg_count            => l_msg_count,
                                   x_msg_data             => l_msg_data,
                                   p_cash_receipt_id      => l_cash_receipt_id,
                                   p_customer_trx_id      => j.customer_trx_id,
                                   p_amount_applied       => j.amount,
                                   p_show_closed_invoices => 'Y',
                                   p_apply_date           => trunc(SYSDATE),
                                   p_apply_gl_date        => trunc(SYSDATE),
                                   p_line_number          => 1);
          l_suc_count := l_suc_count + 1;
          l_suc_txt(l_suc_count) := 'Receipt # ' || l_receipt_number ||
                                    ' was applied to Invoice # ' ||
                                    j.trx_number;

        END LOOP;

      ELSE

        FOR j IN c_invoices(i.order_number) LOOP
          IF l_ledger_currency != j.invoice_currency_code THEN
            l_exchange_rate_type := fnd_profile.value('AR_DEFAULT_EXCHANGE_RATE_TYPE');
            l_exchange_rate_date := trunc(SYSDATE);
          ELSE
            l_exchange_rate_type := NULL;
            l_exchange_rate_date := NULL;
          END IF;

          ar_receipt_api_pub.create_and_apply(p_api_version          => 1.0,
                                              p_init_msg_list        => fnd_api.g_true,
                                              p_commit               => fnd_api.g_true,
                                              p_validation_level     => fnd_api.g_valid_level_full,
                                              x_return_status        => l_return_status,
                                              x_msg_count            => l_msg_count,
                                              x_msg_data             => l_msg_data,
                                              p_currency_code        => j.invoice_currency_code,
                                              p_exchange_rate_type   => l_exchange_rate_type,
                                              p_exchange_rate_date   => l_exchange_rate_date,
                                              p_amount               => j.amount,
                                              p_receipt_date         => i.creation_date,
                                              p_gl_date              => trunc(SYSDATE),
                                              p_customer_id          => j.bill_to_customer_id,
                                              p_customer_site_use_id => j.bill_to_site_use_id,
                                              p_receipt_number       => j.trx_number,
                                              p_receipt_method_id    => fnd_profile.value('XXAR_CC_PAYMENT_METHOD'),
                                              p_customer_trx_id      => j.customer_trx_id,
                                              -- p_payment_trxn_extension_id => i.trxn_extension_id,
                                              p_cr_id => l_cash_receipt_id);

          IF l_cash_receipt_id IS NULL THEN
            l_err_count := l_err_count + 1;
            -- l_err_ord_err(l_err_count) := i.order_number;
            l_err_txt(l_err_count) := 'Error in create and apply cash for order #' ||
                                      i.order_number;
            IF l_msg_count = 1 THEN
              l_msg_data := fnd_msg_pub.get(fnd_msg_pub.g_next,
                                            fnd_api.g_false);
              dbms_output.put_line('Message' || l_msg_data);

            END IF;
            IF l_msg_count > 1 THEN
              LOOP
                l_msg_data := fnd_msg_pub.get(fnd_msg_pub.g_next,
                                              fnd_api.g_false);
                IF l_msg_data IS NULL THEN
                  EXIT;
                END IF;
                dbms_output.put_line('Message' || l_msg_data);
              END LOOP;
            END IF;

          ELSE
            /*select aca.receipt_number
             into l_receipt_number
             from ar_cash_receipts_all aca
            where aca.cash_receipt_id = l_cash_receipt_id;*/
            UPDATE ar_cash_receipts_all aca
               SET aca.attribute1 = i.header_id
             WHERE aca.cash_receipt_id = l_cash_receipt_id
            RETURNING aca.receipt_number INTO l_receipt_number;
            l_suc_count := l_suc_count + 1;
            l_suc_txt(l_suc_count) := 'Receipt #' || l_receipt_number ||
                                      ' was applied to Invoice #' ||
                                      j.trx_number;

          END IF;
        END LOOP;
      END IF;
    END LOOP;
    FOR i IN 1 .. l_err_count LOOP
      l_msg_text := l_msg_text || '<tr><td>' || l_err_txt(i) ||
                    '</td></tr>';
      fnd_file.put_line(fnd_file.log, l_err_txt(i));
    END LOOP;

    FOR i IN 1 .. l_suc_count LOOP
      l_msg_text := l_msg_text || '<tr><td>' || l_suc_txt(i) ||
                    '</td></tr>';
      fnd_file.put_line(fnd_file.log, l_suc_txt(i));
    END LOOP;

    IF l_found > 0 THEN
      --      select ar_batches_s.nextval into l_batch_id from dual;
      SELECT arm.receipt_class_id
        INTO l_receipt_class_id
        FROM ar_receipt_methods arm
       WHERE arm.receipt_method_id =
             fnd_profile.value('XXAR_CC_PAYMENT_METHOD');

      ar_autorem_api.insert_batch(p_batch_date                 => trunc(SYSDATE),
                                  p_batch_gl_date              => trunc(SYSDATE),
                                  p_currency_code              => l_ledger_currency,
                                  p_remmitance_method          => 'STANDARD',
                                  p_receipt_class_id           => l_receipt_class_id,
                                  p_payment_method_id          => fnd_profile.value('XXAR_CC_PAYMENT_METHOD'),
                                  p_remmitance_bank_branch_id  => fnd_profile.value('XXAR_CC_BANK_BRANCH_ID'), --6050
                                  p_remmitance_bank_account_id => fnd_profile.value('XXAR_CC_BANK_ACCOUNT_ID'), --
                                  p_batch_id                   => l_batch_id);

      l_request_id := fnd_request.submit_request('AR',
                                                 'AUTOREMAPI', --PAYMENT_UPTAKE ARZCAR_REMIT
                                                 NULL,
                                                 -- 'Create Automatic remittance receipt Batch',
                                                 to_char(SYSDATE,
                                                         'DD-MON-YYYY'),
                                                 FALSE,
                                                 'REMIT',
                                                 NULL, -- Batch Date
                                                 NULL, -- Batch GL Date
                                                 'Y',
                                                 'Y',
                                                 'Y',
                                                 l_batch_id,
                                                 'N',
                                                 NULL, -- Batch Currency
                                                 NULL, -- Exchange Date
                                                 NULL, -- Exchange Rate
                                                 NULL, -- Exchange Rate Type
                                                 NULL, -- Remit Method Code
                                                 NULL, -- Receipt Class
                                                 NULL, --fnd_profile.VALUE('XXAR_CC_PAYMENT_METHOD'), -- Payment Method
                                                 NULL, -- Media Reference
                                                 NULL, -- Remit Bank Branch
                                                 NULL, -- Remit Bank Account
                                                 NULL, -- Bank Deposit Number
                                                 NULL, -- Batch Comments
                                                 NULL, --fnd_date.date_to_canonical(p_receipt_date_low),
                                                 NULL, --  fnd_date.date_to_canonical(sysdate),
                                                 NULL, --fnd_date.date_to_canonical(p_due_date_low),
                                                 fnd_date.date_to_canonical(trunc(SYSDATE)),
                                                 NULL, -- p_receipt_number_low,
                                                 NULL, -- p_receipt_number_high,
                                                 NULL, --p_document_number_low,
                                                 NULL, -- p_document_number_high,
                                                 NULL, -- p_customer_number_low,
                                                 NULL, --p_customer_number_high,
                                                 NULL, --p_customer_name_low,
                                                 NULL, -- p_customer_name_high,
                                                 NULL, -- p_customer_id,
                                                 NULL, --p_location_low,
                                                 NULL, --p_location_high,
                                                 NULL, -- p_site_use_id,
                                                 NULL, --fnd_number.number_to_canonical(p_remit_total_low),
                                                 NULL, --fnd_number.number_to_canonical(p_remit_total_high),
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL);
      IF l_request_id <> 0 THEN
        SELECT ab.name
          INTO l_batch_name
          FROM ar_batches_all ab
         WHERE ab.batch_id = l_batch_id;
        l_msg_text := l_msg_text || '<tr><td>Remittance Batch ' ||
                      l_batch_name || ' was created. </td></tr>';
      ELSE
        l_msg_text := l_msg_text ||
                      '<tr><td>Error while create Remittance Batch </td></tr>';
      END IF;
      l_msg_text := l_msg_text || '</table>' ||
                    xxobjt_wf_mail.get_footer_html;

      xxobjt_wf_mail.send_mail_html(p_to_role     => fnd_profile.value('XX_AR_CC_RECIEPT_MAIL_RECEIVER'),
                                    p_cc_mail     => fnd_profile.value('XX_AR_CC_RECIEPT_CC_MAIL_RECEIVER'),
                                    p_subject     => 'eStore Credit Card Receipts',
                                    p_body_html   => l_msg_text,
                                    p_err_code    => retcode,
                                    p_err_message => errbuf);
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get_term_name_tl
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   25.4.2013
  --------------------------------------------------------------------
  --  purpose :        cr 724 support japan description
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25.4.2013   yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION get_term_name_tl(p_term_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 IS

    l_name VARCHAR2(500);
  BEGIN

    SELECT decode(xxhz_util.get_ou_lang(p_org_id),
                  'JA',
                  t.description,
                  t.name)
      INTO l_name
      FROM ra_terms_tl t

     WHERE t.term_id = p_term_id
       AND t.language = xxhz_util.get_ou_lang(p_org_id);
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            is_account_dist
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   25.4.2013
  --------------------------------------------------------------------
  --  purpose :        CR 970 - inital
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25.4.2013   yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION is_account_dist(p_cust_account_id NUMBER)

   RETURN VARCHAR2 IS
    l_flag VARCHAR2(1);
  BEGIN

    SELECT 'Y'
      INTO l_flag
      FROM hz_parties hz, hz_cust_accounts hca
     WHERE hz.party_id = hca.party_id
       AND hca.cust_account_id = p_cust_account_id
       AND hz.category_code = 'DISTRIBUTOR';

    RETURN l_flag;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';

  END;

  --------------------------------------------------------------------
  --  name:            get_customer_open_balance
  --  create by:       vitaly K.
  --  Revision:        1.0
  --  creation date:   21.8.2013
  --------------------------------------------------------------------
  --  purpose :        CR983  - inital
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21.8.2013   vitaly K          initial build
  --------------------------------------------------------------------
  FUNCTION get_customer_open_balance(p_cust_account_id NUMBER,
                                     p_currency_code   VARCHAR2)
    RETURN NUMBER IS
    v_customer_open_balance NUMBER;
  BEGIN

    IF p_cust_account_id IS NULL THEN
      RETURN NULL;
    END IF;

    SELECT nvl(round(SUM(t.balance *
                         gl_currency_api.get_closest_rate(t.currency_code,
                                                          nvl(p_currency_code, ---parameter
                                                              t.currency_code),
                                                          SYSDATE,
                                                          'Corporate',
                                                          10))),
               0) customer_open_balance
      INTO v_customer_open_balance
      FROM ont.oe_credit_summaries t

     WHERE t.bucket_duration =
           (SELECT MAX(t1.bucket_duration)
              FROM oe_credit_summaries t1
             WHERE t1.cust_account_id = p_cust_account_id -- parameter
               AND t1.balance_type = t.balance_type)
       AND t.cust_account_id = p_cust_account_id;         -- parameter

    RETURN v_customer_open_balance;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_customer_open_balance;

  --------------------------------------------------------------------
  --  name:            get_customer_credit_limit_amt
  --  create by:       vitaly K.
  --  Revision:        1.0
  --  creation date:   21.8.2013
  --------------------------------------------------------------------
  --  purpose :        CR983  - inital
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21.8.2013   vitaly K          initial build
  --------------------------------------------------------------------
  FUNCTION get_customer_credit_limit_amt(p_cust_account_id NUMBER,
                                         p_currency_code   VARCHAR2)
    RETURN NUMBER IS
    v_customer_credit_limit_amnt NUMBER;
  BEGIN

    IF p_cust_account_id IS NULL OR p_currency_code IS NULL THEN
      RETURN NULL;
    END IF;

    SELECT t.overall_credit_limit
      INTO v_customer_credit_limit_amnt
      FROM ar.hz_cust_profile_amts t
     WHERE t.cust_account_id = p_cust_account_id ---parameter
       AND t.currency_code = p_currency_code ---parameter
       AND t.site_use_id IS NULL;

    RETURN v_customer_credit_limit_amnt;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_customer_credit_limit_amt;

  --------------------------------------------------------------------
  --  name:            get_company_WEEE_num
  --  create by:       Sandeep Akula
  --  Revision:        1.0
  --  creation date:   04-AUG-2015
  --------------------------------------------------------------------
  --  purpose :        Derives WEEE Number from Legal Entity Registration DFF
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04-AUG-2015 Sandeep Akula     initial build - CHG0035932
  --------------------------------------------------------------------
  FUNCTION get_company_WEEE_num(p_legal_entity_id IN NUMBER,
                                p_org_id IN NUMBER)
  RETURN VARCHAR2 AS

    l_weee_num VARCHAR2(150);

  BEGIN

    BEGIN
      SELECT reg.attribute2
        INTO l_weee_num
        FROM xle_entity_profiles lep7,
             xle_registrations   reg,
             hr_operating_units  opu
       WHERE lep7.transacting_entity_flag = 'Y'
         AND lep7.legal_entity_id = reg.source_id
         AND lep7.legal_entity_id = opu.default_legal_context_id
         AND opu.organization_id = p_org_id
         AND reg.source_table = 'XLE_ENTITY_PROFILES'
         AND reg.identifying_flag = 'Y'
         AND lep7.legal_entity_id = p_legal_entity_id;

    EXCEPTION
      WHEN OTHERS THEN
        l_weee_num := NULL;
    END;

    RETURN l_weee_num;

  EXCEPTION
    WHEN OTHERS THEN
      l_weee_num := NULL;
      RETURN l_weee_num;
  END get_company_WEEE_num;

  --------------------------------------------------------------------
  --  name:            get_location_territory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29-Sep-2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495
  --                   return the territory of customer/site/site_use
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29-Sep-2015 Dalit A. Raviv    initial build
  --  1.1  18-Oct-2015 Dalit A. Raviv    INC0049601 - correct select logic to return one record
  --------------------------------------------------------------------
  function get_location_territory (p_site_id     in number,
                                   p_site_use_id in number,
                                   p_customer_id in number) return varchar2 is

  l_territory varchar2(150);
  begin
    select ffv.description
    into   l_territory
    from   hz_parties                hp,
           hz_party_sites            hps,
           hz_party_site_uses        hpsu,
           hz_cust_accounts          hca,
           hz_cust_acct_sites_all    hcas,
           hz_cust_site_uses_all     hcsu,
           gl_code_combinations      gcb,
           fnd_flex_value_sets       ffvs,
           fnd_flex_values_vl        ffv
    where  hp.party_id               = hps.party_id
    and    hp.party_id               = hca.party_id
    and    hps.party_site_id         = hcas.party_site_id
    and    hcsu.cust_acct_site_id    = hcas.cust_acct_site_id
    and    hps.party_site_id         = hpsu.party_site_id
    and    hcsu.site_use_code        = hpsu.site_use_type
    and    hcsu.site_use_code        = 'BILL_TO'
    and    hcsu.status               = 'A'
    and    hcas.party_site_id        = nvl(p_site_id, hcas.party_site_id)
    and    hcsu.site_use_id          = nvl(p_site_use_id, hcsu.site_use_id)    -- invoice_to_org_id
    and    hca.cust_account_id       = nvl(p_customer_id, hca.cust_account_id) -- customer_id
    and    gcb.code_combination_id   = hcsu.gl_id_rev
    and    ffv.flex_value            = gcb.segment6
    and    ffvs.flex_value_set_name  = 'XXGL_LOCATION_SEG'
    and    ffvs.flex_value_set_id    = ffv.flex_value_set_id;
    
    return l_territory;
  exception
    when TOO_MANY_ROWS then
      select ffv.description
      into   l_territory
      from   hz_parties                hp,
             hz_party_sites            hps,
             hz_party_site_uses        hpsu,
             hz_cust_accounts          hca,
             hz_cust_acct_sites_all    hcas,
             hz_cust_site_uses_all     hcsu,
             gl_code_combinations      gcb,
             fnd_flex_value_sets       ffvs,
             fnd_flex_values_vl        ffv
      where  hp.party_id               = hps.party_id
      and    hp.party_id               = hca.party_id
      and    hps.party_site_id         = hcas.party_site_id
      and    hcsu.cust_acct_site_id    = hcas.cust_acct_site_id
      and    hps.party_site_id         = hpsu.party_site_id
      and    hcsu.site_use_code        = hpsu.site_use_type
      and    hcsu.site_use_code        = 'BILL_TO'
      and    hcsu.status               = 'A'
      and    hcas.party_site_id        = nvl(p_site_id, hcas.party_site_id)
      and    hcsu.site_use_id          = nvl(p_site_use_id, hcsu.site_use_id)    -- invoice_to_org_id
      and    hca.cust_account_id       = nvl(p_customer_id, hca.cust_account_id) -- customer_id
      and    gcb.code_combination_id   = hcsu.gl_id_rev
      and    ffv.flex_value            = gcb.segment6
      and    ffvs.flex_value_set_name  = 'XXGL_LOCATION_SEG'
      and    ffvs.flex_value_set_id    = ffv.flex_value_set_id
      and    rownum = 1;
    when others then
      return null;
  end get_location_territory;

END xxar_utils_pkg;
/
