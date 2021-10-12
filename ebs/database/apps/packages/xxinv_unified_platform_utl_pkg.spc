create or replace package xxinv_unified_platform_utl_pkg is

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

  ---------------------------------------------------------------------
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
                               p_organization_id   IN NUMBER) RETURN VARCHAR2;


  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_basis_hasp
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      29/06/2014
  --  Purpose :           Check if given item is defined as Basis HASP
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/06/2014    Michal Tzvik    CHG0032166: initial build
  -----------------------------------------------------------------------
  FUNCTION is_basis_hasp (p_inventory_item_id IN NUMBER,
                          p_organization_id   IN NUMBER) RETURN VARCHAR2;
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
  FUNCTION get_hasp_sn(p_job  varchar2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code:
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
                               p_organization_id   in number) return varchar2;

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
                                     p_org_id            in number) return number;

end xxinv_unified_platform_utl_pkg;
/
