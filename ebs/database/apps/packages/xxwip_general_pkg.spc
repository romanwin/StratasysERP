create or replace package xxwip_general_pkg is

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
                                    p_lookup_code in varchar2) return varchar2;
  
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
                                 p_component       in varchar2) return varchar2;                                    

end XXWIP_GENERAL_PKG;
/
