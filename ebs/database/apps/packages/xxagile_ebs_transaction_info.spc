CREATE OR REPLACE PACKAGE xxagile_ebs_transaction_info IS
   ---------------------------------------------------------------------------
   -- $Header: xxagile_ebs_transaction_info 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_ebs_transaction_info
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Agile procedures
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------

   g_create CONSTANT VARCHAR2(10) := 'CREATE';
   g_update CONSTANT VARCHAR2(10) := 'UPDATE';

   PROCEDURE get_transaction_info(p_item_name         IN VARCHAR2 DEFAULT NULL,
                                  p_operating_unit    IN VARCHAR2 DEFAULT NULL,
                                  p_old_lifecycle     IN VARCHAR2 DEFAULT NULL,
                                  p_cre_user_name     IN VARCHAR2,
                                  p_upd_user_name     IN VARCHAR2,
                                  px_cre_user_id      OUT NUMBER,
                                  px_upd_user_id      OUT NUMBER,
                                  px_transaction_type OUT VARCHAR2);

   PROCEDURE process_rollback(p_rollback VARCHAR2);

END xxagile_ebs_transaction_info;
/

