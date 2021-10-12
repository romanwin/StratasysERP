CREATE OR REPLACE PACKAGE BODY xxinv_onhand_asofdate_pkg IS

  --------------------------------------------------------------------
  --  name:              xxinv_onhand_asofdate_pkg
  --  create by:         
  --  Revision:          1.0
  --  creation date:     
  --------------------------------------------------------------------
  --  purpose :          
  -----------------------------------------------------------------
  --  ver  date          name         desc
  --  1.0  xxxxxx        xxxxx        initial build
  --  1.1  10/09/2013    Vitaly       CR870 -- Average cost_type_id=2 was replaced with fnd_profile.value('XX_COST_TYPE') in calc_onhand_asofdate function
  ------------------------------------------------------
  FUNCTION pl_to_sql(p_asofdate                DATE,
                     p_subinventory            VARCHAR2,
                     p_item_number             VARCHAR2,
                     p_organization_code       VARCHAR2,
                     p_quantity                NUMBER,
                     p_cost_type               VARCHAR2,
                     p_material_cost           NUMBER,
                     p_material_overhead_cost  NUMBER,
                     p_resource_cost           NUMBER,
                     p_outside_processing_cost NUMBER,
                     p_overhead_cost           NUMBER,
                     p_item_cost               NUMBER,
                     p_item_decription         VARCHAR2,
                     p_organization_id         NUMBER,
                     p_inventory_item_id       NUMBER,
                     p_category_id             NUMBER,
                     p_cost_type_id            NUMBER,
                     p_qty_source              NUMBER)
    RETURN xxinv_onhand_asofdate_type IS
    l_onhand_asofdate_rec xxinv_onhand_asofdate_type;
  BEGIN
    -- initialize the object
    l_onhand_asofdate_rec                         := xxinv_onhand_asofdate_type(NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL,
                                                                                NULL);
    l_onhand_asofdate_rec.asofdate                := p_asofdate;
    l_onhand_asofdate_rec.subinventory            := p_subinventory;
    l_onhand_asofdate_rec.item_number             := p_item_number;
    l_onhand_asofdate_rec.organization_code       := p_organization_code;
    l_onhand_asofdate_rec.quantity                := p_quantity;
    l_onhand_asofdate_rec.cost_type               := p_cost_type;
    l_onhand_asofdate_rec.material_cost           := p_material_cost;
    l_onhand_asofdate_rec.material_overhead_cost  := p_material_overhead_cost;
    l_onhand_asofdate_rec.resource_cost           := p_resource_cost;
    l_onhand_asofdate_rec.outside_processing_cost := p_outside_processing_cost;
    l_onhand_asofdate_rec.overhead_cost           := p_overhead_cost;
    l_onhand_asofdate_rec.item_cost               := p_item_cost;
    l_onhand_asofdate_rec.item_decription         := p_item_decription;
    l_onhand_asofdate_rec.organization_id         := p_organization_id;
    l_onhand_asofdate_rec.inventory_item_id       := p_inventory_item_id;
    l_onhand_asofdate_rec.category_id             := p_category_id;
    l_onhand_asofdate_rec.cost_type_id            := p_cost_type_id;
    l_onhand_asofdate_rec.qty_source              := p_qty_source;
  
    RETURN l_onhand_asofdate_rec;
  
  END pl_to_sql;

  FUNCTION calc_onhand_asofdate(p_asofdate        IN DATE,
                                p_organization_id IN NUMBER)
  --RETURN xxinv_onhand_asofdate_tbl_type IS
   RETURN NUMBER IS
    --    PRAGMA AUTONOMOUS_TRANSACTION;
  
    TYPE number_tbl_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    TYPE date_tbl_type IS TABLE OF DATE INDEX BY BINARY_INTEGER;
    TYPE varchar2_tbl_type_3 IS TABLE OF VARCHAR2(3) INDEX BY BINARY_INTEGER;
    TYPE varchar2_tbl_type_10 IS TABLE OF VARCHAR2(10) INDEX BY BINARY_INTEGER;
    TYPE varchar2_tbl_type_30 IS TABLE OF VARCHAR2(30) INDEX BY BINARY_INTEGER;
    TYPE varchar2_tbl_type_240 IS TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;
  
    t_asofdate_tbl                date_tbl_type;
    t_subinventory_tbl            varchar2_tbl_type_30;
    t_item_number_tbl             varchar2_tbl_type_30;
    t_organization_code_tbl       varchar2_tbl_type_3;
    t_quantity_tbl                number_tbl_type;
    t_cost_type_tbl               varchar2_tbl_type_10;
    t_material_cost_tbl           number_tbl_type;
    t_material_overhead_cost_tbl  number_tbl_type;
    t_resource_cost_tbl           number_tbl_type;
    t_outside_processing_cost_tbl number_tbl_type;
    t_overhead_cost_tbl           number_tbl_type;
    t_item_cost_tbl               number_tbl_type;
    t_item_decription_tbl         varchar2_tbl_type_240;
    t_organization_id_tbl         number_tbl_type;
    t_inventory_item_id_tbl       number_tbl_type;
    t_category_id_tbl             number_tbl_type;
    t_cost_type_id_tbl            number_tbl_type;
    t_qty_source_tbl              number_tbl_type;
  
    l_onhand_asofdate_t xxinv_onhand_asofdate_tbl_type := xxinv_onhand_asofdate_tbl_type();
  
    v_p_asofdate    DATE;
    l_return_status VARCHAR2(1000);
    l_msg_count     NUMBER(20);
    l_msg_data      VARCHAR2(1000);
    v_org_name      mtl_parameters.organization_code%TYPE;
    v_categsetid    mtl_category_sets_tl.category_set_id%TYPE;
    v_op_name       hr_all_organization_units.name%TYPE;
    v_orgid         NUMBER;
  
    j NUMBER;
  
  BEGIN
  
    -- fnd_session_management.reset_session(userenv('SESSIONID'));
  
    v_p_asofdate := trunc(p_asofdate);
  
    SELECT mcs.category_set_id
      INTO v_categsetid
      FROM mtl_category_sets_tl mcs
     WHERE mcs.category_set_name = 'Main Category Set'
       AND mcs.language = userenv('LANG');
  
    inv_quantity_tree_pub.clear_quantity_cache;
    cst_inventory_pub.calculate_inventoryvalue(p_api_version       => 1.0,
                                               p_init_msg_list     => cst_utility_pub.get_true,
                                               p_organization_id   => p_organization_id,
                                               p_onhand_value      => 1,
                                               p_intransit_value   => 1,
                                               p_receiving_value   => 1,
                                               p_valuation_date    => v_p_asofdate + 1,
                                               p_cost_type_id      => fnd_profile.value('XX_COST_TYPE'), ----2,
                                               p_item_from         => NULL, --p_item_number,
                                               p_item_to           => NULL, --p_item_number,
                                               p_category_set_id   => v_categsetid,
                                               p_category_from     => NULL,
                                               p_category_to       => NULL,
                                               p_cost_group_from   => NULL,
                                               p_cost_group_to     => NULL,
                                               p_subinventory_from => NULL,
                                               p_subinventory_to   => NULL,
                                               p_qty_by_revision   => 2,
                                               p_zero_cost_only    => 2,
                                               p_zero_qty          => 2,
                                               p_expense_item      => 2,
                                               p_expense_sub       => 1,
                                               p_unvalued_txns     => 2,
                                               p_receipt           => 1,
                                               p_shipment          => 1,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data);
  
    /*      SELECT DISTINCT trunc(v_p_asofdate),
                    ciqt.subinventory_code,
                    msi.segment1,
                    mp.organization_code,
                    ciqt.rollback_qty,
                    decode(cict.cost_type_id, 2, 'Average', '*'),
                    nvl(cict.material_cost, 0),
                    nvl(cict.material_overhead_cost, 0),
                    nvl(resource_cost, 0),
                    nvl(cict.outside_processing_cost, 0),
                    nvl(cict.overhead_cost, 0),
                    nvl(cict.item_cost, 0),
                    msi.description,
                    p_organization_id,
                    msi.inventory_item_id,
                    ciqt.category_id,
                    cict.cost_type_id,
                    ciqt.qty_source BULK COLLECT
      INTO t_asofdate_tbl,
           t_subinventory_tbl,
           t_item_number_tbl,
           t_organization_code_tbl,
           t_quantity_tbl,
           t_cost_type_tbl,
           t_material_cost_tbl,
           t_material_overhead_cost_tbl,
           t_resource_cost_tbl,
           t_outside_processing_cost_tbl,
           t_overhead_cost_tbl,
           t_item_cost_tbl,
           t_item_decription_tbl,
           t_organization_id_tbl,
           t_inventory_item_id_tbl,
           t_category_id_tbl,
           t_cost_type_id_tbl,
           t_qty_source_tbl
      FROM mtl_system_items_b msi,
           mtl_parameters     mp,
           cst_inv_qty_temp   ciqt,
           cst_inv_cost_temp  cict
     WHERE ciqt.organization_id = mp.organization_id AND
           msi.organization_id = ciqt.organization_id AND
           msi.inventory_item_id = ciqt.inventory_item_id AND
           cict.organization_id = ciqt.organization_id AND
           cict.inventory_item_id = ciqt.inventory_item_id AND
           (mp.primary_cost_method = 1 OR
           cict.cost_group_id = ciqt.cost_group_id) AND
           nvl(ciqt.rollback_qty, 0) <> 0 AND
           mp.organization_id = p_organization_id AND
           msi.segment1 = p_item_number;
    
    j := t_inventory_item_id_tbl.COUNT;
    
    l_onhand_asofdate_t := xxinv_onhand_asofdate_tbl_type();
    l_onhand_asofdate_t.EXTEND(j);
    
    FOR i IN 1 .. t_inventory_item_id_tbl.COUNT LOOP
    
       l_onhand_asofdate_t(i) := pl_to_sql(t_asofdate_tbl(i),
                                           t_subinventory_tbl(i),
                                           t_item_number_tbl(i),
                                           t_organization_code_tbl(i),
                                           t_quantity_tbl(i),
                                           t_cost_type_tbl(i),
                                           t_material_cost_tbl(i),
                                           t_material_overhead_cost_tbl(i),
                                           t_resource_cost_tbl(i),
                                           t_outside_processing_cost_tbl(i),
                                           t_overhead_cost_tbl(i),
                                           t_item_cost_tbl(i),
                                           t_item_decription_tbl(i),
                                           t_organization_id_tbl(i),
                                           t_inventory_item_id_tbl(i),
                                           t_category_id_tbl(i),
                                           t_cost_type_id_tbl(i),
                                           t_qty_source_tbl(i));
    END LOOP; */
  
    COMMIT;
  
    --   RETURN l_onhand_asofdate_t;
    RETURN 0;
  
  END calc_onhand_asofdate;

END xxinv_onhand_asofdate_pkg;
/
