CREATE OR REPLACE PACKAGE XXMSC_UTILS_PKG IS

   -- Author  : Vitaly K.
   -- Created : 07/01/2010
   -- Purpose : 
  --------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   XXXXXX      XXXXXX         XXXXXXX
  --  1.1   28/08/2019  Bellona(TCS)   CHG0046023 - add is_plan_operation_enable.
  --									called from form personalization.
  --                                   (Advanced Supply Chain Plan) 
  --------------------------------------------------------------------   
FUNCTION msc_vs_current_supply(p_organization_id in number,
                               p_plan_id         in number,
                               p_item_name       in varchar2) RETURN NUMBER;

FUNCTION msc_excess_po_supply(p_po_header_id in number,
                               p_plan_id         in number,
                               p_item_name       in varchar2) RETURN NUMBER;

                               
FUNCTION is_plan_operation_enable(p_user_id in number,
                                  p_plan_name in varchar2) RETURN VARCHAR2;                               

END XXMSC_UTILS_PKG;
/
