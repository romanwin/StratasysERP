CREATE OR REPLACE PACKAGE BODY APPS.XXBI_APPS_WRAPPER AS
  ----------------------------------------------------------------------------------------------------------------------------------------
--  Name : XXBI_APPS_WRAPPER
--  create by:       Shirley Brenkel
--  Revision:        1.3
--  creation date:   15-Jun-2017
----------------------------------------------------------------------------------------------------------------------------------------
--  Purpose:  Let BI ETL process reuse EBS code without giving a direct execute permission on each EBS package.

 ----------------------------------------------------------------------------------------------------------------------------------------
--  ver                   Date                       Name                                    Desc
--  1.0                    15-Jun-2017        Shirley Brenkel          Initial build (return NULL for function not yet in PROD) (CHG0041007)
--  1.1                    06-aug-2017        Shirley Brenkel          INC0099085 OM General Report fixing
--  1.2                    27-Dec-2017        Shirley Brenkel          Add "get_master_org", "get_primary_uom"  and "inv_um_convert" for the PTP project
--  1.3                    19-Mar-2018        Mor Boyarski             replace inv_convert.inv_um_convert with po_uom_s.po_uom_convert_p. INC0115906
----------------------------------------------------------------------------------------------------------------------------------------

  ---   fnd_profile.value
  FUNCTION fnd_profile_value(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN fnd_profile.value(p_name);
  END fnd_profile_value;
 
  ---   xxinv_utils_pkg.get_master_organization_id
  FUNCTION get_master_organization_id RETURN NUMBER IS
  BEGIN
    RETURN xxinv_utils_pkg.get_master_organization_id;
  END get_master_organization_id;
  
  ----  get_manufacturing_org
  FUNCTION get_manufacturing_org (p_itemid IN NUMBER,p_asofdate IN DATE) RETURN NUMBER IS
  BEGIN
    RETURN xxcst_ratam_pkg.get_manufacturing_org(p_itemid,p_asofdate);
  END get_manufacturing_org;

  ----  get_il_std_cost
  FUNCTION get_il_std_cost(p_isrorgid IN NUMBER,
                           p_asofdate IN DATE,
                           p_itemid   IN NUMBER) RETURN NUMBER IS

  BEGIN
    RETURN xxcst_ratam_pkg.get_il_std_cost(p_isrorgid, p_asofdate, p_itemid);
  END;

  --- Sale Order Line:  is_bundle_line
  FUNCTION is_bundle_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2 IS

  BEGIN
    RETURN xxoe_utils_pkg.is_bundle_line(p_sales_order_line_id);
  END is_bundle_line;

  --- Sale Order Line:  is_model_line
  FUNCTION is_model_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2 IS

  BEGIN
    RETURN xxoe_utils_pkg.is_model_line(p_sales_order_line_id);
  END is_model_line;

  --- Sale Order Line:  is_option_line
  FUNCTION is_option_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2 IS

  BEGIN
    RETURN xxoe_utils_pkg.is_option_line(p_sales_order_line_id);
  END is_option_line;

  --- Sale Order Line:  is_comp_bundle_line
  FUNCTION is_comp_bundle_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2 IS

  BEGIN
    RETURN xxoe_utils_pkg.is_comp_bundle_line(p_sales_order_line_id);
  END is_comp_bundle_line;

  --- Sale Order Line:  is_get_item_line
  FUNCTION is_get_item_line(p_sales_order_line_id NUMBER) RETURN VARCHAR2 IS

  BEGIN
    RETURN xxqp_get_item_avg_dis_pkg.is_get_item_line(p_sales_order_line_id);
  END is_get_item_line;

  ---   xxqp_get_item_avg_dis_pkg.get_price
  FUNCTION get_header_plist_item_price(p_inventory_item_id NUMBER,
                p_price_list_id NUMBER,-- From order header
                p_pricing_date DATE,--From order header
                p_line_id NUMBER DEFAULT NULL) RETURN NUMBER IS
  BEGIN
      RETURN  xxqp_get_item_avg_dis_pkg.get_price(p_inventory_item_id,p_price_list_id,p_pricing_date,p_line_id);
  END  get_header_plist_item_price;

  ---   safe_devisor - to be used when doing a division  between number and need to validate the denominator
  FUNCTION safe_devisor(p_devisor NUMBER) RETURN NUMBER IS
  BEGIN
     RETURN xxar_autoinvoice_pkg.safe_devisor(p_devisor);
  END safe_devisor;

  FUNCTION get_price_list_for_resin(p_sales_order_line_id NUMBER,p_price_list NUMBER, p_attribute4 NUMBER) RETURN NUMBER IS
  BEGIN
    RETURN xxar_autoinvoice_pkg.get_price_list_for_resin(p_sales_order_line_id, p_price_list,p_attribute4 ) ;
  END get_price_list_for_resin;

  ---   get_price_list_dist
  FUNCTION get_price_list_dist(p_sales_order_line_id  NUMBER, p_price_list NUMBER, p_attribute4 NUMBER) RETURN NUMBER IS
  BEGIN
    -- RETURN 0;
    RETURN xxar_autoinvoice_pkg.get_price_list_dist(p_sales_order_line_id,p_price_list,p_attribute4) ; -- INC0099085
  END;

  ---   view_average_discount
  ---   Start: Added by Rahul (TCS) on 2/22/2017 for CHG0039611
  FUNCTION view_average_discount(p_sales_ord_header_id NUMBER) RETURN NUMBER IS
  BEGIN
    --RETURN xxar_autoinvoice_pkg.view_average_discount(p_sales_ord_header_id);
    RETURN 0;
  END view_average_discount;

/* Start: Added by Aritra (TCS) on 8/30/2017 for CHG0041186 */
 Procedure Xxbi_Ar_Aging(P_AS_OF_DATE VARCHAR2)
IS
  l_request_id   NUMBER;
  l_user_id      NUMBER ;
  l_resp_id      NUMBER;
  l_resp_appl_id NUMBER;
BEGIN
  dbms_output.put_line('Start !!');
  SELECT b.responsibility_id,
    b.application_id
  INTO l_resp_id,
    l_resp_appl_id
  FROM fnd_profile_option_values a,
    fnd_responsibility_vl b,
    fnd_profile_options e,
    fnd_profile_options_tl pot
  WHERE e.profile_option_name = 'ORG_ID'
  AND e.PROFILE_OPTION_NAME   = pot.profile_option_name
  AND e.profile_option_id     = a.profile_option_id
  AND a.level_value           = b.responsibility_id
  AND pot.LANGUAGE            = 'US'
  AND upper(b.responsibility_name) LIKE upper('AR Inquiry, SSYS US')
  AND a.profile_option_value = '737' ;
  SELECT user_id INTO l_user_id FROM fnd_user WHERE user_name = 'SYSADMIN';
  fnd_global.apps_initialize(user_id => l_user_id, resp_id => l_resp_id, resp_appl_id => l_resp_appl_id);
  Mo_Global.Set_Policy_Context('S',737);
  l_request_id := fnd_request.submit_request ( application => 'XXOBJT', program => 'XXAR_AGING_MASTER', description => 'Aging - By Account Report', start_time => sysdate, sub_request => FALSE, argument1 => P_AS_OF_DATE, argument2 => '' );
  COMMIT;
  dbms_output.put_line('Request Submitted: '||l_Request_id);
EXCEPTION
WHEN OTHERS THEN
  Dbms_Output.Put_Line('Submit Request error:'||Sqlcode||Sqlerrm);
End Xxbi_Ar_Aging;

 ---1.2 po_uom_s.get_primary_uom 
  FUNCTION get_primary_uom(p_itemid IN NUMBER, p_org_id IN NUMBER,p_current_uom IN  VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN po_uom_s.get_primary_uom(p_itemid,p_org_id,p_current_uom);
  END get_primary_uom;
  
 ---1.2  inv_convert.inv_um_convert
  FUNCTION inv_um_convert(p_itemid IN NUMBER,p_from_uom_code IN VARCHAR2, p_to_uom_code IN VARCHAR2) RETURN NUMBER IS
  BEGIN    
    RETURN  po_uom_s.po_uom_convert_p(p_from_uom_code,p_to_uom_code,p_itemid); --V1.3
  END inv_um_convert;

End Xxbi_Apps_Wrapper
;
/
