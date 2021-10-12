create or replace package xxwsh_political IS

  --------------------------------------------------------------------

  --  name:               xxwsh_political
  --  create by:          yuval tal
  --  $Revision:          1.1
  --  creation date:      20.12.10
  --  Purpose :           support political shipments
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    20.12.10     yuval tal       initial build
  --  1.1    16.01.11     Eran Baram      is_job_political - add reference to job class_code = 'Political'
  --   1.2    10.4.11      yuval tal       change logic at is_so_hdr_political -
  --                                      exclude check in transaction types  mark with att10=Y     cr-241
  --  1.3   12/07/215    Michal Tzvik     CHG0035224: New function: is_item_political
  --   1.4   2.3.16     yuval tal          INC0059396 add get_ship_to_country function to spec
  --  1.5	20.02.2018  bellona banerjee  CHG0041294- Added P_Delivery_Name to is_delivery_political,
  --									   is_delivery_political_mixed,  is_dlv_politic_shippable 
  --									   as part of delivery_id to delivery_name conversion 
  -----------------------------------------------------------------------
  FUNCTION get_ship_to_country(p_ship_to_org_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_job_political(p_wip_entity_id NUMBER) RETURN NUMBER;

  FUNCTION is_so_hdr_political(p_oe_header_id NUMBER) RETURN NUMBER;
  FUNCTION is_so_hdr_political(p_attribute18    VARCHAR2,
               p_ship_to_org_id NUMBER,
               p_order_type_id  NUMBER) RETURN NUMBER;
  FUNCTION is_so_line_political(p_oe_line_id NUMBER) RETURN NUMBER;

  FUNCTION is_delivery_political(p_delivery_name in varchar2)--(p_delivery_id NUMBER) -- CHG0041294 on 20/02/2018 for delivery id to name change
  RETURN NUMBER;

  FUNCTION is_delivery_political_mixed(p_delivery_name in varchar2)--(p_delivery_id NUMBER)    -- CHG0041294 on 20/02/2018 for delivery id to name change 
  RETURN NUMBER;

  FUNCTION is_dlv_politic_shippable(p_delivery_name in varchar2)--(p_delivery_id NUMBER)    -- CHG0041294 on 20/02/2018 for delivery id to name change  
  RETURN NUMBER;

  FUNCTION is_ship_to_political(p_site_id NUMBER) RETURN NUMBER;

  FUNCTION is_country_political(p_country VARCHAR2) RETURN NUMBER;

  FUNCTION is_delivery_detail_political(p_delivery_detail_id NUMBER)
    RETURN NUMBER;

  FUNCTION is_item_political(p_inventory_item_id NUMBER) RETURN VARCHAR2;

END;
/