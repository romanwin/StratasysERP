create or replace package body xxwip_general_pkg is

--------------------------------------------------------------------
--  name:              XXWIP_GENERAL_PKG
--  create by:         Dalit A. Raviv
--  Revision:          1.1
--  creation date:     07/07/2013 11:25:36
--------------------------------------------------------------------
--  purpose :          General functions and procedures for the WIP module
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  07/07/2013    Dalit A. Raviv    initial build
--  1.1  19/01/2014    Dalit A. Raviv    add function get_Suggested_Vendor
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:              get_lookup_code_meaning
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 11:25:36
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_lookup_code_meaning (p_lookup_type in varchar2,
                                    p_lookup_code in varchar2) return varchar2 is

    l_meaning varchar2(80) := null;
  begin
    select meaning
    into   l_meaning
    from   fnd_lookup_values lv
    where  lv.lookup_type    = p_lookup_type
    and    lv.language       = userenv('LANG')
    and    lookup_code       = p_lookup_code;

    return l_meaning;
  exception
    when others then
      return p_lookup_code;
  end get_lookup_code_meaning;
  
  --------------------------------------------------------------------
  --  name:              get_Suggested_Vendor
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     19/01/2014
  --------------------------------------------------------------------
  --  purpose :          shortage report
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  19/01/2014    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_Suggested_Vendor (p_organization_id in number,
                                 p_component       in varchar2) return varchar2 is
                                 
    l_suggested_vendor varchar2(50):= null;
    
  begin
    select u.sourcing_rule_name
    into   l_suggested_vendor
    from   mrp_sr_assignments_v u, 
           mtl_system_items_b comp
    where  (assignment_type in (1, 2, 4, 5) OR
            u.organization_id is not null OR
            (assignment_type in (3, 6) AND u.organization_id is null))
     and   (u.assignment_set_id   = 1250191)
     and   comp.inventory_item_id = u.inventory_item_id
     and   comp.organization_id   = u.organization_id
     and   u.organization_id      = p_organization_id
     and   comp.segment1          = p_component;
     
     return l_suggested_vendor;
  exception
    when others then
      return null;
  end;
  
end xxwip_general_pkg;
/
