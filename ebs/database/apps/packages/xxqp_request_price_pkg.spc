CREATE OR REPLACE PACKAGE xxqp_request_price_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxqp_request_price_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   10/03/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0034837 - Simulate Line and Order pricing by
  --                   calling Oracle Advanced Pricing engine via
  --                   API QP_PREQ_PUB.PRICE_REQUEST
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  10/03/2015  Diptasurjya Chatterjee(TCS)  CHG0034837 - initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This is a AUTONOMOUS TRANSACTION funtion which inserts data into the
  --          price request custom tables. This funtions inserts data for Pricing Session,
  --          Modifiers, Attributes and related modifiers into tables XX_QP_PRICEREQ_MODIFIERS,
  --          XX_QP_PRICEREQ_ATTRIBUTES, XX_QP_PRICEREQ_RELTD_ADJ.This procedure can be called
  --          with proper input parameters to insert data into pricing tables
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_pricereq_tables(p_session_details    IN xxecom.xxqp_pricereq_session_tab_type,
		           p_modifier_details   IN xxecom.xxqp_pricereq_mod_tab_type,
		           p_attribute_details  IN xxecom.xxqp_pricereq_attr_tab_type,
		           p_related_adjustment IN xxecom.xxqp_pricereq_reltd_tab_type,
		           p_pricing_server     IN VARCHAR2,
		           p_request_number     IN VARCHAR2 DEFAULT NULL,
		           x_status             OUT VARCHAR2,
		           x_status_message     OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure will be registered in a Concurrent program which will
  --          enable users to purge processed the Price Request custom tables.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE purge_pricereq_tables(x_retcode OUT NUMBER,
		          x_errbuf  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This Procedure calls the validation procedure and the price_order_batch
  --          or the price_single_line procedure based on the input p_pricing_phase value. This is
  --          main entry procedure for Price Request calls
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ecom_price_request(p_order_header       IN xxecom.xxqp_pricereq_header_tab_type,
		       p_item_lines         IN xxecom.xxqp_pricereq_lines_tab_type,
		       p_pricing_phase      IN VARCHAR2,
		       p_debug_flag         IN VARCHAR2 DEFAULT 'Y',
		       p_pricing_server     IN VARCHAR2 DEFAULT 'NORMAL',
		       x_session_details    OUT xxecom.xxqp_pricereq_session_tab_type,
		       x_order_details      OUT xxecom.xxqp_pricereq_header_tab_type,
		       x_line_details       OUT xxecom.xxqp_pricereq_lines_tab_type,
		       x_modifier_details   OUT xxecom.xxqp_pricereq_mod_tab_type,
		       x_attribute_details  OUT xxecom.xxqp_pricereq_attr_tab_type,
		       x_related_adjustment OUT xxecom.xxqp_pricereq_reltd_tab_type,
		       x_status             OUT VARCHAR2,
		       x_status_message     OUT VARCHAR2);

END xxqp_request_price_pkg;
/
