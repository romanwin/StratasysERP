create or replace package XXINV_NEW_KANBAN_CARD_CHNG_PKG is
-----------------------------------------------------------------------
--  name:               XXINV_NEW_KANBAN_CARD_CHNG_PKG
--  create by:          Michal Tzvik 
--  Revision:           1.0
--  creation date:      06-OCT-2014
--  Purpose :           
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   06/10/2014    Michal Tzvik    CHG0032848: initial build
-----------------------------------------------------------------------  


  --------------------------------------------------------------------
  --  customization code: main
  --  name:               
  --  create by:          Michal Tzvik 
  --  Revision:           1.0
  --  creation date:      06/10/2014  
  --  Purpose :           update kanban card status. Called by concurrent program
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/10/2014    Michal Tzvik    CHG0032848: initial build 
  -----------------------------------------------------------------------
  PROCEDURE  main(errbuf               OUT  varchar2
                 ,retcode              OUT  number
                 ,p_mfg_org_id         IN   number
                 ,p_subinventory       IN   varchar2
                 ,p_inventory_item_id  IN   number
                 ,p_current_status     IN   varchar2
                 ,p_change_to_status   IN   varchar2 
                 ,p_delete_kanban_card IN   varchar2);
                 
                 
end XXINV_NEW_KANBAN_CARD_CHNG_PKG;
/
