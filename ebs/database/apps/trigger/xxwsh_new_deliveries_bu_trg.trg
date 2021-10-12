CREATE OR REPLACE TRIGGER APPS.XXWSH_NEW_DELIVERIES_BU_TRG
  before update of ATTRIBUTE3 on WSH_NEW_DELIVERIES  
  for each row

DECLARE
  -- local variables here
  is_delv_political NUMBER := 0;
  general_exception EXCEPTION;
BEGIN
--------------------------------------------------------------------
--  name:            XXWSH_NEW_DELIVERIES_BU_TRG
--  create by:       XXX
--  Revision:        1.0
--  creation date:   XX/XX/20XX 
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  XX/XX/20XX  XXX               initial build
--  1.1  13/10/2010  Dalit A. Raviv    CHG0035915 - Packing interface to support delivery packing
--                                     add profile to control the trigger
--------------------------------------------------------------------
  -- CHG0035915  1.1 13/10/2010 Dalit A. Raviv
  if fnd_profile.VALUE('XXINV_POLITICAL_PACK_CHECK') = 'Y' then
    -- check if this is a political delivery
    is_delv_political := xxwsh_political.is_delivery_political(:NEW.delivery_id);

    IF is_delv_political = 1 AND :NEW.attribute3 = 'Y' AND
       nvl(:NEW.attribute11, 'N') <> 'Y' THEN
      RAISE general_exception;
    END IF;
  end if; 
EXCEPTION
  WHEN general_exception THEN
    fnd_message.set_name('XXOBJT', 'XXWSH_POLITICAL_DELIVERY');
    app_exception.raise_exception;
  WHEN OTHERS THEN
    NULL;
END xxwsh_new_deliveries_bu_trg;
/
