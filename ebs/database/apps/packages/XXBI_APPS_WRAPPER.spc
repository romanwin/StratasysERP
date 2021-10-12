CREATE OR REPLACE PACKAGE APPS.XXBI_APPS_WRAPPER AUTHID DEFINER AS
----------------------------------------------------------------------------------------------------------------------------------------
--  Name : XXBI_APPS_WRAPPER
--  create by:       Shirley Brenkel
--  Revision:        1.0
--  creation date:   15-Jun-2017
----------------------------------------------------------------------------------------------------------------------------------------
--  Purpose:  Let BI ETL process reuse EBS code without giving a direct execute permission on each EBS package.

----------------------------------------------------------------------------------------------------------------------------------------
--  ver                   Date                       Name                                    Desc
--  1.0                    15-Jun-2017        Shirley Brenkel          Initial build (return NULL for function not yet in PROD) (CHG0041007)
--  1.1                    06-aug-2017        Shirley Brenkel          INC0099085 OM General Report fixing
--  1.2                    27-Dec-2017        Shirley Brenkel          CHG0042073 "get_master_org", "get_primary_uom"  and "inv_um_convert" for use in the PTP project
----------------------------------------------------------------------------------------------------------------------------------------


  FUNCTION fnd_profile_value(p_name IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION get_master_organization_id RETURN NUMBER;
  FUNCTION get_manufacturing_org (p_itemid IN NUMBER,p_asofdate IN DATE) RETURN NUMBER;
  FUNCTION get_il_std_cost(p_isrorgid IN NUMBER,
                           p_asofdate IN DATE,
                           p_itemid   IN NUMBER) RETURN NUMBER;

  FUNCTION is_bundle_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_model_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_option_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_comp_bundle_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_get_item_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_header_plist_item_price(p_inventory_item_id NUMBER,
                p_price_list_id NUMBER,-- From order header
                p_pricing_date DATE,--From order header
                p_line_id NUMBER DEFAULT NULL) RETURN NUMBER;

  FUNCTION safe_devisor(p_devisor NUMBER) RETURN NUMBER;

  FUNCTION get_price_list_for_resin(p_sales_order_line_id NUMBER, p_price_list NUMBER, p_attribute4 NUMBER) RETURN NUMBER;

  --Check if this can be cancelled
  FUNCTION get_price_list_dist(p_sales_order_line_id NUMBER, p_price_list NUMBER, p_attribute4 NUMBER) RETURN NUMBER;


  /* Start: Added by Rahul (TCS) on 2/22/2017 for CHG0039611 */
  FUNCTION view_average_discount(p_sales_ord_header_id NUMBER) RETURN NUMBER;

  /* Start: Added by Aritra (TCS) on 8/30/2017 for CHG0041186 */
  Procedure Xxbi_Ar_Aging(P_As_Of_Date Varchar2);

  FUNCTION inv_um_convert(p_itemid IN NUMBER,p_from_uom_code IN VARCHAR2, p_to_uom_code IN VARCHAR2) RETURN NUMBER;
  
  FUNCTION get_primary_uom(p_itemid IN NUMBER, p_org_id IN NUMBER,p_current_uom IN  VARCHAR2) RETURN VARCHAR2;

End Xxbi_Apps_Wrapper;
/
