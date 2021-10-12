CREATE OR REPLACE PACKAGE xxgl_utils_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxgl_utils_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxgl_utils_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: GL Generic package
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  15/01/14  Ofer Suad       CR -1228 Add function to support location segment in disco reports
  --     1.2  11/03/15  Ofer Suad       CHG0034796- Add translation according to monthly average rates
  --     1.3  10/05/16  Ofer Suad       CHG0037996- Function get product line for Misclenious transactions
  --     1.4  01/02/17  Ofer Suad       CHG0040189- add function XXAP_GET_ITEM_PL  (called from SLA ) ,
  --                                                Use SLA to define product line segment for IPV PPV and WIP variances .
  ---------------------------------------------------------------------------
  g_session_cc_id NUMBER;

  TYPE g_rate_type IS TABLE OF gl_daily_rates.conversion_rate%TYPE INDEX BY VARCHAR2(15);
  TYPE g_period_rate_type IS TABLE OF g_rate_type INDEX BY VARCHAR2(15);
  g_avg_rate        g_rate_type;
  g_avg_period_rate g_period_rate_type;

  FUNCTION get_coa_id_from_inv_org(p_inv_org_id NUMBER,
		           x_org_id     OUT NUMBER) RETURN NUMBER;

  FUNCTION get_coa_id_from_ou(p_org_id NUMBER) RETURN NUMBER;

  PROCEDURE get_and_create_account(p_concat_segment      IN VARCHAR2,
		           p_coa_id              IN VARCHAR2,
		           p_app_short_name      IN VARCHAR2 DEFAULT NULL,
		           x_code_combination_id OUT NUMBER,
		           x_return_code         OUT VARCHAR2,
		           x_err_msg             OUT VARCHAR2);

  PROCEDURE get_and_create_account(segments              fnd_flex_ext.segmentarray,
		           p_coa_id              IN VARCHAR2,
		           p_app_short_name      IN VARCHAR2 DEFAULT NULL,
		           x_code_combination_id OUT NUMBER,
		           x_return_code         OUT VARCHAR2,
		           x_err_msg             OUT VARCHAR2);

  /* SAFE_GET_FORMAT_MASK-  slower version of GET_FORMAT_MASK
  **                         without WNPS pragma restrictions.
  **
  ** This version of GET_FORMAT_MASK uses slower,
  ** non-caching profiles functions to do its defaulting.  It runs
  ** about half the speed of GET_FORMAT_MASK, but it can
  ** be used in situations, like where clauses, in views, that
  ** GET_FORMAT_MASK cannot be used due to pragma restrictions.
  */
  FUNCTION safe_get_format_mask(currency_code         IN VARCHAR2,
		        field_length          IN NUMBER,
		        p_thousands_separator VARCHAR2 DEFAULT 'N',
		        p_percision           IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;
  PRAGMA RESTRICT_REFERENCES(safe_get_format_mask, WNDS, WNPS);

  FUNCTION format_mask(p_num_value           IN NUMBER,
	           currency_code         IN VARCHAR2,
	           field_length          IN NUMBER,
	           p_thousands_separator IN VARCHAR2 DEFAULT 'N',
	           p_percision           IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  FUNCTION get_flex_value_description(p_flex_value_id IN VARCHAR)
    RETURN VARCHAR2;

  --created by daniel katz on 17-nov-09 to get dff description according to value set id and value
  FUNCTION get_dff_value_description(p_dff_value_set_id IN NUMBER,
			 p_dff_value        IN VARCHAR)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_flex_Project_description
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2010
  --------------------------------------------------------------------
  --  purpose :        Function that return the project desc
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_flex_project_description(p_flex_value_id IN VARCHAR)
    RETURN VARCHAR2;

  FUNCTION set_session_cc_id_from_seg(p_cc_segments IN VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_session_cc_id_from_seg RETURN NUMBER;
  --------------------------------------------------------------------
  --  name:            replace_cc_segment
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   15/01/2014
  --------------------------------------------------------------------
  --  purpose :        Function to support replacing location segment by subledger accoutning in disco reports
  --------------------------------------------------------------------

  FUNCTION replace_cc_segment(p_inv_dist_id NUMBER,
		      p_segemt      VARCHAR2) RETURN VARCHAR2;

  -------------------------------------------------------------------
  --  name:            get_cust_location_segment
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   15/01/2014
  --------------------------------------------------------------------
  --  purpose :       unction to get location segment by subledger accoutning
  --------------------------------------------------------------------
  FUNCTION get_cust_location_segment(p_cust_state VARCHAR2,
			 p_site_seg   VARCHAR2) RETURN VARCHAR2;

  -------------------------------------------------------------------
  -- CHG0034796
  --  name:            set_avg_conversion_rate-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   11/03/2015
  --------------------------------------------------------------------
  --  purpose :       Function to set array of AVG conversion rate
  --------------------------------------------------------------------
  FUNCTION set_avg_conversion_rate(p_from_period VARCHAR2,
		           p_to_period   VARCHAR2) RETURN NUMBER;
  -------------------------------------------------------------------
  -- CHG0034796
  --  name:            get_avg_conversion_rate-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   11/03/2015
  --------------------------------------------------------------------
  --  purpose :       Function to get period  AVG conversion rate
  --------------------------------------------------------------------
  FUNCTION get_avg_conversion_rate(p_period        VARCHAR2,
		           p_func_currency VARCHAR2) RETURN NUMBER;
  -------------------------------------------------------------------
  -- CHG0037996
  --  name:            XXINV_GET_ITEM_PL-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   10/05/2016
  --------------------------------------------------------------------------
  --  purpose :       Function get product line for Misclenious transactions
  -------------------------------------------------------------------------
  FUNCTION xxinv_get_item_pl(p_event_id     NUMBER,
		     p_defualt_cogs NUMBER) RETURN NUMBER;

  -------------------------------------------------------------------
  -- CHG0040189
  --  name:            XXAP_GET_ITEM_PL-
  --  Revision:        1.3
  --  creation date:   10/05/2016

  --------------------------------------------------------------------------
  --  purpose :       Function get product line for IPV
  -------------------------------------------------------------------------
  FUNCTION xxap_get_item_pl(p_inv_dist_id     NUMBER,
		    p_defualt_account NUMBER) RETURN NUMBER;
END xxgl_utils_pkg;
/
