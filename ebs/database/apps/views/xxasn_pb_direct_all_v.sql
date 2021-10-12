create or replace view xxasn_pb_direct_all_v as
select
--------------------------------------------------------------------
--  name:            XXASN_PB_DIRECT_ALL_V
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   26/12/2011
--------------------------------------------------------------------
--  purpose :        REP339 - Objet Price Books from Oracle 1.8
--                   run report as disco report to be able to get
--                   result in excel.
--                   we do manipulation on the discoverer:
--                   here price list name will get null, on disco admin i connnect alternative LOV
--                   that show name but return id. at the report the condition is:
--                   price_list_name = PARAMETER or is null this give the ability to get LOV for the param
--                   and get the value from the parameter to use it for other calculations fields (set session param etc)
--
--                   select
--                   XXCS_SESSION_PARAM.set_session_param_number(9013,1)
--                   from dual;
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  26/12/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------
       territory,
       pb_type,
       platform,
       price_list_name,
       pb_category,
       part_number,
       description,
       currency,
       end_user_price,
       demo_unit_price,
       price,
       order_by
from   XXASN_PB_DIRECT_BASIC_V b
union  all
select territory,
       pb_type,
       platform,
       price_list_name,
       pb_category,
       part_number,
       description,
       currency,
       end_user_price,
       demo_unit_price,
       price,
       order_by
from   XXASN_PB_DIRECT_SUPPORT_V s
union  all
select territory,
       pb_type,
       platform,
       price_list_name,
       pb_category,
       part_number,
       description,
       currency,
       end_user_price,
       demo_unit_price,
       price,
       order_by
from   XXASN_PB_DIRECT_RESINS_V r
union all
select territory,
       pb_type,
       platform,
       price_list_name,
       pb_category,
       part_number,
       description,
       currency,
       end_user_price,
       demo_unit_price,
       price,
       order_by
from   XXASN_PB_DIRECT_SYSTEM_V sy;
