CREATE OR REPLACE PACKAGE xxs3_otc_resin_credit_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Resin Credit Extract
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  26/09/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Resin Credit Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE resin_credit_extract(x_retcode OUT NUMBER
                                ,x_errbuf  OUT VARCHAR2);


END xxs3_otc_resin_credit_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_otc_resin_credit_pkg IS



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' ||
                         SQLERRM);
  END log_p;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' ||
                         SQLERRM);
  END out_p;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Resin Credit Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/09/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE resin_credit_extract(x_retcode OUT NUMBER
                                ,x_errbuf  OUT VARCHAR2) AS
  
  
    l_err_code    NUMBER;
    l_err_msg     VARCHAR2(100);
    l_sysdate     DATE := SYSDATE;
    l_entity_name VARCHAR2(50);
    v_org_id      NUMBER;
  
  
  
  
    CURSOR cur_resin_credit(l_org_id NUMBER) IS
      SELECT customer_number
            ,customer_name
            ,currency
            ,'ORDER' AS order_category
            ,'CONVERSION' AS order_source_name
            ,SUM(credit_amount) resin_credit_balance
            ,SUM(average_discount_amount) deffered_avg_discount
            ,operating_unit
      FROM (SELECT ho.NAME operating_unit
                  ,hp.party_name customer_name
                  ,hca.account_number customer_number
                  ,oh.transactional_curr_code currency
                  ,oh.order_number
                  ,rct.trx_number invoice_number
                  ,oh.ordered_date
                  ,rctlgd.gl_date
                  ,to_number(nvl(ol.attribute4, 0)) credit_amount
                  ,(SELECT SUM(nvl(rctlgd1.amount, 0))
                    FROM ra_cust_trx_line_gl_dist_all rctlgd1
                        ,gl_code_combinations         gcc
                    WHERE rctl.customer_trx_line_id =
                          rctlgd1.customer_trx_line_id
                    AND gcc.code_combination_id = rctlgd1.code_combination_id
                    AND gcc.segment3 = '251305') average_discount_amount
            FROM oe_order_lines               ol
                ,wsh_delivery_details         wdd
                ,hz_cust_site_uses_all        hcsu
                ,hz_cust_acct_sites_all       hcas
                ,hz_cust_accounts             hca
                ,hz_parties                   hp
                ,oe_order_headers_all         oh
                ,mtl_system_items_b           msi
                ,hr_operating_units           ho
                ,ra_customer_trx_lines_all    rctl
                ,ra_customer_trx_all          rct
                ,ra_cust_trx_line_gl_dist_all rctlgd
            WHERE decode(oh.attribute8, 'SHIP_TO', ol.ship_to_org_id, ol.invoice_to_org_id) =
                  hcsu.site_use_id
            AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
            AND hcas.cust_account_id = hca.cust_account_id
            AND hca.party_id = hp.party_id
            AND oh.header_id = ol.header_id
            AND oh.org_id = ho.organization_id
            AND oh.org_id = l_org_id
            AND msi.inventory_item_id = ol.inventory_item_id
            AND msi.organization_id = ol.ship_from_org_id
            AND msi.item_type =
                  fnd_profile.VALUE('XXAR_CREDIT_RESIN_ITEM_TYPE')
            AND ol.unit_selling_price >= 0
            AND ol.attribute10 IS NOT NULL
            AND ol.cancelled_flag = 'N'
            AND ol.line_id = wdd.source_line_id
            AND wdd.released_status NOT IN ('R', 'B')
            AND to_char(ol.line_id) = rctl.interface_line_attribute6(+)
            AND rctl.customer_trx_id = rct.customer_trx_id(+)
            AND rct.customer_trx_id = rctlgd.customer_trx_id(+)
            AND rctlgd.latest_rec_flag(+) = 'Y'
            AND rctlgd.account_class(+) = 'REC'
            AND rctl.interface_line_context(+) = 'ORDER ENTRY'
            AND rctl.inventory_item_id = msi.inventory_item_id
            UNION ALL
            SELECT ho.NAME operating_unit
                  ,hp.party_name customer_name
                  ,hca.account_number customer_number
                  ,oh.transactional_curr_code currency
                  ,oh.order_number
                  ,rct.trx_number invoice_number
                  ,oh.ordered_date
                  ,rctlgd.gl_date
                  ,decode(ol.line_category_code, 'RETURN', -1, 1) *
                   ol.unit_selling_price * ol.ordered_quantity credit_amount
                  ,(SELECT SUM(nvl(rctlgd1.amount, 0))
                    FROM ra_cust_trx_line_gl_dist_all rctlgd1
                        ,gl_code_combinations         gcc
                    WHERE rctl.customer_trx_line_id =
                          rctlgd1.customer_trx_line_id
                    AND gcc.code_combination_id = rctlgd1.code_combination_id
                    AND gcc.segment3 = '251305') average_discount_amount
            FROM oe_order_lines               ol
                ,wsh_delivery_details         wdd
                ,hz_cust_site_uses_all        hcsu
                ,hz_cust_acct_sites_all       hcas
                ,hz_cust_accounts             hca
                ,hz_parties                   hp
                ,oe_order_headers_all         oh
                ,mtl_system_items_b           msi
                ,hr_operating_units           ho
                ,ra_customer_trx_lines_all    rctl
                ,ra_customer_trx_all          rct
                ,ra_cust_trx_line_gl_dist_all rctlgd
            WHERE decode(oh.attribute8, 'SHIP_TO', ol.ship_to_org_id, ol.invoice_to_org_id) =
                  hcsu.site_use_id
            AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
            AND hcas.cust_account_id = hca.cust_account_id
            AND hca.party_id = hp.party_id
            AND oh.header_id = ol.header_id
            AND oh.org_id = ho.organization_id
            AND oh.org_id = l_org_id
            AND msi.inventory_item_id = ol.inventory_item_id
            AND msi.organization_id = ol.ship_from_org_id
            AND msi.item_type =
                  fnd_profile.VALUE('XXAR_CREDIT_RESIN_ITEM_TYPE')
            AND ol.unit_selling_price < 0
            AND ol.cancelled_flag = 'N'
            AND ol.line_id = wdd.source_line_id
            AND wdd.released_status NOT IN ('R', 'B')
            AND to_char(ol.line_id) = rctl.interface_line_attribute6(+)
            AND rctl.customer_trx_id = rct.customer_trx_id(+)
            AND rct.customer_trx_id = rctlgd.customer_trx_id(+)
            AND rctlgd.latest_rec_flag(+) = 'Y'
            AND rctlgd.account_class(+) = 'REC'
            AND rctl.interface_line_context(+) = 'ORDER ENTRY'
            AND rctl.inventory_item_id = msi.inventory_item_id)
      GROUP BY customer_number
              ,customer_name
              ,currency
              ,operating_unit;
  
  
  
  
  BEGIN
  
    log_p('Truncating Table xxs3_otc_resin_credit...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_resin_credit';
  
  
    mo_global.init('M');
  
    l_entity_name := 'RESIN_CREDIT';
  
    log_p(chr(10) || 'Inserting Customer Resin Credit Data...');
  
  
    FOR j IN (SELECT (substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1)) v_org_id
              FROM fnd_lookup_values
              WHERE lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
              AND substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) =
                    l_entity_name
              AND substr(TRIM(lookup_code), instr(TRIM(lookup_code), '-') + 1) =
                    l_entity_name
              AND enabled_flag = 'Y'
              AND description = 'Organization'
              AND LANGUAGE = userenv('LANG')
              AND trunc(SYSDATE) BETWEEN
                    nvl(start_date_active, trunc(SYSDATE)) AND
                    nvl(end_date_active, trunc(SYSDATE)))
    
    LOOP
    
    
      log_p(chr(10) ||
            'Inserting Customer Resin Credit Data for Organization Id : ' ||
            j.v_org_id);
    
      FOR i IN cur_resin_credit(j.v_org_id)
      LOOP
      
        BEGIN
        
        
          INSERT INTO xxobjt.xxs3_otc_resin_credit
            (xx_resin_credit_id
            ,date_of_extract
            ,process_flag
            ,customer_number
            ,customer_name
            ,resin_credit_balance
            ,deffered_avg_discount
            ,unit_selling_price)
          VALUES
            (xxobjt.xxs3_otc_resin_credit_seq.NEXTVAL
            ,l_sysdate
            ,'N'
            ,i.customer_number
            ,i.customer_name
            ,i.resin_credit_balance
            ,i.deffered_avg_discount
            ,(i.resin_credit_balance - i.deffered_avg_discount));
        
        
        EXCEPTION
          WHEN OTHERS THEN
            log_p('Unexpected error while inserting data for xx_resin_credit_id :' ||
                  xxobjt.xxs3_otc_resin_credit_seq.CURRVAL ||
                  ' : ERROR : ' || SQLERRM);
          
        END;
      
      END LOOP;
    
    
    END LOOP;
  
    COMMIT;
  
  
    log_p(chr(10) || 'Insertion of Customer Resin Credit Data Completed');
  
  
  
  END resin_credit_extract;



END xxs3_otc_resin_credit_pkg;
/
