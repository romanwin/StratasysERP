CREATE OR REPLACE PACKAGE xxmsc_horizontal_plan_pkg IS
   ---------------------------------------------------------------------------
   -- $Header: xxmsc_horizontal_plan_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxmsc_horizontal_plan_pkg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Manipulate user defined column in horizontal plan
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   /***************************************************************************
   Metalink Note 5227328
   -------------------------
   A. New preference option 'User Defined': 
      1. This option is added to 'Material Plan' tab of Preference 
         window under  'Demand' region. 
         The default value is unchecked. 
      2. This field will be displayed only when the profile
         'MSC: Horizontal Plan Extension Program' is not a null value
      3. This option label 'User Defined' and the corresponding row type
         displayed in HP can be customized. 
         For a ASCP plan, it is tied to the lookup meaning for lookup 
         code 500 and lookup type 'MRP_HORIZONTAL_PLAN_TYPE_SC'.    
         For a IO plan, the lookup type is 'MSC_HORIZONTAL_PLAN_TYPE_IO'.
   B. To populate customized data to 'User Defined' row in HP: 
      The following is just an example. File name, package name and 
      procedure name can be anything, but the procedure needs to take 
      one number as in parameter. 
   *****************************************************************************/
   PROCEDURE customized_plan(p_query_id NUMBER);

   /****************************************************************************
   For DRP HP, the customized package needs to insert new row to 
   msc_drp_hori_plans for the 'User Defined' row. The following is an example, 
   *****************************************************************************/
   PROCEDURE add_new_row(p_query_id NUMBER);

END xxmsc_horizontal_plan_pkg;
/

