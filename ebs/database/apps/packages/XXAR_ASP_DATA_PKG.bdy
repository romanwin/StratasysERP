CREATE OR REPLACE PACKAGE BODY "APPS"."XXAR_ASP_DATA_PKG" IS
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   14/10/2020      yuval tal            CHG0048628 - initial 
  --------------------------------------------------------------------

  PROCEDURE logger(p_log_line VARCHAR2) IS
    l_msg VARCHAR2(4000);
  BEGIN
    IF TRIM(p_log_line) IS NOT NULL OR p_log_line != chr(10) THEN
      l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
	   p_log_line;
    END IF;
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(substr(l_msg, 1, 250));
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  END logger;
  --------------------------------------------------------------------
  --  Name :      populate_date
  --  fill custom table , later soa will pick data and sync it to sfdc
  -- called from : XX AR Calc Price List Average Selling Price/XXARCALCASP

  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   14/10/2020      yuval tal            CHG0048628 - initial 
  --------------------------------------------------------------------
  PROCEDURE populate_date(err_buff OUT VARCHAR2,
		  err_code OUT VARCHAR2) IS
  
  BEGIN
  
    err_code := 0;
    MERGE INTO xxar_asp_data e
    USING (SELECT qlh.list_header_id || '|' || mb.segment1 || '|' ||
                  qlh.currency_code sf_ext_key,
                  mb.inventory_item_id,
                  mb.segment1,
                  oll.price_list_id,
                  round(SUM(
                   --- Ofer 12-Nov-2020
                  case
                   when oll.item_type_code = 'MODEL' then
                    (select sum(rd.amount)
                       from oe_order_lines_all           ol,
                            ra_customer_trx_lines_all    rl,
                            ra_cust_trx_line_gl_dist_all rd
                      where ol.top_model_line_id = oll.top_model_line_id
                        and ol.header_id = oll.header_id
                        and to_char(ol.line_id) = rl.interface_line_attribute6
                        and rd.customer_trx_line_id = rl.customer_trx_line_id
                        and rd.account_set_flag = 'N'
                        and rd.account_class = 'REV')
                   else
                    (select sum(rd.amount)
                       from ra_cust_trx_line_gl_dist_all rd
                      where rd.customer_trx_line_id = rl.customer_trx_line_id
                        and rd.account_set_flag = 'N'
                        and rd.account_class = 'REV')
                 end          *
                 --- Ofer 12-Nov-2020
                            nvl(rl.quantity_invoiced, -rl.quantity_credited)) /
                        SUM(nvl(rl.quantity_invoiced, -rl.quantity_credited)),
                        2) selling_price,
                        
                        ------------
                         round(SUM(
                   --- Ofer 12-Nov-2020
                  case
                   when oll.item_type_code = 'MODEL' then
                    (select  round(sum(rd.amount*xxgl_utils_pkg.get_avg_conversion_rate(gpp.period_name,rt.invoice_currency_code)))
                       from oe_order_lines_all           ol,
                            ra_customer_trx_lines_all    rl,
                            ra_cust_trx_line_gl_dist_all rd,
                            gl_periods gpp
                      where ol.top_model_line_id = oll.top_model_line_id
                        and ol.header_id = oll.header_id
                        and to_char(ol.line_id) = rl.interface_line_attribute6
                        and rd.customer_trx_line_id = rl.customer_trx_line_id
                        and rd.account_set_flag = 'N'
                        and rd.account_class = 'REV'
                        and rd.account_class = 'REV'
                        and  gpp.period_set_name = 'OBJET_CALENDAR'
                        and rd.gl_date between gpp.start_date and gpp.end_date
                        and gpp.adjustment_period_flag='N'
                          AND gpp.period_type = '21')
                   else
                    (select  round(sum(rd.amount*xxgl_utils_pkg.get_avg_conversion_rate(gpp.period_name,rt.invoice_currency_code)))
                       from ra_cust_trx_line_gl_dist_all rd,
                            gl_periods gpp
                      where rd.customer_trx_line_id = rl.customer_trx_line_id
                        and rd.account_set_flag = 'N'
                        and rd.account_class = 'REV'
                        and rd.account_class = 'REV'
                        and  gpp.period_set_name = 'OBJET_CALENDAR'
                        and rd.gl_date between gpp.start_date and gpp.end_date
                        and gpp.adjustment_period_flag='N'
                          AND gpp.period_type = '21')
                 end          *
                 --- Ofer 12-Nov-2020
                            nvl(rl.quantity_invoiced, -rl.quantity_credited)) /
                        SUM(nvl(rl.quantity_invoiced, -rl.quantity_credited)),
                        2) asp_usd,
                        
                        -----------------
                  round(SUM(nvl(rl.attribute10, 0) *
                            nvl(rl.quantity_invoiced, -rl.quantity_credited)) /
                        SUM(nvl(rl.quantity_invoiced, -rl.quantity_credited)),
                        2) avg_avg_discount,
                  SUM(nvl(rl.quantity_invoiced, -rl.quantity_credited)) qty,
                  rt.invoice_currency_code,
                  gp.quarter_num || '-' || gp.period_year period
           
             FROM ra_customer_trx_lines_all rl,
                  ra_customer_trx_all       rt,
                  oe_order_lines_all        oll,
                  mtl_system_items_b        mb,
                  hz_cust_site_uses_all     hcu,
                  gl_code_combinations      gcc,
                  gl_periods                gp,
                  qp_list_headers           qlh,
                  ra_cust_trx_types_all     rcta
            WHERE qlh.list_header_id = oll.price_list_id
              AND rt.trx_date BETWEEN gp.quarter_start_date AND SYSDATE
              AND oll.line_id = to_char(rl.interface_line_attribute6)
              AND mb.organization_id =
                  xxinv_utils_pkg.get_master_organization_id
              AND mb.inventory_item_id = rl.inventory_item_id
              AND rt.customer_trx_id = rl.customer_trx_id
              AND trunc(SYSDATE) BETWEEN gp.start_date AND gp.end_date
              AND rl.interface_line_context = 'ORDER ENTRY'
              AND gp.period_set_name = 'OBJET_CALENDAR'
              and rcta.cust_trx_type_id=rt.cust_trx_type_id 
              and rcta.org_id=rt.org_id
              and nvl(rcta.attribute5,'N')='Y'
              AND gp.period_type = '21'
              and gp.adjustment_period_flag='N'
              AND mb.item_type NOT IN
                  (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                   fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
              AND hcu.site_use_id = rt.bill_to_site_use_id
              AND gcc.code_combination_id (+) = hcu.gl_id_rec
              AND nvl(gcc.segment7,'00') = '00'
             and xxgl_utils_pkg.set_avg_conversion_rate(to_char(gp.quarter_start_date,'MON-YY'),gp.period_name)=1
            GROUP BY qlh.list_header_id || '|' || mb.segment1 || '|' ||
                     qlh.currency_code,
                     mb.inventory_item_id,
                     mb.segment1,
                     oll.price_list_id,
                     rt.invoice_currency_code,
                     gp.quarter_num,
                     gp.period_year
           HAVING SUM(nvl(rl.quantity_invoiced,- rl.quantity_credited)) <> 0) h
    ON (e.inventory_item_id = h.inventory_item_id AND e.price_list_id = h.price_list_id AND e.period = h.period)
    WHEN MATCHED THEN
      UPDATE
      SET    e.last_update_date      = SYSDATE,
	 e.selling_price         = h.selling_price,
   e.asp_usd =h.asp_usd,
	 e.avg_avg_discount      = h.avg_avg_discount,
	 e.qty                   = h.qty,
	 e.invoice_currency_code = h.invoice_currency_code,
	 e.sf_price_line_ext_key = h.sf_ext_key,
	 e.status                = CASE
			     WHEN (e.selling_price != h.selling_price OR
			          e.avg_avg_discount != h.avg_avg_discount OR e.qty != h.qty) THEN
			      'NEW'
			     ELSE
			      e.status
			   END
      WHERE  (e.selling_price != h.selling_price OR
	 e.avg_avg_discount != h.avg_avg_discount OR e.qty != h.qty)
      
       WHEN NOT MATCHED THEN INSERT(inventory_item_id, segment1, price_list_id, selling_price,asp_usd, avg_avg_discount, qty, invoice_currency_code, period, sf_price_line_ext_key, status, creation_date) VALUES(h.inventory_item_id, h.segment1, h.price_list_id, h.selling_price,h.asp_usd, h.avg_avg_discount, h.qty, h.invoice_currency_code, h.period, h.sf_ext_key, 'NEW', SYSDATE);
    logger('Updated/Inserted :' || SQL%ROWCOUNT);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      logger(substr(SQLERRM, 1, 200));
      err_buff := 'xxar_asp_data_pkg.populate_data ' || SQLERRM;
      err_code := -2;
  END;
END xxar_asp_data_pkg;
/
