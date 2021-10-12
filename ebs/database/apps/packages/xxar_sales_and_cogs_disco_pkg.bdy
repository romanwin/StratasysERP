create or replace package body xxar_sales_and_cogs_disco_pkg is
  -- Author  : Ofer Suad
  -- Created : 06/10/2013
  -- Purpose : Sale and Cogs   Disco Report
  -- Global variables 
  g_start_date date;
  g_end_date   date;
  -------------------------------------
    --  For view  get the from period start date 
  function get_start_date return date is
  begin
    return g_start_date;
  end;
  ------------------------------------
    --  For view  get the to period end date 
  function get_end_date return date is
  begin
    return g_end_date;
  end;
  ------------------------------------
   -- Called from disco - set the from period start date 
  function set_start_date(p_period_name varchar2) return number is
  begin
    select start_date
      into g_start_date
      from gl_periods gp
     where gp.period_name = p_period_name
       and gp.period_set_name = 'OBJET_CALENDAR';
    return 1;
  exception
    when others then
      return 0;
  end;
  -------------------------------------
    -- Called from disco - set the from period end date 
  function set_end_date(p_period_name varchar2) return number is
  begin
    select end_date
      into g_end_date
      from gl_periods gp
     where gp.period_name = p_period_name
       and gp.period_set_name = 'OBJET_CALENDAR';
    return 1;
  exception
    when others then
      return 0;
  end;
    -------------------------------------
    
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
 RETURN VARCHAR2 IS
 l_country VARCHAR2(100);
 BEGIN
 
begin 
select hl.country
into l_country
from hz_cust_accounts_all hca,
    hz_parties hp,
    hz_cust_acct_sites_all hcas,
    hz_party_sites hps,
    hz_locations hl,
    hz_cust_site_uses_all hcsu
where hca.party_id = hp.party_id and
      hca.cust_account_id = hcas.cust_account_id and
      hcas.party_site_id = hps.party_site_id and
      hps.location_id = hl.location_id and
      hcas.cust_Acct_site_id = hcsu.cust_acct_site_id and
      hca.cust_Account_id = p_cust_account_id and
      hcsu.site_use_id = p_site_use_id;
exception
when others then
l_country := '';
end;
 
RETURN(l_country); 
END GET_SHIP_TO_COUNTRY; 
   
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
 RETURN VARCHAR2 IS
 
 l_state VARCHAR2(100);
 BEGIN
 
begin 
select hl.state
into l_state
from hz_cust_accounts_all hca,
    hz_parties hp,
    hz_cust_acct_sites_all hcas,
    hz_party_sites hps,
    hz_locations hl,
    hz_cust_site_uses_all hcsu
where hca.party_id = hp.party_id and
      hca.cust_account_id = hcas.cust_account_id and
      hcas.party_site_id = hps.party_site_id and
      hps.location_id = hl.location_id and
      hcas.cust_Acct_site_id = hcsu.cust_acct_site_id and
      hca.cust_Account_id = p_cust_account_id and
      hcsu.site_use_id = p_site_use_id;
exception
when others then
l_state := '';
end;
 
RETURN(l_state); 
END GET_SHIP_TO_STATE;
    
end xxar_sales_and_cogs_disco_pkg;
/

