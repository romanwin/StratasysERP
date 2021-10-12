/*
REM $Header: INVCLRMO.sql 115.5 2002/03/09 16:23:25 kadavi noship $
REM 
REM             (c) Copyright Oracle Corporation 2001
REM                     All Rights Reserved
REM
REM HISTORY
REM This is script to clear Open move order lines which 
REM are not linked to Delivery details ,clean Orphan suggestions
REM in Mtl_material_transactions_temp and remove reservations 
REM link to Mtl_material_transactions_temp if reservations are
REM not existing.
REM  
REM Also this script creates and drop temp tables so Ct 
REM need to manually run this script.
REM dbdrv: sql ~PROD ~PATH ~FILE none none none sqlplus_single &phase=dat \
REM dbdrv: checkfile:~PROD:~PATH:~FILE 

WHENEVER SQLERROR CONTINUE ROLLBACK;


prompt dropping tables
drop table mtl_mmtt_CHG0043521_backup;
drop table mtl_mtrl_CHG0043521_backup;
drop table mtl_msnt_CHG0043521_backup;
drop table mtl_mtlt_CHG0043521_backup;
*/

WHENEVER SQLERROR CONTINUE ROLLBACK;


--prompt create table for MMTT backup

create table mtl_mmtt_CHG0043521_backup
as (
  select mmtt.*
  from mtl_material_transactions_temp mmtt,
       mtl_txn_request_lines mtrl,
       mtl_txn_request_headers mtrh
  where mmtt.move_order_line_id IS NOT NULL 
       AND mmtt.move_order_line_id = mtrl.line_id
       AND mtrl.line_status = 7
       and mtrl.header_id = mtrh.header_id
       and mtrh.move_order_type = 3
       and not exists (
	  select 'Y'
	    from wsh_delivery_details
	   where move_order_line_id = mtrl.line_id
	     and released_status = 'S'
          )
       )
/

--prompt select allocation records for closed move order

insert into mtl_mmtt_CHG0043521_backup 
(select mmtt.* 
 from mtl_material_transactions_temp mmtt, mtl_txn_request_lines mtrl
 where  mmtt.move_order_line_id = mtrl.line_id
   and  mtrl.line_status = 5
)
/
--prompt select allocation records with missing move order

insert into mtl_mmtt_CHG0043521_backup
(select mmtt.*
   from mtl_material_transactions_temp mmtt
  where move_order_line_id IS NOT NULL
    and not exists (
        select mtrl.line_id 
          from mtl_txn_request_lines mtrl
	 where mtrl.line_id = mmtt.move_order_line_id)
)
/
--prompt create backup table for move order lines

create table mtl_mtrl_CHG0043521_backup -- 1 record
as (
  select mtrl.*
    from mtl_txn_request_lines mtrl,
       mtl_txn_request_headers mtrh
   where mtrl.line_status = 7
       and mtrl.header_id = mtrh.header_id
       and mtrh.move_order_type = 3
       and not exists (
          select 'Y'
            from wsh_delivery_details
           where move_order_line_id = mtrl.line_id
	     and released_status = 'S'
        )
     )
/
--prompt create backup table for serial number allocations

create table mtl_msnt_CHG0043521_backup 
as(
  select msnt.* 
  from mtl_serial_numbers_temp msnt
  where msnt.transaction_temp_id IN
  (select transaction_temp_id from mtl_mmtt_CHG0043521_backup)
)
/
--prompt create backup table for lot number allocations

create table mtl_mtlt_CHG0043521_backup
as (
  select mtlt.* from mtl_transaction_lots_temp mtlt
  where mtlt.transaction_temp_id IN 
   (select transaction_temp_Id from mtl_mmtt_CHG0043521_backup)
 )
/
--prompt select serial number allocations for lot controlled items

insert into mtl_msnt_CHG0043521_backup
(select msnt.* from mtl_serial_numbers_temp msnt
where msnt.transaction_temp_id IN
(select serial_transaction_temp_id
 from mtl_mtlt_CHG0043521_backup)
)
/
--prompt delete serial number allocations

delete from mtl_serial_numbers_temp
where transaction_temp_id IN
(select transaction_temp_id from mtl_msnt_CHG0043521_backup)
/ 
--prompt delete lot number allocations

delete from mtl_transaction_lots_temp
where transaction_temp_id IN 
(select transaction_temp_id from mtl_mtlt_CHG0043521_backup)
/
--prompt delete allocations

delete from mtl_material_transactions_temp
where transaction_temp_id IN
(select transaction_temp_id from mtl_mmtt_CHG0043521_backup)
/
--prompt close move order lines

update mtl_txn_request_lines
set quantity = 0,
    quantity_detailed = 0,
    line_status = 5
where line_id IN
(select line_id from mtl_mtrl_CHG0043521_backup)
/
--prompt update transaction source on the move order line

update mtl_txn_request_lines mtrl
set mtrl.txn_source_line_id = 
(select distinct(source_line_id) from wsh_delivery_details
where move_order_line_id = mtrl.line_id
and released_status = 'S')
where mtrl.line_status = 7
and exists (select delivery_detail_id
from wsh_delivery_details wdd
where move_order_line_Id = mtrl.line_Id
and wdd.source_line_id <> mtrl.txn_source_line_id
and wdd.source_line_id > 0
and wdd.released_status = 'S')
/
--prompt update transaction source on the allocation

update mtl_material_transactions_temp mmtt
set mmtt.trx_source_line_id = 
(select txn_source_line_id
from mtl_txn_request_lines 
where line_id = mmtt.move_order_line_id)
where mmtt.transaction_type_id IN (52, 53)
and mmtt.move_order_line_id IS NOT NULL
and exists (
select line_id from mtl_txn_request_lines
where line_status = 7
and line_id = mmtt.move_order_line_id
and txn_source_line_id <> mmtt.trx_source_line_id)
/
--prompt update allocations for missing reservations

update mtl_material_transactions_temp mmtt
set reservation_id = NULL
where mmtt.reservation_id IS NOT NULL
and not exists (
select mr.reservation_id from mtl_reservations mr
where reservation_id = mmtt.reservation_id)

/*prompt Drop these temp tables after one week:
prompt mtl_mmtt_CHG0043521_backup 
prompt mtl_mtrl_CHG0043521_backup
prompt mtl_msnt_CHG0043521_backup
prompt mtl_mtlt_CHG0043521_backup
*/
/
commit
/
EXIT;
/
