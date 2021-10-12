create or replace view xxasn_pb_indirect_basic_v as
select
--------------------------------------------------------------------
--  name:            XXASN_PB_INDIRECT_BASIC_V
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   27/12/2011
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
--  1.0  27/12/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------
       decode(flv.tag,
              'CN','OBJET CN (OU)',
              'DE','OBJET DE (OU)',
              'HK','OBJET HK (OU)',
              'IL','OBJET IL (OU)',
              'US','OBJET US (OU)',
              flv.tag)               territory,
       'Indirect'                    pb_type,
       'Desktop'                     platform,
       null                          price_list_name,
       'Basic'                       PB_Category,
       substr(flv.meaning,1,length(flv.meaning)-3)                                            part_number,
       flv.description                                                                        description,
       XXASN_PRICE_BOOK_PKG.get_currency (XXCS_SESSION_PARAM.get_session_param_number(1))     currency,
       XXASN_PRICE_BOOK_PKG.get_transfer_price (XXCS_SESSION_PARAM.get_session_param_number(1),
                                                flv.attribute3,
                                                substr(flv.meaning,1,length(flv.meaning)-3),
                                                null)                                         transfer_price,
       XXASN_PRICE_BOOK_PKG.get_user_price(flv.attribute4,
                                           substr(flv.meaning,1,length(flv.meaning)-3),
                                           XXCS_SESSION_PARAM.get_session_param_number(1),
                                           'Indirect')                                        end_user_price,
       null                          demo_unit_price,
       to_number(flv.attribute2)     order_by
from   fnd_lookup_values             flv,
       fnd_lookup_types_tl           flvt,
       fnd_lookup_types              flt
where  flv.lookup_type               = 'XX_PB_ALARIS_BASIC'
and    flv.lookup_type               = flt.lookup_type
and    flv.language                  = 'US'
and    flv.enabled_flag              = 'Y'
and    trunc(sysdate )               between nvl(flv.start_date_active, sysdate - 1)  and  nvl(flv.end_date_active, sysdate)
and    flvt.language                 = 'US'
and    flvt.lookup_type              = flv.lookup_type
union all
select decode(flv.tag,
              'CN','OBJET CN (OU)',
              'DE','OBJET DE (OU)',
              'HK','OBJET HK (OU)',
              'IL','OBJET IL (OU)',
              'US','OBJET US (OU)',
              flv.tag)               territory,
       'Indirect'                    pb_type,
       'Eden/Connex'                 platform,
       null                          price_list_name,
       'Basic'                       PB_Category,
       substr(flv.meaning,1,length(flv.meaning)-3)                                            part_number,
       flv.description                                                                        description,
       XXASN_PRICE_BOOK_PKG.get_currency (XXCS_SESSION_PARAM.get_session_param_number(1))     currency,
       XXASN_PRICE_BOOK_PKG.get_transfer_price (XXCS_SESSION_PARAM.get_session_param_number(1),
                                                flv.attribute3,
                                                substr(flv.meaning,1,length(flv.meaning)-3),
                                                null)                                         transfer_price,
       XXASN_PRICE_BOOK_PKG.get_user_price(flv.attribute4,
                                           substr(flv.meaning,1,length(flv.meaning)-3),
                                           XXCS_SESSION_PARAM.get_session_param_number(1),
                                           'Indirect')                                        end_user_price,
       null                          demo_unit_price,
       to_number(flv.attribute2)     order_by
from   fnd_lookup_values             flv,
       fnd_lookup_types_tl           flvt,
       fnd_lookup_types              flt
where  flv.lookup_type               = 'XX_PB_EDENCONNEX_BASIC'
and    flv.lookup_type               = flt.lookup_type
and    flv.language                  = 'US'
and    flv.enabled_flag              = 'Y'
and    trunc(sysdate )               between nvl(flv.start_date_active, sysdate - 1)  and  nvl(flv.end_date_active, sysdate)
and    flvt.language                 = 'US'
and    flvt.lookup_type              = flv.lookup_type;
