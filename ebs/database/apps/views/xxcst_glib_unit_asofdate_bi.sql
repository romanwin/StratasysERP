create or replace view xxcst_glib_unit_asofdate_bi as
select "INSTANCE_ID","ITEM_NUMBER","DESCRIPTION","SERIAL_NUMBER","QTY","CONV_COST","COMPANY","ORG_ID","INVENTORY_ITEM_ID","UNIT_OF_MEASURE" from xxcst_glib_unit_asofdate t
where ((xxcs_session_param.set_session_param_date(to_date(SYSDATE),
                                                           1)) = 1);

