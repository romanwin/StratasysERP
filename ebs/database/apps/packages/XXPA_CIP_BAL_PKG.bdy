create or replace PACKAGE BODY      XXPA_CIP_BAL_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXPA_CIP_BAL_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    27-FEB-2014
Purpose:         Find Various Column Values for XX: PA CIP Balances (EXCEL)
Program Style:   Stored Package Body
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
27-FEB-2014        1.0                  Sandeep Akula    Initial Version
26-JUN-2014        1.1                  Sandeep Akula    Added Functions GET_CIP_ADDITIONS and GET_TRANSFER_TO_FA
                                                         Changed the Logic in Function GET_BEGINNING_BALANCE  (CHG0032482)
23-MAR-2015        1.2                  Gubendran K      CHG0034884 - Added transfer_status_code and removed system_linkage_function condition from GET_BEGINNING_BALANCE/GET_CIP_ADDITIONS Functions                                                         
---------------------------------------------------------------------------------------------------*/
FUNCTION GET_BEGINNING_BALANCE(P_PROJECT_ID IN NUMBER,
                               P_CCID IN NUMBER,
                               P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER IS
l1_burdened_cost  NUMBER;
l1_transfer_to_fa NUMBER;
BEGIN
l1_burdened_cost := '';
begin
  SELECT SUM(pcdla.project_burdened_cost)
  INTO l1_burdened_cost
    FROM  pa_cost_distribution_lines_all   pcdla
     ,  pa_expenditure_items_all         peia
     ,  pa_tasks                         pt
     ,  pa_projects_all                  ppa
  WHERE --pcdla.resource_accumulated_flag  = 'Y'
        pcdla.expenditure_item_id        = peia.expenditure_item_id
  --AND   peia.system_linkage_function     IN ('VI','PJ') -- Removed as per the CR-CHG0034884
  AND   pcdla.transfer_status_code       <> 'R' --Added as per the CR-CHG0034884
  AND   peia.task_id                     = pt.task_id
  AND   pt.billable_flag                 = 'Y'
  AND   pt.project_id                    = ppa.project_id
  AND   ppa.project_id = P_PROJECT_ID
  AND   pcdla.dr_code_combination_id = P_CCID
  AND   to_date(gl_period_name,'MON-RR') < to_date(P_GL_PERIOD,'MON-RR')
  GROUP BY
          peia.project_id
       ,  pcdla.dr_code_combination_id;
EXCEPTION
WHEN OTHERS THEN
l1_burdened_cost := '';
END;

l1_transfer_to_fa := '';
begin
  SELECT SUM(current_asset_cost)
  INTO l1_transfer_to_fa
  FROM pa_project_asset_lines_v
  WHERE line_type = 'C'
  AND   project_id = P_PROJECT_ID
  AND   cip_ccid = P_CCID
  AND to_date(fa_period_name,'MON-RR') < to_date(P_GL_PERIOD,'MON-RR')
  GROUP BY project_id,
          cip_ccid;
EXCEPTION
WHEN OTHERS THEN
l1_transfer_to_fa := '';
END;

RETURN(nvl(l1_burdened_cost,'0')-nvl(l1_transfer_to_fa,'0'));
END GET_BEGINNING_BALANCE;

FUNCTION GET_CIP_ADDITIONS(P_PROJECT_ID IN NUMBER,
                           P_CCID IN NUMBER,
                           P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER IS
l_burdened_cost  NUMBER;
BEGIN
l_burdened_cost := '';
begin
  SELECT SUM(pcdla.project_burdened_cost)
  INTO l_burdened_cost
  FROM  pa_cost_distribution_lines_all   pcdla
     ,  pa_expenditure_items_all         peia
     ,  pa_tasks                         pt
     ,  pa_projects_all                  ppa
  WHERE --pcdla.resource_accumulated_flag  = 'Y'
        pcdla.expenditure_item_id        = peia.expenditure_item_id
  --AND   peia.system_linkage_function     IN ('VI','PJ') -- Removed as per the CR-CHG0034884
  AND   pcdla.transfer_status_code       <> 'R' --Added as per the CR-CHG0034884
  AND   peia.task_id                     = pt.task_id
  AND   pt.billable_flag                 = 'Y'
  AND   pt.project_id                    = ppa.project_id
  AND   ppa.project_id = P_PROJECT_ID
  AND   pcdla.dr_code_combination_id = P_CCID
  AND   to_date(gl_period_name,'MON-RR') = to_date(P_GL_PERIOD,'MON-RR')
  GROUP BY
          peia.project_id
       ,  pcdla.dr_code_combination_id;
EXCEPTION
WHEN OTHERS THEN
l_burdened_cost := '';
END;

RETURN(nvl(l_burdened_cost,'0'));
END GET_CIP_ADDITIONS;

FUNCTION GET_TRANSFER_TO_FA(P_PROJECT_ID IN NUMBER,
                            P_CCID IN NUMBER,
                            P_GL_PERIOD IN VARCHAR2)
RETURN NUMBER IS
l_transfer_to_fa NUMBER;
BEGIN

l_transfer_to_fa := '';
begin
  SELECT SUM(current_asset_cost)
  INTO l_transfer_to_fa
  FROM pa_project_asset_lines_v
  WHERE line_type = 'C'
  AND   project_id = P_PROJECT_ID
  AND   cip_ccid = P_CCID
  AND to_date(fa_period_name,'MON-RR') = to_date(P_GL_PERIOD,'MON-RR')
  GROUP BY project_id,
          cip_ccid;
EXCEPTION
WHEN OTHERS THEN
l_transfer_to_fa := '';
END;

RETURN(nvl(l_transfer_to_fa,'0'));

END GET_TRANSFER_TO_FA;

FUNCTION AFTERPFORM RETURN BOOLEAN IS
begin
NULL;
return (TRUE);
END AFTERPFORM;

FUNCTION BEFOREREPORT RETURN BOOLEAN  IS
begin
null;
return (TRUE);
END BEFOREREPORT;

FUNCTION AFTERREPORT RETURN BOOLEAN IS
BEGIN
null;
return (TRUE);
END AFTERREPORT;
END XXPA_CIP_BAL_PKG;
/