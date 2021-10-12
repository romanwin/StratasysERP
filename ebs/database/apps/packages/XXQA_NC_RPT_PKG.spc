CREATE OR REPLACE PACKAGE APPS.xxqa_nc_rpt_pkg AUTHID CURRENT_USER AS
  -----------------------------------------------------------------------
  --  name:               xxqa_nc_rpt_pkg
  --  create by:          xxxxxxxx
  --  Revision:           1.0
  --  creation date:      xxxxxxx
  --  Purpose :           CHG0040770 - Quality Nonconformance Report
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xxxxxx        xxxxx           S3 Initial Build
  --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
  --  1.2   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
  -----------------------------------------------------------------------------------

    /* Functional Overview: The Quality Nonconformance Report displays
      information pertaining to quality-related nonconformances.  It is physically
      affixed to the nonconforming material.  The Information displayed on this
      report comes from three Collection Plans (in each Org): Nonconformance,
      Nonconformance Verification, and Disposition.

      Technical Overview: Because of the "flexible" nature of Oracle Quality
      Collection Plan configurations, building a single nonconformance report that
      will work for collection plans in an arbitrary organization requires some
      complexity.  This package supports an XML Publisher-based report using
      dynamic SQL to allow it to be run in any org that strictly implements a
      Nonconformance--Verify Nonconformance--Disposition colelction plan hierachy.

      In addition to supporting the XML Publisher-based Quality Nonconformance
      report, this package can be used for analytical reporting, albeit with less
      than optimal performance due to the dynamic SQL utilized.

      The primary function used is f_report_data, which utilizes a reference
      cursor and returns a custom table type object.  This allows the function to
      be called directly from SQL by specifying (optional) paramaters for a
      specific Nonconformance Number, and/or Verify Nonconformance Number, and/or
      Disposition Number.  (The main query in the Data Template uses this
      function in a SQL statement).  See the description for the function,
      f_report_data, in the package body for a more detailed description.
     --------
      Constants for Collection Plan Result Views.
       These constants are for building the name of each collection plan
       results view.  The collection plan names in each org must be globally unique
       so the convention is to use a standard name with an org code suffix, for
       example, "NONCONFORMANCE_UME".
    */

    c_plan_type_code_1 CONSTANT VARCHAR2(50) := 'XX_NONCONFORMANCE'; --Nonconformance Collection Plan Type Code
    c_plan_type_code_2 CONSTANT VARCHAR2(50) := 'XX_VERIFY_NONCONFORMANCE'; --Verify Nonconformance Collection Plan Type Code
    c_plan_type_code_3 CONSTANT VARCHAR2(50) := 'XX_DISPOSITION'; --Disposition Collection Plan Type Code

    c_sequence_column_1 CONSTANT VARCHAR2(50) := 'XX_NONCONFORMANCE_NUMBER'; --Auto-incrementing (sequence) column for the Nonconformance number.
    c_sequence_column_2 CONSTANT VARCHAR2(50) := 'XX_VERIFY_NC_NUMBER'; --Auto-incrementing (sequence) column for the Verify Nonconformance number.
    c_sequence_column_3 CONSTANT VARCHAR2(50) := 'XX_DISPOSITION_NUMBER'; --Auto-incrementing (sequence) column for the Disposition number.

    c_parent_sequence_column_1 CONSTANT VARCHAR2(50) := 'XX_NONCONFORMANCE_NUMBER'; --can't be null (even though there really isn't a parent) but this is use in a dynamic query so that causes a problem and we just refernce
    c_parent_sequence_column_2 CONSTANT VARCHAR2(50) := 'XX_NONCONFORMANCE_NO_REFERENCE'; --Nonconformance
    c_parent_sequence_column_3 CONSTANT VARCHAR2(50) := 'XX_VERIFY_NC_NO_REFERENCE'; --Verify Nonconformance

    /* Debug Constants*/
    c_debug_level NUMBER := 10;  --0: Off, 10: On,
    c_output_header CONSTANT VARCHAR2(200) :=  '***Beginning of Output***';--Used for log file/debug statements
    c_output_footer CONSTANT VARCHAR2(200) :=  '***End of Output***';--Used for log file/debug statements

    /* Paramater Variables (required for XML Publisher-based reports)*/
    P_ORGANIZATION_ID NUMBER;
    P_NONCONFORMANCE_NUMBER VARCHAR2(8);
    P_VERIFY_NONCONFORMANCE_NUMBER VARCHAR2(8);
    P_DISPOSITION_NUMBER VARCHAR2(8);
    P_PRINT_VERIFY_NC_RESULT VARCHAR2(3);
    P_PRINT_REPORT_HEADER_FOOTER VARCHAR2(3);
    P_REPORT_LAYOUT_NAME VARCHAR2(30);

  -----------------------------------------------------------------------
  --  name:               f_report_data
  --  create by:          xxxxxxxx
  --  Revision:           1.0
  --  creation date:      xxxxxxx
  --  Purpose :           CHG0040770 - Quality Nonconformance Report
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xxxxxx        xxxxx           S3 Initial Build
  --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
  -----------------------------------------------------------------------------------
  FUNCTION f_report_data (
                          p_sequence_1_value IN VARCHAR2
                         ,p_sequence_2_value IN VARCHAR2
                         ,p_sequence_3_value IN VARCHAR2
                         ,p_organization_id  IN NUMBER
                         ) RETURN apps.XXQA_NC_RPT_TAB_TYPE;

  -----------------------------------------------------------------------
  --  name:               f_report_parameter_lov
  --  create by:          xxxxxxxx
  --  Revision:           1.0
  --  creation date:      xxxxxxx
  --  Purpose :           CHG0040770 - Quality Nonconformance Report
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xxxxxx        xxxxx           S3 Initial Build
  --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
  -----------------------------------------------------------------------------------
  FUNCTION f_report_parameter_lov (
                                    p_plan_type_code  IN VARCHAR2
                                   ,p_sequence_number IN VARCHAR2
                                   ,p_organization_id IN NUMBER
  ) RETURN apps.XXQA_NCR_SEQ_LOV_TAB_TYPE;

  -----------------------------------------------------------------------
  --  Name:               print_nc_report
  --  Created By:         Hubert, Eric
  --  Revision:           1.0
  --  Creation Date:      31-Jul-2017 
  --  Purpose :           This function will create a concurrent request for the 
  --  'XXQA: Quality Nonconformance Report' (XXQANCR1).  The function has 
  --  separate arguments for the Nonconformance Number, Verify Nonconformance
  --  Number, and Disposition Number.  This allows for the printing of a 
  --  specific branch in the three-level parent-child collection plan 
  --  hierarchy.  However, in practice, there will typically be only a single
  --  verification and disposition record for a given nonconformance, thus
  --  providing just the Nonconformacne Number is sufficient.  
  --  
  --  There is an argument for explicitly indicating which printer should be used,
  --  to bypass any rules within the function for determining which printer should
  --  be used.
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
  -----------------------------------------------------------------------------------
  FUNCTION print_nc_report (
   p_organization_id IN NUMBER
   , p_sequence_1_value IN VARCHAR2 --Nonconformance Number
   , p_sequence_2_value IN VARCHAR2 --Verify Nonconformance Number
   , p_sequence_3_value IN VARCHAR2 --Disposition Number
   , p_printer_name IN VARCHAR2 --Optional printer name
  ) RETURN NUMBER; --Return Concurrent Request ID

  -----------------------------------------------------------------------
  --  Name:               p_plan_type
  --  Created By:         Hubert, Eric
  --  Revision:           1.0
  --  Creation Date:      31-Jul-2017 
  --  Purpose :           This procedure will return the Plan Type or a given 
  --  collection plan, via the plan ID.
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
  -----------------------------------------------------------------------------------
  FUNCTION plan_type (p_plan_id IN NUMBER)
  RETURN VARCHAR2;

  -----------------------------------------------------------------------
  --  Name:               print_ncr_from_occurrence
  --  Created By:         Hubert, Eric
  --  Revision:           1.0
  --  Creation Date:      31-Jul-2017 
  --  Purpose :           This is a wrapper function for print_nc_report.  It 
  --  simplifies the creation of the concurrent request for the report by only
  --  requiring the collection result occurrence, which is a unique ID number
  --  within the qa_results table.  From this occurrence, the required arguments
  --  can be determined to make a call of print_nc_report.
  ----------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
  -----------------------------------------------------------------------------------
  FUNCTION print_ncr_from_occurrence (
  p_occurrence IN NUMBER
  ) RETURN NUMBER; --Return Concurrent Request ID

END xxqa_nc_rpt_pkg;
/
