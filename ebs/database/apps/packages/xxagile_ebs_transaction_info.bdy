CREATE OR REPLACE PACKAGE BODY xxagile_ebs_transaction_info IS

   PROCEDURE get_transaction_info(p_item_name         IN VARCHAR2 DEFAULT NULL,
                                  p_operating_unit    IN VARCHAR2 DEFAULT NULL,
                                  p_old_lifecycle     IN VARCHAR2 DEFAULT NULL,
                                  p_cre_user_name     IN VARCHAR2,
                                  p_upd_user_name     IN VARCHAR2,
                                  px_cre_user_id      OUT NUMBER,
                                  px_upd_user_id      OUT NUMBER,
                                  px_transaction_type OUT VARCHAR2) IS
   
      CURSOR v_get_cre_user_id IS
         SELECT user_id FROM fnd_user fu WHERE fu.user_name = 'SYSADMIN'; --nvl(upper(replace(substr(p_cre_user_name,instr(p_cre_user_name,'(',1)+1,length(p_cre_user_name)),')')),'SYSADMIN');
      --upper(p_cre_user_name) ;
   
      CURSOR v_get_upd_user_id IS
         SELECT user_id FROM fnd_user fu WHERE fu.user_name = 'SYSADMIN'; --nvl(upper(replace(substr(p_upd_user_name,instr(p_upd_user_name,'(',1)+1,length(p_upd_user_name)),')')),'SYSADMIN');--upper(p_upd_user_name) ;
   
   BEGIN
   
      FOR rec_user IN v_get_cre_user_id LOOP
         px_cre_user_id := rec_user.user_id;
      END LOOP;
   
      FOR rec_user IN v_get_upd_user_id LOOP
         px_upd_user_id := rec_user.user_id;
      END LOOP;
   
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   PROCEDURE process_rollback(p_rollback VARCHAR2) IS
   BEGIN
      ROLLBACK;
   END;

BEGIN
   -- Initialization
   NULL;
END xxagile_ebs_transaction_info;
/

