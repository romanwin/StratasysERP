CREATE OR REPLACE TRIGGER XXAP_SUPPLIERS_APR_TRG
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Trigger: XXAP_SUPPLIERS_APR_TRG
   -- Created:
   -- Author  : YUVAL TAL
   --------------------------------------------------------------------------
   -- Perpose:  CUST607 - support supplier approval process
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --   1.0    26.11.12   yuval tal       Initial Build
   ---------------------------------------------------------------------------
BEFORE  INSERT OR UPDATE  OF ATTRIBUTE1 or update of vendor_type_lookup_code ON ap_suppliers
    FOR EACH ROW


DECLARE
  l_type_require_approval_flag NUMBER;
BEGIN

  IF fnd_profile.value('XXPO_ENABLE_APPROVAL_PROCESS') = 'Y' THEN
    l_type_require_approval_flag := 0;
    -- check vendor type require approval
    IF updating AND (nvl(:new.vendor_type_lookup_code, '-1') !=
       nvl(:old.vendor_type_lookup_code, -1)) THEN
    
      IF xxpo_supplier_approval_pkg.is_approval_process_needed(nvl(:old.vendor_type_lookup_code,
                                                                   '-1')) = 'NO' AND
         xxpo_supplier_approval_pkg.is_approval_process_needed(nvl(:new.vendor_type_lookup_code,
                                                                   '-1')) =
         'YES' THEN
      
        :new.attribute1              := xxpo_supplier_approval_pkg.get_approval_status_by_seq(1);
        l_type_require_approval_flag := 1;
      END IF;
    
    END IF;
    -- check approval status change
    IF (updating AND nvl(:new.attribute1, '-1') != nvl(:old.attribute1, -1)) OR
       inserting AND :new.attribute1 IS NOT NULL THEN
    
      -- check approval needed according to vendor type
      IF xxpo_supplier_approval_pkg.is_approval_process_needed(nvl(:new.vendor_type_lookup_code,
                                                                   :old.vendor_type_lookup_code)) =
         'YES' THEN
      
        -- check hierarchy
        IF l_type_require_approval_flag = 0 AND updating AND
           nvl(:new.attribute1, '0') != 'Rejected' AND
           xxpo_supplier_approval_pkg.is_hierarchy_exists(:old.attribute1,
                                                          :new.attribute1) = 0 THEN
          fnd_message.set_name('XXOBJT', 'XXPUR_SUPPLIER_HIERARCY_ALERT');
          app_exception.raise_exception;
        END IF;
      
        -- check attachment needed
        IF xxpo_supplier_approval_pkg.attachment_exists(:new.vendor_id,
                                                        :new.attribute1) = 'N' THEN
        
          fnd_message.set_name('XXOBJT', 'XXPUR_SUPPLIER_ATT_ALERT');
          app_exception.raise_exception;
        
        END IF;
        -- send status alert
        xxpo_supplier_approval_pkg.send_mail(p_vendor_id     => :new.vendor_id,
                                             p_created_by    => :new.created_by,
                                             p_supplier_name => :new.vendor_name,
                                             p_old_status    => nvl(:old.attribute1,
                                                                    'Draft'),
                                             p_new_status    => :new.attribute1,
                                             p_history_ind   => 'Y');
      
      END IF;
    
    END IF;
  END IF;
END xxpo_requisition_int_bir_trg;
/
