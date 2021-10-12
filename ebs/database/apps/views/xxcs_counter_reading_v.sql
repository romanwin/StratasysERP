create or replace view xxcs_counter_reading_v as
select
--------------------------------------------------------------------
--  name:            xxcs_counter_reading_v
--  create by:       Yoram Zamir
--  Revision:        1.1
--  creation date:   01/01/2010
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/01/2010  Yoram Zamir      initial build
--  1.1  23/08/2010  Roman            Removed disabled readings
--  1.2  15/03/2012  Dalit A. Raviv   add field inventory_item_id
--------------------------------------------------------------------
       cii.serial_number,
       ccr.counter_reading,
       ccr.value_timestamp,
       cii.inventory_item_id
from   csi_counter_readings       ccr,
       csi_counter_associations_v cca,
       csi_item_instances         cii
where  cii.instance_id            = cca.source_object_id (+)
and    ccr.counter_id             = cca.counter_id
and    ccr.disabled_flag          = 'N';
