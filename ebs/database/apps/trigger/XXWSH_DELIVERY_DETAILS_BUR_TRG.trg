CREATE OR REPLACE TRIGGER XXWSH_DELIVERY_DETAILS_BUR_TRG  
--------------------------------------------------------------------
--  customization code: CHG0041696
--  name:               XXWSH_DELIVERY_DETAILS_BUR_TRG  
--  create by:          Piyali Bhowmick
--  Revision:           1.0
--  creation date:      09.11.2017
--------------------------------------------------------------------
--  purpose :           Back order notification 
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   09.11.2017   Piyali Bhowmick CHG0041696 - initial version
--  2.0   17.01.2018   Bellona Banerjee INC011984 - Multiple Back order 
--                                        notifications send to user.
--------------------------------------------------------------------------
  before  update  of released_status
  on WSH.WSH_DELIVERY_DETAILS
  for each row
  when(NEW.released_status = 'B' and OLD.released_status = 'S')
DECLARE
  l_header_id NUMBER;
  l_xxssys_event_rec xxssys_events%ROWTYPE;
  
  l_org_id    NUMBER;
  l_flag      NUMBER := 0;
    
begin


      l_header_id := :NEW.SOURCE_HEADER_ID;
      
       l_xxssys_event_rec.entity_name := 'DELIVERY';
       l_xxssys_event_rec.target_name := 'BACKORDER_NTY';
      l_xxssys_event_rec.event_name := 'XXWSH_DELIVERY_DETAILS_BUR_TRG';
      
      BEGIN
            SELECT org_id INTO l_org_id
            FROM apps.oe_order_headers_all
            WHERE header_id= l_header_id;
      EXCEPTION
        WHEN OTHERS THEN
            --fnd_file.put_line(fnd_file.log,'Error while fetching org_id for order header_id: '||l_header_id);
            return;
      END;
      
      -- checking whether order is already picked for sending notification
      BEGIN
            select  count(1) INTO l_flag
            FROM   xxssys_events
            WHERE  status in ('NEW','IN_PROCESS','SUCCESS')
            AND    target_name = 'BACKORDER_NTY'
            AND    entity_name = 'DELIVERY'
            and    entity_id   = l_header_id;
      EXCEPTION
      WHEN OTHERS THEN
           return;
      END;
      
    -- checking whether profile option value is set at org level 
    
      IF (fnd_profile.value_specific( name   =>'XXOM_BACKORDER_NTY'
                                    ,org_id => l_org_id) is not null)
         and (l_flag = 0)                           
      THEN 
    -- fetch header id  for back order info 
 
      l_xxssys_event_rec.entity_id  := l_header_id;
         
      -- insert into stage table xxssys_events 
      xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
      ELSE
        --fnd_file.put_line(fnd_file.log,'Value not set for profile XXOM_BACKORDER_NTY at org level, for order header_id '||l_header_id);
        return;
      END IF;
end;
/
