CREATE OR REPLACE PACKAGE xxoe_om_to_pa_intf_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: XXCN_OM_TO_PA_INTF_PKG    
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used for interfaced material transactions tied to order lines to 
--          pa_transaction_interface_all as well as marking the transactions as they are processed
--          on attribute15 of mtl_material_transactions.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/11/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------

  PROCEDURE process_mtl_trx(
     p_org_id             IN    NUMBER
  ,  p_order_number       IN    NUMBER
  ,  p_min_trx_date       IN    VARCHAR2 DEFAULT NULL
  ,  p_report_detail      IN    VARCHAR2 DEFAULT 'N'
  ,  x_return_status      OUT   VARCHAR2
  ,  x_return_msg         OUT   VARCHAR2
  );

  PROCEDURE ins_pa_transaction_intf(            
    x_errbuff               OUT   VARCHAR2,
    x_retcode               OUT   NUMBER,
    p_org_id                IN    NUMBER,
    p_order_number          IN    NUMBER,
    p_task_number           IN    VARCHAR2,
    p_expenditure_type      IN    VARCHAR2,                                   
    p_min_trx_date          IN    VARCHAR2,
    p_update_mat_trx        IN    VARCHAR2,
    p_update_mat_trx_only   IN    VARCHAR2,
    p_report_detail         IN    VARCHAR2
  );

END xxoe_om_to_pa_intf_pkg;
/

SHOW ERRORS
   

