create or replace view xxcs_debrief_summary as
select t.incident_id INCIDENT_ID, t.item_number ITEM_NUMBER,  sum(t.quantity) QTY
from  xxcs_debrief_v t
where t.txn_type in ( 'Replace Part' , 'Replace Head')
/*and t.incident_id = 10043*/
group by  t.incident_id , t.item_number;

