create or replace package xx_wip_filament_jobs_pkg AS
  --------------------------------------------------------------------
  --  name:            XX_WIP_FILAMENT_JOBS_PKG
  --  create by:       Rajeeb Das
  --  Revision:        1.0
  --  creation date:   17-SEP-2013
  --------------------------------------------------------------------
  --  purpose :        This Procedure to extracts Job details for
  --                   Filament Jobs for the Strat System.
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17-SEP-2013 RDAS              Initial Version.
  --  1.1  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness - FDM Auto Job Completion by interface
  --------------------------------------------------------------------
  
  --------------------------------------------------------------------------
  -- Purpose:  This Procedure to extracts Job details for
  --           Filament Jobs for the Strat System.
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  17-SEP-2013  RDAS            Initial Version.  
  ---------------------------------------------------------------------------    
  PROCEDURE xx_wip_flmt_extr_jobs_extract(errbuf  OUT VARCHAR2,
                                          retcode OUT NUMBER);
  --------------------------------------------------------------------
  --  name:            xx_wip_flmt_jobs_cmpl
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :        
  --                   
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness - FDM Auto Job Completion by interface
  --------------------------------------------------------------------                                         
  PROCEDURE xx_wip_flmt_jobs_cmpl(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  --------------------------------------------------------------------
  --  name:            update_lot_dff
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-Dec-2018
  --------------------------------------------------------------------
  --  purpose :        Update Lot Attribute Attribute 2
  --                   
  --  Parameters :     Standard Concurrent Program Parameters.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18-Dec-2018 Lingaraj          CHG0044616 - manufacturing readiness
  --------------------------------------------------------------------                                         
  Procedure update_lot_dff(p_organization_id NUMBER,
                           p_inv_item_id     NUMBER,
                           p_lot_number      VARCHAR2,
                           p_expiration_date DATE,
                           p_attribute2      VARCHAR2, -- Case Number
                           x_status          OUT Varchar2,
                           x_err_msg         OUT Varchar2);
END xx_wip_filament_jobs_pkg;
/
