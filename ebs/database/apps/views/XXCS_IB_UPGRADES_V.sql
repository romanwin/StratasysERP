CREATE OR REPLACE VIEW XXCS_IB_UPGRADES_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_IB_UPGRADES_V
--  create by:       Roman Vaintraub
--  Revision:        1.3
--  creation date:   18/07/2011
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  18/07/2011  Roman            initial build
--  1.1  19/07/2011  Roman            Added Contracts and Warranties data
--  1.2  24/07/2011  Roman            Changed Creation_date to Transaction_date as v2c download date
--  1.3  22/11/2011  Roman            Added ug_contract_warranty  during the Upgrade
--  1.4  02/05/2012  Adi Safin        Changed the shipment query - add join condition to upgrade lookup instead inventory category.prevent duplications
--                                    Changed the V2C Download date - instead of an instance(the instance only fill after the lines was processed and ended in success, get it from serial.
--  1.5  06/12/2012  Adi Safin        Bug fix - prevent upgrade duplication by adding the inventory order line to the where clause
--  1.6  13/01/2013  Adi Safin        Add Item_instance_type cloumn
--------------------------------------------------------------------
       HP.PARTY_NAME CUSTOMER,
       HP1.PARTY_NAME END_CUSTOMER,
       OUP.NAME OPERATING_UNIT,
       CIV.INSTANCE_ID,
       CII.SERIAL_NUMBER,
       CIE.ATTRIBUTE_NAME IB_UPGRADE_NAME,
       CIV.ATTRIBUTE_VALUE ESTIMATE_UPGRADE_DATE,
       MSIB.SEGMENT1 SYSTEM_PART_NUMBER,
       MSIB.DESCRIPTION SYSTEM_DESCRIPTION,
       MSIB1.SEGMENT1 UPGRADE_PART_NUMBER,
       MSIB1.DESCRIPTION UPGRADE_DESCRIPTION,
       flv2.meaning      Item_instance_type, --  1.6  13/01/2013  Adi Safin
       --  1.4  02/05/2012  Adi
         (SELECT pz.PZ_DATE
          FROM (SELECT PZ.SYSTEM_SN, MIN(PZ.TRANSACTION_DATE) PZ_DATE
                  FROM XXCS_PZ2OA_INTF PZ
                GROUP BY PZ.SYSTEM_SN)pz
         WHERE PZ.SYSTEM_SN = CII.SERIAL_NUMBER) V2C_DOWNLOAD_DATE,
       -- end
       SHIPMENT.ORDER_NUMBER,
       SHIPMENT.LAST_UPDATE_DATE shipment_date,
       ic.CONTRACT_TYPE,
       ic.CONTRACT_NUMBER,
       ic.CONTRACT_LINE_STATUS  CONTRACT_STATUS,
       ic.CONTRACT_LINE_START_DATE,
       ic.CONTRACT_LINE_END_DATE,
       iw.WARRANTY_LINE_STATUS WARRANTY_STATUS,
       iw.WARRANTY_NUMBER,
       iw.WARRANTY_LINE_START_DATE,
       iw.WARRANTY_LINE_END_DATE,
       nvl((select cc.type
          from XXCS_INST_CONTR_AND_WARR_ALL_V cc
         where CIV.ATTRIBUTE_VALUE between cc.line_start_date and cc.line_end_date
         and cc.instance_id = cii.instance_id
         and rownum < 2),'T&M') ug_contract_warranty
  FROM CSI_IEA_VALUES         CIV,
       CSI_I_EXTENDED_ATTRIBS CIE,
       FND_LOOKUP_VALUES      FLV,
       FND_LOOKUP_VALUES      FLV2,--  1.6  13/01/2013  Adi Safin
       CSI_ITEM_INSTANCES     CII,
       MTL_SYSTEM_ITEMS_B     MSIB,
       MTL_SYSTEM_ITEMS_B     MSIB1,
       hr_operating_units     OUP,
       HZ_PARTIES             HP,
       CSI_SYSTEMS_B          CSB,
       HZ_PARTIES             HP1,
       xxcs_instance_contract IC,
       xxcs_instance_warranty IW,
       --  1.4  02/05/2012  Adi
       (SELECT DISTINCT WDD.LAST_UPDATE_DATE, ooha.order_number, oola.attribute1,oola.inventory_item_id
        FROM OE_ORDER_LINES_ALL   OOLA,
             oe_order_headers_all ooha,
             WSH_DELIVERY_DETAILS WDD,
             fnd_lookup_values    flv,
             mtl_system_items_b   msib
      WHERE OOLA.LINE_ID = WDD.SOURCE_LINE_ID
         AND ooha.header_id = oola.header_id
         AND OOLA.FLOW_STATUS_CODE != 'CANCELLED'
         AND WDD.RELEASED_STATUS = 'C'
         AND WDD.SOURCE_CODE = 'OE'
         and flv.language = 'US'
         and flv.lookup_type = 'XXCSI_UPGRADE_TYPE'
         and msib.organization_id = 91
         and oola.inventory_item_id = msib.inventory_item_id
         and msib.segment1 = flv.description) SHIPMENT
       /*(SELECT WDD.LAST_UPDATE_DATE, ooha.order_number, oola.attribute1
          FROM OE_ORDER_LINES_ALL   OOLA,
               oe_order_headers_all ooha,
               WSH_DELIVERY_DETAILS WDD,
               MTL_ITEM_CATEGORIES  MIC
         WHERE OOLA.LINE_ID = WDD.SOURCE_LINE_ID
           AND ooha.header_id = oola.header_id
           AND OOLA.FLOW_STATUS_CODE != 'CANCELLED'
           AND WDD.RELEASED_STATUS = 'C'
           AND OOLA.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
           AND MIC.ORGANIZATION_ID = 91
           AND MIC.CATEGORY_ID = 36123
           AND WDD.SOURCE_CODE = 'OE') SHIPMENT*/
      -- end 1.4  02/05/2012
 WHERE CIE.ATTRIBUTE_ID = CIV.ATTRIBUTE_ID
   AND to_char(cii.instance_id) = SHIPMENT.ATTRIBUTE1 (+)
   AND FLV.LOOKUP_CODE = CIE.ATTRIBUTE_CODE
   AND cii.instance_id = ic.CONTRACT_INSTANCE_ID (+)
   AND cii.instance_id = iw.WARRANTY_INSTANCE_ID (+)
   AND FLV.LANGUAGE = 'US'
   AND FLV.ATTRIBUTE1 IS NOT NULL
   AND CII.INSTANCE_ID = CIV.INSTANCE_ID
   AND FLV.LOOKUP_TYPE = 'CSI_EXTEND_ATTRIB_POOL'
   -- Start 1.6 Adi Safin
   AND nvl(cii.instance_type_code,'XXCS_STANDARD') = flv2.lookup_code
   and flv2.language         ='US'
   and flv2.lookup_type      ='CSI_INST_TYPE_CODE'
   -- End 1.6 Adi Safin
   AND MSIB.ORGANIZATION_ID = 91
   AND MSIB.INVENTORY_ITEM_ID = CII.INVENTORY_ITEM_ID
   AND CIV.ATTRIBUTE_VALUE IS NOT NULL
   AND MSIB1.INVENTORY_ITEM_ID = FLV.ATTRIBUTE1
   AND msib1.inventory_item_id = shipment.inventory_item_id -- 1.5 Adi Safin
   AND MSIB1.ORGANIZATION_ID = 91
   AND HP.PARTY_ID = CII.OWNER_PARTY_ID
   AND HP1.PARTY_ID (+) = CSB.ATTRIBUTE2
   AND CSB.SYSTEM_ID (+) = CII.SYSTEM_ID
   AND to_number(hp.attribute3) = oup.organization_id;
