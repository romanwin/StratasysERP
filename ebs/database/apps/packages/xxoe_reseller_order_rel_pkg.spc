CREATE OR REPLACE PACKAGE xxoe_reseller_order_rel_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: XXOE_RESELLER_ORDER_REL_PKG
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This is a multi-purpose package used for processing commissions for resellers.  Its
--          functionality is as follows
--
--          1. We've created a custom table called xxoe_reseller_order_rel table.  This table is
--             used to store invoiced order lines down to the serial number level.  Our intent is
--             to store only System items.  Based on the system items for a paticular reseller, we
--             determine commission percentages for standard materials order for those systems, since
--             reseller is not stored on the standard materials orders.  We've also built a form
--             top of this table, so that the users essentially have the ability to split commissions
--             (XXOERESELLORDRREL) on one line between multiple resellers, which is not possible in
--             Oracle.  See the design doc for full details.
--
--          2. Users needed a way to establish a relationship between resellers and their customers
--             for commissions calculations on the commission statement (XXCN_RESELLER_STATEMENT)
--             XML Publisher report.  We've decided to use standard hz party relationship functionality
--             for this task.  However, commissions users needed a way to do this without affecting
--             other hz_relationships.  Initially, I was going down the route of extendeing the
--             hz_relationship OA form, but this got to be too cumbersome.  Since we're already
--             building a form for the task above, I've built a tab on the XXOERESELLORDRREL form,
--             which calls Oracle's standard hz_relationship API in the hz_relationship_api procedure
--             below.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- 1.1  03/10/2015  MMAZANET    CHG00XXXXX.  Added party_site_number and id to the g_reseller_order_rel_type
-- 1.2  10/06/2017  DCHATTERJEE CHG0041334 - Add function get_reseller_stmt_msg to retrieve message for
--                              split system transactions between reseller and channel partner
-- 1.3  12/04/2020  DCHATTERJEE CHG0047344 - New Logo and item commission category creation change
-- ---------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure is used to process trade in orders.  Essentially, when a trade in comes
--          comes in, we need to look for the original item (by serial number) and end date that
--          item so we don't account for it twice on the xxoe_reseller_order_rel table
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- 1.1  08/28/2014  MMAZANET    CHG0031576.  This was changed to accomodate commissions calculation.
--                              See the following procedure descriptions for further explanation.
--
--                              end_date_records
--                              process_return_credit_inv_only
--                              insert_xxoe_reseller_order_rel
--                              validate_resell_order_rel
--                              ins_xxoe_reseller_order_rel
--                              ins_xxoe_resell_order_rel_pub
--                              ins_xxoe_resell_order_rel_bulk
--                              upd_xxoe_resell_order_rel_pub
--                              upd_xxoe_reseller_order_rel
-- 1.2  05/02/2016  DCHATTERJEE CHG0038418 - Add global variables for new parameters to reseller statement report
--                              P_SEND_TO_RESELLER and P_BURST_FORMAT
-- 1.3  10/25/2016  DCHATTERJEE CHG0039544 - Add global variables for new parameters to reseller statement report
--                              P_ANALYST_FIRST_NAME, P_ANALYST_LAST_NAME, P_ANALYST_ROLE and P_ANALYST_PHONE
-- 1.4  03/22/2019  Diptasurjya CHG0041777 - add variable for P_RESELLER_ID, P_INACTIVE_SYSTEM
-- ---------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------

  P_ERROR                                VARCHAR2(1000);
  P_ORGANIZATION_ID                      NUMBER;
  P_VENDOR_ID                            NUMBER;
  P_AR_DATE_FROM                         VARCHAR2(25);
  P_AR_DATE_TO                           VARCHAR2(25);
  P_SUMMARY_EMAIL_TO                     VARCHAR2(240);
  P_SEND_EMAIL                           VARCHAR2(1);
  P_SEND_TO_RESELLER                     VARCHAR2(1);    -- CHG0038418
  P_BURST_FORMAT                         VARCHAR2(10);   -- CHG0038418
  P_EMAIL_FROM                           VARCHAR2(240);
  P_EMAIL_SUBJECT                        VARCHAR2(240);
  P_EMAIL_PARAGRAPH1                     VARCHAR2(240);
  P_EMAIL_PARAGRAPH2                     VARCHAR2(240);
  P_EMAIL_PARAGRAPH3                     VARCHAR2(240);
  P_EMAIL_SIGNATURE1                     VARCHAR2(240);
  P_EMAIL_SIGNATURE2                     VARCHAR2(240);
  P_INCLUDE_ON_ACCOUNT_CREDITS           VARCHAR2(1);
  P_INCLUDE_ON_ACCOUNT_RECEIPTS          VARCHAR2(1);
  P_INCLUDE_ON_UNAPPLIED_RCPTS           VARCHAR2(1);
  P_INCLUDE_ON_UNCLEARED_RCPTS           VARCHAR2(1);
  P_CURRENCY                             VARCHAR2(3);
  P_DEBUG_GET_AR_BAL                     VARCHAR2(1);
  P_TRACE_GET_AR_BAL                     VARCHAR2(1);
  P_TYPE                                 VARCHAR2(30);
  P_ANALYST_FIRST_NAME                   VARCHAR2(120);  -- CHG0039544
  P_ANALYST_LAST_NAME                    VARCHAR2(120);  -- CHG0039544
  P_ANALYST_ROLE                         VARCHAR2(120);  -- CHG0039544
  P_ANALYST_PHONE                        VARCHAR2(120);  -- CHG0039544
  P_RESELLER_ID                          NUMBER;         -- CHG0041777
  P_INACTIVE_SYSTEM                      VARCHAR2(10);   -- CHG0041777

  TYPE g_reseller_order_rel_type IS RECORD(
    system_rec          xxoe_reseller_order_rel_intf%ROWTYPE,
    creation_action     xxoe_reseller_order_rel.creation_action%TYPE,
    update_flag         VARCHAR2(1),
    total_revenue_pct   NUMBER
  );

  FUNCTION before_report
  RETURN BOOLEAN;

  FUNCTION after_report
  RETURN BOOLEAN;

  FUNCTION before_system_report
  RETURN BOOLEAN;

  PROCEDURE is_duplicate_serial_number(
     p_load                  IN    g_reseller_order_rel_type
  ,  x_duplicate_serial_flag OUT   VARCHAR2
  ,  x_return_message        OUT   VARCHAR2
  ,  x_return_status         OUT   VARCHAR2
  );

  PROCEDURE load_systems(
    errbuff         OUT VARCHAR2,
    retcode         OUT NUMBER,
    p_load_type     IN VARCHAR2,
    p_batch_name    IN VARCHAR2,
    p_file_location IN VARCHAR2,
    p_file_name     IN VARCHAR2
  );

  PROCEDURE handle_update(
    p_load                     IN OUT g_reseller_order_rel_type,
    p_from_form                IN VARCHAR2 DEFAULT 'N',
    x_return_message           OUT VARCHAR2,
    x_return_status            OUT VARCHAR2
  );

  PROCEDURE ins_xxoe_resell_order_rel_pub(
     p_load                     IN OUT  g_reseller_order_rel_type
  ,  p_validate_all             IN      VARCHAR2  DEFAULT 'N'
  ,  x_return_message           OUT     VARCHAR2
  ,  x_return_status            OUT     VARCHAR2
  );

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Function to retrieve message from FND message XXCN_RESELLER_STMT_SPLIT_TEXT
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  10/06/2017  DCHATTERJEE    CHG0041334 - Initial build
  -- ---------------------------------------------------------------------------------------------
  FUNCTION get_reseller_stmt_msg return varchar2;

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to create item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE create_item_comm_cat_assn(p_category_id number,
                                     p_category_set_id number,
                                     p_inventory_item_id number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2);

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to update item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE update_item_comm_cat_assn(p_category_id IN number,
                                     p_category_set_id IN number,
                                     p_inventory_item_id IN number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2);

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to delete item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE delete_item_comm_cat_assn(p_category_id IN number,
                                     p_category_set_id IN number,
                                     p_inventory_item_id IN number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2);
END xxoe_reseller_order_rel_pkg;
/
