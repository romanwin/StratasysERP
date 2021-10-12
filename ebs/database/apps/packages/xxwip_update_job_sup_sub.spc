CREATE OR REPLACE PACKAGE xxwip_update_job_sup_sub AUTHID CURRENT_USER IS
  
--------------------------------------------------------------------
--  name:            XXWIP_UPDATE_JOB_SUP_SUB
--  create by:       ARIK LALO
--  Revision:        1.0
--  creation date:   14/04/2004
--------------------------------------------------------------------
--  purpose :        
--
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  14/04/2004  ARIK LALO       initial build
--  1.1  23.6.11     YUVAL TAL       ADD wip_update2
--  1.2  28.05.2014  Gary Altman     CHG0032162 - add procedure to cancel ato jobs
--  1.3  04/11/2014  Dalit A. Raviv  CHG0033022 - Update Supply Information in WIP Material Requirements
--                                   add procedure wip_change_supply_info
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            wip_update
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE wip_update(errbuf                OUT VARCHAR2,
                       retcode               OUT VARCHAR2,
                       p_job_number          IN NUMBER,
                       p_organization_id     IN NUMBER);

  --------------------------------------------------------------------
  --  name:            wip_update2
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE wip_update2(errbuf               OUT VARCHAR2,
                        retcode              OUT VARCHAR2,
                        p_organization_id    IN NUMBER,
                        p_item_id            NUMBER,
                        p_job_number         VARCHAR2);

  --------------------------------------------------------------------
  --  name:            cancel_ato_job
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE cancel_ato_job(errbuf            OUT VARCHAR2,
                           retcode           OUT VARCHAR2);
                           
  --------------------------------------------------------------------
  --  name:            CHG0033022 - Update Supply Information in WIP Material Requirements
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/11/2014
  --------------------------------------------------------------------
  --  purpose :        Update wip_supply_type, supply_subinventory, and supply_locator_id
  --                   at wip_requirement_operations tbl by:
  --                   take values from BOM if all 3 fields are null take from organization item. 
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  04/11/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure wip_change_supply_info (errbuf              out varchar2,
                                    retcode             out varchar2,
                                    p_organization_id   in  number,
                                    p_inventory_item_id in  number);                        

END xxwip_update_job_sup_sub;
/
