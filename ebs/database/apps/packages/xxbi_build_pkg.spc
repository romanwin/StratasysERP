CREATE OR REPLACE PACKAGE xxbi_build_pkg AS

-- ---------------------------------------------------------------------------------
-- Name:  xxbi_build_pkg     
-- Created By: John Hendrickson
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Used for populating BI tables
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032224.
-- 1.1  06/14/2014  Hendrickson Additions for CHG0032486
-- ---------------------------------------------------------------------------------

   /********************************************************************************
    This procedure first deletes, then re-inserts revenue
    facts to the XX_REVENUE_FACT table for a General
    Ledger Period.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/
   PROCEDURE build_revenue_fact(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   ,  p_period_name  IN VARCHAR2
   );

    /********************************************************************************
    This procedure deletes from the XX_REVENUE_FACT table for a given Year.  
    Assumption is that this program will run under concurrent manager 
    standard report submission.  YEAR is required, and validated
    via standard report submission.
   *********************************************************************************/   
   PROCEDURE purge_revenue_fact(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   ,  p_year         IN NUMBER
   );

    /********************************************************************************
    This procedure first deletes, then re-inserts cost
    facts to the XXMTL_COSTS_FACT table for a General
    Ledger Period.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/   
   PROCEDURE build_cost_fact(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   ,  p_period_name  IN VARCHAR2
   );
  
      /********************************************************************************
    This procedure first deletes, then re-inserts all GL Periods
    to the XXGL_PERIODS_T table.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/   
   PROCEDURE build_gl_periods(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   );
   
END xxbi_build_pkg;

/
SHOW ERRORS

