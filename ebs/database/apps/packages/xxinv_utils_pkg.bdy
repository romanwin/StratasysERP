create or replace package body xxinv_utils_pkg IS

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30.7.13     yuval tal         add update_group_mark_id- CUST439 - INV General\439 Delete Group Mark ID
  --  1.1  07.08.13    yuval tal /vitaly cr 811 - modify org_assignment,get_organization_id_to_assign,get_bom_organization, ADD get_tranform_cost_org_code
  --  2.9  05.08.13    Vitaly            CR811- select in cursor csr_org_assign was changed (see sub-select "org")
  --  3.0  18.08.13    Vitaly            CR 870 std cost - change hard-coded organization; change cost_type_id=2 to cost_type_id=fnd_profile.value('XX_COST_TYPE')
  --  3.1  18.08.13    yuval tal         CR936-Change the get_avail_to_reserve quantity to return  quantity by list sub inventory
  --  3.2  22.04.14    sanjai misra      Modified this pkg for CHG31742
  --                                     Added following two functions: get_category_value, get_tariff_code
  --  3.3  28.04.14    sandeep akula     Added Function GET_STD_CST_BSD_ORGS_IN_LOOKUP (CHG0031469)
  --  3.4  08/06/2014  yuval tal         CHG0032388 - add function get_item_catalog_value
  --  3.5  17/06/2014  Dalit A. Raviv    Change logic of function is_fdm_item
  --  3.6  25/06/2014  Dalit A. Raviv    CHG0032316 - procedure org_assignment change lists from hard code to lookup lists,
  --                                     XXINV_ORG_ASSIGN, XXINV_ORG_ASSIGN_RESIN XXINV_ORG_ASSIGN_SYSTEM
  --                                     add KSS, KTS to XXINV_ORG_ASSIGN
  --  3.7  29.6.2014   yuval tal         change CHG0032103: add get_category_segment
  --  3.6  7.7.14      yuval tal         CHG0032699 add get_item_id
  --  3.7  06/10/2014  Dalit A. Raviv    CHG0032322 change logic of function - get_item_category
  --  3.8  09/11/2014  Dalit A. Raviv    CHG0034134 add function - get_related_item
  --  3.9  17/12/2014  Dalit A. Raviv    CHG0033956 correct function get_oh_qty
  --  4.0  30/03/2015  Michal Tzvik      CHG0034935 Add function get_organization_id
  --  4.1  10/05/2015  Dalit A. Raviv    CHG0034558 add function get_org_code
  --  4.2  10/06/2015  Michal Tzvik      CHG0035332 add function get_sp_technical_category
  --  4.3  09/21/2015  Diptasurjya       CHG0036213 add function is_aerospace_item
  --                   Chatterjee
  --  4.4  07/Oct/2015 Dalit A. Raviv    CHG0035915 add function get_weight_uom_code
  --  4.5  07/Mar/2016 Lingaraj Sarangi  CHG0037886 add function is_item_restricted
  --  4.6  27/Jul/2016 Lingaraj Sarangi  CHG0038799 - New fields in SP catalog PZ and Oracle
  --  4.7  28/Feb/2017 Lingaraj Sarangi  INC0088394 - Add a Returnable  P/N to the Return form
  --                                     get_related_item - Function Modified to show all releated Items
  --                                     rather then restricting to only FDM Item
  --  4.8  05/MAR/2017 Dovik Pollak      CHG0040117 add funtion get_sourcing_buyer_id
  --  4.9  30.4.17     yuval tal         CHG0040061  modify is_fdm_system_item
  --  5.0  07/12/2017  bellona banerjee  CHG0041294 TPL Interface FC -
  --                                     Remove Pick Allocations, Added P_Delivery_Name to
  --                                            check_asset_sub_inv_status for delivery id to name conversion
  --
  --  6.0  09/04/2018  Roman W.          CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --                                     added function : 1) is_intangible_items
  --  7.0  18-Jun-2018 Dan Melamed       CHG0043145 - Add function : get_lot_control_type_id
  --  8.0  17/06/2019  Bellona(TCS)      CHG0045830 - Remove Expiration Date column value from the Invoice Print Document for all regions
  --                                     change logic of function - get_serials_and_lots
  --------------------------------------------------------------------

  g_format_musk_jpn VARCHAR2(50) := 'RRRR/MM/DD';
  g_format_musk     VARCHAR2(50) := 'DD-MON-RR';




  --------------------------------------------------------------------
  --  name:            get_lot_control_type_id
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   18-Jun-2018
  --------------------------------------------------------------------
  --  purpose :  return item_id from item code
  --------------------------------------------------------------------
  --   1.0    18-Jun-2018    Dan Melamed      CHG0043145 - Add function : get_lot_control_type_id
  --------------------------------------------------------------------

 Function get_lot_control_type_id(p_inventory_item_id number, p_org_id number) return number
 is
    l_lot_control_type number;
 begin

  Select msib.lot_control_code
  into l_lot_control_type
  FROM mtl_system_items_b msib
  where msib.inventory_item_id = p_inventory_item_id
    and msib.organization_id = p_org_id;

  return l_lot_control_type;

 exception
    when others then
        return null;
 end get_lot_control_type_id;

  --------------------------------------------------------------------
  --  name:            get_item_id
  --  create by:
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :  return item_id from item code
  --------------------------------------------------------------------
  --   1.0    7.7.14   yuval tal      CHG0032699 add get_item_id
  --------------------------------------------------------------------
  FUNCTION get_item_id(p_item_code VARCHAR2) RETURN NUMBER IS
    l_item_id NUMBER;
  BEGIN

    SELECT inventory_item_id
      INTO l_item_id
      FROM mtl_system_items_b t
     WHERE t.segment1 = p_item_code
       AND t.organization_id = 91;

    RETURN l_item_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ---------------------------------------------
  -- get_resin_item_kg_rate
  ---------------------------------------------
  FUNCTION get_resin_item_kg_rate(p_inventory_item_id NUMBER) RETURN NUMBER IS
    CURSOR c IS

      SELECT element_value
        FROM mtl_descr_element_values_v t
       WHERE inventory_item_id = p_inventory_item_id
         AND item_catalog_group_id = 2
         AND element_name = 'Weight Factor (Kg)'
       ORDER BY element_sequence, element_name;

    l_tmp NUMBER;
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 99999;
  END;

  -------------------------------------------------------
  FUNCTION get_current_revision(p_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE,
                                p_organization_id   mtl_system_items_b.organization_id%TYPE)
    RETURN VARCHAR2 IS
    v_current_rev mtl_item_revisions_b.revision%TYPE;
  BEGIN

    SELECT MAX(revision)
      INTO v_current_rev
      FROM mtl_item_revisions_vl
     WHERE inventory_item_id = p_inventory_item_id
       AND organization_id = p_organization_id
       AND effectivity_date < SYSDATE;

    RETURN v_current_rev;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_current_revision;

  -------------------------------------------------------
  FUNCTION get_future_revision(p_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE,
                               p_organization_id   mtl_system_items_b.organization_id%TYPE,
                               x_effectivity_date  OUT DATE) RETURN VARCHAR2 IS

    l_future_rev mtl_item_revisions_b.revision%TYPE;

  BEGIN

    SELECT revision, effectivity_date
      INTO l_future_rev, x_effectivity_date
      FROM mtl_item_revisions_vl
     WHERE inventory_item_id = p_inventory_item_id
       AND organization_id = p_organization_id
       AND revision =
           (SELECT MAX(revision)
              FROM mtl_item_revisions_vl
             WHERE inventory_item_id = p_inventory_item_id
               AND organization_id = p_organization_id);

    RETURN l_future_rev;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_future_revision;

  -------------------------------------------------------
  PROCEDURE query_quantities(p_inventory_item_id   NUMBER,
                             p_organization_id     NUMBER,
                             p_subinventory_code   VARCHAR2 DEFAULT NULL,
                             p_locator_id          NUMBER DEFAULT NULL,
                             p_is_revision_control NUMBER DEFAULT 0,
                             p_is_lot_control      NUMBER DEFAULT 0,
                             p_is_serial_control   NUMBER DEFAULT 0,
                             p_revision            VARCHAR2 DEFAULT NULL,
                             p_revision_control    IN VARCHAR2 DEFAULT NULL,
                             p_lot_number          VARCHAR2 DEFAULT NULL,
                             p_lot_control         IN VARCHAR2 DEFAULT NULL,
                             p_serial_control      IN VARCHAR2 DEFAULT NULL,
                             x_qoh                 OUT NUMBER,
                             x_rqoh                OUT NUMBER,
                             x_qr                  OUT NUMBER,
                             x_qs                  OUT NUMBER,
                             x_att                 OUT NUMBER,
                             x_atr                 OUT NUMBER) IS

    l_on_hand_qty   NUMBER := 0;
    l_avail_qty     NUMBER := 0;
    l_rqoh          NUMBER := 0;
    l_qr            NUMBER := 0;
    l_qs            NUMBER := 0;
    l_atr           NUMBER := 0;
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(200);

    l_is_revision_control BOOLEAN := FALSE;
    l_is_lot_control      BOOLEAN := FALSE;
    l_is_serial_control   BOOLEAN := FALSE;
    l_locator_id          NUMBER;
    --l_cost_group_id       NUMBER;

  BEGIN
    --
    -- Tree mode constants
    -- Users can call create_tree() in three modes, reservation mode,
    -- transaction mode, and loose items only mode.  In loose items only
    -- mode, only quantity not in containers is considered
    -- g_reservation_mode CONSTANT INTEGER := 1;
    -- g_transaction_mode CONSTANT INTEGER := 2;
    -- g_loose_only_mode  CONSTANT INTEGER := 3;
    -- g_no_lpn_rsvs_mode  CONSTANT INTEGER := 4;
    -----------------------------------------------
    -- synonyms used in this program
    --     qoh          quantity on hand
    --     rqoh         reservable quantity on hand
    --     qr           quantity reserved
    --     att          available to transact
    --     atr          available to reserve
    -- invConv changes begin
    --    sqoh          secondary quantity on hand
    --    srqoh         secondary reservable quantity on hand
    --    sqr           secondary quantity reserved
    --    satt          secondary available to transact
    --    satr          secondary available to reserve
    -- invConv changes end

    IF upper(p_revision_control) = 'TRUE' THEN
      l_is_revision_control := TRUE;
    END IF;
    IF upper(p_lot_control) = 'TRUE' THEN
      l_is_lot_control := TRUE;
    END IF;
    IF upper(p_serial_control) = 'TRUE' THEN
      l_is_serial_control := TRUE;
    END IF;

    IF p_locator_id <= 0 THEN
      l_locator_id := NULL;
    ELSE
      l_locator_id := p_locator_id;
    END IF;

    inv_quantity_tree_pub.clear_quantity_cache;
    inv_quantity_tree_pub.query_quantities(p_api_version_number  => 1.0,
                                           x_return_status       => l_return_status,
                                           x_msg_count           => l_msg_count,
                                           x_msg_data            => l_msg_data,
                                           p_organization_id     => p_organization_id,
                                           p_inventory_item_id   => p_inventory_item_id,
                                           p_tree_mode           => inv_quantity_tree_pub.g_transaction_mode,
                                           p_is_revision_control => l_is_revision_control,
                                           p_is_lot_control      => l_is_lot_control,
                                           p_is_serial_control   => l_is_serial_control,
                                           p_revision            => p_revision,
                                           p_lot_number          => p_lot_number,
                                           p_subinventory_code   => p_subinventory_code,
                                           p_locator_id          => l_locator_id,
                                           x_qoh                 => l_on_hand_qty,
                                           x_rqoh                => l_rqoh,
                                           x_qr                  => l_qr,
                                           x_qs                  => l_qs,
                                           x_att                 => l_avail_qty,
                                           x_atr                 => l_atr);

    x_qoh  := l_on_hand_qty;
    x_rqoh := l_rqoh;
    x_qr   := l_qr;
    x_qs   := l_qs;
    x_att  := l_avail_qty;
    x_atr  := l_atr;

  END query_quantities;

  -------------------------------------------------------
  FUNCTION get_avail_to_transact(p_inventory_item_id NUMBER,
                                 p_organization_id   NUMBER,
                                 p_subinventory      VARCHAR2 DEFAULT NULL,
                                 p_locator_id        NUMBER DEFAULT NULL,
                                 p_is_serial_control NUMBER DEFAULT NULL,
                                 p_revision          VARCHAR2 DEFAULT NULL,
                                 p_lot_number        VARCHAR2 DEFAULT NULL)
    RETURN NUMBER IS

    l_on_hand_qty NUMBER := 0;
    l_avail_qty   NUMBER := 0;
    l_rqoh        NUMBER := 0;
    l_qr          NUMBER := 0;
    l_qs          NUMBER := 0;
    l_atr         NUMBER := 0;

  BEGIN
    query_quantities(p_inventory_item_id => p_inventory_item_id,
                     p_organization_id   => p_organization_id,
                     p_subinventory_code => p_subinventory,
                     x_qoh               => l_on_hand_qty,
                     x_rqoh              => l_rqoh,
                     x_qr                => l_qr,
                     x_qs                => l_qs,
                     x_att               => l_avail_qty,
                     x_atr               => l_atr);

    RETURN l_avail_qty;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_avail_to_transact;

  --------------------------------------------------------------------
  --  name:            get_avail_to_reserve
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   xx/xx/2009
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2009  XXX               initial build
  --  1.1  03/12/2009  Dalit A. Raviv    add the ability to get quantity by
  --                                     subinv and / or locator.
  --                                     need to send tree_mode by the correct level
  --  1.2  3.10.2010                       add p_line_id logic
  --  1.3  18/08/2013  yuval tal         CR936- return quantity for  list sub inventory
  --  1.4  07/12/2017  bellona banerjee  CHG0041294 TPL Interface FC -
  --                                     Remove Pick Allocations
  --------------------------------------------------------------------
  FUNCTION get_avail_to_reserve(p_inventory_item_id NUMBER,
                                p_organization_id   NUMBER,
                                -- Dalit A. Raviv 03/12/2009
                                p_subinventory      VARCHAR2 DEFAULT NULL,
                                p_locator_id        NUMBER DEFAULT NULL,
                                p_is_serial_control NUMBER DEFAULT NULL,
                                p_revision          VARCHAR2 DEFAULT NULL,
                                p_lot_number        VARCHAR2 DEFAULT NULL,
                                p_line_id           NUMBER DEFAULT NULL)
    RETURN NUMBER IS

    l_on_hand_qty             NUMBER := 0;
    l_avail_qty               NUMBER := 0;
    l_rqoh                    NUMBER := 0;
    l_qr                      NUMBER := 0;
    l_qs                      NUMBER := 0;
    l_atr                     NUMBER := 0;
    l_att_total               NUMBER := 0; -- CR936
    l_order_line_reserved_qty NUMBER;
    l_revision_control        VARCHAR2(10); -- CHG0041294
  BEGIN

    FOR i IN (SELECT regexp_substr(p_subinventory, '[^,]+', 1, LEVEL) subinventory
                FROM dual
              CONNECT BY regexp_substr(p_subinventory, '[^,]+', 1, LEVEL) IS NOT NULL) LOOP
      -- CR936

      l_on_hand_qty := 0;
      l_avail_qty   := 0;
      l_rqoh        := 0;
      l_qr          := 0;
      l_qs          := 0;
      l_atr         := 0;

      /*CHG0041294- Logic added for TPL Interface FC - Remove Pick Allocations */
      IF p_revision IS NOT NULL THEN
        l_revision_control := 'TRUE';
      ELSE
        l_revision_control := 'FALSE';
      END IF;

      -- Dalit A. Raviv 03/11/2009 add tree_mode by in params

      query_quantities(p_inventory_item_id => p_inventory_item_id,
                       p_organization_id   => p_organization_id,
                       -- Dalit a. Raviv 03/12/2009
                       p_subinventory_code => i.subinventory, -- in v
                       p_locator_id        => p_locator_id, -- in n
                       -- end
                       p_revision         => p_revision, -- CHG0041294
                       p_revision_control => l_revision_control, -- CHG0041294
                       x_qoh              => l_on_hand_qty,
                       x_rqoh             => l_rqoh,
                       x_qr               => l_qr,
                       x_qs               => l_qs,
                       x_att              => l_avail_qty,
                       x_atr              => l_atr);
      l_att_total := nvl(l_att_total, 0) + l_atr;
    END LOOP;

    -- decrease qty reserved by order line
    IF p_line_id IS NOT NULL THEN

      SELECT SUM(nvl(mra.reservation_quantity, 0))
        INTO l_order_line_reserved_qty
        FROM mtl_reservations_all_v mra
       WHERE mra.demand_source_type = 'Sales order'
         AND mra.demand_source_line_id = p_line_id;

    END IF;

    RETURN l_att_total + nvl(l_order_line_reserved_qty, 0); -- CR936

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_avail_to_reserve;

  ------------------------------------------------------
  --  org_assignment
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 2.0    07.12.11     yuval tal      add logic to org_assignment  : UOP as UOC
  -- 2.1    08.07.12     Dovik Pollak   add logic to org_assignment  : POT
  -- 2.2    17.06.13     yuval tal      CR832- Assign Item to JOO,JOT : add logic to org_assignment - support JOO,JOT to be defines like EOT in the Agile
  -- 2.3    05.08.13     Vitaly         CR811- select in cursor csr_org_assign was changed (see sub-select "org")
  -- 3.6    25/06/2014   Dalit A. Raviv CHG0032316 - org_assignment change lists from hard code to lookup lists,
  --                                    XXINV_ORG_ASSIGN, XXINV_ORG_ASSIGN_RESIN XXINV_ORG_ASSIGN_SYSTEM
  --                                    add KSS, KTS to XXINV_ORG_ASSIGN
  ------------------------------------------------------
  PROCEDURE org_assignment(p_inventory_item_id NUMBER,
                           p_item_code         VARCHAR2,
                           p_group             VARCHAR2,
                           p_family            VARCHAR2 DEFAULT NULL,
                           x_return_status     OUT VARCHAR2,
                           x_err_message       OUT VARCHAR2) IS

    --  |  Criteria                         |  Assign to Org        |  Comments
    -------------------------------------------------------------------------------------------------
    -- 1|  In Main Category: Group = Other, |                       |
    --  |  Customer Support or Accessories  |  all Organizations    |
    -------------------------------------------------------------------------------------------------
    -- 2|  Item Code starts with OBJ        |  POT, UOP, WPI, WSI,  |
    --  |                                   |  UOB, UOC, POC, POH,  |
    --  |  OR ends with '-S' or '-R'        |  EOT  EOG, POS, JOO,  |
    --  |                                   |  JOT, KSS, KTS        |
    -------------------------------------------------------------------------------------------------
    -- 3|  In Main Category: Group = System | ITA, WPI              |
    -------------------------------------------------------------------------------------------------
    -- 4|  In Main Category: Group = Resin  | WRI                   |  Including OBJ Items
    -------------------------------------------------------------------------------------------------
    -- 5|  All Items                        | ITA, WPI              |
    -------------------------------------------------------------------------------------------------

    CURSOR csr_org_assign(p_category_group VARCHAR2,
                          p_item_number    VARCHAR2) IS
      SELECT msi.organization_id master_organization_id,
             --org.organization_id         organiation_id,
             nvl(om.new_organization_id, org.organization_id) organization_id,
             --org.organization_code,
             nvl(om.new_organization_code, org.organization_code) organization_code,
             msi.primary_uom_code,
             msi.inventory_item_id,
             msi.secondary_uom_code,
             msi.tracking_quantity_ind,
             msi.secondary_default_ind,
             msi.ont_pricing_qty_source,
             msi.dual_uom_deviation_high,
             msi.dual_uom_deviation_low
        FROM mtl_system_items_b msi,
             xxinv_cost_org_map_v om,
             (SELECT mp.organization_id, mp.organization_code
                FROM mtl_parameters mp
               WHERE p_category_group IN
                     ('Other', 'Customer Support', 'Accessories')
                 AND mp.organization_id != mp.master_organization_id
                 AND NOT EXISTS
               (SELECT 1 ---OLD organizations only
                        FROM fnd_lookup_values_vl a
                       WHERE a.lookup_type = 'XXCST_INV_ORG_REPLACE'
                         AND a.attribute1 = to_char(mp.organization_id))
              UNION
              SELECT organization_id, organization_code
                FROM mtl_parameters
               WHERE (p_item_code LIKE 'OBJ-%' OR p_item_code LIKE '%-S' OR
                     p_item_code LIKE '%-R')
                    -- Dalit A. Raviv 25/06/2014 change hard code to Lookup list and add 'KSS', 'KTS' TO LIST
                 AND organization_code IN
                     (SELECT lookup_code
                        FROM fnd_lookup_values v
                       WHERE v.lookup_type = 'XXINV_ORG_ASSIGN'
                         AND v.language = 'US'
                         AND nvl(v.enabled_flag, 'N') <> 'N'
                         AND nvl(v.end_date_active, SYSDATE + 1) >
                             trunc(SYSDATE))
              --('POS','WPI', 'WSI',
              -- 'UOB','UOP', 'UOC',
              -- 'POC','POH', 'POT',
              --'EOT', 'EOG',
              -- 'JOO', 'JOT',
              -- 'UME', 'USE',
              -- 'ITA',
              -- 'KSS', 'KTS') -- yuval add POS xx.xx.xxxx + UOC 7.12.11
              UNION
              SELECT organization_id, organization_code
                FROM mtl_parameters
               WHERE p_category_group = 'Systems'
                    -- Dalit A. Raviv 25/06/2014 change hard code to Lookup list
                 AND organization_code IN
                     (SELECT lookup_code
                        FROM fnd_lookup_values v
                       WHERE v.lookup_type = 'XXINV_ORG_ASSIGN_SYSTEM'
                         AND v.language = 'US'
                         AND nvl(v.enabled_flag, 'N') <> 'N'
                         AND nvl(v.end_date_active, SYSDATE + 1) >
                             trunc(SYSDATE)) --('ITA', 'WPI')
              UNION

              SELECT organization_id, organization_code
                FROM mtl_parameters
               WHERE p_category_group = 'Resins'
                    -- Dalit A. Raviv 25/06/2014 change hard code to Lookup list
                 AND organization_code IN
                     (SELECT lookup_code
                        FROM fnd_lookup_values v
                       WHERE v.lookup_type = 'XXINV_ORG_ASSIGN_RESIN'
                         AND v.language = 'US'
                         AND nvl(v.enabled_flag, 'N') <> 'N'
                         AND nvl(v.end_date_active, SYSDATE + 1) >
                             trunc(SYSDATE)) --('WRI')

              UNION
              SELECT organization_id, organization_code
                FROM mtl_parameters
               WHERE organization_code IN ('ITA', 'WPI')) org
       WHERE msi.inventory_item_id = p_inventory_item_id
         AND org.organization_id = om.organization_id(+)
         AND msi.organization_id =
             xxinv_utils_pkg.get_master_organization_id;

    cur_org_asg csr_org_assign%ROWTYPE;

    l_group VARCHAR2(50);
    l_stage VARCHAR2(10);

    invalid_assignment EXCEPTION;

    t_item_org_assign_tbl system.ego_item_org_assign_table := NEW
                                                              system.ego_item_org_assign_table();
    l_error_tbl           error_handler.error_tbl_type;

    l_org_counter NUMBER := 1;

  BEGIN

    -- SAVEPOINT assign_item;

    --l_return_status := 'S';
    l_group := p_group;

    FOR cur_org_asg IN csr_org_assign(l_group, p_item_code) LOOP

      t_item_org_assign_tbl.extend();
      t_item_org_assign_tbl(l_org_counter) := system.ego_item_org_assign_rec(1,
                                                                             1,
                                                                             '1',
                                                                             '1',
                                                                             1,
                                                                             '1',
                                                                             '1',
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL,
                                                                             NULL);
      t_item_org_assign_tbl(l_org_counter).master_organization_id := cur_org_asg.master_organization_id;
      t_item_org_assign_tbl(l_org_counter).organization_id := cur_org_asg.organization_id;
      t_item_org_assign_tbl(l_org_counter).organization_code := cur_org_asg.organization_code;
      t_item_org_assign_tbl(l_org_counter).primary_uom_code := cur_org_asg.primary_uom_code;
      t_item_org_assign_tbl(l_org_counter).inventory_item_id := cur_org_asg.inventory_item_id;
      t_item_org_assign_tbl(l_org_counter).secondary_uom_code := cur_org_asg.secondary_uom_code;
      t_item_org_assign_tbl(l_org_counter).tracking_quantity_ind := cur_org_asg.tracking_quantity_ind;
      t_item_org_assign_tbl(l_org_counter).secondary_default_ind := cur_org_asg.secondary_default_ind;
      t_item_org_assign_tbl(l_org_counter).ont_pricing_qty_source := cur_org_asg.ont_pricing_qty_source;
      t_item_org_assign_tbl(l_org_counter).dual_uom_deviation_high := cur_org_asg.dual_uom_deviation_high;
      t_item_org_assign_tbl(l_org_counter).dual_uom_deviation_low := cur_org_asg.dual_uom_deviation_low;
      l_org_counter := l_org_counter + 1;

    END LOOP;

    xxinv_item_org_assign_pkg.process_org_assignments(p_item_org_assign_tab => t_item_org_assign_tbl,
                                                      p_commit              => fnd_api.g_false,
                                                      x_return_status       => x_return_status,
                                                      x_msg_count           => l_org_counter);
    IF x_return_status != 'S' THEN

      error_handler.get_message_list(x_message_list => l_error_tbl);
      FOR j IN 1 .. l_error_tbl.count LOOP
        x_err_message := x_err_message || l_error_tbl(j).message_text ||
                         chr(10);
      END LOOP;
      -- RAISE invalid_assignment;
    END IF;

    x_return_status := 'S';

  EXCEPTION
    WHEN OTHERS THEN

      -- ROLLBACK TO assign_item;
      x_return_status := 'E';
      x_err_message   := 'Error for ' || l_stage || ': ' || SQLERRM;

  END org_assignment;

  ---------------------------------------------------
  FUNCTION get_lookup_meaning(p_lookup_type VARCHAR2,
                              p_lookup_code VARCHAR2) RETURN VARCHAR2 IS

    l_meaning fnd_lookup_values.meaning%TYPE;
  BEGIN

    SELECT meaning
      INTO l_meaning
      FROM fnd_lookup_values flv
     WHERE flv.lookup_type = p_lookup_type
       AND flv.lookup_code = p_lookup_code
       AND flv.language = userenv('LANG');

    RETURN l_meaning;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lookup_meaning;

  ---------------------------------------------------
  -- get_organization_id_to_assign
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07.08.13     yuval tal         cr811 : support change in function xxinv_utils_pkg.get_bom_organization
  --                                              return code instead of name
  ----------------------------------------------------
  FUNCTION get_organization_id_to_assign(p_inv_item_id IN NUMBER)
    RETURN NUMBER IS

    l_organization_code inv_organization_name_v.organization_code%TYPE;
    l_organization_id   inv_organization_name_v.organization_id%TYPE;
    l_category          mtl_categories_b.segment1%TYPE;
  BEGIN

    SELECT segment1
      INTO l_category
      FROM mtl_categories_b mc, mtl_item_categories mic
     WHERE mc.category_id = mic.category_id
       AND mic.inventory_item_id = p_inv_item_id
       AND mic.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND mic.category_set_id =
           xxinv_utils_pkg.get_default_category_set_id;

    l_organization_code := xxinv_utils_pkg.get_bom_organization(l_category);

    SELECT organization_id
      INTO l_organization_id
      FROM inv_organization_name_v
     WHERE organization_code = l_organization_code;

    RETURN l_organization_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_organization_id_to_assign;

  --Get Segment1 Of Category Set XXOBJT_Main Category Set. Return Organization To Create BOM

  ------------------------------------------------------
  -- get_tranform_cost_org_code
  --------------------------------------------------------------------
  --  1.0  30.7.13     yuval tal         cr811 : return translted organization_code
  -----------------------------------------------------
  FUNCTION get_transform_cost_org_code(p_organization_code VARCHAR2)
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT t.new_organization_code
        FROM xxinv_cost_org_map_v t
       WHERE t.organization_code = p_organization_code
         AND t.organization_code != t.new_organization_code;
    l_tmp xxinv_cost_org_map_v.organization_code%TYPE;
  BEGIN
    IF fnd_profile.value('XXINV_AGILE_ORG_ASSIGN_MODE') = 'NEW' THEN
      OPEN c;
      FETCH c
        INTO l_tmp;
      CLOSE c;

      RETURN l_tmp;
    ELSE

      RETURN p_organization_code;

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------------------------------
  -- get_bom_organization
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30.7.13     yuval tal         cr811 : return organization_code instead of name
  --  1.1  18.8.13     Vitaly            CR 870 std cost - change hard-coded organization
  ----------------------------------------------------
  FUNCTION get_bom_organization(p_category IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_category = 'Resins' THEN
      RETURN get_transform_cost_org_code('WRI'); -- 'WRI - WW Resin Israel (IO)';
      -- RETURN get_transform_cost_org_code('IRK');
    ELSE
      RETURN get_transform_cost_org_code('WPI'); -- 'WPI - WW Printers Israel (IO)';
      -- RETURN get_transform_cost_org_code('IPK');
    END IF;
  END get_bom_organization;

  ---------------------------------------------------
  FUNCTION get_master_organization_id(p_organization_id NUMBER DEFAULT NULL)
    RETURN NUMBER IS

    v_organization_id NUMBER;
  BEGIN

    SELECT mp.master_organization_id
      INTO v_organization_id
      FROM mtl_parameters mp
     WHERE organization_id = nvl(p_organization_id, master_organization_id);

    RETURN v_organization_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_master_organization_id;

  --------------------------------------------------------------------
  --  name:               get_organization_id
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      30/03/2015
  --  Description:        return organization_id of given organization_code
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/03/2015    Michal Tzvik    CHG0034935 - Initial build
  --------------------------------------------------------------------
  FUNCTION get_organization_id(p_organization_code VARCHAR2) RETURN NUMBER IS

    v_organization_id NUMBER;
  BEGIN

    SELECT mp.organization_id
      INTO v_organization_id
      FROM mtl_parameters mp
     WHERE mp.organization_code = p_organization_code;

    RETURN v_organization_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_organization_id;

  ---------------------------------------------------
  FUNCTION get_default_category_set_id(p_func_area VARCHAR2 DEFAULT 'Inventory')
    RETURN NUMBER IS

    l_category_set_id NUMBER;

  BEGIN

    SELECT category_set_id
      INTO l_category_set_id
      FROM mtl_default_category_sets_fk_v
     WHERE functional_area_desc = p_func_area;

    RETURN l_category_set_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_default_category_set_id;

  ---------------------------------------------------
  FUNCTION item_routing_exists(p_item_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 IS

    rtg_exists VARCHAR2(2);

  BEGIN

    BEGIN
      SELECT 'Y'
        INTO rtg_exists
        FROM bom_operational_routings r
       WHERE r.assembly_item_id = p_item_id
         AND r.organization_id = p_org_id
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    RETURN rtg_exists;

  END item_routing_exists;

  ---------------------------------------------------
  FUNCTION item_in_price_list(p_item_id NUMBER) RETURN VARCHAR2 IS

    item_in_pl VARCHAR2(2);

  BEGIN

    BEGIN
      SELECT 'Y'
        INTO item_in_pl
        FROM qp_list_lines_v q
       WHERE q.product_attribute_context = 'ITEM'
         AND q.product_attr_value = to_char(p_item_id)
         AND q.product_attribute = 'PRICING_ATTRIBUTE1'
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    RETURN item_in_pl;

  END item_in_price_list;

  ---------------------------------------------------
  FUNCTION item_in_asl(p_item_id NUMBER) RETURN VARCHAR2 IS

    s_item_in_asl VARCHAR2(200);

  BEGIN
    BEGIN
      SELECT 'Y'
        INTO s_item_in_asl
        FROM po_asl_suppliers_v p
       WHERE p.item_id = p_item_id
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    RETURN s_item_in_asl;

  END item_in_asl;

  ---------------------------------------------------
  FUNCTION get_item_formulation(p_item_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 IS

    for_num VARCHAR2(200);

  BEGIN
    BEGIN
      SELECT msib.attribute18
        INTO for_num
        FROM mtl_system_items_b msib
       WHERE msib.inventory_item_id = p_item_id
         AND msib.organization_id = p_org_id;

    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    RETURN for_num;

  END get_item_formulation;

  ---------------------------------------------------
  FUNCTION get_item_ms(p_item_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2 IS

    for_num VARCHAR2(2);

  BEGIN
    BEGIN
      SELECT msib.attribute19
        INTO for_num
        FROM mtl_system_items_b msib
       WHERE msib.inventory_item_id = p_item_id
         AND msib.organization_id = p_org_id;

    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    RETURN for_num;

  END get_item_ms;

  ---------------------------------------------------
  FUNCTION item_has_sourcing_rule(p_item VARCHAR2, p_org_id NUMBER)
    RETURN VARCHAR2 IS

    source_rule_exists VARCHAR2(20);

  BEGIN
    BEGIN
      SELECT 'Y'
        INTO source_rule_exists
        FROM msc_sr_assignments_v msc
       WHERE msc.entity_name = p_item
         AND msc.organization_id = p_org_id
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
      WHEN OTHERS THEN
        RETURN 'N';
    END;

    RETURN source_rule_exists;

  END item_has_sourcing_rule;

  ---------------------------------------------------
  FUNCTION item_req_by_date(p_item_id NUMBER, p_org_id NUMBER, p_date DATE)
    RETURN NUMBER IS
    p_item_req NUMBER;

  BEGIN
    BEGIN
      SELECT SUM(CASE
                   WHEN wro.required_quantity > wro.quantity_issued THEN
                    wro.required_quantity - wro.quantity_issued
                   ELSE
                    0
                 END)
        INTO p_item_req
        FROM wip_requirement_operations wro
       WHERE wro.inventory_item_id = p_item_id
         AND wro.organization_id = p_org_id
         AND wro.date_required < p_date;

    EXCEPTION
      WHEN no_data_found THEN
        RETURN 0;
      WHEN OTHERS THEN
        RETURN 0;
    END;

    RETURN p_item_req;

  END item_req_by_date;

  ---------------------------------------------------
  FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
                                p_order_line_id NUMBER) RETURN VARCHAR2 IS

    CURSOR csr_lot_serials IS
      SELECT wsn.fm_serial_number || decode(wsn.fm_serial_number,
                                            wsn.to_serial_number,
                                            NULL,
                                            wsn.fm_serial_number,
                                            NULL,
                                            NULL,
                                            ', ') ||
             decode(wsn.fm_serial_number,
                    wsn.to_serial_number,
                    NULL,
                    wsn.to_serial_number) ser_lot,
             NULL exp_date,
             wdd.inventory_item_id
        FROM wsh_delivery_details     wdd,
             wsh_delivery_assignments wda,
             wsh_new_deliveries       wnd,
             wsh_serial_numbers       wsn
       WHERE wdd.delivery_detail_id = wda.delivery_detail_id
         AND wdd.delivery_detail_id = wsn.delivery_detail_id
         AND wda.delivery_id = wnd.delivery_id
         AND wnd.name = nvl(p_delivery_name, wnd.name)
         AND -- Delivery_id from Invoice
             wdd.source_line_id = p_order_line_id -- Order Line ID from invoice;
      UNION ALL
      SELECT wdd.lot_number ser_lot,
             to_char(mln.expiration_date, 'DD-MON-RR') exp_date,
             wdd.inventory_item_id
        FROM wsh_delivery_details     wdd,
             wsh_delivery_assignments wda,
             wsh_new_deliveries       wnd,
             mtl_lot_numbers          mln
       WHERE wdd.delivery_detail_id = wda.delivery_detail_id
         AND wdd.lot_number IS NOT NULL
         AND wdd.inventory_item_id = mln.inventory_item_id
         AND wdd.organization_id = mln.organization_id
         AND wdd.lot_number = mln.lot_number
         AND wda.delivery_id = wnd.delivery_id
         AND wnd.name = nvl(p_delivery_name, wnd.name)
         AND -- Delivery_id from Invoice
             wdd.source_line_id = p_order_line_id; -- Order Line ID from invoice;

    v_serial_num VARCHAR2(50);
    v_flag       NUMBER;

  BEGIN

    v_flag := 1;

    FOR curec IN csr_lot_serials LOOP
      IF v_flag = 1 THEN
        IF curec.exp_date IS NOT NULL THEN
          v_serial_num := curec.ser_lot || chr(10) || '(' || curec.exp_date || ')';
        ELSE
          v_serial_num := curec.ser_lot;
        END IF;
      ELSE
        IF curec.exp_date IS NOT NULL THEN
          v_serial_num := v_serial_num || ',' || curec.ser_lot || chr(10) || '(' ||
                          curec.exp_date || ')';
        ELSE
          v_serial_num := v_serial_num || ',' || curec.ser_lot;
        END IF;
      END IF;

      v_flag := v_flag + 1;
    END LOOP;

    RETURN v_serial_num;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_delivery_serials;

  --------------------------------------------------------------------
  --  name:            get_serials_and_lots
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2009
  --------------------------------------------------------------------
  --  purpose :        concatenate all serials/lots for SO line
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2009  Ella Malchi       initial build
  --  1.1  03/12/2009  Dalit A. Raviv    change the select for the serial_lot
  --                                     function will return serials for RMA, INTERNAL and STD SO
  --                                     and not only for STD SO. add param p_reference_id
  --  1.2  14/02/2010  Dalit A. Raviv    maker the function faster
  --  1.3  17/06/2019  Bellona(TCS)      CHG0045830 - Remove Expiration Date column value from the Invoice Print Document for all regions
  --------------------------------------------------------------------
  FUNCTION get_serials_and_lots(p_order_line_id NUMBER,
                                p_reference_id  NUMBER DEFAULT NULL,
                                p_str_len       NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    CURSOR csr_lot_serials(p_order_line_id NUMBER,
                           p_reference_id  NUMBER,
                           p_language      VARCHAR2) IS
    -- 33 - Sales order issue , 62 - Int Order Intr Ship , 15 - RMA Receipt , 50 - Internal Order Xfer
    -- retrieve SERIAL FOR STD SO
      SELECT mtlu.serial_number     ser_lot,
             NULL                   exp_date,
             mtlu.inventory_item_id
        FROM mtl_material_transactions mmt,
             -- oe_order_lines_all        oola,
             mtl_unit_transactions mtlu,
             mtl_txn_source_types  mtst
       WHERE --mmt.source_line_id = oola.line_id AND
       mmt.transaction_id = mtlu.transaction_id
       AND nvl(mmt.transaction_type_id, 33) IN (33, 15, 50, 62)
       AND mtst.transaction_source_type_id = mmt.transaction_source_type_id
       AND mtst.transaction_source_type_id = 2
       AND mmt.source_line_id = p_order_line_id --<reference_line_att6>
      UNION
      -- retrieve SERIAL FOR RMA
      SELECT mtlu.serial_number     ser_lot,
             NULL                   exp_date,
             mtlu.inventory_item_id
        FROM --oe_order_lines_all        oel,
             rcv_transactions          rcvtrx,
             mtl_material_transactions mmt,
             mtl_unit_transactions     mtlu,
             mtl_txn_source_types      mtst
       WHERE rcvtrx.transaction_id = mmt.source_line_id -- in this case this is the transaction id
         AND
            --rcvtrx.oe_order_line_id = oel.line_id AND
             mtlu.transaction_id = mmt.transaction_id
         AND mtst.transaction_source_type_id =
             mmt.transaction_source_type_id
         AND mtst.transaction_source_type_id = 12
         AND nvl(mmt.transaction_type_id, 33) IN (33, 15, 50, 62)
         AND rcvtrx.oe_order_line_id = p_order_line_id --<reference_line_att6>
      UNION
      -- retrieve SERIAL FOR INTERCOMPANY
      SELECT mtlu.serial_number     ser_lot,
             NULL                   exp_date,
             mtlu.inventory_item_id
        FROM mtl_unit_transactions mtlu
       WHERE mtlu.transaction_id = p_reference_id --<reference_line_att7>
      UNION
      -- retrieve LOTS FOR STD SO
      SELECT mtln.lot_number ser_lot,
             to_char(mln.expiration_date,
                     decode(p_language,
                            'JA',
                            g_format_musk_jpn,
                            g_format_musk)) exp_date,
             mtln.inventory_item_id
        FROM mtl_material_transactions mmt,
             -- oe_order_lines_all          oola,
             mtl_lot_numbers             mln,
             mtl_transaction_lot_numbers mtln,
             mtl_txn_source_types        mtst
       WHERE --mmt.source_line_id = oola.line_id AND
       mmt.transaction_id = mtln.transaction_id
       AND nvl(mmt.transaction_type_id, 33) IN (33, 15, 50, 62)
       AND mtst.transaction_source_type_id = mmt.transaction_source_type_id
       AND mtst.transaction_source_type_id = 2
       AND mln.inventory_item_id = mtln.inventory_item_id
       AND mln.organization_id = mtln.organization_id
       AND mln.lot_number = mtln.lot_number
       AND mmt.source_line_id = p_order_line_id --<reference_line_att6>
      UNION
      -- retrieve LOTS FOR RMA
      SELECT mtln.lot_number ser_lot,
             to_char(mln.expiration_date,
                     decode(p_language,
                            'JA',
                            g_format_musk_jpn,
                            g_format_musk)) exp_date,
             mtln.inventory_item_id
        FROM --oe_order_lines_all          oel,
             rcv_transactions            rcvtrx,
             mtl_material_transactions   mmt,
             mtl_lot_numbers             mln,
             mtl_transaction_lot_numbers mtln,
             mtl_txn_source_types        mtst
       WHERE rcvtrx.transaction_id = mmt.source_line_id -- in this case this is the transaction id
         AND
            -- rcvtrx.oe_order_line_id = oel.line_id AND
             mtln.transaction_id = mmt.transaction_id
         AND mtst.transaction_source_type_id =
             mmt.transaction_source_type_id
         AND mtst.transaction_source_type_id = 12
         AND nvl(mmt.transaction_type_id, 33) IN (33, 15, 50, 62)
         AND mln.inventory_item_id = mtln.inventory_item_id
         AND mln.organization_id = mtln.organization_id
         AND mln.lot_number = mtln.lot_number
         AND rcvtrx.oe_order_line_id = p_order_line_id --<reference_line_att6>
      UNION
      -- retrieve LOTS FOR INTERCOMPANY
      SELECT mtln.lot_number ser_lot,
             to_char(mln.expiration_date,
                     decode(p_language,
                            'JA',
                            g_format_musk_jpn,
                            g_format_musk)) exp_date,
             mtln.inventory_item_id
        FROM mtl_lot_numbers mln, mtl_transaction_lot_numbers mtln
       WHERE mln.inventory_item_id = mtln.inventory_item_id
         AND mln.organization_id = mtln.organization_id
         AND mln.lot_number = mtln.lot_number
         AND mtln.transaction_id = p_reference_id; --<reference_line_att7>

    v_serial_num VARCHAR2(2000);
    v_flag       NUMBER;
    v_language   VARCHAR2(50);

  BEGIN
    v_flag     := 1;
    v_language := xxhz_util.get_ou_lang(fnd_global.org_id);
    FOR curec IN csr_lot_serials(nvl(p_order_line_id, -1),
                                 nvl(p_reference_id, -1),
                                 v_language) LOOP
      --format of the string adjusted by daniel katz on 24-mar-10 (chr10 and spaces)
      IF v_flag = 1 THEN
        /*IF curec.exp_date IS NOT NULL THEN
          v_serial_num := curec.ser_lot || chr(10) || '(' || curec.exp_date || ')';
        ELSE*/ -- commented as part of CHG0045830
          v_serial_num := curec.ser_lot;
        /*END IF;*/ -- commented as part of CHG0045830
      ELSE
        /*IF curec.exp_date IS NOT NULL THEN
          v_serial_num := v_serial_num || ',' || chr(10) || curec.ser_lot ||
                          chr(10) || '(' || curec.exp_date || ')';
        ELSE*/      -- commented as part of CHG0045830
          v_serial_num := v_serial_num || ', ' || curec.ser_lot;
        /*END IF;*/ -- commented as part of CHG0045830
      END IF;

      v_flag := v_flag + 1;
    END LOOP;

    -- Dalit A. Raviv 1.1 03/12/2009
    -- if str bigger then p_str_len (50 char) return Multiple
    -- 1) if p_str_len is null return the string as it is.
    -- 2) if v_serial_num (string) bigger then p_str_len (50 char) then return Multiple - no need to show all
    -- 3) if last char at the string is ',' and string is <= p_str_len return the string witout ','
    -- 4) string is less then p_str_len then return what you find.
    IF p_str_len IS NULL THEN
      RETURN v_serial_num;
    ELSE
      IF length(v_serial_num) > p_str_len THEN
        RETURN 'multiple';
      ELSE
        IF (substr(v_serial_num, length(v_serial_num)) = ',') AND
           (length(v_serial_num) <= p_str_len) THEN
          RETURN substr(v_serial_num, 1, length(v_serial_num) - 1);
        ELSE
          RETURN v_serial_num;
        END IF; -- if 2
      END IF; -- if 1
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_serials_and_lots;

  ---------------------------------------------------
  FUNCTION get_in_transit_qty(p_inventory_item_id    NUMBER,
                              p_from_organization_id NUMBER,
                              p_to_organization_id   NUMBER DEFAULT NULL)
    RETURN NUMBER IS

    l_in_transit_qty NUMBER;

  BEGIN

    SELECT SUM(xit.open_qty)
      INTO l_in_transit_qty
      FROM xxinv_in_transit_v xit
     WHERE xit.inventory_item_id = p_inventory_item_id
       AND xit.from_organization_id =
           nvl(p_from_organization_id, xit.from_organization_id)
       AND xit.to_organization_id =
           nvl(p_to_organization_id, xit.to_organization_id);

    RETURN l_in_transit_qty;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_in_transit_qty;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_item_category
  --  create by:          Dalit a. Raviv
  --  $Revision:          1.0
  --  creation date:      06/10/2014
  --  Description:        return item category by category set
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx/xx/xxxx    xxxx            initial build
  --  1.1   06/10/2014    Dalit a. Raviv  redirect function to get_category_value.
  --------------------------------------------------------------------
  FUNCTION get_item_category(p_inventory_item_id NUMBER,
                             p_category_set_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS

    l_category        mtl_categories_kfv.concatenated_segments%TYPE;
    l_category_set_id NUMBER;

  BEGIN
    l_category_set_id := nvl(p_category_set_id,
                             xxinv_utils_pkg.get_default_category_set_id);

    l_category := xxinv_utils_pkg.get_category_value(p_category_set_id   => l_category_set_id, -- i n
                                                     p_inventory_item_id => p_inventory_item_id, -- i n
                                                     p_org_id            => xxinv_utils_pkg.get_master_organization_id); -- i n

    RETURN l_category;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_item_category;

  ------------------------------------------------
  -- function for disco report ...
  ------------------------------------------------
  FUNCTION xxinv_calc_quantity(p_org_code  VARCHAR2,
                               p_item      VARCHAR2,
                               p_month_num NUMBER) -- 1,2 or 3
   RETURN NUMBER IS

    v_quantity NUMBER;

  BEGIN
    IF p_month_num = 1 THEN
      SELECT SUM(ooel.ordered_quantity)
        INTO v_quantity
        FROM (SELECT b.order_number,
                     a.ordered_quantity,
                     a.shipped_quantity,
                     a.line_number,
                     a.ordered_item,
                     a.schedule_arrival_date,
                     a.inventory_item_id,
                     a.ship_from_org_id,
                     pla.organization_id ship_to_org_id
                FROM oe_order_lines_all           a,
                     oe_order_headers_all         b,
                     oe_transaction_types_tl      c,
                     po_location_associations_all pla
               WHERE nvl(a.ordered_quantity, 0) - nvl(a.shipped_quantity, 0) > 0
                 AND a.header_id = b.header_id
                 AND a.org_id = b.org_id
                 AND b.order_type_id = c.transaction_type_id
                 AND c.language = 'US'
                 AND upper(c.name) LIKE '%INTERNAL%'
                 AND a.flow_status_code = 'AWAITING_SHIPPING'
                 AND a.ship_to_org_id = pla.site_use_id) ooel
       WHERE to_char(ooel.schedule_arrival_date, 'MM') =
             to_char(SYSDATE, 'MM')
         AND ooel.ordered_item = p_item; -- AND ORGANIZATION CODE = P_ORG_CODE
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 5;
  END xxinv_calc_quantity;

  --------------------------------------------------------------------
  --  name:            get_oh_qty
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        Returns OH quantity for specified item, organization, subinv, locator
  --  in param:
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  XX/XX/XXXX  XXX            initial build
  --  1.1  17/12/2014  Dalit A. Raviv CHG0033956 add the ability to get the qty only from nettable subinv
  --------------------------------------------------------------------
  FUNCTION get_oh_qty(p_item_code       VARCHAR2,
                      p_organization_id NUMBER,
                      p_subinventory    VARCHAR2,
                      p_locator_code    VARCHAR2 DEFAULT NULL,
                      p_available_type  NUMBER DEFAULT NULL) RETURN NUMBER IS

    l_on_hand_qty NUMBER := 0;

  BEGIN
    SELECT SUM(transaction_quantity)
      INTO l_on_hand_qty
      FROM (SELECT oh.transaction_quantity
              FROM mtl_onhand_quantities_detail oh,
                   mtl_item_locations_kfv       loc,
                   mtl_system_items_b           msi,
                   mtl_secondary_inventories    subinv --  1.1  17/12/2014  Dalit A. Raviv
             WHERE oh.locator_id = loc.inventory_location_id
               AND oh.organization_id = loc.organization_id
               AND oh.inventory_item_id = msi.inventory_item_id
               AND msi.organization_id = oh.organization_id
               AND msi.segment1 = p_item_code -- 'ASY-01230'
               AND oh.organization_id = p_organization_id --90
               AND oh.subinventory_code =
                   nvl(p_subinventory, oh.subinventory_code) --'MAIN'
               AND loc.segment2 = p_locator_code
                  --  1.1  17/12/2014  Dalit A. Raviv
               AND oh.subinventory_code = subinv.secondary_inventory_name
               AND oh.organization_id = subinv.organization_id
               AND subinv.availability_type =
                   nvl(p_available_type, subinv.availability_type) -- 1 = netable
                  --
               AND p_locator_code IS NOT NULL
            UNION ALL
            SELECT oh.transaction_quantity
              FROM mtl_onhand_quantities_detail oh,
                   mtl_system_items_b           msi,
                   mtl_secondary_inventories    subinv --  1.1  17/12/2014  Dalit A. Raviv
             WHERE oh.inventory_item_id = msi.inventory_item_id
               AND msi.organization_id = oh.organization_id
               AND msi.segment1 = p_item_code -- 'ASY-01230'
               AND oh.organization_id = p_organization_id --90
               AND oh.subinventory_code =
                   nvl(p_subinventory, oh.subinventory_code) --'MAIN'
                  --  1.1  17/12/2014  Dalit A. Raviv
               AND oh.subinventory_code = subinv.secondary_inventory_name
               AND oh.organization_id = subinv.organization_id
               AND subinv.availability_type =
                   nvl(p_available_type, subinv.availability_type) -- 1 = netable
                  --
               AND p_locator_code IS NULL); --'2E'

    RETURN l_on_hand_qty;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_oh_qty;

  ----------------------------------------------------------
  -- Returns OH quantity for specified item, organization, subinv, locator
  ----------------------------------------------------------
  -- Gabriel
  -- 24/12/2009
  --
  ----------------------------------------------------------
  FUNCTION get_oh_qty_by_id(p_inventory_item_id NUMBER,
                            p_organization_id   NUMBER,
                            p_subinventory      VARCHAR2 DEFAULT NULL,
                            p_locator_id        NUMBER DEFAULT NULL)
    RETURN NUMBER IS

    l_on_hand_qty NUMBER := 0;

  BEGIN

    SELECT SUM(oh.transaction_quantity) on_hand_qty
      INTO l_on_hand_qty
      FROM mtl_onhand_quantities_detail oh
     WHERE oh.inventory_item_id = p_inventory_item_id
       AND oh.organization_id = p_organization_id
       AND oh.subinventory_code = nvl(p_subinventory, oh.subinventory_code)
       AND nvl(oh.locator_id, -1) =
           nvl(p_locator_id, nvl(oh.locator_id, -1));

    RETURN l_on_hand_qty;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;

  END;
  -------------------------------------------------------
  -- get_oh_qty_STRING
  ------------------------------------------------------
  FUNCTION get_oh_qty_string(p_inventory_item_id NUMBER,
                             p_organization_id   NUMBER,
                             p_subinventory_list VARCHAR2) RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT subinventory_code, SUM(oh.transaction_quantity) on_hand_qty

        FROM mtl_onhand_quantities_detail oh
       WHERE oh.inventory_item_id = p_inventory_item_id
         AND oh.organization_id = p_organization_id
         AND (p_subinventory_list = 'All' OR
             instr(p_subinventory_list, ',' || oh.subinventory_code || ',') > 0)
       GROUP BY oh.subinventory_code; -- = nvl(p_subinventory, oh.subinventory_code)

    l_ret VARCHAR2(2000);
  BEGIN

    FOR i IN c LOOP
      l_ret := l_ret || chr(10) || i.subinventory_code || ':' ||
               i.on_hand_qty;

    END LOOP;
    RETURN ltrim(l_ret, chr(10));
  END;

  ----------------------------------------------------------
  -- Returns customer details for an identifier
  --  received from Supply/Demand form
  ----------------------------------------------------------
  FUNCTION get_cust_4sup_dem(p_identifier VARCHAR2) RETURN VARCHAR2 IS

    l_ret        VARCHAR2(400);
    l_account_id NUMBER;

  BEGIN
    -- parse the identifier and get account id
    SELECT ooha.sold_to_org_id
      INTO l_account_id
      FROM oe_order_headers_all ooha
     WHERE order_number =
           substr(p_identifier, 1, instr(p_identifier, '.', 1, 1) - 1);

    SELECT hca.account_number || ', ' || hp.party_name
      INTO l_ret
      FROM hz_cust_accounts hca, hz_parties hp
     WHERE cust_account_id = l_account_id
       AND hca.party_id = hp.party_id;

    RETURN l_ret;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_cust_4sup_dem;

  ----------------------------------------------------------
  -- get_revision_2receive
  -- Returns item revision for the receiving
  ----------------------------------------------------------
  FUNCTION get_revision_2receive(p_inventory_item_id NUMBER,
                                 p_organization_id   NUMBER,
                                 p_po_line           NUMBER) RETURN VARCHAR2 IS

    l_ret         VARCHAR2(50);
    l_po_max_date DATE;

  BEGIN

    SELECT nvl(MAX(poll.need_by_date), SYSDATE)
      INTO l_po_max_date
      FROM po_line_locations_all poll
     WHERE poll.po_line_id = p_po_line; -- RCV_TRANSACTION.PO_LINE_ID

    SELECT MAX(a.revision)
      INTO l_ret
      FROM mtl_item_revisions a
     WHERE a.inventory_item_id = p_inventory_item_id
       AND -- RCV_TRANSACTION.ITEM_ID
           a.organization_id = p_organization_id
       AND -- GLOBAL.ORG_ID
           a.effectivity_date =
           (SELECT MAX(b.effectivity_date)
              FROM mtl_item_revisions b
             WHERE b.inventory_item_id = a.inventory_item_id
               AND b.organization_id = a.organization_id
               AND l_po_max_date > b.effectivity_date);

    RETURN l_ret;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_revision_2receive;
  -------------------------------------------------
  -- get_revision4date
  -------------------------------------------------
  FUNCTION get_revision4date(p_inventory_item_id NUMBER,
                             p_organization_id   NUMBER,
                             p_date              DATE) RETURN VARCHAR2 IS

    l_ret VARCHAR2(50);
    --l_po_max_date DATE;

  BEGIN

    SELECT a.revision
      INTO l_ret
      FROM mtl_item_revisions a
     WHERE a.organization_id = p_organization_id
       AND a.inventory_item_id = p_inventory_item_id
       AND a.effectivity_date =
           (SELECT MAX(b.effectivity_date)
              FROM mtl_item_revisions b
             WHERE b.inventory_item_id = a.inventory_item_id
               AND b.organization_id = a.organization_id
               AND p_date >= b.effectivity_date);

    RETURN l_ret;

  END;

  ---------------------------------------------------
  FUNCTION get_item_cost(p_inventory_item_id NUMBER,
                         p_organization_id   NUMBER) RETURN NUMBER IS

    l_item_cost cst_item_costs.item_cost%TYPE;

  BEGIN

    SELECT item_cost
      INTO l_item_cost
      FROM cst_item_costs cic
     WHERE cic.inventory_item_id = p_inventory_item_id
       AND cic.organization_id = p_organization_id
       AND cic.cost_type_id = fnd_profile.value('XX_COST_TYPE'); ---2;

    RETURN l_item_cost;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  ----------------------------------------------
  -- get_item_material_cost
  ----------------------------------------------
  FUNCTION get_item_material_cost(p_inventory_item_id NUMBER,
                                  p_organization_id   NUMBER) RETURN NUMBER IS

    l_item_cost cst_item_costs.material_cost%TYPE;

  BEGIN

    SELECT cic.material_cost
      INTO l_item_cost
      FROM cst_item_costs cic
     WHERE cic.inventory_item_id = p_inventory_item_id
       AND cic.organization_id = p_organization_id
       AND cic.cost_type_id = fnd_profile.value('XX_COST_TYPE'); ---2;

    RETURN l_item_cost;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  -----------------------------------------------------
  -- get_trx_type_loc_validation
  ----------------------------------------------------
  FUNCTION get_trx_type_loc_validation(p_trx_type_id NUMBER) RETURN VARCHAR2 IS

    l_validation_val VARCHAR2(1);

  BEGIN

    SELECT nvl(attribute3, 'N')
      INTO l_validation_val
      FROM mtl_transaction_types
     WHERE transaction_type_id = p_trx_type_id;

    RETURN l_validation_val;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_trx_type_loc_validation;

  ----------------------------------
  -- get_item_seg
  --------------------------------
  FUNCTION get_item_segment(p_item_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 IS
    l_seg mtl_system_items_b.segment1%TYPE;
  BEGIN
    SELECT msib.segment1
      INTO l_seg
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN l_seg;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END;

  ---------------------------------------
  -- get_MFG_mfg_part
  -------------------------------------
  FUNCTION get_mfg_mfg_part(p_item_id NUMBER, p_organization_id NUMBER)
    RETURN VARCHAR2 IS

    CURSOR c_mfg IS
      SELECT mfg.manufacturer_name || '-' || mfg.mfg_part_num mfg
        FROM mtl_mfg_part_numbers_all_v mfg
       WHERE mfg.inventory_item_id = p_item_id
         AND mfg.organization_id = p_organization_id;
    l_mfg_desc VARCHAR2(2000);
  BEGIN

    FOR i IN c_mfg LOOP

      l_mfg_desc := l_mfg_desc || chr(13) || i.mfg;

    END LOOP;

    RETURN ltrim(l_mfg_desc, chr(13));

  END;

  --------------------------------------
  -- get_Item_full_lead_time
  -------------------------------------
  FUNCTION get_item_full_leadtime(p_item_id NUMBER, p_org_id NUMBER)
    RETURN NUMBER IS
    l_lead_time NUMBER;
  BEGIN
    SELECT msib.full_lead_time
      INTO l_lead_time
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN l_lead_time;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END;

  ---------------------------------------------
  --   get_item_make_buy_code
  --------------------------------------------
  FUNCTION get_item_make_buy_code(p_item_id NUMBER, p_org_id NUMBER)
    RETURN NUMBER IS
    l_planning_make_buy_code mtl_system_items_b.planning_make_buy_code%TYPE;
  BEGIN
    SELECT msib.planning_make_buy_code
      INTO l_planning_make_buy_code
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN l_planning_make_buy_code;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ---------------------------------------------
  --   get_buyer_id
  --------------------------------------------
  FUNCTION get_buyer_id(p_item_id NUMBER, p_org_id NUMBER) RETURN NUMBER IS
    l_buyer_id mtl_system_items_b.buyer_id%TYPE;
  BEGIN
    SELECT msib.buyer_id
      INTO l_buyer_id
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN l_buyer_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_sourcing_buyer_id
  --  create by:       Dovik
  --  Revision:        1.0
  --  creation date:   05/Mar/2017
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  05/Mar/2017   Dovik.Pollak      CHG0040117 - Cut the PO
  --------------------------------------------------------------------
  FUNCTION get_sourcing_buyer_id(p_item_id NUMBER, p_org_id NUMBER)
    RETURN NUMBER IS
    l_sourcing_buyer_id mtl_system_items_b.attribute27%TYPE;
  BEGIN
    SELECT nvl(msib.attribute27, msib.buyer_id)
      INTO l_sourcing_buyer_id
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN l_sourcing_buyer_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_sourcing_buyer_id;

  -----------------------------------------------
  -- check_hasp_item_allowed for user
  ------------------------------------------------
  FUNCTION check_disallowed_hasp_in_req(p_requisition_header_id NUMBER,
                                        p_user_id               NUMBER)
    RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT rl.item_description,
             rl.item_id,
             rl.destination_organization_id
        FROM po_requisition_lines_all rl
       WHERE rl.requisition_header_id = p_requisition_header_id
         AND nvl(rl.cancel_flag, 'N') = 'N';

  BEGIN
    FOR i IN c LOOP
      IF check_hasp_item_allowed(i.item_id,
                                 i.destination_organization_id,
                                 p_user_id) = 'N' THEN
        RETURN i.item_description;
      END IF;

    END LOOP;
    RETURN NULL;
  END;

  ------------------------------------------
  -- check_hasp_item_allowed
  ------------------------------------------
  FUNCTION check_hasp_item_allowed(p_inventory_item_id NUMBER,
                                   p_organization_id   NUMBER,
                                   p_user_id           NUMBER)
    RETURN VARCHAR2 IS
    l_tmp NUMBER(1);
    CURSOR c IS
      SELECT t.attribute2, t.cross_reference
        FROM mtl_cross_references_v t
       WHERE t.cross_reference_type = 'hasp'
         AND t.inventory_item_id = p_inventory_item_id
         AND nvl(t.organization_id, p_organization_id) = p_organization_id;
    --  AND attribute2 = p_user_id;
    --   AND t.cross_reference = 'Yes';
  BEGIN

    FOR i IN c LOOP
      l_tmp := 1; -- hasp item control
      IF nvl(i.attribute2, -1) = p_user_id /* AND
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            nvl(i.cross_reference, 'N') = 'Yes'*/
       THEN
        RETURN 'Y';
      END IF;

    END LOOP;
    IF l_tmp = 1 THEN
      RETURN 'N';
    ELSE

      RETURN 'Y';
    END IF;
    --  EXCEPTION
    --
    --WHEN OTHERS THEN
    --   RETURN 'N';

  END;

  ------------------------------------------------------
  -- is_sub_inventory_asset
  ------------------------------------------------------
  FUNCTION is_sub_inventory_asset(p_secondary_inventory_name VARCHAR2,
                                  p_organization_id          NUMBER)
    RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN

    SELECT t.asset_inventory
      INTO l_tmp
      FROM mtl_secondary_inventories t
     WHERE secondary_inventory_name = p_secondary_inventory_name
       AND t.organization_id = p_organization_id;

    IF l_tmp = 1 THEN
      RETURN 1;
    ELSE
      RETURN 0;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  --------------------------------------------------------------------
  -- check_asset_sub_inv_status
  -- return value
  -- M = mix
  -- A = all Asset
  -- N = all non asset
  ---------------------------------------------------------------------
  FUNCTION check_asset_sub_inv_status --(p_delivery_id NUMBER) -- CHG0041294 - on 06/03/2018 for delivery id to name change
  (p_delivery_name VARCHAR2) RETURN VARCHAR2 IS
    l_non_asset NUMBER;
    l_asset     NUMBER;

    no_delivery_found EXCEPTION;
  BEGIN

    SELECT COUNT(*)
      INTO l_non_asset
      FROM wsh_deliverables_v t
     WHERE t.delivery_id = nvl(xxinv_trx_in_pkg.get_delivery_id(p_delivery_name),
                               p_delivery_name) --p_delivery_id -- CHG0041294 on 06/03/2018 for delivery id to name change
       AND t.subinventory IS NOT NULL
       AND is_sub_inventory_asset(t.subinventory, t.organization_id) = 0;

    SELECT COUNT(*)
      INTO l_asset
      FROM wsh_deliverables_v t
     WHERE t.delivery_id = nvl(xxinv_trx_in_pkg.get_delivery_id(p_delivery_name),
                               p_delivery_name) --p_delivery_id -- CHG0041294 on 06/03/2018 for delivery id to name change
       AND t.subinventory IS NOT NULL
       AND is_sub_inventory_asset(t.subinventory, t.organization_id) = 1;

    IF l_non_asset > 0 AND l_asset > 0 THEN
      RETURN 'M';
    ELSIF l_non_asset > 0 AND l_asset = 0 THEN
      RETURN 'N';

    ELSIF l_non_asset = 0 AND l_asset > 0 THEN
      RETURN 'A';
    ELSE
      RETURN 'NO SUB INVENTORY FOR DLY';
    END IF;

  END;

  -------------------------------------
  -- is_hazard_item
  -------------------------------------
  FUNCTION is_hazard_item(p_item_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2 IS
    l_hazardous_material_flag mtl_system_items_b.hazardous_material_flag%TYPE;
  BEGIN
    SELECT msib.hazardous_material_flag
      INTO l_hazardous_material_flag
      FROM mtl_system_items_b msib
     WHERE msib.inventory_item_id = p_item_id
       AND msib.organization_id = p_org_id;

    RETURN nvl(l_hazardous_material_flag, 'N');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------------------------
  -- IS_TPL_SUB
  ----------------------------------------------
  FUNCTION is_tpl_sub(p_organization_id    NUMBER,
                      p_sub_inventory_code VARCHAR2) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);

  BEGIN
    SELECT 'Y'
      INTO l_tmp
      FROM mtl_secondary_inventories si
     WHERE nvl(si.attribute4, 'N') = 'Y'
       AND si.organization_id = p_organization_id /*Parameter*/
       AND si.secondary_inventory_name = p_sub_inventory_code; /*Parameter*/

    RETURN l_tmp;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';

  END;

  --------------------------------------------------------------------
  --  name:            is_fdm_item
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   11.02.2013
  --------------------------------------------------------------------
  --  purpose :        indication for ssys item Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11.02.2013  yuval tal         initial ver
  --  1.1  27/03/2014  Dalit A. Raviv    add if for better performance
  --  1.2  29/05/2014  Dalit A. Raviv    the logic of is FDM item transfer into other
  --                                     package and logic changed.
  --                                     we do not look at attribute8 = 'FDM' anymore
  --                                     we look at segment from the category.
  --------------------------------------------------------------------
  FUNCTION is_fdm_item(p_item_id     NUMBER DEFAULT NULL,
                       p_item_number VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS

    l_item_id NUMBER := 0;
    l_is_fdm  VARCHAR2(10) := NULL;
  BEGIN
    IF p_item_number IS NOT NULL AND p_item_id IS NULL THEN
      SELECT inventory_item_id
        INTO l_item_id
        FROM mtl_system_items_b msi
       WHERE msi.segment1 = p_item_number
         AND msi.organization_id = 91;
    ELSE
      l_item_id := p_item_id;
    END IF;

    l_is_fdm := xxinv_item_classification.is_item_fdm(l_item_id);
    RETURN l_is_fdm;

  EXCEPTION

    WHEN OTHERS THEN
      RETURN 'N';
  END;

  ----------------------------------------------------
  -- get_item_supplier
  --
  -- return recommended supplier vendor site id for item
  -----------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------    --------------  ---------------------
  --     1.0  14.02.2013   yuval tal      initial
  -----------------------------------------------------------
  FUNCTION get_item_supplier(p_organization_id NUMBER, p_item_id NUMBER)
    RETURN NUMBER IS

    CURSOR c IS
      SELECT msso.vendor_site_id
        FROM mrp_sr_assignments msa,
             mrp_sourcing_rules msr,
             mrp_sr_receipt_org msro,
             mrp_sr_source_org  msso
       WHERE msa.sourcing_rule_id = msr.sourcing_rule_id
         AND msr.sourcing_rule_id = msro.sourcing_rule_id
         AND msro.sr_receipt_id = msso.sr_receipt_id
         AND msa.inventory_item_id = p_item_id
         AND msa.organization_id = p_organization_id;

    l_vendor_site_id NUMBER;
  BEGIN

    OPEN c;
    FETCH c
      INTO l_vendor_site_id;
    CLOSE c;

    RETURN l_vendor_site_id;

  END;

  ----------------------------------------------------
  -- get_item_desc_tl
  -- purpose : japan project
  -- return item description according to OU
  -----------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------    --------------  ---------------------
  --     1.0  14.02.2013   yuval tal      initial
  --     1.1  13.05.2013   Vitaly         cr 724 support japan description
  -----------------------------------------------------------
  FUNCTION get_item_desc_tl(p_item_id         NUMBER,
                            p_organization_id NUMBER,
                            p_org_id          NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_language mtl_system_items_tl.language%TYPE;
    l_name     mtl_system_items_tl.description%TYPE;
  BEGIN

    l_language := xxhz_util.get_ou_lang(nvl(p_org_id,
                                            xxhz_util.get_inv_org_ou(p_organization_id)));
    IF l_language = 'JA' THEN
      -----
      BEGIN
        SELECT t.description
          INTO l_name
          FROM mtl_categories_v      t,
               mtl_item_categories_v ic,
               mtl_category_sets     cset
         WHERE t.structure_name = 'SSYS Japan Pack Breakdown'
           AND cset.category_set_name = 'Japan Resin Pack Breakdown'
           AND ic.structure_id = t.structure_id
           AND ic.category_id = t.category_id
           AND ic.category_set_id = cset.category_set_id
           AND ic.inventory_item_id = p_item_id ----
           AND ic.organization_id = nvl(p_organization_id, 91); ----
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      ------
    END IF;

    IF l_name IS NULL THEN
      SELECT t.description
        INTO l_name
        FROM mtl_system_items_tl t
       WHERE t.language = l_language ---
         AND t.organization_id = p_organization_id ---
         AND t.inventory_item_id = p_item_id; ---
    END IF;

    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END;

  ---------------------------------------------------------------------------
  -- get_qty_factor_jpn
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  13/05/2013     Vitaly              cr 724 support japan description
  ---------------------------------------------------------------------------
  FUNCTION get_qty_factor_jpn(p_item_id         NUMBER,
                              p_organization_id NUMBER DEFAULT NULL,
                              p_org_id          NUMBER DEFAULT NULL)
    RETURN NUMBER IS
    l_qty_factor NUMBER := 1;

  BEGIN

    SELECT t.segment1 factor
      INTO l_qty_factor
      FROM mtl_categories_v      t,
           mtl_item_categories_v ic,
           mtl_category_sets     cset
     WHERE t.structure_name = 'SSYS Japan Pack Breakdown'
       AND cset.category_set_name = 'Japan Resin Pack Breakdown'
       AND ic.structure_id = t.structure_id
       AND ic.category_id = t.category_id
       AND ic.category_set_id = cset.category_set_id
       AND ic.inventory_item_id = p_item_id ----
       AND ic.organization_id = nvl(p_organization_id, 91); ----

    RETURN nvl(l_qty_factor, 1);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END get_qty_factor_jpn;

  ---------------------------------------------------------------------------
  -- get_print_inv_uom_tl
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --           02/06/2013 Vitaly          cr 731 support japan description
  -- 1.1       28.8.2013  yuval tal       CR990 support uom for factor items Japan
  ---------------------------------------------------------------------------
  FUNCTION get_print_inv_uom_tl(p_uom_code        VARCHAR2,
                                p_item_id         NUMBER,
                                p_organization_id NUMBER,
                                p_org_id          NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_language   mtl_system_items_tl.language%TYPE;
    l_result_uom VARCHAR2(50);
    l_uom_jpn    VARCHAR2(50);

  BEGIN
    l_language := xxhz_util.get_ou_lang(nvl(p_org_id,
                                            xxhz_util.get_inv_org_ou(p_organization_id)));
    IF l_language = 'JA' THEN
      -----Get UOM Code for Japan---------
      --- cr990 -- get uom for item belong to structure SSYS Japan Pack Breakdown
      BEGIN

        SELECT xxobjt_general_utils_pkg.get_valueset_desc('JP UOM sign',
                                                          t.segment3) uom_code
          INTO l_uom_jpn
          FROM mtl_categories_v      t,
               mtl_item_categories_v ic,
               mtl_category_sets     cset
         WHERE t.structure_name = 'SSYS Japan Pack Breakdown'
           AND cset.category_set_name = 'Japan Resin Pack Breakdown'
           AND ic.structure_id = t.structure_id
           AND ic.category_id = t.category_id
           AND ic.category_set_id = cset.category_set_id
           AND ic.inventory_item_id = p_item_id ----
           AND ic.organization_id = nvl(p_organization_id, 91);

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      IF l_uom_jpn IS NULL THEN
        BEGIN
          SELECT t.description
            INTO l_uom_jpn
            FROM mtl_categories_v t, mtl_item_categories_v ic
           WHERE t.structure_name = 'SSYS Japan UOM sign'
             AND ic.category_id = t.category_id
             AND ic.inventory_item_id = p_item_id ---
             AND ic.organization_id = p_organization_id; ----
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
      -----
    END IF;

    IF l_uom_jpn IS NULL THEN
      ---IF l_language = 'JA' THEN
      ---Translate Japan----
      SELECT t.unit_of_measure_tl
        INTO l_result_uom
        FROM mtl_units_of_measure_tl t
       WHERE t.uom_code = p_uom_code -----
         AND t.language = l_language; -----
      ---AND t.language = 'JA';
      ---END IF;
    END IF;
    RETURN nvl(l_uom_jpn, l_result_uom);

  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_uom_code;
  END get_print_inv_uom_tl;

  --------------------------------------------------------------------
  --  name:            is_fdm_system_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/06/2013
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/06/2013  Dalit A. Raviv    initial build
  -- 1.1   30.4.17     yuval tal         CHG0040061 - change logic to point to xxinv_item_classification
  --------------------------------------------------------------------
  FUNCTION is_fdm_system_item(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS

    /*   l_return VARCHAR2(10) := NULL;
    BEGIN
      SELECT 'Y'
      INTO   l_return
      FROM   mtl_item_categories_v mic,
             mtl_categories_b      mcb,
             mtl_system_items_b    msib
      WHERE  mic.organization_id = 91
      AND    mcb.category_id = mic.category_id
      AND    msib.inventory_item_id = mic.inventory_item_id
      AND    msib.organization_id = 91
      AND    mcb.attribute8 = 'FDM'
      AND    mic.category_set_name = 'Main Category Set'
      AND    mic.segment1 = 'Systems'
      AND    msib.inventory_item_id = p_inventory_item_id;

      RETURN 'Y';
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
      WHEN too_many_rows THEN
        RETURN 'Y';*/
    l_master_org_id NUMBER;
  BEGIN

    l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
    IF xxinv_item_classification.is_system_item(p_inventory_item_id,
                                                l_master_org_id) = 'Y' AND
       xxinv_item_classification.is_item_fdm(p_inventory_item_id,
                                             l_master_org_id) = 'Y' THEN
      RETURN 'Y';

    ELSE
      RETURN 'N';
    END IF;

  END is_fdm_system_item;

  --------------------------------------------------------------------
  --  name:            update_group_mark_id
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   30.7.13
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30.7.13     yuval tal         initial build - CUST439 - INV General\439 Delete Group Mark ID
  --                                     called by concurrent : XX Inv Update group Mark Id /XXINVGRPUPD
  --------------------------------------------------------------------
  PROCEDURE update_group_mark_id(p_errbuff       OUT VARCHAR2,
                                 p_errcode       OUT VARCHAR2,
                                 p_serial_number VARCHAR2) IS
  BEGIN

    p_errcode := 0;
    UPDATE mtl_serial_numbers ms
       SET ms.group_mark_id    = NULL,
           ms.line_mark_id     = NULL,
           ms.lot_line_mark_id = NULL
     WHERE ms.serial_number = p_serial_number;

    fnd_file.put_line(fnd_file.log, SQL%ROWCOUNT || ' Rows were updated');
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      p_errcode := 2;
      p_errbuff := 'Error in xxinv_utils_pkg.update_group_mark_id ' ||
                   SQLERRM;
  END;

  ---------------------------------------------------
  FUNCTION get_category_value(p_category_set_id   NUMBER,
                              p_inventory_item_id NUMBER,
                              p_org_id            NUMBER) RETURN VARCHAR2 IS
    --
    l_category VARCHAR2(150);
  BEGIN

    SELECT mc.concatenated_segments
      INTO l_category
      FROM mtl_item_categories mic, mtl_categories_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.category_set_id = p_category_set_id
       AND mic.inventory_item_id = p_inventory_item_id
       AND mic.organization_id = p_org_id;

    RETURN(l_category);

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  -- ---------------------------------------------------------------------------
  -- Modification History
  -- Date     By        Description
  -- ---------------------------------------------------------------------------
  -- 04.22.14 smisra    Created this procedure for CHG31742
  --                    This function is called by formula CF_TARIFF_CODEFORMULA
  --                    of report XXWSHRDINV.rdf and XXSSUS_WSHRDINV.rdf
  -- ---------------------------------------------------------------------------
  FUNCTION get_tariff_code(p_org_id            IN NUMBER,
                           p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_tariff_code VARCHAR2(150);
  BEGIN

    l_tariff_code := get_category_value(1100000121,
                                        p_inventory_item_id,
                                        p_org_id);
    IF l_tariff_code IS NULL THEN
      SELECT msi.attribute3
        INTO l_tariff_code
        FROM mtl_system_items_b msi, mtl_parameters mp
       WHERE msi.inventory_item_id = p_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_id = mp.master_organization_id;
    END IF;
    RETURN l_tariff_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            GET_STD_CST_BSD_ORGS_IN_LOOKUP
  --  create by:       Sandeep Akula
  --  Revision:        1.0
  --  creation date:   28/04/2014
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/04/2014  Sandeep Akula    initial build
  --                                    get Standard Cost of an Item based on the Inventory Organizations order in Lookup XXQP_STD_COST_INV_ORGS_ORDER(CHG0031469)
  --                                    Used in QP_CUSTOM Package
  --------------------------------------------------------------------
  FUNCTION get_std_cst_bsd_orgs_in_lookup(p_cost_type         IN VARCHAR2,
                                          p_lookup_type       IN VARCHAR2,
                                          p_order             IN VARCHAR2,
                                          p_inventory_item_id IN NUMBER)
    RETURN NUMBER IS
    l_std_cost NUMBER := '';
  BEGIN

    BEGIN
      SELECT cic.item_cost
        INTO l_std_cost
        FROM cst_item_costs      cic,
             cst_cost_types      cct,
             mtl_system_items_vl msi,
             mtl_parameters      mp
       WHERE cic.cost_type_id = cct.cost_type_id
         AND cic.inventory_item_id = msi.inventory_item_id
         AND cic.organization_id = msi.organization_id
         AND msi.costing_enabled_flag = 'Y'
         AND upper(cct.cost_type) = upper(p_cost_type)
         AND msi.organization_id = mp.organization_id
         AND msi.inventory_item_id = p_inventory_item_id
         AND mp.organization_code IN
             (SELECT upper(flvv.lookup_code)
                FROM fnd_lookup_types_vl fltv, fnd_lookup_values_vl flvv
               WHERE fltv.security_group_id = flvv.security_group_id
                 AND fltv.view_application_id = flvv.view_application_id
                 AND fltv.lookup_type = flvv.lookup_type
                 AND fltv.lookup_type = upper(p_lookup_type)
                 AND flvv.meaning = p_order
                 AND trunc(SYSDATE) BETWEEN trunc(flvv.start_date_active) AND
                     nvl(flvv.end_date_active, trunc(SYSDATE)));
    EXCEPTION
      WHEN OTHERS THEN
        l_std_cost := NULL;
    END;
    RETURN(l_std_cost);
  END get_std_cst_bsd_orgs_in_lookup;

  ------------------------------------------------------------------
  --get_item_catalog_value
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/06/2014  yuval tal         CHG0032388 - initial
  ---------------------------------------------------------------------
  FUNCTION get_item_catalog_value(p_organization_id       NUMBER,
                                  p_inventoy_item_id      NUMBER,
                                  p_item_catalog_group_id NUMBER,
                                  p_element_name          VARCHAR2)
    RETURN VARCHAR2 IS
    l_tmp mtl_descr_element_values_v.element_value%TYPE;
  BEGIN

    SELECT mde.element_value
      INTO l_tmp
      FROM mtl_system_items_b msib, mtl_descr_element_values_v mde
     WHERE msib.inventory_item_id = p_inventoy_item_id
       AND msib.organization_id = p_organization_id
       AND mde.inventory_item_id = msib.inventory_item_id
       AND mde.item_catalog_group_id = msib.item_catalog_group_id
       AND msib.item_catalog_group_id = 2
       AND mde.element_name = p_element_name;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_category_segment
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   11.6.14
  --------------------------------------------------------------------
  --  purpose :CHG0032103
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11.6.14  yuval tal            initial build - change CHG0032103:Add Item classification categories to modifiers
  --------------------------------------------------------------------
  FUNCTION get_category_segment(p_segment_name      VARCHAR2,
                                p_category_set_id   NUMBER,
                                p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_seg_value VARCHAR2(240);
    l_cur       SYS_REFCURSOR;

  BEGIN
    OPEN l_cur FOR 'SELECT ' || p_segment_name || '
      FROM mtl_item_categories mic, mtl_categories_kfv mc
     WHERE mic.category_id = mc.category_id
       AND mic.category_set_id = :1
       AND mic.inventory_item_id = :2
       AND mic.organization_id = xxinv_utils_pkg.get_master_organization_id'
      USING p_category_set_id, p_inventory_item_id;
    LOOP
      FETCH l_cur
        INTO l_seg_value;
      --dbms_output.put_line('l_seg_value=' || l_seg_value);
      EXIT WHEN l_cur%NOTFOUND;
    END LOOP;
    CLOSE l_cur;

    RETURN l_seg_value;

  END;

  --------------------------------------------------------------------
  --  name:               get_related_item
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      09/11/2014
  --  Description:        return the relate item to specific item (by item id or item number)
  --                      p_is_fdm -> N / Y
  --                      p_entity -> ID / CODE, ID will return the item id, CODE will return segment1
  --                      CHG0034134
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/11/2014    Dalit A. Raviv  CHG0034134 initial build
  --  1.1   28/Feb/2017 Lingaraj Sarangi  INC0088394 - Add a Returnable  P/N to the Return form
  --                                      get_related_item - Function Modified to show all releated Items
  --                                      rather then restricting to only FDM Item
  --------------------------------------------------------------------
  FUNCTION get_related_item(p_item_number IN VARCHAR2,
                            p_item_id     IN NUMBER,
                            p_is_fdm      IN VARCHAR2 DEFAULT 'N',
                            p_entity      IN VARCHAR2 DEFAULT 'ID')
    RETURN VARCHAR2 IS

    CURSOR pop_c IS
      SELECT msir.segment1, mri.inventory_item_id
        FROM mtl_related_items  mri,
             fnd_lookup_values  flv,
             mtl_system_items_b msir
       WHERE (mri.end_date IS NULL OR mri.end_date > SYSDATE)
         AND flv.lookup_type = 'MTL_RELATIONSHIP_TYPES'
         AND flv.language = 'US'
         AND flv.meaning = 'Related'
         AND flv.lookup_code = mri.relationship_type_id
         AND mri.inventory_item_id = nvl(p_item_id, mri.inventory_item_id)
         AND msir.segment1 = nvl(p_item_number, msir.segment1)
         AND mri.organization_id = 91
         AND mri.organization_id = msir.organization_id
         AND msir.inventory_item_id = mri.related_item_id
         AND ((p_is_fdm = 'Y' AND
             xxinv_utils_pkg.is_fdm_item(mri.related_item_id) = 'Y') OR
             (p_is_fdm = 'N'))
      --1.1 Commented on 28th Feb 2017 for INC0088394, this was restricted to only Fdm Related Item
      /*AND    xxinv_utils_pkg.is_fdm_item(mri.related_item_id) = 'Y'*/
      ;

    l_item_number mtl_system_items_b.segment1%TYPE;
    l_item_id     mtl_system_items_b.inventory_item_id%TYPE;
  BEGIN

    FOR pop_r IN pop_c LOOP
      l_item_number := pop_r.segment1;
      l_item_id     := pop_r.inventory_item_id;
      EXIT;
    END LOOP;

    IF p_entity = 'ID' THEN
      RETURN l_item_id;
    ELSE
      RETURN l_item_number;
    END IF;
  END get_related_item;

  --------------------------------------------------------------------
  --  name:            get_org_code
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034558
  --                   get organization code by id
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0034558
  --------------------------------------------------------------------
  FUNCTION get_org_code(p_organization_id IN NUMBER) RETURN VARCHAR2 IS

    l_org_code VARCHAR2(10);
  BEGIN
    SELECT mp.organization_code
      INTO l_org_code
      FROM mtl_parameters mp
     WHERE mp.organization_id = p_organization_id;

    RETURN l_org_code;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_org_code;

  --------------------------------------------------------------------
  --  name:            get_SP_Technical_category
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   10/06/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332
  --                   get technical category of an item. If p_organization_id
  --                   is null, use master organization.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/06/2015  Michal Tzvik    initial version
  --  1.1  27/Jul/2016 Lingaraj Sarangi  CHG0038799 - New fields in SP catalog PZ and Oracle
  --------------------------------------------------------------------
  FUNCTION get_sp_technical_category(p_inventory_item_id NUMBER,
                                     p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_category mtl_categories_b_kfv.segment3%TYPE;
  BEGIN
    SELECT mc.segment3
      INTO l_category
      FROM mtl_item_categories  mic,
           mtl_category_sets_tl mcst,
           mtl_categories_b_kfv mc
     WHERE 1 = 1
          -- AND    mcst.category_set_name = 'Main Category Set'  -- Commented on 27th july 2016 CHG0038799
       AND mcst.category_set_name = 'CS Category Set' -- 1.1 Added 27/July/2016 CHG0038799
       AND mcst.language = 'US'
       AND mic.category_set_id = mcst.category_set_id
       AND mic.inventory_item_id = p_inventory_item_id
       AND mic.organization_id =
           nvl(p_organization_id,
               xxinv_utils_pkg.get_master_organization_id)
       AND mic.category_id = mc.category_id;

    RETURN l_category;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_sp_technical_category;

  --------------------------------------------------------------------
  --  name:            is_aerospace_item
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   09/21/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0036213
  --                   Check if an item is aerospace related
  --                   Currently this is achieved by matching item segment1
  --                   against a fixed set of values in a custom value set
  --------------------------------------------------------------------
  --  ver  date        name                      desc
  --  1.0  09/21/2015  Diptasurjya Chatterjee    initial version
  --------------------------------------------------------------------
  FUNCTION is_aerospace_item(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_order_aerospace_item_count NUMBER := 0;
  BEGIN
    SELECT COUNT(*)
      INTO l_order_aerospace_item_count
      FROM fnd_flex_values     ffv,
           fnd_flex_value_sets ffvs,
           mtl_system_items_b  msib
     WHERE msib.inventory_item_id = p_inventory_item_id
       AND msib.organization_id = 91
       AND ffvs.flex_value_set_name = 'XXOM_AEROSPACE_ITEMS'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND msib.segment1 = ffv.flex_value
       AND ffv.enabled_flag = 'Y';

    IF l_order_aerospace_item_count > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get_weight_uom_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/21/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   Get item id return item weight_uom
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/21/2015  Dalit A. Raviv    initial version
  --------------------------------------------------------------------
  FUNCTION get_weight_uom_code(p_inventory_item_id NUMBER,
                               p_organization_id   NUMBER) RETURN VARCHAR2 IS

    l_weight_uom VARCHAR2(3);
  BEGIN
    SELECT msi.weight_uom_code
      INTO l_weight_uom
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = p_organization_id;

    RETURN l_weight_uom;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_weight_uom_code;

  --------------------------------------------------------------------
  --  name:            is_item_restricted
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   01-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037886
  --                   Get item id return item is restricted(Y) or not (N)
  --  Business Logic : item category set (DG Restriction Level) will be created and assigned to items at master org level,
  --                   which can have 1 of 2 possible category values
  --                   a.     Restricted
  --                   b.     Non-Restricted
  --                   If an item satisfies point 1 but has no value assigned as part of point 2, we will consider the item as Restricted
  --                   Will return ¿Y¿ if value of item category set DG Restriction Level has category value as Restricted
  --                   Will return ¿Y¿ if item is hazardous and item category DG Restriction Level is not assigned
  --                   Will return ¿N¿ if value of item category DG Restriction Level has category value as Non-Restricted
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07-Mar-2016 Lingaraj Sarangi  initial version
  --------------------------------------------------------------------
  FUNCTION is_item_restricted(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS

    l_restricted_flag VARCHAR2(1) := NULL;
    l_organization_id NUMBER := xxinv_utils_pkg.get_master_organization_id;
  BEGIN

    SELECT decode(mc.segment1, 'R', 'Y', 'N')
      INTO l_restricted_flag
      FROM mtl_item_categories  mic,
           mtl_categories_b_kfv mc,
           mtl_category_sets_vl mcs
     WHERE mic.category_id = mc.category_id
       AND mcs.category_set_name = 'DG Restriction Level'
       AND mcs.category_set_id = mic.category_set_id
       AND mic.inventory_item_id = p_inventory_item_id
       AND mic.organization_id = l_organization_id;

    RETURN l_restricted_flag;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END is_item_restricted;

  --------------------------------------------------------------------
  --  name:            is_item_hazard_restricted
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   01-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037863
  --                   Get item id return item is
  --                   If the Item is Hazard and restricted Return Value (Y)
  --                   If the Item is Hazard and Not restricted Return Value (N)
  --                   If the Item is Non Hazard and * Return Value (N)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07-Mar-2016 Lingaraj Sarangi  initial version
  --------------------------------------------------------------------
  FUNCTION is_item_hazard_restricted(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_organization_id    NUMBER := xxinv_utils_pkg.get_master_organization_id;
    l_is_item_restricted VARCHAR2(1) := NULL;
  BEGIN
    IF xxinv_utils_pkg.is_hazard_item(p_inventory_item_id,
                                      l_organization_id) = 'Y' THEN
      l_is_item_restricted := xxinv_utils_pkg.is_item_restricted(p_inventory_item_id);
      IF l_is_item_restricted IS NULL OR l_is_item_restricted = 'Y' THEN
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;

    ELSE
      RETURN 'N';
    END IF;

  END is_item_hazard_restricted;

  --------------------------------------------------------------------------------------------------
  -- Ver    When        Who      Descr
  -- -----  ----------  -------  -------------------------------------------------------------------
  -- 1.0    21-03-2018  Roman.W  CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --------------------------------------------------------------------------------------------------
  function is_intangible_items(p_inventory_item_id IN NUMBER) return VARCHAR2 is
    --------------------------------
    --    Local Definition
    --------------------------------
    l_count   NUMBER;
    l_ret_val VARCHAR2(300);
    --------------------------------
    --    Code Section
    --------------------------------
  begin

    SELECT count(*)
      INTO l_count
      FROM mtl_system_items_b mtl
     WHERE nvl(mtl.stock_enabled_flag, 'Y') = 'N'
       AND mtl.inventory_item_id = p_inventory_item_id;

    if 0 = l_count then
      l_ret_val := 'N';
    else
      l_ret_val := 'Y';
    end if;

    return l_ret_val;

  end is_intangible_items;

END xxinv_utils_pkg;
/
