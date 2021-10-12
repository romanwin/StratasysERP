CREATE OR REPLACE PACKAGE xxcs_auto_return_deb IS
--------------------------------------------------------------------
--  customization code: CUST017 - XXCS_AUTO_RETURN_DEB 
--  name:               XXCS_AUTO_RETURN_DEB
--                            
--  create by:          XXX
--  $Revision:          1.0 
--  creation date:      31/08/2009 1:32:25 PM
--  Purpose:            CLose debrief lines and create move orders for service tasks
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   31/08/2009    XXX             initial build  
--  1.1   08/04/2010    Vitaly          add logic changes
--  1.2   16/05/2010    Vitaly          add condition to CURSOR cr_deb_header at create_move_order procedure  
--  1.3   28/10/2010    Dalit A. Raviv  procedure create_move_order :
--                                      change population of cursor cr_deb_lines add 
--                                      lines of return that do not have part requirement.
--  1.4   02/01/2011    Roman V.        add validation of subinv. to part
--                                      Get MO lines for PR that were not assign to deb
-------------------------------------------------------------------- 

  PROCEDURE create_move_order(p_task_assignment_id IN  NUMBER,
                              p_return_status      OUT VARCHAR2,
                              p_return_message     OUT VARCHAR2);
                              
  -- this is the procedure the conccurent call.                              
  PROCEDURE create_return_deb(errbuf               OUT VARCHAR2,
                              retcode              OUT VARCHAR2,
                              p_instance_number    IN  NUMBER);
                              
  --------------------------------------------------------------------
  --  customization code: CUST017 - Debrief Closure / CUST281 - XXCS_AUTO_RETURN_DEB 
  --  name:               update_status_to_closed
  --                            
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      31/05/2012 
  --  Purpose:            update status to Closed at debrief, task assignment and task. 
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/05/2012    Dalit A. Raviv  initial build  
  -------------------------------------------------------------------- 
  procedure update_status_to_closed (p_debrief_header_id in  number,
                                     p_return_status     out varchar2,
                                     p_err_msg           out varchar2) ;                              

--Procedure Approve_MO(P_Header_Id In Number,P_Line_Id In Number);
END xxcs_auto_return_deb;
/
