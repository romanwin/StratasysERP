create or replace package body xxmfg_job_comp_suninv_pkg as
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
-- ver  date     name     desc
-- -----------------------------------------------------------------------------
-- 1.0  01/30/14 smisra   Initial Creation
--                         CR 1271
-- -----------------------------------------------------------------------------


FUNCTION before_report return boolean IS
BEGIN
  UPDATE WIP_REQUIREMENT_OPERATIONS
     set supply_subinventory = p_subinv
   where wip_entity_id          = p_entity_id
     and required_quantity      > 0
     and nvl(quantity_issued,0) = 0
     and wip_supply_type in ('2','3')
  ;
  fnd_file.put_line(fnd_file.log, 'Proceduure before_report, Rows updated = ' || sql%rowcount);
  return true;
EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, 'Error in procedure xxmfg_job_comp_suninv.before_report');
    fnd_file.put_line(fnd_file.log, 'Error Text = ' || sqlerrm);
    return false;
END;
end;
/