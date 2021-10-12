CREATE OR REPLACE VIEW XXCS_INSTALL_BASE_MIS_FCO_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE_MIS_FCO_V
--  create by:       Adi Safin
--  Revision:        1.0
--  creation date:   21/11/2012
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  21/11/2012  Adi Safin        initial build
--  1.1  09/07/2013  Adi Safin        Bugfix - Remove inactive FCO's from the report
--------------------------------------------------------------------
       ib.operating_unit_party,
       ib.owner_cs_region                          cs_region,
       ib.instance_id                              instance_id,
       ib.internal                                 internal,
       ib.owner_name                               customer,
       ib.end_customer                             end_customer,
       ib.serial_number                            serial_number,
       ib.item                                     printer,
       ib.item_description                         printer_description,
       ib.item || '   -   ' || ib.item_description item_for_parameter,
       ib.last_update_date                         last_update_date,
       ib.counter_reading                          counter_reading,
       ib.counter_reading_date                     counter_reading_date,
       ib.coi                                      coi,
       ib.coi_date                                 coi_date,
       ib.embedded_sw_version                      embedded_sw_version,
       ib.objet_studio_sw_version                  objet_studio_sw_version,
       ib.optimax_upgrade_date                     optimax_upgrade_date,
       ib.tempo_upgrade_date                       tempo_upgrade_date,
       nvl(ib.ship_date, ib.initial_ship_date)     ship_date,
       trunc(ib.install_date)                      install_date,
       ib.sales_channel_code                       sales_channel_code,
       ib.category_code                            category_code,
       ib.country                                  country,
       ib.state                                    state,
       ib.postal_code                              postal_code,
       ib.city                                     city,
       ib.address1                                 address1,
       ib.address2                                 address2,
       ib.address3                                 address3,
       ib.address4                                 address4,
       ib.ib_status                                ib_status,
       ib.item_instance_type                       item_instance_type,
       fco.attribute_name                          fco_missed,
       region_gr.CS_Region_group
from
       xxcs_install_base_bi_v                       ib,
        (select cii.instance_id,cii.serial_number ,cii.attribute8,mic.SEGMENT3,cie1.attribute_name
        from   csi_item_instances cii ,
               CSI_I_EXTENDED_ATTRIBS cie1,
               MTL_ITEM_CATEGORIES_v mic
        WHERE cii.inventory_item_id = mic.inventory_item_id
        AND   mic.category_set_id = 1100000041
        AND   mic.category_id = cie1.item_category_id
        AND   cie1.attribute_level    = 'CATEGORY'
        AND   cie1.attribute_code LIKE  'OBJ_FCO%'
        AND   cii.accounting_class_code = 'CUST_PROD'
        AND   nvl(cie1.active_end_date,SYSDATE +1/24) > SYSDATE --  1.1  09/07/2013  Adi Safin
        --AND   cii.se
        AND   nvl(cii.active_end_date,SYSDATE +1/24) > SYSDATE
        AND   mic.ORGANIZATION_ID = 91
        AND   cii.instance_id NOT IN (select civ.instance_id
                                      from   csi_iea_values         civ,
                                             csi_i_extended_attribs cie
                                      where  civ.attribute_id       = cie.attribute_id
                                       AND   cie.attribute_level    = 'CATEGORY'
                                       AND   cie.attribute_code LIKE  'OBJ_FCO%'
                                       and   cie.attribute_code     = cie1.attribute_code)) fco,
       xxcs_regions_v    region_gr
where  IB.instance_id     = FCO.instance_id
and    ib.owner_cs_region = region_gr.CS_Region(+);
