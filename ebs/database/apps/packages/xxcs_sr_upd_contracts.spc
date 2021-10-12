create or replace package XXCS_SR_UPD_CONTRACTS is

--------------------------------------------------------------------
--  customization code: CUST311 - Activate Get Contract and update SR
--  name:               XXCS_SR_UPD_CONTRACTS
--                      
--  create by:          Dalit A. Raviv
--  Revision:           1.0 
--  creation date:      28/04/2010 9:07:38 AM
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   28/04/2010    Dalit A. Raviv  initial build
--  1.1   10/06/2010    Dalit A. Raviv  Fix error at Upd_sr_with_contract
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  customization code: CUST311 - Activate Get Contract and update SR
  --  name:               Upd_sr_with_contract
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      28/04/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2010    Dalit A. Raviv  initial build
  --  1.1   10/06/2010    Dalit A. Raviv  The program do not update the profile because the message
  --                                      from Update_ServiceRequest is too long and then 
  --                                      the program jump to general exception.
  --                                      * add handle of the error message come from API
  --------------------------------------------------------------------
  Procedure Upd_sr_with_contract (errbuf   out varchar2,
                                  retcode  out varchar2);
  
  --------------------------------------------------------------------
  --  customization code: CUST311 - Activate Get Contract and update SR
  --  name:               upd_profile
  --                      
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0 
  --  creation date:      02/05/2010 9:07:38 AM
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   02/05/2010    Dalit A. Raviv  initial build
  -------------------------------------------------------------------- 
  Procedure upd_profile (p_timestamp    in  date,
                         p_error_code   out number,
                         p_error_desc   out varchar2);
                         
                        
                         
end XXCS_SR_UPD_CONTRACTS;
/

