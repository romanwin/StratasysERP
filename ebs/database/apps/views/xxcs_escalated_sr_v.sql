CREATE OR REPLACE VIEW XXCS_ESCALATED_SR_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_ESCALATED_SR_V
--  create by:       Yoram Zamir
--  Revision:        1.0
--  creation date:   07/01/2010
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  07/01/2010  Yoram Zamir      initial build
--  1.1  XX/XX/20XX  XXXXXXXXXXX      XXXXXXXXXXXXX
--
--------------------------------------------------------------------
       t.source_object_id   incident_id,
       t.source_object_name incident_number,
       MIN(t.creation_date) task_creation_date
FROM   jtf_tasks_b t
WHERE
       EXISTS      -- Tasks type = Escalated
                   (SELECT 1 FROM
                   (
                   SELECT tasks.task_type_id
                    FROM
                           (
                           SELECT t.task_type_id,
                           tt.name,
                           tf.xxcs_esc_flag esc_flag,
                           tf.xxcs_on_site  on_site
                    FROM   jtf_task_types_b t,
                           jtf_task_types_b_dfv tf,
                           jtf_task_types_tl tt
                    WHERE  t.rowid = tf.row_id AND
                           t.task_type_id = tt.task_type_id AND
                           tt.language = 'US' AND
                           t.rule = 'DISPATCH' AND
                           SYSDATE BETWEEN nvl(t.start_date_active, SYSDATE) AND nvl(t.end_date_active, SYSDATE)
                           ) TASKS
                    WHERE  tasks.esc_flag = 'Y'
                                       ) esc
                   WHERE t.task_type_id  = esc.task_type_id)
AND
       NOT EXISTS  --Tasks stsus <> Cancelled
                   (SELECT   1 FROM
                   (
                    SELECT task_sts.task_status_id
                    FROM
                           (
                           SELECT
                           ts.task_status_id,
                           tsd.name,
                           tsd.description ,
                           ts.completed_flag,
                           ts.cancelled_flag,
                           ts.closed_flag,
                           ts.assigned_flag
                    FROM   jtf_task_statuses_b ts,
                           jtf_task_statuses_tl tsd
                    WHERE  ts.task_status_id = tsd.task_status_id  AND
                           tsd.language = 'US' AND
                           ts.usage = 'TASK' AND
                           SYSDATE BETWEEN nvl(ts.start_date_active, SYSDATE) AND nvl(ts.end_date_active, SYSDATE)
                           ) TASK_STS
                    WHERE  task_sts.cancelled_flag = 'Y'
                   ) TASK_STS
                   WHERE t.task_status_id = task_sts.task_status_id )
AND                t.source_object_type_code =  'SR'
GROUP BY t.source_object_id ,
         t.source_object_name;

