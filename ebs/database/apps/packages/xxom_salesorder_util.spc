CREATE OR REPLACE PACKAGE xxom_salesorder_util AS

  ----------------------------------------------------------------------------
  --  name:          create_order
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------------
  --  purpose :      CHG0034837: Sales Order interface between Hybris
  --                 and Oracle Apps to handle order creation
  ----------------------------------------------------------------------------
  --  ver  date        name               desc
  --  1.0  20/03/2015  Debarati Banerjee  CHG0034837 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE create_order(p_header_rec      IN xxecom.xxom_order_header_rec_type,
		 p_line_tab        IN xxecom.xxom_order_line_tab_type,
		 p_debug_flag      IN VARCHAR2 DEFAULT 'N',
		 p_username        IN VARCHAR2,
		 p_err_code        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_order_number    OUT NUMBER,
		 p_order_header_id OUT NUMBER,
		 p_order_status    OUT VARCHAR2);

END xxom_salesorder_util;
/
