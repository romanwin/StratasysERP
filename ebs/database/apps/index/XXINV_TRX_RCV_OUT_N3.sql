----------------------------------------------------------------------
-- Ver   When          Who         Descr
-- ----  ------------  ----------  -----------------------------------
-- 1.0   19/05/2021    Roman W.    INC0232164 
----------------------------------------------------------------------
DROP INDEX "XXOBJT"."XXINV_TRX_RCV_OUT_N3";

CREATE INDEX "XXOBJT"."XXINV_TRX_RCV_OUT_N3" 
  ON "XXOBJT"."XXINV_TRX_RCV_OUT" 
  ( SHIPMENT_LINE_ID || '|' || 
    LOT_NUMBER       || '|' || 
    SERIAL_NUMBER    || '|' ||
    ORDER_LINE_ID    || '|' ||
    PO_LINE_LOCATION_ID) ;
