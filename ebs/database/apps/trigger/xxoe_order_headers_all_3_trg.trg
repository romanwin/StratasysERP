CREATE OR REPLACE TRIGGER XXOE_ORDER_HEADERS_ALL_3_TRG
AFTER UPDATE of attribute1 , attribute2,ATTRIBUTE11  ON OE_ORDER_HEADERS_ALL
  FOR EACH ROW


DECLARE
  ---------------------------------------------------------------------------
  -- $Header: XXOE_ORDER_HEADERS_ALL_3_TRG 
  ---------------------------------------------------------------------------
  -- Trigger: xxoe_order_headers_all_3_trg
  -- Created: yuval tal

  --------------------------------------------------------------------------
  -- Perpose: cust 495 cr 409 Email Notification upon update Expected Revenue Rec. Month
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --    1.0  13.05.12   yuval tal       Initial Build - cust 495 cr 409 
  --                                    Email Notification upon update Expected Revenue Rec. Month (attribute1 change)
  --    1.1  28.6.12    yuval.tal       add customer and OU details / change lead mail user_name logic 
  --                                    take user_name from xx_send_mail valueset cr 438 
  --    1.2  05.3.13    yuval.tal       cr-688 :Email Notification when updating value in the SO header DFF field SYS Booking Date ATT2
  --    1.3  29.07.13   yuval tal       CUST495 CR-893 Notifying user by mail, when SO DFF header- "Indirect Use" is Updated.
  --    1.4  14.03.14   Mike Mazanet    CHG0031323 - Changed trigger for changes to attibute1, attribute2, and attribute11.  It will now insert a row
  --                                    into xxobjt_custom_events table where we can report off of it. 
  ---------------------------------------------------------------------------

  l_to                        VARCHAR2(500);
  l_cc                        VARCHAR2(500);
  l_body                      VARCHAR2(4000);
  l_org_name                  VARCHAR2(100);
  l_xxobjt_custom_events_rec  xxobjt_custom_events%ROWTYPE;

  l_tmp         NUMBER;
  l_err_code    NUMBER;
  l_err_message VARCHAR2(200);
  CURSOR c_check IS
    SELECT 1
      FROM oe_transaction_types_tl t
     WHERE LANGUAGE = 'US'
       AND (t.name LIKE 'Stand%Order%' OR t.name LIKE 'Trade%Order%')
       AND t.transaction_type_id =
           nvl(:new.order_type_id, :old.order_type_id);

BEGIN
  -- check order type = standard  order OR trade order 
  OPEN c_check;
  FETCH c_check
    INTO l_tmp;
  CLOSE c_check;
  IF nvl(l_tmp, 0) = 1 THEN
  
      -------  ATTRIBUTE1 CHANGED  ------
      IF (nvl(:new.attribute1, '-1') != nvl(:old.attribute1, '-1') 
         AND :old.attribute1 IS NOT NULL) 
      THEN
         l_xxobjt_custom_events_rec.event_name        := 'OE_REVENUE_CHG';
         l_xxobjt_custom_events_rec.event_description := 'Called from xxoe_order_headers_all_3_trg when attribute1 changes';
         l_xxobjt_custom_events_rec.source_name       := 'XXOE_ORDER_HEADERS_ALL_3_TRG';
         l_xxobjt_custom_events_rec.event_table       := 'OE_ORDER_HEADERS_ALL';
         l_xxobjt_custom_events_rec.event_key         := :new.header_id;
         l_xxobjt_custom_events_rec.attribute1        := :new.attribute1;
         l_xxobjt_custom_events_rec.attribute2        := :old.attribute1;
         
         xxobjt_custom_events_pkg.insert_event(l_xxobjt_custom_events_rec);
         
    END IF;
  
    -------  ATTRIBUTE2 CHANGED  ------
    IF (nvl(:new.attribute2, '-1') != nvl(:old.attribute2, '-1') AND
       :old.attribute2 IS NOT NULL) THEN

         l_xxobjt_custom_events_rec.event_name        := 'OE_SYS_BOOK_DATE_CHG';
         l_xxobjt_custom_events_rec.event_description := 'Called from xxoe_order_headers_all_3_trg when attribute2 changes';
         l_xxobjt_custom_events_rec.source_name       := 'XXOE_ORDER_HEADERS_ALL_3_TRG';
         l_xxobjt_custom_events_rec.event_table       := 'OE_ORDER_HEADERS_ALL';
         l_xxobjt_custom_events_rec.event_key         := :new.header_id;
         l_xxobjt_custom_events_rec.attribute1        := :new.attribute2;
         l_xxobjt_custom_events_rec.attribute2        := :old.attribute2;
         
         xxobjt_custom_events_pkg.insert_event(l_xxobjt_custom_events_rec);

    END IF;
  
    -- CR 893 Notifying user by mail, when SO DFF header- "Indirect Use" is Updated.
    -------  ATTRIBUTE11 CHANGED  ------
    IF (nvl(:new.attribute11, '-1') != nvl(:old.attribute11, '-1') AND
       :old.attribute11 IS NOT NULL) THEN

         l_xxobjt_custom_events_rec.event_name        := 'OE_INDIRECT_CHG';
         l_xxobjt_custom_events_rec.event_description := 'Called from xxoe_order_headers_all_3_trg when attribute11 changes';
         l_xxobjt_custom_events_rec.source_name       := 'XXOE_ORDER_HEADERS_ALL_3_TRG';
         l_xxobjt_custom_events_rec.event_table       := 'OE_ORDER_HEADERS_ALL';
         l_xxobjt_custom_events_rec.event_key         := :new.header_id;
         l_xxobjt_custom_events_rec.attribute1        := :new.attribute11;
         l_xxobjt_custom_events_rec.attribute2        := :old.attribute11;
         
         xxobjt_custom_events_pkg.insert_event(l_xxobjt_custom_events_rec);
    END IF;
    ------ END CR 893  
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
