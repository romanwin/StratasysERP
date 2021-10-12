CREATE OR REPLACE VIEW XXCS_HASP_UPGRADE_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_HASP_UPGRADE_V
--  create by:
--  Revision:
--  creation date:
----------------------------------------------------------------------------------------------------------------
--  purpose :        Hasp Interface
----------------------------------------------------------------------------------------------------------------
--  ver  date        name              desc
--  ---  ----------- ----------------- -------------------------------------------------------------------------
--  1.X  1.12.13     Yuval Tal         CR1163-Service - Customization support new operating unit
--  1.1  23-Nov-2014 Adi Safin         Change view to support new SFDC Install base
--  1.2  19/6/2014   Moshe Lavi        CHG0032163
--  1.3  15/07/2015  Michal Tzvik      CHG0035439 - run only on V2C upgrades
--  1.4  11/04/2016  Adi Safin         Instead of delivery last update date use order line actual shipment date.
--  1.5  23/12/2019  Adi Safin         INC0178665 improve performance
--                   Roman W
--                   Yuval T.
--  1.6  30/06/2020  Roman W.          CHG0048021 - PZ Move to MY SSYS
--                                              owner.party_number -> csb.account_number
--  1.7  05/01/2021  Adi Safin         CHG0049205 - Add Case in order to get the correct last update date in case the SN added after actual shipping date, also add an option to push SN via IB table.
----------------------------------------------------------------------------------------------------------------
 'Upgrade' SOURCE_TYPE, --Moshe Lavi CHG0032163 19/6/2014
 ORG,
 OWNER,
-- owner_party_number, -- rem by Roman W. 03/04/2020 CHG0048021
 owner_account_number, -- added by Roman W. 03/04/2020 CHG0048021
 EDU,
 SEGMENT1,
 order_number,
 line_id,
 header_id,
 DESCRIPTION,
 CS_REGION,
 CUR_DATE,
 SERIAL_NUMBER,
 old_printer,
 old_printer_description,
 HASP,
 key_pn,
 DONGLE_SN DONGLE_SN,
 NVL2(DONGLE_SN, NULL, 'U/G requires dongle shipment!') DONGLE_SHIP,
 CMP,
 USER_NAME,
 TIMESTAMP,
 MSC,
 LAST_UPDATE_DATE
  FROM (SELECT DISTINCT oola.line_id,
                        oola.header_id,
                        --WDD.LAST_UPDATE_DATE,
                        CASE  -- CHG0049205
                          WHEN cii.attribute18 IS NOT NULL AND oola.actual_shipment_date IS NOT NULL THEN
                               to_date(cii.attribute18,'yyyy-mm-dd hh24:mi:ss')
                          WHEN oola.attribute15 IS NOT NULL AND oola.attribute1 IS NOT NULL AND oola.LAST_UPDATE_DATE > oola.actual_shipment_date THEN
                               oola.LAST_UPDATE_DATE
                          ELSE 
                              oola.actual_shipment_date
                        END LAST_UPDATE_DATE, -- end CHG0049205
                        DECODE(OOHA.ORG_ID,
                               81,
                               'IL',
                               96,
                               'DE',
                               89,
                               'US',
                               737,
                               'US',
                               103,
                               'HK',
                               161,
                               'CN',
                               683,
                               'JP',
                               914,
                               'KR'
                               ) ORG,
                        OWNER.PARTY_NAME OWNER,
                        -- owner.party_number owner_party_number, -- rem by Roman W. 03/06/2020 CHG0048021
                        csb.account_number owner_account_number, -- added by Roman W. 03/06/2020 CHG0048021
                        EDU.PARTY_NAME EDU,
                        UI.upgrade_item segment1,
                        UI.upgrade_item_description description,
                        sf_cii.ATTRIBUTE8 CS_REGION,
                        TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') CUR_DATE,
                        TO_CHAR(OOHA.ORDER_NUMBER) ORDER_NUMBER,
                        CII.SERIAL_NUMBER,
                        MSIB1.SEGMENT1 old_printer,
                        MSIB1.DESCRIPTION old_printer_description,
                        NVL((SELECT MSIB.SEGMENT1 || '  ( ' || MSIB.DESCRIPTION || ' )'
                              FROM xxinv_bom_explode_history t,
                                   MTL_SYSTEM_ITEMS_B        MSIB
                             WHERE ROWNUM=1
                               and t.top_assembly_item_id =
                                   OOLA.INVENTORY_ITEM_ID
                               and t.comp_part_number like 'KEY%'
                               AND MSIB.INVENTORY_ITEM_ID = t.comp_item_id
                               AND MSIB.ORGANIZATION_ID = 91
                               and sysdate between
                                   nvl(t.effective_date, sysdate) and nvl(t.disable_date, sysdate)
                                      ),
                            (SELECT MSIB.SEGMENT1 || '  ( ' || MSIB.DESCRIPTION || ' )'
                               FROM xxinv_bom_explode_history t,
                                    MTL_SYSTEM_ITEMS_B        MSIB
                              WHERE ROWNUM=1
                                and t.top_assembly_item_id = OOLA.INVENTORY_ITEM_ID
                                AND t.comp_part_number like 'CMP%'
                                AND MSIB.DESCRIPTION LIKE 'HASP%'
                                AND MSIB.ORGANIZATION_ID = 91
                                AND MSIB.INVENTORY_ITEM_ID = t.comp_item_id
                                and sysdate between nvl(t.effective_date, sysdate) and nvl(t.disable_date, sysdate))) HASP,
                        NVL((SELECT MSIB.SEGMENT1
                              FROM xxinv_bom_explode_history t,
                                   MTL_SYSTEM_ITEMS_B        MSIB
                             WHERE ROWNUM=1
                               and t.top_assembly_item_id = OOLA.INVENTORY_ITEM_ID
                               and t.comp_part_number like 'KEY%'
                               AND MSIB.INVENTORY_ITEM_ID = t.comp_item_id
                               AND MSIB.ORGANIZATION_ID = 91
                               and sysdate between nvl(t.effective_date, sysdate) and nvl(t.disable_date, sysdate)
                              ),

                            (SELECT MSIB.SEGMENT1
                               FROM xxinv_bom_explode_history t,
                                    MTL_SYSTEM_ITEMS_B        MSIB
                              WHERE ROWNUM=1
                                AND t.top_assembly_item_id = OOLA.INVENTORY_ITEM_ID
                                AND t.comp_part_number like 'CMP%'
                                AND MSIB.DESCRIPTION LIKE 'HASP%'
                                AND MSIB.ORGANIZATION_ID = 91
                                AND MSIB.INVENTORY_ITEM_ID = t.comp_item_id
                                and sysdate between nvl(t.effective_date, sysdate) and nvl(t.disable_date, sysdate))) key_pn,

                          (SELECT CHLD.SERIAL_NUMBER
                           FROM csi_item_instances Chld,
                                csi_ii_relationships cir,
                                MTL_SYSTEM_ITEMS_B      MSIB
                          WHERE ROWNUM =1
                            AND MSIB.INVENTORY_ITEM_ID = Chld.INVENTORY_ITEM_ID
                            AND MSIB.ORGANIZATION_ID = 91
                            AND cir.relationship_type_code = 'COMPONENT-OF'
                            AND MSIB.SEGMENT1 LIKE 'CMP%'
                            AND MSIB.DESCRIPTION LIKE 'HASP%'
                            and Chld.instance_id = cir.subject_id
                            AND cir.object_id = CII.INSTANCE_ID
                            AND SYSDATE BETWEEN nvl(cir.active_start_date, SYSDATE) AND  nvl(cir.active_end_date, SYSDATE)
                            AND Chld.SERIAL_NUMBER IS NOT NULL) DONGLE_SN, --  1.1  23-Nov-2014 Adi Safin

                        (SELECT MSIB.SEGMENT1 || '  ( ' ||  MSIB.DESCRIPTION || ' )'
                           FROM BOM_INVENTORY_COMPONENTS_V BIC,
                                BOM_BILL_OF_MATERIALS_V    BBO,
                                MTL_SYSTEM_ITEMS_B         MSIB
                          WHERE ROWNUM=1
                            AND BBO.BILL_SEQUENCE_ID = BIC.BILL_SEQUENCE_ID
                            AND MSIB.INVENTORY_ITEM_ID = BBO.ASSEMBLY_ITEM_ID
                            AND MSIB.ORGANIZATION_ID = 91
                            AND MSIB.SEGMENT1 LIKE 'CMP%'
                            AND NVL(BIC.DISABLE_DATE,SYSDATE+1) > sysdate
                            AND BIC.COMPONENT_ITEM_ID IN
                                (SELECT t.comp_item_id
                                   FROM xxinv_bom_explode_history t
                                  WHERE t.comp_part_number like 'KEY%'
                                    AND oola.INVENTORY_ITEM_ID = t.top_assembly_item_id
                                    and sysdate between nvl(t.effective_date, sysdate ) and nvl(t.disable_date, sysdate))) CMP,

                        FU.USER_NAME,

                        TO_CHAR(SYSDATE, 'mm/dd/yyyy hh24:mi:ss') TIMESTAMP,

                        (SELECT UV.SERIAL_NUMBER
                           FROM OE_ORDER_LINES_ALL          OL,
                                WSH_DELIVERY_DETAILS        WD,
                                MTL_UNIT_TRANSACTIONS_ALL_V UV,
                                OE_ORDER_HEADERS_ALL        OOHA1
                          WHERE ROWNUM=1
                            AND OL.INVENTORY_ITEM_ID = 386001
                            AND OOHA1.HEADER_ID = OOHA.HEADER_ID
                            AND OL.HEADER_ID = OOHA1.HEADER_ID
                            AND OL.LINE_ID = WD.SOURCE_LINE_ID
                            AND nvl(ol.attribute1, cii.instance_number) =
                                cii.instance_number
                            AND OL.FLOW_STATUS_CODE != 'CANCELLED'
                            AND WD.RELEASED_STATUS = 'C'
                            AND WD.TRANSACTION_ID = UV.TRANSACTION_ID) MSC

          FROM OE_ORDER_LINES_ALL      OOLA,
               OE_ORDER_HEADERS_ALL    OOHA,
               CSI_ITEM_INSTANCES      CII, --  1.1  23-Nov-2014 Adi Safin: replace CSI_ITEM_INSTANCES
               xxsf_csi_item_instances_sub_v SF_CII, --new arival
               xxcs_sales_ug_items_v   UI,
               mtl_system_items_b      msib1,
               HZ_PARTIES              OWNER,
               HZ_PARTIES              EDU,
               hz_cust_accounts        csb, --  1.1  23-Nov-2014 Adi Safin: replace CSI_SYSTEMS_B
               WSH_DELIVERY_DETAILS    WDD,
               FND_USER                FU
         WHERE OOHA.HEADER_ID = OOLA.HEADER_ID
           AND cii.inventory_item_id = msib1.inventory_item_id --
           and cii.inventory_item_id = UI.before_upgrade_item--
           and msib1.organization_id = 91
           AND OOLA.ATTRIBUTE1 = CII.INSTANCE_number--
           AND OOLA.CREATED_BY = FU.USER_ID
           AND OOLA.INVENTORY_ITEM_ID = ui.upgrade_item_id
           AND CII.OWNER_PARTY_ID = OWNER.PARTY_ID--
           and sf_cii.instance_id = CII.INSTANCE_ID
           AND sf_cii.owner_account_number   = csb.account_number(+) --  1.1  23-Nov-2014 Adi Safin
           AND CSB.PARTY_ID = EDU.PARTY_ID(+) --  1.1  23-Nov-2014 Adi Safin
           AND OOLA.LINE_ID = WDD.SOURCE_LINE_ID
           AND OOLA.FLOW_STATUS_CODE != 'CANCELLED'
           AND WDD.RELEASED_STATUS = 'C'
           AND ( (ui.upgrade_trigger = 'V2C' ) or ( ui.upgrade_trigger IS NULL ) ) -- 1.3  15/07/2015  Michal Tzvik
        ) SUB;
/		
