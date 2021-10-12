CREATE OR REPLACE PACKAGE xxar_intercompany_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: xxar_intercompany_pkg    
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This code is used to allow INTERCOMPANY orders to invoice as the shipments are 
--          received.  This is accomplished manipulating the orders in the ra_interface_lines
--          table.  See details in the process_intercompany_invoices.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
-- ---------------------------------------------------------------------------------------------

  TYPE xxoe_order_numbers_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

  FUNCTION has_receipt_been_invoiced(
    p_receiving_trx_id        NUMBER,
    p_order_line_id           NUMBER
  )
  RETURN VARCHAR2;

  PROCEDURE process_intercompany_invoices(
    p_order_numbers_tbl     IN  xxoe_order_numbers_type,
    p_organization_id       IN  NUMBER,
    p_show_success_flag     IN  VARCHAR2,
    x_return_message        OUT VARCHAR2,
    x_return_status         OUT VARCHAR2
  );
  
END xxar_intercompany_pkg;
/

SHOW ERRORS
