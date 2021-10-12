create or replace package body XXBOM_UTIL_PKG is

--------------------------------------------------------------------
--  name:            XXBOM_UTIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   16/12/2014 09:09:38
--------------------------------------------------------------------
--  purpose :        Util Package to wrapped all proc/func related to BOM
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  16/12/2014  Dalit A. Raviv  initial build
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  name:            get_person_routing_hr
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2014 09:09:38
  --------------------------------------------------------------------
  --  purpose :        calculate sum(usage_rate_or_amount) per resource type
  --                   resource_type 1 = machine 2 = person 
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  16/12/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  function get_routing_hr (p_organization_id   in number,
                           p_inventory_item_id in number,
                           p_resource_type     in number,
                           p_make_buy_code     in number default 1) return number is
                                  
    l_usage_rate_or_amount number := 0;
  begin
    select  sum(bres.usage_rate_or_amount) 
    into    l_usage_rate_or_amount
    from    bom_operational_routings_v  bor,
            bom_operation_sequences_v   bos,
            bom_operation_resources_v   bres,
            bom_resources               br,
            mtl_system_items_b          msib,
            mtl_parameters              mp
    where   bor.routing_sequence_id     = bos.routing_sequence_id
    and     bos.operation_sequence_id   = bres.operation_sequence_id
    and     bor.assembly_item_id        = msib.inventory_item_id
    and     bor. organization_id        = msib.organization_id
    and     BOR.organization_id         = MP.Organization_Id
    and     bres.basis_type             = 1 -- Item - time per unit
    and     bos.effectivity_date        < sysdate 
    and     nvl(bos.disable_date, sysdate +1) > sysdate 
    and     bres.uom                    = 'HR'
    and     bres.resource_id            = br.resource_id
    and     br.resource_type            = p_resource_type -- 1 = machine 2 = person 
    and     msib.planning_make_buy_code = p_make_buy_code -- 1 = make
    and     bor.organization_id         = p_organization_id
    and     bor.assembly_item_id        = p_inventory_item_id;
  
    return l_usage_rate_or_amount;
  exception
    when others then
      return null;
  end get_routing_hr;                                  

                        

end XXBOM_UTIL_PKG;
/
