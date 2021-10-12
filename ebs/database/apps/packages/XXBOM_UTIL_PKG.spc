create or replace package XXBOM_UTIL_PKG is

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
                           p_make_buy_code     in number default 1) return number;

  

end XXBOM_UTIL_PKG;
/
