create or replace package XXCS_DISCO_PKG is


--------------------------------------------------------------------
--  name:            XXCS_DISCO_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   14/02/2011 09:19:34
--------------------------------------------------------------------
--  purpose :        Package that will handle all CS Disco functions
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  14/02/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------      
 
  --------------------------------------------------------------------
  --  name:            get_early_contract_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2011 09:19:34
  --------------------------------------------------------------------
  --  purpose :        function that for time and material instances
  --                   will check early period of 60 days and see if there was 
  --                   a warranty or contract.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------    
  function get_early_contract_status (p_instance_id in number,
                                      p_from_date   in date,
                                      p_to_date     in date) return varchar2; 

end XXCS_DISCO_PKG;
/

