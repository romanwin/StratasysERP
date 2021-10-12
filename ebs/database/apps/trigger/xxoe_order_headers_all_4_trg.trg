create or replace trigger xxoe_order_headers_all_4_trg
  before insert or UPDATE ON OE_ORDER_HEADERS_ALL
  FOR EACH ROW

  
when (new.shipping_instructions is null )
declare

--------------------------------------------------------------------
  --  name:            XXOE_ORDER_HEADERS_ALL_4_TRG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2014
  --------------------------------------------------------------------
  --  purpose :
  --
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2014  Dalit A. Raviv    initial build CHG0031347
  --------------------------------------------------------------------

begin
  if nvl(fnd_profile.VALUE('XXOE_ENABLE_SHIPPING_INSTRUCTION'), 'N') = 'Y' THEN
    :NEW.SHIPPING_INSTRUCTIONS := xxoe_utils_pkg.get_shipping_instructions(:new.SHIP_TO_ORG_ID);

  end if;

exception
  when others then
    null;
end;
/
