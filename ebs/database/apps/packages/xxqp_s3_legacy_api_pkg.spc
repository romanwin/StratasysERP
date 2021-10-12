CREATE OR REPLACE PACKAGE xxqp_s3_legacy_api_pkg AS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_S3_LEGACY_API_PKG.pkb                                                     *
  * Parameters  :                                                                                *
  * Description : Package contains the procedures required for SSYS to call the open             *
  *                interface program.
                                                                                                 *
  *
  *                                                                                              *
  * Notes       : None
  * History     :                                                                                *
  * Creation Date : 20-Aug-2016
  * Created/Updated By  : TCS                                                                    *
  * Version: 1.0
  **********************************************************************************************/
  --
  -- Private variable declarations
  ---------------------------------------------
  PROCEDURE create_pricelist_insert_prc(errbuff      OUT VARCHAR2,
                                        retcode      OUT NUMBER,
                                        p_request_id IN NUMBER DEFAULT NULL,
                                        p_header_tbl IN xxqp_s3_legacy_int_pkg.p_header_tbl%TYPE,
                                        p_line_tbl   IN xxqp_s3_legacy_int_pkg.p_line_tbl%TYPE,
                                        p_attr_tbl   IN xxqp_s3_legacy_int_pkg.p_attr_tbl%TYPE,
                                        x_status     OUT VARCHAR2);

  PROCEDURE create_pricelist_update_prc(errbuff      OUT VARCHAR2,
                                        retcode      OUT NUMBER,
                                        p_request_id IN NUMBER DEFAULT NULL,
                                        p_header_tbl IN xxqp_s3_legacy_int_pkg.p_header_tbl%TYPE,
                                        p_line_tbl   IN xxqp_s3_legacy_int_pkg.p_line_tbl%TYPE,
                                        p_attr_tbl   IN xxqp_s3_legacy_int_pkg.p_attr_tbl%TYPE,
                                        x_status     OUT VARCHAR2);

  PROCEDURE price_create_prc(errbuf   OUT VARCHAR2,
                             retcode  OUT NUMBER,
                             x_status OUT VARCHAR2);
END xxqp_s3_legacy_api_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxqp_s3_legacy_api_pkg AS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_S3_LEGACY_API_PKG.pkb                                                     *
  * Parameters  :                                                                                *
  * Description : Package contains the procedures required for SSYS to call the open             *
  *                interface program.
                                                                                                 *
  *
  *                                                                                              *
  * Notes       : None
  * History     :                                                                                *
  * Creation Date : 20-Aug-2016
  * Created/Updated By  : TCS                                                                    *
  * Version: 1.0
  **********************************************************************************************/

  --------------------------------------------------------------------
  --  name:            create_pricelist_insert_prc
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   20-Aug-2016
  --------------------------------------------------------------------
  --  purpose :       To insert data in the interface table in case of insert
  --                  and inserting the pricelist line.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  20-Aug-2016    TCS        initial build
  --------------------------------------------------------------------
  PROCEDURE create_pricelist_insert_prc(errbuff      OUT VARCHAR2,
                                        retcode      OUT NUMBER,
                                        p_request_id IN NUMBER DEFAULT NULL,
                                        p_header_tbl IN xxqp_s3_legacy_int_pkg.p_header_tbl%TYPE,
                                        p_line_tbl   IN xxqp_s3_legacy_int_pkg.p_line_tbl%TYPE,
                                        p_attr_tbl   IN xxqp_s3_legacy_int_pkg.p_attr_tbl%TYPE,
                                        x_status     OUT VARCHAR2)
  
   IS
  
    l_price_creation_status VARCHAR2(10);
    l_orig_sys_pricing      VARCHAR2(50);
    l_item                  VARCHAR2(50);
    l_header_id             NUMBER;
    l_orig_sys_line_ref     VARCHAR2(50);
    l_list_line_id          NUMBER;
    /*  *********** Inserting records into open interface header table  ************** */
  
  BEGIN
    FOR i IN p_header_tbl.FIRST .. p_header_tbl.LAST LOOP
      BEGIN
        ---------------to populate the header id from legecy 
        BEGIN
          SELECT orig_system_header_ref
          INTO   l_header_id
          FROM   qp_list_headers_all
          WHERE  NAME = fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME');--p_header_tbl(i).NAME;
        EXCEPTION
          WHEN no_data_found THEN
            x_status := 'E';
            dbms_output.put_line('** no such price list header found   **');
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting pricelist header in procedure create_pricelist_insert_prc ** ' ||
                                    SQLERRM);
        END;
        ------------
        INSERT INTO qp_interface_list_headers
          (orig_sys_header_ref,
           list_type_code,
           NAME,
           active_flag,
           currency_code,
           currency_header,
           rounding_factor,
           source_lang,
           LANGUAGE,
           end_date_active,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          (l_header_id,
           p_header_tbl(i).list_type_code,
           fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME'),--p_header_tbl(i).NAME,
           p_header_tbl(i).active_flag,
           p_header_tbl(i).currency_code,
           p_header_tbl(i).currency_header,
           -2,
           p_header_tbl(i).source_lang,
           p_header_tbl(i).LANGUAGE,
           p_header_tbl(i).end_date_active,
           p_header_tbl(i).interface_action_code,
           p_header_tbl(i).process_flag,
           p_header_tbl(i).process_status_flag);
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          x_status := 'E';
          dbms_output.put_line('** no such price list header found   **' ||
                               SQLERRM);
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Header record in the interface table for the price list header ********* ' ||
                                  l_header_id);
          apps.fnd_file.put_line(apps.fnd_file.log, '** Error Message  ** ' ||
                                  SQLERRM);
      END;
    END LOOP;
  
    FOR i IN p_line_tbl.FIRST .. p_line_tbl.LAST LOOP
      BEGIN
        ---------------to populate the header id from legecy 
        BEGIN
          SELECT orig_system_header_ref
          INTO   l_header_id
          FROM   qp_list_headers_all
          WHERE  NAME = fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME'); --p_header_tbl(i).NAME;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('** no such price list header found   **');
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting pricelist header in procedure create_pricelist_insert_prc ** ' ||
                                    SQLERRM);
        END;
      
        INSERT INTO qp_interface_list_lines
          (orig_sys_line_ref,
           orig_sys_header_ref,
           list_line_type_code,
           start_date_active,
           end_date_active,
           arithmetic_operator,
           operand,
           primary_uom_flag,
           product_precedence,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          (p_line_tbl(i).list_line_id,
           l_header_id,
           p_line_tbl(i).list_line_type_code,
           nvl(p_line_tbl(i).start_date_active, SYSDATE),
           p_line_tbl(i).end_date_active,
           p_line_tbl(i).arithmetic_operator,
           p_line_tbl(i).operand,
           p_line_tbl(i).primary_uom_flag,
           p_line_tbl(i).product_precedence,
           'INSERT',
           p_line_tbl(i).process_flag,
           p_line_tbl(i).process_status_flag);
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          x_status := 'E';
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Line record in the interface table for the price list Line.The Inventory Item Id is ********* ' ||
                                  p_line_tbl(i).inventory_item_id ||
                                  SQLERRM);
        
          dbms_output.put_line('** Error Message  ** ');
      END;
    END LOOP;
  
    FOR i IN p_attr_tbl.FIRST .. p_attr_tbl.LAST LOOP
      BEGIN
      
        INSERT INTO qp_interface_pricing_attribs
          (orig_sys_pricing_attr_ref,
           orig_sys_line_ref,
           orig_sys_header_ref,
           product_attribute_context,
           product_attr_code,
           product_attr_val_disp,
           product_uom_code,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          ('QIPA' || p_attr_tbl(i).orig_sys_line_ref,
           p_attr_tbl(i).list_line_id,
           l_header_id,
           'ITEM',
           'INVENTORY_ITEM_ID',
           p_attr_tbl(i).product_attr_val_disp,
           p_attr_tbl(i).product_uom_code,
           'INSERT',
           'Y',
           'P');
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Pricing attribute record in the staging table for the price list Line.The orig_sys_line_ref is ********* ' ||
                                  p_line_tbl(i).orig_sys_line_ref ||
                                  SQLERRM);
        
          x_status := 'E';
      END;
    END LOOP;
    --   END LOOP;
    /************************************************************************************************
      
      *********** Calling the procedure to submit price list program  **************                                                               
    
    *************************************************************************************************/
  
    IF nvl(x_status, 'S') <> 'E' THEN
    
      price_create_prc(errbuff, retcode, l_price_creation_status);
    
    END IF;
  
    IF nvl(l_price_creation_status, 'S') <> 'E' THEN
    
      x_status := 'S';
    
    ELSE
    
      x_status := 'E';
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_status := 'E';
      fnd_file.put_line(fnd_file.log, 'Error code for pull_pricelist_insert_prc  :' ||
                         SQLCODE || '  ' || 'Error Msg :' ||
                         SQLERRM);
  END create_pricelist_insert_prc;
  --------------------------------------------------------------------
  --  name:            create_pricelist_update_prc
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   20-Aug-2016
  --------------------------------------------------------------------
  --  purpose :       To insert data in the interface table in case of update
  --                  and updating the pricelist line.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  20-Aug-2016    TCS        initial build
  --------------------------------------------------------------------
  PROCEDURE create_pricelist_update_prc(errbuff      OUT VARCHAR2,
                                        retcode      OUT NUMBER,
                                        p_request_id IN NUMBER DEFAULT NULL,
                                        p_header_tbl IN xxqp_s3_legacy_int_pkg.p_header_tbl%TYPE,
                                        p_line_tbl   IN xxqp_s3_legacy_int_pkg.p_line_tbl%TYPE,
                                        p_attr_tbl   IN xxqp_s3_legacy_int_pkg.p_attr_tbl%TYPE,
                                        x_status     OUT VARCHAR2)
  
   IS
  
    l_price_creation_status VARCHAR2(10);
    l_orig_sys_pricing      VARCHAR2(50);
    l_item                  VARCHAR2(50);
    l_header_id             NUMBER;
    l_orig_sys_line_ref     VARCHAR2(50);
    l_list_line_id          NUMBER;
  
  BEGIN
    FOR i IN p_header_tbl.FIRST .. p_header_tbl.LAST LOOP
      BEGIN
        ---------------to populate the header id from legecy 
        BEGIN
          SELECT orig_system_header_ref
          INTO   l_header_id
          FROM   qp_list_headers_all
          WHERE  NAME = fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME');-- p_header_tbl(i).NAME;
        EXCEPTION
          WHEN no_data_found THEN 
            dbms_output.put_line('** no such price list header found   **');
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting pricelist header   ** ' ||
                                    SQLERRM);
        END;
        ------------
        INSERT INTO qp_interface_list_headers
          (orig_sys_header_ref,
           list_type_code,
           NAME,
           active_flag,
           currency_code,
           currency_header,
           rounding_factor,
           source_lang,
           LANGUAGE,
           end_date_active,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          (l_header_id,
           p_header_tbl(i).list_type_code,
           fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME'), --p_header_tbl(i).NAME,
           p_header_tbl(i).active_flag,
           p_header_tbl(i).currency_code,
           p_header_tbl(i).currency_header,
           -2,
           p_header_tbl(i).source_lang,
           p_header_tbl(i).LANGUAGE,
           p_header_tbl(i).end_date_active,
           p_header_tbl(i).interface_action_code,
           p_header_tbl(i).process_flag,
           p_header_tbl(i).process_status_flag);
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          x_status := 'E';
          dbms_output.put_line('** no such price list header found   **' ||
                               SQLERRM);
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Header record in the interface table for the price list header .The orig_sys_header_ref is ********* ' ||
                                  p_header_tbl(i).orig_sys_header_ref ||
                                  SQLERRM);
        
      END;
    END LOOP;
  
    FOR i IN p_line_tbl.FIRST .. p_line_tbl.LAST LOOP
      BEGIN
        ---------------to populate the header id from legecy 
        BEGIN
          SELECT orig_system_header_ref
          INTO   l_header_id
          FROM   qp_list_headers_all
          WHERE  NAME = fnd_profile.value('XXQP_DEFAULT_INTERIM_PRICELIST_NAME'); --p_header_tbl(i).NAME;
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('** no such price list header found   **');
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting pricelist header   ** ' ||
                                    SQLERRM);
        END;
      
        /*-----to select already existing line id
        BEGIN
          SELECT orig_sys_line_ref,
                 list_line_id
          INTO   l_orig_sys_line_ref,
                 l_list_line_id
          FROM   qp_list_lines
          WHERE  orig_sys_line_ref =
                 to_char(p_line_tbl(i).orig_sys_line_ref);
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('** no such price list line id or orig system reference found   **' ||
                                 p_line_tbl(i).orig_sys_line_ref);
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          WHEN OTHERS THEN
            dbms_output.put_line('** error   **' || SQLERRM);
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting orig_sys_line_ref  ** ' ||
                                    SQLERRM);
        END;*/
        
        
        -----to select already existing line id
        BEGIN
          SELECT orig_sys_line_ref,
                 list_line_id
          INTO   l_orig_sys_line_ref,
                 l_list_line_id
          FROM   qp_list_lines
          WHERE  list_line_id =
                 to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', p_line_tbl(i).list_line_id));
        EXCEPTION
          WHEN no_data_found THEN
            dbms_output.put_line('** no such price list line id or orig system reference found   **' ||
                                 p_line_tbl(i).orig_sys_line_ref);
            apps.fnd_file.put_line(apps.fnd_file.log, '** no such price list header found   ** ' ||
                                    SQLERRM);
          WHEN OTHERS THEN
            dbms_output.put_line('** error   **' || SQLERRM);
            apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while selecting orig_sys_line_ref  ** ' ||
                                    SQLERRM);
        END;
      
        INSERT INTO qp_interface_list_lines
          (list_header_id,
           list_line_id,
           orig_sys_line_ref,
           orig_sys_header_ref,
           list_line_type_code,
           start_date_active,
           end_date_active,
           arithmetic_operator,
           operand,
           primary_uom_flag,
           product_precedence,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          (l_header_id,
           l_list_line_id,
           l_orig_sys_line_ref,
          -- p_line_tbl(i).orig_sys_line_ref,
           l_header_id,
           p_line_tbl(i).list_line_type_code,
           nvl(p_line_tbl(i).start_date_active, SYSDATE),           
           p_line_tbl(i).end_date_active,
           p_line_tbl(i).arithmetic_operator,
           p_line_tbl(i).operand,
           p_line_tbl(i).primary_uom_flag,
           p_line_tbl(i).product_precedence,
           'UPDATE',
           p_line_tbl(i).process_flag,
           p_line_tbl(i).process_status_flag);
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          x_status := 'E';
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Line record in the interface table for the price list Line ********* ' ||
                                  p_line_tbl(i).inventory_item_id ||
                                  SQLERRM);
        
      END;
    END LOOP;
  
    FOR i IN p_attr_tbl.FIRST .. p_attr_tbl.LAST LOOP
      BEGIN
        BEGIN
          SELECT orig_sys_pricing_attr_ref,
                 list_header_id
          INTO   l_orig_sys_pricing,
                 l_header_id
          FROM   qp_pricing_attributes
          WHERE  list_line_id =
                 to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', p_line_tbl(i).list_line_id));
        EXCEPTION
          WHEN no_data_found THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** no orig_sys_pricing_attr_ref found   ** ' ||
                                    SQLERRM);
          
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** error orig_sys_pricing_attr_ref select query   ** ' ||
                                    SQLERRM);
        END;
      
        INSERT INTO qp_interface_pricing_attribs
          (orig_sys_pricing_attr_ref,
           orig_sys_line_ref,
           orig_sys_header_ref,
           product_attribute_context,
           product_attr_code,
           product_attr_val_disp,
           product_uom_code,
           interface_action_code,
           process_flag,
           process_status_flag)
        VALUES
          (l_orig_sys_pricing,
          -- p_attr_tbl(i).orig_sys_line_ref,
          to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', p_line_tbl(i).list_line_id)),
           l_header_id,
           'ITEM',
           'INVENTORY_ITEM_ID',
           p_attr_tbl(i).product_attr_val_disp,
           p_attr_tbl(i).product_uom_code,
           'UPDATE',
           'Y',
           'P');
        x_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          apps.fnd_file.put_line(apps.fnd_file.log, '******* Unable to Insert Pricing attribute record in the staging table for the price list Line ********* ' ||
                                  'QILL-' || l_item ||
                                  SQLERRM);
        
          x_status := 'E';
      END;
    END LOOP;
    -- END LOOP;
    /************************************************************************************************
      
      *********** Calling the procedure to submit price list program  **************                                                               
    
    *************************************************************************************************/
  
    IF nvl(x_status, 's') <> 'e' THEN
    
      price_create_prc(errbuff, retcode, l_price_creation_status);
    
    END IF;
  
    IF nvl(l_price_creation_status, 's') <> 'e' THEN
    
      x_status := 's';
    
    ELSE
    
      x_status := 'e';
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_status := 'E';
      fnd_file.put_line(fnd_file.log, 'Error code for pull_pricelist_update_prc  :' ||
                         SQLCODE || '  ' || 'Error Msg :' ||
                         SQLERRM);
    
  END create_pricelist_update_prc;
  --------------------------------------------------------------------
  --  name:            price_create_prc
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   20-Aug-2016
  --------------------------------------------------------------------
  --  purpose :       To call standard program for pricelist line creation 
  --                  and update  
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  20-Aug-2016    TCS        initial build
  --------------------------------------------------------------------
  PROCEDURE price_create_prc(errbuf   OUT VARCHAR2,
                             retcode  OUT NUMBER,
                             x_status OUT VARCHAR2) IS
    ln_user_id           NUMBER;
    ln_responsibility_id fnd_concurrent_requests.responsibility_id%TYPE;
    ln_application_id    fnd_concurrent_requests.responsibility_application_id%TYPE;
    ln_request_id        fnd_concurrent_requests.request_id%TYPE;
    v_success            BOOLEAN;
    ln_phase             VARCHAR2(80) := NULL;
    ln_status            VARCHAR2(80) := NULL;
    ln_dev_phase         VARCHAR2(30) := NULL;
    ln_dev_status        VARCHAR2(30) := NULL;
    ln_message           VARCHAR2(240);
    ln_no_of_batch       NUMBER;
    l_org_id             NUMBER;
  
  BEGIN
  
    SELECT fnd_profile.VALUE('USER_ID')
    INTO   ln_user_id
    FROM   dual;
  
    SELECT fnd_profile.VALUE('RESPONSIBILITY_ID')
    INTO   ln_responsibility_id
    FROM   dual;
  
    SELECT fnd_profile.VALUE('APPLICATION_ID')
    INTO   ln_application_id
    FROM   dual;
  
    fnd_global.apps_initialize(ln_user_id, --1220,
                               ln_responsibility_id, -- 50740,
                               ln_application_id);
  
    ln_request_id := fnd_request.submit_request(application => 'QP', program => 'QPXVBLK', description => 'QP: Bulk import of Price List', start_time => SYSDATE, sub_request => FALSE, argument1 => 'PRL',
                                                --Entity
                                                argument2 => NULL, -- Entity Name
                                                argument3 => NULL, -- Process ID                                    
                                                argument4 => NULL, --Process Type
                                                argument5 => 'Y', --Process Parent?
                                                argument6 => 1, --No of Threads
                                                argument7 => 'N', argument8 => NULL, argument9 => 'N', -- Turn Debug on                                    
                                                argument10 => 'Y' --Enable duplicate Line Check                                    
                                                );
    COMMIT;
    dbms_output.put_line('Request id is : ' || ln_request_id);
    fnd_file.put_line(fnd_file.log, 'Request Id' || ln_request_id);
  
    IF ln_request_id <> 0 THEN
      --wait till the concurrent program submitted is completed
      v_success := fnd_concurrent.wait_for_request(request_id => ln_request_id,
                                                   -- REQUEST ID
                                                   INTERVAL => .1, phase => ln_phase,
                                                   -- PHASE DISPLYED ON SCREEN
                                                   status => ln_status,
                                                   -- STATUS DISPLAYED ON SCREEN
                                                   dev_phase => ln_dev_phase,
                                                   -- PHASE AVAILABLE FOR DEVELOPER
                                                   dev_status => ln_dev_status,
                                                   -- STATUS AVAILABLE FOR DEVELOPER
                                                   message => ln_message
                                                   -- EXECUTION MESSAGE
                                                   ); --OUT
    END IF;
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'v_req_id :  ' ||
                       to_char(ln_request_id));
    fnd_file.put_line(fnd_file.log, 'v_dphase :  ' || ln_dev_phase);
    fnd_file.put_line(fnd_file.log, 'v_dstatus:  ' || ln_dev_status);
    fnd_file.put_line(fnd_file.log, 'v_message:  ' || ln_message);
    x_status := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '**Error Ocurred In Procedure price_create_prc ** ' ||
                         SQLERRM);
      x_status := 'E';
  END price_create_prc;

END xxqp_s3_legacy_api_pkg;
/
