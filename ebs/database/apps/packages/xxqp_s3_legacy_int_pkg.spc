CREATE OR REPLACE PACKAGE xxqp_s3_legacy_int_pkg AS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_S3_LEGACY_INT_PKG.spc                                                     *
  * Parameters  :                                                                                *
  * Description : Package contains the procedures required to call the open                      *
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
  TYPE qp_header_rec IS TABLE OF qp_interface_list_headers%ROWTYPE INDEX BY BINARY_INTEGER;
  p_header_tbl qp_header_rec;

  TYPE qp_line_rec IS TABLE OF qp_interface_list_lines%ROWTYPE INDEX BY BINARY_INTEGER;
  p_line_tbl qp_line_rec;

  TYPE qp_attr_rec IS TABLE OF qp_interface_pricing_attribs%ROWTYPE INDEX BY BINARY_INTEGER;
  p_attr_tbl qp_attr_rec;
  -------------------------------
  PROCEDURE pricelist_load_prc(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER);
  --------------------------------
  PROCEDURE update_status(errbuff OUT VARCHAR2,
                          retcode OUT NUMBER);
END xxqp_s3_legacy_int_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxqp_s3_legacy_int_pkg AS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_S3_LEGACY_INT_PKG.bdy                                                     *
  * Parameters  :                                                                                *
  * Description : Package contains the procedures required to call the open                      *
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
  -- Private variable declarations   
  g_request_id          NUMBER;
  g_entity_name         VARCHAR2(50);
  g_entity_id           NUMBER;
  g_orig_sytem_line_ref VARCHAR2(200);
  g_event_id            NUMBER;
  --------------------------------------------------------------------
  --  name:            pricelist_load_prc
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   20-Aug-2016
  --------------------------------------------------------------------
  --  purpose : This procedure will collect the price list detials from  s3 environment and will create or update those
  --            price list line details into Legacy environment through standard program
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  20-Aug-2016    TCS        initial build
  --------------------------------------------------------------------
  PROCEDURE pricelist_load_prc(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER) IS
  
    TYPE qp_pricelist_val_rec IS TABLE OF xxqp_pricelist_legecy_int_v%ROWTYPE INDEX BY BINARY_INTEGER;
    l_price_list_tab qp_pricelist_val_rec;
  
    l_header_line_index NUMBER := 1;
    l_line_index        NUMBER := 1;
    l_attr_index        NUMBER := 1;
    l_status            VARCHAR2(5);
    l_return_status     VARCHAR2(5);
    l_list_line_id      NUMBER;
    l_out_status        VARCHAR2(20);
    l_cref_list_line_id NUMBER;
    l_orig_sys_line_ref VARCHAR2(50);
    x_err_code          VARCHAR2(100);
    x_err_message       VARCHAR2(2000);
    l_legacy_id         VARCHAR2(100);
    l_true              VARCHAR2(5);
  BEGIN
    BEGIN
    
      SELECT * BULK COLLECT
      INTO   l_price_list_tab
      FROM   xxqp_pricelist_legecy_int_v
      WHERE  1 = 1     
      AND    rownum <= p_batch_size
      ORDER  BY last_update_date ASC;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
      WHEN OTHERS THEN
        p_retcode := 2;
        fnd_file.put_line(fnd_file.log, 'Unexpected error 0....' || SQLERRM);
      
    END;
  
    g_request_id := fnd_global.conc_request_id;
  
    apps.fnd_file.put_line(apps.fnd_file.log, '******* IRequest ID is ********* ' ||
                            g_request_id);
    FOR i IN l_price_list_tab.FIRST .. l_price_list_tab.LAST LOOP
      BEGIN
        INSERT INTO xxqp_pricelist_stg
          (list_line_id,
           list_header_id,
           list_line_type_code,
           orig_sys_line_ref,
           orig_sys_header_ref,
           orig_sys_pricing_attr_ref,
           product_attr_value,
           start_date_active,
           end_date_active,
           arithmetic_operator,
           operand,
           primary_uom_flag,
           product_precedence,
           event_id,
           target_name,
           event_status,
           entity_name,
           entity_id,
           list_type_code,
           NAME,
           description,
           active_flag,
           currency_code,
           currency_header,
           rounding_factor,
           start_date_active_hdr,
           end_date_active_hdr,
           primary_uom_code,
           segment1,
           request_id,
           status,
           error_msg,
           last_update_date,
           creation_date)
        
        VALUES
          (l_price_list_tab(i).list_line_id,
           l_price_list_tab(i).list_header_id,
           l_price_list_tab(i).list_line_type_code,
           l_price_list_tab(i).orig_sys_line_ref,
           l_price_list_tab(i).orig_sys_header_ref,
           l_price_list_tab(i).orig_sys_pricing_attr_ref,
           l_price_list_tab(i).product_attr_value,
           l_price_list_tab(i).start_date_active,
           l_price_list_tab(i).end_date_active,
           l_price_list_tab(i).arithmetic_operator,
           l_price_list_tab(i).operand,
           l_price_list_tab(i).primary_uom_flag,
           l_price_list_tab(i).product_precedence,
           l_price_list_tab(i).event_id,
           l_price_list_tab(i).target_name,
           l_price_list_tab(i).status,
           l_price_list_tab(i).entity_name,
           l_price_list_tab(i).entity_id,
           l_price_list_tab(i).list_type_code,
           l_price_list_tab(i).NAME,
           l_price_list_tab(i).description,
           l_price_list_tab(i).active_flag,
           l_price_list_tab(i).currency_code,
           l_price_list_tab(i).currency_header,
           l_price_list_tab(i).rounding_factor,
           l_price_list_tab(i).start_date_active_hdr,
           l_price_list_tab(i).end_date_active_hdr,
           l_price_list_tab(i).product_uom_code,
           l_price_list_tab(i).segment1,
           g_request_id,
           'NEW',
           x_err_message,
           SYSDATE,
           SYSDATE);
        dbms_output.put_line('data inserted on stagging table :' ||
                             SQLCODE || '  ' ||
                             'data inserted on stagging table :' ||
                             SQLERRM);
        COMMIT;
      
        p_header_tbl(l_header_line_index).orig_sys_header_ref := l_price_list_tab(i)
                                                                .orig_sys_header_ref;
        p_header_tbl(l_header_line_index).list_type_code := l_price_list_tab(i)
                                                           .list_type_code;
        p_header_tbl(l_header_line_index).NAME := l_price_list_tab(i).NAME;
        p_header_tbl(l_header_line_index).active_flag := l_price_list_tab(i)
                                                        .active_flag;
        p_header_tbl(l_header_line_index).currency_code := l_price_list_tab(i)
                                                          .currency_code;
        p_header_tbl(l_header_line_index).currency_header := 'Global Conversion to all';
        p_header_tbl(l_header_line_index).rounding_factor := l_price_list_tab(i)
                                                            .rounding_factor;
        p_header_tbl(l_header_line_index).source_lang := 'US';
        p_header_tbl(l_header_line_index).LANGUAGE := 'US';
        p_header_tbl(l_header_line_index).start_date_active := l_price_list_tab(i)
                                                              .start_date_active_hdr;
        p_header_tbl(l_header_line_index).end_date_active := l_price_list_tab(i)
                                                            .end_date_active_hdr;
        p_header_tbl(l_header_line_index).interface_action_code := 'UPDATE';
        p_header_tbl(l_header_line_index).process_flag := 'Y';
        p_header_tbl(l_header_line_index).process_status_flag := 'P';
        l_header_line_index := l_header_line_index + 1;
        p_line_tbl(l_line_index).list_header_id := l_price_list_tab(i)
                                                  .list_header_id;
        p_line_tbl(l_line_index).list_line_id := l_price_list_tab(i)
                                                .list_line_id;
        p_line_tbl(l_line_index).orig_sys_line_ref := l_price_list_tab(i)
                                                     .orig_sys_line_ref;
        p_line_tbl(l_line_index).orig_sys_header_ref := l_price_list_tab(i)
                                                       .orig_sys_header_ref;
        p_line_tbl(l_line_index).list_line_type_code := l_price_list_tab(i)
                                                       .list_line_type_code;
        p_line_tbl(l_line_index).inventory_item_id := l_price_list_tab(i)
                                                     .product_attr_value;
        p_line_tbl(l_line_index).start_date_active := l_price_list_tab(i)
                                                     .start_date_active;
        p_line_tbl(l_line_index).end_date_active := l_price_list_tab(i)
                                                   .end_date_active;
        p_line_tbl(l_line_index).arithmetic_operator := l_price_list_tab(i)
                                                       .arithmetic_operator;
        p_line_tbl(l_line_index).operand := l_price_list_tab(i).operand;
        p_line_tbl(l_line_index).primary_uom_flag := l_price_list_tab(i)
                                                    .primary_uom_flag;
        p_line_tbl(l_line_index).product_precedence := l_price_list_tab(i)
                                                      .product_precedence;
        p_line_tbl(l_line_index).process_flag := 'Y';
        p_line_tbl(l_line_index).process_status_flag := 'P';
        l_line_index := l_line_index + 1;
      
        p_attr_tbl(l_attr_index).orig_sys_line_ref := l_price_list_tab(i)
                                                     .orig_sys_line_ref;
        p_attr_tbl(l_attr_index).orig_sys_header_ref := l_price_list_tab(i)
                                                       .orig_sys_header_ref;
        p_attr_tbl(l_attr_index).product_attr_val_disp := l_price_list_tab(i)
                                                         .segment1;
        p_attr_tbl(l_attr_index).product_uom_code := l_price_list_tab(i)
                                                    .product_uom_code;
        p_attr_tbl(l_attr_index).orig_sys_pricing_attr_ref := l_price_list_tab(i)
                                                             .orig_sys_pricing_attr_ref;
        l_attr_index := l_attr_index + 1;
        g_entity_id := l_price_list_tab(i).entity_id;
        g_orig_sytem_line_ref := to_char(l_price_list_tab(i)
                                         .orig_sys_line_ref);
        g_entity_name := l_price_list_tab(i).entity_name;
        g_event_id := l_price_list_tab(i).event_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_status := 'E';
          dbms_output.put_line('Others Error code :' || SQLCODE || '  ' ||
                               'Error Msg :' || SQLERRM ||
                               dbms_utility.format_error_backtrace);
          fnd_file.put_line(fnd_file.log, 'Error while inserting data in the table types :' ||
                             SQLCODE || '  ' || 'Error Msg :' ||
                             SQLERRM ||
                             dbms_utility.format_error_backtrace);
          p_retcode := 2;
      END;
      /* ----item number check--
      BEGIN
      
        SELECT 'Y'
        INTO   l_true
        FROM   qp_pricing_attributes a,
               qp_list_lines  c,
               qp_list_headers d,
               mtl_system_items_b    b
        WHERE  a.product_attr_value = to_char(b.inventory_item_id)
        AND    b.segment1 = l_price_list_tab(i)
        .segment1
        AND c.list_line_id = a.list_line_id
        AND d.list_header_id = c.list_header_id 
       AND d.NAME = l_price_list_tab(i).NAME
        AND    rownum = 1;
      
      EXCEPTION
        WHEN no_data_found THEN
          dbms_output.put_line('** no such price list header found   **');
          apps.fnd_file.put_line(apps.fnd_file.log, '** no such item found in legecy   ** ' ||
                                  SQLERRM);
        
        WHEN OTHERS THEN
          apps.fnd_file.put_line(apps.fnd_file.log, '** error occured while checking if item number already exist in price list line ** ' ||
                                  SQLERRM);
      END;*/
      --END LOOP;
      -----Checking Cross Reference----
     -- l_list_line_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', to_number(g_orig_sytem_line_ref)));
      
      l_list_line_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', l_price_list_tab(i).list_line_id));
      
      apps.fnd_file.put_line(apps.fnd_file.log, '*******legecy list line id *********' ||
                              l_list_line_id);
      IF l_list_line_id IS NULL /*AND l_true IS NULL*/
       THEN
        /************************************************************************************************
          
          *********** Calling  package to insert data in price list interface table and craete price list line**************                                                               
        
        *************************************************************************************************/
      
        BEGIN
          apps.fnd_file.put_line(apps.fnd_file.log, 'Calling pull_pricelist_insert_prc to insert data in interface table ');
        
          xxqp_s3_legacy_api_pkg.create_pricelist_insert_prc(errbuff => p_errbuf, retcode => p_retcode, p_request_id => p_errbuf, p_header_tbl => p_header_tbl, p_line_tbl => p_line_tbl, p_attr_tbl => p_attr_tbl, x_status => l_return_status);
          apps.fnd_file.put_line(apps.fnd_file.log, 'l_return_status' ||
                                  l_return_status);
          IF l_return_status = 'E' THEN
            fnd_file.put_line(fnd_file.log, 'data insertion in interface table went into error..............' ||
                               l_return_status);
            l_status := 'E';
          
            UPDATE xxqp_pricelist_stg xps
            SET    status    = 'E',
                   error_msg = 'Interface Processing Error'
            WHERE  NOT EXISTS (SELECT 'XX'
                    FROM   qp_pricing_attributes
                    WHERE  orig_sys_pricing_attr_ref =
                           'QIPA' || l_price_list_tab(i).orig_sys_line_ref)
            AND    EXISTS
             (SELECT 'XX'
                    FROM   qp_interface_pricing_attribs
                    WHERE  list_line_id =
                           l_price_list_tab(i).list_line_id);
          ELSE
          
            UPDATE xxqp_pricelist_stg xps
            SET    status = 'S'
            WHERE  EXISTS (SELECT 'XX'
                    FROM   qp_pricing_attributes
                    WHERE  orig_sys_line_ref =
                           to_char(l_price_list_tab(i).list_line_id));
          
            /************************************************************************************************
            *********** Calling the procedure to update the status in the event table  **************                                                               
            *************************************************************************************************/
            BEGIN
            
              update_status(p_errbuf, p_retcode);
            
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log, 'Error in Calling of update status.............');
                fnd_file.put_line(fnd_file.log, 'Error code :' || SQLCODE || '  ' ||
                                   'Error Msg :' || SQLERRM ||
                                   dbms_utility.format_error_backtrace);
              
            END;
          END IF;
        
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Error in Calling of Calling pull_pricelist_insert_prc..............');
            fnd_file.put_line(fnd_file.log, 'Error code :' || SQLCODE || '  ' ||
                               'Error Msg :' || SQLERRM ||
                               dbms_utility.format_error_backtrace);
            l_status := 'E';
        END; -----insert price list ends..
      ELSE
        /************************************************************************************************
          
          *********** Calling  package to insert data in price list interface table when update **************                                                               
        
        *************************************************************************************************/
        fnd_file.put_line(fnd_file.log, 'calling the update procedure..............');
        BEGIN
        
          xxqp_s3_legacy_api_pkg.create_pricelist_update_prc(errbuff => p_errbuf, retcode => p_retcode, p_request_id => p_errbuf, p_header_tbl => p_header_tbl, p_line_tbl => p_line_tbl, p_attr_tbl => p_attr_tbl, x_status => l_return_status);
        
          IF l_return_status = 'E' THEN
            fnd_file.put_line(fnd_file.log, 'data insertion in interface table went into error..............');
            l_status := 'E';
            UPDATE xxqp_pricelist_stg xps
            SET    status    = 'E',
                   error_msg = 'Interface Processing Error'
            WHERE  NOT EXISTS (SELECT 'XX'
                    FROM   qp_pricing_attributes
                    WHERE  list_line_id =
                           to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', l_price_list_tab(i).list_line_id)))
            AND    EXISTS
             (SELECT 'XX'
                    FROM   qp_interface_pricing_attribs
                    WHERE  list_line_id =
                           to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', l_price_list_tab(i).list_line_id)));
          ELSE
          
            UPDATE xxqp_pricelist_stg xps
            SET    status = 'S'
            WHERE  EXISTS (SELECT 'XX'
                    FROM   qp_pricing_attributes
                    WHERE  list_line_id =
                           to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', l_price_list_tab(i).list_line_id)));
          
            /************************************************************************************************
              
              *********** Calling the procedure to update the status in the event table  **************                                                               
            
            *************************************************************************************************/
            BEGIN
            
              update_status(p_errbuf, p_retcode);
            
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log, 'Error in Calling of update status.............');
                fnd_file.put_line(fnd_file.log, 'Error code :' || SQLCODE || '  ' ||
                                   'Error Msg :' || SQLERRM ||
                                   dbms_utility.format_error_backtrace);
              
            END;
          END IF;
        
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Error in Calling of create_pricelist_update_prc..............');
            fnd_file.put_line(fnd_file.log, 'Error code :' || SQLCODE || '  ' ||
                               'Error Msg :' || SQLERRM ||
                               dbms_utility.format_error_backtrace);
            l_status := 'E';
        END;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in Calling of PRICELIST_LOAD_PRC..............');
      fnd_file.put_line(fnd_file.log, 'Error code :' || SQLCODE || '  ' ||
                         'Error Msg :' || SQLERRM ||
                         dbms_utility.format_error_backtrace);
      l_status := 'E';
    
  END pricelist_load_prc;

  --------------------------------------------------------------------
  --  name:            update_status
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   20-Aug-2016
  --------------------------------------------------------------------
  --  purpose : This procedure will update status and Error message in the event table of the source side
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  20-Aug-2016    TCS        initial build
  --------------------------------------------------------------------
  PROCEDURE update_status(errbuff OUT VARCHAR2,
                          retcode OUT NUMBER) IS
  
    CURSOR c_price_list_data IS
      SELECT *
      FROM   xxqp_pricelist_stg
      WHERE  status IS NOT NULL
      AND    request_id = g_request_id;
  
    l_cref_list_line_id NUMBER;
    l_orig_sys_line_ref VARCHAR2(50);
    l_err_code          VARCHAR2(100);
    l_err_message       VARCHAR2(2000);
  BEGIN
  
    /************************************************************************************************
      
      *********** Updating status and Error message in the event table of the source side ********                                                               
    
    *************************************************************************************************/
  
    FOR rec_price_list_data IN c_price_list_data LOOP
    
      IF rec_price_list_data.status = 'S' THEN
      
        BEGIN
          SELECT list_line_id,
                 orig_sys_line_ref
          INTO   l_cref_list_line_id,
                 l_orig_sys_line_ref
          FROM   qp_list_lines
          WHERE  list_line_id = to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('PRICE-LINES', rec_price_list_data.list_line_id));
        EXCEPTION
          WHEN no_data_found THEN
            l_cref_list_line_id := NULL;
            l_orig_sys_line_ref := NULL;
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log, '** Error Message  ** ' ||
                                    SQLERRM);
        END;
        apps.fnd_file.put_line(apps.fnd_file.log, '***g_entity_name***' ||
                                g_entity_name);
      
        apps.fnd_file.put_line(apps.fnd_file.log, '***legecy line id***' ||
                                l_cref_list_line_id);
        apps.fnd_file.put_line(apps.fnd_file.log, '***orig system line reference***' ||
                                l_orig_sys_line_ref);
        ----calling procedure to insert record in cross ref table
        
        xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => g_entity_name, p_legacy_id => l_cref_list_line_id, p_s3_id => rec_price_list_data.list_line_id, p_org_id => '', p_attribute1 => '', p_attribute2 => '', p_attribute3 => '', p_attribute4 => '', p_attribute5 => '', p_err_code => l_err_code, p_err_message => l_err_message);
      
        xxssys_event_pkg_s3.update_success(rec_price_list_data.event_id);
      
      ELSIF rec_price_list_data.status = 'E' THEN
      
        xxssys_event_pkg_s3.update_error(rec_price_list_data.event_id, rec_price_list_data.error_msg);
      
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error while executing procedure update_status:' ||
                         SQLCODE || '  ' || 'Error Msg :' ||
                         SQLERRM ||
                         dbms_utility.format_error_backtrace);
  END update_status;

END xxqp_s3_legacy_int_pkg;
/
