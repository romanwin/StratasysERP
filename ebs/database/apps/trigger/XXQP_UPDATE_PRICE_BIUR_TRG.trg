CREATE OR REPLACE TRIGGER XXQP_UPDATE_PRICE_BIUR_TRG
   ---------------------------------------------------------------------------
   -- $Header: XXQP_UPDATE_PRICE_BIUR_TRG  120.0 2012/10/03  $
   ---------------------------------------------------------------------------
   -- Trigger: XXQP_UPDATE_PRICE_BIUR_TRG
   -- Created: 17/10/2012
   -- Author  : Vitaly Kuzmenko
   --------------------------------------------------------------------------
   -- Purpose: CUST527 - Update Price in Price List and Blanket PO Lines
   --------------------------------------------------------------------------
   -- Version  Date      Performer           Comments
   ----------  --------  --------------  -------------------------------------
   --  1.0  17/10/2012  Vitaly Kuzmenko     Initial Build
   ---------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON XXQP_UPDATE_PRICE
  FOR EACH ROW

DECLARE

BEGIN

  IF inserting THEN
    SELECT xxqp_update_price_seq.nextval INTO :new.line_id FROM dual;
    :new.creation_date := SYSDATE;
    :new.created_by    := fnd_global.user_id;
  END IF;
  :new.last_update_date := SYSDATE;
  :new.last_updated_by  := fnd_global.user_id;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
