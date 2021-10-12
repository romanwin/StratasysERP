CREATE OR REPLACE TRIGGER xxpo_requisition_int_bir_trg
   ---------------------------------------------------------------------------
   -- $Header: XXPO_REQUISITION_INT_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: XXPO_REQUISITION_INT_BIR_TRG
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: handle price and approval status for auto create requisitions
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
BEFORE INSERT ON po_requisitions_interface_all
  FOR EACH ROW
  
when (NEW.interface_source_code in ('MSC', 'FILE'))
DECLARE
   l_transaction_id       NUMBER;
   l_sr_instance_id       NUMBER;
   l_list_header_id       qp_list_headers_all.list_header_id%TYPE := NULL;
   l_unit_price           NUMBER := NULL;
   l_source_line_id       NUMBER;
   l_error_msg            VARCHAR2(80);
   l_price_list_curr_code VARCHAR2(3);
   l_source_curr_code     VARCHAR2(3);
BEGIN

   IF :NEW.interface_source_code = 'MSC' THEN
   
      :NEW.authorization_status := 'INCOMPLETE';
   
      /*      BEGIN
      
         SELECT max(mri.transaction_id), max(mri.sr_instance_id)
           INTO l_transaction_id, l_sr_instance_id
           FROM xxobjt_mrp_req_int_temp mri
          WHERE need_by_date = :NEW.need_by_date AND
                item_id = :NEW.item_id AND
                preparer_id = :NEW.preparer_id AND
                quantity = :NEW.quantity AND
                org_id = :NEW.org_id AND
                batch_id = :NEW.batch_id AND
                nvl(source_organization_id, fnd_api.g_miss_num) =
                nvl(:NEW.source_organization_id, fnd_api.g_miss_num) AND
                nvl(destination_organization_id, fnd_api.g_miss_num) =
                nvl(:NEW.destination_organization_id, fnd_api.g_miss_num) AND
                nvl(item_revision, fnd_api.g_miss_char) =
                nvl(:NEW.item_revision, fnd_api.g_miss_char) AND
                nvl(charge_account_id, fnd_api.g_miss_num) =
                nvl(:NEW.charge_account_id, fnd_api.g_miss_num) AND
                nvl(group_code, fnd_api.g_miss_char) =
                nvl(:NEW.group_code, fnd_api.g_miss_char) AND
                nvl(autosource_flag, fnd_api.g_miss_char) =
                nvl(:NEW.autosource_flag, fnd_api.g_miss_char) AND
                nvl(deliver_to_location_id, fnd_api.g_miss_num) =
                nvl(:NEW.deliver_to_location_id, fnd_api.g_miss_num) AND
                nvl(deliver_to_requestor_id, fnd_api.g_miss_num) =
                nvl(:NEW.deliver_to_requestor_id, fnd_api.g_miss_num) AND
                nvl(suggested_vendor_id, fnd_api.g_miss_num) =
                nvl(:NEW.suggested_vendor_id, fnd_api.g_miss_num) AND
                nvl(suggested_vendor_site, fnd_api.g_miss_num) =
                nvl(:NEW.suggested_vendor_site, fnd_api.g_miss_num) AND
                nvl(source_type_code, fnd_api.g_miss_char) =
                nvl(:NEW.source_type_code, fnd_api.g_miss_char) AND
                nvl(destination_type_code, fnd_api.g_miss_char) =
                nvl(:NEW.destination_type_code, fnd_api.g_miss_char) AND
                nvl(uom_code, fnd_api.g_miss_char) =
                nvl(:NEW.uom_code, fnd_api.g_miss_char) AND
                nvl(line_type_id, fnd_api.g_miss_num) =
                nvl(:NEW.line_type_id, fnd_api.g_miss_num) AND
                nvl(end_item_unit_number, fnd_api.g_miss_num) =
                nvl(:NEW.end_item_unit_number, fnd_api.g_miss_num) AND
                req_use_flag = 'N';
      
         DELETE xxobjt_mrp_req_int_temp
          WHERE transaction_id = l_transaction_id AND
                sr_instance_id = l_sr_instance_id AND
                req_use_flag = 'N' AND
                rownum < 2;
      
         :NEW.line_attribute1 := l_transaction_id;
         :NEW.line_attribute2 := l_sr_instance_id;
      
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;*/
   
   END IF;

   IF :NEW.source_organization_id != :NEW.destination_organization_id THEN
   
      l_list_header_id := xxpo_advanced_price_pkg.get_list_price_from_ic(:NEW.source_organization_id,
                                                                         :NEW.destination_organization_id,
                                                                         l_price_list_curr_code,
                                                                         l_source_curr_code);
   
      xxpo_advanced_price_pkg.get_item_price(l_list_header_id,
                                             :NEW.item_id,
                                             l_price_list_curr_code,
                                             l_source_curr_code,
                                             l_unit_price);
   
      IF l_unit_price IS NOT NULL THEN
         :NEW.unit_price := l_unit_price;
      END IF;
   
   END IF;

END xxpo_requisition_int_bir_trg;
/

