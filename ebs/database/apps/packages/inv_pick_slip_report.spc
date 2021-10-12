CREATE OR REPLACE PACKAGE inv_pick_slip_report AUTHID CURRENT_USER AS
  /* $Header: INVPKSLS.pls 120.0 2005/05/25 04:37:51 appldev noship $ */

  /*
  ** -------------------------------------------------------------------------
  ** Function:    chk_wms_install
  ** Description: Checks to see if WMS is installed
  **               This API should be used only for Move Order Pick Slip Report's
  **               Move order type value set.
  ** Input:       None
  ** Output:      none
  ** Returns:
  **      'TRUE' if WMS installed, else 'FALSE'
  **
  ** --------------------------------------------------------------------------
  */
  FUNCTION chk_wms_install(p_organization_id NUMBER)
    RETURN VARCHAR2;

  PROCEDURE run_detail_engine(
    x_return_status           OUT NOCOPY    VARCHAR2
  , p_org_id                                NUMBER
  , p_move_order_type                       NUMBER
  , p_move_order_from                       VARCHAR2
  , p_move_order_to                         VARCHAR2
  , p_source_subinv                         VARCHAR2
  , p_source_locator_id                     NUMBER
  , p_dest_subinv                           VARCHAR2
  , p_dest_locator_id                       NUMBER
  , p_sales_order_from                      VARCHAR2
  , p_sales_order_to                        VARCHAR2
  , p_freight_code                          VARCHAR2
  , p_customer_id                           NUMBER
  , p_requested_by                          NUMBER
  , p_date_reqd_from                        DATE
  , p_date_reqd_to                          DATE
  , p_plan_tasks                            BOOLEAN
  , p_pick_slip_group_rule_id               NUMBER
  , p_request_id                            NUMBER DEFAULT 1); /* Added p_request_id to fix Bug# 3869858 */

  FUNCTION print_pick_slip(
    p_organization_id         VARCHAR2
  , p_move_order_from         VARCHAR2 DEFAULT ''
  , p_move_order_to           VARCHAR2 DEFAULT ''
  , p_pick_slip_number_from   VARCHAR2 DEFAULT ''
  , p_pick_slip_number_to     VARCHAR2 DEFAULT ''
  , p_source_subinv           VARCHAR2 DEFAULT ''
  , p_source_locator          VARCHAR2 DEFAULT ''
  , p_dest_subinv             VARCHAR2 DEFAULT ''
  , p_dest_locator            VARCHAR2 DEFAULT ''
  , p_requested_by            VARCHAR2 DEFAULT ''
  , p_date_reqd_from          VARCHAR2 DEFAULT ''
  , p_date_reqd_to            VARCHAR2 DEFAULT ''
  , p_print_option            VARCHAR2 DEFAULT '99'
  , p_print_mo_type           VARCHAR2 DEFAULT '99'
  , p_sales_order_from        VARCHAR2 DEFAULT ''
  , p_sales_order_to          VARCHAR2 DEFAULT ''
  , p_ship_method_code        VARCHAR2 DEFAULT ''
  , p_customer_id             VARCHAR2 DEFAULT ''
  , p_auto_allocate           VARCHAR2 DEFAULT 'N'
  , p_plan_tasks              VARCHAR2 DEFAULT 'N'
  , p_pick_slip_group_rule_id VARCHAR2 DEFAULT ''
  ) RETURN NUMBER;

END inv_pick_slip_report;

 
/
