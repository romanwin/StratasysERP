/******************************************************************************************************
  File Name  : xx_wip_filament_jobs_pkg.pks
  Author     : Rajeeb Das
  Date       : 17-SEP-2013
  
  Description: This Package has the Procedure to extract Job details for 
               Filament Jobs for the Strat System.
  Parameters : Standard Concurrent Program Parameters.

  MODIFICATION HISTORY
  --------------------
  DATE        NAME         DESCRIPTION
  ----------  -----------  --------------------------------------------------------------
  17-SEP-2013 RDAS         Initial Version.

*******************************************************************************************************/
CREATE OR REPLACE PACKAGE xx_wip_filament_jobs_pkg
AS

  PROCEDURE XX_WIP_FLMT_EXTR_JOBS_EXTRACT(errbuf     OUT varchar2
                                         ,retcode   OUT number);




END xx_wip_filament_jobs_pkg;
/
show errors
exit