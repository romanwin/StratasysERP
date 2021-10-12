CREATE OR REPLACE TRIGGER xxcs_estimate_details_air_trg

---------------------------------------------------------------------------
-- Trigger   :        XXCS_ESTIMATE_DETAILS_AIR_TRG
-- Created by:        Ella
-- creation date:     24/02/2010
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:           Call concurrent program that update charges pricing details
---------------------------------------------------------------------------
--  ver    date        name            desc
--  1.0   24/02/2010   Ella            Initial Build
---------------------------------------------------------------------------
  AFTER INSERT ON cs_estimate_details 
  FOR EACH ROW  
when (NEW.contract_id IS NULL AND NEW.contract_line_id IS NULL)
DECLARE

   l_request_id    NUMBER;
   l_new_header_id NUMBER;

BEGIN

   IF nvl(fnd_profile.VALUE('XXCS_ENABLE_CHARGES_PRICING_CHG'), 'N') = 'Y' THEN
   
      BEGIN
      
         SELECT attribute11
           INTO l_new_header_id
           FROM cs_incidents_all_b ci, csi_item_instances cii
          WHERE ci.customer_product_id = cii.instance_id AND
                ci.incident_id = :NEW.incident_id;
      
      EXCEPTION
         WHEN OTHERS THEN
            l_new_header_id := -1;
      END;
   
      IF nvl(:NEW.price_list_header_id, 0) != nvl(l_new_header_id, -1) THEN
      
         IF fnd_request.set_mode(db_trigger => TRUE) THEN
         
            l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                       program     => 'XXCSUCPL',
                                                       description => NULL,
                                                       start_time  => NULL,
                                                       sub_request => FALSE,
                                                       argument1   => :NEW.incident_id); -- i v p_body
         
         END IF;
      
      END IF;
   
   END IF; -- Profile 

EXCEPTION
   WHEN OTHERS THEN
      NULL;
   
END xxcs_estimate_details_air_trg;
/

