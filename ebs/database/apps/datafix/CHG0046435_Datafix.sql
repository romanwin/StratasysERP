--------------------------------------------------------------------
--  customization code: Datafix for CHG0046435
--  create by:          Bellona Banerjee
--  Revision:           1.0
--  creation date:      06.09.2019
--------------------------------------------------------------------
--  purpose :           To add below 3 columns in XXINV_TRX_PACK_IN
--                      and XXINV_TRX_PICK_IN tables-
--                     (1) COC_STATUS (2)COC_REQUEST_ID (3)COC_MESSAGE
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   06/09/2019   Bellona(TCS)    CHG0046435 - TPL Handle Pack - COC document by Email
--------------------------------------------------------------------------
ALTER TABLE XXOBJT.XXINV_TRX_PACK_IN
  ADD (COC_STATUS         VARCHAR2(1),
      COC_REQUEST_ID          NUMBER,
      COC_MESSAGE        VARCHAR2(500))
/

ALTER TABLE XXOBJT.XXINV_TRX_PICK_IN
  ADD (COC_STATUS         VARCHAR2(1),
      COC_REQUEST_ID          NUMBER,
      COC_MESSAGE        VARCHAR2(500))
/