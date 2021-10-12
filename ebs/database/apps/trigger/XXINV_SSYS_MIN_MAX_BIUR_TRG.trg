CREATE OR REPLACE TRIGGER XXINV_SSYS_MIN_MAX_BIUR_TRG
   ---------------------------------------------------------------------------
   -- $Header: XXINV_SSYS_MIN_MAX_BIUR_TRG  120.0 2012/10/03  $
   ---------------------------------------------------------------------------
   -- Trigger: XXINV_SSYS_MIN_MAX_BIUR_TRG
   -- Created: 03/10/2012
   -- Author  : Vitaly Kuzmenko
   --------------------------------------------------------------------------
   -- Purpose: CUST540 - FDM Items Creation Program
   --------------------------------------------------------------------------
   -- Version  Date      Performer           Comments
   ----------  --------  --------------  -------------------------------------
   --  1.0  03/10/2012  Vitaly Kuzmenko     Initial Build
   ---------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON XXOBJT.XXINV_SSYS_MIN_MAX
  FOR EACH ROW

DECLARE
  
BEGIN

  IF INSERTING THEN
     select XXOBJT.XXINV_SSYS_MIN_MAX_SEQ.nextval
     into :new.line_id
     from dual;
     :new.creation_date:=sysdate;
     :new.created_by   :=fnd_global.user_id;
  END IF;
  :new.last_update_date:=sysdate;
  :new.last_updated_by :=fnd_global.user_id;

EXCEPTION
  WHEN others THEN
    NULL;
END;
/
