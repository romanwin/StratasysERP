create or replace view xxasn_pb_direct_resins_v as
select
--------------------------------------------------------------------
--  name:            XXASN_PB_DIRECT_RESINS_V
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
        decode(flv.tag,
               'CN','OBJET CN (OU)',
               'DE','OBJET DE (OU)',
               'HK','OBJET HK (OU)',
               'IL','OBJET IL (OU)',
               'US','OBJET US (OU)',
               flv.tag)               territory,
        'Direct'                      pb_type,
        'Eden/Connex'                 platform,
        /*XXASN_PRICE_BOOK_PKG.get_price_list_name(XXCS_SESSION_PARAM.get_session_param_number(1)) price_list_name,*/
        null                          price_list_name,
        'Resins'                      PB_Category,
        --null                         entity_name,
        substr(flv.meaning,1,length(flv.meaning)-3)                                              part_number,
        flv.description               description,
        XXASN_PRICE_BOOK_PKG.get_currency(XXCS_SESSION_PARAM.get_session_param_number(1))        currency,
        XXASN_PRICE_BOOK_PKG.get_transfer_price(XXCS_SESSION_PARAM.get_session_param_number(1),
                                         flv.attribute4,
                                         substr(flv.meaning,1,length(flv.meaning)-3),
                                         null)                                                   end_user_price,
        null                          demo_unit_price,
        flv.attribute4                price,
        to_number(flv.attribute1)     order_by
from    fnd_lookup_values             flv,
        fnd_lookup_types              flt
where   flv.lookup_type               = 'XX_PB_RESINS'
and     flv.lookup_type               = flt.lookup_type
and     flv.language                  = 'US'
and     flv.enabled_flag              = 'Y'
and     trunc(sysdate)                between nvl(flv.start_date_active, sysdate - 1) and nvl(flv.end_date_active, sysdate)
union all
select  decode (flv.tag,
               'CN','OBJET CN (OU)',
               'DE','OBJET DE (OU)',
               'HK','OBJET HK (OU)',
               'IL','OBJET IL (OU)',
               'US','OBJET US (OU)')  territory,
        'Direct'                      pb_type,
        'Desktop'                     platform,
        /*XXASN_PRICE_BOOK_PKG.get_price_list_name(XXCS_SESSION_PARAM.get_session_param_number(1)) price_list_name,*/
        null                          price_list_name,
        'Resins'                      PB_Category,
        --null                         entity_name,
        substr(flv.meaning,1,length(flv.meaning)-3)                                              part_number,
        flv.description               description,
        XXASN_PRICE_BOOK_PKG.get_currency(XXCS_SESSION_PARAM.get_session_param_number(1))        currency,
        XXASN_PRICE_BOOK_PKG.get_transfer_price(XXCS_SESSION_PARAM.get_session_param_number(1),
                                         flv.attribute4,
                                         substr(flv.meaning,1,length(flv.meaning)-3),
                                         null)                                                   end_user_price,
        null                          demo_unit_price,
        flv.attribute4                price,
        to_number(flv.attribute1)     order_by
from    fnd_lookup_values             flv,
        fnd_lookup_types              flt
where   flv.lookup_type               = 'XX_PB_RESINS_ALARIS'
and     flv.lookup_type               = flt.lookup_type
and     flv.language                  = 'US'
and     flv.enabled_flag              = 'Y'
and     trunc(sysdate)                between nvl(flv.start_date_active, sysdate - 1) and nvl(flv.end_date_active, sysdate);
