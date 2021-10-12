create or replace package xxwip_generate_sn_pkg is

--------------------------------------------------------------------
--  name:              XXWIP_GENERATE_SN_PKG
--  create by:         Dalit A. Raviv
--  Revision:          1.0
--  creation date:     07/07/2013 10:39:52
--------------------------------------------------------------------
--  purpose :          CUST494 - Mass Generate Serial Numbers
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  07/07/2013    Dalit A. Raviv    initial build
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:              generate_sn_main
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure generate_sn_main (errbuf        out varchar2, 
                              retcode       out number,
                              p_org_id      in  number,
                              p_assembly_id in  number,
                              p_from_job    in  varchar2,
                              p_to_job      in  varchar2);

end xxwip_generate_sn_pkg;
/
