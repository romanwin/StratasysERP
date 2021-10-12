CREATE OR REPLACE TRIGGER xxclef062_po_release
--------------------------------------------------------------------
--  name:            XXCLEF062_PO_RELEASE
--  create by:       Yuval Tal
--  Revision:        1.0
--  creation date:   16/07/2013
--------------------------------------------------------------------
--  purpose :        correct oracle trigger CLEF062_PO_RELEASE
--                   to handle document_id and reales num
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  16/07/2013  Yuval Tal         initial build
--------------------------------------------------------------------
before insert or update of release_num on po_releases_all
referencing NEW as NEW OLD as OLD
for each row
  -- Execute only for distributions created by PO matching. This trigger should not get fired
  -- IF the line is created because of reversal of distribution or cancellation of Invoice
when ( NEW.RELEASE_TYPE = 'BLANKET'  )
DECLARE
  lc_module          varchar2(240);
  lc_document_id     varchar2(240);
  lc_currency_code   varchar2(240);
  lc_conversion_type varchar2(240);
  ln_linkage_to      number;
  lc_base_rate       number;
  ld_base_date       date;
  lc_currency_name   varchar2(240);
  lc_description     varchar2(240);
  ln_rate_limit      number;
  lc_country_flag    varchar2(10);  -- as per bug#13862194
  v_org_id           number;        -- as per bug#13862194
  v_error_message    varchar2(100); -- as per bug#13862194

BEGIN

  v_org_id := fnd_profile.value('ORG_ID');
  begin
    select decode(nvl(jg_zz_shared_pkg.get_country(v_org_id), 'US'), 'IL',  'Y', 'N')
      into lc_country_flag
      from dual;
  exception
    when others then
      fnd_message.set_name('CLE', 'CLE_F062_AP_TRIG1_ERR5');
      v_error_message := fnd_message.get;
      raise_application_error(-20000, v_error_message);
  end;

  if lc_country_flag = 'Y' then
    if inserting then
      begin
     	 SELECT   cpie.module
		        , cpie.document_id
				, cpie.currency_code
				, cpie.conversion_type
				, cpie.linkage_to
				, cpie.base_rate
				, cpie.base_date
				, cpie.currency_name
				, cpie.description
				, cpie.rate_limit
         INTO
                  lc_module
                , lc_document_id
                , lc_currency_code
                , lc_conversion_type
                , ln_linkage_to
                , lc_base_rate
                , ld_base_date
				, lc_currency_name
                , lc_description
				, ln_rate_limit
          FROM    clef062_po_index_esc_set     cpie
                 ,po_headers_all               poh
-- Changed the where clause to refer to po_header_id instead of document_id(po_number) as per ER# 12710151
--          WHERE   cpie.document_id           = poh.segment1
          WHERE   cpie.po_header_id           = poh.po_header_id
          AND     cpie.release_num           = 0
          AND     poh.po_header_id           = :NEW.po_header_id
          AND     poh.type_lookup_code       = 'BLANKET';

      exception
        when no_data_found then
          null;
        when too_many_rows then
          raise;
      end;
    
      if lc_document_id is not null then
           INSERT INTO CLEF062_PO_INDEX_ESC_SET(
		                                    module
										  , document_id
										  , currency_code
										  , conversion_type
										  , linkage_to
										  , base_rate
										  , base_date
                                          , description
										  , currency_name
										  , rate_limit
										  , release_num
										  , last_updated_by
										  , last_update_date
										  , created_by
										  , creation_date
										  , last_update_login
-- Added po_header_id as per ER# 12710151
										  , po_header_id
										  )
								  VALUES (
									       lc_module
                                         , lc_document_id
                                         , lc_currency_code
                                         , lc_conversion_type
                                         , ln_linkage_to
                                         , lc_base_rate
                                         , ld_base_date
										 , lc_description
				                         , lc_currency_name
										 , ln_rate_limit
										 , :NEW.release_num
										 , :NEW.last_updated_by
                                         , :NEW.last_update_date
                                         , :NEW.created_by
                                         , :NEW.creation_date
                                         , :NEW.last_update_login
-- Added po_header_id as per ER# 12710151
                                         , :NEW.po_header_id
									     );
      end if;
    -- Yuval
    elsif updating then
      if :old.release_num < 0 and :new.release_num > 0 then
      
        update clef062_po_index_esc_set t
           set t.release_num  = :new.release_num
         where t.po_header_id = :old.po_header_id
           and t.release_num  = - :old.po_release_id;
      end if;
    end if;
  end if;
end xxclef062_po_release;
/
