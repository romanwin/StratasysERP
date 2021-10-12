CREATE OR REPLACE PACKAGE BODY xxar_revenue_recognition_disco IS

  -- Author  : DANIEL.KATZ
  -- Created : 1/18/2010 1:27:43 PM
  -- Purpose : Revenue Recognition Disco Report

  -- Function and procedure implementations

  t_reset_date date_table_type;
  g_first_time BOOLEAN := TRUE;

  --collect the ledger ids according to security
  PROCEDURE initialize_ledger_id IS
  
  BEGIN
    SELECT asp.set_of_books_id BULK COLLECT
      INTO t_ledger_id
      FROM ar_system_parameters asp;
  
    FOR idx IN 1 .. t_ledger_id.count LOOP
      dbms_output.put_line(t_ledger_id(idx));
    END LOOP;
  
  END initialize_ledger_id;

  --special function to retreive the last period (before the end date but not before 140 days) in the GL
  --with the deferred Revenue and cogs Journals. it saves the value for each relevant ledger id according to security.
  FUNCTION set_revrecog_glstrt_date(p_segment3_rev  VARCHAR2,
                                    p_segment3_cogs VARCHAR2,
                                    p_end_date      DATE) RETURN NUMBER AS
  
  BEGIN
  
    IF g_first_time THEN
      initialize_ledger_id;
      g_first_time := FALSE;
    END IF;
  
    t_start_date := t_reset_date;
  
    BEGIN
      FOR idx IN 1 .. t_ledger_id.count LOOP
      
        SELECT MAX(gp1.start_date)
          INTO t_start_date(t_ledger_id(idx))
          FROM gl_je_headers        jh1,
               gl_je_lines          jl1,
               gl_code_combinations gcc1,
               gl_periods           gp1
         WHERE jh1.je_header_id = jl1.je_header_id
           AND jl1.code_combination_id = gcc1.code_combination_id
           AND nvl(jh1.accrual_rev_period_name, jh1.period_name) !=
               jh1.period_name
           AND jh1.je_category = '21' --XX Deferred Revenue/Cogs
           AND jh1.status = 'P'
           AND jh1.actual_flag = 'A'
           AND gcc1.segment3 IN (p_segment3_rev, p_segment3_cogs)
           AND jh1.ledger_id = t_ledger_id(idx)
           AND gp1.period_name = jh1.period_name
           AND gp1.adjustment_period_flag = 'N'
           AND gp1.period_set_name = 'OBJET_CALENDAR'
           AND gp1.start_date BETWEEN p_end_date - 140 AND p_end_date;
      
      END LOOP;
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
  
    RETURN(1);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END set_revrecog_glstrt_date;

  FUNCTION get_revrecog_glstrt_date(p_ledger_id IN NUMBER) RETURN DATE IS
  BEGIN
    RETURN(t_start_date(p_ledger_id));
  END;

  --function to get invoice balance as of date. the balance is Entered or Accounted according to the parameter (E or A).
  -- the default value is for Entered open balance.
  --the function takes into account all applications (Cash & CM) and Adjustments that were done before the 
  --as of date GL Date.
  FUNCTION get_invoice_balance(p_invoice_id        NUMBER,
                               p_as_of_date        DATE,
                               p_accounted_entered VARCHAR2 DEFAULT 'E')
    RETURN NUMBER AS
  
    l_accounted_balance NUMBER := 0;
    l_entered_balance   NUMBER := 0;
  
  BEGIN
  
    SELECT SUM(original), SUM(acctd_original)
      INTO l_entered_balance, l_accounted_balance
      FROM (SELECT nvl(SUM(aps.amount_due_original), 0) original,
                   nvl(SUM(aps.amount_due_original *
                           nvl(aps.exchange_rate, 1)),
                       0) acctd_original
              FROM ar_payment_schedules_all aps
             WHERE aps.customer_trx_id = p_invoice_id
               AND aps.gl_date <= trunc(p_as_of_date)
            UNION ALL
            --cm applied to inv or cash applied to inv/cm
            SELECT -nvl(SUM(ara.amount_applied +
                            nvl(ara.earned_discount_taken, 0) +
                            nvl(ara.unearned_discount_taken, 0)),
                        0),
                   -nvl(SUM(ara.acctd_amount_applied_to +
                            nvl(ara.acctd_earned_discount_taken, 0) +
                            nvl(ara.acctd_unearned_discount_taken, 0)),
                        0)
              FROM ar_receivable_applications_all ara
             WHERE ara.status = 'APP'
               AND ara.applied_customer_trx_id = p_invoice_id
               AND ara.gl_date <= trunc(p_as_of_date)
            UNION ALL
            --inv applied to cm   
            SELECT nvl(SUM(ara.amount_applied), 0),
                   nvl(SUM(ara.acctd_amount_applied_from), 0)
              FROM ar_receivable_applications_all ara
             WHERE ara.status = 'APP'
               AND ara.customer_trx_id = p_invoice_id
               AND ara.gl_date <= trunc(p_as_of_date)
            UNION ALL
            --adjustments
            SELECT nvl(SUM(aa.amount), 0), nvl(SUM(aa.acctd_amount), 0)
              FROM ar_adjustments_all aa
             WHERE aa.customer_trx_id = p_invoice_id
               AND aa.gl_date <= trunc(p_as_of_date)
               AND status = 'A');
  
    IF p_accounted_entered = 'A' THEN
      RETURN l_accounted_balance;
    ELSIF p_accounted_entered = 'E' THEN
      RETURN l_entered_balance;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END get_invoice_balance;

  --function to get information about applied inv / cm to current cm / invoice (by parameter)
  --the info is concatenated trx number and trx type name.
  FUNCTION get_applied_invoice_info(p_invoice_id NUMBER) RETURN VARCHAR2 AS
  
    --cm info which is applied to invoice
    CURSOR csr_applied_cm IS
      SELECT rct_applied_cm.trx_number || ', Type="' ||
             rctt_applied_cm.name || '"' applied_cm_info
        FROM ar_receivable_applications ara,
             ra_customer_trx_all        rct_applied_cm,
             ra_cust_trx_types_all      rctt_applied_cm
       WHERE ara.customer_trx_id = rct_applied_cm.customer_trx_id
         AND rct_applied_cm.cust_trx_type_id =
             rctt_applied_cm.cust_trx_type_id
         AND rct_applied_cm.org_id = rctt_applied_cm.org_id
         AND ara.application_type = 'CM'
         AND ara.applied_customer_trx_id = p_invoice_id;
  
    --inv info which is applied to cm
    CURSOR csr_applied_inv IS
      SELECT rct_applied_inv.trx_number || ', Type="' ||
             rctt_applied_inv.name || '"' applied_inv_info
        FROM ar_receivable_applications ara,
             ra_customer_trx_all        rct_applied_inv,
             ra_cust_trx_types_all      rctt_applied_inv
       WHERE ara.applied_customer_trx_id = rct_applied_inv.customer_trx_id
         AND rct_applied_inv.cust_trx_type_id =
             rctt_applied_inv.cust_trx_type_id
         AND rct_applied_inv.org_id = rctt_applied_inv.org_id
         AND ara.application_type = 'CM'
         AND ara.customer_trx_id = p_invoice_id;
  
    l_info      VARCHAR2(2000) := NULL;
    l_inv_class VARCHAR2(20);
    l_first     BOOLEAN := TRUE;
  
  BEGIN
    SELECT rctt.type
      INTO l_inv_class
      FROM ra_cust_trx_types_all rctt, ra_customer_trx_all rct
     WHERE rct.cust_trx_type_id = rctt.cust_trx_type_id
       AND rct.org_id = rctt.org_id
       AND rct.customer_trx_id = p_invoice_id;
  
    IF l_inv_class IN ('INV', 'DM') THEN
      FOR cm_info IN csr_applied_cm LOOP
        IF l_first THEN
          l_info  := cm_info.applied_cm_info;
          l_first := FALSE;
        ELSE
          l_info := l_info || chr(10) || cm_info.applied_cm_info;
        END IF;
      END LOOP;
    ELSIF l_inv_class = 'CM' THEN
      FOR inv_info IN csr_applied_inv LOOP
        IF l_first THEN
          l_info  := inv_info.applied_inv_info;
          l_first := FALSE;
        ELSE
          l_info := l_info || chr(10) || inv_info.applied_inv_info;
        END IF;
      END LOOP;
    END IF;
  
    RETURN l_info;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Multiple';
    
  END get_applied_invoice_info;

  --function to get warranty start date and set end date and service type for covered product according to serial number.
  --and customer account id (in case the serial is returned and sent to other customer with new warranty)
  --it sets global variables that are retreived later by get function (this is for performance, instead using 3 separate functions).
  FUNCTION get_set_warranty_data(p_serial VARCHAR2, p_cust_acct_id NUMBER)
    RETURN DATE AS
  
  BEGIN
  
    g_warranty_start_date := NULL;
    g_warranty_end_date   := NULL;
    g_warranty_service    := NULL;
  
    SELECT oal_product.start_date warranty_line_start_date,
           oal_product.end_date   warranty_line_end_date,
           msi_service.segment1   warranty_service
      INTO g_warranty_start_date, g_warranty_end_date, g_warranty_service
      FROM okc.okc_k_items     oki, --covered product
           okc_k_headers_all_b kh,
           oks_auth_lines_v    oal_product, -- Connects between Service Item and Covered Product     
           oks_line_details_v  ld_service, --service items     
           mtl_system_items_b  msi_service,
           csi_item_instances  ib --intall base
     WHERE oki.dnz_chr_id = ld_service.contract_id
       AND oki.jtot_object1_code = 'OKX_CUSTPROD'
       AND oki.cle_id = oal_product.id
       AND oal_product.cle_id = ld_service.line_id
       AND ld_service.object1_id1 = msi_service.inventory_item_id
       AND ld_service.object1_id2 = msi_service.organization_id
       AND oki.object1_id1 = ib.instance_id
       AND upper(oal_product.sts_code) IN ('ACTIVE', 'EXPIRED')
       AND ib.serial_number = p_serial
       AND ib.owner_party_account_id = p_cust_acct_id
       AND kh.scs_code = 'WARRANTY'
       AND kh.id = oki.dnz_chr_id
       AND kh.id = ld_service.contract_id;
  
    RETURN g_warranty_start_date;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_set_warranty_data;

  --function to get warranty end date for covered product.
  FUNCTION get_warranty_end_date RETURN DATE AS
  BEGIN
    RETURN g_warranty_end_date;
  END;

  --function to get warranty service type for covered product.
  FUNCTION get_warranty_service RETURN VARCHAR2 AS
  BEGIN
    RETURN g_warranty_service;
  END;

  --function not related to revenue recognition (it is for ar prepayment offset report)
  --gets sale order header id according to sale order number and org id.
  --it can be done in objet because the sale order number is unique (generally it doesn't have to be unique).
  FUNCTION get_order_header_id(p_order_number VARCHAR2, p_org_id NUMBER)
    RETURN NUMBER AS
  
    l_order_header_id NUMBER;
  
  BEGIN
    --currently sale order number is unique so i can use the following query by so number and org id.
    --just in case i retrieve here only 1 line.
    SELECT oh.header_id
      INTO l_order_header_id
      FROM oe_order_headers_all oh
     WHERE oh.order_number = p_order_number
       AND oh.org_id = p_org_id
       AND rownum = 1;
  
    RETURN l_order_header_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_order_header_id;
  -----------------------------------------------------
  /* Ofer Suad 12-03-2013  add ssys itmes          */
  -----------------------------------------------------

  FUNCTION is_ssys_900_item(pc_itemid NUMBER) RETURN NUMBER IS
    l_item_prod_line NUMBER := 0;
    --  change code here acording to new logic
  BEGIN
    SELECT 1
      INTO l_item_prod_line
      FROM mtl_item_categories_v mic,
           mtl_system_items_b    msib,
           mtl_categories_b      mcb
     WHERE mic.inventory_item_id = msib.inventory_item_id
       AND msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
       AND mic.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND mcb.category_id = mic.category_id
       AND mcb.attribute8 = 'FDM'
       AND mic.category_set_name = 'Main Category Set'
       AND mic.segment1 = 'Systems'
          -- and mic.SEGMENT2 = '900MC'
       AND mic.segment3 = '900MC'
       AND msib.inventory_item_id = pc_itemid;
    RETURN l_item_prod_line;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END is_ssys_900_item;
  -----------------------------------------------------
  /* Ofer Suad 12-03-2013  add ssys itmes          */
  -----------------------------------------------------

  FUNCTION is_ssys_item(pc_itemid NUMBER) RETURN NUMBER IS
    l_item_prod_line NUMBER := 0;
    --  change code here acording to new logic
  BEGIN
    SELECT 1
      INTO l_item_prod_line
      FROM mtl_item_categories_v mic,
           mtl_system_items_b    msib,
           mtl_categories_b      mcb
     WHERE mic.inventory_item_id = msib.inventory_item_id
       AND msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
       AND mic.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND mcb.category_id = mic.category_id
       AND mcb.attribute8 = 'FDM'
       AND mic.category_set_name = 'Main Category Set'
       AND msib.inventory_item_id = pc_itemid;
    RETURN l_item_prod_line;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END is_ssys_item;

END xxar_revenue_recognition_disco;
/
