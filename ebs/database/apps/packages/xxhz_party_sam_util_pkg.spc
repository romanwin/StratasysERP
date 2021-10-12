CREATE OR REPLACE PACKAGE xxhz_party_sam_util_pkg AS
  --------------------------------------------------------------------
  --  name:            xxhz_party_sam_util_pkg
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   5/1/2015
  --------------------------------------------------------------------
  --  purpose : Utility package used by XXHZ_PARTY_SAM_RPT XML report
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------

  P_PRICING_DEBUG_FLAG  VARCHAR2(1) DEFAULT 'N';
  P_START_DATE	        DATE;
  P_END_DATE	        DATE;

  FUNCTION get_ib_sam_basket(p_amount  NUMBER)
  RETURN VARCHAR2;

  FUNCTION price_item_by_price_list(
    p_inventory_item_id     IN NUMBER,
    p_price_list_id         IN NUMBER,
    p_price_list_curr_code  IN VARCHAR2
  )
  RETURN VARCHAR2;
  
  FUNCTION get_ib_aging_factor(p_date DATE)
  RETURN NUMBER;

  FUNCTION stage_sam_pricing_tbl
  RETURN BOOLEAN;
  
  FUNCTION delete_sam_pricing_tbl
  RETURN BOOLEAN;
  
  PROCEDURE truncate_sam_pricing_tbl(
    x_errbuff     OUT VARCHAR2,
    x_retcode     OUT VARCHAR2
  );  

END xxhz_party_sam_util_pkg;
/

SHOW ERRORS