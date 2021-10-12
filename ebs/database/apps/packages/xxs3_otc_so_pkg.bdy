CREATE OR REPLACE PACKAGE BODY xxs3_otc_so_pkg AS

  -- ----------------------------------------------------------------------------------------------------------
  -- Purpose:  This Package is used for Sales Order Data Extraction, Quality Check and Report generation
  --
  -- ----------------------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- ----------------------------------------------------------------------------------------------------------





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
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
  -- 1.0  18/05/2016  TCS                           Initial build  
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
  -- Purpose: This procedure is used for Sales Order Header Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_header_extract(p_retcode OUT VARCHAR2
                             ,p_errbuf  OUT VARCHAR2) AS
  
    l_err_code              NUMBER;
    l_err_msg               VARCHAR2(1000);
    l_s3_freight_terms_code VARCHAR2(30);
    l_s3_incoterms          VARCHAR2(30);
    l_legacy_information    VARCHAR2(200);
    l_step                  VARCHAR2(200);
    l_sold_to_contact_id    NUMBER;
    l_freight_term_meaning  VARCHAR2(200);
    l_inco_term_meaning     VARCHAR2(200);
  
    CURSOR c_so_header IS
      SELECT DISTINCT ooha.header_id
                     ,trunc(ooha.request_date) request_date --
                     ,trunc(ooha.booked_date) booked_date --
                     ,trunc(ooha.pricing_date) pricing_date --
                     ,ooha.tax_exempt_flag
                     ,hca.cust_account_id
                     ,hca.account_number customer_number
                     ,ooha.cust_po_number
                     ,ooha.sold_to_contact_id --
                     ,hcsua.location ship_to_location
                     ,hps.party_site_number ship_to_site_no
                     ,hcsua.site_use_code ship_to_site_uses
                     ,in_hcsua.location invoice_to_location
                     ,in_hps.party_site_number invoice_to_site_no
                     ,in_hcsua.site_use_code invoice_to_site_uses
                     ,'' deliver_to_location --np
                     ,'' deliver_to_site_no --cannot find
                     ,'' deliver_to_site_uses --cannot find
                     ,ooha.order_source_id
                     ,ooha.order_number
                     ,ottl.NAME order_type
                     ,trunc(ooha.ordered_date) ordered_date --
                     ,qlht.NAME price_list
                     ,jrdv.resource_name salesrep
                     ,ooha.flow_status_code
                     ,'CONVERSION' order_source_name
                     ,ooha.transactional_curr_code transactional_curr
                     ,ooha.return_reason_code
                     ,ooha.fob_point_code
                     ,ooha.shipping_instructions
                     ,ooha.shipping_method_code
                     ,ooha.freight_carrier_code
                     ,ooha.freight_terms_code
                     ,ooha.shipment_priority_code
                     ,ooha.packing_instructions
                     ,(SELECT NAME
                       FROM ra_terms_vl
                       WHERE term_id = ooha.payment_term_id) payment_terms
                     ,ooha.ship_from_org_id
                     ,mtp.organization_code ship_from_org_code
                     ,ooha.line_set_name line_set
                     ,ooha.credit_card_code
                      -- ,'' credit_card_type --
                     ,ooha.credit_card_number
                     ,ooha.credit_card_holder_name card_holder
                     ,trunc(ooha.credit_card_expiration_date) card_expiration_date --
                     ,ooha.credit_card_approval_code approval_code
                     ,ooha.credit_card_approval_date -- Added on 20-OCT-2016
                     ,ooha.tax_exempt_number
                     ,ooha.tax_exempt_reason_code exempt_reason
                     ,ooha.payment_amount amount
                     ,ooha.payment_type_code payment_type
                     ,ooha.check_number
                     ,op.prepaid_amount --
                     ,ooha.CONTEXT attribute_category
                     ,to_char(ooha.attribute1) attribute1
                     ,ooha.attribute2
                     ,ooha.attribute3
                     ,ooha.attribute4
                     ,ooha.attribute5
                     ,ooha.attribute6
                     ,ooha.attribute7
                     ,ooha.attribute8
                     ,ooha.attribute9
                      --   ,ooha.attribute10  --Commented on 24-OCT-2016
                     ,(SELECT source_name
                       FROM jtf_rs_resource_extns jrre
                       WHERE jrre.resource_id = ooha.attribute10) attribute10
                     ,ooha.attribute11
                     ,ooha.attribute12
                     ,ooha.attribute13
                     ,ooha.attribute14
                     ,ooha.attribute15
                     ,ooha.attribute16
                     ,ooha.attribute17
                     ,ooha.attribute18
                     ,ooha.attribute19
                     ,ooha.attribute20
                     ,ooha.global_attribute_category
                     ,ooha.global_attribute1
                     ,ooha.global_attribute2
                     ,ooha.global_attribute3
                     ,ooha.global_attribute4
                     ,ooha.global_attribute5
                     ,ooha.global_attribute6
                     ,ooha.global_attribute7
                     ,ooha.global_attribute8
                     ,ooha.global_attribute9
                     ,ooha.global_attribute10
                     ,ooha.global_attribute11
                     ,ooha.global_attribute12
                     ,ooha.global_attribute13
                     ,ooha.global_attribute14
                     ,ooha.global_attribute15
                     ,ooha.global_attribute16
                     ,ooha.global_attribute17
                     ,ooha.global_attribute18
                     ,ooha.global_attribute19
                     ,ooha.global_attribute20
                     ,ooha.order_category_code
      
      FROM oe_order_headers_all    ooha
          ,hz_cust_accounts        hca
          ,hz_cust_site_uses_all   hcsua
          ,hz_cust_acct_sites_all  hcsa
          ,hz_party_sites          hps
          ,hz_cust_site_uses_all   in_hcsua
          ,hz_cust_acct_sites_all  in_hcsa
          ,hz_party_sites          in_hps
          ,oe_transaction_types_tl ottl
          ,jtf_rs_salesreps        jrs
          ,jtf_rs_defresources_vl  jrdv
          ,qp_list_headers_tl      qlht
          ,mtl_parameters          mtp
          ,oe_payments             op
      
      WHERE ooha.sold_to_org_id = hca.cust_account_id
      AND hcsua.site_use_id = ooha.ship_to_org_id
      AND hcsa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND hcsa.party_site_id = hps.party_site_id
      AND hcsua.site_use_code = 'SHIP_TO'
      AND in_hcsua.site_use_id = ooha.invoice_to_org_id
      AND in_hcsa.cust_acct_site_id = in_hcsua.cust_acct_site_id
      AND in_hcsa.party_site_id = in_hps.party_site_id
      AND in_hcsua.site_use_code = 'BILL_TO'
      AND ottl.transaction_type_id = ooha.order_type_id
      AND jrs.org_id = ooha.org_id
      AND jrs.resource_id = jrdv.resource_id
      AND ooha.salesrep_id = jrs.salesrep_id
      AND ooha.price_list_id = qlht.list_header_id
      AND mtp.organization_id = ooha.ship_from_org_id
      AND ottl.LANGUAGE = 'US'
      AND qlht.LANGUAGE = 'US'
      AND ooha.org_id = 737
      AND ooha.header_id = op.header_id(+)
      AND ooha.header_id IN
            (SELECT oel.header_id
             FROM oe_order_lines_all oel
             WHERE oel.flow_status_code IN ('ENTERED', 'BOOKED')
                  -- ('ENTERED', 'AWAITING_RETURN', 'BOOKED')-- Added on 20-OCT-2016 as per updated FDD
             AND oel.org_id = 737
             UNION
             -- Added on 20-OCT-2016 as per updated FDD --
             SELECT oel.header_id
             FROM oe_order_lines_all oel
             WHERE flow_status_code = 'AWAITING_RETURN'
             AND line_category_code = 'RETURN'
             AND oel.org_id = 737
             -- Added on 20-OCT-2016 as per updated FDD --
             UNION
             SELECT oel.header_id
             FROM oe_order_lines_all   oel
                 ,wsh_delivery_details wdd
             WHERE oel.flow_status_code IN ('AWAITING_SHIPPING') --, 'BOOKED')
             AND wdd.released_status IN ('R', 'B')
             AND oel.line_id = wdd.source_line_id
             AND oel.org_id = 737
             -- Added on 20-OCT-2016 as per updated FDD --
             UNION
             SELECT oeh.header_id
             FROM oe_order_headers_all oeh
             WHERE NOT EXISTS (SELECT 1
                    FROM oe_order_lines_all oel
                    WHERE oel.header_id = oeh.header_id
                    AND open_flag = 'Y')
             AND oeh.open_flag = 'Y'
             AND oeh.org_id = 737
             AND oeh.order_source_id = 1001)
           -- Added on 20-OCT-2016 as per updated FDD --
      AND ooha.flow_status_code IN ('ENTERED', 'BOOKED')
      AND hca.customer_type != 'I'; -- Added on 20-OCT-2016 as per updated FDD
  
  
  BEGIN
  
    p_retcode := '0';
    p_errbuf  := 'SUCCESS';
  
  
    log_p('Truncating Sales order header table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_so_header';
  
    FOR i IN c_so_header
    LOOP
    
    
      /* Added on 13-OCT-2016 to fetch value of org_contact_id to the field SOLD_TO_CONTACT 
      in generated extract, so that correct sales order customer contact can be tracked 
      while loading to Conversion*/
    
      BEGIN
      
        l_sold_to_contact_id := NULL;
        l_sold_to_contact_id := fetch_so_sold_to_contact_id(i.cust_account_id, i.sold_to_contact_id);
      
      
      EXCEPTION
      
        WHEN OTHERS THEN
          log_p('Error while fetching l_sold_to_contact_id : ' || SQLERRM);
        
      END;
    
      /* Added on 13-OCT-2016 to fetch value of org_contact_id to the field SOLD_TO_CONTACT 
      in generated extract, so that correct sales order customer contact can be tracked 
      while loading to Conversion*/
    
    
    
      BEGIN
        INSERT INTO xxobjt.xxs3_otc_so_header
          (xx_so_header_id
          ,date_extracted_on
          ,process_flag
          ,header_id
          ,customer_number
          ,cust_po_number
          ,sold_to_contact
          ,ship_to_location
          ,ship_to_site_no
          ,ship_to_site_uses
          ,invoice_to_location
          ,invoice_to_site_no
          ,invoice_to_site_uses
          ,deliver_to_location
          ,deliver_to_site_no
          ,deliver_to_site_uses
          ,order_source_id
          ,order_number
          ,order_type
          ,ordered_date
          ,request_date
          ,booked_date
          ,pricing_date
          ,price_list
          ,salesrep
          ,flow_status_code
          ,order_source_name
          ,transactional_curr
          ,return_reason_code
           --,fob_point_code
          ,shipping_instructions
          ,shipping_method_code
          ,freight_carrier_code
          ,freight_terms_code
          ,shipment_priority_code
          ,packing_instructions
          ,payment_terms
          ,ship_from_org_code
          ,line_set
          ,credit_card_code
          ,credit_card_number
          ,card_holder
          ,card_expiration_date
          ,approval_code
          ,credit_card_approval_date
          ,tax_exempt_flag
          ,tax_exempt_number
          ,exempt_reason
          ,amount
          ,payment_type
          ,check_number
          ,prepaid_amount
          ,attribute_category
          ,attribute1
          ,attribute2
          ,attribute3
          ,attribute4
          ,attribute5
          ,attribute6
          ,attribute7
          ,attribute8
          ,attribute9
          ,attribute10
          ,attribute11
          ,attribute12
          ,attribute13
          ,attribute14
          ,attribute15
          ,attribute16
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute20
          ,global_attribute_category
          ,global_attribute1
          ,global_attribute2
          ,global_attribute3
          ,global_attribute4
          ,global_attribute5
          ,global_attribute6
          ,global_attribute7
          ,global_attribute8
          ,global_attribute9
          ,global_attribute10
          ,global_attribute11
          ,global_attribute12
          ,global_attribute13
          ,global_attribute14
          ,global_attribute15
          ,global_attribute16
          ,global_attribute17
          ,global_attribute18
          ,global_attribute19
          ,global_attribute20
          ,order_category_code)
        
        VALUES
          (xxs3_otc_so_header_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.header_id
          ,i.customer_number
          ,i.cust_po_number
           -- ,i.sold_to_contact_id -- Commented on 13-OCT-2016
          ,l_sold_to_contact_id -- Added on 13-OCT-2016
          ,i.ship_to_location
          ,i.ship_to_site_no
          ,i.ship_to_site_uses
          ,i.invoice_to_location
          ,i.invoice_to_site_no
          ,i.invoice_to_site_uses
          ,i.deliver_to_location
          ,i.deliver_to_site_no
          ,i.deliver_to_site_uses
          ,i.order_source_id
          ,i.order_number
          ,i.order_type
          ,i.ordered_date
          ,i.request_date
          ,i.booked_date
          ,i.pricing_date
          ,i.price_list
          ,i.salesrep
          ,i.flow_status_code
          ,i.order_source_name
          ,i.transactional_curr
          ,i.return_reason_code
           -- ,i.fob_point_code
          ,i.shipping_instructions
          ,i.shipping_method_code
          ,i.freight_carrier_code
          ,i.freight_terms_code
          ,i.shipment_priority_code
          ,i.packing_instructions
          ,i.payment_terms
          ,i.ship_from_org_code
          ,i.line_set
           --,i.credit_card_type
          ,i.credit_card_code
          ,i.credit_card_number
          ,i.card_holder
          ,i.card_expiration_date
          ,i.approval_code
          ,i.credit_card_approval_date
          ,i.tax_exempt_flag
          ,i.tax_exempt_number
          ,i.exempt_reason
          ,i.amount
          ,i.payment_type
          ,i.check_number
          ,i.prepaid_amount
          ,i.attribute_category
          ,i.attribute1
          ,i.attribute2
          ,i.attribute3
          ,i.attribute4
          ,i.attribute5
          ,i.attribute6
          ,i.attribute7
          ,i.attribute8
          ,i.attribute9
          ,i.attribute10
          ,i.attribute11
          ,i.attribute12
          ,i.attribute13
          ,i.attribute14
          ,i.attribute15
          ,i.attribute16
          ,i.attribute17
          ,i.attribute18
          ,i.attribute19
          ,i.attribute20
          ,i.global_attribute_category
          ,i.global_attribute1
          ,i.global_attribute2
          ,i.global_attribute3
          ,i.global_attribute4
          ,i.global_attribute5
          ,i.global_attribute6
          ,i.global_attribute7
          ,i.global_attribute8
          ,i.global_attribute9
          ,i.global_attribute10
          ,i.global_attribute11
          ,i.global_attribute12
          ,i.global_attribute13
          ,i.global_attribute14
          ,i.global_attribute15
          ,i.global_attribute16
          ,i.global_attribute17
          ,i.global_attribute18
          ,i.global_attribute19
          ,i.global_attribute20
          ,i.order_category_code);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          p_errbuf := 'Error in Inserting into the table ' || SQLERRM;
        
          log_p(p_errbuf);
        
      END;
    
    END LOOP;
  
  
    -- Added on 18-OCT-2016 as per updated FDD 
  
    ----------  Cleasing   ------------
    log_p('Starting Cleasing...');
  
    FOR k IN (SELECT xx_so_header_id
                    ,salesrep
              FROM xxobjt.xxs3_otc_so_header)
    LOOP
      BEGIN
      
        IF k.salesrep = 'No Commission,  - Stratasys, Inc.'
        THEN
        
        
          UPDATE xxobjt.xxs3_otc_so_header
          SET s3_salesrep    = 'No Sales Credit'
             ,cleanse_status = 'PASS'
          WHERE xx_so_header_id = k.xx_so_header_id;
        
        ELSE
        
          UPDATE xxobjt.xxs3_otc_so_header
          SET s3_salesrep    = k.salesrep
             ,cleanse_status = 'PASS'
          WHERE xx_so_header_id = k.xx_so_header_id;
        
        END IF;
      
      
      EXCEPTION
        WHEN OTHERS THEN
        
          p_errbuf := 'Cleanse Error : SLAESREP : ' || SQLERRM;
          UPDATE xxobjt.xxs3_otc_so_header
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = cleanse_error || p_errbuf || ' ,'
          WHERE xx_so_header_id = k.xx_so_header_id;
        
      
      END;
    
    END LOOP;
  
    -- Added on 18-OCT-2016 as per updated FDD
  
  
    --------- Transformation ---------  
    log_p('Starting Transformation...');
  
    FOR j IN (SELECT xx_so_header_id
                    ,order_type
                    ,price_list
                    ,ship_from_org_code
                    ,freight_terms_code
              FROM xxobjt.xxs3_otc_so_header)
    LOOP
    
    
      l_step := 'Sales Order Type Transformation';
      IF j.order_type IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_order_type', p_stage_tab => 'XXS3_OTC_SO_HEADER', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_header_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.order_type, --Legacy Value
                                               p_stage_col => 'S3_order_type', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
      l_step := 'Sales Order Header Price List Transformation';
      IF j.price_list IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_price_list', p_stage_tab => 'XXS3_OTC_SO_HEADER', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_header_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.price_list, --Legacy Value
                                               p_stage_col => 'S3_price_list', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
      l_step := 'Sales Order Header Inventory Org Transformation';
      IF j.ship_from_org_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'XXS3_OTC_SO_HEADER', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_header_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.ship_from_org_code, --Legacy Value
                                               p_stage_col => 'S3_ship_from_org_code', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
      -- Added on 06-OCT-2016 as per the updated FDD   
    
      l_step                 := 'Sales Order Header Freight Term Transformation';
      l_freight_term_meaning := NULL;
      l_inco_term_meaning    := NULL;
    
      IF j.freight_terms_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_freight_term', p_stage_tab => 'XXS3_OTC_SO_HEADER', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_header_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.freight_terms_code, --Legacy Value
                                               p_stage_col => 'S3_FREIGHT_TERMS_CODE', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      
      
        SELECT legacy_information
        INTO l_freight_term_meaning
        FROM xxobjt.xxs3_transform
        WHERE mapping_type = 'so_freight_term'
        AND legacy_data = j.freight_terms_code;
      
      
        UPDATE xxs3_otc_so_header
        SET freight_term_meaning = l_freight_term_meaning
        WHERE xx_so_header_id = j.xx_so_header_id;
      
      
        COMMIT;
      
        l_step := 'Sales Order Header Freight Term to Inco Term Transformation';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_fob_point_codes', p_stage_tab => 'XXS3_OTC_SO_HEADER', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_header_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_header_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.freight_terms_code, --Legacy Value
                                               p_stage_col => 'S3_INCOTERMS', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      
      
      
        SELECT legacy_information
        INTO l_inco_term_meaning
        FROM xxobjt.xxs3_transform
        WHERE mapping_type = 'so_fob_point_codes'
        AND legacy_data = j.freight_terms_code;
      
      
        UPDATE xxs3_otc_so_header
        SET inco_term_meaning = l_inco_term_meaning
        WHERE xx_so_header_id = j.xx_so_header_id;
      
        /* SELECT s3_freight_terms_code
              ,s3_incoterms
        INTO l_s3_freight_terms_code
            ,l_s3_incoterms
        FROM xxobjt.xxs3_otc_so_header
        WHERE xx_so_header_id = j.xx_so_header_id;
        
        IF (l_s3_freight_terms_code IS NULL AND l_s3_incoterms IS NULL)
        THEN
        
          SELECT legacy_information
          INTO l_legacy_information
          FROM xxobjt.xxs3_transform
          WHERE mapping_type = 'so_freight_term'
          AND legacy_data = j.freight_terms_code;
        
          UPDATE xxobjt.xxs3_otc_so_header
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error ||
                                 'For S3_Freight/Inco Term Mapping : ' ||
                                 l_legacy_information || ','
          WHERE xx_so_header_id = j.xx_so_header_id;
        
        END IF;*/
      
      
      END IF;
      -- Added on 06-OCT-2016 as per the updated FDD
    
    
    END LOOP;
  
    log_p('End of Transformation...');
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_retcode := 2;
      p_errbuf  := 'Unexpected error in inserting Value to so_header_extract.';
      log_p('Unexpected error in inserting Value to so_header_extract in step : ' ||
            l_step || ' - ' || SQLERRM);
      log_p(dbms_utility.format_error_backtrace);
    
  END so_header_extract;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Line Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_line_extract(p_retcode OUT VARCHAR2
                           ,p_errbuf  OUT VARCHAR2) AS
  
    l_err_code              NUMBER;
    l_err_msg               VARCHAR2(1000);
    l_s3_freight_terms_code VARCHAR2(30);
    l_s3_incoterms          VARCHAR2(30);
    l_legacy_information    VARCHAR2(200);
    l_step                  VARCHAR2(200);
    l_released_status       VARCHAR2(30);
    l_freight_term_meaning  VARCHAR2(200);
    l_inco_term_meaning     VARCHAR2(200);
    l_counter               NUMBER;
  
    CURSOR c_so_line IS
    
      SELECT DISTINCT ooha.order_number ----
                     ,oola.return_reason_code return_reason ----
                     ,oola.split_from_line_id
                     ,oola.cancelled_quantity ----
                     ,'R' || ooha.cust_po_number cust_po_number ----
                      --,oola.delivery_lead_time
                     ,oola.flow_status_code ----
                     ,oola.fob_point_code ----
                     ,oola.freight_carrier_code ----
                     ,oola.invoice_to_org_id --------
                     ,oola.line_number ----
                     ,lt.NAME line_type ----
                     ,oola.unit_list_price unit_list_price ----
                     ,oola.order_quantity_uom ----
                      --,'CONVERSION' order_source_name
                     ,oola.ordered_item ----
                     ,oola.ordered_quantity ----
                     ,qlht.NAME price_list ----
                     ,trunc(oola.request_date) request_date -- 
                     ,trunc(oola.schedule_ship_date) schedule_ship_date --
                      --,oola.ship_from_org_id
                     ,oola.ship_to_org_id --
                     ,oola.shipped_quantity ----
                     ,oola.shipping_method_code ----
                      --,oola.sold_from_org_id
                     ,oola.sold_to_org_id --
                     ,ooha.transactional_curr_code transactional_curr ----
                     ,oola.unit_selling_price ----
                     ,oola.accounting_rule_id
                     ,trunc(oola.actual_arrival_date) actual_arrival_date --
                     ,oola.attribute1 ----
                     ,oola.attribute2
                     ,oola.attribute3
                     ,oola.attribute4
                     ,oola.attribute5
                     ,oola.attribute6
                     ,oola.attribute7
                     ,oola.attribute8
                     ,oola.attribute9
                     ,oola.attribute10
                     ,oola.attribute11
                     ,oola.attribute12
                     ,oola.attribute13
                     ,oola.attribute14
                     ,oola.attribute15
                     ,oola.attribute16
                     ,oola.attribute17
                     ,oola.attribute18
                     ,oola.attribute19
                     ,oola.attribute20 ----
                     ,oola.deliver_to_org_id --
                     ,oola.freight_terms_code
                      --,oola.demand_class_code
                      --,oola.drop_ship_flag
                      /*    ,(SELECT meaning  FROM fnd_lookup_values
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                WHERE lookup_code = oola.freight_terms_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             AND lookup_type = 'FREIGHT_TERMS'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             AND LANGUAGE = 'US') freight_terms_code ----*/ -- Commented on 06-OCT-2016                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
                                                                                                                                    
                      
                      
                      
                      --   ,olav.fulfillment_set_name ---- Commented on 24-OCT-2016
                      -- Added on 24-OCT-2016
                     ,(SELECT set_name
                       FROM oe_sets
                       WHERE set_type = 'FULFILLMENT_SET'
                       AND set_id = (SELECT set_id
                                    FROM oe_line_sets
                                    WHERE line_id = oola.line_id)) fulfillment_set_name
                     ,(SELECT set_name
                       FROM oe_sets
                       WHERE set_type = 'SHIP_SET'
                       AND set_id = (SELECT set_id
                                    FROM oe_line_sets
                                    WHERE line_id = oola.line_id)) line_set_name
                      -- Added on 24-OCT-2016
                     ,oola.global_attribute1 ----
                     ,oola.global_attribute2
                     ,oola.global_attribute3
                     ,oola.global_attribute4
                     ,oola.global_attribute5
                     ,oola.global_attribute6
                     ,oola.global_attribute7
                     ,oola.global_attribute8
                     ,oola.global_attribute9
                     ,oola.global_attribute10
                     ,oola.global_attribute11
                     ,oola.global_attribute12
                     ,oola.global_attribute13
                     ,oola.global_attribute14
                     ,oola.global_attribute15
                     ,oola.global_attribute16
                     ,oola.global_attribute17
                     ,oola.global_attribute18
                     ,oola.global_attribute19
                     ,oola.global_attribute20
                      --,oola.invoicing_rule_id
                     ,oola.option_number
                     ,oola.packing_instructions
                     ,(SELECT NAME
                       FROM ra_terms_vl
                       WHERE term_id = ooha.payment_term_id) payment_term
                     ,oola.pricing_context
                     ,trunc(oola.pricing_date) pricing_date --
                     ,ooha.salesrep_id salesrep
                     ,trunc(oola.schedule_arrival_date) schedule_arrival_date --
                     ,oola.ship_set_id ship_set_name
                      --,oola.ship_tolerance_above
                      --,oola.ship_tolerance_below
                      --,olav.shipment_number
                     ,oola.shipment_priority_code
                     ,oola.shipping_instructions
                     ,ohav.sold_to_contact_id
                     ,trunc(oola.promise_date) promise_date --
                      --,mpt.organization_code invoice_to_org_code
                     ,mpt1.organization_code ship_from_org
                      --,'' tax_code
                      --,'' tax_exempt_flag
                      --,'' tax_exempt_reason_code
                     ,oola.calculate_price_flag
                     ,oola.global_attribute_category
                     ,oola.header_id
                     ,oola.item_type_code
                     ,oola.line_category_code
                     ,oola.line_id
                     ,ottl.NAME order_type
                     ,oola.return_attribute1
                     ,oola.return_attribute10
                     ,oola.return_attribute2
                     ,oola.return_attribute3
                     ,oola.return_attribute4
                     ,oola.return_attribute5
                     ,oola.return_attribute6
                     ,oola.return_attribute7
                     ,oola.return_attribute8
                     ,oola.return_attribute9
                     ,oola.return_context
                     ,oola.CONTEXT attribute_category
                     ,'' default_shipping_org
                     ,'' deliver_to_location ----
                     ,'' deliver_to_site_no ----
                     ,'' deliver_to_site_uses ----
                     ,'' extended_price ----
                     ,in_hcsua.location invoice_to_location ----
                     ,in_hps.party_site_number invoice_to_site_no ----
                     ,in_hcsua.site_use_code invoice_to_site_uses ----
                     ,hcsua.location ship_to_location ----
                     ,hps.party_site_number ship_to_site_no ----
                     ,hcsua.site_use_code ship_to_site_uses
                     ,oola.orig_sys_document_ref
                     ,oola.orig_sys_line_ref
                     ,oola.top_model_line_id
                     ,oola.link_to_line_id ---- 
      
      FROM oe_order_headers_all    ooha
          ,oe_order_lines_all      oola
          ,hz_cust_accounts        hca
          ,hz_cust_site_uses_all   hcsua
          ,hz_cust_acct_sites_all  hcsa
          ,hz_party_sites          hps
          ,hz_cust_site_uses_all   in_hcsua
          ,hz_cust_acct_sites_all  in_hcsa
          ,hz_party_sites          in_hps
          ,oe_transaction_types_tl ottl
          ,jtf_rs_salesreps        jrs
          ,jtf_rs_defresources_vl  jrdv
          ,qp_list_headers_tl      qlht
          ,oe_transaction_types_tl lt
          ,mtl_parameters          mpt
          ,mtl_parameters          mpt1
          ,oe_line_acks_v          olav
          ,oe_header_acks_v        ohav
      
      WHERE ooha.header_id = oola.header_id
      AND ooha.sold_to_org_id = hca.cust_account_id(+)
      AND ooha.ship_to_org_id = hcsua.site_use_id(+)
      AND hcsa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND hcsa.party_site_id = hps.party_site_id
      AND hcsua.site_use_code = 'SHIP_TO'
      AND ooha.invoice_to_org_id = in_hcsua.site_use_id(+)
      AND in_hcsa.cust_acct_site_id = in_hcsua.cust_acct_site_id
      AND in_hcsa.party_site_id = in_hps.party_site_id
      AND in_hcsua.site_use_code = 'BILL_TO'
      AND ooha.order_type_id = ottl.transaction_type_id(+)
      AND ooha.org_id = jrs.org_id(+)
      AND jrs.resource_id = jrdv.resource_id
      AND ooha.salesrep_id = jrs.salesrep_id(+)
      AND ooha.price_list_id = qlht.list_header_id(+)
      AND ottl.LANGUAGE = 'US'
      AND qlht.LANGUAGE = 'US'
      AND oola.invoice_to_org_id = mpt.organization_id(+)
      AND oola.ship_from_org_id = mpt1.organization_id(+)
      AND oola.header_id = olav.header_id(+)
      AND oola.line_id = olav.line_id(+)
      AND ooha.header_id = ohav.header_id(+)
      AND ooha.order_number = ohav.order_number(+)
      AND EXISTS
       (SELECT *
             FROM xxs3_otc_so_header xsoh
             WHERE xsoh.header_id = ooha.header_id
             AND xsoh.process_flag != 'R')
           
           /* (SELECT oel.header_id                                                                                                                                                                                                                                                                                                                            FROM oe_order_lines_all oel
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          WHERE oel.flow_status_code IN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ('ENTERED', 'AWAITING_RETURN', 'BOOKED')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   AND oel.org_id = 737
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  UNION
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  SELECT oel.header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               FROM oe_order_lines_all   oel
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ,wsh_delivery_details wdd
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              WHERE oel.flow_status_code IN ('AWAITING_SHIPPING', 'BOOKED')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND wdd.released_status IN ('R', 'B')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    AND oel.line_id = wdd.source_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    AND oel.org_id = 737)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             AND ooha.flow_status_code IN ('ENTERED', 'BOOKED')*/
      AND oola.line_type_id = lt.transaction_type_id(+)
      AND lt.LANGUAGE = 'US'
      AND oola.flow_status_code NOT IN ('CLOSED', 'CANCELLED');
  
    /* UNION
    
    SELECT DISTINCT ooha.order_number ----
                   ,oola.return_reason_code return_reason ----
                   ,oola.split_from_line_id
                   ,oola.cancelled_quantity ----
                   ,'R' || ooha.cust_po_number cust_po_number ----
                    --,oola.delivery_lead_time
                   ,oola.flow_status_code ----
                   ,oola.fob_point_code ----
                   ,oola.freight_carrier_code ----
                   ,oola.invoice_to_org_id --------
                   ,oola.line_number ----
                   ,lt.NAME line_type ----
                   ,oola.unit_list_price unit_list_price ----
                   ,oola.order_quantity_uom ----
                    --,'CONVERSION' order_source_name
                   ,oola.ordered_item ----
                   ,oola.ordered_quantity ----
                   ,qlht.NAME price_list ----
                   ,trunc(oola.request_date) request_date -- 
                   ,trunc(oola.schedule_ship_date) schedule_ship_date --
                    --,oola.ship_from_org_id
                   ,oola.ship_to_org_id --
                   ,oola.shipped_quantity ----
                   ,oola.shipping_method_code ----
                    --,oola.sold_from_org_id
                   ,oola.sold_to_org_id --
                   ,ooha.transactional_curr_code transactional_curr ----
                   ,oola.unit_selling_price ----
                   ,oola.accounting_rule_id
                   ,trunc(oola.actual_arrival_date) actual_arrival_date --
                   ,oola.attribute1 ----
                   ,oola.attribute2
                   ,oola.attribute3
                   ,oola.attribute4
                   ,oola.attribute5
                   ,oola.attribute6
                   ,oola.attribute7
                   ,oola.attribute8
                   ,oola.attribute9
                   ,oola.attribute10
                   ,oola.attribute11
                   ,oola.attribute12
                   ,oola.attribute13
                   ,oola.attribute14
                   ,oola.attribute15
                   ,oola.attribute16
                   ,oola.attribute17
                   ,oola.attribute18
                   ,oola.attribute19
                   ,oola.attribute20 ----
                   ,oola.deliver_to_org_id --
                   ,oola.freight_terms_code
                    --,oola.demand_class_code
                    --,oola.drop_ship_flag
                    /*    ,(SELECT meaning  FROM fnd_lookup_values
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    WHERE lookup_code = oola.freight_terms_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND lookup_type = 'FREIGHT_TERMS'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND LANGUAGE = 'US') freight_terms_code ----*/ -- Commented on 06-OCT-2016                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     

  
  
  
    -- ,olav.fulfillment_set_name -- Commented on 24-OCT-2016
    -- Added on 24-OCT-2016
    /*  ,(SELECT set_name
                                                                                                                                   FROM oe_sets
                                                                                                                                   WHERE set_type = 'FULFILLMENT_SET'
                                                                                                                                   AND set_id = (SELECT set_id
                                                                                                                                                FROM oe_line_sets
                                                                                                                                                WHERE line_id = oola.line_id)) fulfillment_set_name
                    ,(SELECT set_name
                                                                                                             FROM oe_sets
                                                                                                             WHERE set_type = 'SHIP_SET'
                                                                                                             AND set_id = (SELECT set_id
                                                                                                                          FROM oe_line_sets
                                                                                                                          WHERE line_id = oola.line_id)) line_set_name
                    -- Added on 24-OCT-2016
                    ,oola.global_attribute1 ----
                   ,oola.global_attribute2
                   ,oola.global_attribute3
                   ,oola.global_attribute4
                   ,oola.global_attribute5
                   ,oola.global_attribute6
                   ,oola.global_attribute7
                   ,oola.global_attribute8
                   ,oola.global_attribute9
                   ,oola.global_attribute10
                   ,oola.global_attribute11
                   ,oola.global_attribute12
                   ,oola.global_attribute13
                   ,oola.global_attribute14
                   ,oola.global_attribute15
                   ,oola.global_attribute16
                   ,oola.global_attribute17
                   ,oola.global_attribute18
                   ,oola.global_attribute19
                   ,oola.global_attribute20
                    --,oola.invoicing_rule_id
                   ,oola.option_number
                   ,oola.packing_instructions
                   ,(SELECT NAME
                     FROM ra_terms_vl
                     WHERE term_id = ooha.payment_term_id) payment_term
                   ,oola.pricing_context
                   ,trunc(oola.pricing_date) pricing_date --
                   ,ooha.salesrep_id salesrep
                   ,trunc(oola.schedule_arrival_date) schedule_arrival_date --
                   ,oola.ship_set_id ship_set_name
                    --,oola.ship_tolerance_above
                    --,oola.ship_tolerance_below
                    --,olav.shipment_number
                   ,oola.shipment_priority_code
                   ,oola.shipping_instructions
                   ,ohav.sold_to_contact_id
                   ,trunc(oola.promise_date) promise_date --
                    --,mpt.organization_code invoice_to_org_code
                   ,mpt1.organization_code ship_from_org
                    --,'' tax_code
                    --,'' tax_exempt_flag
                    --,'' tax_exempt_reason_code
                   ,oola.calculate_price_flag
                   ,oola.global_attribute_category
                   ,oola.header_id
                   ,oola.item_type_code
                   ,oola.line_category_code
                   ,oola.line_id
                   ,ottl.NAME order_type
                   ,oola.return_attribute1
                   ,oola.return_attribute10
                   ,oola.return_attribute2
                   ,oola.return_attribute3
                   ,oola.return_attribute4
                   ,oola.return_attribute5
                   ,oola.return_attribute6
                   ,oola.return_attribute7
                   ,oola.return_attribute8
                   ,oola.return_attribute9
                   ,oola.return_context
                   ,oola.CONTEXT attribute_category
                   ,'' default_shipping_org
                   ,'' deliver_to_location ----
                   ,'' deliver_to_site_no ----
                   ,'' deliver_to_site_uses ----
                   ,'' extended_price ----
                   ,in_hcsua.location invoice_to_location ----
                   ,in_hps.party_site_number invoice_to_site_no ----
                   ,in_hcsua.site_use_code invoice_to_site_uses ----
                   ,hcsua.location ship_to_location ----
                   ,hps.party_site_number ship_to_site_no ----
                   ,hcsua.site_use_code ship_to_site_uses
                   ,oola.orig_sys_document_ref
                   ,oola.orig_sys_line_ref
                   ,oola.top_model_line_id
                   ,oola.link_to_line_id ---- 
    
    FROM oe_order_headers_all    ooha
        ,oe_order_lines_all      oola
        ,hz_cust_accounts        hca
        ,hz_cust_site_uses_all   hcsua
        ,hz_cust_acct_sites_all  hcsa
        ,hz_party_sites          hps
        ,hz_cust_site_uses_all   in_hcsua
        ,hz_cust_acct_sites_all  in_hcsa
        ,hz_party_sites          in_hps
        ,oe_transaction_types_tl ottl
        ,jtf_rs_salesreps        jrs
        ,jtf_rs_defresources_vl  jrdv
        ,qp_list_headers_tl      qlht
        ,oe_transaction_types_tl lt
        ,mtl_parameters          mpt
        ,mtl_parameters          mpt1
        ,oe_line_acks_v          olav
        ,oe_header_acks_v        ohav
    
    WHERE ooha.header_id = oola.header_id
    AND ooha.sold_to_org_id = hca.cust_account_id(+)
    AND ooha.ship_to_org_id = hcsua.site_use_id(+)
    AND hcsa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND hcsa.party_site_id = hps.party_site_id
    AND hcsua.site_use_code = 'SHIP_TO'
    AND ooha.invoice_to_org_id = in_hcsua.site_use_id(+)
    AND in_hcsa.cust_acct_site_id = in_hcsua.cust_acct_site_id
    AND in_hcsa.party_site_id = in_hps.party_site_id
    AND in_hcsua.site_use_code = 'BILL_TO'
    AND ooha.order_type_id = ottl.transaction_type_id(+)
    AND ooha.org_id = jrs.org_id(+)
    AND jrs.resource_id = jrdv.resource_id
    AND ooha.salesrep_id = jrs.salesrep_id(+)
    AND ooha.price_list_id = qlht.list_header_id(+)
    AND ottl.LANGUAGE = 'US'
    AND qlht.LANGUAGE = 'US'
    AND oola.invoice_to_org_id = mpt.organization_id(+)
    AND oola.ship_from_org_id = mpt1.organization_id(+)
    AND oola.header_id = olav.header_id(+)
    AND oola.line_id = olav.line_id(+)
    AND ooha.header_id = ohav.header_id(+)
    AND ooha.order_number = ohav.order_number(+)
    AND EXISTS (SELECT *
           FROM xxs3_otc_so_header xsoh
           WHERE xsoh.header_id = ooha.header_id)*/
  
    /* (SELECT oel.header_id
    FROM oe_order_lines_all oel
                                                                                                                                                                                                                                                                                                                                                                                            WHERE oel.flow_status_code IN
                                                                                                                                                                                                                                                                                                                                                                                         ('ENTERED', 'AWAITING_RETURN', 'BOOKED')
                                                                                                                                                                                                                                                                                                                                                                                         AND oel.org_id = 737
                                                                                                                                                                                                                                                                                                                                                                                        UNION
                                                                                                                                                                                                                                                                                                                                                                                        SELECT oel.header_id
                                                                                                                                                                                                                                                                                                                                                                                     FROM oe_order_lines_all   oel
                                                                                                                                                                                                                                                                                                                                                                                       ,wsh_delivery_details wdd
                                                                                                                                                                                                                                                                                                                                                                                    WHERE oel.flow_status_code IN ('AWAITING_SHIPPING', 'BOOKED')
                                                                                                                                                                                                                                                                                                                                                                                      AND wdd.released_status IN ('R', 'B')
                                                                                                                                                                                                                                                                                                                                                                                          AND oel.line_id = wdd.source_line_id                                                                                                                                                                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          AND oel.org_id = 737)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   AND ooha.flow_status_code IN ('ENTERED', 'BOOKED')*/
    /* AND oola.line_type_id = lt.transaction_type_id(+)
      AND lt.LANGUAGE = 'US'
      AND oola.flow_status_code IN ('CLOSED', 'CANCELLED')
      AND ooha.order_source_id = 1001; -- added on 21-OCT-2016 as per updated FDD
    
    
    CURSOR c_cleanse_line IS
      SELECT osh.header_id
      FROM xxobjt.xxs3_otc_so_header osh
      WHERE osh.order_source_id = 1001;*/
  
  
  BEGIN
  
    p_retcode := '0';
    p_errbuf  := 'SUCCESS';
  
  
  
    log_p('Truncating Sales order lines table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_so_line';
  
  
    FOR i IN c_so_line
    LOOP
    
      BEGIN
        INSERT INTO xxobjt.xxs3_otc_so_line
          (xx_so_line_id
          ,date_extracted_on
          ,process_flag
          ,header_id
          ,line_id
          ,ship_from_org
          ,order_number
          ,cust_po_number
          ,line_number
          ,ordered_item
          ,ordered_quantity
          ,transactional_curr
          ,request_date
          ,promise_date
          ,pricing_date
          ,schedule_arrival_date
          ,schedule_ship_date
          ,order_quantity_uom
          ,cancelled_quantity
          ,shipped_quantity
          ,price_list
          ,payment_term
          ,shipment_priority_code
          ,shipping_method_code
          ,freight_terms_code
          ,fob_point_code
          ,unit_selling_price
          ,unit_list_price
          ,ship_set_name
          ,fulfillment_set_name
          ,line_set_name
          ,extended_price
          ,line_category_code
          ,line_type
          ,return_reason
          ,attribute_category
          ,attribute1
          ,attribute2
          ,attribute3
          ,attribute4
          ,attribute5
          ,attribute6
          ,attribute7
          ,attribute8
          ,attribute9
          ,attribute10
          ,attribute11
          ,attribute12
          ,attribute13
          ,attribute14
          ,attribute15
          ,attribute16
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute20
          ,global_attribute_category
          ,global_attribute1
          ,global_attribute2
          ,global_attribute3
          ,global_attribute4
          ,global_attribute5
          ,global_attribute6
          ,global_attribute7
          ,global_attribute8
          ,global_attribute9
          ,global_attribute10
          ,global_attribute11
          ,global_attribute12
          ,global_attribute13
          ,global_attribute14
          ,global_attribute15
          ,global_attribute16
          ,global_attribute17
          ,global_attribute18
          ,global_attribute19
          ,global_attribute20
          ,return_context
          ,return_attribute1
          ,return_attribute2
          ,return_attribute3
          ,return_attribute4
          ,return_attribute5
          ,return_attribute6
          ,return_attribute7
          ,return_attribute8
          ,return_attribute9
          ,return_attribute10
          ,pricing_context
          ,default_shipping_org
          ,ship_to_location
          ,ship_to_site_no
          ,ship_to_site_uses
          ,deliver_to_location
          ,deliver_to_site_no
          ,deliver_to_site_uses
          ,invoice_to
          ,invoice_to_site_no
          ,invoice_to_site_uses
          ,salesrep
          ,shipping_instructions
          ,packing_instructions
          ,flow_status_code
          ,calculate_price_flag
          ,order_type
          ,freight_carrier_code
          ,option_number
          ,item_type_code
          ,orig_sys_document_ref
          ,orig_sys_line_ref
          ,top_model_line_id
          ,link_to_line_id)
        
        VALUES
          (xxs3_otc_so_line_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.header_id
          ,i.line_id
          ,i.ship_from_org
          ,i.order_number
          ,i.cust_po_number
          ,i.line_number
          ,i.ordered_item
          ,i.ordered_quantity
          ,i.transactional_curr
          ,i.request_date
          ,i.promise_date
          ,i.pricing_date
          ,i.schedule_arrival_date
          ,i.schedule_ship_date
          ,i.order_quantity_uom
          ,i.cancelled_quantity
          ,i.shipped_quantity
          ,i.price_list
          ,i.payment_term
          ,i.shipment_priority_code
          ,i.shipping_method_code
          ,i.freight_terms_code
          ,i.fob_point_code
          ,i.unit_selling_price
          ,i.unit_list_price
          ,i.ship_set_name
          ,i.fulfillment_set_name
          ,i.line_set_name
          ,i.extended_price
          ,i.line_category_code
          ,i.line_type
          ,i.return_reason
          ,i.attribute_category
          ,i.attribute1
          ,i.attribute2
          ,i.attribute3
          ,i.attribute4
          ,i.attribute5
          ,i.attribute6
          ,i.attribute7
          ,i.attribute8
          ,i.attribute9
          ,i.attribute10
          ,i.attribute11
          ,i.attribute12
          ,i.attribute13
          ,i.attribute14
          ,i.attribute15
          ,i.attribute16
          ,i.attribute17
          ,i.attribute18
          ,i.attribute19
          ,i.attribute20
          ,i.global_attribute_category
          ,i.global_attribute1
          ,i.global_attribute2
          ,i.global_attribute3
          ,i.global_attribute4
          ,i.global_attribute5
          ,i.global_attribute6
          ,i.global_attribute7
          ,i.global_attribute8
          ,i.global_attribute9
          ,i.global_attribute10
          ,i.global_attribute11
          ,i.global_attribute12
          ,i.global_attribute13
          ,i.global_attribute14
          ,i.global_attribute15
          ,i.global_attribute16
          ,i.global_attribute17
          ,i.global_attribute18
          ,i.global_attribute19
          ,i.global_attribute20
          ,i.return_context
          ,i.return_attribute1
          ,i.return_attribute2
          ,i.return_attribute3
          ,i.return_attribute4
          ,i.return_attribute5
          ,i.return_attribute6
          ,i.return_attribute7
          ,i.return_attribute8
          ,i.return_attribute9
          ,i.return_attribute10
          ,i.pricing_context
          ,i.default_shipping_org
          ,i.ship_to_location
          ,i.ship_to_site_no
          ,i.ship_to_site_uses
          ,i.deliver_to_location
          ,i.deliver_to_site_no
          ,i.deliver_to_site_uses
          ,i.invoice_to_location
          ,i.invoice_to_site_no
          ,i.invoice_to_site_uses
          ,i.salesrep
          ,i.shipping_instructions
          ,i.packing_instructions
          ,i.flow_status_code
          ,i.calculate_price_flag
          ,i.order_type
          ,i.freight_carrier_code
          ,i.option_number
          ,i.item_type_code
          ,i.orig_sys_document_ref
          ,i.orig_sys_line_ref
          ,i.top_model_line_id
          ,i.link_to_line_id);
      
      EXCEPTION
        WHEN OTHERS THEN
          log_p('Error in Inserting into the table ' || ' - ' || i.line_id ||
                ' - ' || SQLERRM);
        
      
      END;
    
    END LOOP;
  
    COMMIT;
  
  
    log_p('Insertion completed for Sales Order Lines...');
  
  
  
  
  
    --------- Cleanse ---------  
    log_p('Starting Cleanse...');
    l_step := 'Sales Order Lines calculate_price_f Cleanse..';
  
    FOR j IN (SELECT xx_so_line_id
                    ,calculate_price_flag
              FROM xxobjt.xxs3_otc_so_line)
    LOOP
    
      BEGIN
      
        UPDATE xxs3_otc_so_line
        SET s3_calculate_price_flag = 'N'
           ,cleanse_status          = 'PASS'
        WHERE xx_so_line_id = j.xx_so_line_id;
      
      EXCEPTION
        WHEN OTHERS THEN
        
          UPDATE xxs3_otc_so_line
          SET s3_calculate_price_flag = NULL
             ,cleanse_status          = 'FAIL'
          WHERE xx_so_line_id = j.xx_so_line_id;
        
          log_p('Unexpected error in cleanse  calculate_price_flag in step : ' ||
                l_step || ' - ' || SQLERRM);
        
      END;
    
    
    END LOOP;
  
  
    log_p('End of Cleanse...');
  
  
    --------- Transformation ---------  
    log_p('Starting Transformation...');
  
  
    FOR j IN (SELECT xx_so_line_id
                     -- ,fob_point_code
                    ,freight_carrier_code
                    ,order_type
                    ,line_type
                    ,price_list
                    ,ship_from_org
                    ,shipping_method_code
                    ,freight_terms_code
              FROM xxobjt.xxs3_otc_so_line)
    LOOP
    
    
    
      -- Commented on 06-OCT-2016
      /*l_step := 'Sales Order Lines FOB Point Code Transformation';
      IF j.fob_point_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_fob_point_code', p_stage_tab => 'xx_so_line', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.fob_point_code, --Legacy Value
                                               p_stage_col => 'S3_fob_point_code', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;*/
      -- Commented on 06-OCT-2016
    
    
      -- Added on 17-OCT-2016 
      l_step := 'Sales Order Lines Price List Transformation';
      IF j.price_list IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_price_list', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.price_list, --Legacy Value
                                               p_stage_col => 'S3_price_list', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
      -- Added on 17-OCT-2016 
    
    
      l_step := 'Sales Order Lines Inventory Org Transformation';
      IF j.ship_from_org IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.ship_from_org, --Legacy Value
                                               p_stage_col => 'S3_SHIP_FROM_ORG', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
      -- Commented on 20-OCT-2016 as per updated FDD
      /*
        l_step := 'Sales Order Lines Shipping Method Code Transformation';
        IF j.shipping_method_code IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_shipping_method_code', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                                 p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                                 p_legacy_val => j.shipping_method_code, --Legacy Value
                                                 p_stage_col => 'S3_SHIPPING_METHOD_CODE', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      */
      -- Commented on 20-OCT-2016 as per updated FDD
    
    
      -- Commented on 06-OCT-2016
      /*IF j.freight_terms_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_freight_terms', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.freight_terms_code, --Legacy Value
                                               p_stage_col => 'S3_FREIGHT_TERMS_CODE', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;*/
      -- Commented on 06-OCT-2016
    
    
      -- Added on 06-OCT-2016 as per the updated FDD   
    
    
      l_step := 'Sales Order Type Transformation';
      IF j.order_type IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_order_type', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.order_type, --Legacy Value
                                               p_stage_col => 's3_order_type', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
    
      l_step := 'Sales Order Line Type Transformation';
      IF j.line_type IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_line_type', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.line_type, --Legacy Value
                                               p_stage_col => 'S3_LINE_TYPE', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      
      END IF;
    
    
    
    
      l_step                 := 'Sales Order Lines Freight Term Transformation';
      l_freight_term_meaning := NULL;
      l_inco_term_meaning    := NULL;
    
      IF j.freight_terms_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_freight_term', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.freight_terms_code, --Legacy Value
                                               p_stage_col => 'S3_FREIGHT_TERMS_CODE', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      
        SELECT legacy_information
        INTO l_freight_term_meaning
        FROM xxobjt.xxs3_transform
        WHERE mapping_type = 'so_freight_term'
        AND legacy_data = j.freight_terms_code;
      
      
        UPDATE xxs3_otc_so_line
        SET freight_term_meaning = l_freight_term_meaning
        WHERE xx_so_line_id = j.xx_so_line_id;
      
        COMMIT;
      
      
        l_step := 'Sales Order Lines Freight Term to Inco Term Transformation';
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_fob_point_codes', p_stage_tab => 'XXS3_OTC_SO_LINE', --Staging Table Name
                                               p_stage_primary_col => 'xx_so_line_id', --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_so_line_id, --Staging Table Primary Column Value
                                               p_legacy_val => j.freight_terms_code, --Legacy Value
                                               p_stage_col => 'S3_INCOTERMS', --Staging Table Name
                                               p_err_code => l_err_code, -- Output error code
                                               p_err_msg => l_err_msg);
      
        SELECT legacy_information
        INTO l_inco_term_meaning
        FROM xxobjt.xxs3_transform
        WHERE mapping_type = 'so_fob_point_codes'
        AND legacy_data = j.freight_terms_code;
      
      
        UPDATE xxs3_otc_so_line
        SET inco_term_meaning = l_inco_term_meaning
        WHERE xx_so_line_id = j.xx_so_line_id;
      
      
      
        /* SELECT s3_freight_terms_code
              ,s3_incoterms
        INTO l_s3_freight_terms_code
            ,l_s3_incoterms
        FROM xxobjt.xxs3_otc_so_line
        WHERE xx_so_line_id = j.xx_so_line_id;
        
        IF (l_s3_freight_terms_code IS NULL AND l_s3_incoterms IS NULL)
        THEN
        
          SELECT legacy_information
          INTO l_legacy_information
          FROM xxobjt.xxs3_transform
          WHERE mapping_type = 'so_freight_term'
          AND legacy_data = j.freight_terms_code;
        
          UPDATE xxobjt.xxs3_otc_so_line
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error ||
                                 'For S3_Freight/Inco Term Mapping : ' ||
                                 l_legacy_information
          WHERE xx_so_line_id = j.xx_so_line_id;
        
        END IF;*/
      
      
      END IF;
      -- Added on 06-OCT-2016 as per the updated FDD
    
    
    END LOOP;
  
    log_p('End of Transformation...');
  
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_retcode := 2;
      p_errbuf  := 'Unexpected error in inserting Value to so_line_extract.';
      log_p('Unexpected error in inserting Value to so_line_extract in step : ' ||
            l_step || ' - ' || SQLERRM);
      log_p(dbms_utility.format_error_backtrace);
    
  END so_line_extract;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Hold Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_hold_extract(p_retcode OUT VARCHAR2
                           ,p_errbuf  OUT VARCHAR2) AS
  
  
  
    l_step     VARCHAR2(200);
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(1000);
  
    CURSOR c_so_hold IS
      SELECT DISTINCT ooha.order_number
                     ,ooho.header_id
                     ,ooho.line_id
                     ,ohd.NAME hold_name
                     ,ohsa.hold_id
                     ,ohsa.hold_entity_code
                     ,ohsa.hold_entity_id
                     ,ohsa.hold_comment
      -- ,ooho.released_flag
      FROM oe_order_holds_all   ooho
          ,oe_order_headers_all ooha
          ,oe_hold_sources_all  ohsa
          ,oe_hold_definitions  ohd
          ,fnd_lookup_values_vl flv
      WHERE ooho.header_id = ooha.header_id
      AND ooho.hold_source_id = ohsa.hold_source_id
      AND ohsa.hold_id = ohd.hold_id
      AND ohsa.hold_entity_code = flv.lookup_code
      AND flv.lookup_type = 'HOLD_ENTITY_DESC'
      AND ooho.line_id IS NULL
      AND ooho.released_flag = 'N'
      AND ooha.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
      AND ooha.header_id IN (SELECT header_id
                            FROM xxobjt.xxs3_otc_so_header
                            WHERE process_flag != 'R')
      UNION
      SELECT DISTINCT ooha.order_number
                     ,ooho.header_id
                     ,ooho.line_id
                     ,ohd.NAME hold_name
                     ,ohsa.hold_id
                     ,ohsa.hold_entity_code
                     ,ohsa.hold_entity_id
                     ,ohsa.hold_comment
      --  ,ooho.released_flag
      FROM oe_order_holds_all   ooho
          ,oe_order_headers_all ooha
          ,oe_hold_sources_all  ohsa
          ,oe_hold_definitions  ohd
          ,fnd_lookup_values_vl flv
          ,oe_order_lines_all   oola
      WHERE ooho.header_id = ooha.header_id
      AND ooho.header_id = oola.header_id
      AND ooho.line_id = oola.line_id
      AND ooho.hold_source_id = ohsa.hold_source_id
      AND ohsa.hold_id = ohd.hold_id
      AND ohsa.hold_entity_code = flv.lookup_code
      AND flv.lookup_type = 'HOLD_ENTITY_DESC'
      AND ooho.line_id IS NOT NULL
      AND ooho.released_flag = 'N'
      AND oola.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
      AND ooha.header_id IN (SELECT header_id
                            FROM xxobjt.xxs3_otc_so_header
                            WHERE process_flag != 'R');
  
  
  BEGIN
  
    p_retcode := '0';
    p_errbuf  := 'SUCCESS';
  
  
    log_p('Truncating Sales order holds table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_so_hold';
  
  
    FOR i IN c_so_hold
    LOOP
    
      BEGIN
        INSERT INTO xxs3_otc_so_hold
          (xx_so_hold_id
          ,date_extracted_on
          ,process_flag
          ,order_number
          ,header_id
          ,line_id
          ,hold_name
          ,hold_id
          ,hold_entity_code
          ,hold_entity_id
          ,hold_comment)
        -- ,released_flag)
        VALUES
        
          (xxs3_otc_so_hold_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.order_number
          ,i.header_id
          ,i.line_id
          ,i.hold_name
          ,i.hold_id
          ,i.hold_entity_code
          ,i.hold_entity_id
          ,i.hold_comment);
        --,i.released_flag);
      
      EXCEPTION
        WHEN OTHERS THEN
          p_errbuf := 'Error in Inserting into the table ' || SQLERRM;
        
          log_p(p_errbuf);
        
      END;
    
    END LOOP;
  
    /* EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_retcode := 2;
      p_errbuf  := 'Unexpected error in inserting Value to so_hold_extract Error: ' ||
                   SQLERRM || dbms_utility.format_error_backtrace;
      log_p('Unexpected error in inserting Value to so_hold_extract Error: ' ||
            SQLERRM);
      log_p(dbms_utility.format_error_backtrace);*/
  
  
  
    --------- Transformation ---------  
    log_p('Starting Transformation...');
  
    FOR j IN (SELECT xx_so_hold_id
                    ,hold_name
              FROM xxobjt.xxs3_otc_so_hold)
    LOOP
    
      BEGIN
      
        log_p('Legacy Hold value : ' || j.hold_name);
        l_step := 'Sales Order Hold Name Transformation';
        IF j.hold_name IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'so_hold_name', p_stage_tab => 'XXS3_OTC_SO_HOLD', --Staging Table Name
                                                 p_stage_primary_col => 'xx_so_hold_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => j.xx_so_hold_id, --Staging Table Primary Column Value
                                                 p_legacy_val => j.hold_name, --Legacy Value
                                                 p_stage_col => 's3_hold_name', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
      
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          log_p('Unexpected error while transfomring Sales order hold in step : ' ||
                l_step || ' - ' || SQLERRM);
          log_p(dbms_utility.format_error_backtrace);
        
      END;
    
    
      COMMIT;
    
    END LOOP;
  
  
  END so_hold_extract;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Price Adjustment Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_price_adjus_extract(p_retcode OUT VARCHAR2
                                  ,p_errbuf  OUT VARCHAR2) AS
  
    CURSOR c_so_price_adjus IS
    /*SELECT DISTINCT ooha.order_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               AND opa.line_id = oola.line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                AND ooha.order_number IN 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                (SELECT order_number FROM xxs3_otc_so_header);*/
      SELECT DISTINCT ooha.order_number
                     ,oola.header_id
                     ,oola.line_id
                     ,qslhv.NAME modifier_no
                     ,qslhv.description modifier_name
                     ,opa.adjusted_amount
                     ,opa.applied_flag
                     ,opa.change_reason_code
                     ,opa.change_reason_text
                     ,opa.list_line_id
                     ,opa.list_line_type_code
                     ,opa.modifier_level_code
                     ,opa.operand
                     ,opa.arithmetic_operator
      FROM qp_secu_list_headers_vl qslhv
          ,oe_price_adjustments    opa
          ,oe_order_headers_all    ooha
          ,oe_order_lines_all      oola
      WHERE opa.list_header_id = qslhv.list_header_id
      AND opa.header_id = ooha.header_id
      AND ooha.header_id = oola.header_id
      AND opa.line_id = oola.line_id
      AND ooha.header_id IN
            (SELECT header_id FROM xxs3_otc_so_header WHERE process_flag != 'R');
  
  
  BEGIN
  
    p_retcode := '0';
    p_errbuf  := 'SUCCESS';
  
  
    log_p('Truncating Sales order price adjustment table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_so_price_adjus';
  
  
    FOR i IN c_so_price_adjus
    LOOP
    
      BEGIN
        INSERT INTO xxs3_otc_so_price_adjus
          (xx_so_price_adjus_id
          ,date_extracted_on
          ,process_flag
          ,order_number
          ,header_id
          ,line_id
           -- ,modifier_no
          ,modifier_name
          ,adjusted_amount
          ,applied_flag
          ,change_reason_code
          ,change_reason_text
          ,list_line_id
          ,list_line_type_code
          ,modifier_level_code
          ,operand
          ,arithmetic_operator)
        
        VALUES
          (xxs3_otc_so_price_adjus_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.order_number
          ,i.header_id
          ,i.line_id
           --   ,i.modifier_no
          ,i.modifier_name
          ,i.adjusted_amount
          ,i.applied_flag
          ,i.change_reason_code
          ,i.change_reason_text
          ,i.list_line_id
          ,i.list_line_type_code
          ,i.modifier_level_code
          ,i.operand
          ,i.arithmetic_operator);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          p_errbuf := 'Error in Inserting into the table ' || SQLERRM;
        
          log_p(p_errbuf);
        
      END;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_retcode := 2;
      p_errbuf  := 'Unexpected error in inserting Value to so_price_adjus_extract.';
      log_p('Unexpected error in inserting Value to so_price_adjus_extract Error: ' ||
            SQLERRM);
      log_p(dbms_utility.format_error_backtrace);
    
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Attachment Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------


  PROCEDURE so_attachment_extract(p_retcode OUT VARCHAR2
                                 ,p_errbuf  OUT VARCHAR2) AS
  
    CURSOR c_so_attachment IS
      SELECT DISTINCT ooha.order_number
                     ,'Order Header' AS SOURCE
                     ,ooha.header_id
                     ,NULL AS line_id
                     ,NULL AS line_number
                     ,(SELECT account_number
                       FROM hz_cust_accounts hca
                       WHERE ooha.sold_to_org_id = hca.cust_account_id) customer_number
                     ,ooha.cust_po_number
                     ,fadf.seq_num
                     ,fadf.category_description
                     ,fdst.short_text
      FROM fnd_attached_docs_form_vl fadf
          ,fnd_documents_short_text  fdst
          ,oe_order_headers_all      ooha
          ,oe_order_lines_all        oola
      WHERE fadf.media_id = fdst.media_id
      AND ooha.header_id = oola.header_id
      AND fadf.pk1_value = to_char(ooha.header_id)
      AND fadf.entity_name = 'OE_ORDER_HEADERS'
      AND ooha.org_id = 737
      AND ooha.header_id IN
            (SELECT header_id FROM xxs3_otc_so_header WHERE process_flag != 'R')
      
      UNION
      
      SELECT DISTINCT ooha.order_number
                     ,'Order Line' AS SOURCE
                     ,ooha.header_id
                     ,oola.line_id
                     ,oola.line_number
                     ,(SELECT account_number
                       FROM hz_cust_accounts hca
                       WHERE ooha.sold_to_org_id = hca.cust_account_id) customer_number
                     ,ooha.cust_po_number
                     ,fadf.seq_num
                     ,fadf.category_description
                     ,fdst.short_text
      FROM fnd_attached_docs_form_vl fadf
          ,fnd_documents_short_text  fdst
          ,oe_order_headers_all      ooha
          ,oe_order_lines_all        oola
      WHERE fadf.media_id = fdst.media_id
      AND ooha.header_id = oola.header_id
      AND fadf.pk1_value = to_char(oola.line_id)
      AND fadf.entity_name = 'OE_ORDER_LINES'
      AND ooha.org_id = 737
      AND ooha.header_id IN
            (SELECT header_id FROM xxs3_otc_so_header WHERE process_flag != 'R');
  
    -- Added on 26-OCT-2016
  
  
    -- Commented on 26-OCT-2016
  
    /* SELECT DISTINCT c.order_number
                   ,c.header_id
                   ,c.customer_number
                   ,c.cust_po_number
                   ,c.order_number
                   ,a.seq_num
                   ,a.category_description
                   ,b.short_text
    FROM fnd_attached_docs_form_vl fadf
        ,fnd_documents_short_text  fdst
        ,xxs3_otc_so_header        xosh
    WHERE fadf.media_id = fdst.media_id
    AND fadf.pk1_value = to_char(xosh.header_id)
    ORDER BY 1;*/
  
  
  BEGIN
  
    p_retcode := '0';
    p_errbuf  := 'SUCCESS';
  
  
    log_p('Truncating Sales order attachments table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_so_attachments';
  
  
    FOR i IN c_so_attachment
    LOOP
    
      BEGIN
        INSERT INTO xxobjt.xxs3_otc_so_attachments
          (xx_so_attachment_id
          ,process_flag
          ,date_extracted_on
          ,order_number
          ,SOURCE
          ,header_id
          ,line_id
          ,line_number
          ,customer_number
          ,cust_po_number
          ,seq_num
          ,category_description
          ,short_text)
        
        VALUES
          (xxobjt.xxs3_otc_so_attachments_seq.NEXTVAL
          ,'N'
          ,SYSDATE
          ,i.order_number
          ,i.SOURCE
          ,i.header_id
          ,i.line_id
          ,i.line_number
          ,i.customer_number
          ,i.cust_po_number
          ,i.seq_num
          ,i.category_description
          ,i.short_text);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          p_errbuf := 'Error in Inserting into the table for order_number :  ' ||
                      i.order_number || ' - ' || SQLERRM;
        
          log_p(p_errbuf);
        
      END;
    
    END LOOP;
  
  END;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Header and Line Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_transform_report(p_entity VARCHAR2) IS
  
    CURSOR c_report_soh IS
      SELECT xsh.xx_so_header_id
            ,xsh.order_number
            ,xsh.order_type
            ,xsh.s3_order_type
            ,xsh.price_list
            ,xsh.s3_price_list
            ,xsh.ship_from_org_code
            ,xsh.s3_ship_from_org_code
            ,xsh.freight_terms_code
            ,xsh.s3_freight_terms_code
            ,xsh.freight_term_meaning
            ,xsh.s3_incoterms
            ,xsh.inco_term_meaning
            ,xsh.transform_status
            ,xsh.transform_error
      FROM xxs3_otc_so_header xsh
      WHERE xsh.transform_status IN ('PASS', 'FAIL');
  
  
    CURSOR c_report_sol IS
      SELECT xsl.xx_so_line_id
            ,xsl.order_number
            ,xsl.line_number
            ,xsl.price_list
            ,xsl.s3_price_list
            ,xsl.ship_from_org
            ,xsl.s3_ship_from_org
             --   ,xsl.shipping_method_code  -- Commented on 20-OCT-2016 as per updated FDD
             --  ,xsl.s3_shipping_method_code -- Commented on 20-OCT-2016 as per updated FDD
            ,xsl.order_type
            ,xsl.s3_order_type
            ,xsl.line_type
            ,xsl.s3_line_type
            ,xsl.freight_terms_code
            ,xsl.s3_freight_terms_code
            ,xsl.freight_term_meaning
            ,xsl.s3_incoterms
            ,xsl.inco_term_meaning
            ,xsl.transform_status
            ,xsl.transform_error
      FROM xxs3_otc_so_line xsl
      WHERE xsl.transform_status IN ('PASS', 'FAIL');
  
  
  
    CURSOR c_report_soho IS
      SELECT xhl.xx_so_hold_id
            ,xhl.order_number
            ,xhl.line_id
            ,xhl.hold_name
            ,xhl.s3_hold_name
            ,xhl.transform_status
            ,xhl.transform_error
      FROM xxs3_otc_so_hold xhl
      WHERE xhl.transform_status IN ('PASS', 'FAIL');
  
    p_delimiter     VARCHAR2(5) := '~';
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
  
  BEGIN
  
  
    IF p_entity = 'SALES_ORDER_HEADER'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_so_header xsh
      WHERE xsh.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_so_header xsh
      WHERE xsh.transform_status = 'FAIL';
    
      out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
      out_p(rpad('========================================' || p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 30, ' ') || p_delimiter ||
            rpad('XX_SO_HEADER_ID', 20, ' ') || p_delimiter ||
            rpad('Order_Number', 30, ' ') || p_delimiter ||
            rpad('Order_Type', 100, ' ') || p_delimiter ||
            rpad('S3_Order_Type', 100, ' ') || p_delimiter ||
            rpad('Price_List', 50, ' ') || p_delimiter ||
            rpad('S3_Price_List', 50, ' ') || p_delimiter ||
            rpad('ship_from_org_code', 25, ' ') || p_delimiter ||
            rpad('S3_ship_from_org_code', 30, ' ') || p_delimiter ||
            rpad('freight_terms_code', 25, ' ') || p_delimiter ||
            rpad('S3_freight_terms_code', 25, ' ') || p_delimiter ||
            rpad('freight_terms_meaning', 50, ' ') || p_delimiter ||
            rpad('S3_incoterms', 25, ' ') || p_delimiter ||
            rpad('inco_terms_meaning', 50, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR r_data IN c_report_soh
      LOOP
        out_p(rpad('OTC', 10, ' ') || p_delimiter ||
              rpad('SALES_ORDER_HEADER', 30, ' ') || p_delimiter ||
              rpad(r_data.xx_so_header_id, 20, ' ') || p_delimiter ||
              rpad(r_data.order_number, 30, ' ') || p_delimiter ||
              rpad(r_data.order_type, 100, ' ') || p_delimiter ||
              rpad(r_data.s3_order_type, 100, ' ') || p_delimiter ||
              rpad(r_data.price_list, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_price_list, 50, ' ') || p_delimiter ||
              rpad(r_data.ship_from_org_code, 25, ' ') || p_delimiter ||
              rpad(r_data.s3_ship_from_org_code, 30, ' ') || p_delimiter ||
              rpad(r_data.freight_terms_code, 25, ' ') || p_delimiter ||
              rpad(r_data.s3_freight_terms_code, 25, ' ') || p_delimiter ||
              rpad(r_data.freight_term_meaning, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_incoterms, 25, ' ') || p_delimiter ||
              rpad(r_data.inco_term_meaning, 50, ' ') || p_delimiter ||
              rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
              rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    
    END IF;
  
  
  
    IF p_entity = 'SALES_ORDER_LINE'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_so_line xsl
      WHERE xsl.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_so_line xsl
      WHERE xsl.transform_status = 'FAIL';
    
      out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
      out_p(rpad('========================================' || p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 20, ' ') || p_delimiter ||
            rpad('XX_SO_LINE_ID', 14, ' ') || p_delimiter ||
            rpad('Order_Number', 30, ' ') || p_delimiter ||
            rpad('Line_Number', 30, ' ') || p_delimiter ||
            rpad('Order_Type', 50, ' ') || p_delimiter ||
            rpad('S3_Order_Type', 50, ' ') || p_delimiter ||
            rpad('Line_Type', 50, ' ') || p_delimiter ||
            rpad('S3_Line_Type', 50, ' ') || p_delimiter ||
            rpad('Price_List', 50, ' ') || p_delimiter ||
            rpad('S3_Price_List', 50, ' ') || p_delimiter ||
            rpad('ship_from_org_code', 25, ' ') || p_delimiter ||
            rpad('S3_ship_from_org_code', 25, ' ') || p_delimiter ||
            --  rpad('shipping_method_code', 50, ' ') || p_delimiter ||   -- Commented on 20-OCT-2016 as per updated FDD
            --  rpad('S3_shipping_method_code', 50, ' ') || p_delimiter ||  -- Commented on 20-OCT-2016 as per updated FDD
            rpad('freight_terms_code', 25, ' ') || p_delimiter ||
            rpad('S3_freight_terms_code', 25, ' ') || p_delimiter ||
            rpad('freight_terms_meaning', 50, ' ') || p_delimiter ||
            rpad('S3_incoterms', 25, ' ') || p_delimiter ||
            rpad('inco_terms_meaning', 50, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR r_data IN c_report_sol
      LOOP
        out_p(rpad('OTC', 10, ' ') || p_delimiter ||
              rpad('SALES_ORDER_LINE', 20, ' ') || p_delimiter ||
              rpad(r_data.xx_so_line_id, 14, ' ') || p_delimiter ||
              rpad(r_data.order_number, 30, ' ') || p_delimiter ||
              rpad(r_data.line_number, 10, ' ') || p_delimiter ||
              rpad(r_data.order_type, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_order_type, 50, ' ') || p_delimiter ||
              rpad(r_data.line_type, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_line_type, 50, ' ') || p_delimiter ||
              rpad(r_data.price_list, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_price_list, 50, ' ') || p_delimiter ||
              rpad(r_data.ship_from_org, 25, ' ') || p_delimiter ||
              rpad(r_data.s3_ship_from_org, 25, ' ') || p_delimiter ||
              --   rpad(r_data.shipping_method_code, 50, ' ') || p_delimiter || -- Commented on 20-OCT-2016 as per updated FDD
              --  rpad(r_data.s3_shipping_method_code, 50, ' ') || p_delimiter || -- Commented on 20-OCT-2016 as per updated FDD
              rpad(r_data.freight_terms_code, 25, ' ') || p_delimiter ||
              rpad(r_data.s3_freight_terms_code, 25, ' ') || p_delimiter ||
              rpad(r_data.freight_term_meaning, 50, ' ') || p_delimiter ||
              rpad(r_data.s3_incoterms, 25, ' ') || p_delimiter ||
              rpad(r_data.inco_term_meaning, 50, ' ') || p_delimiter ||
              rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
              rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
  
  
    IF p_entity = 'SALES_ORDER_HOLDS'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_so_hold xhl
      WHERE xhl.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_so_hold xhl
      WHERE xhl.transform_status = 'FAIL';
    
      out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
      out_p(rpad('========================================' || p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 30, ' ') || p_delimiter ||
            rpad('XX_SO_HOLD_ID', 20, ' ') || p_delimiter ||
            rpad('Order_Number', 30, ' ') || p_delimiter ||
            rpad('Hold_Name', 100, ' ') || p_delimiter ||
            rpad('S3_Hold_Name', 100, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
      FOR r_data IN c_report_soho
      LOOP
        out_p(rpad('OTC', 10, ' ') || p_delimiter ||
              rpad('SALES_ORDER_HOLDS', 30, ' ') || p_delimiter ||
              rpad(r_data.xx_so_hold_id, 20, ' ') || p_delimiter ||
              rpad(r_data.order_number, 30, ' ') || p_delimiter ||
              rpad(r_data.hold_name, 100, ' ') || p_delimiter ||
              rpad(r_data.s3_hold_name, 100, ' ') || p_delimiter ||
              rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
              rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    
    END IF;
  
  
  END so_transform_report;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Header Cleanse Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/10/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------


  PROCEDURE so_cleanse_report(p_entity VARCHAR2) IS
  
    CURSOR c_report_soh IS
      SELECT xsh.xx_so_header_id
            ,xsh.order_number
            ,xsh.salesrep
            ,xsh.s3_salesrep
            ,xsh.cleanse_status
            ,xsh.cleanse_error
      FROM xxs3_otc_so_header xsh
      WHERE xsh.cleanse_status IN ('PASS', 'FAIL');
  
  
  
    CURSOR c_report_sol IS
      SELECT xsl.xx_so_line_id
            ,xsl.order_number
            ,xsl.line_number
            ,xsl.calculate_price_flag
            ,xsl.s3_calculate_price_flag
            ,xsl.cleanse_status
            ,xsl.cleanse_error
      FROM xxs3_otc_so_line xsl
      WHERE xsl.cleanse_status IN ('PASS', 'FAIL');
  
  
  
    p_delimiter     VARCHAR2(5) := '~';
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
  BEGIN
  
    IF p_entity = 'SALES_ORDER_HEADER'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_so_header xsh
      WHERE xsh.cleanse_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_so_header xsh
      WHERE xsh.cleanse_status = 'FAIL';
    
    
      out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('====================================================' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 20, ' ') || p_delimiter ||
            rpad('XX_SO_HEADER_ID  ', 20, ' ') || p_delimiter ||
            rpad('Order_Number', 15, ' ') || p_delimiter ||
            rpad('Salesrep', 100, ' ') || p_delimiter ||
            rpad('S3_Salesrep', 100, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
    
    
      FOR r_data IN c_report_soh
      LOOP
        out_p(rpad('OTC', 10, ' ') || p_delimiter ||
              rpad('SALES_ORDER_HEADER', 20, ' ') || p_delimiter ||
              rpad(r_data.xx_so_header_id, 14, ' ') || p_delimiter ||
              rpad(r_data.order_number, 15, ' ') || p_delimiter ||
              rpad(r_data.salesrep, 100, ' ') || p_delimiter ||
              rpad(r_data.s3_salesrep, 100, ' ') || p_delimiter ||
              rpad(r_data.cleanse_status, 10, ' ') || p_delimiter ||
              rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
      
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
  
    IF p_entity = 'SALES_ORDER_LINE'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_so_line xsl
      WHERE xsl.cleanse_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_so_line xsl
      WHERE xsl.cleanse_status = 'FAIL';
    
    
      out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('====================================================' ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Data Migration Object Name = ' || p_entity ||
                 p_delimiter, 100, ' '));
      out_p('');
      out_p(rpad('Run date and time:    ' ||
                 to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Success = ' || l_count_success ||
                 p_delimiter, 100, ' '));
      out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
                 p_delimiter, 100, ' '));
    
      out_p('');
    
      out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
            rpad('Entity Name', 20, ' ') || p_delimiter ||
            rpad('XX_SO_LINE_ID  ', 20, ' ') || p_delimiter ||
            rpad('Order_Number', 15, ' ') || p_delimiter ||
            rpad('Line_Number', 15, ' ') || p_delimiter ||
            rpad('calculate_price_flag', 25, ' ') || p_delimiter ||
            rpad('S3_calculate_price_flag', 25, ' ') || p_delimiter ||
            rpad('Status', 10, ' ') || p_delimiter ||
            rpad('Error Message', 200, ' '));
    
    
    
      FOR r_data IN c_report_sol
      LOOP
        out_p(rpad('OTC', 10, ' ') || p_delimiter ||
              rpad('SALES_ORDER_HEADER', 20, ' ') || p_delimiter ||
              rpad(r_data.xx_so_line_id, 14, ' ') || p_delimiter ||
              rpad(r_data.order_number, 15, ' ') || p_delimiter ||
              rpad(r_data.line_number, 15, ' ') || p_delimiter ||
              rpad(r_data.calculate_price_flag, 25, ' ') || p_delimiter ||
              rpad(r_data.s3_calculate_price_flag, 25, ' ') || p_delimiter ||
              rpad(r_data.cleanse_status, 10, ' ') || p_delimiter ||
              rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
      
      END LOOP;
    
      out_p('');
      out_p('Stratasys Confidential' || p_delimiter);
    
    END IF;
  
  
  END so_cleanse_report;

END xxs3_otc_so_pkg;
/
