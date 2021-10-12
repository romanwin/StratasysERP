create or replace trigger XXQP_LIST_HEADERS_AUR_TRG1
  after update on qp_list_headers_all_b  
  for each row
  
when (NEW.attribute6 = 'Y' )
declare
  l_oa2sf_rec       xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code        varchar2(10)   := 0;
  l_err_desc        varchar2(2500) := null;
  l_source_id_exist varchar2(10)   := null;
begin
--------------------------------------------------------------------
--  name:            XXQP_LIST_HEADERS_AUR_TRG1
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   10/10/2010 1:30:11 PM
--------------------------------------------------------------------
--  purpose :        Trigger that will fire after update of price list header
--                   when attribute6 (Transfer to SF) = 'Y'
--                   if att5 (sf_id ) is not null and active_flag changed
--                   will check: 
--                   1)if there is a row at interface tbl XXOBJT_OA2SF_INTERFACE
--                     if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/09/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------  
  if ((:NEW.ATTRIBUTE5  is not null and :NEW.ACTIVE_FLAG = 'N'
       and :NEW.ACTIVE_FLAG <> :OLD.ACTIVE_FLAG)  or
       (:NEW.ATTRIBUTE5  is null and :NEW.ACTIVE_FLAG = 'Y' and
        :NEW.attribute6 <> nvl(:OLD.attribute6,'DAR')) ) then
    l_source_id_exist := XXOBJT_OA2SF_INTERFACE_PKG.is_source_id_exist (p_source_id    => :NEW.list_header_id,
                                                                        p_source_name  => 'PRICE_BOOK');                                                                                                                                     
    if l_source_id_exist = 'N' then
      l_oa2sf_rec.status       := 'NEW';
      l_oa2sf_rec.source_id    := :NEW.list_header_id;
      l_oa2sf_rec.source_name  := 'PRICE_BOOK';
      l_oa2sf_rec.sf_id        := :NEW.attribute5;
      XXOBJT_OA2SF_INTERFACE_PKG.insert_into_interface (p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                        p_err_code  => l_err_code,  -- o v
                                                        p_err_msg   => l_err_desc); -- o v
    end if; -- l_source_id_exist  = N
  end if;
  

end XXQP_LIST_HEADERS_AUR_TRG1;
/

