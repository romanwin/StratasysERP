create or replace view xxcs_debrief_tasks_summary as
select 
--------------------------------------------------------------------
--  name:            xxcs_debrief_tasks_summary
--  create by:       Adi Safin
--  Revision:        1.0
--  creation date:   01/04/2012
--------------------------------------------------------------------
--  purpose :        Discoverer Reports - Parts VS Debrief with tasks
--                   summary of all parts in the debrief at task level.
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/04/2012  Adi Safin        initial build
--------------------------------------------------------------------
       t.incident_id      incident_id, 
       t.item_number      item_number,  
       sum(t.quantity)    qty, 
       t.task_id
from   xxcs_debrief_v     t
where  t.txn_type         in ( 'Replace Part' , 'Replace Head')
group by  t.incident_id , t.item_number, t.task_id;
