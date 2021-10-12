CREATE OR REPLACE PACKAGE BODY xxwip_material_req_plan_pkg IS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  ---------------------------------------------------------------------
  --  1.0  29.8.13     yuval tal      rep 299 - CR766 -modify build procedure ,get_quantity_allocated
  --  1.1 30.10.13     yuval tal      rep 229 - CR1056- modify proc biuld : split  Promise Date and PO quantity columns
  --  1.2  30.10.13    yuval tal      rep 229 - CR-1085 init_qty_sub_array modify logic
  --  1.3 17.06.14     yuval tal      CHG0032122 : modify build
   --------------------------------------------------------------------
  TYPE po_info IS RECORD(
    item_id          NUMBER,
    po_number        VARCHAR2(10),
    po_promised_date DATE,
    po_quantity      NUMBER);

  TYPE po_rec IS TABLE OF po_info INDEX BY BINARY_INTEGER;
  g_po_rec po_rec;

  TYPE sub_inv_qty_t IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  g_sub_inv_qty sub_inv_qty_t;

  TYPE t_promised_date_rec IS RECORD(
    po_promised_date DATE,
    po_quantity      NUMBER);

  TYPE t_promised_date_tab IS TABLE OF t_promised_date_rec INDEX BY BINARY_INTEGER;

  --------------------------------------------------------------------
  --  name:            xxwip_material_req_plan_pkg
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/09/2010  yuval tal   initial build
  --  1.1  30.10.13    yuval tal  CR-1085 WPI Shortage Report Add 2 specific Locators to the Inventory quantity supply
  --                              change cursor c (filter by locator id's)
  --------------------------------------------------------------------

  -----------------------------------------
  --- init_qty_sub_array
  -----------------------------------------
  PROCEDURE init_qty_sub_array IS
  
    CURSOR c IS
      SELECT onh.organization_id,
             onh.subinventory_code,
             onh.inventory_item_id,
             SUM(onh.transaction_quantity) qty
      --  INTO l_qty
        FROM mtl_onhand_quantities_detail onh,
             (SELECT DISTINCT t.flex_value, ',' || attribute2 || ',' loc_ids
                FROM fnd_flex_values_vl t, fnd_flex_value_sets vs
               WHERE t.flex_value_set_id = vs.flex_value_set_id
                 AND vs.flex_value_set_name =
                     'XXWIP_SUPPLY_SUBINVENTORY_LIST'
                 AND t.enabled_flag = 'Y') sub_inv
       WHERE onh.subinventory_code = sub_inv.flex_value
         AND (instr(sub_inv.loc_ids, onh.locator_id) > 0 OR
             REPLACE(sub_inv.loc_ids, ',') IS NULL)
       GROUP BY onh.organization_id,
                onh.subinventory_code,
                inventory_item_id;
  BEGIN
    FOR i IN c LOOP
    
      g_sub_inv_qty(i.organization_id || '-' || i.subinventory_code || '-' || i.inventory_item_id) := i.qty;
      /*  dbms_output.put_line(i.organization_id || '-' || i.subinventory_code || '-' ||
      i.inventory_item_id || '=' || i.qty);*/
    
    END LOOP;
  END;
  ----------------------------------------------------
  -- init_g_po_rec
  ------------------------------------------------------
  PROCEDURE init_g_po_array IS
  
    CURSOR c IS
    
      SELECT pl.item_id,
             ph.segment1,
             pll.promised_date,
             SUM(pll.quantity - nvl(pll.quantity_received, 0) -
                 nvl(pll.quantity_cancelled, 0)) tot_quantity
        FROM po_headers_all        ph,
             po_lines_all          pl,
             po_line_locations_all pll,
             po_distributions_all  pd
       WHERE ph.po_header_id = pl.po_header_id
         AND pl.po_line_id = pll.po_line_id
         AND pll.line_location_id = pd.line_location_id
         AND nvl(pll.closed_code, 'OPEN') = 'OPEN'
         AND nvl(pll.cancel_flag, 'N') = 'N'
         AND pll.shipment_type IN ('BLANKET', 'STANDARD', 'PLANNED')
         AND nvl(ph.authorization_status, 'INCOMPLETE') = 'APPROVED'
         AND pd.destination_type_code = 'INVENTORY'
         AND pll.quantity - nvl(pll.quantity_received, 0) -
             nvl(pll.quantity_cancelled, 0) > 0
         AND pl.item_id IN
             (SELECT DISTINCT item_id FROM xxwip_material_req_planning) --p_item_id
       GROUP BY pl.item_id, pll.promised_date, ph.segment1
       ORDER BY (pll.promised_date);
  
  BEGIN
    g_po_rec .delete;
    OPEN c;
    FETCH c BULK COLLECT
      INTO g_po_rec;
  
    CLOSE c;
  
    /* FOR i IN g_po_rec.FIRST .. g_po_rec.LAST LOOP
    
      dbms_output.put_line(g_po_rec(i).po_number);
    
    END LOOP;*/
  
  END;

  -------------------------------------------------------------------
  -- get_postprocessing_lead_time
  -------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.11.13     yuval tal         initial
  -------------------------------------------------------------------

  FUNCTION get_postprocessing_lead_time(p_item_id NUMBER, p_org_id NUMBER)
    RETURN NUMBER IS
    l_lead_time NUMBER;
  BEGIN
    SELECT msib.postprocessing_lead_time
      INTO l_lead_time
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;
  
    RETURN l_lead_time;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END;

  -----------------------------------------
  -- get_po_quantity_from_array
  --------------------------------------------
  PROCEDURE get_po_quantity_from_array(p_item_id   NUMBER,
                                       p_qty       NUMBER,
                                       p_po_number OUT VARCHAR2,
                                       p_date      OUT DATE,
                                       p_po_qty    OUT NUMBER)
  
   IS
  BEGIN
    p_po_qty := 0;
    -- dbms_output.put_line('SIZE=' || g_po_rec.LAST);
    IF g_po_rec.last IS NOT NULL THEN
    
      FOR i IN 1 .. g_po_rec.last LOOP
      
        IF g_po_rec(i).po_quantity > 0 AND p_item_id = g_po_rec(i).item_id THEN
          p_po_qty := least(p_qty, g_po_rec(i).po_quantity);
          g_po_rec(i).po_quantity := g_po_rec(i).po_quantity - p_po_qty;
          p_date := g_po_rec(i).po_promised_date;
          p_po_number := g_po_rec(i).po_number;
          RETURN;
        ELSE
          p_po_qty := 0;
        END IF;
      
      END LOOP;
    END IF;
  
  END;
  -----------------------------------------------------------------------
  -- get_quantity_allocated
  --
  -- get quantity located in  inventory
  -----------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29.8.13     yuval tal         CR766 -add 'Machines' as default value for p_schedule_group in select
  --------------------------------------------------------------------

  FUNCTION get_quantity_allocated(p_item_id         NUMBER,
                                  p_organization_id NUMBER,
                                  p_schedule_group  VARCHAR2,
                                  p_quantity        NUMBER) RETURN NUMBER IS
    l_qty              NUMBER := 0;
    l_qty_tmp          NUMBER;
    l_quantity_demand  NUMBER := p_quantity;
    l_organization_id2 NUMBER := NULL;
    CURSOR c_sub4group(c_organization_id1 NUMBER,
                       c_organization_id2 NUMBER) IS
      SELECT g.organization_id,
             t.parent_flex_value_low group_ind,
             t.flex_value            sub_inventory
        FROM fnd_flex_values_vl  t,
             fnd_flex_value_sets vs,
             wip_schedule_groups g
       WHERE t.flex_value_set_id = vs.flex_value_set_id
         AND vs.flex_value_set_name = 'XXWIP_SUPPLY_SUBINVENTORY_LIST'
         AND t.enabled_flag = 'Y'
         AND g.organization_id IN (c_organization_id1, c_organization_id2) -- p_organization_id
            
         AND g.schedule_group_name = nvl(p_schedule_group, 'Machines') --cr766
         AND g.attribute1 = t.parent_flex_value_low
       ORDER BY to_number(nvl(t.attribute1, 999999999));
  
    -- AND t.parent_flex_value_low = 'A';
  BEGIN
    -- dbms_output.put_line('p_schedule_group='||p_schedule_group||' p_quantity='||p_quantity||' p_organization_id='||i.organization_id);
    IF p_organization_id = 735 THEN
      l_organization_id2 := 736;
    END IF;
  
    FOR i IN c_sub4group(p_organization_id, l_organization_id2) LOOP
      BEGIN
        IF l_quantity_demand > 0 AND
           g_sub_inv_qty(i.organization_id || '-' || i.sub_inventory || '-' ||
                         p_item_id) > 0 THEN
          --IF p_item_id = 13984 THEN
          dbms_output.put_line('p_quantity=' || p_quantity || ' /  ' ||
                               i.organization_id || '-' || i.sub_inventory || '-' ||
                               p_item_id || '=' ||
                               g_sub_inv_qty(i.organization_id || '-' ||
                                             i.sub_inventory || '-' ||
                                             p_item_id));
        
          --   END IF;
        
          l_qty_tmp := least(l_quantity_demand,
                             g_sub_inv_qty(i.organization_id || '-' ||
                                           i.sub_inventory || '-' ||
                                           p_item_id));
        
          l_quantity_demand := l_quantity_demand - l_qty_tmp;
          g_sub_inv_qty(i.organization_id || '-' || i.sub_inventory || '-' || p_item_id) := g_sub_inv_qty(i.organization_id || '-' ||
                                                                                                          i.sub_inventory || '-' ||
                                                                                                          p_item_id) -
                                                                                            l_qty_tmp;
        
          l_qty := l_qty + l_qty_tmp;
        
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END LOOP;
    /*  IF p_item_id = 13984 THEN
      dbms_output.put_line(l_qty);
    END IF;*/
    RETURN nvl(l_qty, 0);
  
  END;

  -----------------------------------------------------------
  -- get_po_quantity

  -- get available quantity from po
  -----------------------------------------------------------

  FUNCTION get_po_quantity(p_item_id NUMBER) RETURN NUMBER IS
  
    l_tmp NUMBER;
  BEGIN
    SELECT /*pl.item_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pll.ship_to_organization_id,*/
     SUM(pll.quantity - nvl(pll.quantity_received, 0) -
         nvl(pll.quantity_cancelled, 0)) tot_quantity
      INTO l_tmp
      FROM po_headers_all        ph,
           po_lines_all          pl,
           po_line_locations_all pll,
           po_distributions_all  pd
     WHERE ph.po_header_id = pl.po_header_id
       AND pl.po_line_id = pll.po_line_id
       AND pll.line_location_id = pd.line_location_id
       AND nvl(pll.closed_code, 'OPEN') = 'OPEN'
       AND nvl(pll.cancel_flag, 'N') = 'N'
       AND pll.shipment_type IN ('BLANKET', 'STANDARD', 'PLANNED')
       AND nvl(ph.authorization_status, 'INCOMPLETE') = 'APPROVED'
       AND pd.destination_type_code = 'INVENTORY'
       AND pll.quantity - nvl(pll.quantity_received, 0) -
           nvl(pll.quantity_cancelled, 0) > 0
       AND pl.item_id = p_item_id;
    -- AND pll.promised_date IS NOT NULL;
    -- GROUP BY pl.item_id
    RETURN nvl(l_tmp, 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END;

  ------------------------------------------------------------------------
  -- build

  -- fill temporary table with data
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29.8.13     yuval tal         CR766 -Change the report to include Jobs without Schedule Group value modify select add outer join
  --  1.1 30.10.13     yuval tal         CR1056- split  Promise Date and PO quantity columns
 --   1.2 17.06.14     yuval tal         CHG0032122 add AND sup.lookup_code IN (1,2,3,4,5) 
 --------------------------------------------------------------------
  PROCEDURE build(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    l_allocated_qty         NUMBER;
    l_qty_po                NUMBER;
    l_po                    VARCHAR2(50);
    l_qty                   NUMBER;
    l_date                  DATE;
    l_open_qty_left         NUMBER;
    l_note                  VARCHAR2(2000);
    l_sysdate               DATE;
    l_quantity_open_balance NUMBER;
    l_open_qty_left_orig    NUMBER;
  
    l_promised_date_tab t_promised_date_tab;
    l_inx               NUMBER;
    CURSOR c_qty /*(c_organization_id NUMBER, c_item_id NUMBER, c_schedule_group_name VARCHAR2)*/
    IS
      SELECT *
        FROM xxwip_material_req_planning t
      /*WHERE t.organization_id = c_organization_id                                                                                                                                                              AND t.inventory_item_id = c_item_id
      AND t.schedule_group_name = c_schedule_group_name*/
       ORDER BY t.inventory_item_id, t.date_required, t.wip_entity_id
         FOR UPDATE;
  
    CURSOR c_build IS
      SELECT bc.inventory_item_id,
             we.wip_entity_name job,
             we.wip_entity_id,
             mtp.organization_code,
             mtp.organization_id,
             typ.meaning job_type,
             stat.meaning status,
             ba.segment1 assembly,
             ba.description assembly_description,
             bc.segment1 component,
             bc.description component_description,
             wro.date_required,
             grp.schedule_group_name,
             sup.meaning supply_type,
             wro.supply_subinventory,
             wro.required_quantity - wro.quantity_issued quantity_open,
             xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                                bc.planning_make_buy_code) make_buy,
             dj.scheduled_completion_date,
             dj.quantity_completed,
             dj.start_quantity
      
        FROM mfg_lookups                stat,
             mfg_lookups                typ,
             mtl_system_items_b         ba,
             wip_discrete_jobs          dj,
             wip_entities               we,
             wip_requirement_operations wro,
             mtl_system_items_b         bc,
             mtl_parameters             mtp,
             wip_schedule_groups        grp,
             mfg_lookups                sup
       WHERE stat.lookup_type = 'WIP_JOB_STATUS'
         AND typ.lookup_type = 'WIP_DISCRETE_JOB'
         AND dj.job_type = typ.lookup_code
         AND dj.status_type = stat.lookup_code
         AND bc.inventory_item_id = wro.inventory_item_id
         AND bc.organization_id = wro.organization_id
         AND ba.inventory_item_id = dj.primary_item_id
         AND ba.organization_id = dj.organization_id
         AND wro.wip_entity_id = dj.wip_entity_id
         AND we.wip_entity_id = wro.wip_entity_id
         AND we.wip_entity_id = dj.wip_entity_id
         AND stat.lookup_code IN (1, 3)
         AND wro.required_quantity - wro.quantity_issued > 0
         AND mtp.organization_id = we.organization_id
         AND grp.schedule_group_id(+) = dj.schedule_group_id -- cr766
         AND sup.lookup_type = 'WIP_SUPPLY'
         AND sup.lookup_code = wro.wip_supply_type
         --AND sup.lookup_code IN (1, 2, 3)
         AND sup.lookup_code IN (1,2,3,4,5) -- CHG0032122
         AND NOT
              (dj.class_code = 'BADAS' AND grp.schedule_group_name = 'BADAS')
         AND dj.class_code != 'RFR';
    --  AND bc.segment1 = 'ASY-04008';
    --  AND we.wip_entity_name = '107802';
  
  BEGIN
  
    errbuf    := '';
    retcode   := 0;
    l_sysdate := SYSDATE;
    EXECUTE IMMEDIATE ('truncate TABLE xxobjt.XXWIP_MATERIAL_REQ_PLANNING');
    -- DELETE FROM xxwip_material_req_planning;
    COMMIT;
  
    FOR i IN c_build LOOP
    
      INSERT INTO xxwip_material_req_planning
        (inventory_item_id,
         job,
         wip_entity_id,
         organization_code,
         organization_id,
         job_type,
         status,
         assembly,
         assembly_description,
         component,
         component_description,
         date_required,
         schedule_group_name,
         supply_type,
         supply_subinventory,
         quantity_open,
         quantity_allocated,
         creation_date,
         make_buy,
         --   plan_group,
         scheduled_completion_date,
         quantity_completed,
         start_quantity)
      VALUES
        (i.inventory_item_id,
         i.job,
         i.wip_entity_id,
         i.organization_code,
         i.organization_id,
         i.job_type,
         i.status,
         i.assembly,
         i.assembly_description,
         i.component,
         i.component_description,
         i.date_required,
         i.schedule_group_name,
         i.supply_type,
         i.supply_subinventory,
         i.quantity_open,
         0,
         l_sysdate,
         i.make_buy,
         --g.group_name,
         i.scheduled_completion_date,
         i.quantity_completed,
         i.start_quantity);
    
    END LOOP;
    COMMIT;
  
    --- update allocated qty for item
    init_qty_sub_array;
    -- init po info
    init_g_po_array;
    -- FOR i IN c_item LOOP
    -- handle item line
  
    FOR j IN c_qty LOOP
      --
      l_allocated_qty := get_quantity_allocated(j.inventory_item_id,
                                                j.organization_id,
                                                j.schedule_group_name,
                                                j.quantity_open);
      l_qty_po        := xxwip_material_req_plan_pkg.get_po_quantity(j.inventory_item_id);
    
      IF l_allocated_qty > 0 OR l_qty_po > 0 THEN
      
        l_note                  := NULL;
        l_quantity_open_balance := j.quantity_open;
      
        IF l_allocated_qty > 0 THEN
          UPDATE xxwip_material_req_planning t
             SET t.quantity_allocated = least(l_allocated_qty,
                                              j.quantity_open)
           WHERE CURRENT OF c_qty;
          l_quantity_open_balance := j.quantity_open -
                                     least(l_allocated_qty, j.quantity_open);
          l_allocated_qty         := l_allocated_qty -
                                     least(l_allocated_qty, j.quantity_open);
          -- update
        
        END IF;
      
        -- check po qty balance
        IF l_quantity_open_balance > 0 AND l_qty_po > 0 THEN
          l_open_qty_left      := l_quantity_open_balance;
          l_open_qty_left_orig := l_open_qty_left; --j.quantity_open;
          l_note               := NULL;
          get_po_quantity_from_array(j.inventory_item_id,
                                     l_open_qty_left,
                                     l_po,
                                     l_date,
                                     l_qty);
        
          l_promised_date_tab.delete;
          --   l_promised_date_tab.extend(5);
          l_promised_date_tab(1).po_promised_date := NULL;
          l_promised_date_tab(1).po_quantity := NULL;
          l_promised_date_tab(2).po_promised_date := NULL;
          l_promised_date_tab(2).po_quantity := NULL;
          l_promised_date_tab(3).po_promised_date := NULL;
          l_promised_date_tab(3).po_quantity := NULL;
          l_promised_date_tab(4).po_promised_date := NULL;
          l_promised_date_tab(4).po_quantity := NULL;
          l_promised_date_tab(5).po_promised_date := NULL;
          l_promised_date_tab(5).po_quantity := NULL;
          --
        
          l_inx := 0;
          WHILE l_qty != 0 /*AND l_open_qty_left != 0*/
           LOOP
          
            l_open_qty_left := l_open_qty_left - l_qty;
            SELECT l_note || ' ' || l_po || ' - ' ||
                   decode(l_date, NULL, 'XX', to_char(l_date, 'DD/MM/YY')) ||
                   ' - ' || l_qty
              INTO l_note
              FROM dual;
          
            -- cr 1045
            l_inx := l_inx + 1;
            l_promised_date_tab(l_inx).po_promised_date := trunc(l_date) +
                                                           CASE l_date
                                                             WHEN NULL THEN
                                                              NULL
                                                             ELSE
                                                              get_postprocessing_lead_time(j.inventory_item_id,
                                                                                           j.organization_id)
                                                           END;
            l_promised_date_tab(l_inx).po_quantity := l_qty;
          
            --
            get_po_quantity_from_array(j.inventory_item_id,
                                       l_open_qty_left,
                                       l_po,
                                       l_date,
                                       l_qty);
          
          END LOOP;
        
          UPDATE xxwip_material_req_planning t
             SET t.quantity_po       = l_open_qty_left_orig -
                                       l_open_qty_left,
                 note                = ltrim(l_note),
                 t.promise_date1     = l_promised_date_tab(1)
                                       .po_promised_date,
                 t.promise_quantity1 = l_promised_date_tab(1).po_quantity,
                 t.promise_date2     = l_promised_date_tab(2)
                                       .po_promised_date,
                 t.promise_quantity2 = l_promised_date_tab(2).po_quantity,
                 t.promise_date3     = l_promised_date_tab(3)
                                       .po_promised_date,
                 t.promise_quantity3 = l_promised_date_tab(3).po_quantity,
                 t.promise_date4     = l_promised_date_tab(4)
                                       .po_promised_date,
                 t.promise_quantity4 = l_promised_date_tab(4).po_quantity,
                 t.promise_date5     = l_promised_date_tab(5)
                                       .po_promised_date,
                 t.promise_quantity5 = l_promised_date_tab(5).po_quantity
           WHERE CURRENT OF c_qty;
        
        END IF;
      
        -- END LOOP;
      END IF;
      -- COMMIT;
    END LOOP;
  
    COMMIT;
    -- END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'General exception - ' || substr(SQLERRM, 1, 250);
      retcode := 2;
  END;

END xxwip_material_req_plan_pkg;
/
