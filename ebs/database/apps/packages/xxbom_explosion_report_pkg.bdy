CREATE OR REPLACE PACKAGE BODY xxbom_explosion_report_pkg IS

  g_costing_buy VARCHAR2(20);

  /*==========================================================================+
  |   Copyright (c) 1993 Oracle Corporation Belmont, California, USA          |
  |                          All rights reserved.                             |
  +===========================================================================+
  |                                                                           |
  | File Name    : BOMPEXPL.sql                                               |
  | DESCRIPTION  : This file is a packaged procedure for the exploders.
  |      This package contains 3 different exploders for the
  |      modules it can be called from.  The procedure exploders
  |    calls the correct exploder based on the module option.
  |    Each of the 3 exploders can be called on directly too.
  | Parameters: org_id    organization_id
  |   order_by  1 - Op seq, item seq
  |       2 - Item seq, op seq
  |   grp_id    unique value to identify current explosion
  |       use value from sequence bom_explosion_temp_s
  |   session_id  unique value to identify current session
  |       use value from bom_explosion_temp_session_s
  |   levels_to_explode
  |   bom_or_eng  1 - BOM
  |       2 - ENG
  |   impl_flag 1 - implemented only
  |       2 - both impl and unimpl
  |   explode_option  1 - All
  |       2 - Current
  |       3 - Current and future
  |   module    1 - Costing
  |       2 - Bom
  |       3 - Order entry
  |                               4 - ATO
  |                               5 - WSM
  |   cst_type_id cost type id for costed explosion
  |   std_comp_flag 1 - explode only standard components
  |       2 - all components
  |   expl_qty  explosion quantity
  |   item_id   item id of asembly to explode
  |   list_id   unique id for lists in bom_lists for range
  |   report_option 1 - cost rollup with report
  |       2 - cost rollup no report
  |       3 - temp cost rollup with report
  |   cst_rlp_id  rollup_id
  |   req_id    request id
  |   prgm_appl_id  program application id
  |   prg_id    program id
  |   user_id   user id
  |   lock_flag 1 - do not lock the table
  |       2 - lock the table
  |   alt_rtg_desg  alternate routing designator
  |   rollup_option 1 - single level rollup
  |       2 - full rollup
  |   plan_factor_flag1 - Yes
  |       2 - No
  |   incl_lt_flag    1 - Yes
  |       2 - No
  |   alt_desg  alternate bom designator
  |   rev_date  explosion date YYYY/MM/DD HH24:MI:SS
  |   comp_code concatenated component code lpad 16
  |   err_msg   error message out buffer
  |   error_code  error code out.  returns sql error code
  |       if sql error
  | Revision
        Shreyas Shah  creation
    02/10/94  Shreyas Shah  added multi-org capability from bom_lists
          max_bom_levels of all orgs for multi-org
    03/24/94  Shreyas Shah    added 4 to module parameter so that
          if ATO calls it dont commit but if CST
          calls it then commit data
    10/19/95      Robert Yee      Added lead time flags
  | 09/05/96      Robert Yee      Increase Sort Order Width to 4 from 3       |
  |       (Bills can have >= 1000 components          |
  | 09/20/97      Robert Yee      Use depth first search for loop check       |
  | 04/15/02  Rahul Chitko  Added a new value for module. Module = 5    |
  |                               added for WSM. When the calling application |
  |                               is WSM, the process will only explode sub-  |
  |                               assemblies that are Phantom.
  | 07/14/04  Refai Farook  Modified the depth first logic into breadth first.
  |                         Implemented bulk.
  | 15-Jun-05  Hari Gelli   Reverted the populating the component code to 11.5.10 style.
  +==========================================================================*/
  ----------------------------------------------------------------------------
  -- ver  Date   performer  note
  --------------------------------------------------------------------------
  -- 1.0  6.2.13 YUVAL TAL  CR 675 Job Component Report - work with Primary BOM
  --                        modify explode_assembly_by_date2
  -- 1.1  13.3.14 yuval tal CHG0031420 modify explode_assembly_by_date2 WIP Job Component Report doesn't reflect the right BOM
  ------------------------------------------------------------------------------

  FUNCTION find_parent_make_buy(p_exploded_items_tbl xxbom_exploded_items_tbl_type,
                                p_curr_index         NUMBER,
                                p_curr_sort_order    VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_parent_sort_order bom_explosion_temp.sort_order%TYPE;
  
  BEGIN
  
    l_parent_sort_order := substr(p_curr_sort_order,
                                  1,
                                  length(p_curr_sort_order) - 7);
  
    FOR i IN REVERSE 1 .. p_curr_index - 1 LOOP
    
      IF p_exploded_items_tbl(i).sort_order = l_parent_sort_order THEN
      
        IF p_exploded_items_tbl(i).costing_make_buy = g_costing_buy THEN
          RETURN p_exploded_items_tbl(i).costing_make_buy;
        ELSE
          RETURN p_exploded_items_tbl(i).planning_make_buy_meaning;
        
        END IF;
      END IF;
    
    END LOOP;
  
  END find_parent_make_buy;

  FUNCTION pl_to_sql(p_top_bill_sequence_id      NUMBER,
                     p_top_item_id               NUMBER,
                     p_bill_sequence_id          NUMBER,
                     p_assembly_item_id          NUMBER,
                     p_organization_id           NUMBER,
                     p_component_sequence_id     NUMBER,
                     p_component_item_id         NUMBER,
                     p_plan_level                NUMBER,
                     p_extended_quantity         NUMBER,
                     p_sort_order                VARCHAR2,
                     p_component_yield_factor    NUMBER,
                     p_item_cost                 NUMBER,
                     p_component_quantity        NUMBER,
                     p_optional                  NUMBER,
                     p_component_code            VARCHAR2,
                     p_operation_seq_num         NUMBER,
                     p_parent_bom_item_type      NUMBER,
                     p_wip_supply_type           NUMBER,
                     p_item_num                  NUMBER,
                     p_effectivity_date          DATE,
                     p_disable_date              DATE,
                     p_implementation_date       DATE,
                     p_supply_subinventory       VARCHAR2,
                     p_supply_locator_id         NUMBER,
                     p_component_remarks         VARCHAR2,
                     p_common_bill_sequence_id   NUMBER,
                     p_assembly_item             VARCHAR2,
                     p_assembly_description      VARCHAR2,
                     p_component_item            VARCHAR2,
                     p_component_description     VARCHAR2,
                     p_planning_make_buy_code    NUMBER,
                     p_planning_make_buy_meaning VARCHAR2,
                     p_org_code                  VARCHAR2,
                     p_costing_make_buy          VARCHAR2,
                     p_supply_type               VARCHAR2)
    RETURN xxbom_exploded_items_type IS
    l_exploded_rec xxbom_exploded_items_type;
  BEGIN
    -- initialize the object
    l_exploded_rec                           := xxbom_exploded_items_type(NULL,
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
                                                                          NULL,
                                                                          NULL);
    l_exploded_rec.top_bill_sequence_id      := p_top_bill_sequence_id;
    l_exploded_rec.top_item_id               := p_top_item_id;
    l_exploded_rec.bill_sequence_id          := p_bill_sequence_id;
    l_exploded_rec.assembly_item_id          := p_assembly_item_id;
    l_exploded_rec.organization_id           := p_organization_id;
    l_exploded_rec.component_sequence_id     := p_component_sequence_id;
    l_exploded_rec.component_item_id         := p_component_item_id;
    l_exploded_rec.plan_level                := p_plan_level;
    l_exploded_rec.extended_quantity         := p_extended_quantity;
    l_exploded_rec.sort_order                := p_sort_order;
    l_exploded_rec.component_yield_factor    := p_component_yield_factor;
    l_exploded_rec.item_cost                 := p_item_cost;
    l_exploded_rec.component_quantity        := p_component_quantity;
    l_exploded_rec.optional                  := p_optional;
    l_exploded_rec.component_code            := p_component_code;
    l_exploded_rec.operation_seq_num         := p_operation_seq_num;
    l_exploded_rec.parent_bom_item_type      := p_parent_bom_item_type;
    l_exploded_rec.wip_supply_type           := p_wip_supply_type;
    l_exploded_rec.item_num                  := p_item_num;
    l_exploded_rec.effectivity_date          := p_effectivity_date;
    l_exploded_rec.disable_date              := p_disable_date;
    l_exploded_rec.implementation_date       := p_implementation_date;
    l_exploded_rec.supply_subinventory       := p_supply_subinventory;
    l_exploded_rec.supply_locator_id         := p_supply_locator_id;
    l_exploded_rec.component_remarks         := p_component_remarks;
    l_exploded_rec.common_bill_sequence_id   := p_common_bill_sequence_id;
    l_exploded_rec.assembly_item             := p_assembly_item;
    l_exploded_rec.assembly_description      := p_assembly_description;
    l_exploded_rec.component_item            := p_component_item;
    l_exploded_rec.component_description     := p_component_description;
    l_exploded_rec.planning_make_buy_code    := p_planning_make_buy_code;
    l_exploded_rec.planning_make_buy_meaning := p_planning_make_buy_meaning;
    l_exploded_rec.org_code                  := p_org_code;
    l_exploded_rec.costing_make_buy          := p_costing_make_buy;
    l_exploded_rec.supply_type               := p_supply_type;
  
    RETURN l_exploded_rec;
  
  END pl_to_sql;

  FUNCTION explode_assembly_by_date(p_item_ind NUMBER DEFAULT 1)
    RETURN xxbom_exploded_items_tbl_type IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    /* Declare pl/sql tables for all coulmns in the select list. BULK BIND and INSERT with
    pl/sql table of records work fine in 9i releases but not in 8i. So, the only option is
    to use individual pl/sql table for each column in the cursor select list */
  
    TYPE number_tbl_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  
    TYPE date_tbl_type IS TABLE OF DATE INDEX BY BINARY_INTEGER;
  
    /* Declared seperate tables based on the column size since pl/sql preallocates the memory for the varchar variable
    when it is lesser than 2000 chars */
  
    /*
    TYPE VARCHAR2_TBL_TYPE IS TABLE OF VARCHAR2(2000)
    INDEX BY BINARY_INTEGER;
    */
  
    TYPE varchar2_tbl_type_1 IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_3 IS TABLE OF VARCHAR2(3) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_10 IS TABLE OF VARCHAR2(10) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_20 IS TABLE OF VARCHAR2(20) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_25 IS TABLE OF VARCHAR2(25) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_30 IS TABLE OF VARCHAR2(30) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_40 IS TABLE OF VARCHAR2(40) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_80 IS TABLE OF VARCHAR2(80) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_150 IS TABLE OF VARCHAR2(150) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_240 IS TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_260 IS TABLE OF VARCHAR2(260) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_1000 IS TABLE OF VARCHAR2(1000) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_2000 IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_4000 IS TABLE OF VARCHAR2(4000) INDEX BY BINARY_INTEGER;
  
    top_bill_sequence_id_tbl       number_tbl_type;
    assembly_item_id_tbl           number_tbl_type;
    bill_sequence_id_tbl           number_tbl_type;
    common_bill_sequence_id_tbl    number_tbl_type;
    common_organization_id_tbl     number_tbl_type;
    organization_id_tbl            number_tbl_type;
    component_sequence_id_tbl      number_tbl_type;
    component_item_id_tbl          number_tbl_type;
    basis_type_tbl                 number_tbl_type;
    component_quantity_tbl         number_tbl_type;
    plan_level_tbl                 number_tbl_type;
    extended_quantity_tbl          number_tbl_type;
    sort_order_tbl                 varchar2_tbl_type_2000;
    group_id_tbl                   number_tbl_type;
    top_alternate_designator_tbl   varchar2_tbl_type_10;
    component_yield_factor_tbl     number_tbl_type;
    top_item_id_tbl                number_tbl_type;
    component_code_tbl             varchar2_tbl_type_1000;
    include_in_cost_rollup_tbl     number_tbl_type;
    loop_flag_tbl                  number_tbl_type;
    planning_factor_tbl            number_tbl_type;
    operation_seq_num_tbl          number_tbl_type;
    bom_item_type_tbl              number_tbl_type;
    parent_bom_item_type_tbl       number_tbl_type;
    parent_item_id_tbl             number_tbl_type;
    alternate_bom_designator_tbl   varchar2_tbl_type_10;
    wip_supply_type_tbl            number_tbl_type;
    item_num_tbl                   number_tbl_type;
    effectivity_date_tbl           date_tbl_type;
    disable_date_tbl               date_tbl_type;
    from_end_item_unit_number_tbl  varchar2_tbl_type_30;
    to_end_item_unit_number_tbl    varchar2_tbl_type_30;
    implementation_date_tbl        date_tbl_type;
    optional_tbl                   number_tbl_type;
    supply_subinventory_tbl        varchar2_tbl_type_10;
    supply_locator_id_tbl          number_tbl_type;
    component_remarks_tbl          varchar2_tbl_type_240;
    change_notice_tbl              varchar2_tbl_type_10;
    operation_leadtime_percent_tbl number_tbl_type;
    mutually_exclusive_options_tbl number_tbl_type;
    check_atp_tbl                  number_tbl_type;
    required_to_ship_tbl           number_tbl_type;
    required_for_revenue_tbl       number_tbl_type;
    include_on_ship_docs_tbl       number_tbl_type;
    low_quantity_tbl               number_tbl_type;
    high_quantity_tbl              number_tbl_type;
    so_basis_tbl                   number_tbl_type;
    operation_offset_tbl           number_tbl_type;
    current_revision_tbl           varchar2_tbl_type_3;
    primary_uom_code_tbl           varchar2_tbl_type_3;
    locator_tbl                    varchar2_tbl_type_40;
    component_item_revision_id_tbl number_tbl_type;
    parent_sort_order_tbl          varchar2_tbl_type_2000;
    assembly_type_tbl              number_tbl_type;
    revision_label_tbl             varchar2_tbl_type_260;
    revision_id_tbl                number_tbl_type;
    bom_implementation_date_tbl    date_tbl_type;
    creation_date_tbl              date_tbl_type;
    created_by_tbl                 number_tbl_type;
    last_update_date_tbl           date_tbl_type;
    last_updated_by_tbl            number_tbl_type;
    auto_request_material_tbl      varchar2_tbl_type_3;
  
    item_cost_tbl                 number_tbl_type;
    comp_bill_seq_id_tbl          number_tbl_type;
    comp_common_bill_seq_id_tbl   number_tbl_type;
    assembly_item_tbl             varchar2_tbl_type_30;
    assembly_description_tbl      varchar2_tbl_type_260;
    component_item_tbl            varchar2_tbl_type_30;
    component_description_tbl     varchar2_tbl_type_260;
    planning_make_buy_code_tbl    number_tbl_type;
    planning_make_buy_meaning_tbl varchar2_tbl_type_30;
    supply_type_tbl               varchar2_tbl_type_30;
    org_code_tbl                  varchar2_tbl_type_3;
    parent_make_buy_code_tbl      number_tbl_type;
  
    l_exploded_items_t xxbom_exploded_items_tbl_type := xxbom_exploded_items_tbl_type();
  
    l_group_id                 NUMBER;
    l_levels_to_explode        NUMBER;
    l_session_id               NUMBER;
    l_organization_id          NUMBER;
    l_assembly_item_id         bom_structures_b.assembly_item_id%TYPE;
    l_alternate_bom_designator bom_structures_b.alternate_bom_designator%TYPE;
    x_error_msg                VARCHAR2(500);
    x_error_code               NUMBER;
    l_date                     DATE;
    l_parent_make_buy          VARCHAR2(20);
    l_top_make_buy             VARCHAR2(20);
    l_costing_buy              VARCHAR2(20);
  
    CURSOR csr_exploded_items IS
      SELECT assembly_item_id,
             organization_id,
             component_item_id,
             effectivity_date
        FROM bom_explosion_temp
       WHERE group_id = l_group_id
         AND rownum < 2;
  
  BEGIN
  
    SELECT bom_explosion_temp_s.nextval INTO l_group_id FROM dual;
    SELECT bom_explosion_temp_session_s.nextval
      INTO l_session_id
      FROM dual;
  
    SELECT meaning
      INTO g_costing_buy
      FROM mfg_lookups
     WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
       AND lookup_code = 2;
  
    SELECT bs.assembly_item_id,
           bs.alternate_bom_designator,
           bs.organization_id,
           xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                              msi.planning_make_buy_code)
      INTO l_assembly_item_id,
           l_alternate_bom_designator,
           l_organization_id,
           l_top_make_buy
      FROM mtl_system_items_b msi, bom_structures_b bs, mtl_parameters mp
     WHERE msi.inventory_item_id = bs.assembly_item_id
       AND msi.organization_id = bs.organization_id
       AND msi.segment1 = g_assembly_item(p_item_ind)
       AND msi.organization_id = mp.organization_id
       AND mp.organization_code = g_organization_code;
  
    SELECT maximum_bom_level
      INTO l_levels_to_explode
      FROM bom_parameters
     WHERE organization_id = l_organization_id;
  
    IF l_levels_to_explode IS NULL THEN
      l_levels_to_explode := 60;
    
    END IF;
  
    bompexpl.exploder_userexit(verify_flag       => 0,
                               org_id            => l_organization_id,
                               order_by          => 1,
                               grp_id            => l_group_id,
                               session_id        => l_session_id,
                               levels_to_explode => l_levels_to_explode,
                               bom_or_eng        => 1, -- bom
                               impl_flag         => 1, -- Implemented ONLY
                               plan_factor_flag  => 2,
                               explode_option    => 2, -- Current
                               module            => 1, --CST
                               cst_type_id       => fnd_profile.value('XX_COST_TYPE'), ----2, --Average
                               std_comp_flag     => 0,
                               expl_qty          => 1,
                               item_id           => l_assembly_item_id,
                               alt_desg          => l_alternate_bom_designator,
                               comp_code         => '',
                               rev_date          => g_explosion_effective_date,
                               unit_number       => '',
                               release_option    => 0,
                               err_msg           => x_error_msg,
                               ERROR_CODE        => x_error_code);
  
    SELECT bet.top_bill_sequence_id,
           bet.top_item_id,
           bet.bill_sequence_id,
           bet.assembly_item_id,
           bet.organization_id,
           bet.component_sequence_id,
           bet.component_item_id,
           bet.plan_level,
           bet.extended_quantity,
           bet.sort_order,
           bet.component_yield_factor,
           bet.item_cost,
           bet.component_quantity,
           bet.optional,
           bet.component_code,
           bet.operation_seq_num,
           bet.parent_bom_item_type,
           bet.wip_supply_type,
           bet.item_num,
           bet.effectivity_date,
           bet.disable_date,
           bet.implementation_date,
           bet.supply_subinventory,
           bet.supply_locator_id,
           bet.component_remarks,
           bet.common_bill_sequence_id,
           ai.segment1 assembly_item,
           ai.description assembly_description,
           ci.segment1 component_item,
           ci.description component_description,
           ci.planning_make_buy_code,
           xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                              ci.planning_make_buy_code) planning_make_buy_meaning,
           xxinv_utils_pkg.get_lookup_meaning('WIP_SUPPLY',
                                              bet.wip_supply_type) planning_make_buy_meaning,
           mp.organization_code BULK COLLECT
      INTO top_bill_sequence_id_tbl,
           top_item_id_tbl,
           bill_sequence_id_tbl,
           assembly_item_id_tbl,
           organization_id_tbl,
           component_sequence_id_tbl,
           component_item_id_tbl,
           plan_level_tbl,
           extended_quantity_tbl,
           sort_order_tbl,
           component_yield_factor_tbl,
           item_cost_tbl,
           component_quantity_tbl,
           optional_tbl,
           component_code_tbl,
           operation_seq_num_tbl,
           parent_bom_item_type_tbl,
           wip_supply_type_tbl,
           item_num_tbl,
           effectivity_date_tbl,
           disable_date_tbl,
           implementation_date_tbl,
           supply_subinventory_tbl,
           supply_locator_id_tbl,
           component_remarks_tbl,
           common_bill_sequence_id_tbl,
           assembly_item_tbl,
           assembly_description_tbl,
           component_item_tbl,
           component_description_tbl,
           planning_make_buy_code_tbl,
           planning_make_buy_meaning_tbl,
           supply_type_tbl,
           org_code_tbl
      FROM mtl_system_items_b ai,
           mtl_system_items_b ci,
           bom_explosion_temp bet,
           mtl_parameters     mp
     WHERE bet.assembly_item_id = ai.inventory_item_id
       AND bet.organization_id = ai.organization_id
       AND bet.component_item_id = ci.inventory_item_id
       AND bet.organization_id = ci.organization_id
       AND bet.organization_id = mp.organization_id
       AND bet.group_id = l_group_id
     ORDER BY bet.sort_order;
  
    l_exploded_items_t := xxbom_exploded_items_tbl_type();
    l_exploded_items_t.extend(assembly_item_id_tbl.count);
  
    FOR i IN 1 .. assembly_item_id_tbl.count LOOP
    
      --check parent make buy
      IF plan_level_tbl(i) = 1 THEN
        l_parent_make_buy := l_top_make_buy;
      ELSE
        l_parent_make_buy := find_parent_make_buy(l_exploded_items_t,
                                                  i,
                                                  sort_order_tbl(i));
      END IF;
    
      IF l_parent_make_buy != l_costing_buy THEN
        l_parent_make_buy := planning_make_buy_meaning_tbl(i);
      END IF;
    
      l_exploded_items_t(i) := pl_to_sql(top_bill_sequence_id_tbl(i),
                                         top_item_id_tbl(i),
                                         bill_sequence_id_tbl(i),
                                         assembly_item_id_tbl(i),
                                         organization_id_tbl(i),
                                         component_sequence_id_tbl(i),
                                         component_item_id_tbl(i),
                                         plan_level_tbl(i),
                                         extended_quantity_tbl(i),
                                         sort_order_tbl(i),
                                         component_yield_factor_tbl(i),
                                         item_cost_tbl(i),
                                         component_quantity_tbl(i),
                                         optional_tbl(i),
                                         component_code_tbl(i),
                                         operation_seq_num_tbl(i),
                                         parent_bom_item_type_tbl(i),
                                         wip_supply_type_tbl(i),
                                         item_num_tbl(i),
                                         effectivity_date_tbl(i),
                                         disable_date_tbl(i),
                                         implementation_date_tbl(i),
                                         supply_subinventory_tbl(i),
                                         supply_locator_id_tbl(i),
                                         component_remarks_tbl(i),
                                         common_bill_sequence_id_tbl(i),
                                         assembly_item_tbl(i),
                                         assembly_description_tbl(i),
                                         component_item_tbl(i),
                                         component_description_tbl(i),
                                         planning_make_buy_code_tbl(i),
                                         planning_make_buy_meaning_tbl(i),
                                         org_code_tbl(i),
                                         l_parent_make_buy,
                                         supply_type_tbl(i));
    END LOOP;
    COMMIT;
    RETURN l_exploded_items_t;
  
  END;

  FUNCTION set_effective_date(p_effective_date DATE) RETURN NUMBER IS
  
  BEGIN
  
    g_explosion_effective_date := p_effective_date;
    RETURN 1;
  
  END set_effective_date;

  FUNCTION set_assembly_item(p_assembly_item VARCHAR2,
                             p_item_ind      NUMBER DEFAULT 1)
    RETURN VARCHAR2 IS
  
  BEGIN
  
    g_assembly_item(p_item_ind) := p_assembly_item;
    RETURN '1';
  
  END set_assembly_item;

  FUNCTION set_organization_code(p_org_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    g_organization_code := p_org_code;
    RETURN '1';
  
  END set_organization_code;

  FUNCTION get_effective_date RETURN DATE IS
  
  BEGIN
  
    RETURN g_explosion_effective_date;
  
  END get_effective_date;

  FUNCTION get_assembly_item(p_item_ind NUMBER DEFAULT 1) RETURN VARCHAR2 IS
  
  BEGIN
  
    RETURN g_assembly_item(p_item_ind);
  
  END get_assembly_item;

  FUNCTION get_organization_code RETURN VARCHAR2 IS
  
  BEGIN
  
    RETURN g_organization_code;
  
  END get_organization_code;
  -------------------------------------------
  -- explode_assembly_by_date2
  --
  -- Date   performer  note
  --------------------------------------------------------------------------
  -- ver  Date   performer  note
  --------------------------------------------------------------------------
  --       6.2.13 YUVAL TAL  CR 675 Job Component Report - work with Primary BOM
  --       13.3.14 yuval tal CHG0031420 WIP Job Component Report doesn't reflect the right BOM
  ------------------------------------------

  FUNCTION explode_assembly_by_date2 RETURN xxbom_exploded_items_tbl_type IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    /* Declare pl/sql tables for all coulmns in the select list. BULK BIND and INSERT with
    pl/sql table of records work fine in 9i releases but not in 8i. So, the only option is
    to use individual pl/sql table for each column in the cursor select list */
  
    TYPE number_tbl_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  
    TYPE date_tbl_type IS TABLE OF DATE INDEX BY BINARY_INTEGER;
  
    /* Declared seperate tables based on the column size since pl/sql preallocates the memory for the varchar variable
    when it is lesser than 2000 chars */
  
    /*
    TYPE VARCHAR2_TBL_TYPE IS TABLE OF VARCHAR2(2000)
    INDEX BY BINARY_INTEGER;
    */
  
    TYPE varchar2_tbl_type_1 IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_3 IS TABLE OF VARCHAR2(3) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_10 IS TABLE OF VARCHAR2(10) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_20 IS TABLE OF VARCHAR2(20) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_25 IS TABLE OF VARCHAR2(25) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_30 IS TABLE OF VARCHAR2(30) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_40 IS TABLE OF VARCHAR2(40) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_80 IS TABLE OF VARCHAR2(80) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_150 IS TABLE OF VARCHAR2(150) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_240 IS TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_260 IS TABLE OF VARCHAR2(260) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_1000 IS TABLE OF VARCHAR2(1000) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_2000 IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;
  
    TYPE varchar2_tbl_type_4000 IS TABLE OF VARCHAR2(4000) INDEX BY BINARY_INTEGER;
  
    top_bill_sequence_id_tbl       number_tbl_type;
    assembly_item_id_tbl           number_tbl_type;
    bill_sequence_id_tbl           number_tbl_type;
    common_bill_sequence_id_tbl    number_tbl_type;
    common_organization_id_tbl     number_tbl_type;
    organization_id_tbl            number_tbl_type;
    component_sequence_id_tbl      number_tbl_type;
    component_item_id_tbl          number_tbl_type;
    basis_type_tbl                 number_tbl_type;
    component_quantity_tbl         number_tbl_type;
    plan_level_tbl                 number_tbl_type;
    extended_quantity_tbl          number_tbl_type;
    sort_order_tbl                 varchar2_tbl_type_2000;
    group_id_tbl                   number_tbl_type;
    top_alternate_designator_tbl   varchar2_tbl_type_10;
    component_yield_factor_tbl     number_tbl_type;
    top_item_id_tbl                number_tbl_type;
    component_code_tbl             varchar2_tbl_type_1000;
    include_in_cost_rollup_tbl     number_tbl_type;
    loop_flag_tbl                  number_tbl_type;
    planning_factor_tbl            number_tbl_type;
    operation_seq_num_tbl          number_tbl_type;
    bom_item_type_tbl              number_tbl_type;
    parent_bom_item_type_tbl       number_tbl_type;
    parent_item_id_tbl             number_tbl_type;
    alternate_bom_designator_tbl   varchar2_tbl_type_10;
    wip_supply_type_tbl            number_tbl_type;
    item_num_tbl                   number_tbl_type;
    effectivity_date_tbl           date_tbl_type;
    disable_date_tbl               date_tbl_type;
    from_end_item_unit_number_tbl  varchar2_tbl_type_30;
    to_end_item_unit_number_tbl    varchar2_tbl_type_30;
    implementation_date_tbl        date_tbl_type;
    optional_tbl                   number_tbl_type;
    supply_subinventory_tbl        varchar2_tbl_type_10;
    supply_locator_id_tbl          number_tbl_type;
    component_remarks_tbl          varchar2_tbl_type_240;
    change_notice_tbl              varchar2_tbl_type_10;
    operation_leadtime_percent_tbl number_tbl_type;
    mutually_exclusive_options_tbl number_tbl_type;
    check_atp_tbl                  number_tbl_type;
    required_to_ship_tbl           number_tbl_type;
    required_for_revenue_tbl       number_tbl_type;
    include_on_ship_docs_tbl       number_tbl_type;
    low_quantity_tbl               number_tbl_type;
    high_quantity_tbl              number_tbl_type;
    so_basis_tbl                   number_tbl_type;
    operation_offset_tbl           number_tbl_type;
    current_revision_tbl           varchar2_tbl_type_3;
    primary_uom_code_tbl           varchar2_tbl_type_3;
    locator_tbl                    varchar2_tbl_type_40;
    component_item_revision_id_tbl number_tbl_type;
    parent_sort_order_tbl          varchar2_tbl_type_2000;
    assembly_type_tbl              number_tbl_type;
    revision_label_tbl             varchar2_tbl_type_260;
    revision_id_tbl                number_tbl_type;
    bom_implementation_date_tbl    date_tbl_type;
    creation_date_tbl              date_tbl_type;
    created_by_tbl                 number_tbl_type;
    last_update_date_tbl           date_tbl_type;
    last_updated_by_tbl            number_tbl_type;
    auto_request_material_tbl      varchar2_tbl_type_3;
  
    item_cost_tbl                 number_tbl_type;
    comp_bill_seq_id_tbl          number_tbl_type;
    comp_common_bill_seq_id_tbl   number_tbl_type;
    assembly_item_tbl             varchar2_tbl_type_30;
    assembly_description_tbl      varchar2_tbl_type_260;
    component_item_tbl            varchar2_tbl_type_30;
    component_description_tbl     varchar2_tbl_type_260;
    planning_make_buy_code_tbl    number_tbl_type;
    planning_make_buy_meaning_tbl varchar2_tbl_type_30;
    supply_type_tbl               varchar2_tbl_type_30;
    org_code_tbl                  varchar2_tbl_type_3;
    parent_make_buy_code_tbl      number_tbl_type;
  
    l_exploded_items_t xxbom_exploded_items_tbl_type := xxbom_exploded_items_tbl_type();
  
    l_group_id                 NUMBER;
    l_levels_to_explode        NUMBER;
    l_session_id               NUMBER;
    l_organization_id          NUMBER;
    l_assembly_item_id         bom_structures_b.assembly_item_id%TYPE;
    l_alternate_bom_designator bom_structures_b.alternate_bom_designator%TYPE;
    x_error_msg                VARCHAR2(500);
    x_error_code               NUMBER;
    l_date                     DATE;
    l_parent_make_buy          VARCHAR2(20);
    l_top_make_buy             VARCHAR2(20);
    l_costing_buy              VARCHAR2(20);
    l_chm_level                NUMBER := 99999;
    l_explode_ind              VARCHAR2(1);
  
    l_continue_exception EXCEPTION;
    CURSOR csr_exploded_items IS
      SELECT assembly_item_id,
             organization_id,
             component_item_id,
             effectivity_date
        FROM bom_explosion_temp
       WHERE group_id = l_group_id
         AND rownum < 2;
  
  BEGIN
    /*
    fnd_global.apps_initialize(user_id      => 3850,
                               resp_id      => 50877,
                               resp_appl_id => 201);*/
  
    SELECT bom_explosion_temp_s.nextval INTO l_group_id FROM dual;
    SELECT bom_explosion_temp_session_s.nextval
      INTO l_session_id
      FROM dual;
  
    SELECT meaning
      INTO g_costing_buy
      FROM mfg_lookups
     WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
       AND lookup_code = 2;
  
    SELECT bs.assembly_item_id,
           bs.alternate_bom_designator,
           bs.organization_id,
           xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                              msi.planning_make_buy_code)
      INTO l_assembly_item_id,
           l_alternate_bom_designator,
           l_organization_id,
           l_top_make_buy
      FROM mtl_system_items_b msi, bom_structures_b bs, mtl_parameters mp
     WHERE msi.inventory_item_id = bs.assembly_item_id
       AND msi.organization_id = bs.organization_id
          --  AND msi.segment1 = get_assembly_item --p_item_segment
       AND msi.inventory_item_id = get_assembly_item
       AND msi.organization_id = mp.organization_id
       AND mp.organization_code = g_organization_code
       AND bs.alternate_bom_designator IS NULL;
  
    SELECT maximum_bom_level
      INTO l_levels_to_explode
      FROM bom_parameters
     WHERE organization_id = l_organization_id;
  
    IF l_levels_to_explode IS NULL THEN
      l_levels_to_explode := 60;
    
    END IF;
  
    bompexpl.exploder_userexit(verify_flag       => 0,
                               org_id            => l_organization_id,
                               order_by          => 1,
                               grp_id            => l_group_id,
                               session_id        => l_session_id,
                               levels_to_explode => l_levels_to_explode,
                               bom_or_eng        => 1, -- bom
                               impl_flag         => 1, -- Implemented ONLY
                               plan_factor_flag  => 2,
                               explode_option    => 2, -- Current
                               module            => 1, --CST
                               -- cst_type_id       => 2, --Average
                               std_comp_flag => 0,
                               expl_qty      => 1,
                               item_id       => l_assembly_item_id,
                               alt_desg      => l_alternate_bom_designator,
                               comp_code     => '',
                               --  rev_date       => g_explosion_effective_date, -- CHG0031420
                               rev_date       => to_char(g_explosion_effective_date, -- CHG0031420
                                                         'YYYY/MM/DD HH24:MI:SS'),
                               unit_number    => '',
                               release_option => 0,
                               err_msg        => x_error_msg,
                               ERROR_CODE     => x_error_code);
  
    SELECT bet.top_bill_sequence_id,
           bet.top_item_id,
           bet.bill_sequence_id,
           bet.assembly_item_id,
           bet.organization_id,
           bet.component_sequence_id,
           bet.component_item_id,
           bet.plan_level,
           bet.extended_quantity,
           bet.sort_order,
           bet.component_yield_factor,
           bet.item_cost,
           bet.component_quantity,
           bet.optional,
           bet.component_code,
           bet.operation_seq_num,
           bet.parent_bom_item_type,
           bet.wip_supply_type,
           bet.item_num,
           bet.effectivity_date,
           bet.disable_date,
           bet.implementation_date,
           bet.supply_subinventory,
           bet.supply_locator_id,
           bet.component_remarks,
           bet.common_bill_sequence_id,
           ai.segment1 assembly_item,
           ai.description assembly_description,
           ci.segment1 component_item,
           ci.description component_description,
           ci.planning_make_buy_code,
           xxinv_utils_pkg.get_lookup_meaning('MTL_PLANNING_MAKE_BUY',
                                              ci.planning_make_buy_code) planning_make_buy_meaning,
           xxinv_utils_pkg.get_lookup_meaning('WIP_SUPPLY',
                                              bet.wip_supply_type) planning_make_buy_meaning,
           
           mp.organization_code BULK COLLECT
      INTO top_bill_sequence_id_tbl,
           top_item_id_tbl,
           bill_sequence_id_tbl,
           assembly_item_id_tbl,
           organization_id_tbl,
           component_sequence_id_tbl,
           component_item_id_tbl,
           plan_level_tbl,
           extended_quantity_tbl,
           sort_order_tbl,
           component_yield_factor_tbl,
           item_cost_tbl,
           component_quantity_tbl,
           optional_tbl,
           component_code_tbl,
           operation_seq_num_tbl,
           parent_bom_item_type_tbl,
           wip_supply_type_tbl,
           item_num_tbl,
           effectivity_date_tbl,
           disable_date_tbl,
           implementation_date_tbl,
           supply_subinventory_tbl,
           supply_locator_id_tbl,
           component_remarks_tbl,
           common_bill_sequence_id_tbl,
           assembly_item_tbl,
           assembly_description_tbl,
           component_item_tbl,
           component_description_tbl,
           planning_make_buy_code_tbl,
           planning_make_buy_meaning_tbl,
           supply_type_tbl,
           org_code_tbl
      FROM mtl_system_items_b ai,
           mtl_system_items_b ci,
           bom_explosion_temp bet,
           mtl_parameters     mp
     WHERE bet.assembly_item_id = ai.inventory_item_id
       AND bet.organization_id = ai.organization_id
       AND bet.component_item_id = ci.inventory_item_id
       AND bet.organization_id = ci.organization_id
       AND bet.organization_id = mp.organization_id
       AND bet.group_id = l_group_id
     ORDER BY bet.sort_order;
  
    l_exploded_items_t := xxbom_exploded_items_tbl_type();
    l_exploded_items_t.extend(assembly_item_id_tbl.count);
  
    FOR i IN 1 .. assembly_item_id_tbl.count LOOP
      BEGIN
        component_remarks_tbl(i) := '';
      
        -- check CHM item , avoid exploding
        IF component_item_tbl(i) LIKE 'CHM%' AND l_explode_ind = 'Y' AND
           plan_level_tbl(i) <= l_chm_level THEN
          l_explode_ind := 'N';
          component_remarks_tbl(i) := '+';
          l_chm_level := plan_level_tbl(i);
          --  dbms_output.put_line('explode=n');
        ELSIF plan_level_tbl(i) <= l_chm_level THEN
          l_explode_ind := 'Y';
        END IF;
      
        IF plan_level_tbl(i) > l_chm_level AND l_explode_ind = 'N' THEN
        
          RAISE l_continue_exception; -- continue
        END IF;
      
        --check parent make buy
        IF plan_level_tbl(i) = 1 THEN
          l_parent_make_buy := l_top_make_buy;
        ELSE
          l_parent_make_buy := find_parent_make_buy(l_exploded_items_t,
                                                    i,
                                                    sort_order_tbl(i));
        END IF;
      
        IF l_parent_make_buy != l_costing_buy THEN
          l_parent_make_buy := planning_make_buy_meaning_tbl(i);
        END IF;
      
        l_exploded_items_t(i) := pl_to_sql(top_bill_sequence_id_tbl(i),
                                           top_item_id_tbl(i),
                                           bill_sequence_id_tbl(i),
                                           assembly_item_id_tbl(i),
                                           organization_id_tbl(i),
                                           component_sequence_id_tbl(i),
                                           component_item_id_tbl(i),
                                           plan_level_tbl(i),
                                           extended_quantity_tbl(i),
                                           sort_order_tbl(i),
                                           component_yield_factor_tbl(i),
                                           item_cost_tbl(i),
                                           component_quantity_tbl(i),
                                           optional_tbl(i),
                                           component_code_tbl(i),
                                           operation_seq_num_tbl(i),
                                           parent_bom_item_type_tbl(i),
                                           wip_supply_type_tbl(i),
                                           item_num_tbl(i),
                                           effectivity_date_tbl(i),
                                           disable_date_tbl(i),
                                           implementation_date_tbl(i),
                                           supply_subinventory_tbl(i),
                                           supply_locator_id_tbl(i),
                                           component_remarks_tbl(i),
                                           common_bill_sequence_id_tbl(i),
                                           assembly_item_tbl(i),
                                           assembly_description_tbl(i),
                                           component_item_tbl(i),
                                           component_description_tbl(i),
                                           planning_make_buy_code_tbl(i),
                                           planning_make_buy_meaning_tbl(i),
                                           org_code_tbl(i),
                                           l_parent_make_buy,
                                           supply_type_tbl(i));
      EXCEPTION
        WHEN l_continue_exception THEN
          NULL;
      END;
    END LOOP;
  
    COMMIT;
    RETURN l_exploded_items_t;
  
  END;

END;

/*
RESULT TYPE:
-----------------------------------
CREATE OR REPLACE TYPE xxbom_exploded_items_type IS OBJECT
(
   top_bill_sequence_id      NUMBER,
   top_item_id               NUMBER,
   bill_sequence_id          NUMBER,
   assembly_item_id          NUMBER,
   organization_id           NUMBER,
   component_sequence_id     NUMBER,
   component_item_id         NUMBER,
   plan_level                NUMBER,
   extended_quantity         NUMBER,
   sort_order                VARCHAR2(2000),
   component_yield_factor    NUMBER,
   item_cost                 NUMBER,
   component_quantity        NUMBER,
   optional                  NUMBER,
   component_code            VARCHAR2(1000),
   operation_seq_num         NUMBER,
   parent_bom_item_type      NUMBER,
   wip_supply_type           NUMBER,
   item_num                  NUMBER,
   effectivity_date          DATE,
   disable_date              DATE,
   implementation_date       DATE,
   supply_subinventory       VARCHAR2(10),
   supply_locator_id         NUMBER,
   component_remarks         VARCHAR2(240),
   common_bill_sequence_id   NUMBER,
   assembly_item             VARCHAR2(40),
   assembly_description      VARCHAR2(240),
   component_item            VARCHAR2(40),
   component_description     VARCHAR2(240),
   planning_make_buy_code    NUMBER,
   planning_make_buy_meaning VARCHAR2(20),
   org_code                  VARCHAR2(3),
   costing_make_buy          VARCHAR2(20),
   supply_type               VARCHAR2(20)
)

TABLE TYPE:
-----------------------------------
create or replace type xxbom_exploded_items_tbl_type as table of xxbom_exploded_items_type

VIEW:
-----------------------------------
SELECT t.top_bill_sequence_id,
       t.top_item_id,
       t.bill_sequence_id,
       t.assembly_item_id,
       t.organization_id,
       t.component_sequence_id,
       t.component_item_id,
       t.plan_level,
       t.extended_quantity,
       t.sort_order,
       t.component_yield_factor,
       t.item_cost,
       t.component_quantity,
       t.optional,
       t.component_code,
       t.operation_seq_num,
       t.parent_bom_item_type,
       t.wip_supply_type,
       t.item_num,
       t.effectivity_date,
       t.disable_date,
       t.implementation_date,
       t.supply_subinventory,
       t.supply_locator_id,
       t.component_remarks,
       t.common_bill_sequence_id,
       t.assembly_item,
       t.assembly_description,
       t.component_item,
       t.component_description,
       t.planning_make_buy_code,
       t.planning_make_buy_meaning,
       t.org_code,
       cic.cost_type_id,
       cct.cost_type,
       cct.description cost_description,
       cct.allow_updates_flag,
       cct.frozen_standard_flag,
       cct.default_cost_type_id,
       cct2.cost_type cst_cost_type,
       cic.inventory_asset_flag,
       cic.lot_size,
       cic.based_on_rollup_flag,
       cic.shrinkage_rate,
       cic.defaulted_flag,
       cic.item_cost cst_item_cost,
       cic.material_cost,
       cic.material_overhead_cost,
       cic.resource_cost,
       cic.outside_processing_cost,
       cic.overhead_cost,
       t.costing_make_buy,
       t.supply_type,
       (SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                              h.currency_code),
                                                          'USD',
                                                          nvl(ind.base_date,
                                                              nvl(h.rate_date,
                                                                  h.creation_date)),
                                                          'Corporate',
                                                          nvl(ind.base_rate,
                                                              h.rate),
                                                          l.unit_price /
                                                          decode(ind.base_rate,
                                                                 0,
                                                                 1,
                                                                 NULL,
                                                                 1,
                                                                 ind.base_rate),
                                                          7)
          FROM po_headers_all           h,
               po_lines_all             l,
               clef062_po_index_esc_set ind
         WHERE h.po_header_id = l.po_header_id AND
               h.segment1 = ind.document_id(+) AND
               ind.module(+) = 'PO' AND
               l.item_id = t.component_item_id AND
               l.po_line_id = (SELECT MAX(po_line_id)
                                 FROM po_headers_all h1, po_lines_all l1
                                WHERE h1.po_header_id = l1.po_header_id AND
                                      l1.item_id = t.component_item_id AND
                                      l1.org_id = 81 AND
                                      h1.type_lookup_code = 'STANDARD' AND
                                      nvl(l1.cancel_flag, 'N') = 'N' AND
                                      l.unit_price > 0)) last_po_price
  FROM TABLE(CAST(xxbom_explosion_report_pkg.explode_assembly_by_date(1) AS
                  xxbom_exploded_items_tbl_type)) t,
       cst_item_costs cic,
       cst_cost_types cct,
       cst_cost_types cct2
 WHERE cct.cost_type_id = cic.cost_type_id AND
       cct2.cost_type_id = cct.default_cost_type_id AND
       cic.inventory_item_id = t.component_item_id AND
       cic.organization_id =
       nvl((SELECT 92
             FROM dual
            WHERE EXISTS
            (SELECT 1
                     FROM bom_structures_b bs1, bom_components_b bc1
                    WHERE bs1.bill_sequence_id = bc1.bill_sequence_id AND
                          bs1.organization_id = 92 AND
                          (bs1.assembly_item_id = t.component_item_id OR
                          bc1.component_item_id = t.component_item_id))),
           t.organization_id) AND
       cic.cost_type_id = 2;


DISCO IMPLEMENTATION:
-----------------------------------
a. Create disco folder for main query
b. Create calculation item in administrator that holds '1'
c. Create custom folder for assembly LOV and assign the lov to the new calculted item
d. Create the report with required fields
e. Add parameter ..... TBD
f. Add calculation ....TBD
g. Add conditions .... TBD
*/
/
