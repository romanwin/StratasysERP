create or replace trigger xxoe_order_headers_all_5_trg
  before UPDATE ON OE_ORDER_HEADERS_ALL
  FOR EACH ROW

when (NEW.payment_term_id  <> OLD.payment_term_id ) 
declare

  l_booked_so    varchar2(10) := 'N';
  l_so_line_id   number;
  l_org_id       number;
  --l_so_header_id number;
  l_hold_id      number;
  l_result       boolean;
  l_req_id       number;
begin
--------------------------------------------------------------------
--  name:            XXOE_ORDER_HEADERS_ALL_5_TRG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   22/09/2014
--------------------------------------------------------------------
--  purpose :
--
--  in params:
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  22/09/2014  Dalit A. Raviv    initial build CHG0031347
--------------------------------------------------------------------
  if (:NEW.flow_status_code  = 'BOOKED' and :OLD.flow_status_code  = 'BOOKED') then   
    begin
      -- chack this So is in stage of BOOK and at list one line is at book stage
      select 'Y', oola.line_id
      into   l_booked_so, l_so_line_id
      from   oe_order_lines_all    oola
      where  oola.booked_flag      = 'Y'
      and    oola.header_id        = :NEW.header_id -- connect to the header
      and    rownum                = 1;
    exception
      when others then
        l_booked_so := 'N';       
    end;  
   
    -- if attachment added to a booked so ('SSYS Non Std Terms and Conditions') then apply hold to the SO
    if l_booked_so = 'Y' then
      begin
        select h.hold_id
        into   l_hold_id
        from   oe_hold_definitions h
        where  h.name = 'SSYS Payment Terms Approval';
      exception
        when others then
          l_hold_id := 1;          
      end;
        
      l_result := FND_REQUEST.SET_MODE(TRUE);
      if l_result then
        l_req_id := fnd_request.submit_request( application   => 'XXOBJT', 
                                                program       => 'XXOM_APPLY_HOLD_BOOK', -- XXOM_AUTO_HOLD_PKG.apply_hold_book_conc
                                                description   => NULL, 
                                                start_time    => NULL,
                                                sub_request   => FALSE,
                                                argument1     => l_so_line_id, 
                                                argument2     => l_org_id,  
                                                argument3     => :NEW.last_updated_by,
                                                argument4     => :NEW.header_id,
                                                argument5     => l_hold_id ); 
              
      end if;-- l_result  
    end if;-- l_booked_so = 'Y' 
  end if;-- status BOOKED  
exception
  when others then
    null;
end;
/
