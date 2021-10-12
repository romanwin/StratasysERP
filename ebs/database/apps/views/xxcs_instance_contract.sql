CREATE OR REPLACE VIEW XXCS_INSTANCE_CONTRACT AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_CONTRACT
--  create by:       Yoram Zamir
--  Revision:        2.2
--  creation date:   03/09/2009
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  03/09/2009  Yoram Zamir      initial build
--  2.0  09/05/2010  Yoram Zamir      Revised version
--  2.1  24/03/2011  Roman            Added signed contracts
--  2.2  27/07/2011  Roman            Chnaged the function to ROW_NUMBER to bring only 1 row
--  2.3  7/07/2014   Adi Safin        get all contracts sold via SO that not related to Contract module
--------------------------------------------------------------------
 CONT_TAB.CONTRACT_LINE_ID,
 CONT_TAB.CONTRACT_SERVICE,
 CONT_TAB.CONTRACT_TYPE,
 CONT_TAB.CONTRACT_COVERAGE,
 CONT_TAB.CONTRACT_INSTANCE_ID,
 CONT_TAB.CONTRACT_INSTANCE_ITEM,
 CONT_TAB.CONTRACT_INSTANCE_ITEM_DESC,
 CONT_TAB.CONTRACT_ITEM_REVISION,
 CONT_TAB.CONTRACT_NUMBER,
 CONT_TAB.CONTRACT_VERSION_NUMBER,
 CONT_TAB.CONTRACT_STATUS,
 CONT_TAB.CONTRACT_START_DATE,
 CONT_TAB.CONTRACT_END_DATE,
 CONT_TAB.CONTRACT_LINE_STATUS,
 CONT_TAB.CONTRACT_LINE_START_DATE,
 CONT_TAB.CONTRACT_LINE_END_DATE
  FROM (SELECT TO_CHAR(CONT.CONTRACT_LINE_ID) CONTRACT_LINE_ID,
               CONT.CONTRACT_SERVICE,
               CONT.CONTRACT_TYPE,
               CONT.CONTRACT_COVERAGE,
               CONT.CONTRACT_INSTANCE_ID,
               CONT.CONTRACT_INSTANCE_ITEM,
               CONT.CONTRACT_INSTANCE_ITEM_DESC,
               CONT.CONTRACT_ITEM_REVISION,
               CONT.CONTRACT_NUMBER,
               CONT.CONTRACT_VERSION_NUMBER,
               CONT.CONTRACT_STATUS,
               CONT.CONTRACT_START_DATE,
               CONT.CONTRACT_END_DATE,
               CONT.CONTRACT_LINE_STATUS,
               CONT.CONTRACT_LINE_START_DATE,
               CONT.CONTRACT_LINE_END_DATE,
               ROW_NUMBER() OVER(PARTITION BY CONT.CONTRACT_INSTANCE_ID
                                 ORDER BY DECODE(CONT.CONTRACT_LINE_STATUS, 'SIGNED', 1,2),
                                 CONT.CONTRACT_LINE_END_DATE DESC, TO_CHAR(CONT.CONTRACT_LINE_END_DATE)
                                 ) CONTRACT_END_DATE_DESC_RANK
          FROM XXCS_INSTANCE_CONTRACT_ALL CONT
         WHERE CONT.CONTRACT_LINE_STATUS IN ('ACTIVE','SIGNED')
         AND cont.date_terminated IS NULL) CONT_TAB
 WHERE CONT_TAB.CONTRACT_END_DATE_DESC_RANK = 1
 UNION
 --  2.3  7/07/2014   Adi Safin 
 SELECT  TO_CHAR(sc.line_id),
        'SERVICE',
        sc.description SC_Part_Description,
        sc.ordered_item SC_Part_number,
        sc.instance_id,        
        sc.printer_PN,
        sc.printer_desc,
        '',
        'SO'||sc.order_number,
        NULL,
        'NOT RELVANT',        
        SC.min_maint_start_date,
        SC.max_maint_end_date,
        CASE 
          WHEN SC.min_maint_start_date > SYSDATE THEN
            'SIGNED'
          WHEN   SYSDATE BETWEEN SC.min_maint_start_date AND SC.max_maint_end_date THEN
            'ACTIVE'
          WHEN   SYSDATE > SC.max_maint_end_date  THEN
            'EXPIRED'
        END CONTRACT_LINE_STATUS,
        sc.min_maint_start_date,
        SC.max_maint_end_date
FROM (SELECT  oola.line_id,
       ooha.org_id,
       ooha.order_number,
       oola.ordered_item,
       ooha.invoice_to_org_id,
       msi_cont.description,
       oola.attribute14 machine_sn,
       cii.instance_id,
       msi_mac.segment1 printer_PN,
       msi_mac.description printer_desc,
       fnd_date.canonical_to_date(oola.attribute12) maint_start_date,
       fnd_date.canonical_to_date(oola.attribute13) maint_end_date,       
       MIN(fnd_date.canonical_to_date(oola.attribute12)) over(PARTITION BY ooha.org_id, ooha.order_number,oola.ordered_item, oola.attribute14 ) AS min_maint_start_date,
       MAX(fnd_date.canonical_to_date(oola.attribute13)) over(PARTITION BY ooha.org_id, ooha.order_number,oola.ordered_item, oola.attribute14 ) AS max_maint_end_date 
 FROM oe_order_headers_all ooha,
      oe_order_lines_all   oola,
      mtl_system_items_b   msi_cont,
      csi_item_instances cii,
      mtl_system_items_b   msi_mac
WHERE ooha.header_id = oola.header_id
   AND msi_cont.organization_id = 91
   AND msi_cont.inventory_item_id = oola.inventory_item_id
   AND msi_mac.organization_id = 91
   AND msi_mac.inventory_item_id = cii.inventory_item_id
   AND cii.serial_number = oola.attribute14
   AND oola.attribute14 IS NOT NULL
   AND oola.ordered_quantity > 0 
   AND oola.flow_status_code = 'CLOSED'  
   AND xxar_autoinvoice_pkg.is_service_item(oola.inventory_item_id) = 1
   ) sc
  WHERE sc.maint_start_date = sc.min_maint_start_date
  -- End  2.3  7/07/2014   Adi Safin 
