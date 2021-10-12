CREATE OR REPLACE TRIGGER XXWIP_REQUISITION_INT_BIR_TRG
   ---------------------------------------------------------------------------
   -- $Header: XXWIP_REQUISITION_INT_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: XXWIP_REQUISITION_INT_BIR_TRG
   -- Created: 18/04/2004
   -- Author  : Boris Sandler
   --------------------------------------------------------------------------
   -- Perpose: Trigger will update the suggested_vendor_id and suggested_vendor _site_id
   --          based on connectin between subinventory and suppler for OSP process.
   --------------------------------------------------------------------------
   -- Version  Date      Performer           Comments
   ----------  --------  --------------      -------------------------------------
   --     1.0  31/08/09                      Initial Build
   --     1.1  15.8.12    yuval tal          cr480 : add logig for suggested buyer and need_by_date
   --     1.2  20/03/13   yuval atl          CR 709 :  change item description call xxqa_utils_pkg.get_rfr_responsibility_from_mf(we.wip_entity_id)
   --     1.3  08/06/14   yuval tal          CHG0032230 :Add RFR job type to the PO item description
   --     1.4  03/04/15   Gubendran K        CHG0033541: Added malfunction number(Attribute 4-8) to the requisition description line.
   --     1.5  17/05/16   yuval tal          INC0064647 - change logic of suggested_buyer_id
   ---------------------------------------------------------------------------
BEFORE INSERT ON PO_REQUISITIONS_INTERFACE_ALL
  FOR EACH ROW


when (NEW.destination_type_code = 'SHOP FLOOR' AND NEW.wip_entity_id IS NOT NULL)
DECLARE
  v_vendor_id_for_change  po_vendor_sites.vendor_id%TYPE := NULL;
  v_vendor_site_id_change po_vendor_sites.vendor_site_id%TYPE := NULL;
  v_job_name              wip_entities.wip_entity_name%TYPE := NULL;
  v_assembly_item         mtl_system_items_b.segment1%TYPE := NULL;
  -- v_class_code            wip_discrete_jobs.class_code%TYPE := NULL;
  v_malfunction_reason VARCHAR2(150) := NULL;
  l_rfr_job_type       VARCHAR2(240);
  --CHG0033541
  l_rfr_mf1      VARCHAR2(150);
  l_rfr_mf2      VARCHAR2(150);
  l_rfr_mf3      VARCHAR2(150);
  l_rfr_mf4      VARCHAR2(150);
  l_rfr_mf5      VARCHAR2(150);
  v_ass_mal_type VARCHAR2(240);
  v_rfr_mf_all   VARCHAR2(240);
  --CHG0033541
BEGIN

  IF nvl(fnd_profile.value('XXWIP_ENABLE_REQ_DEFAULT'), 'N') = 'Y' THEN
  
    :new.autosource_flag := 'P';
  
    BEGIN
    
      SELECT we.wip_entity_name,
	 msi.segment1,
	 --wdj.attribute2 malfunction,
	 --CHG0033541
	 wdj.attribute4,
	 wdj.attribute5,
	 wdj.attribute6,
	 wdj.attribute7,
	 wdj.attribute8,
	 --CHG0033541
	 xxqa_utils_pkg.get_rfr_responsibility_from_mf(we.wip_entity_id),
	 SYSDATE + nvl(req_msi.full_lead_time, 0) +
	 nvl(req_msi.preprocessing_lead_time, 0), -- CR480 need by date
	 wdj.attribute12
      INTO   v_job_name,
	 v_assembly_item,
	 --CHG0033541
	 l_rfr_mf1,
	 l_rfr_mf2,
	 l_rfr_mf3,
	 l_rfr_mf4,
	 l_rfr_mf5,
	 --CHG0033541
	 v_malfunction_reason,
	 :new.need_by_date,
	 l_rfr_job_type
      FROM   wip_discrete_jobs  wdj,
	 wip_entities       we,
	 mtl_system_items_b msi,
	 mtl_system_items_b req_msi
      WHERE  wdj.wip_entity_id = :new.wip_entity_id
      AND    wdj.wip_entity_id = we.wip_entity_id
      AND    wdj.primary_item_id = msi.inventory_item_id
      AND    wdj.organization_id = msi.organization_id
      AND    req_msi.inventory_item_id = :new.item_id
      AND    req_msi.organization_id = wdj.organization_id
      AND    req_msi.allow_item_desc_update_flag = 'Y';
    
      --CHG0033541
      v_ass_mal_type := v_assembly_item || ' ' || v_malfunction_reason || ' ' ||
		l_rfr_job_type;
      v_rfr_mf_all   := l_rfr_mf1 || ' ' || l_rfr_mf2 || ' ' || l_rfr_mf3 || ' ' ||
		l_rfr_mf4 || ' ' || l_rfr_mf5;
      --CHG0033541
      fnd_message.set_name('XXOBJT', 'XXWIP_REQ_LINE_DESCRIPTION');
      fnd_message.set_token('JOB', v_job_name);
      --fnd_message.set_token('ASSEMBLY', v_assembly_item);
      --fnd_message.set_token('MALFUNC', v_malfunction_reason);
      fnd_message.set_token('ASSEMBLY', v_ass_mal_type); --CHG0033541 - Changed the variable name
      fnd_message.set_token('MALFUNC', v_rfr_mf_all); --CHG0033541 - Changed the variable name
    
      --:new.item_description := fnd_message.get || ' ' || l_rfr_job_type;
      :new.item_description := fnd_message.get; --CHG0033541 - Removed l_rfr_job_type variable
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    SELECT pvs.vendor_id,
           pvs.vendor_site_id,
           pvs.attribute1 vs_id -- INC0064647
    INTO   v_vendor_id_for_change,
           v_vendor_site_id_change,
           :new.suggested_buyer_id -- INC0064647
    
    FROM   wip_discrete_jobs wdj,
           --    mtl_secondary_inventories sub,
           po_vendor_sites_all pvs
    WHERE  wdj.wip_entity_id = :new.wip_entity_id
    AND    
          --wdj.attribute1 = sub.secondary_inventory_name AND
          --wdj.organization_id = sub.organization_id AND
           pvs.vendor_site_id = wdj.attribute1;
  
    :new.suggested_vendor_id      := v_vendor_id_for_change;
    :new.suggested_vendor_site_id := v_vendor_site_id_change;
  
    -- cr480 vs person_id
    -- INC0064647
    /*IF v_vendor_id_for_change IS NOT NULL THEN
    
      SELECT attribute7
      INTO   :new.suggested_buyer_id
      FROM   po_vendors v
      WHERE  v.vendor_id = v_vendor_id_for_change;
    END IF;*/
  
    -- check active
    IF :new.suggested_buyer_id IS NOT NULL THEN
      BEGIN
        SELECT pbv.employee_id
        INTO   :new.suggested_buyer_id
        FROM   po_buyers_v pbv
        WHERE  pbv.employee_id = :new.suggested_buyer_id;
      EXCEPTION
        WHEN OTHERS THEN
          :new.suggested_buyer_id := NULL;
      END;
    END IF;
  
  END IF;

EXCEPTION
  WHEN no_data_found THEN
    :new.suggested_vendor_id      := NULL;
    :new.suggested_vendor_site_id := NULL;
  
END;
/
