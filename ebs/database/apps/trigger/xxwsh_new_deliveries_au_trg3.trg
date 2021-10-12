CREATE OR REPLACE TRIGGER xxwsh_new_deliveries_au_trg3
  AFTER UPDATE OF attribute1, waybill ON wsh_new_deliveries
  FOR EACH ROW

DECLARE

  l_xxssys_event_rec xxssys_events%ROWTYPE;

  CURSOR c_lines IS
    SELECT ola.line_id,
           (nvl(oh.order_number, oh.quote_number) || '-' || ola.line_number) entity_code
    
    FROM   oe_order_lines_all   ola,
           oe_order_headers_all oh,
           --  wsh_new_deliveries       wnd,
           wsh_delivery_assignments wda,
           wsh_delivery_details     wdd
    WHERE  ola.header_id = oh.header_id
    AND    :new.delivery_id = wda.delivery_id
    AND    wda.delivery_detail_id = wdd.delivery_detail_id
    AND    wdd.source_line_id = ola.line_id
    AND    xxssys_strataforce_events_pkg.is_valid_order_type(oh.order_type_id) = 'Y';
  -- AND    :new.status_code = 'CL';
BEGIN
  --------------------------------------------------------------------
  --  name:            XXWSH_NEW_DELIVERIES_BU_TRG3
  --  create by:       YUVAL 
  --  Revision:        1.0
  --  creation date:   3.8.21
  --------------------------------------------------------------------
  --  purpose : create order lines  event for sfdc 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  3.8.21     yuval tal         CHG0047450                initial build

  --------------------------------------------------------------------
  IF nvl(:old.attribute1, '-1') != nvl(:new.attribute1, '-1') OR
     nvl(:old.waybill, '-1') != nvl(:new.waybill, '-1') THEN
  
    FOR i IN c_lines
    LOOP
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := 'STRATAFORCE';
      l_xxssys_event_rec.entity_name := 'SO_LINE';
      l_xxssys_event_rec.entity_id   := i.line_id;
      l_xxssys_event_rec.event_name  := 'xxwsh_new_deliveries_au_trg3';
      l_xxssys_event_rec.entity_code := i.entity_code;
      --Insert SO LINE Event
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    END LOOP;
  END IF;
  --exception
END;
/
