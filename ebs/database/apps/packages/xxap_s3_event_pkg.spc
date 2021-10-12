CREATE OR REPLACE PACKAGE xxap_s3_event_pkg 

-- =============================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                 Creation Date    Original Ver    Created by
-- xxap_s3_event_pkg            30-JUL-2016      1.0             Vindhya(TCS)
-- ----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- Description: This program will be used as business event subcription package
--              in s3 side business event
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
-- 
-- =============================================================================
IS

-- ===========================================================================
  --  Program name           Creation Date               Created by
  --  event_process          30-JUL-2016                 Vindhya(TCS)
  -- ---------------------------------------------------------------------------
  -- Description  : This procedure is used to insert the triggered data
  --                into business events table
  -- Return value : None
  --
  -- ===========================================================================
  
  FUNCTION event_process(p_subscription_guid IN RAW,
                          p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;

END xxap_s3_event_pkg;
/
