CREATE OR REPLACE TRIGGER xxinv_trx_ship_conf_in_bi_trg
  BEFORE INSERT ON xxinv_trx_ship_confirm_in
  FOR EACH ROW
--------------------------------------------------------------------
  --  xxinv_trx_ship_conf_in_bi_trg

  --------------------------------------------------------------------
  --  purpose :           Trigger on  TPL pack input table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   06.11.2017   Piyali Bhowmick CHG0041294 - addition of move_order details
  --------------------------------------------------------------------------
BEGIN
  :new.last_update_date := SYSDATE;
  :new.last_updated_by  := fnd_global.user_id;
  IF :new.trx_id IS NULL THEN
    :new.trx_id := xxinv_trx_in_s.nextval;
  END IF;
  BEGIN
    SELECT tso.move_order_no,
           tso.move_order_line_no
    INTO   :new.move_order_no,
           :new.move_order_line_no
    FROM   xxinv_trx_ship_out tso
    WHERE  :new.line_id = tso.line_id;
  
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      NULL;
  END;
END;
/