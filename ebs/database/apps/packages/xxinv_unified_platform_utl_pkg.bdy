create or replace package body xxinv_unified_platform_utl_pkg is

-----------------------------------------------------------------------
--  name:               XXINV_UNIFIED_PLATFORM_UTL_PKG
--  create by:          MICHAL.TZVIK
--  Revision:           1.0
--  creation date:      29-Jun-14 12:00:38
--  Purpose :
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29/06/2014    Michal Tzvik    CHG0032166: initial build
--  1.1   21/09/2014    Dalit A. Raviv  CHG0032268: add function is_gen_platform, get_shortage_qty_for_gen
-----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_unified_platform
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      29/06/2014
  --  Purpose :           Check if given serial has a component of Unified Platform
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/06/2014    Michal Tzvik    CHG0032166: initial build
  -----------------------------------------------------------------------
  FUNCTION is_unified_platform(p_inventory_item_id IN NUMBER,
                               p_organization_id   IN NUMBER) RETURN VARCHAR2
  IS
    l_is_unified_platform VARCHAR2(1);
  BEGIN

    select nvl(max('Y'),'N')
    into   l_is_unified_platform
    from   mtl_item_categories_v micv,
           mtl_system_items_b    msib1,
           mtl_system_items_b    msib2,
           bom_components_b               bcb,
           bom_structures_b              bsb
    where  1 = 1
    and    micv.inventory_item_id =msib2.inventory_item_id
    and    micv.ORGANIZATION_ID = p_organization_id
    and    micv.CATEGORY_SET_NAME = 'Activity Analysis'
    and    micv.SEGMENT1 = 'General'
    and    msib1.inventory_item_id = p_inventory_item_id
    and    msib1.organization_id = micv.organization_id
    and    msib1.replenish_to_order_flag = 'Y'
    and    bcb.bill_sequence_id = bsb.bill_sequence_id
    and    bsb.organization_id = p_organization_id
    and    bsb.assembly_item_id = msib1.inventory_item_id
    and    bcb.component_item_id = msib2.inventory_item_id
    and    msib2.organization_id = bsb.organization_id
    and    trunc(sysdate) between bcb.effectivity_date and nvl(bcb.disable_date, sysdate + 1);

    return l_is_unified_platform;

  END is_unified_platform;


  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_basis_hasp
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      29/06/2014
  --  Purpose :           Check if given item is defined as Basis HASP
  --                      Each machine is specified as BASIS by default.
  --                      The machine is not BASIS only if it was explicitly marked
  --                      as Basis Hasp = N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/06/2014    Michal Tzvik    CHG0032166: initial build
  -----------------------------------------------------------------------
  FUNCTION is_basis_hasp (p_inventory_item_id IN NUMBER,
                         p_organization_id   IN NUMBER) RETURN VARCHAR2
  IS
    l_is_basis_hasp VARCHAR2(1);
  BEGIN
     select mic.segment1
     into   l_is_basis_hasp
     from   mtl_item_categories_v          mic
     where  1 = 1
     and    mic.inventory_item_id = p_inventory_item_id
     and    mic.organization_id = p_organization_id
     and    mic.category_set_name='Basis HASP';

     return l_is_basis_hasp;

  exception
    when no_data_found then
      return 'Y';
  END is_basis_hasp;


  --------------------------------------------------------------------
  --  customization code: CHG0032575
  --  name:               get_hasp_sn
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      03/09/2014
  --  Purpose :           Get Hasp sn from sn reporting
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   03/09/2014    Michal Tzvik    CHG0032575: initial build
  -----------------------------------------------------------------------
  FUNCTION get_hasp_sn(p_job  varchar2) RETURN VARCHAR2
  IS
    l_hasp_sn  q_sn_reporting_v.obj_serial_number%type;
  BEGIN

    select  qsrv.obj_serial_number
    into    l_hasp_sn
    from    mtl_system_items_b    msib1, -- cmp
            mtl_system_items_b    msib2, -- cmp-s
            q_sn_reporting_v      qsrv
    where   1 = 1
    and     qsrv.serial_component_item =msib1.segment1
    and     msib1.attribute9 = msib2.inventory_item_id
    and     msib2.serial_number_control_code != 1
    and     msib1.organization_id = 735
    and     msib2.organization_id = 735
    and     qsrv.plan_name = 'SN REPORTING'
    and     qsrv.serial_component_item like 'CMP%'
    and     qsrv.job = p_job;

    return l_hasp_sn;

  exception
    when others then
      return null;
  END get_hasp_sn;

  --------------------------------------------------------------------
  --  customization code: CHG0032268
  --  name:               is_general_platform
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      21/09/2014
  --  Purpose :           Check if given item is a general platform
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/06/2014    Dalit A. Raviv  CHG0032268
  -----------------------------------------------------------------------
  function is_general_platform(p_inventory_item_id in number,
                               p_organization_id   in number) return varchar2 is

    l_is_unified_platform VARCHAR2(1);
  begin
    select nvl(max('Y'),'N')
    into   l_is_unified_platform
    from   mtl_item_categories_v   micv,
           mtl_system_items_b      msib1,
           mtl_system_items_b      msib2,
           bom_components_b        bcb,
           bom_structures_b        bsb
    where  1 = 1
    and    micv.inventory_item_id  = msib2.inventory_item_id
    and    micv.organization_id    = p_organization_id    -- <>
    and    micv.category_set_name  = 'Activity Analysis'
    and    micv.segment1           = 'General'
    and    msib2.inventory_item_id = p_inventory_item_id  -- <>
    and    msib1.organization_id   = micv.organization_id
    and    msib1.replenish_to_order_flag = 'Y'
    and    bcb.bill_sequence_id    = bsb.bill_sequence_id
    and    bsb.organization_id     = p_organization_id    -- <>
    and    bsb.assembly_item_id    = msib1.inventory_item_id
    and    bcb.component_item_id   = msib2.inventory_item_id
    and    msib2.organization_id   = bsb.organization_id
    and    trunc(sysdate)          between bcb.effectivity_date and nvl(bcb.disable_date, sysdate + 1);

    return l_is_unified_platform;

  end is_general_platform;

  --------------------------------------------------------------------
  --  customization code: CHG0032268
  --  name:               get_shortage_qty_for_gen
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      21/09/2014
  --  Purpose :           Check the shortage of each Top Assembly:
  --                      The shortage is the result of:  On Hand Column + Open SO Column
  --                      Summarize the shortages of all Top Assy (only if there is shortage):
  --                      This should be the result of column Open SO Column of the GEN/PHA item
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/06/2014    Dalit A. Raviv  CHG0032268
  -----------------------------------------------------------------------
  function get_shortage_qty_for_gen (p_inventory_item_id in number,
                                     p_organization_id   in number,
                                     p_org_id            in number) return number is

    cursor get_parent_items_c  is
      select bom.assembly_item_id, bom.description
      from   bom_inventory_components_v bic,
             bom_bill_of_materials_v    bom
      where  bic.bill_sequence_id       = bom.bill_sequence_id
      and    bom.organization_id        = p_organization_id    -- 736
      and    bic.component_item_id      = p_inventory_item_id; -- 1074700

    cursor get_parents_qtys_c (p_item_id in number) is
      select a.*
      from   xxinv_onhand_atp a
      where  a.inventory_item_id = p_item_id -- 539002,819006,1074697
      and    a.organization_id   = p_org_id;


    l_on_hand number  := 0;
    l_open_so number  := 0;
    l_qty     number  := 0;

  begin
    for get_parent_items_r in get_parent_items_c loop
      l_on_hand := 0;
      l_open_so := 0;

      for get_parents_qtys_r in get_parents_qtys_c (get_parent_items_r.assembly_item_id) loop
        if get_parents_qtys_r.type like '%On Hand%' then
          l_on_hand := l_on_hand + get_parents_qtys_r.qty;
        elsif get_parents_qtys_r.type like '%Open SO%' then
          l_open_so := l_open_so + get_parents_qtys_r.qty;
        end if;
      end loop;

      if (l_open_so + l_on_hand) < 0 then
        l_qty := l_qty + (l_open_so + l_on_hand);
      end if;
    end loop;

    return l_qty;

  end get_shortage_qty_for_gen;

end xxinv_unified_platform_utl_pkg;
/
