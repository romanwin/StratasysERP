CREATE OR REPLACE PACKAGE xxmsc_mpp_load_pkg IS

--------------------------------------------------------------------
--  customization code: CUST032 - Upload MPP Planned Orders from Excel file
--  name:               xxmsc_mpp_load_pkg
--                            
--  create by:          RAN.SCHWARTZMAN
--  $Revision:          1.1 
--  creation date:      23/11/2009
--  Purpose:            load MPP from CSV file
--------------------------------------------------------------------
--  ver   date          name             desc
--  1.0   23/11/2009    RAN.SCHWARTZMAN  initial build  
--  1.1   05/07/10      yuval tal        add support for 18 months column in excel file
-------------------------------------------------------------------- 

   PROCEDURE main(errbuf              OUT VARCHAR2,
                  retcode             OUT VARCHAR2,
                  p_location          IN VARCHAR2,
                  p_filename          IN VARCHAR2,
                  p_plan_id           IN NUMBER,
                  p_start_period_name IN VARCHAR2,
                  p_day_of_month      IN NUMBER);

   PROCEDURE update_planned_orders(errbuf               OUT VARCHAR2,
                                   retcode              OUT VARCHAR2,
                                   p_compile_designator IN NUMBER,
                                   p_organization_id    IN NUMBER,
                                   p_date               IN VARCHAR2);

END xxmsc_mpp_load_pkg;
/

