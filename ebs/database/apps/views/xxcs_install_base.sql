CREATE OR REPLACE VIEW XXCS_INSTALL_BASE AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE
--  create by:       Vitaly.K
--  Revision:        1.2
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :    Disco Report:  XX: Service Calls With Charges And Notes
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  01/09/2009  Vitaly            initial build
--  1.1  07/03/2010  Yoram Zamir       outer join with ooha
--  1.2  03/05/2010  Yoram Zamir       New field "Installed date"
--  1.3  13/03/2013  Adi Safin         Add instance_type_code column
--------------------------------------------------------------------
       cii.instance_number,
       cii.instance_id BI_instance_id,
       cis.name Status,
       cii.serial_number,
       civ.PARTY_NAME Customer_Name,
       civ.ADDRESS4 PIVOTAL_SITE_NUMBER,
       civ.COUNTRY,
       civ.STATE,
       civ.CITY,
       civ.ADDRESS1,
       civ.POSTAL_CODE,
       ooha.order_number Created_By_SO_Number,
       ooha.attribute8 SO_Control_Number,
       cii.sales_unit_price,
       cii.inventory_item_id BI_Inventory_item_id,
       s.name     end_customer,
       cii.install_date,
       flv.meaning  instance_type_code-- 1.3 Adi Safin

FROM   csi_inst_install_location_v civ,
       csi_item_instances          cii,
       CSI_INSTANCE_STATUSES       cis,
       CSI_SYSTEMS_VL              S,
       fnd_lookup_values           flv, -- 1.3 Adi Safin
       (SELECT ol.line_id, oh.order_number,oh.attribute8
        FROM oe_order_lines_all          ol,
            oe_order_headers_all        oh
        WHERE  ol.header_id = oh.header_id(+)
                                 ) ooha

WHERE  cii.instance_id = civ.INSTANCE_ID (+)
   and cii.instance_status_id = cis.instance_status_id (+)
   and cii.last_oe_order_line_id = ooha.line_id(+)
   and cii.system_id = s.system_id (+)
   -- Start 1.3 Adi Safin
   AND nvl(cii.instance_type_code,'XXCS_STANDARD') = flv.lookup_code
   and flv.language         ='US'
   and flv.lookup_type      ='CSI_INST_TYPE_CODE' ;-- End 1.3 Adi Safin
   
