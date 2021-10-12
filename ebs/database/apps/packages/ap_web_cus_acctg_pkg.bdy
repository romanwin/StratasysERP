create or replace package body ap_web_cus_acctg_pkg AS
/* $Header: apwcaccb.pls 120.3.12010000.2 2008/08/06 07:44:50 rveliche ship $ */

---------------------------------------------
-- Some global types, constants and cursors
---------------------------------------------

---
--- Function/procedures
---

/*========================================================================
 | PUBLIC FUNCTION GetIsCustomBuildOnly
 |
 | DESCRIPTION
 |   This is called by Expenses Entry Allocations page
 |   when user presses Update/Next (only if Online Validation is disabled).
 |
 |   If you want to enable custom rebuilds in Expenses Entry Allocations page,
 |   when Online Validation is disabled, modify this function to:
 |
 |         return 1 - if you want to enable custom builds
 |         return 0 - if you do not want to enable custom builds
 |
 |   If Online Validation is enabled, custom rebuilds can be performed
 |   in BuildAccount (when p_build_mode = C_VALIDATE).
 |
 |   If Online Validation is disabled, custom rebuilds can be performed
 |   in BuildAccount, as follows:
 |      (1) in Expenses Entry Allocations page (when p_build_mode = C_CUSTOM_BUILD_ONLY)
 |      (2) in Expenses Workflow AP Server Side Validation (when p_build_mode = C_VALIDATE)
 |
 | MODIFICATION HISTORY
 | Date                  Author            Description of Changes
 | 25-Aug-2005           R Langi           Created
 |
 *=======================================================================*/
FUNCTION GetIsCustomBuildOnly RETURN NUMBER
IS
BEGIN

    -- if you want to enable custom builds
    --return 1;

    -- if you do not want to enable custom builds
    return 0;

END;


/*========================================================================
 | PUBLIC FUNCTION BuildAccount
 |
 | DESCRIPTION
 |   This function provides a client extension to Internet Expenses
 |   for building account code combinations.
 |
 |   Internet Expenses builds account code combinations as follows:
 |
 |   If a CCID is provided then get the segments from the CCID else use the
 |   segments provided.  Overlay the segments using the expense type segments.
 |   If the expense type segments are empty then use the employee's default
 |   CCID segments (which is overlaid with the expense report header level
 |   cost center segment).  If Expense Type Cost Center segment is empty,
 |   then overlay using line level cost center or header level cost center.
 |
 |   This procedure returns the built segments and CCID (if validated).
 |
 |
 | CALLED FROM PROCEDURES/FUNCTIONS (local to this package body)
 |
 |   Always used for default employee accounting
 |   (1) Expenses Workflow AP Server Side Validation
 |
 |   PARAMETERS
 |      p_report_header_id              - NULL in this case
 |      p_report_line_id                - NULL in this case
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - contains the expense report cost center
 |      p_exp_type_parameter_id         - NULL in this case
 |      p_segments                      - NULL in this case
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_DEFAULT_VALIDATE
 |      p_new_segments                  - returns the default employee segments
 |      p_new_ccid                      - returns the default employee code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |   When Expense Entry Allocations is enabled:
 |   (1) Initial render of Expense Allocations page:
 |          - creates new distributions
 |            or
 |          - rebuilds existing distributions when expense type changed
 |            or
 |          - rebuilds existing distributions when expense report header cost center changed
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - contains the expense report cost center
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_segments                      - contains the expense report line segments
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_DEFAULT
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 |   When Expense Entry Allocations is enabled with Online Validation:
 |   (1) When user presses Update/Next on Expense Allocations page:
 |          - rebuilds/validates user modified distributions
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - NULL in this case
 |      p_exp_type_parameter_id         - NULL in this case
 |      p_segments                      - contains the expense report line segments
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_VALIDATE
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 |   When Expense Entry Allocations is enabled without Online Validation:
 |   (1) When user presses Update/Next on Expense Allocations page:
 |          - rebuilds user modified distributions
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - NULL in this case
 |      p_exp_type_parameter_id         - NULL in this case
 |      p_segments                      - contains the expense report line segments
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_CUSTOM_BUILD_ONLY
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |   (2) Expenses Workflow AP Server Side Validation
 |          - validates user modified distributions
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - contains the expense report cost center
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_segments                      - contains the expense report line segments
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_VALIDATE
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 |   When Expense Entry Allocations is disabled:
 |   (1) Expenses Workflow AP Server Side Validation
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - contains the expense report cost center
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_segments                      - NULL in this case
 |      p_ccid                          - NULL in this case
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_DEFAULT_VALIDATE
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 |   When Expense Type is changed by Auditor:
 |   (1) Expenses Audit
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_employee_id                   - contains the employee id
 |      p_cost_center                   - contains the expense report cost center
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_segments                      - NULL in this case
 |      p_ccid                          - contains the expense report line code combination id
 |      p_build_mode                    - AP_WEB_ACCTG_PKG.C_BUILD_VALIDATE
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 | CALLS PROCEDURES/FUNCTIONS (local to this package body)
 |
 | RETURNS
 |   True if BuildAccount was customized
 |   False if BuildAccount was NOT customized
 |
 |
 | MODIFICATION HISTORY
 | Date                  Author            Description of Changes
 | 12-Aug-2005           R Langi           Created
 | 05-jul-2009           Shai E            customized for Objet to obtain the SUBACCOUNT value from attribute1
 |                                         in the expense report header 
 | 21-Jan-2019           Bellona B.        CHG0044562- iExpense the Subaccount entry is not working
 |                                         Commenting customization used for subaccount entry.
 *=======================================================================*/

FUNCTION BuildAccount(
        p_report_header_id              IN NUMBER,
        p_report_line_id                IN NUMBER,
        p_employee_id                   IN NUMBER,
        p_cost_center                   IN VARCHAR2,
        p_exp_type_parameter_id         IN NUMBER,
        p_segments                      IN AP_OIE_KFF_SEGMENTS_T,
        p_ccid                          IN NUMBER,
        p_build_mode                    IN VARCHAR2,
        p_new_segments                  OUT NOCOPY AP_OIE_KFF_SEGMENTS_T,
        p_new_ccid                      OUT NOCOPY NUMBER,
        p_return_error_message          OUT NOCOPY VARCHAR2) RETURN BOOLEAN
IS


  l_debug_info                  VARCHAR2(100);

  l_default_emp_ccid            AP_WEB_DB_EXPRPT_PKG.expHdr_employeeCCID;
  l_chart_of_accounts_id        NUMBER;
  l_cost_center_seg_num         NUMBER;
  l_flex_segment_delimiter      VARCHAR2(1);
  l_default_emp_segments        FND_FLEX_EXT.SEGMENTARRAY;
  l_FlexConcactenated           AP_EXPENSE_REPORT_PARAMS.FLEX_CONCACTENATED%TYPE;
  l_exp_type_template_array     FND_FLEX_EXT.SEGMENTARRAY;
  l_exp_line_acct_segs_array    FND_FLEX_EXT.SEGMENTARRAY;
  l_num_segments                NUMBER:=NULL;
  l_concatenated_segments   varchar2(2000);

  l_subaccount                  GL_CODE_COMBINATIONS.Segment4%TYPE;

  C_DEFAULT    CONSTANT VARCHAR2(30) := 'DEFAULT';
  C_CUSTOM_BUILD_ONLY  CONSTANT VARCHAR2(30) := 'CUSTOM_BUILD_ONLY';
  C_DEFAULT_VALIDATE  CONSTANT VARCHAR2(30) := 'DEFAULT_VALIDATE';
  C_BUILD_VALIDATE  CONSTANT VARCHAR2(30) := 'BUILD_VALIDATE';
  C_VALIDATE    CONSTANT VARCHAR2(30) := 'VALIDATE';


BEGIN

  /* start OBJET custom code here */
  /* follow same concept like in the original code AP_WEB_ACCTG_PKG.BuildAccount; In the end, replace the
     subaccount segment */


  --------------------------------------------------------------------
  l_debug_info := 'Start OBJET Custom Code AP_WEB_CUS_ACCTG_PKG.BuildAccount';
  --------------------------------------------------------------------

  -----------------------------------------------------
  l_debug_info := 'OBJET Custom: Get the HR defaulted Employee CCID';
  -----------------------------------------------------
  IF (NOT AP_WEB_DB_EXPRPT_PKG.GetDefaultEmpCCID(
         p_employee_id          => p_employee_id,
         p_default_emp_ccid     => l_default_emp_ccid)) THEN
      NULL;
  END IF;

  IF (l_default_emp_ccid is null) THEN
    FND_MESSAGE.Set_Name('SQLAP', 'AP_WEB_EXP_MISSING_EMP_CCID');
    RAISE AP_WEB_OA_MAINFLOW_PKG.G_EXC_ERROR;
  END IF;

  -----------------------------------------------------
  l_debug_info := 'OBJET Custom: Get the Employee Chart of Accounts ID';
  -----------------------------------------------------
  IF (NOT AP_WEB_DB_EXPRPT_PKG.GetChartOfAccountsID(
         p_employee_id          => p_employee_id,
         p_chart_of_accounts_id => l_chart_of_accounts_id)) THEN
      NULL;
  END IF;

  IF (l_chart_of_accounts_id is null) THEN
    FND_MESSAGE.Set_Name('SQLAP', 'OIE_MISS_CHART_OF_ACC_ID');
    RAISE AP_WEB_OA_MAINFLOW_PKG.G_EXC_ERROR;
  END IF;

  -----------------------------------------------------------------
  l_debug_info := 'OBJET Custom: Get employee default ccid account segments';
  -----------------------------------------------------------------
  IF (l_default_emp_ccid IS NOT NULL) THEN
    IF (NOT FND_FLEX_EXT.GET_SEGMENTS(
                                'SQLGL',
                                'GL#',
                                l_chart_of_accounts_id,
                                l_default_emp_ccid,
                                l_num_segments,
                                l_default_emp_segments)) THEN
      RAISE AP_WEB_OA_MAINFLOW_PKG.G_EXC_ERROR;
    END IF; /* GET_SEGMENTS */
  END IF;

  ----------------------------------------
  l_debug_info := 'OBJET Custom: Get Cost Center Segment Number';
  ----------------------------------------
  IF (NOT FND_FLEX_APIS.GET_QUALIFIER_SEGNUM(
                                101,
                                'GL#',
                                l_chart_of_accounts_id,
                                'FA_COST_CTR',
                                l_cost_center_seg_num)) THEN
    /* We could not find the cost center segment, but we can still overlay the
     * expense type mask, so do nothing */
    null;
  END IF;

  ----------------------------------------
  l_debug_info := 'OBJET Custom: Get Segment Delimiter like .';
  ----------------------------------------
  l_flex_segment_delimiter := FND_FLEX_EXT.GET_DELIMITER(
                                        'SQLGL',
                                        'GL#',
                                        l_chart_of_accounts_id);

  IF (l_flex_segment_delimiter IS NULL) THEN
    FND_MSG_PUB.Add;
    RAISE AP_WEB_OA_MAINFLOW_PKG.G_EXC_ERROR;
  END IF;

  ----------------------------------------
  l_debug_info := 'OBJET Custom: Check if p_ccid or p_segments is passed';
  ----------------------------------------
  if (p_ccid is not null) then

    ----------------------------------------
    l_debug_info := 'OBJET Custom: Convert p_ccid into a segment array';
    ----------------------------------------
    IF (NOT FND_FLEX_EXT.GET_SEGMENTS('SQLGL',
                                      'GL#',
                                      l_chart_of_accounts_id,
                                      p_ccid,
                                      l_num_segments,
                                      l_exp_line_acct_segs_array)) THEN
      return FALSE;
    END IF;

  elsif (p_segments is not null and p_segments.count > 0) then

    ----------------------------------------
    l_debug_info := 'OBJET Custom: Convert p_segments into a segment array';
    ----------------------------------------

    IF (l_num_segments IS NULL) THEN
      l_num_segments := p_segments.count;
    END IF;

    -----------------------------------------------------
    l_debug_info := 'OBJET Custom: Assign values to l_exp_line_acct_segs_array';
    -----------------------------------------------------
    FOR i IN 1..l_num_segments LOOP
          l_exp_line_acct_segs_array(i) := p_segments(i);
    END LOOP;

  end if /* p_ccid is not null or p_segments is not null */;


  if (p_exp_type_parameter_id is not null) then
    ------------------------------------------------------------------------
    l_debug_info := 'OBJET Custom: calling AP_WEB_DB_EXPRPT_PKG.GetFlexConcactenated';
    ------------------------------------------------------------------------
    IF (AP_WEB_DB_EXPRPT_PKG.GetFlexConcactenated(
               p_parameter_id => p_exp_type_parameter_id,
               p_FlexConcactenated => l_FlexConcactenated)) THEN

       IF l_FlexConcactenated is not null THEN

          --------------------------------------------------------------
          l_debug_info:='OBJET Custom: Break Up Segments';
          --------------------------------------------------------------
          l_num_segments := FND_FLEX_EXT.Breakup_Segments(l_FlexConcactenated,
                                                          l_flex_segment_delimiter,
                                                          l_exp_type_template_array);
       END IF;

    END IF;

  end if; /* p_exp_type_parameter_id is not null */

  --------------------------------------------------------------
  l_debug_info:='OBJET Custom: Check Build Account Mode';
  --------------------------------------------------------------
  if (p_build_mode in (C_DEFAULT, C_DEFAULT_VALIDATE, C_BUILD_VALIDATE)) then


     -- Overlay the incoming segment values with the segment values
     -- defined in expense type template IF the incoming segment value
     -- is NULL.

        FOR i IN 1..l_num_segments LOOP
          -- If the incoming segment is not null, then keep this value, do nothing.
          IF (p_segments IS NOT NULL AND
              p_segments.EXISTS(i) AND
              p_segments(i) IS NOT NULL) THEN

            NULL;

          ELSIF (l_exp_type_template_array is not null and
              l_exp_type_template_array.count > 0 and
              l_exp_type_template_array(i) IS NOT NULL) THEN

            l_exp_line_acct_segs_array(i) := l_exp_type_template_array(i);

          ELSE

          /* If cost center is not defined on the expense type mask, override it from line
           * or header, if defined, in that order.  */

            IF i = l_cost_center_seg_num AND p_cost_center is not null THEN
              l_exp_line_acct_segs_array(i) := p_cost_center;

            ELSIF i = l_cost_center_seg_num AND p_cost_center is not null THEN
              l_exp_line_acct_segs_array(i) := p_cost_center;

            ELSIF (p_build_mode in (C_DEFAULT, C_DEFAULT_VALIDATE)) THEN
              l_exp_line_acct_segs_array(i) := l_default_emp_segments(i);
            END IF;

          END IF; /* l_exp_type_template_array(i) IS NOT NULL */

        END LOOP; /* 1..l_num_segments */

  end if; /* p_build_mode in (C_DEFAULT, C_DEFAULT_VALIDATE, C_BUILD_VALIDATE) */

  ------------------------------------------------
  ------------------------------------------------
 --Commented below section as part of CHG0044562- iExpense the Subaccount entry is not working. 
 --After entering it changes automatically to Zero - DE OU.

 
  /*-- Objet Custom: replace SUBACCOUNT Value based on DFF inputted in Expense Report Header
  --  IF p_report_header_id IS NOT NULL THEN
  l_debug_info:='OBJET Custom: Fill Expense Account - Subaccount';

  IF P_REPORT_HEADER_ID IS NOT NULL THEN

    BEGIN
      SELECT AERH.attribute1
        INTO l_subaccount
        FROM ap_expense_report_headers_all AERH
       WHERE AERH.report_header_id = P_REPORT_HEADER_ID
       ;

      EXCEPTION
        WHEN OTHERS THEN
          p_return_error_message := 'OBJET EXCEPTION getting exp header: ' || SQLERRM;
          FND_MESSAGE.set_encoded('OBJET EXCEPTION getting exp header: ' || SQLERRM);
          fnd_msg_pub.add();
          RETURN FALSE;
    END;

  -- fill value in COA

    l_exp_line_acct_segs_array(4) := l_subaccount;
  END IF;
  */
  -------------------------------------------------
  -------------------------------------------------


  --------------------------------------------------------------
  l_debug_info:='OBJET Custom: Check Build Account Mode 2';
  --------------------------------------------------------------
  if (p_build_mode in (C_DEFAULT_VALIDATE, C_BUILD_VALIDATE, C_VALIDATE)) then

      --------------------------------------------------------------
      l_debug_info:='OBJET Custom: Build Account Mode contains VALIDATE';
      --------------------------------------------------------------

      --------------------------------------------------------------
      l_debug_info := 'OBJET Custom: Retrieve new ccid';
      --------------------------------------------------------------
      -- Work around for bug 1569108
      l_concatenated_segments :=  FND_FLEX_EXT.concatenate_segments(l_num_segments,
                        l_exp_line_acct_segs_array,
                        l_flex_segment_delimiter);

      ------------------------------------------------------------------------
      l_debug_info := 'OBJET Custom: calling FND_FLEX_KEYVAL.validate_segs';
      ------------------------------------------------------------------------
      IF (FND_FLEX_KEYVAL.validate_segs('CREATE_COMBINATION',
                                        'SQLGL',
                                        'GL#',
                                        l_chart_of_accounts_id,
                                        l_concatenated_segments)) THEN

        p_new_ccid := FND_FLEX_KEYVAL.combination_id;

      ELSE

        p_return_error_message := FND_FLEX_KEYVAL.error_message;
        FND_MESSAGE.set_encoded(FND_FLEX_KEYVAL.encoded_error_message);
        fnd_msg_pub.add();
        RETURN FALSE;

      END IF; /* FND_FLEX_KEYVAL.validate_segs */

  end if; /* p_build_mode in (C_DEFAULT_VALIDATE, C_BUILD_VALIDATE, C_VALIDATE) */

  -----------------------------------------------------
  l_debug_info := 'Assign values to p_new_segments';
  -----------------------------------------------------
  p_new_segments := AP_OIE_KFF_SEGMENTS_T('');
  p_new_segments.extend(l_num_segments);
  FOR i IN 1..l_num_segments LOOP
        p_new_segments(i) := l_exp_line_acct_segs_array(i);
  END LOOP;

  /*
  --
  -- Insert logic to populate segments here
  --

  --
  -- Insert logic to validate segments here
  --

  --
  -- Insert logic to generate CCID here
  --

  return TRUE;
  */
  return TRUE;



END BuildAccount;


/*========================================================================
 | PUBLIC FUNCTION BuildDistProjectAccount
 |
 | DESCRIPTION
 |   This function provides a client extension to Internet Expenses
 |   for getting account code combinations for projects related expense line.
 |
 |   Internet Expenses gets account code combinations for projects related
 |   expense line as follows:
 |
 |   (1) Calls AP_WEB_PROJECT_PKG.ValidatePATransaction
 |   (2) Calls pa_acc_gen_wf_pkg.ap_er_generate_account
 |
 |   This procedure returns the validated segments and CCID.
 |
 |
 | CALLED FROM PROCEDURES/FUNCTIONS (local to this package body)
 |
 |   Called from the following for projects related expense lines:
 |   (1) Exp
 enses Workflow AP Server Side Validation
 |
 |   PAR

 TERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_report_distribution_id        - contains the expense report distribution identifier
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |      p_return_status                 - returns either 'SUCCESS', 'ERROR', 'VALIDATION_ERROR', 'GENERATION_ERROR'
 |
 |
 |   When Expense Type is changed by Auditor:
 |   (1) Expenses Audit
 |
 |   PARAMETERS
 |      p_report_header_id              - contains report header id
 |      p_report_line_id                - contains report line id
 |      p_report_distribution_id        - contains the expense report distribution identifier
 |      p_exp_type_parameter_id         - contains the expense type parameter id
 |      p_new_segments                  - returns the new expense report line segments
 |      p_new_ccid                      - returns the new expense report line code combination id
 |      p_return_error_message          - returns any error message if an error occurred
 |      p_return_status                 - returns either 'SUCCESS', 'ERROR', 'VALIDATION_ERROR', 'GENERATION_ERROR'
 |
 |
 | CALLS PROCEDURES/FUNCTIONS (local to this package body)
 |
 | RETURNS
 |   True if BuildProjectAccount was customized
 |   False if BuildProjectAccount was NOT customized
 |
 |
 | MODIFICATION HISTORY
 | Date                  Author            Description of Changes
 | 12-Aug-2005           R Langi           Created
 |
 *=======================================================================*/
FUNCTION BuildDistProjectAccount(
        p_report_header_id              IN              NUMBER,
        p_report_line_id                IN              NUMBER,
        p_report_distribution_id        IN              NUMBER,
        p_exp_type_parameter_id         IN              NUMBER,
        p_new_segments                  OUT NOCOPY AP_OIE_KFF_SEGMENTS_T,
        p_new_ccid                      OUT NOCOPY      NUMBER,
        p_return_error_message          OUT NOCOPY      VARCHAR2,
        p_return_status                 OUT NOCOPY      VARCHAR2) RETURN BOOLEAN

IS


BEGIN

  /*
  --
  -- Insert logic to populate segments here
  --

  --
  -- Insert logic to validate segments here
  --

  --
  -- Insert logic to generate CCID here
  --

  return TRUE;
  */
  return FALSE;

END BuildDistProjectAccount;

/*========================================================================
 | PUBLIC FUNCTION CustomValidateProjectDist
 |
 | DESCRIPTION
 |   This function provides a client extension to Internet Expenses
 |   to validate Project Task and Award. Introduced for fix: 7176464
 |
 |
 |   PARAMETERS
 |      p_report_line_id                - contains report line id
 |      p_web_parameter_id          - contains the expense type parameter id
 |      p_project_id            - contains the Id of the Project entered in Allocations
 |      p_task_id                  - contains the Id of the Task entered in Allocations
 |      p_award_id                      - contains the Id of the Award entered in Allocations
 |      p_expenditure_org_id            - contains the Id of the Project Expenditure Organization entered in Allocations
 |      p_amount            - contains the amount entered on the distribution
 |      p_return_error_message          - returns any error message if an error occurred
 |
 |
 | RETURNS
 |   True if CustomValidateProjectDist was customized
 |   False if CustomValidateProjectDist was NOT customized
 |
 |
 | MODIFICATION HISTORY
 | Date                  Author            Description of Changes
 | 01-JUL-2008           Rajesh Velicheti           Created
 |
 *=======================================================================*/

FUNCTION CustomValidateProjectDist(
       p_report_line_id      IN    NUMBER,
       p_web_parameter_id    IN    NUMBER,
       p_project_id      IN    NUMBER,
       p_task_id                        IN    NUMBER,
       p_award_id      IN    NUMBER,
       p_expenditure_org_id    IN    NUMBER,
       p_amount        IN    NUMBER,
       p_return_error_message    OUT NOCOPY  VARCHAR2) RETURN BOOLEAN
IS

BEGIN

  /*
  -- Insert logic to validate Project, Task and Award.
  -- Error messages if any should be populated in p_return_error_message

  return TRUE;
  */
  return FALSE;

END CustomValidateProjectDist;


END AP_WEB_CUS_ACCTG_PKG;
/