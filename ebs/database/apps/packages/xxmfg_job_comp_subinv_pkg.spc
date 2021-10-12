create or replace package  xxmfg_job_comp_suninv_pkg as
--------------------------------------------------------------------------------
--  name:              xxmfg_job_comp_suninv_pkg
--  created by:        sanjai k misra    
--  Revision:          1.0
--  creation date:     01/30/2014
--------------------------------------------------------------------------------
--  purpose :          This package is called by before report trigger of 
--                     xml report xxmfg_job_comp_suninv. This pkg updates
--                     subinvetory for job components to a given value
--                     that have required quantity > o and issued quantity is
--                     equal to 0. 
--------------------------------------------------------------------------------
--  ver  date     name     desc
--  1.0  01/30/14 smisra   Initial Creation
--                         CR 1271
-- -----------------------------------------------------------------------------
   p_entity_id    NUMBER;
   p_subinv       VARCHAR2(80);

function before_report return boolean;
end;
/