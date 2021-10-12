CREATE OR REPLACE TRIGGER xxclef062_inv_dist_bir2
--------------------------------------------------------------------
--  name:            XXCLEF062_INV_DIST_BIR2
--  create by:       Yuval Tal
--  Revision:        1.0
--  creation date:   16/07/2013
--------------------------------------------------------------------
--  purpose :        correct oracle trigger CLEF062_INV_DISTRIBUTIONS_BIR2
--                   to handle document_id and reales num
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  16/07/2013  Yuval Tal         initial build
--------------------------------------------------------------------
before insert on ap_invoice_distributions_all
referencing NEW as NEW OLD as OLD
for each row
 
when (NEW.reversal_flag = 'Y')
declare
  v_att15         varchar2(100);
  v_invoice_type  varchar2(100);
  v_po_header_id  number;
  v_attribute11   varchar2(100);
  v_attribute15   varchar2(100);
  v_esc_price     number;
begin

  select  invoice_type_lookup_code,
          po_header_id,
          attribute11,
          attribute15
  into    v_invoice_type,
          v_po_header_id,
          v_attribute11,
          v_attribute15
  from    ap_invoices_all
  where   invoice_id = :new.invoice_id;

  if  v_invoice_type in ('STANDARD','DEBIT','CREDIT') and  :new.po_distribution_id is not null then
    begin
      select  currency_code
      into    v_att15
      from    clef062_po_index_esc_set
      where   (document_id,release_num) in (select ph.segment1, nvl(por.release_num, 0)
                                            from   po_distributions_all   pd,
                                                   po_headers_all         ph,
                                                   po_releases_all        por
                                            where  pd.po_distribution_id  = :new.po_distribution_id                             
                                            and    ph.po_header_id        = pd.po_header_id
                                            and    por.po_header_id(+)    = pd.po_header_id
                                            and    por.po_release_id(+)   = pd.po_release_id);
      
    exception
      when no_data_found then
        null;
    end;
  end if;

  begin
    select  escalated_price
    into    v_esc_price
    from    clef062_ap_inv_distributions
    where   invoice_distribution_id=:new.parent_reversal_id;
  exception
    when no_data_found then
      null;
  end;

  if v_att15 is not null then

    insert into clef062_ap_inv_distributions(invoice_id,
                                             invoice_distribution_id,
                                             po_distribution_id,
                                             rcv_transaction_id,
                                             quantity_invoiced,
                                             unit_price,
                                             escalated_price,
                                             reversal_flag,
                                             parent_reversal_id,
                                             last_updated_by,
                                             last_update_date,
                                             created_by,
                                             creation_date,
                                             last_update_login)
                                      values (:NEW.invoice_id,
                                              :NEW.invoice_distribution_id,
                                              :NEW.po_distribution_id,
                                              :NEW.rcv_transaction_id,
                                              :NEW.quantity_invoiced,
                                              :NEW.unit_price,
                                              v_esc_price,
                                              :NEW.reversal_flag,
                                              :NEW.parent_reversal_id,
                                              :NEW.last_updated_by,
                                              :NEW.last_update_date,
                                              :NEW.created_by,
                                              :NEW.creation_date,
                                              :NEW.last_update_login);
  end if;
end xxclef062_inv_dist_bir2;
