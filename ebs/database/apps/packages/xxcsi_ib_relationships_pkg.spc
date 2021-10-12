create or replace package XXCSI_IB_RELATIONSHIPS_PKG is
 
--------------------------------------------------------------------
--	customization code: CUST280 - IB - Upgrade IB Serial
--	name:               XXCS_SR_LINK_PKG
--                            
--	create by:          Dalit A. Raviv
--	$Revision:          1.0 
--	creation date:	    10/05/2010 1:32:25 PM
--  Purpose:            Activate Create Link and update SR
--------------------------------------------------------------------
--  ver   date          name            desc
--   1.0    10/05/2010    Dalit A. Raviv  initial build     
-------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  customization code: CUST280
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      10/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------  
  Procedure upd_profile (p_timestamp    in  date,
                         p_error_code   out number,
                         p_error_desc   out varchar2);

  --------------------------------------------------------------------
  --  customization code: CUST280
  --  name:               create_ib_relationship
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      10/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/05/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------  
  Procedure create_ib_relationship (errbuf   out varchar2,
                                    retcode  out varchar2);
 
end XXCSI_IB_RELATIONSHIPS_PKG;
/
