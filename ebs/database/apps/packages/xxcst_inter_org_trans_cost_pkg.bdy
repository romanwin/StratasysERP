CREATE OR REPLACE PACKAGE BODY xxcst_inter_org_trans_cost_pkg IS

  --------------------------------------------------------------------
  --  name:            XXCS_INTER_ORG_TRANSF_COST_PKG 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        The customization will be used for costing.
  --                   All Resin FG are manufactured in WRI inventory organization 
  --                   and upon completion moved to WPI inventory organization.
  --                   The FG movement is done using “Direct Inter-Organization Transfer” transaction type. 
  --                   While performing this transaction, the WRI Cost Elements are considered 
  --                   as MATERIAL cost element in WPI. This causes incorrect costing element value, 
  --                   when analyzing the resin inventory valuation and cogs. 
  --                   This custom will correct WPI Element value for all material that is moved 
  --                   between the organizations.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  --  1.2  10/09/2013  Vitaly            CR870 -- Average cost_type_id=2 was replaced with fnd_profile.value('XX_COST_TYPE') in get_item_element_cost
  -------------------------------------------------------------------- 

  -- c_num_of_days constant number := fnd_profile.value('XXCST_ORG_TRANSFER_COST_DAYS');

  --------------------------------------------------------------------
  --  name:            get_item_number 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Get item number by item_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_item_number(p_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_item VARCHAR2(40) := NULL;
  BEGIN
    SELECT segment1
      INTO l_item
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_item_id
       AND msi.organization_id = 91;
  
    RETURN l_item;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_on_hand_qty 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Get organization on hand qty of item
  --                   for asset subinventories
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_on_hand_qty(p_inventory_item_id  IN NUMBER,
                           p_to_organization_id IN NUMBER) RETURN NUMBER IS
  
    l_on_hand_qty NUMBER := NULL;
  
  BEGIN
    -- get current item OH QTY
    SELECT SUM(oh.transaction_quantity) on_hand_qty
      INTO l_on_hand_qty
      FROM mtl_onhand_quantities_detail oh, mtl_secondary_inventories ohsub
     WHERE oh.inventory_item_id = p_inventory_item_id -- 14167
       AND oh.organization_id = p_to_organization_id -- 90
       AND oh.organization_id = ohsub.organization_id
       AND oh.subinventory_code = ohsub.secondary_inventory_name
       AND ohsub.asset_inventory = 1;
  
    RETURN l_on_hand_qty;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_on_hand_qty;

  --------------------------------------------------------------------
  --  name:            get_item_element_cost 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Get item cost by organization and element             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_item_element_cost(p_inventory_item_id  IN NUMBER,
                                 p_to_organization_id IN NUMBER,
                                 p_cost_element_id    IN NUMBER)
    RETURN NUMBER IS
  
    l_item_cost NUMBER := NULL;
  BEGIN
  
    -- Get Current item Elements cost
    SELECT item_cost
      INTO l_item_cost
      FROM cst_item_cost_details cic
     WHERE cic.inventory_item_id = p_inventory_item_id
       AND cic.organization_id = p_to_organization_id
       AND cic.cost_type_id = fnd_profile.value('XX_COST_TYPE') ----2
       AND cic.cost_element_id = p_cost_element_id; -- 1,2,... 
  
    RETURN l_item_cost;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_item_element_cost;

  --------------------------------------------------------------------
  --  name:            get_trx_value_sum_to 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Get transaction value to organization by ellement          
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_trx_value_sum_to(p_inventory_item_id    IN NUMBER,
                                p_from_organization_id IN NUMBER,
                                p_to_organization_id   IN NUMBER,
                                p_trx_date             IN DATE,
                                p_start_date           IN DATE,
                                p_cost_element_id      IN NUMBER)
    RETURN NUMBER IS
  
    l_cost_element_id  NUMBER := 0;
    l_trx_value_sum_to NUMBER := 0;
  BEGIN
    -- total trx value that move to organization                                 
    SELECT mtla.cost_element_id,
           SUM(mtla.base_transaction_value) trx_value_sum_to
      INTO l_cost_element_id, l_trx_value_sum_to
      FROM mtl_material_transactions mtlt, mtl_transaction_accounts mtla
     WHERE mtlt.transaction_type_id = 3
       AND mtlt.transfer_organization_id = p_from_organization_id -- 92 <P1> 
       AND mtlt.organization_id = p_to_organization_id -- 90 <P2> 
       AND mtlt.transaction_quantity > 0
       AND nvl(mtlt.attribute4, 'N') = 'N'
       AND mtlt.transaction_date <= p_trx_date --    <P3>
       AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days -- now at dev it is 30 at prod will be 90
       AND mtla.transaction_id = mtlt.transaction_id
       AND mtla.accounting_line_type = 1
       AND mtlt.inventory_item_id = p_inventory_item_id -- from the select above 
       AND mtla.cost_element_id = p_cost_element_id
     GROUP BY mtla.cost_element_id;
  
    RETURN l_trx_value_sum_to;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_trx_value_sum_to;

  --------------------------------------------------------------------
  --  name:            get_trx_value_sum_from 
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Get transaction value from organization by ellement          
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_trx_value_sum_from(p_inventory_item_id    IN NUMBER,
                                  p_from_organization_id IN NUMBER,
                                  p_to_organization_id   IN NUMBER,
                                  p_trx_date             IN DATE,
                                  p_start_date           IN DATE,
                                  p_cost_element_id      IN NUMBER)
    RETURN NUMBER IS
  
    l_cost_element_id    NUMBER := 0;
    l_trx_value_sum_from NUMBER := 0;
  
  BEGIN
    -- total trx value that move from organization
    SELECT mtla.cost_element_id,
           SUM(mtla.base_transaction_value) trx_value_sum_from
      INTO l_cost_element_id, l_trx_value_sum_from
      FROM mtl_material_transactions mtlt, mtl_transaction_accounts mtla
     WHERE mtlt.transaction_type_id = 3
       AND mtlt.transfer_organization_id = p_to_organization_id -- 90 <P2>
       AND mtlt.organization_id = p_from_organization_id -- 92 <P1>
       AND mtlt.transaction_quantity < 0
       AND nvl(mtlt.attribute4, 'N') = 'N'
       AND mtlt.transaction_date <= p_trx_date --    < P3>
       AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days -- now at dev it is 30 at prod will be 90
       AND mtla.transaction_id = mtlt.transaction_id
       AND mtla.accounting_line_type = 1
       AND mtlt.inventory_item_id = p_inventory_item_id -- from the select above 
       AND mtla.cost_element_id = p_cost_element_id
     GROUP BY mtla.cost_element_id;
  
    RETURN l_trx_value_sum_from;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_trx_value_sum_from;

  --------------------------------------------------------------------
  --  name:            get_avg_cost_upd_by_element
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        function that calculate the new element cost 
  --                   see detaile design       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_avg_cost_upd_by_element(p_inventory_item_id    IN NUMBER,
                                       p_from_organization_id IN NUMBER,
                                       p_to_organization_id   IN NUMBER,
                                       p_trx_date             IN DATE,
                                       p_start_date           IN DATE,
                                       p_cost_element_id      IN NUMBER,
                                       p_trx_qty_sum_to       IN NUMBER,
                                       p_on_hand_qty          IN NUMBER)
    RETURN NUMBER IS
    l_on_hand_qty        NUMBER := 0;
    l_element_cost       NUMBER := 0;
    l_trx_value_sum_to   NUMBER := 0;
    l_trx_value_sum_from NUMBER := 0;
    l_a                  NUMBER := 0;
    l_b                  NUMBER := 0;
    l_c                  NUMBER := 0;
    l_d                  NUMBER := 0;
  BEGIN
  
    l_on_hand_qty := p_on_hand_qty;
    /*get_on_hand_qty (p_inventory_item_id,   -- i n
    p_to_organization_id); -- i n*/
  
    l_element_cost       := get_item_element_cost(p_inventory_item_id, -- i n
                                                  p_to_organization_id, -- i n
                                                  p_cost_element_id); -- i n
    l_trx_value_sum_to   := abs(get_trx_value_sum_to(p_inventory_item_id, -- i n
                                                     p_from_organization_id, -- i n
                                                     p_to_organization_id, -- i n
                                                     p_trx_date,
                                                     p_start_date, -- i d
                                                     p_cost_element_id)); -- i n
    l_trx_value_sum_from := abs(get_trx_value_sum_from(p_inventory_item_id, -- i n
                                                       p_from_organization_id, -- i n
                                                       p_to_organization_id, -- i n
                                                       p_trx_date,
                                                       p_start_date, -- i d
                                                       p_cost_element_id)); -- i n                                          
  
    fnd_file.put_line(fnd_file.log,
                      ' --- Cost element id    - ' || p_cost_element_id);
    fnd_file.put_line(fnd_file.log,
                      ' --- Element_cost       - ' || l_element_cost);
    fnd_file.put_line(fnd_file.log,
                      ' --- Trx value sum to   - ' || l_trx_value_sum_to);
    fnd_file.put_line(fnd_file.log,
                      ' --- Trx value sum from - ' || l_trx_value_sum_from);
  
    l_a := l_on_hand_qty * l_element_cost;
    l_b := l_trx_value_sum_to / p_trx_qty_sum_to;
  
    -- get the minimum value 
    IF l_on_hand_qty > p_trx_qty_sum_to THEN
      l_c := p_trx_qty_sum_to;
    ELSE
      l_c := l_on_hand_qty;
    END IF;
  
    l_d := l_trx_value_sum_from / p_trx_qty_sum_to;
    IF l_on_hand_qty <> 0 THEN
      RETURN(l_a - (l_b * l_c) + (l_c * l_d)) / l_on_hand_qty;
    ELSE
      RETURN l_d;
    END IF;
  END get_avg_cost_upd_by_element;

  --------------------------------------------------------------------
  --  name:            update_items_cost_single
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   15/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :            
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_items_cost_single(p_trx_date        IN DATE,
                                     p_account_ccid    IN NUMBER,
                                     p_item_id         IN NUMBER,
                                     p_organization_id IN NUMBER,
                                     p_material_cost   IN NUMBER,
                                     p_matovh_cost     IN NUMBER,
                                     p_res_cost        IN NUMBER,
                                     p_outside_p_cost  IN NUMBER,
                                     p_overhead_cost   IN NUMBER,
                                     p_trx_qty         IN NUMBER,
                                     p_error_code      OUT NUMBER,
                                     p_error_desc      OUT VARCHAR2) IS
  
    TYPE t_csr_items_params_rec IS RECORD(
      inventory_item_id          NUMBER,
      organization_id            NUMBER,
      primary_uom_code           VARCHAR2(3),
      primary_cost_method        NUMBER,
      default_cost_group_id      NUMBER,
      revision_qty_control_code  NUMBER,
      material_account           NUMBER,
      material_overhead_account  NUMBER,
      resource_account           NUMBER,
      outside_processing_account NUMBER,
      overhead_account           NUMBER);
  
    cur_inv_item_r      t_csr_items_params_rec;
    cur_inv_item_mis_r  t_csr_items_params_rec;
    l_interfaced_txn_id mtl_transactions_interface.transaction_interface_id%TYPE;
  
    l_stage                      VARCHAR2(25);
    l_source_id                  NUMBER := NULL;
    l_transaction_type_id        NUMBER;
    l_transaction_action_id      NUMBER;
    l_transaction_source_type_id NUMBER;
    l_prim_trx_quantity          NUMBER;
    l_user_id                    NUMBER;
    l_material_element           NUMBER;
    l_material_overhead_element  NUMBER;
    l_resource_element           NUMBER;
    l_revision                   VARCHAR2(3);
  
    l_outside_element  NUMBER := NULL;
    l_overhead_element NUMBER := NULL;
  BEGIN
    l_user_id := fnd_profile.value('USER_ID');
    -- SELECT FROM cst_cost_groups
    BEGIN
      SELECT transaction_type_id,
             transaction_action_id,
             transaction_source_type_id
        INTO l_transaction_type_id,
             l_transaction_action_id,
             l_transaction_source_type_id
        FROM mtl_transaction_types mtt
       WHERE mtt.transaction_type_name = 'Average cost update';
    EXCEPTION
      WHEN OTHERS THEN
        l_transaction_type_id        := NULL;
        l_transaction_action_id      := NULL;
        l_transaction_source_type_id := NULL;
    END;
    ---- 
    BEGIN
      SELECT cost_element_id
        INTO l_material_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material';
    EXCEPTION
      WHEN OTHERS THEN
        l_material_element := NULL;
    END;
    ----
    BEGIN
      SELECT cost_element_id
        INTO l_material_overhead_element
        FROM cst_cost_elements
       WHERE cost_element = 'Material Overhead';
    EXCEPTION
      WHEN OTHERS THEN
        l_material_overhead_element := NULL;
    END;
    ---- 
    BEGIN
      SELECT cost_element_id
        INTO l_resource_element
        FROM cst_cost_elements
       WHERE cost_element = 'Resource';
    EXCEPTION
      WHEN OTHERS THEN
        l_resource_element := NULL;
    END;
    ----
    BEGIN
      SELECT cost_element_id
        INTO l_outside_element
        FROM cst_cost_elements
       WHERE cost_element = 'Outside Processing';
    EXCEPTION
      WHEN OTHERS THEN
        l_outside_element := NULL;
    END;
    BEGIN
      SELECT cost_element_id
        INTO l_overhead_element
        FROM cst_cost_elements
       WHERE cost_element = 'Overhead';
    EXCEPTION
      WHEN OTHERS THEN
        l_overhead_element := NULL;
    END;
  
    ---------------------------
    BEGIN
      l_stage             := NULL;
      cur_inv_item_r      := cur_inv_item_mis_r;
      l_source_id         := NULL;
      l_revision          := NULL;
      l_prim_trx_quantity := NULL;
      ---------------------------
      l_stage := 'Item';
      ---------------------------
      SELECT msi.inventory_item_id,
             msi.organization_id,
             primary_uom_code,
             mp.primary_cost_method,
             mp.default_cost_group_id,
             msi.revision_qty_control_code,
             mp.material_account,
             mp.material_overhead_account,
             mp.resource_account,
             mp.outside_processing_account,
             mp.overhead_account
        INTO cur_inv_item_r
        FROM mtl_system_items_b msi, mtl_parameters mp
       WHERE msi.organization_id = mp.organization_id
         AND msi.inventory_item_id = p_item_id
         AND msi.organization_id = p_organization_id;
    
      ---------------------------
      l_stage := 'Revision';
      ---------------------------
      BEGIN
        SELECT MAX(revision)
          INTO l_revision
          FROM mtl_item_revisions_b
         WHERE inventory_item_id = cur_inv_item_r.inventory_item_id
           AND organization_id = cur_inv_item_r.organization_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_revision := NULL;
      END;
      --------------------------- 
      l_stage := 'Check On-Hand';
      ---------------------------
      SELECT nvl(SUM(primary_transaction_quantity), 0)
        INTO l_prim_trx_quantity
        FROM mtl_onhand_quantities_detail
       WHERE inventory_item_id = cur_inv_item_r.inventory_item_id
         AND organization_id = cur_inv_item_r.organization_id;
    
      IF nvl(p_trx_qty, 0) != 0 THEN
        l_prim_trx_quantity := p_trx_qty;
      END IF;
      ---------------------------
      l_stage := 'Insert';
      --------------------------- 
      SELECT inv.mtl_material_transactions_s.nextval
        INTO l_interfaced_txn_id
        FROM dual;
    
      INSERT INTO mtl_transactions_interface
        (transaction_interface_id,
         inventory_item_id,
         organization_id,
         revision,
         transaction_type_id,
         transaction_action_id,
         transaction_source_type_id,
         transaction_source_id,
         transaction_quantity,
         transaction_uom,
         primary_quantity,
         transaction_date,
         cost_group_id,
         cost_type_id,
         new_average_cost,
         source_line_id,
         source_header_id,
         process_flag,
         transaction_mode,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login,
         source_code,
         material_account,
         material_overhead_account,
         resource_account,
         outside_processing_account,
         overhead_account)
      VALUES
        (l_interfaced_txn_id,
         cur_inv_item_r.inventory_item_id,
         cur_inv_item_r.organization_id,
         l_revision,
         l_transaction_type_id,
         l_transaction_action_id,
         l_transaction_source_type_id,
         l_source_id,
         0,
         cur_inv_item_r.primary_uom_code,
         l_prim_trx_quantity,
         --to_date(trx_date, 'DD/MM/YYYY'), --'31/08/2009'
         p_trx_date,
         cur_inv_item_r.default_cost_group_id,
         cur_inv_item_r.primary_cost_method,
         (nvl(p_material_cost, 0) + nvl(p_matovh_cost, 0) +
         nvl(p_res_cost, 0) + nvl(p_outside_p_cost, 0) +
         nvl(p_overhead_cost, 0)),
         1, --> ?????
         1, --> ?????
         '1', --> ?????
         '3', --> ?????
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         'COST_CORRECTION',
         p_account_ccid, --cur_inv_item.material_account,
         p_account_ccid, --cur_inv_item.material_overhead_account,
         p_account_ccid, --cur_inv_item.resource_account,
         p_account_ccid, --cur_inv_item.outside_processing_account,
         p_account_ccid); --cur_inv_item.overhead_account);
    
      ---------------------------
      l_stage := 'Material';
      ---------------------------
      INSERT INTO mtl_txn_cost_det_interface
        (transaction_interface_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         organization_id,
         cost_element_id,
         level_type,
         new_average_cost)
      VALUES
        (l_interfaced_txn_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         cur_inv_item_r.organization_id,
         l_material_element,
         1,
         nvl(p_material_cost, 0));
    
      --------------------------- 
      l_stage := 'Material Overhead';
      ---------------------------
      INSERT INTO mtl_txn_cost_det_interface
        (transaction_interface_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         organization_id,
         cost_element_id,
         level_type,
         new_average_cost)
      VALUES
        (l_interfaced_txn_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         cur_inv_item_r.organization_id,
         l_material_overhead_element,
         1,
         nvl(p_matovh_cost, 0));
    
      ---------------------------
      l_stage := 'Resource';
      ---------------------------     
      INSERT INTO mtl_txn_cost_det_interface
        (transaction_interface_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         organization_id,
         cost_element_id,
         level_type,
         new_average_cost)
      VALUES
        (l_interfaced_txn_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         cur_inv_item_r.organization_id,
         l_resource_element,
         1,
         nvl(p_res_cost, 0));
    
      ---------------------------
      l_stage := 'overheade';
      ---------------------------
      INSERT INTO mtl_txn_cost_det_interface
        (transaction_interface_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         organization_id,
         cost_element_id,
         level_type,
         new_average_cost)
      VALUES
        (l_interfaced_txn_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         cur_inv_item_r.organization_id,
         l_overhead_element,
         1,
         nvl(p_overhead_cost, 0));
    
      ---------------------------
      l_stage := 'Outside';
      ---------------------------    
      INSERT INTO mtl_txn_cost_det_interface
        (transaction_interface_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         organization_id,
         cost_element_id,
         level_type,
         new_average_cost)
      VALUES
        (l_interfaced_txn_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         trunc(SYSDATE), --'31/08/2009'
         l_user_id,
         -1,
         cur_inv_item_r.organization_id,
         l_outside_element,
         1,
         nvl(p_outside_p_cost, 0));
    
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        p_error_desc := l_stage || ': ' || substr(SQLERRM, 1, 300);
        p_error_code := 1;
    END;
    COMMIT;
  END update_items_cost_single;

  --------------------------------------------------------------------
  --  name:            run_Process_trx_interface
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Main procedure to update item             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE run_process_trx_interface(p_error_code IN OUT NUMBER,
                                      p_error_desc IN OUT VARCHAR2) IS
  
    l_request_id   NUMBER := NULL;
    l_print_option BOOLEAN;
    l_printer_name VARCHAR2(150) := NULL;
    l_error_flag   BOOLEAN := FALSE;
    l_phase        VARCHAR2(100);
    l_status       VARCHAR2(100);
    l_dev_phase    VARCHAR2(100);
    l_dev_status   VARCHAR2(100);
    l_message      VARCHAR2(100);
    l_return_bool  BOOLEAN;
  
  BEGIN
    --
    -- Set printer and print option
    --
    l_printer_name := fnd_profile.value('PRINTER');
    l_print_option := fnd_request.set_print_options(l_printer_name,
                                                    '',
                                                    '0',
                                                    TRUE,
                                                    'N');
  
    IF l_print_option = TRUE THEN
      --l_request_id := null;
      l_request_id := fnd_request.submit_request(application => 'INV',
                                                 program     => 'INCTCM', --Process transaction interface
                                                 description => NULL,
                                                 start_time  => NULL,
                                                 sub_request => FALSE);
    
      IF l_request_id = 0 THEN
      
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          '------------------ Failed to run program  ---------------------');
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------------------------');
        p_error_desc := SQLERRM;
        p_error_code := SQLCODE;
      ELSE
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          '------------------ Success to run program  --------------------');
        fnd_file.put_line(fnd_file.log,
                          '---------------------------------------------------------------');
        -- must commit the request
        COMMIT;
      
        -- loop to wait until the request finished
        l_error_flag := FALSE;
        l_phase      := NULL;
        l_status     := NULL;
        l_dev_phase  := NULL;
        l_dev_status := NULL;
        l_message    := NULL;
      
        WHILE l_error_flag = FALSE LOOP
          l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                           5,
                                                           86400,
                                                           l_phase,
                                                           l_status,
                                                           l_dev_phase,
                                                           l_dev_status,
                                                           l_message);
        
          IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
            l_error_flag := TRUE;
          ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
            l_error_flag := TRUE;
            fnd_file.put_line(fnd_file.log,
                              '---------------------------------------------------------------');
            fnd_file.put_line(fnd_file.log,
                              'Request finished in error or warrning. try again later. - ' ||
                              l_message);
            fnd_file.put_line(fnd_file.log,
                              '---------------------------------------------------------------');
          END IF; -- dev_phase
        END LOOP; -- l_error_flag
      
        ---------- add update 
      END IF; -- l_request_id
    ELSE
      --
      -- Didn't find printer
      --
      fnd_file.put_line(fnd_file.log,
                        '---------------------------------------------------------------');
      fnd_file.put_line(fnd_file.log,
                        '------------------ Can not Find printer -----------------------');
      fnd_file.put_line(fnd_file.log,
                        '---------------------------------------------------------------');
      p_error_desc := SQLERRM;
      p_error_code := SQLCODE;
    END IF; -- l_print_option
  END run_process_trx_interface;

  --------------------------------------------------------------------
  --  name:            update_material_trx_att4
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Main procedure to update item             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE update_material_trx_att4(p_from_organization_id IN NUMBER, -- P1
                                     p_to_organization_id   IN NUMBER, -- P2 
                                     p_trx_date             IN DATE,
                                     p_start_date           IN DATE, -- P3
                                     p_item_id              IN NUMBER,
                                     p_error_code           OUT NUMBER,
                                     p_error_desc           OUT VARCHAR2) IS
  
    --l_num_of_days number := 0;
    l_item VARCHAR2(40) := NULL;
  BEGIN
    --l_num_of_days := fnd_profile.value('XXCST_ORG_TRANSFER_COST_DAYS');
  
    UPDATE mtl_material_transactions mtlt
       SET mtlt.attribute4 = 'Y'
     WHERE mtlt.transaction_type_id = 3
       AND mtlt.transfer_organization_id = p_from_organization_id -- <P1> 92
       AND mtlt.organization_id = p_to_organization_id -- <P2> 90
       AND mtlt.transaction_quantity > 0
       AND nvl(mtlt.attribute4, 'N') = 'N'
       AND mtlt.transaction_date <= p_trx_date -- <P3>
       AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days 
       AND mtlt.inventory_item_id = p_item_id -- <INVENTORY_ITEM_ID>
       AND mtlt.costed_flag IS NULL;
  
    UPDATE mtl_material_transactions mtlt
       SET mtlt.attribute4 = 'Y'
     WHERE mtlt.transaction_type_id = 3
       AND mtlt.transfer_organization_id = p_to_organization_id -- <P2> 90
       AND mtlt.organization_id = p_from_organization_id -- <P1> 92
       AND mtlt.transaction_quantity < 0
       AND nvl(mtlt.attribute4, 'N') = 'N'
       AND mtlt.transaction_date <= p_trx_date -- <P3>
       AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days 
       AND mtlt.inventory_item_id = p_item_id -- <INVENTORY_ITEM_ID>
       AND mtlt.costed_flag IS NULL;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      l_item := get_item_number(p_item_id);
      fnd_file.put_line(fnd_file.log,
                        ' Update failed for item - ' || l_item);
      p_error_code := 1;
      p_error_desc := '2 update_material_trx_att4 - failed - ' ||
                      substr(SQLERRM, 1, 250);
  END update_material_trx_att4;

  --------------------------------------------------------------------
  --  name:            update_material_trx_att4_old
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Main procedure to update item             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE update_material_trx_att4_old(p_from_organization_id IN NUMBER, -- P1
                                         p_to_organization_id   IN NUMBER, -- P2 
                                         p_trx_date             IN DATE,
                                         p_start_date           IN DATE, -- P3
                                         p_item_id              IN NUMBER,
                                         p_error_code           OUT NUMBER,
                                         p_error_desc           OUT VARCHAR2) IS
  
    CURSOR get_items_to_fix_c(p_from_organization_id IN NUMBER,
                              p_to_organization_id   IN NUMBER,
                              p_trx_date             IN DATE,
                              p_start_date           IN DATE) IS
      SELECT mtlt.inventory_item_id,
             SUM(mtlt.transaction_quantity) trx_qty_sum_to
        FROM mtl_material_transactions mtlt
       WHERE mtlt.transaction_type_id = 3
         AND mtlt.transfer_organization_id = p_from_organization_id -- 92 -- from organization
         AND mtlt.organization_id = p_to_organization_id -- 90 -- to   organization
         AND mtlt.transaction_quantity > 0
         AND nvl(mtlt.attribute4, 'N') = 'N'
         AND mtlt.transaction_date <= p_trx_date -- <P3>
         AND mtlt.transaction_date >= p_start_date --sysdate - p_num_of_days -- now at dev it is 30 at prod will be 90 
         AND mtlt.costed_flag IS NULL
       GROUP BY mtlt.inventory_item_id;
  
    --l_num_of_days number := 0;
    l_item VARCHAR2(40) := NULL;
  BEGIN
    --l_num_of_days := fnd_profile.value('XXCST_ORG_TRANSFER_COST_DAYS');
    IF p_item_id IS NULL THEN
      -- to ask hod if we need this
      fnd_file.put_line(fnd_file.log,
                        '---------------------------------------------------------------');
      fnd_file.put_line(fnd_file.log,
                        '-------------------- update_material_trx_att4 -----------------');
      FOR get_items_to_fix_r IN get_items_to_fix_c(p_from_organization_id,
                                                   p_to_organization_id,
                                                   p_trx_date,
                                                   p_start_date) LOOP
        BEGIN
          UPDATE mtl_material_transactions mtlt
             SET mtlt.attribute4 = 'Y'
           WHERE mtlt.transaction_type_id = 3
             AND mtlt.transfer_organization_id = p_from_organization_id -- <P1> 92
             AND mtlt.organization_id = p_to_organization_id -- <P2> 90
             AND mtlt.transaction_quantity > 0
             AND nvl(mtlt.attribute4, 'N') = 'N'
             AND mtlt.transaction_date <= p_trx_date -- <P3>
             AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days
             AND mtlt.inventory_item_id =
                 get_items_to_fix_r.inventory_item_id -- <INVENTORY_ITEM_ID>
             AND mtlt.costed_flag IS NULL;
        
          UPDATE mtl_material_transactions mtlt
             SET mtlt.attribute4 = 'Y'
           WHERE mtlt.transaction_type_id = 3
             AND mtlt.transfer_organization_id = p_to_organization_id -- <P2> 90
             AND mtlt.organization_id = p_from_organization_id -- <P1> 92
             AND mtlt.transaction_quantity < 0
             AND nvl(mtlt.attribute4, 'N') = 'N'
             AND mtlt.transaction_date <= p_trx_date -- <P3>
             AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days
             AND mtlt.inventory_item_id =
                 get_items_to_fix_r.inventory_item_id -- <INVENTORY_ITEM_ID>
             AND mtlt.costed_flag IS NULL;
        
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            l_item := get_item_number(get_items_to_fix_r.inventory_item_id);
            fnd_file.put_line(fnd_file.log,
                              ' Udate failed for item - ' || l_item);
            p_error_code := 1;
            p_error_desc := '1 update_material_trx_att4 - failed - ' ||
                            substr(SQLERRM, 1, 250);
            ROLLBACK;
        END;
      END LOOP;
      fnd_file.put_line(fnd_file.log,
                        '---------------------------------------------------------------');
    ELSE
    
      UPDATE mtl_material_transactions mtlt
         SET mtlt.attribute4 = 'Y'
       WHERE mtlt.transaction_type_id = 3
         AND mtlt.transfer_organization_id = p_from_organization_id -- <P1> 92
         AND mtlt.organization_id = p_to_organization_id -- <P2> 90
         AND mtlt.transaction_quantity > 0
         AND nvl(mtlt.attribute4, 'N') = 'N'
         AND mtlt.transaction_date <= p_trx_date -- <P3>
         AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days
         AND mtlt.inventory_item_id = p_item_id -- <INVENTORY_ITEM_ID>
         AND mtlt.costed_flag IS NULL;
    
      UPDATE mtl_material_transactions mtlt
         SET mtlt.attribute4 = 'Y'
       WHERE mtlt.transaction_type_id = 3
         AND mtlt.transfer_organization_id = p_to_organization_id -- <P2> 90
         AND mtlt.organization_id = p_from_organization_id -- <P1> 92
         AND mtlt.transaction_quantity < 0
         AND nvl(mtlt.attribute4, 'N') = 'N'
         AND mtlt.transaction_date <= p_trx_date -- <P3>
         AND mtlt.transaction_date >= p_start_date --sysdate - c_num_of_days
         AND mtlt.inventory_item_id = p_item_id -- <INVENTORY_ITEM_ID>
         AND mtlt.costed_flag IS NULL;
    
      COMMIT;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_item := get_item_number(p_item_id);
      fnd_file.put_line(fnd_file.log,
                        ' Udate failed for item - ' || l_item);
      p_error_code := 1;
      p_error_desc := '2 update_material_trx_att4 - failed - ' ||
                      substr(SQLERRM, 1, 250);
    
  END update_material_trx_att4_old;

  --------------------------------------------------------------------
  --  name:            main
  --  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2010 2:22:33 PM
  --------------------------------------------------------------------
  --  purpose :        Main procedure to update item             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE main(errbuf                 OUT VARCHAR2,
                 retcode                OUT VARCHAR2,
                 p_from_organization_id IN NUMBER, -- P1
                 p_to_organization_id   IN NUMBER, -- P2 
                 p_trx_date             IN VARCHAR2, -- P3
                 p_gl_account           IN NUMBER, -- P4
                 p_start_date           IN VARCHAR2 -- P5 
                 ) IS
  
    CURSOR get_items_to_fix_c(p_from_organization_id IN NUMBER,
                              p_to_organization_id   IN NUMBER,
                              p_trx_date             IN DATE,
                              p_start_date           IN DATE) IS
      SELECT mtlt.inventory_item_id,
             SUM(mtlt.transaction_quantity) trx_qty_sum_to
        FROM mtl_material_transactions mtlt
       WHERE mtlt.transaction_type_id = 3
         AND mtlt.transfer_organization_id = p_from_organization_id -- 92 -- from organization
         AND mtlt.organization_id = p_to_organization_id -- 90 -- to   organization
         AND mtlt.transaction_quantity > 0
         AND nvl(mtlt.attribute4, 'N') = 'N'
         AND mtlt.transaction_date <= p_trx_date -- <P3>
         AND mtlt.transaction_date >= p_start_date --sysdate - p_num_of_days -- now at dev it is 30 at prod will be 90 
         AND mtlt.costed_flag IS NULL
       GROUP BY mtlt.inventory_item_id;
  
    l_on_hand_qty            NUMBER := 0;
    l_material_cost          NUMBER := 0;
    l_material_overhead_cost NUMBER := 0;
    l_resource_cost          NUMBER := 0;
    l_outside_process_cost   NUMBER := 0;
    l_overhead_cost          NUMBER := 0;
    l_error_code             NUMBER := 0;
    l_error_desc             VARCHAR2(500) := NULL;
    l_item                   VARCHAR2(40) := NULL;
    l_trx_date               DATE := NULL;
    l_start_date             DATE := NULL;
  
  BEGIN
    l_trx_date   := to_date(p_trx_date, 'YYYY/MM/DD HH24:MI:SS');
    l_start_date := to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
  
    FOR get_items_to_fix_r IN get_items_to_fix_c(p_from_organization_id,
                                                 p_to_organization_id,
                                                 l_trx_date,
                                                 l_start_date) LOOP
    
      --------- For Debug
      l_item := get_item_number(get_items_to_fix_r.inventory_item_id);
      fnd_file.put_line(fnd_file.log, 'Item  - ' || l_item);
      /*
      element_id
      l_on_hand_qty
      l_element_cost
      l_trx_value_sum_to
      l_trx_value_sum_from
      l_material_cost
      */
      --------- End Debug
    
      l_on_hand_qty := get_on_hand_qty(get_items_to_fix_r.inventory_item_id, -- i n
                                       p_to_organization_id); -- i n
      fnd_file.put_line(fnd_file.log, 'Onhand qty  - ' || l_on_hand_qty);
    
      -- get Material element cost -> cost_element_id = 1 
      l_material_cost := get_avg_cost_upd_by_element(p_inventory_item_id    => get_items_to_fix_r.inventory_item_id, -- i n
                                                     p_from_organization_id => p_from_organization_id, -- i n 
                                                     p_to_organization_id   => p_to_organization_id, -- i n
                                                     p_trx_date             => l_trx_date,
                                                     p_start_date           => l_start_date, -- i d
                                                     p_cost_element_id      => 1, -- i n
                                                     p_trx_qty_sum_to       => get_items_to_fix_r.trx_qty_sum_to, -- i n
                                                     p_on_hand_qty          => l_on_hand_qty); -- i n
      fnd_file.put_line(fnd_file.log,
                        'Material cost  - ' || l_material_cost);
      -- get Material Overhaed element cost -> cost_element_id = 2                           
      l_material_overhead_cost := get_avg_cost_upd_by_element(p_inventory_item_id    => get_items_to_fix_r.inventory_item_id, -- i n
                                                              p_from_organization_id => p_from_organization_id, -- i n 
                                                              p_to_organization_id   => p_to_organization_id, -- i n
                                                              p_trx_date             => l_trx_date,
                                                              p_start_date           => l_start_date, -- i d
                                                              p_cost_element_id      => 2, -- i n
                                                              p_trx_qty_sum_to       => get_items_to_fix_r.trx_qty_sum_to, -- i n
                                                              p_on_hand_qty          => l_on_hand_qty); -- i n 
      fnd_file.put_line(fnd_file.log,
                        'Material overhead cost  - ' ||
                        l_material_overhead_cost);
      -- get Resource element cost -> cost_element_id = 3                           
      l_resource_cost := get_avg_cost_upd_by_element(p_inventory_item_id    => get_items_to_fix_r.inventory_item_id, -- i n
                                                     p_from_organization_id => p_from_organization_id, -- i n 
                                                     p_to_organization_id   => p_to_organization_id, -- i n
                                                     p_trx_date             => l_trx_date,
                                                     p_start_date           => l_start_date, -- i d
                                                     p_cost_element_id      => 3, -- i n
                                                     p_trx_qty_sum_to       => get_items_to_fix_r.trx_qty_sum_to, -- i n
                                                     p_on_hand_qty          => l_on_hand_qty); -- i n 
      fnd_file.put_line(fnd_file.log,
                        'Resource cost  - ' || l_resource_cost);
      -- get Outside Processing element cost -> cost_element_id = 4                           
      l_outside_process_cost := get_avg_cost_upd_by_element(p_inventory_item_id    => get_items_to_fix_r.inventory_item_id, -- i n
                                                            p_from_organization_id => p_from_organization_id, -- i n 
                                                            p_to_organization_id   => p_to_organization_id, -- i n
                                                            p_trx_date             => l_trx_date,
                                                            p_start_date           => l_start_date, -- i d
                                                            p_cost_element_id      => 4, -- i n
                                                            p_trx_qty_sum_to       => get_items_to_fix_r.trx_qty_sum_to, -- i n
                                                            p_on_hand_qty          => l_on_hand_qty); -- i n  
      fnd_file.put_line(fnd_file.log,
                        'Outside process cost  - ' ||
                        l_outside_process_cost);
      -- get Overhead element cost -> cost_element_id = 5                           
      l_overhead_cost := get_avg_cost_upd_by_element(p_inventory_item_id    => get_items_to_fix_r.inventory_item_id, -- i n
                                                     p_from_organization_id => p_from_organization_id, -- i n 
                                                     p_to_organization_id   => p_to_organization_id, -- i n
                                                     p_trx_date             => l_trx_date,
                                                     p_start_date           => l_start_date, -- i d
                                                     p_cost_element_id      => 5, -- i n
                                                     p_trx_qty_sum_to       => get_items_to_fix_r.trx_qty_sum_to, -- i n
                                                     p_on_hand_qty          => l_on_hand_qty); -- i n                                                                                                                          
      fnd_file.put_line(fnd_file.log,
                        'Overhead cost  - ' || l_overhead_cost);
      -- insert rows to interface
      update_items_cost_single(p_trx_date        => l_trx_date, -- i d
                               p_account_ccid    => p_gl_account, -- i n 
                               p_item_id         => get_items_to_fix_r.inventory_item_id, -- i n
                               p_organization_id => p_to_organization_id, -- i n
                               p_material_cost   => l_material_cost, -- i n
                               p_matovh_cost     => l_material_overhead_cost, -- i n
                               p_res_cost        => l_resource_cost, -- i n
                               p_outside_p_cost  => l_outside_process_cost, -- i n
                               p_overhead_cost   => l_overhead_cost, -- i n
                               p_trx_qty         => l_on_hand_qty, -- i n
                               p_error_code      => l_error_code, -- o n
                               p_error_desc      => l_error_desc); -- o v                         
    
      IF l_error_code <> 0 THEN
        --l_item  := get_item_number (get_items_to_fix_r.inventory_item_id);
        fnd_file.put_line(fnd_file.log,
                          'Failed to insert row to interface - item ' ||
                          l_item || ' - ' || l_error_desc);
        errbuf  := 'Progarm finished with error';
        retcode := 1;
      ELSE
      
        -- run process_trx_interface
        l_error_desc := NULL;
        l_error_code := 0;
        run_process_trx_interface(p_error_code => l_error_code,
                                  p_error_desc => l_error_desc);
      
        IF l_error_code = 0 THEN
          l_error_desc := NULL;
          l_error_code := 0;
          update_material_trx_att4(p_from_organization_id => p_from_organization_id, -- i n -- P1
                                   p_to_organization_id   => p_to_organization_id, -- i n -- P2 
                                   p_trx_date             => l_trx_date,
                                   p_start_date           => l_start_date, -- i n -- P3
                                   p_item_id              => get_items_to_fix_r.inventory_item_id, -- i n      
                                   p_error_code           => l_error_code, -- o n
                                   p_error_desc           => l_error_desc -- o v
                                   );
          IF l_error_code <> 0 THEN
            fnd_file.put_line(fnd_file.log,
                              'Failed Update material transaction attribute4 - ' ||
                              l_error_desc);
            errbuf  := 'Progarm finished with error';
            retcode := 1;
          END IF;
        ELSE
          fnd_file.put_line(fnd_file.log,
                            'Failed run process trx interface - ' ||
                            l_error_desc);
          errbuf  := 'Progarm finished with error';
          retcode := 1;
        END IF;
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Main - general exception - ' || substr(SQLERRM, 1, 249);
      retcode := 1;
  END main;

END xxcst_inter_org_trans_cost_pkg;
/
