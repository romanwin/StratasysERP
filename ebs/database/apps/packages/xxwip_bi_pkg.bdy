CREATE OR REPLACE PACKAGE BODY xxwip_bi_pkg IS

  FUNCTION internal_onhand_nettable(p_inventory_item_id NUMBER,
                                    p_organization_id   NUMBER) RETURN NUMBER IS
    v_qty NUMBER := 0;
  
  BEGIN
    BEGIN
      SELECT nvl(SUM(mtoh.transaction_quantity), 0)
        INTO v_qty
        FROM mtl_onhand_quantities_detail mtoh,
             mtl_secondary_inventories    subinv
       WHERE mtoh.subinventory_code = subinv.secondary_inventory_name
         AND mtoh.organization_id = subinv.organization_id
         AND mtoh.inventory_item_id = p_inventory_item_id
         AND subinv.attribute1 IS NULL
         AND subinv.availability_type = 1
         AND mtoh.organization_id = p_organization_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        -- dbms_output.put_line(Sqlerrm);
        RETURN 0;
    END;
    RETURN v_qty;
  END internal_onhand_nettable;

  FUNCTION external_onhand_nettable(p_inventory_item_id NUMBER,
                                    p_supplier_code     VARCHAR2)
    RETURN NUMBER IS
    v_qty NUMBER := 0;
  
  BEGIN
    BEGIN
      SELECT nvl(SUM(mtoh.transaction_quantity), 0)
        INTO v_qty
        FROM mtl_onhand_quantities_detail mtoh,
             mtl_secondary_inventories    subinv
       WHERE mtoh.subinventory_code = subinv.secondary_inventory_name
         AND mtoh.organization_id = subinv.organization_id
         AND mtoh.inventory_item_id = p_inventory_item_id
         AND subinv.attribute1 IS NOT NULL
         AND subinv.secondary_inventory_name =
             nvl(p_supplier_code, subinv.secondary_inventory_name);
    
    EXCEPTION
      WHEN OTHERS THEN
        --dbms_output.put_line(Sqlerrm);
        RETURN 0;
    END;
    RETURN v_qty;
  END external_onhand_nettable;

  FUNCTION internal_released_jobs_qty(p_inventory_item_id NUMBER,
                                      p_status_type       NUMBER /*default 3 - released*/,
                                      p_wip_entity_id     NUMBER)
    RETURN NUMBER IS
    v_released_qty NUMBER;
  BEGIN
    BEGIN
      SELECT (nvl(SUM(wro.required_quantity), 0) -
             nvl(SUM(wro.quantity_issued), 0))
        INTO v_released_qty
        FROM wip_requirement_operations wro, wip_discrete_jobs wdj
       WHERE wro.organization_id = wdj.organization_id
         AND wdj.wip_entity_id = wro.wip_entity_id
         AND wdj.status_type = p_status_type
         AND wro.inventory_item_id = p_inventory_item_id
         AND wro.wip_entity_id <> p_wip_entity_id
         AND nvl(wro.supply_subinventory, 1) NOT IN
             (SELECT mtlsec.secondary_inventory_name
                FROM mtl_secondary_inventories mtlsec
               WHERE mtlsec.attribute1 IS NOT NULL
                 AND mtlsec.organization_id = wdj.organization_id);
    
      /*    
      And nvl(wro.supply_subinventory,
             (Select default_pull_supply_subinv
              From wip_parameters
              Where organization_id = wdj.organization_id)) =
            (Select default_pull_supply_subinv
             From wip_parameters
             Where organization_id = wdj.organization_id);*/
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_released_qty;
  END internal_released_jobs_qty;

  FUNCTION external_released_jobs_qty(p_inventory_item_id NUMBER,
                                      p_status_type       NUMBER /*default 3 - released*/,
                                      p_supplier_code     VARCHAR2 /* if null then released internal*/,
                                      p_wip_entity_id     NUMBER)
    RETURN NUMBER IS
  
    v_released_qty NUMBER;
  BEGIN
    BEGIN
      SELECT (nvl(SUM(wro.required_quantity), 0) -
             nvl(SUM(wro.quantity_issued), 0))
        INTO v_released_qty
        FROM wip_requirement_operations wro, wip_discrete_jobs wdj
       WHERE wro.organization_id = wdj.organization_id
         AND wdj.wip_entity_id = wro.wip_entity_id
         AND wdj.status_type = p_status_type
         AND wro.inventory_item_id = p_inventory_item_id
         AND wro.wip_entity_id <> p_wip_entity_id
         AND wro.supply_subinventory IN
             (SELECT mtlsec.secondary_inventory_name
                FROM mtl_secondary_inventories mtlsec
               WHERE mtlsec.attribute1 IS NOT NULL
                 AND mtlsec.organization_id = wdj.organization_id)
         AND nvl(wro.supply_subinventory,
                 (SELECT default_pull_supply_subinv
                    FROM wip_parameters
                   WHERE organization_id = wdj.organization_id)) =
             nvl(p_supplier_code, wro.supply_subinventory);
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_released_qty;
  END external_released_jobs_qty;

  FUNCTION open_supply_qty(p_inventory_item_id NUMBER) RETURN NUMBER IS
    v_qty NUMBER;
  BEGIN
    BEGIN
      /*     Select ms.quantity
      Into v_qty
      From mtl_supply ms
      Where ms.item_id = p_inventory_item_id;*/
    
      SELECT SUM(sp.quantity)
        INTO v_qty
        FROM mtl_supply sp /*,
                                                                                                                                         mtl_system_items_b msi*/
       WHERE sp.item_id = p_inventory_item_id
         AND sp.supply_type_code LIKE 'PO';
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_qty;
  END open_supply_qty; --mtl_supply*/

  FUNCTION oldest_po_vendor(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    v_vendor_name VARCHAR2(128);
  BEGIN
    BEGIN
      SELECT pv.vendor_name
        INTO v_vendor_name
        FROM po_headers_all     poh,
             po_vendors         pv,
             mtl_supply         ms,
             mtl_system_items_b msi
       WHERE poh.po_header_id = ms.po_header_id
         AND pv.vendor_id = poh.vendor_id
         AND ms.item_id = p_inventory_item_id
         AND ms.to_organization_id = msi.organization_id
         AND rownum = 1
       ORDER BY pv.creation_date;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    RETURN v_vendor_name;
  END oldest_po_vendor;

  FUNCTION wip_comp_assbly_descrip(p_wip_job           NUMBER,
                                   p_inventory_item_id NUMBER,
                                   p_info_request      VARCHAR2)
    RETURN VARCHAR2 IS
    v_assembly    VARCHAR2(40);
    v_component   VARCHAR2(40);
    v_description VARCHAR2(240);
    v_comp_type   VARCHAR2(240);
  BEGIN
    BEGIN
      SELECT msi1.segment1 assembly,
             msi2.segment1 component,
             msi2.description description,
             look2.meaning
        INTO v_assembly, v_component, v_description, v_comp_type
        FROM wip.wip_requirement_operations mat,
             wip.wip_entities               ent,
             wip.wip_discrete_jobs          djob,
             mtl_system_items_b             msi1,
             mtl_system_items_b             msi2,
             mfg_lookups                    look,
             mfg_lookups                    look2
       WHERE 1 = 1
         AND mat.wip_entity_id = ent.wip_entity_id
         AND ent.wip_entity_id = djob.wip_entity_id
         AND ent.primary_item_id = msi1.inventory_item_id
         AND mat.inventory_item_id = msi2.inventory_item_id
         AND msi1.organization_id = mat.organization_id
         AND msi2.organization_id = mat.organization_id
         AND look2.lookup_code = mat.wip_supply_type
         AND look2.lookup_type = 'WIP_SUPPLY'
            
            --And mat.wip_supply_type Not In (4, 5, 6)
            --And mat.wip_supply_type In (1, 3, 6) -- Unreleased, Released, On Hand
            
         AND look.lookup_type = 'WIP_JOB_STATUS'
         AND djob.status_type = look.lookup_code
         AND ent.wip_entity_name = p_wip_job
         AND msi2.inventory_item_id = p_inventory_item_id;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    CASE p_info_request
      WHEN 'COMPONENT' THEN
        RETURN v_component;
      WHEN 'ASSEMBLY' THEN
        RETURN v_assembly;
      WHEN 'DESCRIPTION' THEN
        RETURN v_description;
      WHEN 'COMP_TYPE' THEN
        RETURN v_comp_type;
      ELSE
        RETURN NULL;
    END CASE;
  END wip_comp_assbly_descrip;

  FUNCTION supply_over_all_wip_jobs(p_inventory_item_id NUMBER) RETURN NUMBER IS
    v_supply NUMBER;
  BEGIN
    BEGIN
      SELECT SUM(start_quantity) - SUM(quantity_completed)
        INTO v_supply
        FROM wip_discrete_jobs wdj2, wip_entities we2
      --        wip_requirement_operations wro2
       WHERE wdj2.status_type IN (1, 3, 6)
         AND wdj2.wip_entity_id = we2.wip_entity_id
         AND we2.primary_item_id = p_inventory_item_id;
      --     And we2.wip_entity_id = wro2.wip_entity_id
      /*  And wro2.inventory_item_id In
      (Select nn.inventory_item_id
       From mtl_system_items_b nn
       Where nn.segment1 =
             ryst_bi_wip.wip_comp_assbly_descrip(p_wip_job,
                                                 p_inventory_item_id,
                                                 'COMPONENT'));*/
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_supply;
  END supply_over_all_wip_jobs;

  FUNCTION wip_req_for_released(p_wip_entity_id NUMBER) RETURN NUMBER IS
    v_qty NUMBER;
  BEGIN
    BEGIN
      SELECT (SUM(wro.required_quantity) - SUM(wro.quantity_issued))
        INTO v_qty
        FROM wip_requirement_operations wro, wip_discrete_jobs wdj
       WHERE wdj.wip_entity_id = wro.wip_entity_id
         AND wdj.status_type = 3 --Released only
         AND wro.wip_entity_id = p_wip_entity_id
       GROUP BY wro.wip_entity_id;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_qty;
  END wip_req_for_released;

  FUNCTION il_job_pick_qty(p_entity_id wip_entities.wip_entity_id%TYPE)
    RETURN NUMBER IS
    v_pick_quantity NUMBER := 1;
  BEGIN
    BEGIN
      SELECT nvl((SUM(wor.quantity_allocated) + SUM(wor.quantity_issued)),
                 0) / decode(SUM(wor.required_quantity),
                             0,
                             1,
                             SUM(wor.required_quantity))
        INTO v_pick_quantity
        FROM wip_requirement_operations wor
       WHERE wor.wip_entity_id = p_entity_id
         AND nvl(wor.supply_subinventory, 'xxx') NOT IN
             (SELECT wipp.default_pull_supply_subinv
                FROM wip_parameters wipp
               WHERE wor.organization_id = wipp.organization_id);
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          v_pick_quantity := 1;
          RETURN v_pick_quantity;
        END;
      WHEN OTHERS THEN
        v_pick_quantity := 0;
        RETURN v_pick_quantity;
    END;
    RETURN nvl(v_pick_quantity, 1);
  END il_job_pick_qty;

  FUNCTION po_open_quantity(p_inventory_item_id NUMBER,
                            p_organization_id   NUMBER) RETURN NUMBER IS
    v_qty NUMBER := 0;
  
  BEGIN
    BEGIN
      SELECT nvl(SUM(ms.quantity), 0)
        INTO v_qty
        FROM mtl_supply ms
       WHERE ms.item_id = p_inventory_item_id
         AND ms.to_organization_id = p_organization_id
         AND ms.supply_type_code LIKE 'PO';
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END;
    RETURN v_qty;
  END po_open_quantity;

  FUNCTION po_vendor_name(p_inventory_item_id NUMBER,
                          p_organization_id   NUMBER) RETURN VARCHAR2 IS
    v_name VARCHAR2(300) := NULL;
  
    CURSOR csr_vendors IS
      SELECT DISTINCT ven.vendor_name
        FROM mtl_supply ms, po_headers_all pha, po_vendors ven
       WHERE ms.item_id = p_inventory_item_id
         AND ms.to_organization_id = p_organization_id
         AND ms.supply_type_code LIKE 'PO'
         AND ms.po_header_id = pha.po_header_id
         AND pha.vendor_id = ven.vendor_id;
    cur_vendor csr_vendors%ROWTYPE;
  
  BEGIN
  
    FOR cur_vendor IN csr_vendors LOOP
    
      v_name := v_name || cur_vendor.vendor_name || ',';
    
      IF length(v_name) > 240 THEN
        v_name := substr(v_name, 1, 240);
        EXIT;
      END IF;
    END LOOP;
  
    RETURN rtrim(v_name, ',');
  END po_vendor_name;

  FUNCTION po_buyer_name(p_inventory_item_id NUMBER,
                         p_organization_id   NUMBER) RETURN VARCHAR2 IS
    v_name VARCHAR2(300) := NULL;
  
    CURSOR csr_buyers IS
      SELECT DISTINCT pap.full_name
        FROM Mtl_Supply       ms,
             po_headers_all   Pha,
             po_vendors       VEN,
             PER_ALL_PEOPLE_F pap
       WHERE ms.to_organization_id = p_organization_id
         and MS.Item_Id = p_inventory_item_id
         and MS.SUPPLY_TYPE_CODE LIKE 'PO'
         and MS.po_header_id = pha.po_header_id
         and pha.vendor_id = ven.vendor_id
         and pha.agent_id = pap.person_id;
    cur_buyer csr_buyers%ROWTYPE;
  
  BEGIN
  
    FOR cur_buyer IN csr_buyers LOOP
    
      v_name := v_name || cur_buyer.full_name || ' , ';
    
      IF length(v_name) > 240 THEN
        v_name := substr(v_name, 1, 240);
        EXIT;
      END IF;
    END LOOP;
  
    RETURN rtrim(v_name, ' , ');
  END po_buyer_name;

  function xx_job_pick_qty(p_entity_id wip_entities.wip_entity_id%type)
    return number is
    v_Pick_quantity number;
  Begin
     Begin
     SELECT round ((nvl(sum(wro.quantity_allocated),0)+nvl(sum(wro.quantity_issued),0)/sum(wro.required_quantity)),2)
     into v_Pick_quantity
     FROM wip_requirement_operations wro, fnd_lookup_values flv
     where wro.wip_entity_id=p_entity_id
     and wro.wip_supply_type = flv.lookup_code
     and flv.lookup_type = 'WIP_SUPPLY'
     and flv.meaning = 'Push';
    Exception
      When Others Then
        v_Pick_quantity := 0;
    End;
    return nvl(v_Pick_quantity*100,0);
  End xx_Job_Pick_Qty;

END xxwip_bi_pkg;
/

