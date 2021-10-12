CREATE OR REPLACE TRIGGER xxoe_order_headers_all_6_trg
  before DELETE ON OE_ORDER_HEADERS_ALL
FOR EACH ROW

when( 1=1 )
declare
l_event_rec   xxobjt_custom_events%ROWTYPE;
begin
--------------------------------------------------------------------
--  name:            XXOE_ORDER_HEADERS_ALL_6_TRG
--  create by:       Lingaraj Sarangi
--  Revision:        1.0
--  creation date:   16-Apr-2018
--------------------------------------------------------------------
--  purpose :   Order Header Delete Event will be generated for Strataforce
--
--  in params:
--------------------------------------------------------------------
--  ver  date          name                  desc
--  1.0  16-Apr-2018   Lingaraj Sarangi      initial build CHG0042041
--------------------------------------------------------------------

    l_event_rec.event_name               := 'SO_HEADER_DELETE';  
    l_event_rec.source_name              := 'XXOE_ORDER_HEADERS_ALL_6_TRG';
    l_event_rec.event_table              := 'OE_ORDER_HEADERS_ALL';
    l_event_rec.event_key                := :OLD.HEADER_ID;    
    
    l_event_rec.attribute1               := :OLD.ORDER_TYPE_ID;
    l_event_rec.attribute2               := :OLD.order_number;
    l_event_rec.attribute3               := :OLD.quote_number;
    
    xxobjt_custom_events_pkg.insert_event(l_event_rec);

  
exception
  when others then
    null;
End xxoe_order_headers_all_6_trg;
/
