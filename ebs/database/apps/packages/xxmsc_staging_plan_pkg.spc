CREATE OR REPLACE PACKAGE xxmsc_staging_plan_pkg IS

  --------------------------------------------------------------------
  --  name:            XXMSC_STAGING_PLAN_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/06/2012
  --------------------------------------------------------------------
  --  purpose :        
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2010  Vitaly K.         initial build
  --  1.1  25/06/2012  Dalit A. Raviv    add procedure: set_planning_time_fence
  --  1.2  26/06/2014  yuval tal         CHG0032542 : add clear_source_org 

  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            set_planning_time_fence
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/06/2012
  --------------------------------------------------------------------
  --  purpose :        CUST504 - Planning Time Fence by Date
  --                   Resin planners in Objet need to have Planning time Fence as a specific date.
  --                   The Planning time fence in Oracle is loaded to the item as number of days 
  --                   thus the Planning time fence is related to the MPP/MRP running date.
  --                   The planning time fence is managed by days in the organization item 
  --                   and Planning time fence is related to the running date.
  --                   Objet planners would like to have a firm Planning time fence that 
  --                   is not influenced by the MRP/MPP running date.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_planning_time_fence(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            set_short_expiration_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2012
  --------------------------------------------------------------------
  --  purpose :        CUST504 - Planning Time Fence by Date
  --                   Resin LOT’s are controlled with Expiration date.
  --                   Each resin item have minimum selling months, this mean that it is 
  --                   not allowed to sell LOT that is under the minimum selling months.
  --
  --                   Resin planners in Objet would like to short the expiration date in the 
  --                   planning workbench with the minimum selling expiration months for LOT’s 
  --                   that are located in all organizations.
  --
  --                   The concurrent will take the expiration date from the table msc_st_supplies in 
  --                   field expiration_date for all items in organization WPI that have the order type “on hand”(18). 
  --                   Then, the concurrent will take the minimum selling expiration months from item DFF in the 
  --                   field attribute7 in the table mtl_system_items_b for WPI organization and the relevant 
  --                   item and will short the expiration date by the minimum selling expiration months (month).
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_short_expiration_date(errbuf  OUT VARCHAR2,
                                      retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            set_short_expiration_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/07/2012
  --------------------------------------------------------------------
  --  purpose :        CUST505 - Average consumption Calculation  
  --                   Resin item will be loaded with Forecasts for the coming year to predict the 
  --                   future consumption for an item and create demand in the system.
  --                   We would like to calculate the average future consumption for an item based on 
  --                   the item forecast.
  --                   Objet Planners need to know the average future consumption for their calculations. 
  --                   In addition, there will be a need of this calculation in many planning reports.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                 
  PROCEDURE set_average_consumption_calc(errbuf          OUT VARCHAR2,
                                         retcode         OUT VARCHAR2,
                                         p_num_of_months IN NUMBER);

  --------------------------------------------------------------------
  --  name:            clear_source_org
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.6.14
  --------------------------------------------------------------------
  --  purpose :        CHG0032542 - Clear default ISK Org source in Planning staging tables
  --                  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.6.14     yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE clear_source_org(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

END xxmsc_staging_plan_pkg;
/
