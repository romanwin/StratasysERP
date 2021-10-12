create or replace trigger XXINV_ITEM_BUYER_BUR_TRG
---------------------------------------------------------------------------
-- Trigger   :        XXINV_ITEM_BUYER_BUR_TRG
-- Created by:        Dalit A. Raviv
-- creation date:     16/12/2009
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:           Send mail to buyer when default buyer changed for the item
--                    will change alert - XXINV_NEW_BUYER_ASSIGNED
---------------------------------------------------------------------------
--	ver		date        name		        desc
--  1.0   16/12/2009  Dalit A. Raviv  Initial Build
--  1.1   07.05.14    yuval tal         CHG0031795 - send assign buyer alert for all IL orgs
---------------------------------------------------------------------------

  before update on MTL_SYSTEM_ITEMS_B
  for each row

when (NEW.buyer_id is not null and (NEW.buyer_id <> nvl(OLD.buyer_id,'-1')) /*and (NEW.organization_id = 91 )*/ )
DECLARE

  l_to_person         VARCHAR2(100) := NULL;
  l_sender_name       VARCHAR2(240) := 'OracleApps_NoReply@objet.com';
  l_buyer_name        VARCHAR2(240) := NULL;
  l_html_str          VARCHAR2(500) := NULL;
  l_req_id            NUMBER := NULL;
  l_result            BOOLEAN;
  l_organization_name VARCHAR2(500) := NULL;

BEGIN

  IF nvl(fnd_profile.value('XXINV_NEW_BUYER_FOR_ITEM_SEND_MAIL'), 'N') = 'Y' THEN
    BEGIN
      SELECT pba.email_address, pba.full_name
        INTO l_to_person, l_buyer_name
        FROM po_buyers_all_v pba
       WHERE pba.employee_id = :new.buyer_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_to_person := NULL;
    END;

    SELECT t.organization_name --, t.operating_unit
      INTO l_organization_name --, l_operating_unit
      FROM xxobjt_org_organization_def_v t
     WHERE t.organization_id = :new.organization_id
       AND operating_unit = 81;

    IF l_to_person IS NOT NULL THEN
      l_html_str := '<p>Hello:</p>' ||

                    '<p>Item: ' || :new.segment1 || '<p>Organization: ' ||
                    l_organization_name || '<p>Description: ' ||
                    substr(:new.description, 1, 80) ||
                    '<p>Has been assigned to you as its Buyer </p>' ||
                   --'<p>Thanks </p>' ;
                    '<p>Good day,' || --'<p> <br> </p>' ||
                    '<p>Oracle sys';

      l_result := fnd_request.set_mode(TRUE);
      IF l_result THEN
        l_req_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXOBJT_SEND_MAIL',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => l_sender_name, -- i v p_sender_name
                                               argument2   => l_to_person, -- i v p_recipient
                                               argument3   => 'Item assigned to you as its buyer', -- i v p_subject
                                               argument4   => l_html_str); -- i v p_body
      END IF;

    ELSE

      NULL;
    END IF;

  END IF;
EXCEPTION

  WHEN no_data_found THEN
    NULL;
  WHEN too_many_rows THEN
    NULL;
END xxinv_item_buyer_bur_trg;
/
