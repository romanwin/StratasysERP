create or replace view XQS_Po_Open_REQ_V as 
select 
 ---------------------------------------------------------------------------
  -- $Header: XQS_Po_Open_REQ_V   $
  ---------------------------------------------------------------------------
  -- Package: XQS_Po_Open_REQ_V
  -- Created:
  ------------------------------------------------------------------
  -- Purpose: CUST-802 CR1308- Open Requisitions Alert
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  23.2.14   shirly b         initial build
  ------------------------------------------------------------------
  t.req_type as "Req Type",
       t.project_name as "Project",
       t.req_num as "Req Num",
       t.req_creation_date as "Req Creation Date",
       t.requestor as "Requestor",
       t.req_status as "Req Status",
       t.current_req_approver as "Current Req Approver",
       t.req_approved_date as "Req Approved Date",
       t.req_buyer as "Buyer",
       t.po_so_num as "PO SO Num",
       t.po_so_creation_date as "PO SO Creation Date",
       t.po_status as "PO Status",
       t.line_type as "Line Type",
       t.item_description as "Item Desc",
       t.qty_due as "Qty Due",
       t.current_po_approver as "Current PO Approver",
       t.po_so_approved_date as "PO SO Approved Date",
       t.promised_date as "Promised Date",
       t.last_po_acceptance as "Last Acceptance",
       t.deliver_to_location_id as "Deliver To Location Id"
from XXPO_Po_Open_REQ_V t
order by t.req_approved_date
;
create or replace synonym apps_view.XQS_Po_Open_REQ_V for XQS_Po_Open_REQ_V;
Grant select on apps.XQS_Po_Open_REQ_V to apps_view;
