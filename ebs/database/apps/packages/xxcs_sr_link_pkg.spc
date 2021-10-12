create or replace package XXCS_SR_LINK_PKG is

--------------------------------------------------------------------
--	customization code: CUST310 - Activate Create Link and update SR
--	name:               XXCS_SR_LINK_PKG
--                            
--	create by:          Dalit A. Raviv
--	$Revision:          1.0 
--	creation date:	    03/05/2010 2:10:59 PM
--  Purpose:            Activate Create Link and update SR
--------------------------------------------------------------------
--  ver   date          name            desc
-- 	1.0		03/05/2010    Dalit A. Raviv	initial build     
--------------------------------------------------------------------   
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_link_exists
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      03/05/2010 
  --  Description:        Function that check id link exist between 
  --                      2 specific SR's.            
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   03/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------                                 
  function get_link_exists  (p_o_incident_id in number,
                             p_s_incident_id in number) return varchar2; 
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_incident_number
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      04/05/2010 
  --  Description:        Function that get incident id and return the number
  --                      use for the messages in the program           
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------     
  function get_incident_number (p_incident_id in number) return varchar2; 
  
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               get_link_type_name
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      04/05/2010 
  --  Description:        Function return the link type name for the API           
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------     
  function get_link_type_name  (p_link_type_id in number) return varchar2;  
     
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      04/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------  
  Procedure upd_profile (p_timestamp    in  date,
                         p_error_code   out number,
                         p_error_desc   out varchar2);
                                             
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               create_incident_link
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      03/05/2010
  --  Description:        procedure that go throught SR population and
  --                      create SR link's. 
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   03/05/2010    Dalit A. Raviv  initial build
  -------------------------------------------------------------------- 
  procedure create_incident_link(errbuf   out varchar2,
                                 retcode  out varchar2);                              
  
end XXCS_SR_LINK_PKG;
/

