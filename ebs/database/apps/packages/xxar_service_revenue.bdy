create or replace package body xxar_service_revenue is
  --------------------------------------------------------------------
  --  name:              XXAR_SERVICE_REVENUE
  --  create by:         Ofer.Suad
  --  Revision:          1.0
  --  creation date:     15/01/2012
  --  Modifications to Japan 26/06/2013
  --------------------------------------------------------------------
  --  purpose :          Conratcts from OM Accounting
  --  CHG0034524-   Ofer Suad - Fix revenue recognition of Service contract invoice credit memo  
  --------------------------------------------------------------------
  procedure move_earned_revenue(errbuf OUT VARCHAR2, retcode OUT NUMBER) is
    cursor c_inv_lines is
      select sum(nvl(rctl.amount, 0)) une_amt,
             sum(nvl(rctl.acctd_amount, 0)) act_amt, --11-10-2012 add act_amt
             decode(rla.previous_customer_trx_line_id,
                    null,
                    rla.interface_line_attribute6,
                    null) ord_line_id,
             rta.trx_number,
             rbs.name,
             rla.customer_trx_line_id,
             rla.org_id,
             rla.previous_customer_trx_line_id,
             rla.revenue_amount,
             msib.inventory_item_id,
             trunc(to_date(rla.attribute12, 'YYYY/MM/DD HH24:MI:SS')) start_date,
             trunc(to_date(rla.attribute13, 'YYYY/MM/DD HH24:MI:SS')) end_date,
             rta.invoice_currency_code
        from ra_customer_trx_lines        rla,
             mtl_system_items_b           msib,
             ra_customer_trx_all          rta,
             ra_batch_sources_all         rbs,
             RA_CUST_TRX_LINE_GL_DIST_ALL rctl
       where msib.inventory_item_id = rla.inventory_item_id
         and msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND xxar_autoinvoice_pkg.is_service_item(msib.inventory_item_id) = 1
         and rta.customer_trx_id = rla.customer_trx_id
         and rbs.batch_source_id = rta.batch_source_id
         and rla.accounting_rule_id =
             fnd_profile.VALUE('XXAR_CONTRACTS_ACCT_RULE_ID')
         and rctl.customer_trx_line_id = rla.customer_trx_line_id
         and rctl.account_class = 'UNEARN'
         and revenue_amount != 0
       group by rla.interface_line_attribute6,
                rla.customer_trx_line_id,
                rta.trx_number,
                msib.inventory_item_id,
                rbs.name,
                rla.org_id,
                rla.previous_customer_trx_line_id,
                rla.revenue_amount,
                rla.attribute12,
                rla.attribute13,
                rta.invoice_currency_code
      having abs(sum(nvl(rctl.amount, 0)) / revenue_amount) > 0.01;--CHG0034524
  
    cursor c_periods(l_from_date date, l_to_date date) is
      select start_date, end_date, period_year, period_num
        from (select gp.start_date,
                     gp.end_date,
                     gp.period_year,
                     gp.period_num
                from gl_periods gp
               where gp.period_set_name = 'OBJET_CALENDAR'
                 and ((l_from_date between gp.start_date and gp.end_date) or
                     (l_to_date between gp.start_date and gp.end_date))
                 and gp.adjustment_period_flag = 'N'
              
              union
              select gp.start_date,
                     gp.end_date,
                     gp.period_year,
                     gp.period_num
                from gl_periods gp
               where gp.period_set_name = 'OBJET_CALENDAR'
                 and gp.start_date >= l_from_date
                 and gp.end_date <= l_to_date
                 and gp.adjustment_period_flag = 'N')
       order by period_year, period_num;
  
    l_start_date        date;
    l_end_date          date;
    l_calc_from         date;
    l_calc_to           date;
    l_okc_status        okc_k_headers_all_b.sts_code%type;
    p_revenue_adj_rec   ar_revenue_adjustment_pvt.rev_adj_rec_type;
    l_return_status     VARCHAR2(100);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(1000);
    l_adjustment_id     NUMBER;
    l_adjustment_number VARCHAR2(1000);
    l_total_calc        NUMBER;
    l_cur_amt           NUMBER;
    l_rate              number;
    l_periods           number;
    l_ord_id            number;
    p_bool              BOOLEAN;
    l_cm_line_amt       number;
    l_line_amt_adjust   number;
    l_orig_amount       number;
    l_precision         number;
  begin
  
    for i in c_inv_lines loop-- 26/06/2013 - japan precision is zero
      begin
        select PRECISION
          into l_precision
          from FND_CURRENCIES c
         where c.currency_code = i.invoice_currency_code;
      exception
        when others then
          l_precision := 2;
      end;
      if i.previous_customer_trx_line_id is null then
        select nvl(sum(rctl.amount), 0)
          into l_cm_line_amt
          from RA_CUST_TRX_LINE_GL_DIST_ALL rctl,
               ra_customer_trx_lines_all    rct
         where rctl.customer_trx_line_id = rct.customer_trx_line_id
           and rct.previous_customer_trx_line_id = i.customer_trx_line_id
           and rctl.account_class = 'UNEARN';
      else
        select nvl(sum(rctl.amount), 0)
          into l_cm_line_amt
          from RA_CUST_TRX_LINE_GL_DIST_ALL rctl,
               ra_customer_trx_lines_all    rct
         where rctl.customer_trx_line_id = rct.customer_trx_line_id
           and rct.customer_trx_line_id = i.previous_customer_trx_line_id
           and rctl.account_class = 'UNEARN';
      
      end if;
    
      l_line_amt_adjust := i.une_amt + round(l_cm_line_amt);
    
      if abs(l_line_amt_adjust) > 1 then
        select -nvl(sum(nvl(amount, 0)), 0) / i.une_amt
          into l_rate
          from RA_CUST_TRX_LINE_GL_DIST_ALL rda
         where rda.customer_trx_line_id = i.customer_trx_line_id
           and rda.account_class = 'SUSPENSE';
        if i.ord_line_id is null then
        
          begin
            select rla.interface_line_attribute6
              into l_ord_id
              from ra_customer_trx_lines_all rla
             where rla.customer_trx_line_id =
                   i.previous_customer_trx_line_id;
          exception
            when others then
              p_bool := fnd_concurrent.set_completion_status('WARNING',
                                                             'Error in finding contarct for invoice ' ||
                                                             i.trx_number);
          end;
        end if;
     --  26-jun-2013 -Remove FDM - in Japan these condition wil fail
     -- take dates from att if exists 
        --if is_SSYS_item(i.inventory_item_id)=1 then
        if i.start_date is not null then
          if i.end_date is not null then
            l_start_date := i.start_date;
            l_end_date   := i.end_date;
            l_okc_status := 'SIGNED';
          else
            l_okc_status := 'NOT CREATED';
          end if;
        
        else
          begin
            /*
             ofer suad 20.03.2012 change the query to
            the correct one */
            select l1.start_date, l1.end_date, h.sts_code
              into l_start_date, l_end_date, l_okc_status
              from okc_k_headers_all_b h,
                   oks_reprocessing    okr,
                   okc_k_lines_b       l1
             where h.id = okr.contract_id
               and okr.order_line_id = nvl(i.ord_line_id, l_ord_id)
               AND h.scs_code = 'SERVICE'
               and l1.cle_id = okr.contract_line_id
               and l1.id = okr.subline_id;
          
          exception
            when no_data_found then
              l_okc_status := 'NOT CREATED';
          end;
        end if;
        --   fnd_file.PUT_LINE(fnd_file.LOG,i.trx_number||' '||l_okc_status);
      
        if l_okc_status != 'NOT CREATED' then
          select round(months_between(l_end_date, l_start_date))
            into l_periods
            from dual;
          l_total_calc := 0;
          for j in c_periods(l_start_date, l_end_date) loop
            p_revenue_adj_rec.trx_number            := i.trx_number;
            p_revenue_adj_rec.FROM_CUST_TRX_LINE_ID := i.customer_trx_line_id;
            p_revenue_adj_rec.ADJUSTMENT_TYPE       := 'EA';
            p_revenue_adj_rec.batch_source_name     := i.name;
            p_revenue_adj_rec.amount_mode           := 'A';
            p_revenue_adj_rec.gl_date               := j.end_date;
            p_revenue_adj_rec.reason_code           := 'RA';
          
            l_cur_amt := l_line_amt_adjust / l_periods;
          
            if j.start_date < l_start_date then
              l_calc_from := l_start_date;
            else
              l_calc_from := j.start_date;
            end if;
          
            if j.end_date > l_end_date then
              l_calc_to := l_end_date;
            else
              l_calc_to := j.end_date;
            end if;
          
            l_cur_amt := l_cur_amt * ((l_calc_to + 1 - l_calc_from) /
                         (j.end_date + 1 - j.start_date));
          
            /*
             ofer suad 06.05.2012 change the reminder logic
            */
          
            if l_calc_to = l_end_date then
              l_cur_amt := trunc(l_line_amt_adjust - l_total_calc, 2);
            end if;
            l_orig_amount := l_cur_amt;
            /* if abs(l_total_calc + l_cur_amt) > abs(l_line_amt_adjust) or
               abs(l_line_amt_adjust) - abs((l_total_calc + l_cur_amt)) < 1 then
              l_cur_amt := l_line_amt_adjust - l_total_calc;
            end if;*/
            l_total_calc := l_total_calc + l_cur_amt;
          
            -- l_cur_amt := round(l_cur_amt * (1 - l_rate));
          
            -- dbms_output.put_line(' l_cur_amt ' || l_cur_amt);
            P_REVENUE_ADJ_REC.AMOUNT := trunc(l_cur_amt, l_precision);
          
            dbms_output.put_line(P_REVENUE_ADJ_REC.AMOUNT);
          
            --    fnd_file.PUT_LINE(fnd_file.LOG,
            --                       l_cur_amt || ',' || l_total_calc);
            ar_revenueadjust_pub.earn_revenue(p_api_version       => 2.0,
                                              p_init_msg_list     => fnd_api.g_true,
                                              x_return_status     => l_return_status,
                                              x_msg_count         => l_msg_count,
                                              x_msg_data          => l_msg_data,
                                              p_rev_adj_rec       => p_revenue_adj_rec,
                                              p_org_id            => i.ORG_ID,
                                              x_adjustment_id     => l_adjustment_id,
                                              x_adjustment_number => l_adjustment_number);
          
            if l_msg_count != 0 then
              retcode := 1;
              errbuf  := i.ord_line_id || substr(l_msg_data, 0, 190);
              fnd_file.PUT_LINE(fnd_file.LOG,
                                'Error in line ' || i.ord_line_id || ',' ||
                                l_start_date);
              fnd_file.PUT_LINE(fnd_file.LOG, substr(l_msg_data, 0, 200));
              rollback;
              exit;
            end if;
          
            /* 05-07-2012 deal with  discount cases  */
            if l_rate != 0 or i.revenue_amount != i.une_amt then
              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.amount       = trunc(l_orig_amount, 2),
                     t.acctd_amount = trunc(l_orig_amount * i.act_amt /
                                            i.une_amt,
                                            2) --11-10-2012 add act_amt
               where t.customer_trx_line_id = i.customer_trx_line_id
                 AND t.account_class IN ('REV')
                 and t.revenue_adjustment_id = l_adjustment_id;
            
              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.amount       = -trunc(l_orig_amount, 2),
                     t.acctd_amount = -trunc(l_orig_amount * i.act_amt /
                                             i.une_amt,
                                             2) --11-10-2012 add act_amt
               where t.customer_trx_line_id = i.customer_trx_line_id
                 AND t.account_class IN ('UNEARN')
                 and t.revenue_adjustment_id = l_adjustment_id;
            end if;
            --dbms_output.put_line( l_msg_data);
          end loop;
        end if;
      end if;
      commit;
    end loop;
  
  end move_earned_revenue;
  -----------------------------------------------------
  /* Ofer Suad 21-06-2012  add ssys itmes          */
  -----------------------------------------------------
  function is_SSYS_item(PC_ItemID number) return number is
    l_item_prod_line number := 0;
    --  change code here acording to new logic
  begin
    SELECT 1
      into l_item_prod_line
      FROM MTL_ITEM_CATEGORIES_V MIC,
           mtl_system_items_b    msib,
           mtl_categories_b      mcb
     WHERE mic.INVENTORY_ITEM_ID = msib.inventory_item_id
       and msib.ORGANIZATION_ID =
           xxinv_utils_pkg.get_master_organization_id
       and mic.ORGANIZATION_ID = xxinv_utils_pkg.get_master_organization_id
       and mcb.category_id = mic.CATEGORY_ID
       and mcb.attribute8 = 'FDM'
       and mic.CATEGORY_SET_NAME = 'Main Category Set'
       and msib.inventory_item_id = PC_ItemID;
    return l_item_prod_line;
  exception
    when others then
      return 0;
    
  end is_SSYS_item;

----------------------

end XXAR_SERVICE_REVENUE;
/
