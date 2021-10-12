CREATE OR REPLACE PACKAGE xx_inv_kanban_status_chng_pkg AUTHID CURRENT_USER
/******************************************************************************************************
  Package    : XX_INV_KANBAN_STATUS_CHNG_PKG
  Author     : Rajeeb Das
  Date       : 04-DEC-2013

  Description: This Package is used to change the Kanban supply status
               to Empty or Wait.


  MODIFICATION HISTORY
  --------------------
  DATE        NAME         DESCRIPTION
  ----------  -----------  --------------------------------------------------------------
  04-DEC-2013 RDAS         Initial Version.

*******************************************************************************************************/
AS
  PROCEDURE  p_chng_kanban_status(errbuf             OUT  varchar2
                                 ,retcode            OUT  number
                                 ,p_mfg_org_id       IN   number
                                 ,p_kanban_status    IN   varchar2);


END xx_inv_kanban_status_chng_pkg;
/
