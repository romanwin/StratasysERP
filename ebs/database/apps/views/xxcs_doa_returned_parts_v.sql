CREATE OR REPLACE VIEW xxcs_doa_returned_parts_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_DOA_RETURNED_PARTS_V
--  create by:       Yoram Zamir
--  Revision:        1.3
--  creation date:   03/01/2010
--------------------------------------------------------------------
--  purpose :      Discoverer Report "DOA Report"
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  03/01/2010  Yoram            initial build
--  1.1  10/01/2010  Yoram            Add region field
--  1.2  07/03/2010  Vitaly --        Region is NULL in first select.Source for Region was changed to cs_incidents_all_b.external_attribute_1 (the second select)
--  1.3  08/03/2010  Vitaly           Operating_Unit_Party and Sales_Channel were added , Region=NULL
--  1.4  08/06/2010  Vitaly           Security by OU was added;    org_id field was added
--  1.5  14/05/2012  Adi S.           Add SR type.
--------------------------------------------------------------------
       --Orders
       'Sales Order'                                    "SOURCE",
       to_char(oh.order_number)                          ORDER_SR_NUMBER,
       oh.header_id                                      ORDER_SR_ID,
       oh.ordered_date                                   SO_SR_DATE,
       oh.flow_status_code                               SO_SR_STATUS,
       '      '                                          SO_SR_TYPE,
       ol.line_number ||'.'|| ol.shipment_number         SO_LINE_TASK_NUMBER,
       ol.flow_status_code                               SO_DEBRIF_LINE_STATUS,
       ol.creation_date                                  SO_DEBRIEF_LINE_DATE,
       ol.inventory_item_id                              INVENTORY_ITEM_ID,
       ol.ordered_item                                   ITEM,
       msib.description                                  ITEM_DESCRIPTION,
       ol.ordered_quantity                               QUANTITY,
       ol.order_quantity_uom                             UOM,
       hp1.party_name                                    CUSTOMER,
       -----hp1.attribute1                                    REGION
       ''                                                REGION,
       oup.name                                          OPERATING_UNIT_PARTY,
       to_number(hp1.attribute3)                         ORG_ID,
       hca.sales_channel_code
FROM   oe_order_headers_all            oh,
       oe_order_lines_all              ol,
       mtl_system_items_b              msib,
       hz_cust_accounts                hca,
       hz_parties                      hp1,
       hr_operating_units              oup
WHERE oh.header_id = ol.header_id                        AND
      ol.line_category_code = 'RETURN'                   AND
      ol.return_reason_code = 'XXCS_DOA'                 AND
      ol.inventory_item_id  = msib.inventory_item_id     AND
      msib.organization_id = 91                          AND
      oh.sold_to_org_id = hca.cust_account_id            AND
      hca.party_id = hp1.party_id                        AND
      to_number(hp1.attribute3)=oup.organization_id(+)   AND
      XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(to_number(hp1.attribute3),hp1.party_id)='Y'
UNION ALL
SELECT  --Debrief
        'Debrief'                                    "SOURCE",
        dh.source_number                             ORDER_SR_NUMBER,
        dh.incident_id                               ORDER_SR_ID,
        dh.debrief_date                              SO_SR_DATE,
        srs.name                                     SO_SR_STATUS,
        cit.name                                     SO_SR_TYPE,
        dh.task_number                               SO_LINE_TASK_NUMBER,
        dl.spare_update_status                       SO_DEBRIF_LINE_STATUS,
        dl.service_date                              SO_DEBRIEF_LINE_DATE,
        dl.inventory_item_id                         INVENTORY_ITEM_ID,
        msi.segment1                                 ITEM,
        msi.description                              ITEM_DESCRIPTION,
        dl.quantity                                  QUANTITY,
        dl.uom_code                                  UOM,
        hp.party_name                                CUSTOMER,
        ----hp.attribute1                                REGION
        --sr.external_attribute_1                      REGION
        ''                                           REGION,
        oup.name                                     OPERATING_UNIT_PARTY,
        to_number(hp.attribute3)                     ORG_ID,
        hca.sales_channel_code
FROM    CSF_DEBRIEF_HEADERS_V                   dh,
        CSF_DEBRIEF_MAT_LINES_V                 dl,
        cs_incidents_all_b                      sr,
        cs_incident_statuses_tl                 srs,
        cs_incident_types_tl                    cit,
        mtl_system_items_b                      msi,
        hz_parties                              hp,
        hz_cust_accounts                        hca,
        hr_operating_units                      oup
WHERE   dh.debrief_header_id = dl.debrief_header_id     AND
        dl.attribute2 = 'DOA'                           AND
        dh.organization_id = 91                         AND
        dh.incident_id = sr.incident_id                 AND
        sr.incident_status_id = srs.incident_status_id  AND
        srs.language = 'US'                             AND
        sr.incident_type_id = cit.incident_type_id      AND
        cit.language = 'US'                             AND
        dl.inventory_item_id = msi.inventory_item_id    AND
        dh.organization_id = msi.organization_id        AND
        sr.customer_id = hp.party_id                    AND
        hp.party_id=hca.party_id                        AND
        to_number(hp.attribute3)=oup.organization_id(+) AND
      XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(to_number(hp.attribute3),hp.party_id)='Y';
