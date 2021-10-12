CREATE OR REPLACE TRIGGER xxpo_msc_req_int_bir_trg
   ---------------------------------------------------------------------------
   -- $Header: XXPO_MSC_REQ_INT_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: XXPO_MSC_REQ_INT_BIR_TRG
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: relate the rerquisition line to the source supply line 
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
BEFORE INSERT ON msc_po_requisitions_interface
  FOR EACH ROW
BEGIN

   /*** Insert future requisition details to temp table to relate
   the rerquisition line to the source supply line ***/

   INSERT INTO xxobjt_mrp_req_int_temp
      (transaction_id,
       need_by_date,
       item_id,
       item_revision,
       charge_account_id,
       batch_id,
       group_code,
       preparer_id,
       autosource_flag,
       source_organization_id,
       destination_organization_id,
       deliver_to_location_id,
       deliver_to_requestor_id,
       suggested_vendor_id,
       suggested_vendor_site_id,
       source_type_code,
       destination_type_code,
       quantity,
       uom_code,
       line_type_id,
       org_id,
       end_item_unit_number,
       sr_instance_id,
       req_use_flag)
   VALUES
      (:NEW.source_line_id,
       :NEW.need_by_date,
       :NEW.item_id,
       :NEW.item_revision,
       :NEW.charge_account_id,
       :NEW.batch_id,
       :NEW.group_code,
       :NEW.preparer_id,
       :NEW.autosource_flag,
       :NEW.source_organization_id,
       :NEW.destination_organization_id,
       :NEW.deliver_to_location_id,
       :NEW.deliver_to_requestor_id,
       :NEW.suggested_vendor_id,
       :NEW.suggested_vendor_site_id,
       :NEW.source_type_code,
       :NEW.destination_type_code,
       :NEW.quantity,
       :NEW.uom_code,
       :NEW.line_type_id,
       :NEW.org_id,
       :NEW.end_item_unit_number,
       :NEW.sr_instance_id,
       'N');
END xxpo_msc_req_int_bir_trg;
/

