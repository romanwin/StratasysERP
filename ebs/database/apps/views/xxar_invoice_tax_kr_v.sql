CREATE OR REPLACE VIEW XXAR_INVOICE_TAX_KR_V AS
SELECT
---------------------------------------------------------------------------------
--  Purpose :        Korean Tax Invoice interface
--                   Functional & Design Specification Num:  CHG0032318

----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0    9.8.10    YUVAL TAL            initial build
-----------------------------------------------------------------------
   tab."ORG_ID",tab."CREATION_DATE",tab."TRX_DATE",tab."TRX_DATE_DISP",tab."TRX_NUMBER",tab."CONSTANT1",tab."CONSTANT2",tab."CONSTANT3",tab."SERIAL_NUMBER",tab."SUPPLIER_VAT_REG_NUMBER",tab."SUPPLIER_COMPANY_NAME",tab."LE_INFORMATION1",tab."SUPPLIER_ADDRESS",tab."ACTIVITY_CODE",tab."SUB_ACTIVITY_CODE",tab."CUSTOMER_CLASSIFICATION_CODE",tab."CUSTOMER_VAT_REG_NUMBER",tab."CUSTOMER_COMPANY_NAME",tab."CUSTOMER_REPRESENTATIVE_NAME",tab."CUSTOMER_ADDRESS",tab."CUSTOMER_TYPE_INDUSTRY",tab."CUSTOMER_TYPE_OF_BUSINESS",tab."CUSTOMER_NAME_IN_CHARGE",tab."CUSTOMER_PHONE_NUMBER",tab."CUSTOMER_MAIL",tab."AMOUNT_INCLUDES_TAX_FLAG",tab."TOTAL_SUPPLY_VALUE",tab."TOTAL_VAT_AMOUNT",tab."SERIAL_NUMBER_OF_PRODUCT",tab."TRANSACTION_DATE",tab."ITEM_NAME",tab."UOM_CODE",tab."QUANTITY",tab."UNIT_PRICE",tab."SUPPLY_VALUE",tab."VAT_AMOUNT",tab."REMARK",
       nvl(total_supply_value, 0) + nvl(total_vat_amount, 0) total_amount
  FROM (SELECT
  T.ORG_ID,T.CREATION_DATE CREATION_DATE,
               t.trx_date,
               to_char(t.trx_date,'YYYYMMDD') TRX_DATE_DISP  ,
               trx_number,
               1 constant1,
               1 constant2,
               2 constant3,
               trx_number serial_number,
               xxar_utils_pkg.get_company_reg_number(t.legal_entity_id,
                                                     t.org_id) supplier_vat_reg_number,
               (SELECT lep.attribute2
                  FROM xle_entity_profiles lep, hr_operating_units opu
                 WHERE lep.transacting_entity_flag = 'Y'
                   AND lep.legal_entity_id = opu.default_legal_context_id
                   AND opu.organization_id = t.org_id
                   AND lep.legal_entity_id = t.legal_entity_id) supplier_company_name,
               ep.le_information1,
               (    SELECT  hrl.address_line_1 || ' ' || hrl.address_line_2 || ' ' || hrl.town_or_city
       FROM xle_entity_profiles lep6,
            xle_registrations   reg,
            hr_locations_all    hrl

      WHERE lep6.transacting_entity_flag = 'Y'
        AND lep6.legal_entity_id = reg.source_id
              AND reg.source_table = 'XLE_ENTITY_PROFILES'
        AND hrl.location_id = reg.location_id
        AND reg.identifying_flag = 'Y'
       AND lep6.legal_entity_id = ep.legal_entity_id) supplier_address,
               replace(ep.activity_code,',','-') activity_code,
               replace(ep.sub_activity_code,',','-') sub_activity_code ,
               1 customer_classification_code,
               bill_party.jgzz_fiscal_code customer_vat_reg_number,
               bill_party.organization_name_phonetic customer_company_name,
               replace (acc_site.global_attribute1,',',' ') customer_representative_name,
               replace(raa_bill_loc.address1 || ' ' || raa_bill_loc.address2 || ' ' ||
               raa_bill_loc.city,',', ' ') customer_address,
               replace(xxobjt_general_utils_pkg.get_lookup_meaning('JAKR_AR_VAT_IND_CLASS', acc_site.global_attribute8),',','-') customer_type_industry,
               replace(acc_site.global_attribute3,',','-') customer_type_of_business,
               --

               replace((SELECT hov.person_first_name || ' ' || hov.person_last_name
                  FROM ra_customer_trx_all   rta,
                       hz_cust_accounts      htc,
                       hz_relationships      rl,
                       hz_org_contacts_v     hov,
                       hz_cust_account_roles hcar
                 WHERE rta.customer_trx_id = t.customer_trx_id
                   AND htc.cust_account_id = rta.bill_to_customer_id
                   AND rl.subject_id = htc.party_id
                   AND hov.party_relationship_id = rl.relationship_id
                   AND hov.job_title = 'TAX INV'
                   AND nvl(hov.status, 'A') = 'A'
                   AND hov.contact_point_type = 'PHONE'
                   AND hov.contact_primary_flag = 'Y'
                   AND hcar.party_id = rl.party_id
                   AND nvl(hcar.current_role_state, 'A') = 'A'
                   AND hcar.cust_account_id = htc.cust_account_id
                   AND rownum = 1),',','-') customer_name_in_charge,

               (SELECT hov.phone_number
                  FROM ra_customer_trx_all   rta,
                       hz_cust_accounts      htc,
                       hz_relationships      rl,
                       hz_org_contacts_v     hov,
                       hz_cust_account_roles hcar
                 WHERE rta.customer_trx_id = t.customer_trx_id
                   AND htc.cust_account_id = rta.bill_to_customer_id
                   AND rl.subject_id = htc.party_id
                   AND hov.party_relationship_id = rl.relationship_id
                   AND hov.job_title = 'TAX INV'
                   AND nvl(hov.status, 'A') = 'A'
                   AND hov.contact_point_type = 'PHONE'
                   AND hov.phone_line_type = 'GEN'
                   AND hov.contact_primary_flag = 'Y'
                   AND hcar.party_id = rl.party_id
                   AND nvl(hcar.current_role_state, 'A') = 'A'
                   AND hcar.cust_account_id = htc.cust_account_id
                   AND rownum = 1) customer_phone_number,

               (SELECT hov.email_address
                  FROM ra_customer_trx_all   rta,
                       hz_cust_accounts      htc,
                       hz_relationships      rl,
                       hz_org_contacts_v     hov,
                       hz_cust_account_roles hcar
                 WHERE rta.customer_trx_id = t.customer_trx_id
                   AND htc.cust_account_id = rta.bill_to_customer_id
                   AND rl.subject_id = htc.party_id
                   AND hov.party_relationship_id = rl.relationship_id
                   AND hov.job_title = 'TAX INV'
                   AND nvl(hov.status, 'A') = 'A'
                   AND hov.contact_point_type = 'EMAIL'
                   AND hov.contact_primary_flag = 'Y'
                   AND hcar.party_id = rl.party_id
                   AND nvl(hcar.current_role_state, 'A') = 'A'
                   AND hcar.cust_account_id = htc.cust_account_id
                   AND rownum = 1) customer_mail,
               --
               trx_lines.amount_includes_tax_flag,
               --
               (SELECT SUM(extended_amount)
                  FROM ra_customer_trx_lines_all l
                 WHERE l.customer_trx_id = t.customer_trx_id
                 and    l.line_type='LINE') total_supply_value,
               (SELECT SUM(a.tax_amt)
                  FROM zx_lines a
                 WHERE application_id = '222'
                   AND entity_code = 'TRANSACTIONS'
                   AND a.trx_id = t.customer_trx_id
                   and a.trx_level_type='LINE'
                   ) total_vat_amount,

               row_number() over(PARTITION BY t.customer_trx_id ORDER BY trx_lines.customer_trx_line_id) AS serial_number_of_product,

               to_char(t.trx_date, 'YYYYMMDD') transaction_date,
               replace (decode (inventory_item_id, null,null,xxinv_utils_pkg.get_item_segment(trx_lines.inventory_item_id,
                                                91) || '; ' ||
               xxinv_utils_pkg.get_item_desc_tl(trx_lines.inventory_item_id,
                                                91)),',',' ') item_name,
               trx_lines.uom_code,
               nvl(trx_lines.quantity_credited, trx_lines.quantity_invoiced) quantity,
               trx_lines.unit_selling_price unit_price,
               trx_lines.extended_amount supply_value,
               (SELECT a.tax_amt
                  FROM zx_lines a
                 WHERE application_id = '222'
                   AND entity_code = 'TRANSACTIONS'
                   AND a.trx_id = t.customer_trx_id
                   AND a.trx_line_id = trx_lines.customer_trx_line_id
                ) vat_amount,
               replace (decode( bs.batch_source_type,'INV',trx_lines.description,null),',','-') remark
          FROM ra_customer_trx_all       t,
               xle_entity_profiles       ep,
               hz_cust_accounts          bill_cust,
               hz_parties                bill_party,
               hz_cust_acct_sites_all    acc_site,
               hz_cust_site_uses_all     su_bill,
               hz_party_sites            raa_bill_ps,
               hz_locations              raa_bill_loc,
               ra_customer_trx_lines_all trx_lines,
               ra_batch_sources_all bs

         WHERE ep.legal_entity_id = t.legal_entity_id
           AND t.bill_to_customer_id = bill_cust.cust_account_id
           AND bill_cust.party_id = bill_party.party_id
           AND t.bill_to_site_use_id = su_bill.site_use_id
           AND acc_site.cust_account_id = bill_cust.cust_account_id
           AND su_bill.cust_acct_site_id = acc_site.cust_acct_site_id
           AND raa_bill_ps.party_site_id = acc_site.party_site_id
           AND raa_bill_loc.location_id = raa_bill_ps.location_id
           AND trx_lines.customer_trx_id = t.customer_trx_id
           and trx_lines.line_type='LINE'
           and bs.batch_source_id=t.batch_source_id
           and t.GLOBAL_ATTRIBUTE1 is null

           AND t.org_id = 914
           AND T.COMPLETE_FLAG='Y'
                    ) tab;
