create or replace view xxasn_price_book_list_names_v as
select
--------------------------------------------------------------------
--  name:            XXASN_PRICE_BOOK_LIST_NAMES_V
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   13/12/2011
--------------------------------------------------------------------
--  purpose :        View that show all price list names and types
--                   by territory for price book.
--                   REP339 - Objet Price Books from Oracle 1.7
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/12/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------
       'Eden/Connex'            view_entity,
       ffv.flex_value           price_list_header_id,
       qh.name                  price_list_name,
       ffv.attribute1           price_list_type,
       --nvl(qha.orig_org_id,81)  territory,
       qha.orig_org_id          territory,
       'N'                      check_row
from   fnd_flex_values          ffv,
       fnd_flex_value_sets      ffvs,
       qp_list_headers_tl       qh,
       qp_list_headers_all_b    qha
where  ffvs.flex_value_set_name = 'XXPB_PRICE_LISTS'
and    ffv.flex_value_set_id    = ffvs.flex_value_set_id
and    qh.list_header_id        = ffv.flex_value
and    qh.language              = 'US'
and    qh.list_header_id        = qha.list_header_id
union all
select 'Desktop'                view_entity,
       ffv.flex_value           price_list_header_id,
       qh.name                  price_list_name,
       ffv.attribute1           price_list_type,
       --nvl(qha.orig_org_id,81)  territory,
       qha.orig_org_id          territory,
       'N'                      check_row
from   fnd_flex_values          ffv,
       fnd_flex_value_sets      ffvs,
       qp_list_headers_tl       qh,
       qp_list_headers_all_b    qha
where  ffvs.flex_value_set_name = 'XXPB_PRICE_LISTS'
and    ffv.flex_value_set_id    = ffvs.flex_value_set_id
and    qh.list_header_id        = ffv.flex_value
and    qh.language              = 'US'
and    qh.list_header_id        = qha.list_header_id;
