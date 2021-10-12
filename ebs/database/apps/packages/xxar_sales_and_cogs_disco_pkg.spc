create or replace package xxar_sales_and_cogs_disco_pkg is
  -- Author  : Ofer Suad
  -- Created : 06/10/2013
  -- Purpose : Sale and Cogs   Disco Report
  ----------------------------------------------
  --  For view  get the from period start date 
  function get_start_date return date;
  ----------------------------------------------
   --  For view  get the to period end date 
  function get_end_date return date;
    ----------------------------------------------
    -- Called from disco - set the from period start date 
  function set_start_date(p_period_name varchar2) return number;
   ----------------------------------------------
    -- Called from disco - set the from period end date 
  function set_end_date(p_period_name varchar2) return number;
  
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_SHIP_TO_COUNTRY    
  Author's Name:   Sandeep Akula   
  Date Written:    11-JUNE-2014        
  Purpose:         Derives Ship To Country for the Ship To Customer on AR Invoice 
  Program Style:   Function Definition
  Called From:     Used in Discoverer Report "XX: AR Sales and Cogs". 
                   Folder Name: XXAR_SALES_AND_COGS_DISCO_V
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  11-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032350 
  ---------------------------------------------------------------------------------------------------*/
 FUNCTION GET_SHIP_TO_COUNTRY(p_cust_account_id IN NUMBER,
                              p_site_use_id IN NUMBER)
 RETURN VARCHAR2;
 
   
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_SHIP_TO_STATE    
  Author's Name:   Sandeep Akula   
  Date Written:    11-JUNE-2014        
  Purpose:         Derives Ship To State for the Ship To Customer on AR Invoice 
  Program Style:   Function Definition
  Called From:     Used in Discoverer Report "XX: AR Sales and Cogs". 
                   Folder Name: XXAR_SALES_AND_COGS_DISCO_V
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  11-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032350 
  ---------------------------------------------------------------------------------------------------*/
 FUNCTION GET_SHIP_TO_STATE(p_cust_account_id IN NUMBER,
                            p_site_use_id IN NUMBER)
 RETURN VARCHAR2;

end xxar_sales_and_cogs_disco_pkg;
/

