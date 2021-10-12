CREATE OR REPLACE TRIGGER XXAR_CUSTOMER_TRX_ALL_TRG
  AFTER INSERT ON "AR"."RA_CUSTOMER_TRX_ALL#"
  FOR EACH ROW
DECLARE

  l_error_msg VARCHAR2(240) := NULL;
BEGIN

   xxar_inv_trigger_pkg.trigger_prc(p_customer_trx_id => :NEW.customer_trx_id);

EXCEPTION
  WHEN OTHERS THEN
     l_error_msg := SQLERRM;
END;
/