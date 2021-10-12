CREATE OR REPLACE FORCE VIEW "APPS"."IBE_ORDER_SUM_V" 
--------------------------------------------------------------------
--  name:            IBE_ORDER_SUM_V
--  create by:       yuval tal
--  Revision:        1.1
--  creation date:   2.8.12
--------------------------------------------------------------------
--  purpose :        eStore Order summary
--------------------------------------------------------------------
--  ver  date        name                  desc
--  1.0  2.8.12      yuval tal /apps ass   restrict order by source
--------------------------------------------------------------------

  ("HEADER_ID", "CREATED_BY", "REFERENCE_NUMBER", "WEB_CONFIRM_NUMBER", "ORDER_NUMBER", "ORDERED_DATE", "ORDER_STATUS", "CUST_ACCOUNT_ID",
 "PARTY_ID", "CUSTOMER_NAME", "CUST_PO_NUMBER", "CREDIT_CARD_NUMBER", "ORDER_CATEGORY_CODE", "BOOKED_DATE", "SOLD_TO_CONTACT_ID", "CANCELLED_FLAG",
 "OPEN_FLAG", "BOOKED_FLAG", "SOURCE_DOCUMENT_ID", "SOURCE_DOCUMENT_TYPE_ID", "MEANING", "BILL_TO_ACCOUNT_ID", "BILL_TO_ACCT_SITE_ID", "ORG_ID") 
 AS 
SELECT oh.header_id,
       oh.created_by,
       oh.source_document_id,
       oh.orig_sys_document_ref,
       oh.order_number,
       oh.ordered_date,
       oh.flow_status_code order_status,
       oh.sold_to_org_id cust_account_id,
       cust.party_id,
       cust.party_name customer_name,
       oh.cust_po_number,
       substr(oh.credit_card_number, (length(oh.credit_card_number) - 3), 4),
       oh.order_category_code,
       oh.booked_date,
       oh.sold_to_contact_id,
       oh.cancelled_flag,
       oh.open_flag,
       oh.booked_flag,
       oh.source_document_id,
       oh.source_document_type_id,
       oel.meaning,
       hcs.cust_account_id,
       hcsu.cust_acct_site_id,
       oh.org_id org_id
  FROM oe_order_headers_all   oh,
       hz_cust_accounts       acct,
       hz_parties             cust,
       oe_lookups             oel,
       hz_cust_site_uses_all  hcsu,
       hz_cust_acct_sites_all hcs,
       oe_order_sources       oos
 WHERE oh.sold_to_org_id = acct.cust_account_id
   AND acct.party_id = cust.party_id
   AND oel.lookup_code = oh.flow_status_code
   AND oel.lookup_type = 'FLOW_STATUS'
   AND oh.invoice_to_org_id = hcsu.site_use_id(+)
   AND hcsu.cust_acct_site_id = hcs.cust_acct_site_id(+)
   AND oh.order_source_id = oos.order_source_id
   AND oos.name = 'IStore Account';
