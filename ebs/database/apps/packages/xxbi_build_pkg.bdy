CREATE OR REPLACE PACKAGE BODY xxbi_build_pkg AS

-- ---------------------------------------------------------------------------------
-- Name:  xxbi_build_pkg     
-- Created By: John Hendrickson
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Used for populating BI tables
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG?????.
-- ---------------------------------------------------------------------------------

   /********************************************************************************
    This procedure first deletes, then re-inserts revenue
    facts to the XX_REVENUE_FACT table for a General
    Ledger Period.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/
   PROCEDURE build_revenue_fact(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   ,  p_period_name  IN VARCHAR2
   )
   IS
      l_delete_count NUMBER   := 0;
      l_insert_count NUMBER   := 0;
   BEGIN
   
   
      DELETE FROM XXBI.XX_REVENUE_FACT 
      WHERE period_name = p_period_name;
      
      l_delete_count := SQL%ROWCOUNT;

      INSERT INTO xxbi.xx_revenue_fact
      ( party_id
        ,party_account_id
        ,party_site_id
        ,customer_number
        ,customer_name
        ,customer_short_name
        ,gl_date
        ,period_name
        ,currency_code
        ,transaction_source
        ,amount
        ,xla_amount
        ,gl_segment1
        ,gl_segment2
        ,gl_segment3
        ,gl_segment4
        ,gl_segment5
        ,gl_segment6
        ,code_combination_id
        ,xla_code_combination_id
        ,ledger_id
        ,chart_of_accounts_id
        ,org_id
        ,transaction_number
        ,transaction_type
        ,transaction_line_number
        ,inventory_item_id
        ,sales_order_number
        ,oe_line_id
        ,oe_line_number
        ,is_vsoe_flag
        ,rule_start_date
        ,line_extended_amount
        ,line_revenue_amount
        ,base_currency_code
        ,base_amount
        ,usd_amount
        ,uom_code
        ,quantity_ordered 
        ,quantity_credited
        ,quantity_invoiced
        ,ship_to_customer_name
        ,ship_to_customer_number
        ,ship_to_cust_acct_site_id
        ,ship_to_customer_site_use_id
        ,ship_to_customer_country_code
        ,ship_to_customer_state
        ,bill_to_customer_name
        ,bill_to_customer_number
        ,bill_to_cust_acct_site_id
        ,bill_to_customer_site_use_id
        ,bill_to_customer_country_code
        ,bill_to_customer_state   )
      (SELECT
         party_id
        ,party_account_id
        ,party_site_id
        ,customer_number
        ,customer_name
        ,customer_short_name
        ,gl_date
        ,period_name
        ,currency_code
        ,transaction_source
        ,amount
        ,xla_amount
        ,gl_segment1
        ,gl_segment2
        ,gl_segment3
        ,gl_segment4
        ,gl_segment5
        ,gl_segment6
        ,code_combination_id
        ,xla_code_combination_id
        ,ledger_id
        ,chart_of_accounts_id
        ,org_id
        ,transaction_number
        ,transaction_type
        ,transaction_line_number
        ,nvl(inventory_item_id,0)
        ,sales_order_number
        ,nvl(oe_line_id,0)
        ,oe_line_number
        ,is_vsoe_flag
        ,rule_start_date
        ,line_extended_amount
        ,line_revenue_amount
        ,base_currency_code
        ,base_amount
        ,usd_amount
        ,uom_code
        ,quantity_ordered 
        ,quantity_credited
        ,quantity_invoiced
        ,ship_to_customer_name
        ,ship_to_customer_number
        ,ship_to_cust_acct_site_id
        ,nvl(ship_to_customer_site_use_id,0)
        ,nvl(ship_to_customer_country_code,'XX')
        ,ship_to_customer_state
        ,bill_to_customer_name
        ,bill_to_customer_number
        ,bill_to_cust_acct_site_id
        ,nvl(bill_to_customer_site_use_id,0)
        ,nvl(bill_to_customer_country_code,'XX')
        ,bill_to_customer_state   
      FROM   xxbi.xx_revenue_v
      WHERE  period_name = p_period_name);
      
      l_insert_count := SQL%ROWCOUNT;
      
      fnd_file.put_line(fnd_file.output,'Record Counts for build_revenue_fact');
      fnd_file.put_line(fnd_file.output,'************************************');
      fnd_file.put_line(fnd_file.output,'Records Deleted  : '||l_delete_count);
      fnd_file.put_line(fnd_file.output,'Records Inserted : '||l_insert_count);
   EXCEPTION
      WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.output,'Error in build_revenue_fact '||DBMS_UTILITY.FORMAT_ERROR_STACK);
          x_retcode := 2;
   END build_revenue_fact;
 
     /********************************************************************************
    This procedure deletes from the XX_REVENUE_FACT table for a given Year.  
    Assumption is that this program will run under concurrent manager 
    standard report submission.  YEAR is required, and validated
    via standard report submission.
   *********************************************************************************/   
  PROCEDURE purge_revenue_fact(
      x_errbuf       OUT VARCHAR2
   ,  x_retcode      OUT NUMBER
   ,  p_year         IN NUMBER
   )
   IS
      l_delete_count NUMBER   := 0;
   BEGIN
   
   DELETE FROM  xxbi.xx_revenue_fact
   WHERE trunc(gl_date) in
      (SELECT period_day
       FROM   xxbi.xxgl_periods_v
       WHERE  period_year = p_year);
       
      l_delete_count := SQL%ROWCOUNT;
      
      fnd_file.put_line(fnd_file.output,'Record Counts for purge_revenue_fact');
      fnd_file.put_line(fnd_file.output,'************************************');
      fnd_file.put_line(fnd_file.output,'Records Deleted  : '||l_delete_count);
   EXCEPTION
      WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.output,'Error in purge_revenue_fact '||DBMS_UTILITY.FORMAT_ERROR_STACK);
          x_retcode := 2;
   END purge_revenue_fact;

    /********************************************************************************
    This procedure first deletes, then re-inserts coste
    facts to the XXMTL_COSTS_FACT table for a General
    Ledger Period.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/   
   PROCEDURE build_cost_fact(
    x_errbuf OUT VARCHAR2 ,
    x_retcode OUT NUMBER ,
    p_period_name IN VARCHAR2 )
IS
  l_delete_count NUMBER := 0;
  l_insert_count NUMBER := 0;
BEGIN

  DELETE
  FROM xxbi.xxmtl_costs_fact
  WHERE TRUNC(transaction_date) IN
    (SELECT period_day FROM xxbi.xxgl_periods_v WHERE period_name = p_period_name
    );
    
  l_delete_count := SQL%ROWCOUNT;
  
  INSERT
  INTO xxbi.xxmtl_costs_fact
    (SELECT transaction_source ,
        code_combination_id ,
        ledger_id ,
        chart_of_account_id ,
        org_id ,
        transaction_id ,
        inventory_item_id ,
        organization_id ,
        TRUNC(transaction_date) AS transaction_date ,
        transaction_source_id ,
        transaction_source_type_id ,
        transaction_source_type_name ,
        primary_quantity ,
        gl_batch_id ,
        accounting_line_type ,
        base_transaction_value ,
        ledger_currency_code ,
        usd_cogs_amount ,
        rate_or_amount ,
        gl_sl_link_id ,
        subinventory_code ,
        locator_id ,
        h_transaction_type_id ,
        h_transaction_action_id ,
        h_transaction_source_type_id ,
        h_transaction_source_id ,
        h_transaction_quantity ,
        h_transaction_uom ,
        h_primary_quantity ,
        h_transaction_date ,
        h_acct_period_id ,
        mso_sales_order_id ,
        mso_segment1 ,
        mso_segment2 ,
        mso_segment3 ,
        ship_to_customer_site_use_id ,
        bill_to_customer_site_use_id ,
        oe_order_header_id ,
        oe_order_line_id ,
        NVL(oe_line_inventory_item_id,0)
      FROM xxbi.xxmtl_costs_v xcv ,
        apps.gl_periods gp
      WHERE gp.period_name = p_period_name
      AND gl_segment3     IN ('501050','501055')
      AND xcv.transaction_date BETWEEN gp.start_date AND TO_DATE(TO_CHAR(gp.end_date,'DD-MON-YYYY')
        ||' 23:59:59','DD-MON-YYYY HH24:MI:SS')
    );
    
  l_insert_count := SQL%ROWCOUNT;
 
  fnd_file.put_line(fnd_file.output,'Record Counts for build_cost_fact');
  fnd_file.put_line(fnd_file.output,'************************************');
  fnd_file.put_line(fnd_file.output,'Records Deleted  : '||l_delete_count);
  fnd_file.put_line(fnd_file.output,'Records Inserted : '||l_insert_count);

EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.output,'Error in build_cost_fact '||DBMS_UTILITY.FORMAT_ERROR_STACK);
  x_retcode := 2;

END build_cost_fact; 

      /********************************************************************************
    This procedure first deletes, then re-inserts all GL Periods
    to the XXGL_PERIODS_T table.  Assumption is that this program will
    run under concurrent manager standard report
    submission.  Period name is required, and validated
    via standard report submission.
   *********************************************************************************/
   PROCEDURE build_gl_periods(
    x_errbuf OUT VARCHAR2 ,
    x_retcode OUT NUMBER     )
IS
  l_delete_count NUMBER := 0;
  l_insert_count NUMBER := 0;
BEGIN

  DELETE
  FROM xxbi.xxgl_periods_t;
    
  l_delete_count := SQL%ROWCOUNT;
  
INSERT
INTO xxbi.xxgl_periods_t
  (SELECT period_set_name ,
      period_day ,
      period_name ,
      period_start_date ,
      period_end_date ,
      period_year ,
      period_number ,
      period_year_name ,
      quarter_number ,
      quarter_name ,
      quarter_year_name ,
      month_name ,
      quarter_rank
    FROM xxbi.xxgl_periods_v
  );
    
  l_insert_count := SQL%ROWCOUNT;
 
  fnd_file.put_line(fnd_file.output,'Record Counts for build_gl_periods');
  fnd_file.put_line(fnd_file.output,'************************************');
  fnd_file.put_line(fnd_file.output,'Records Deleted  : '||l_delete_count);
  fnd_file.put_line(fnd_file.output,'Records Inserted : '||l_insert_count);

EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.output,'Error in build_gl_periods '||DBMS_UTILITY.FORMAT_ERROR_STACK);
  x_retcode := 2;

END build_gl_periods; 

END xxbi_build_pkg;

/
SHOW ERRORS

