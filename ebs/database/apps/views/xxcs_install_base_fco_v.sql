CREATE OR REPLACE VIEW XXCS_INSTALL_BASE_FCO_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE_FCO_V
--  create by:       Roman Vaintraub
--  Revision:        1.0
--  creation date:   08/11/2010
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/09/2009  Roman            initial build
--  1.1  08/11/2011  Dalit A. Raviv   Add CS_region_group field
--  1.2  31/12/2012  Adi Safin        Add support for 3 FCO changes in one SR
--                                    Add value set id for improvement
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
       fco.incident_number,
       fco.attribute_code fco,
       fco.attribute_value fco_date,
       region_gr.CS_Region_group
from
       xxcs_install_base_bi_v                       ib,
       (select ciab.incident_number,
               ciab.customer_product_id             instance_id,
               cii.serial_number,
               cie1.attribute_code                  attribute_code,
               cie1.attribute_id                    attribute_id,
               to_char(ciab.close_date,'dd-mon-yyyy') attribute_value
          from cs_incidents_all_b        ciab,
               cs_incident_statuses_b    cisb,
               cs_incident_statuses_tl   cist,
               csi_item_instances        cii,
               csi_i_extended_attribs    cie1,
               fnd_flex_values           flv
         where ciab.incident_status_id   = cisb.incident_status_id
           and cisb.close_flag           = 'Y'
           and cisb.incident_status_id   = cist.incident_status_id
           and cist.language             = 'US'
           and cist.name                 != 'Cancelled'
           and ciab.customer_product_id  = cii.instance_id
           -- 1.2 Adi Safin  31.12.2012
           and (ciab.external_attribute_5 = flv.flex_value OR  ciab.external_attribute_12 = flv.flex_value OR  ciab.external_attribute_13 = flv.flex_value)
           AND flv.flex_value_set_id      = (SELECT ffvs.flex_value_set_id
                                             FROM fnd_flex_value_sets ffvs
                                             WHERE ffvs.flex_value_set_name = 'XXCS_FCO_TYPE'
                                            )
          -- End 1.2 Adi Safin 31.12.2012
           and flv.attribute1            = to_char(cie1.attribute_id)
           and                           exists (select 1
                                                 from   csi_iea_values civ, csi_i_extended_attribs cie
                                                 where  civ.attribute_id = cie.attribute_id
                                                 and    cie.attribute_code = cie1.attribute_code)) fco,
       xxcs_regions_v    region_gr
where  IB.instance_id     = FCO.instance_id
and    ib.owner_cs_region = region_gr.CS_Region(+);
