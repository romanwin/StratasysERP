CREATE OR REPLACE PACKAGE XXAR_INV_TRIGGER_PKG IS

 -- =============================================================================
  -- Copyright (C) 2013  TCS, India
  -- All rights Reserved
  -- Program Name: XXAR_INV_TRIGGER_PKG
  -- Parameters  : None
  -- Description : Package contains the procedures required for SSYS to raise
  --                Business Event
  --
  --
  -- Notes       : None
  -- History     :
  -- Creation Date : 02-SEP-2016
  -- Created/Updated By  : TCS
  -- Version: 1.0
 -- ============================================================================

  -- ------------------------------------------------------------------------
  --  purpose :  Legacy business event raise package for AR Invoice Creation
  -- -----------------------------------------------------------------------
  --  ver  date            name             desc
  --  1.0  02-SEP-2016     TCS         Initial Build
  -- ---------------------------------------------------------------------
  --  name:              trigger_prc
  --  create by:          TCS
  --  Revision:          1.0
  --  creation date:    02-SEP-2016
  --------------------------------------------------------------------

  PROCEDURE trigger_prc(p_customer_trx_id IN NUMBER);

END XXAR_INV_TRIGGER_PKG;
/