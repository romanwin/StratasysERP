--------------------------------------------------------------------
--  customization code: Datafix for INC011984
--  name:               Datafix for XXWSH_DELIVERY_DETAILS_BUR_TRG  
--  create by:          Bellona Banerjee
--  Revision:           1.0
--  creation date:      17.1.2018
--------------------------------------------------------------------
--  purpose :           To delete all events created by target_name 
--						= 'BACKORDER_NTY' & entity_name = 'DELIVERY'
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   19.01.2018   Bellona Banerjee INC011984 - Multiple Back order 
--										notifications send to user.
--------------------------------------------------------------------------

UPDATE  xxssys_events t
SET status='SUCCESS',t.last_update_date=SYSDATE,t.err_message='closed by INC011984 '
WHERE  target_name = 'BACKORDER_NTY'
AND    entity_name = 'DELIVERY'
AND    status ='NEW'
;

COMMIT;
/