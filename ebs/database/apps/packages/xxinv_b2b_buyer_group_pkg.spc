CREATE OR REPLACE PACKAGE xxinv_b2b_buyer_group_pkg IS

  -- Author  : YUVAL.TAL
  -- Created : 7/10/2020 4:27:49 PM
  -- Purpose : CHG0048217 oracle sfdc B2B sync

  FUNCTION get_entitlementpolicy_sf_id(p_cat_ext_key VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_buyergroup_sf_id(p_product_cat_ext_key VARCHAR2)
    RETURN VARCHAR2;
  PROCEDURE populate_events(err_buff         OUT VARCHAR2,
		    err_code         OUT VARCHAR2,
		    p_price_list_id  NUMBER,
		    p_account_number VARCHAR2);
END xxinv_b2b_buyer_group_pkg;
/
