CREATE OR REPLACE PACKAGE xxpa_concur_interface_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: xxpa_concur_interface_pkg   
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used to take 'Concur' sourced GL lines and create entries for them
--          in pa_transaction_interface_all.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033409.
-- ---------------------------------------------------------------------------------------------

   PROCEDURE process_rows(                          
     x_errbuff                     OUT   VARCHAR2,
     x_retcode                     OUT   VARCHAR2,
     p_org_id                      IN    NUMBER,
     p_dep_org_id                  IN    NUMBER,
     p_gl_ledger_id                IN    NUMBER,
     p_cap_acct                    IN    VARCHAR2,
     p_non_trade_exp_acct          IN    VARCHAR2,
     p_trade_exp_acct              IN    VARCHAR2
   );

END xxpa_concur_interface_pkg;
/

SHOW ERRORS
   

