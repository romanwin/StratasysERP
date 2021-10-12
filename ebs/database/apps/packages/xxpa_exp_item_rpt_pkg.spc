create or replace 
PACKAGE xxpa_exp_item_rpt_pkg AS
-- ---------------------------------------------------------------------------------
-- Name:       XXPA_EXP_ITEM_RPT_PKG.spc
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: This package is used by the XX: PA Expenditure Item Detail (EXCEL) reports
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/21/2014  MMAZANET    Initial Creation for CR 1281 (Tech Log 72)
-- 2.0  09/10/2014  SMIRA       Modified this pkg for Change request 32060 and added
--                              two parameters p_exp_org and p_proj_mgr
-- ---------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------
-- This procedure is called from either the XX: PA Expenditure Item Detail (EXCEL)
-- or the XX: PA Expenditure Item Summary (EXCEL).  The program then calls
-- the XX: PA Expenditure Item Detail (XML) XML Publisher report.  This
-- gives us more flexibility with the concurrent programs to turn parameters
-- on and off or make them required or not-required.
-- ---------------------------------------------------------------------------------
PROCEDURE submit_xxpa_exp_item_dtl_xml(
   x_errbuff               OUT NUMBER
,  x_retcode               OUT VARCHAR2
,  p_summary_flag          IN  VARCHAR2
,  p_date_from             IN  VARCHAR2
,  p_date_to               IN  VARCHAR2
,  p_gl_period             IN  VARCHAR2
,  p_project_id            IN  NUMBER
,  p_project_type          IN  VARCHAR2
,  p_account_from          IN  gl_code_combinations.segment1%TYPE
,  p_account_to            IN  gl_code_combinations.segment1%TYPE
,  p_company               IN  gl_code_combinations.segment1%TYPE
,  p_organization          IN  NUMBER
,  p_output_type           IN  VARCHAR2
,  p_exp_org               IN  NUMBER
,  p_proj_mgr              IN  NUMBER
);

END xxpa_exp_item_rpt_pkg;
/
show errors
