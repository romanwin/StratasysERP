CREATE OR REPLACE PACKAGE xxap_legacy_s3_intf_pkg

-- =============================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                   Creation Date    Original Ver    Created by
-- xxap_legacy_s3_intf_pkg         16-JUN-2016      1.0             Vindhya(TCS)
-- -----------------------------------------------------------------------------
-- Usage: This will be used as AP Invoice Conversion program. This is the 
-- Package Specification.
-- -----------------------------------------------------------------------------
-- Description: This is a conversion script. This program will be used to upload
--              AP invoice information
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
-- 
-- =============================================================================
 AS
   PROCEDURE main(x_errbuf OUT VARCHAR2,
                 x_retcode OUT VARCHAR2);
  -- ===========================================================================
--  Program name                Creation Date                Created by
--  MAIN                        16-JUN-2016                  Vindhya(TCS)
-- ---------------------------------------------------------------------------
-- Description  : This is the main procedure
--
-- Return value : None
--
-- =========================================================================== 

END xxap_legacy_s3_intf_pkg;
/
