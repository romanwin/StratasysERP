CREATE OR REPLACE PACKAGE BODY xxobjt_interface_check AS
  ---------------------------------------------------------------------------
  -- $Header: XX_AP_INVOICE_IMPORT   $
  ---------------------------------------------------------------------------
  -- Package: XX_AP_INVOICE_IMPORT
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: CUST 641 CombTas Interfaces
  --          CR681: generic procerdures for invoice interface data check and import
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.2.13   yuval tal        initial Build
  ----------------------------------------------------

  -----------------------------------------------------
  -- get_err_string
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  --     1.1  30.5.13    YUVAL TAL      CHANGE LOGIC 
  FUNCTION get_err_string(p_group_id   NUMBER,
                          p_table_name VARCHAR2,
                          p_id         NUMBER) RETURN VARCHAR2 IS
    l_err_message VARCHAR2(3000);
  BEGIN
    SELECT listagg(e.description, ',') within GROUP(ORDER BY group_id)
      INTO l_err_message
      FROM xxobjt_interface_errors e
     WHERE e.table_name = p_table_name
       AND group_id = p_group_id
       AND e.obj_id = p_id
     GROUP BY table_name, group_id;
    RETURN l_err_message;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------------------------------
  -- insert_error
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build

  PROCEDURE delete_err_log(p_table_name VARCHAR2,
                           p_group_id   NUMBER,
                           p_id         NUMBER) IS
  BEGIN
  
    DELETE FROM xxobjt_interface_errors t
     WHERE table_name = p_table_name
       AND t.group_id = p_group_id
       AND obj_id = p_id;
  
    COMMIT;
  END;

  ----------------------------------------------------
  -- insert_error
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build

  PROCEDURE insert_error(p_err_rec xxobjt_interface_errors%ROWTYPE) IS
  BEGIN
  
    INSERT INTO xxobjt_interface_errors t
      (table_name,
       obj_id,
       group_id,
       check_id,
       description,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login)
    VALUES
      (p_err_rec.table_name,
       p_err_rec.obj_id,
       p_err_rec.group_id,
       p_err_rec.check_id,
       p_err_rec.description,
       NULL,
       NULL,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.login_id);
  
    COMMIT;
  END;

  ----------------------------------------------------
  -- handle_check
  ----------------------------------------------------
  -- p_table_name : interface table being checked
  -- p_source     : source of checking
  -- p_id         : pk id for dynamic sql
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  PROCEDURE handle_check(p_group_id     NUMBER,
                         p_table_name   VARCHAR2,
                         p_table_source VARCHAR2,
                         p_check_id     NUMBER DEFAULT NULL,
                         p_id           NUMBER, -- pk id for dynamic sql
                         p_err_code     OUT NUMBER,
                         p_err_message  OUT VARCHAR2) IS
  
    -- Check list
    CURSOR c_check IS
      SELECT k.check_order, k.check_id, c.check_sql, c.table_name
        FROM xxobjt_interface_source_chk k, xxobjt_interface_chk c
       WHERE c.check_id = k.check_id
         AND k.table_source = p_table_source
         AND c.table_name = p_table_name
         AND k.check_id = nvl(p_check_id, k.check_id)
       ORDER BY k.check_order;
  
    l_err_code    NUMBER;
    l_err_message VARCHAR2(1000);
    l_err_rec     xxobjt_interface_errors%ROWTYPE;
    my_exception EXCEPTION;
  
  BEGIN
    l_err_code    := 0;
    p_err_code    := 0;
    l_err_message := '';
  
    delete_err_log(p_table_name, p_group_id, p_id);
  
    FOR i IN c_check LOOP
      BEGIN
        l_err_code    := 0;
        l_err_message := NULL;
      
        EXECUTE IMMEDIATE (i.check_sql)
          USING p_id, OUT l_err_code, OUT l_err_message;
        -- save error
        IF l_err_code = 1 THEN
        
          l_err_rec.table_name  := p_table_name;
          l_err_rec.obj_id      := p_id;
          l_err_rec.description := l_err_message;
          l_err_rec.group_id    := p_group_id;
          l_err_rec.check_id    := i.check_id;
          insert_error(l_err_rec);
          RAISE my_exception;
        END IF;
      
      EXCEPTION
        WHEN my_exception THEN
          NULL;
        WHEN OTHERS THEN
          l_err_message := substr(SQLERRM, 1, 2000);
          p_err_code    := 1;
        
          l_err_rec.table_name  := p_table_name;
          l_err_rec.obj_id      := p_id;
          l_err_rec.description := l_err_message;
          l_err_rec.group_id    := p_group_id;
          l_err_rec.check_id    := i.check_id;
          insert_error(l_err_rec);
        
      END;
      p_err_code := greatest(p_err_code, l_err_code);
    END LOOP;
    IF p_err_code = 1 THEN
      p_err_message := 'Errors Exists for id=' || p_id || ' Table Name=' ||
                       p_table_name;
    END IF;
  END;
  ----------------------------------------------------
  -- GET_CHECK_NAME
  ----------------------------------------------------

  -- p_check_id
  -- Return check name for check_id
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  FUNCTION get_check_name(p_check_id NUMBER) RETURN VARCHAR2 IS
    l_check_name xxobjt_interface_chk.check_name%TYPE;
  BEGIN
  
    SELECT check_name
      INTO l_check_name
      FROM xxobjt_interface_chk t
     WHERE t.check_id = p_check_id;
  
    RETURN l_check_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------------------------------
  -- check_role_sql
  ----------------------------------------------------

  -- in : p_sql : dynamic sql with  IN l_id, OUT l_err_code, OUT l_err_msg
  --
  ----------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  PROCEDURE check_sql(p_sql VARCHAR2) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(1000);
    l_role     VARCHAR2(50);
  BEGIN
    EXECUTE IMMEDIATE p_sql
      USING 1, OUT l_err_code, OUT l_err_msg;
  
  END;

  ------------------------------------------------------------
  -- assign_check
  --
  -- connect check to source
  ------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  -------------------------------------------------------------
  PROCEDURE assign_check(p_check_id NUMBER, p_table_source VARCHAR2) IS
  BEGIN
  
    INSERT INTO xxobjt_interface_source_chk
      (check_id,
       check_order,
       table_name,
       table_source,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login)
      SELECT check_id,
             check_order,
             table_name,
             p_table_source,
             NULL, --last_update_date,
             NULL, --last_updated_by,
             SYSDATE,
             fnd_global.user_id,
             last_update_login
      
        FROM xxobjt_interface_chk chk
       WHERE chk.check_id = p_check_id;
  
  END;

  ------------------------------------------------------------
  -- get_check_sql
  --
  -- get sql code for check_id
  ------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  -------------------------------------------------------------
  FUNCTION get_check_sql(p_check_id NUMBER) RETURN VARCHAR2 IS
  
    l_check_sql xxobjt_interface_chk.check_sql%TYPE;
  BEGIN
  
    SELECT check_sql
      INTO l_check_sql
      FROM xxobjt_interface_chk t
     WHERE t.check_id = p_check_id;
  
    RETURN l_check_sql;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ------------------------------------------------------------
  -- is_check_assigned
  ------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  -------------------------------------------------------------
  FUNCTION is_check_assigned(p_check_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT 1
      INTO l_tmp
      FROM xxobjt_interface_source_chk t
     WHERE t.check_id = p_check_id;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
    
    WHEN OTHERS THEN
      RETURN 1;
  END;
END;
/
