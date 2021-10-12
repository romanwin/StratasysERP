create or replace package XXHZ_SF_BUSINESS_EVENTS_PKG is

--------------------------------------------------------------------
--  customization code: CHG0034741 - New Interface OA2SF for Account relationships
--  name:               XXHZ_SF_BUSINESS_EVENTS_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      17/05/2015 11:44:06
--  Description:        General package that handle all HZ business events for SF
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   17/05/2015    Dalit A. Raviv  initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0034741 - New Interface OA2SF for Account relationships
  --  name:               CustAcctRelate
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        Procedure that will handle create and update of
  --                      relationship between account.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  function CustAcctRelate(p_subscription_guid in raw,
	                        p_event             in out wf_event_t) return varchar2;

  --------------------------------------------------------------------
  --  customization code: CHG0036771 - Business event on merge table to execute SFDC merge process 
  --  name:               CustAcctMerge
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        Procedure that will handle customer account merge 
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  function Cust_Acct_Merge (p_subscription_guid in raw,
	                          p_event             in out wf_event_t) return varchar2;

  --------------------------------------------------------------------
  --  customization code: CHG0034741 - New Interface OA2SF for Account relationships
  --  name:               get_business_events_params
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        function that can help to know what are the parameters
  --                      of the xml. for the use of developers only.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  function get_business_events_params (p_subscription_guid in raw,
                                       p_event             in out wf_event_t) return varchar2;
  
end XXHZ_SF_BUSINESS_EVENTS_PKG;
/
