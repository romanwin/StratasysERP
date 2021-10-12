<<<<<<< Updated upstream
chg2.1 yuval aaaa--------------------------------------------------------------------
=======
chg2.1  yuval aaaa--------------------------------------------------------------------
>>>>>>> Stashed changes
--  name:               Datafix for CHG0041294  
--  create by:          Bellona Banerjee
--  Revision:           1.0
--  creation date:      29.03.2018
--------------------------------------------------------------------
--  purpose :           To add columns to table related to TPL interface.
--						Drop an existing index and create 2 new indexes.
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   19.01.2018   Bellona Banerjee CHG0041294 - Datafix related to 
--										TPL interface process modification.
--  1.0   19.01.2018   Bellona Banerjee CHG0041294 - Datafix related to 
--------------------------------------------------------------------------
ALTER TABLE XXOBJT.XXINV_TRX_PICK_IN
  ADD (delivery_name    VARCHAR2(30),
  move_order_no         VARCHAR2(30),
  move_order_line_no    NUMBER)
/
ALTER TABLE XXOBJT.XXINV_TRX_PACK_IN
  ADD (delivery_name    VARCHAR2(30),
  move_order_no         VARCHAR2(30),
  move_order_line_no    NUMBER)
/
ALTER TABLE XXOBJT.XXINV_TRX_SHIP_CONFIRM_IN
  ADD (delivery_name    VARCHAR2(30),
  move_order_no         VARCHAR2(30),
  move_order_line_no    NUMBER)
/
ALTER TABLE XXOBJT.XXINV_TRX_SHIP_OUT
  ADD (move_order_no    VARCHAR2(30),
  move_order_line_no    NUMBER,
  ship_set_number		VARCHAR2(30))
/
DROP INDEX XXOBJT.XXINV_TRX_SHIP_OUT_U1
/
CREATE INDEX XXOBJT.XXINV_TRX_SHIP_OUT_N1
  ON XXINV_TRX_SHIP_OUT (DELIVERY_DETAIL_ID, MOVE_ORDER_LINE_ID)
/
CREATE INDEX XXOBJT.XXINV_TRX_SHIP_OUT_N2
  ON XXINV_TRX_SHIP_OUT (TRANSACTION_TEMP_ID)  
/
