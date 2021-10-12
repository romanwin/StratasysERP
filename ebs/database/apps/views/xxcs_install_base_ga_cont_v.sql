CREATE OR REPLACE VIEW xxcs_install_base_ga_cont_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE_GA_CONT_V
--  create by:       Adi Safin
--  Revision:        1.0
--  creation date:   24/10/2012
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  24/10/2012  Adi              initial build
--------------------------------------------------------------------
       ib.instance_id,
       ib.internal,
       ib.cs_region,
       ib.customer,
       ib.owner_market_classification,
       ib.end_market_classification,
       ib.instance_usage_code,
       ib.end_customer,
       ib.owner_customer_number,
       ib.end_customer_number,
       ib.serial_number,
       ib.printer,
       ib.printer_description,
       ib.item_for_parameter,
       ib.counter_reading,
       ib.counter_reading_date,
       ib.coi,
       ib.coi_date,
       ib.embedded_sw_version,
       ib.objet_studio_sw_version,
       ib.ship_date,
       ib.install_date,
       ib.account_number,
       ib.sales_channel_code,
       ib.category_code,
       ib.country,
       ib.state,
       ib.postal_code,
       ib.city,
       ib.address1,
       ib.address2,
       ib.address3,
       ib.address4,
       ib.ib_status,
       ib.item_instance_type,
       ib.item_category,
       ib.enabled_flag,
       ib.ib_contacts,
       ib.operating_unit_party,
       ib.instance_contract_type,
       ib.contract_service,
       ib.contract_coverage,
       ib.contract_type,
       ib. contract_number,
       ib.contract_status,
       ib.contract_start_date,
       ib.contract_end_date,
       ib.contract_line_status,
       ib.contract_line_start_date,
       ib.contract_line_end_date,
       ib.warranty_service,
       ib.warranty_coverage,
       ib.warranty_number,
       ib.warranty_status,
       ib.warranty_start_date,
       ib.warranty_end_date,
       ib.warranty_line_status,
       ib.warranty_line_start_date,
       ib.warranty_line_end_date,
       ib.related_distributor,
       ib.ga,
       ib.associated_distributor,
       con.person_first_name,
       con.person_last_name,
       con.job_title,
       con.creation_date,
       con.phone_country_code,
       con.phone_area_code,
       con.phone_number,
       con.phone_extension,
       con.mobile_country_code,
       con.mobile_area_code,
       con.mobile_number,
       con.mobile_extension,
       con.fax_country_code,
       con.fax_area_code,
       con.fax_number,
       con.fax_extension,
       con.email_address,
       con.party_relationship_status,
       con.account_contact_status,
       con.WW_Global_Main_Contact,
       con.Site_Main_Contact,
       con.GAM_Contact,
       region_gr.CS_Region_group,
       xxhz_party_ga_util.is_party_ga (hca.party_id) Gla,
       (select nvl(hp_par.party_name,' ')
       from   hz_relationships         tt, 
              hz_parties               hp_par,
              hz_parties               hp_sub       
       where  tt.object_table_name     = 'HZ_PARTIES'
       and    tt.subject_id            = hp_sub.party_id
       AND    hp_sub.party_id          = hca.party_id
       and    tt.object_id             = hp_par.party_id
       and    tt.status                = 'A'
       and    sysdate                  between tt.start_date and nvl(tt.end_date, sysdate + 1)
       and    tt.relationship_type     = 'XX_OBJ_GLOBAL'
       AND    tt.relationship_code     = 'GLOBAL_SUBSIDIARY_OF'
       AND    nvl(hp_sub.attribute5,'N') = 'N' 
       AND    ROWNUM = 1
       UNION
       SELECT hp.party_name 
       FROM   hz_parties hp
       WHERE  hp.party_id      = hca.party_id
       AND    hp.attribute5 = 'Y' -- Global Account
       AND    ROWNUM = 1
       ) Global_parent      
  from xxcs_install_base_rep_v ib,
       xxcs_contacts_all_v     con,
       xxcs_regions_v          region_gr,
       hz_cust_accounts        hca      
 where ib.end_customer_number  = con.party_number (+)
   and ib.item_category        in ('WATER-JET', 'PRINTER')
   and ib.customer             <> 'Objet Internal Install Base'
   and ib.cs_region            = region_gr.CS_Region(+)
   
   AND xxhz_party_ga_util.is_party_ga (hca.party_id) = 'Y'
   AND ib.account_number = hca.account_number

