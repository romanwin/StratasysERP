CREATE OR REPLACE PACKAGE xxhz_b2b_pkg IS

  -- Author  : YUVAL.TAL
  -- Created : 7/10/2020 4:27:49 PM
  -- Purpose : CHG0048217 oracle sfdc B2B sync

  PROCEDURE populate_events(err_buff OUT VARCHAR2,
		    err_code OUT VARCHAR2);
  FUNCTION is_ecomm_contact(p_sf_contact_id VARCHAR2) RETURN VARCHAR2;

END;
/
