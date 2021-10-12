CREATE OR REPLACE TRIGGER xxcs_task_all_assign_air_trg
   ---------------------------------------------------------------------------
   -- $Header: xxcs_task_all_assign_air_trg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxcs_task_all_assign_air_trg
   -- Created: Maoz
   -- Author  : 02/06/2009
   --------------------------------------------------------------------------
   -- Perpose: update task description
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
  AFTER INSERT ON Jtf_Task_All_Assignments
  FOR EACH ROW

DECLARE
   v_prof      VARCHAR2(10);
   v_task_desc VARCHAR2(500);
   v_error     VARCHAR(4000);
BEGIN

   UPDATE csp_requirement_headers crh
      SET crh.task_assignment_id = :NEW.task_assignment_id
    WHERE crh.task_id = :NEW.task_id AND
          task_assignment_id IS NULL;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END xxcs_task_all_assign_air_trg;
/

