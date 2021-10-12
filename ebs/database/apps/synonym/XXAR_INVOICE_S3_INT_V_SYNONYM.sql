-- =============================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                 Creation Date    Original Ver    Created by
-- XXAR_INVOICE_S3_INT_V          8-Jul-2016      1.0             Vindhya(TCS)
-- -----------------------------------------------------------------------------
-- Usage: Synonym creation script
--
-- -----------------------------------------------------------------------------
-- Description: This is a synonym creation script. This table will be used to 
--              hold AP Invoice information along with business event table new record.
-- Parameter    : None
-- Return value : None
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
-- 
-- =============================================================================

CREATE OR REPLACE SYNONYM XXAR_INVOICE_S3_INT_V FOR apps.XXAR_INVOICE_S3_INT_V@source_s3
/