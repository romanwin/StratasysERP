CREATE OR REPLACE PACKAGE xxap_legacy_s3_int_pkg 

 -- =============================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                         Creation Date    Original Ver    Created by
-- xxap_legacy_s3_int_pkg               4-AUG-2016         1.0             Vindhya(TCS)
-- -----------------------------------------------------------------------------
-- Usage: This will be used as Auto AP Invoice Creation program based on AR Invoice.
-- This is the Package Specification.
-- -----------------------------------------------------------------------------
-- Description: This program will be used to create
--              AP invoice for AR Invoice in legacy.
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
-- 
-- =============================================================================

IS
  

 -- ===========================================================================
    --  Program name                Creation Date                Created by
    --  pull_ar_invoices            4-AUG-2016                    Vindhya(TCS)
    -- ---------------------------------------------------------------------------
    -- Description  : This is the Data pull procedure
    --
    -- Return value : None
    --
    -- ===========================================================================
    
  PROCEDURE pull_ar_invoices(x_errbuf     OUT VARCHAR2,
                             x_retcode    OUT VARCHAR2,
                             p_batch_size IN NUMBER);                  

END xxap_legacy_s3_int_pkg;
/
