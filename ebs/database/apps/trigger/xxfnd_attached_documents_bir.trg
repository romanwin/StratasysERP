create or replace trigger XXFND_ATTACHED_DOCUMENTS_BIR
before insert on FND_ATTACHED_DOCUMENTS
for each row

when (NEW.entity_name in ('OE_ORDER_HEADERS', 'OE_ORDER_LINES') )
declare
  l_exists       varchar2(10) := 'N';
  l_booked_so    varchar2(10) := 'N';
  l_so_line_id   number;
  l_org_id       number;
  l_so_header_id number;
  l_hold_id      number;
  --l_log_msg      varchar2(1000);
  --l_log_code     varchar2(100);
  l_result       boolean;
  l_req_id       number;
begin
  --------------------------------------------------------------------
  --  name:            XXFND_ATTACHED_DOCUMENTS_BIR
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Orders Holds
  --                   1) check the attachment is 'SSYS Non Std Terms and Conditions'
  --                   2) check if order is in book status
  --                   3) if yes and yes then apply hold 'SSYS Terms & Conditions Approval'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  -- check the attachment is 'SSYS Non Std Terms and Conditions'
  begin
    select 'Y'
    into   l_exists
    from   fnd_document_categories_tl fdctl
    where  fdctl.category_id          = :NEW.category_id
    and    fdctl.user_name            = 'SSYS Non Std Terms and Conditions'
    and    language                   = 'US';

  exception
    when others then
      l_exists := 'N';
  end;

  if l_exists = 'Y' then
    -- check if order is in book status
    begin
      if :NEW.entity_name = 'OE_ORDER_HEADERS' then
        select 'Y', oola.line_id, ooha.org_id, ooha.header_id
        into   l_booked_so, l_so_line_id, l_org_id, l_so_header_id
        from   oe_order_headers_all  ooha,
               oe_order_lines_all    oola
        where  ooha.header_id        = oola.header_id
        and    ooha.flow_status_code = 'BOOKED'
        and    oola.booked_flag      = 'Y'
        and    ooha.header_id        = :NEW.pk1_value -- connect to the header
        and    rownum                = 1;

      elsif :NEW.entity_name = 'OE_ORDER_LINES' then
        select 'Y', oola.line_id, ooha.org_id, ooha.header_id
        into   l_booked_so, l_so_line_id, l_org_id, l_so_header_id
        from   oe_order_headers_all  ooha,
               oe_order_lines_all    oola
        where  ooha.header_id        = oola.header_id
        and    ooha.flow_status_code = 'BOOKED'
        and    oola.booked_flag      = 'Y'
        and    oola.line_id          = :NEW.pk1_value -- connect to the line
        and    rownum                = 1;
      end if;

    exception
      when others then     
        l_booked_so := 'N';
    end;
  end if;
  
  -- if attachment added to a booked so ('SSYS Non Std Terms and Conditions') then apply hold to the SO
  if l_booked_so = 'Y' then
    begin
      select h.hold_id
      into   l_hold_id
      from   oe_hold_definitions h
      where  h.name = 'SSYS Terms & Conditions Approval';
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
                                              argument3     => :NEW.last_updated_by ,
                                              argument4     => l_so_header_id,
                                              argument5     => l_hold_id ); 
          
    end if;  
  end if;

exception
  when others then
    null;
end;
/
