create or replace 
PACKAGE BODY xxpa_exp_item_rpt_pkg AS
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
--                              two parameters p_exp_org and p_proj_mgr and passed these paraemters to Detail report
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
)
IS
   l_request_id   NUMBER;
   l_return       BOOLEAN;
   l_location     VARCHAR2(100);
   e_error        EXCEPTION;
BEGIN
   -- Set BI Publisher template for request
   l_return := fnd_request.add_layout (
                  template_appl_name   => 'XXOBJT',
                  template_code        => 'XXPA_EXP_ITEM_DTL_XML',
                  template_language    => 'en',
                  template_territory   => 'US',
                  output_format        => p_output_type
               );
   IF NOT l_return THEN
      l_location := 'Error adding layout';
      RAISE e_error;
   END IF;

   l_request_id := fnd_request.submit_request (
                     application          => 'XXOBJT'
                  ,  program              => 'XXPA_EXP_ITEM_DTL_XML'
                  ,  argument1            => p_summary_flag
                  ,  argument2            => p_date_from
                  ,  argument3            => p_date_to
                  ,  argument4            => p_gl_period
                  ,  argument5            => p_project_id
                  ,  argument6            => p_project_type
                  ,  argument7            => p_account_from
                  ,  argument8            => p_account_to
                  ,  argument9            => p_company
                  ,  argument10           => p_organization
                  ,  argument11           => p_exp_org
                  ,  argument12           => p_proj_mgr
                  );

   IF l_request_id IS NULL THEN
      l_location := 'Error submitting request';
      RAISE e_error;
   ELSE
      fnd_file.put_line(fnd_file.output,'Please view this request '||l_request_id||' for report output.');
   END IF;

   x_retcode := 0;
EXCEPTION
   WHEN e_error THEN
      fnd_file.put_line(fnd_file.output,'Error while '||l_location);
      x_retcode := 2;
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Error occurred running report '||SQLERRM);
      x_retcode := 2;
END submit_xxpa_exp_item_dtl_xml;

END xxpa_exp_item_rpt_pkg;
/
show errors