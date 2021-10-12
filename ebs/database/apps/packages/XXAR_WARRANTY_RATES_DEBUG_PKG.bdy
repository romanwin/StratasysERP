create or replace 
package body xxar_warranty_rates_debug_pkg is

  --------------------------------------------------------------------
  --  name:            XXAR_WARRANTY_RATES_DEBUG_PKG
  --  create by:       Mike Mazanet
  --  Revision:        1.1
  --  creation date:   17/11/2014 
  --------------------------------------------------------------------
  --  purpose :        Created as a copy of xxar_warranty_rates_pkg to 
  --                   troubleshoot performance issues only occurring 
  --                   in production.  Added write_log statements 
  --                   throughout.  Also added p_call_api, which allows
  --                   us to bypass calling the AR_INVOICE_API_PUB.create_single_invoice
  --                   API and p_item_id parameter in
  --                   Create_warrenty_Invoices procedure so we can run
  --                   program for one item.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/11/2014  Mike Mazanet      CHG003877.  initial build
  --------------------------------------------------------------------

g_log         VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
g_log_module  VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG003877.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE write_log(p_msg  VARCHAR2)
   IS 
   BEGIN
      IF g_log = 'Y' AND 'xxar.warranty_rates_debug.xxar_warranty_rates_debug_pkg.create_warrenty_invoices' LIKE LOWER(g_log_module) THEN
         fnd_file.put_line(fnd_file.log,TO_CHAR(SYSDATE,'HH:MI:SS')||' - '||p_msg); 
      END IF;
   END write_log; 

  --------------------------------------------------------------------
  --  name:            ins_check_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   insert duplicated rows
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --  1.2  26/01/2014  Ofer Suad CHG0031727 -cahnge unreal account PL and deff and rec queties
  --  1.3  08/04/2014  Ofer Suad CHG0031891 Fix perfomance issue
  --  1.4  01/08/2014 Ofer Suad  CHG0032979 New Logic of Warranty Invoices
  --------------------------------------------------------------------
  procedure ins_check_line(p_user_id            in number,
                           p_warrenty_rates_tbl in t_warrenty_rates_tbl,
                           p_error_code         out varchar2,
                           p_error_desc         out varchar2) is

    l_rate_id number := null;

  begin
    p_error_code := 0;
    p_error_desc := null;
    for i IN p_warrenty_rates_tbl.first .. p_warrenty_rates_tbl.last LOOP
      select xxar_warranty_rates_s.nextval into l_rate_id from dual;

      insert into xxar_warranty_rates
        (rate_id,
         org_id,
         channel,
         inventory_item_id,
         warranty_period,
         rate,
         from_date,
         to_date,
         location_code,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by)
      values
        (l_rate_id,
         p_warrenty_rates_tbl(i).org_id,
         p_warrenty_rates_tbl(i).channel,
         p_warrenty_rates_tbl(i).inventory_item_id,
         p_warrenty_rates_tbl(i).warranty_period,
         p_warrenty_rates_tbl(i).rate,
         p_warrenty_rates_tbl(i).to_date + 1,
         p_warrenty_rates_tbl(i).location_code,
         null,
         sysdate,
         p_user_id,
         fnd_global.login_id,
         sysdate,
         p_user_id);
    end loop;
    commit;

  exception
    when others then
      p_error_code := 1;
      p_error_desc := 'Problem insert - ' || substr(sqlerrm, 1, 240);
  end ins_check_line;
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                    FIND the GL account with VSOE product line
  --------------------------------------------------------------------

  function get_vsoe_ccid(p_sys_ccid  number,
                         is_fdm_item varchar2,
                         is_unearned varchar2) return number is
    l_new_cc_id      number;
    l_app_short_name fnd_application.application_short_name%TYPE;
    l_delimiter      fnd_id_flex_structures.concatenated_segment_delimiter%TYPE;
    ok               BOOLEAN := FALSE;
    seg_war          fnd_flex_ext.segmentarray;
    num_segments     INTEGER;
    l_result         BOOLEAN := FALSE;

    l_segment3  gl_code_combinations.segment5%type;
    l_segment4  gl_code_combinations.segment5%type;
    l_segment5  gl_code_combinations.segment5%type;
    l_segment6  gl_code_combinations.segment5%type;
    l_segment7  gl_code_combinations.segment5%type;
    l_segment8  gl_code_combinations.segment5%type;
    l_segment9  gl_code_combinations.segment5%type;
    l_segment10 gl_code_combinations.segment5%type;

    cursor c_old_seg is
      select gcc_sys.chart_of_accounts_id,
             gcc_sys.code_combination_id,
             gcc_sys.segment1,
             gcc_sys.segment2,
             gcc_sys.segment3,
             gcc_sys.segment4,
             gcc_sys.segment5,
             gcc_sys.segment6,
             gcc_sys.segment7,
             gcc_sys.segment8,
             gcc_sys.segment9,
             gcc_sys.segment10

        from gl_code_combinations gcc_sys
       where gcc_sys.code_combination_id = p_sys_ccid;
  begin
    write_log('BEGIN get_vsoe_ccid'); 
    l_new_cc_id := null;
    
    for i in c_old_seg loop
      write_log('BEGIN c_old_seg LOOP');
      write_log('i.chart_of_accounts_id: '||i.chart_of_accounts_id);
      write_log('i.code_combination_id : '||i.code_combination_id);
      write_log('i.segment1            : '||i.segment1);
      write_log('i.segment2            : '||i.segment2);
      write_log('i.segment3            : '||i.segment3);
      write_log('i.segment4            : '||i.segment4);
      write_log('i.segment5            : '||i.segment5);
      write_log('i.segment6            : '||i.segment6);
      write_log('i.segment7            : '||i.segment7);
      write_log('i.segment8            : '||i.segment8);
      write_log('i.segment9            : '||i.segment9);
      write_log('i.segment10           : '||i.segment10);  
      
      if is_fdm_item != 'Y' then
        l_segment5 := fnd_profile.VALUE('XX_VSOE_POLY_PRODUCT_LINE');
      else
        l_segment5 := fnd_profile.VALUE('XX_VSOE_FDM_PRODUCT_LINE');
      end if;

      write_log('Before getting app values'); 
      SELECT fap.application_short_name,
             fifs.concatenated_segment_delimiter
        INTO l_app_short_name, l_delimiter
        FROM fnd_application        fap,
             fnd_id_flexs           fif,
             fnd_id_flex_structures fifs
       WHERE fif.application_id = fap.application_id
         AND fif.id_flex_code = 'GL#'
         AND fifs.application_id = fif.application_id
         AND fifs.id_flex_code = fif.id_flex_code
         AND fifs.id_flex_num = i.chart_of_accounts_id;
      write_log('After getting app values l_app_short_name: '||l_app_short_name||' l_delimiter: '||l_delimiter); 

      if is_unearned != 'Y' then
        l_segment3 := i.segment3;
      else
        l_segment3 := fnd_profile.VALUE('XX_VSOE_UNEAREBD_ACCOUNT');
      end if;

      begin
        write_log('Before getting l_new_cc_id'); 
        select gcc_war.code_combination_id
          into l_new_cc_id
          from gl_code_combinations gcc_war
         where i.segment1 = gcc_war.segment1
           and i.segment2 = gcc_war.segment2
           and l_segment3 = gcc_war.segment3
           and nvl(i.segment4, 0) = nvl(gcc_war.segment4, 0)
           and l_segment5 = gcc_war.segment5
           and i.segment6 = gcc_war.segment6
           and i.segment7 = gcc_war.segment7
           and nvl(i.segment8, 0) = nvl(gcc_war.segment8, 0)
           and i.segment9 = gcc_war.segment9
           and nvl(i.segment10, 0) = nvl(gcc_war.segment10, 0);
        
        write_log('After getting l_new_cc_id'); 
      exception
        when others then
          write_log('Before get_segments'); 
          l_result := fnd_flex_ext.get_segments(l_app_short_name,
                                                'GL#',
                                                i.chart_of_accounts_id,
                                                i.code_combination_id,
                                                num_segments,
                                                seg_war);
          write_log('i.chart_of_accounts_id '||i.chart_of_accounts_id); 

          if i.chart_of_accounts_id = 50308 then
            seg_war(3) := l_segment3;
            seg_war(5) := l_segment5;

          else
            seg_war(3) := l_segment3;
            seg_war(4) := l_segment5;
            seg_war(5) := i.segment6;
            seg_war(6) := i.segment7;
            seg_war(7) := i.segment10;
            seg_war(8) := i.segment9;

          end if;

          write_log('Before getting get_combination_id'); 
          ok := fnd_flex_ext.get_combination_id(l_app_short_name,
                                                'GL#',
                                                i.chart_of_accounts_id,
                                                SYSDATE,
                                                num_segments,
                                                seg_war,
                                                l_new_cc_id);
          write_log('l_new_cc_id: '||l_new_cc_id);
          
          IF ok THEN
            -- this means the CCID is OK
            null;
          ELSE
            fnd_file.put_line(fnd_file.log,
                              'vsoe ccid not found for ' || p_sys_ccid);
            return null;
          END IF;
      end;
      -- fnd_file.put_line(fnd_file.log, 'l_new_cc_id ' || l_new_cc_id);
      write_log('END c_old_seg LOOP');
    end loop;
    write_log('BEGIN get_vsoe_ccid'); 
    return l_new_cc_id;
  end;

  --------------------------------------------------------------------
  --  name:            validate_record
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   validate end_date and to_date before save data to DB
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/2012  Dalit A. Raviv    initial build
  --  1.1  06/02/2014  Vitaly            New condition xwr.location_code =  added
  --                                     nvl was added to existing to_date condition
  --------------------------------------------------------------------
  PROCEDURE validate_record(p_warrenty_rates_rec IN t_warrenty_rates_rec,
                            p_err_code           OUT NUMBER,
                            p_err_desc           OUT VARCHAR2) IS

    l_count NUMBER := 0;
    my_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;

    -- check this record with this date allready exists
    -- check from date entered is overlap
    SELECT COUNT(1)
      INTO l_count
      FROM xxar_warranty_rates xwr
     WHERE xwr.org_id = p_warrenty_rates_rec.org_id
       AND xwr.location_code = p_warrenty_rates_rec.location_code
       AND xwr.channel = p_warrenty_rates_rec.channel
       AND xwr.inventory_item_id = p_warrenty_rates_rec.inventory_item_id
       AND p_warrenty_rates_rec.from_date BETWEEN xwr.from_date AND
           nvl(xwr.to_date, to_date('31-DEC-2049', 'DD-MON-YYYY'));

    IF l_count <> 0 THEN
      p_err_code := 1;
      p_err_desc := 'XXAR_WAR_RATE_OVERLAP';
      RAISE my_exception;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
  END validate_record;

  --------------------------------------------------------------------
  --  name:            unEarned_warrenty_revenue
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/06/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   program that will run scheduled.
  --                   the program will locate all invoice line from account XX
  --                   and will sprade the amount into several periods
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure unEarned_warrenty_revenue(errbuf  out varchar2,
                                      retcode out varchar2) is

    cursor c_poly_rates is
      select WR.RATE,
             WR.WARRANTY_PERIOD,
             WR.INVENTORY_ITEM_ID,
             WR.CHANNEL,
             WR.FROM_DATE,
             NVL(WR.TO_DATE, SYSDATE + 1) TO_DATE
        from XXAR_WARRANTY_RATES wr
       where wr.org_id = fnd_global.ORG_ID
         and xxhz_party_ga_util.is_system_item(wr.inventory_item_id) = 'Y';

    cursor c_poly_lines(l_item_id   number,
                        l_channel   varchar2,
                        l_from_date date,
                        l_to_date   date,
                        l_rate      number) is
      select case
               when rbs.name = 'ORDER ENTRY' then
                l_rate
               else
                (l_rate * -1)
             end rate,
             -- wr.warranty_period,
             rg.gl_date,
             rta.trx_number,
             rcl.customer_trx_line_id,
             rbs.name,
             rta.org_id,
             rg.amount,
             rg.acctd_amount,
             gl_currency_api.get_closest_rate('USD',
                                              rta.invoice_currency_code,
                                              nvl(rta.exchange_date,
                                                  rta.trx_date),
                                              'Corporate',
                                              10) conv_rate,
             rcl.attribute10
        from ra_customer_trx_lines        rcl,
             ra_cust_trx_line_gl_dist_all rg,
             ra_customer_trx_all          rta,
             oe_order_lines_all           ol,
             oe_order_headers_all         oh,
             -- xxar_warranty_rates          wr,
             ra_batch_sources_all   rbs,
             ra_cust_trx_types_all  rcta,
             hz_cust_site_uses_all  hcu,
             hz_cust_acct_sites_all hcs,
             hz_cust_accounts       hca
       where rcl.interface_line_attribute6 = ol.line_id
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hca.cust_account_id = hcs.cust_account_id
         and oh.header_id = ol.header_id
            -- and xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
         and rta.cust_trx_type_id = rcta.cust_trx_type_id
         and nvl(rcta.attribute5, 'N') = 'Y'
         and fnd_global.ORG_ID = rcl.org_id
         and ol.inventory_item_id = l_item_id --wr.inventory_item_id
         and nvl(oh.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = l_channel --wr.channel
         and rta.customer_trx_id = rcl.customer_trx_id
         and rbs.name in ('ORDER ENTRY', 'ORDER ENTRY CM')
         and rg.user_generated_flag is null
         and rta.trx_date between /*wr.from_date*/
             l_from_date and nvl( /*wr.to_date*/ l_to_date, sysdate + 1)
         and rg.customer_trx_line_id = rcl.customer_trx_line_id
         and nvl(rg.amount, 0) != 0
         and rg.account_class = 'REV'
         and rbs.batch_source_id = rta.batch_source_id
         and not exists
       (select 1
                from ra_cust_trx_line_gl_dist_all rg1
               where rg1.customer_trx_line_id = rcl.customer_trx_line_id
                 and rg1.account_class = 'UNEARN'
                 and rg1.user_generated_flag is not null);

    cursor c_fdm_rates is
      select WR.RATE,
             WR.WARRANTY_PERIOD,
             XXGL_UTILS_PKG.GET_DFF_VALUE_DESCRIPTION(1013892,
                                                      WR.LOCATION_CODE) loc,
             WR.INVENTORY_ITEM_ID,
             WR.CHANNEL,
             WR.FROM_DATE,
             NVL(WR.TO_DATE, SYSDATE + 1) TO_DATE
        from XXAR_WARRANTY_RATES wr
       where wr.org_id = 737
         and XXINV_UTILS_PKG.IS_FDM_SYSTEM_ITEM(wr.INVENTORY_ITEM_ID) = 'Y';

    cursor c_fdm_lines(l_item_id       number,
                       l_channel       varchar2,
                       l_from_date     date,
                       l_to_date       date,
                       l_location_code varchar2,
                       l_rate          number) is
      select case
               when rbs.name = 'ORDER ENTRY' then
                l_rate -- wr.rate
               else
                ( /*wr.rate*/
                 l_rate * -1)
             end rate,
             --wr.warranty_period,
             rg.gl_date,
             rta.trx_number,
             rcl.customer_trx_line_id,
             rbs.name,
             rta.org_id,
             rg.amount,
             rg.acctd_amount,
             gl_currency_api.get_closest_rate('USD',
                                              rta.invoice_currency_code,
                                              nvl(rta.exchange_date,
                                                  rta.trx_date),
                                              'Corporate',
                                              10) conv_rate,
             rcl.attribute10

        from ra_customer_trx_lines        rcl,
             ra_cust_trx_line_gl_dist_all rg,
             ra_customer_trx_all          rta,
             oe_order_lines_all           ol,
             oe_order_headers_all         oh,
             -- xxar_warranty_rates          wr,
             ra_batch_sources_all   rbs,
             ra_cust_trx_types_all  rcta,
             gl_code_combinations   gcc,
             hz_cust_site_uses_all  hcu,
             hz_cust_acct_sites_all hcs,
             hz_party_sites         hps,
             hz_locations           hl,
             hz_cust_accounts       hca
       where xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
                                                                                                  nvl(gcc.segment6,
                                                                                                      '803'))) =
             l_location_code
            --xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hps.party_site_id = hcs.party_site_id
         and hl.location_id = hps.location_id
         and hca.cust_account_id = hcs.cust_account_id
         and rcl.interface_line_attribute6 = ol.line_id
         and oh.header_id = ol.header_id
            -- and xxinv_utils_pkg.is_fdm_system_item(ol.inventory_item_id) = 'Y'
         and rta.cust_trx_type_id = rcta.cust_trx_type_id
         and nvl(rcta.attribute5, 'N') = 'Y'
            --and wr.org_id = 737
         and ol.inventory_item_id = l_item_id --wr.inventory_item_id
         and nvl(oh.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = l_channel --wr.channel
         and rta.customer_trx_id = rcl.customer_trx_id
         and rbs.name in ('ORDER ENTRY', 'ORDER ENTRY CM')
         and rg.user_generated_flag is null
         and rta.trx_date between l_from_date and l_to_date --wr.from_date and nvl(wr.to_date, sysdate + 1)
         and rg.customer_trx_line_id = rcl.customer_trx_line_id
         and nvl(rg.amount, 0) != 0
         and rg.account_class = 'REV'
         and rbs.batch_source_id = rta.batch_source_id
         and gcc.code_combination_id(+) = hcu.gl_id_rev --rg.code_combination_id
         and xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
         and not exists
       (select 1
                from ra_cust_trx_line_gl_dist_all rg1
               where rg1.customer_trx_line_id = rcl.customer_trx_line_id
                 and rg1.account_class = 'UNEARN'
                 and rg1.user_generated_flag is not null);

    l_revenue_adj_rec    ar_revenue_adjustment_pvt.rev_adj_rec_type;
    l_return_status      varchar2(100);
    l_msg_count          number;
    l_msg_data           varchar2(1000);
    l_adjustment_id      number;
    l_adjustment_number  varchar2(1000);
    l_sus                number;
    l_program_request_id NUMBER := -1;
  begin
    retcode              := 0;
    errbuf               := null;
    l_program_request_id := fnd_global.conc_request_id;

    for j in c_poly_rates loop
      for i in c_poly_lines(j.inventory_item_id,
                            j.channel,
                            j.from_date,
                            j.to_date,
                            j.rate) loop
        fnd_file.put_line(fnd_file.log, 'Trx Number Poly ' || i.trx_number);
        select nvl(sum(nvl(amount, 0)), 0)
          into l_sus
          from ra_cust_trx_line_gl_dist_all rda
         where rda.customer_trx_line_id = i.customer_trx_line_id
           and rda.account_class = 'SUSPENSE';

        dbms_output.put_line(i.rate);
        l_revenue_adj_rec.trx_number            := i.trx_number;
        l_revenue_adj_rec.from_cust_trx_line_id := i.customer_trx_line_id;
        l_revenue_adj_rec.adjustment_type       := 'EA';
        l_revenue_adj_rec.batch_source_name     := i.name;
        l_revenue_adj_rec.amount_mode           := 'A';
        l_revenue_adj_rec.gl_date               := i.gl_date;
        l_revenue_adj_rec.reason_code           := 'RA';
        l_revenue_adj_rec.amount                := trunc(i.rate *
                                                         i.conv_rate *
                                                         nvl(1 -
                                                             i.attribute10 / 100,
                                                             1) *
                                                         (i.amount /
                                                         (i.amount - l_sus)));

        ar_revenueadjust_pub.Unearn_Revenue(p_api_version       => 2.0,
                                            p_init_msg_list     => fnd_api.g_true,
                                            x_return_status     => l_return_status,
                                            x_msg_count         => l_msg_count,
                                            x_msg_data          => l_msg_data,
                                            p_rev_adj_rec       => l_revenue_adj_rec,
                                            p_org_id            => i.org_id,
                                            x_adjustment_id     => l_adjustment_id,
                                            x_adjustment_number => l_adjustment_number);
        if l_msg_count != 0 then
          dbms_output.put_line(substr(l_msg_data, 0, 190));
          /*retcode := 2;
          errbuf  := 'Trx Number ' || i.trx_number || ' Line id - ' ||
                     i.customer_trx_line_id || ' - ' ||
                     substr(l_msg_data, 0, 190);*/
          fnd_file.put_line(fnd_file.log,
                            'Trx Number ' || i.trx_number || ' Line id - ' ||
                            i.customer_trx_line_id || ' - ' ||
                            substr(l_msg_data, 0, 190));
          rollback;
        end if;
        /* if l_sus!=0  then

        update ar.ra_cust_trx_line_gl_dist_all t
               set t.amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1),2),
                   t.acctd_amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1)*i.acctd_amount/i.amount,2)
             where t.customer_trx_line_id = i.customer_trx_line_id
               and t.account_class ='REV'
               and t.revenue_adjustment_id = l_adjustment_id;

        update ar.ra_cust_trx_line_gl_dist_all t
               set t.code_combination_id=get_vsoe_ccid(t.code_combination_id,'Y','Y'),
               t.amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1),2),
                   t.acctd_amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1)*i.acctd_amount/i.amount,2)
             where t.customer_trx_line_id = i.customer_trx_line_id

               and t.account_class ='UNEARN'
               and t.revenue_adjustment_id = l_adjustment_id;
               else*/
        update ar.ra_cust_trx_line_gl_dist_all t
           set t.code_combination_id = get_vsoe_ccid(t.code_combination_id,
                                                     'N',
                                                     'Y')
         where t.customer_trx_line_id = i.customer_trx_line_id
           and t.account_class IN ('UNEARN')
           and t.revenue_adjustment_id = l_adjustment_id;

        -- end if;
        commit;
      end loop;
    end loop;

    for j in c_fdm_rates loop
      for i in c_fdm_lines(j.inventory_item_id,
                           j.channel,
                           j.from_date,
                           j.to_date,
                           j.loc,
                           j.rate) loop
        fnd_file.put_line(fnd_file.log, 'Trx Number FDM ' || i.trx_number);
        select nvl(sum(nvl(amount, 0)), 0)
          into l_sus
          from ra_cust_trx_line_gl_dist_all rda
         where rda.customer_trx_line_id = i.customer_trx_line_id
           and rda.account_class = 'SUSPENSE';

        dbms_output.put_line(i.rate);
        l_revenue_adj_rec.trx_number            := i.trx_number;
        l_revenue_adj_rec.from_cust_trx_line_id := i.customer_trx_line_id;
        l_revenue_adj_rec.adjustment_type       := 'EA';
        l_revenue_adj_rec.batch_source_name     := i.name;
        l_revenue_adj_rec.amount_mode           := 'A';
        l_revenue_adj_rec.gl_date               := i.gl_date;
        l_revenue_adj_rec.reason_code           := 'RA';
        l_revenue_adj_rec.amount                := trunc(i.rate *
                                                         i.conv_rate *
                                                         nvl(1 -
                                                             i.attribute10 / 100,
                                                             1) *
                                                         (i.amount /
                                                         (i.amount - l_sus)),
                                                         2);

        ar_revenueadjust_pub.Unearn_Revenue(p_api_version       => 2.0,
                                            p_init_msg_list     => fnd_api.g_true,
                                            x_return_status     => l_return_status,
                                            x_msg_count         => l_msg_count,
                                            x_msg_data          => l_msg_data,
                                            p_rev_adj_rec       => l_revenue_adj_rec,
                                            p_org_id            => i.org_id,
                                            x_adjustment_id     => l_adjustment_id,
                                            x_adjustment_number => l_adjustment_number);
        if l_msg_count != 0 then
          dbms_output.put_line(substr(l_msg_data, 0, 190));
          /* retcode := 2;
          errbuf  := 'Trx Number ' || i.trx_number || ' Line id - ' ||
                     i.customer_trx_line_id || ' - ' ||
                     substr(l_msg_data, 0, 190);*/
          fnd_file.put_line(fnd_file.log,
                            'Trx Number ' || i.trx_number || ' Line id - ' ||
                            i.customer_trx_line_id || ' - ' ||
                            substr(l_msg_data, 0, 190));
          rollback;
        end if;
        /*if l_sus!=0 then

        update ar.ra_cust_trx_line_gl_dist_all t
               set t.amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1),2),
                   t.acctd_amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1)*i.acctd_amount/i.amount,2)
             where t.customer_trx_line_id = i.customer_trx_line_id
               and t.account_class ='REV'
               and t.revenue_adjustment_id = l_adjustment_id;

        update ar.ra_cust_trx_line_gl_dist_all t
               set t.code_combination_id=get_vsoe_ccid(t.code_combination_id,'Y','Y'),
               t.amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1),2),
                   t.acctd_amount= trunc(i.rate * i.conv_rate *nvl(1-i.attribute10/100,1)*i.acctd_amount/i.amount,2)
             where t.customer_trx_line_id = i.customer_trx_line_id

               and t.account_class ='UNEARN'
               and t.revenue_adjustment_id = l_adjustment_id;

        else*/
        update ar.ra_cust_trx_line_gl_dist_all t
           set t.code_combination_id = get_vsoe_ccid(t.code_combination_id,
                                                     'Y',
                                                     'Y')
         where t.customer_trx_line_id = i.customer_trx_line_id

           and t.account_class = 'UNEARN'
           and t.revenue_adjustment_id = l_adjustment_id;

        -- end if;
        commit;
      end loop;
    end loop;
    update ra_cust_trx_line_gl_dist_all rctg
       set rctg.attribute1 = 'Y'
     where rctg.request_id = l_program_request_id;
    commit;
  end unEarned_warrenty_revenue;

  --------------------------------------------------------------------
  --  name:            Earned_warrenty_revenue
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/06/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   program that will run scheduled.
  --                   the program will locate all invoice line from account XX
  --                   and will sprade the amount into several periods
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure Earned_warrenty_revenue(errbuf  out varchar2,
                                    retcode out varchar2) is

    cursor get_pop_poly_c is
      select sum(nvl(rctl.amount, 0)) une_amt,
             sum(nvl(rctl.acctd_amount, 0)) act_amt,
             rta.trx_number trx_number,
             rbs.name,
             rla.customer_trx_line_id customer_trx_line_id,
             rla.org_id org_id,
             msib.inventory_item_id inventory_item_id,
             ooha.attribute7 channel,
             nvl(oola.actual_shipment_date, rta.trx_date) actual_shipment_date,
             rta.trx_date trx_date,
             wr.warranty_period,
             rla.attribute10
        from ra_customer_trx_lines_all    rla, -- inv line
             mtl_system_items_b           msib,
             ra_customer_trx_all          rta, -- inv header
             ra_batch_sources_all         rbs,
             ra_cust_trx_line_gl_dist_all rctl,
             gl_code_combinations         gcc,
             oe_order_headers_all         ooha,
             oe_order_lines_all           oola,
             xxar_warranty_rates          wr,
             hz_cust_site_uses_all        hcu,
             hz_cust_acct_sites_all       hcs,
             hz_cust_accounts             hca
       where msib.inventory_item_id = rla.inventory_item_id
         and msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hca.cust_account_id = hcs.cust_account_id
         and rla.org_id = fnd_global.ORG_ID --solved  Perfomance issue
         and gcc.code_combination_id = rctl.code_combination_id
         and xxhz_party_ga_util.is_system_item(oola.inventory_item_id) = 'Y'
         and rta.customer_trx_id = rla.customer_trx_id
         and rbs.batch_source_id = rta.batch_source_id
         and rctl.customer_trx_line_id = rla.customer_trx_line_id
         and rctl.account_class = 'UNEARN'
         and rctl.revenue_adjustment_id is not null
         and rla.revenue_amount != 0
         and rctl.attribute1 = 'Y'
         and wr.rate > 0
         and rla.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')

            --  and rta.trx_number='1002902'
         and oola.header_id = ooha.header_id
         and oola.line_id = rla.interface_line_attribute6
         and wr.org_id = rla.org_id
         and oola.inventory_item_id = wr.inventory_item_id
         and nvl(ooha.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = wr.channel
         and rta.trx_date between wr.from_date and
             nvl(wr.to_date, sysdate + 1)
       group by rla.customer_trx_line_id,
                rta.trx_number,
                msib.inventory_item_id,
                rbs.name,
                rla.org_id,
                ooha.attribute7,
                oola.actual_shipment_date,
                rla.revenue_amount,
                rta.trx_date,
                wr.rate,
                wr.warranty_period,
                rla.attribute10
      having abs(sum(nvl(rctl.amount, 0))) / wr.rate > 0.02;
    --   08/04/2014  Ofer Suad CHG0031891 Fix perfomance issue
    cursor c_fdm_war is
      select wr.warranty_period,
             xxgl_utils_pkg.get_dff_value_description(1013892,
                                                      wr.location_code) location_code,
             wr.rate,
             wr.inventory_item_id,
             wr.channel,
             wr.from_date,
             nvl(wr.to_date, sysdate + 1) to_date
        from xxar_warranty_rates wr
       where wr.rate > 0
         and wr.org_id = 737
         and xxinv_utils_pkg.is_fdm_system_item(wr.inventory_item_id) = 'Y';

    cursor get_pop_fdm_c(location_code varchar2,
                         l_item_id     number,
                         l_channel     varchar2,
                         l_from_date   date,
                         l_to_date     date,
                         l_rate        number) is
    ------------------
      select sum(nvl(rctl.amount, 0)) une_amt,
             sum(nvl(rctl.acctd_amount, 0)) act_amt,
             rta.trx_number trx_number,
             rbs.name,
             rla.customer_trx_line_id customer_trx_line_id,
             rla.org_id org_id,
             msib.inventory_item_id inventory_item_id,
             ooha.attribute7 channel,
             nvl(oola.actual_shipment_date, rta.trx_date) actual_shipment_date,
             rta.trx_date trx_date,
             --wr.warranty_period,
             rla.attribute10
        from ra_customer_trx_lines_all    rla, -- inv line
             mtl_system_items_b           msib,
             ra_customer_trx_all          rta, -- inv header
             ra_batch_sources_all         rbs,
             ra_cust_trx_line_gl_dist_all rctl,
             gl_code_combinations         gcc,
             oe_order_headers_all         ooha,
             oe_order_lines_all           oola,
             -- xxar_warranty_rates          wr,
             hz_cust_site_uses_all  hcu,
             hz_cust_acct_sites_all hcs,
             hz_party_sites         hps,
             hz_locations           hl,
             hz_cust_accounts       hca
       where xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
                                                                                                  nvl(gcc.segment6,
                                                                                                      '803'))) =
             location_code --USA Defualt

            -- xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hps.party_site_id = hcs.party_site_id
         and hl.location_id = hps.location_id
         and hca.cust_account_id = hcs.cust_account_id
         and msib.inventory_item_id = rla.inventory_item_id
         and msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and gcc.code_combination_id(+) = hcu.gl_id_rev --rctl.code_combination_id
            -- and xxinv_utils_pkg.is_fdm_system_item(oola.inventory_item_id) = 'Y'
            --   and rta.trx_number='1021811'-------------------------------
         and rta.customer_trx_id = rla.customer_trx_id
         and rbs.batch_source_id = rta.batch_source_id
         and rctl.customer_trx_line_id = rla.customer_trx_line_id
         and rla.org_id = fnd_global.ORG_ID --solved  Perfomance issue
         and rctl.account_class = 'UNEARN'
         and rctl.revenue_adjustment_id is not null
         and rla.revenue_amount != 0
            --and rta.trx_number='1011032'
            --and wr.rate > 0
         and rctl.attribute1 = 'Y'
         and rla.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')
         and oola.header_id = ooha.header_id
         and oola.line_id = rla.interface_line_attribute6
            --  and wr.org_id = 737
         and oola.inventory_item_id = l_item_id -- wr.inventory_item_id
         and nvl(ooha.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = l_channel --wr.channel
            -- and rta.trx_date between wr.from_date and nvl(wr.to_date, sysdate + 1)
         and rta.trx_date between l_from_date and l_to_date
         and xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
       group by rla.customer_trx_line_id,
                rta.trx_number,
                msib.inventory_item_id,
                rbs.name,
                rla.org_id,
                ooha.attribute7,
                oola.actual_shipment_date,
                rla.revenue_amount,
                rta.trx_date,
                -- wr.rate,
                -- wr.warranty_period,
                rla.attribute10
      having abs(sum(nvl(rctl.amount, 0))) / /*wr.rate*/
      l_rate > 0.02;
    l_program_request_id NUMBER := -1;
    ------------------

    --l_unearned_account  varchar2(100) := null;
    -- l_warranty_period   number := null;
    l_ship_days         number := null;
    l_revenue_adj_rec   ar_revenue_adjustment_pvt.rev_adj_rec_type;
    l_return_status     varchar2(100);
    l_msg_count         number;
    l_msg_data          varchar2(1000);
    l_adjustment_id     number;
    l_adjustment_number varchar2(1000);
    l_ship_date         date := null;
    l_sus               number;
    l_portion           number;
    l_agg_portion       number;
    l_amount            number;
    --l_rev number;

  begin
    errbuf               := null;
    retcode              := 0;
    l_program_request_id := fnd_global.conc_request_id;
    --l_unearned_account := fnd_profile.value('XXAR_VSOE_WARRANTY_UNEARNED_ACCOUNT'); -- 251307
    l_ship_days := fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'); -- 60

    for get_pop_r in get_pop_poly_c loop

      -- period loop

      l_agg_portion := 0;

      for i in 1 .. get_pop_r.warranty_period + 1 loop

        select nvl(sum(nvl(amount, 0)), 0)
          into l_sus
          from ra_cust_trx_line_gl_dist_all rda
         where rda.customer_trx_line_id = get_pop_r.customer_trx_line_id
           and rda.account_class = 'SUSPENSE';

        if i = 1 then
          l_portion     := 1 -
                           (get_pop_r.actual_shipment_date -
                           (TRUNC(get_pop_r.actual_shipment_date, 'MONTH') - 1)) /
                           (LAST_DAY(get_pop_r.actual_shipment_date) -
                           (TRUNC(get_pop_r.actual_shipment_date, 'MONTH') - 1));
          l_agg_portion := l_portion;
        elsif i = get_pop_r.warranty_period + 1 then
          --  l_portion:=(LAST_DAY(get_pop_r.actual_shipment_date)-get_pop_r.actual_shipment_date)/(LAST_DAY(get_pop_r.actual_shipment_date)-(TRUNC(get_pop_r.actual_shipment_date,'MONTH') -1));
          l_portion := get_pop_r.warranty_period - l_agg_portion;
        else
          l_portion     := 1;
          l_agg_portion := l_agg_portion + 1;
        end if;

        l_amount := trunc((1 / get_pop_r.warranty_period) *
                          get_pop_r.une_amt * /*nvl(1-get_pop_r.attribute10/100,1)**/
                          l_portion,
                          2);

        if l_portion != 0 then

          l_ship_date := add_months((get_pop_r.actual_shipment_date +
                                    l_ship_days),
                                    i - 1);

          l_revenue_adj_rec.trx_number            := get_pop_r.trx_number;
          l_revenue_adj_rec.from_cust_trx_line_id := get_pop_r.customer_trx_line_id;
          l_revenue_adj_rec.adjustment_type       := 'EA';
          l_revenue_adj_rec.batch_source_name     := get_pop_r.name;
          l_revenue_adj_rec.amount_mode           := 'A';
          l_revenue_adj_rec.gl_date               := l_ship_date;
          l_revenue_adj_rec.reason_code           := 'RA';

          l_revenue_adj_rec.amount := l_amount;

          ar_revenueadjust_pub.earn_revenue(p_api_version       => 2.0,
                                            p_init_msg_list     => fnd_api.g_true,
                                            x_return_status     => l_return_status,
                                            x_msg_count         => l_msg_count,
                                            x_msg_data          => l_msg_data,
                                            p_rev_adj_rec       => l_revenue_adj_rec,
                                            p_org_id            => get_pop_r.org_id,
                                            x_adjustment_id     => l_adjustment_id,
                                            x_adjustment_number => l_adjustment_number);

          if l_msg_count != 0 then
            --  retcode := 2;
            --    errbuf  := 'Trx Number ' || get_pop_r.trx_number || ' Line id - ' ||
            --                 get_pop_r.customer_trx_line_id || ' - ' ||
            --                substr(l_msg_data, 0, 190);
            fnd_file.put_line(fnd_file.log,
                              'Trx Number ' || get_pop_r.trx_number ||
                              ' Line id - ' ||
                              get_pop_r.customer_trx_line_id || ' - ' ||
                              substr(l_msg_data, 0, 190));
            fnd_file.put_line(fnd_file.log, 'Ship date: ' || l_ship_date);
            fnd_file.put_line(fnd_file.log, substr(l_msg_data, 0, 200));
            rollback;
            exit;
          end if;

          if l_sus != 0 then
            update ar.ra_cust_trx_line_gl_dist_all t
               set t.amount              = trunc((l_portion /
                                                 get_pop_r.warranty_period /*l_warranty_period*/
                                                 ) * get_pop_r.une_amt,
                                                 2),
                   t.acctd_amount        = trunc((l_portion /
                                                 get_pop_r.warranty_period /*l_warranty_period*/
                                                 ) * get_pop_r.une_amt *
                                                 get_pop_r.act_amt /
                                                 get_pop_r.une_amt,
                                                 2), --11-10-2012 add act_amt
                   t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                             'N',
                                                             'N'),
                                               t.code_combination_id) -- 08-oct-2013 update product line
             where t.customer_trx_line_id = get_pop_r.customer_trx_line_id
               and t.account_class IN ('REV')
               and t.revenue_adjustment_id = l_adjustment_id;

            update ar.ra_cust_trx_line_gl_dist_all t
               set t.amount              = -trunc((l_portion /
                                                  get_pop_r.warranty_period /*l_warranty_period*/
                                                  ) * get_pop_r.une_amt,
                                                  2),
                   t.acctd_amount        = -trunc((l_portion /
                                                  get_pop_r.warranty_period /*l_warranty_period*/
                                                  ) * get_pop_r.une_amt *
                                                  get_pop_r.act_amt /
                                                  get_pop_r.une_amt,
                                                  2), --11-10-2012 add act_amt
                   t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                             'N',
                                                             'Y'),
                                               t.code_combination_id)
             where t.customer_trx_line_id = get_pop_r.customer_trx_line_id
               and t.account_class IN ('UNEARN')
               and t.revenue_adjustment_id = l_adjustment_id;
          else
            -- 08-oct-2013 update product line
            update ar.ra_cust_trx_line_gl_dist_all t
               set t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                             'N',
                                                             'N'),
                                               t.code_combination_id)
             where t.customer_trx_line_id = get_pop_r.customer_trx_line_id
               and t.account_class IN ('REV')
               and t.revenue_adjustment_id = l_adjustment_id;

            update ar.ra_cust_trx_line_gl_dist_all t
               set t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                             'N',
                                                             'Y'),
                                               t.code_combination_id)
             where t.customer_trx_line_id = get_pop_r.customer_trx_line_id
               and t.account_class IN ('UNEARN')
               and t.revenue_adjustment_id = l_adjustment_id;
          end if;
        end if;
      end loop; -- period
      commit; -- ether all periods save or none
    end loop; -- invoice population

    for j in c_fdm_war loop

      for get_pop_r in get_pop_fdm_c(j.location_code,
                                     j.inventory_item_id,
                                     j.channel,
                                     j.from_date,
                                     j.to_date,
                                     j.rate) loop

        null;

        -- period loop
        for i in 1 .. j.warranty_period + 1 loop

          select nvl(sum(nvl(amount, 0)), 0)
            into l_sus
            from ra_cust_trx_line_gl_dist_all rda
           where rda.customer_trx_line_id = get_pop_r.customer_trx_line_id
             and rda.account_class = 'SUSPENSE';
          if i = 1 then
            l_portion     := 1 - (get_pop_r.actual_shipment_date -
                             (TRUNC(get_pop_r.actual_shipment_date,
                                         'MONTH') - 1)) /
                             (LAST_DAY(get_pop_r.actual_shipment_date) -
                             (TRUNC(get_pop_r.actual_shipment_date,
                                         'MONTH') - 1));
            l_agg_portion := l_portion;
          elsif i = j.warranty_period + 1 then
            --  l_portion:=(LAST_DAY(get_pop_r.actual_shipment_date)-get_pop_r.actual_shipment_date)/(LAST_DAY(get_pop_r.actual_shipment_date)-(TRUNC(get_pop_r.actual_shipment_date,'MONTH') -1));
            l_portion := j.warranty_period - l_agg_portion;
          else
            l_portion     := 1;
            l_agg_portion := l_agg_portion + 1;
          end if;

          l_amount := trunc((1 / j.warranty_period) * get_pop_r.une_amt * /*nvl(1-get_pop_r.attribute10/100,1)**/
                            l_portion);

          --   fnd_file.put_line(fnd_file.log,'amt '||l_amount);

          if l_portion != 0 then

            l_ship_date := add_months((get_pop_r.actual_shipment_date +
                                      l_ship_days),
                                      i - 1);
            --  fnd_file.put_line(fnd_file.log, 'Ship date: ' || l_ship_date);
            l_revenue_adj_rec.trx_number            := get_pop_r.trx_number;
            l_revenue_adj_rec.from_cust_trx_line_id := get_pop_r.customer_trx_line_id;
            l_revenue_adj_rec.adjustment_type       := 'EA';
            l_revenue_adj_rec.batch_source_name     := get_pop_r.name;
            l_revenue_adj_rec.amount_mode           := 'A';
            l_revenue_adj_rec.gl_date               := l_ship_date;
            l_revenue_adj_rec.reason_code           := 'RA';

            l_revenue_adj_rec.amount := l_amount;

            ar_revenueadjust_pub.earn_revenue(p_api_version       => 2.0,
                                              p_init_msg_list     => fnd_api.g_true,
                                              x_return_status     => l_return_status,
                                              x_msg_count         => l_msg_count,
                                              x_msg_data          => l_msg_data,
                                              p_rev_adj_rec       => l_revenue_adj_rec,
                                              p_org_id            => get_pop_r.org_id,
                                              x_adjustment_id     => l_adjustment_id,
                                              x_adjustment_number => l_adjustment_number);

            if l_msg_count != 0 then
              -- retcode := 2;
              --   errbuf  := 'Trx Number ' || get_pop_r.trx_number || ' Line id - ' ||
              --           get_pop_r.customer_trx_line_id || ' - ' ||
              --               substr(l_msg_data, 0, 190);
              fnd_file.put_line(fnd_file.log,
                                'Trx Number ' || get_pop_r.trx_number ||
                                ' Line id - ' ||
                                get_pop_r.customer_trx_line_id || ' - ' ||
                                substr(l_msg_data, 0, 190));
              fnd_file.put_line(fnd_file.log, 'Ship date: ' || l_ship_date);
              fnd_file.put_line(fnd_file.log, substr(l_msg_data, 0, 200));
              rollback;
              exit;
            end if;

            --  fnd_file.put_line(fnd_file.log,'amt '||(trunc((l_portion /get_pop_r.warranty_period\*l_warranty_period*\ ) *
            --                                          get_pop_r.une_amt,
            --                                           2)));

            if l_sus != 0 then
              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.amount              = trunc((l_portion /
                                                   j.warranty_period) *
                                                   get_pop_r.une_amt,
                                                   2),
                     t.acctd_amount        = trunc((l_portion /
                                                   j.warranty_period) *
                                                   get_pop_r.une_amt *
                                                   get_pop_r.act_amt /
                                                   get_pop_r.une_amt,
                                                   2), --11-10-2012 add act_amt
                     t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                               'Y',
                                                               'N'),
                                                 t.code_combination_id) -- 08-oct-2013 update product line
               where t.customer_trx_line_id =
                     get_pop_r.customer_trx_line_id
                 and t.account_class IN ('REV')
                 and t.revenue_adjustment_id = l_adjustment_id;

              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.amount              = -trunc((l_portion /
                                                    j.warranty_period) *
                                                    get_pop_r.une_amt,
                                                    2),
                     t.acctd_amount        = -trunc((l_portion /
                                                    j.warranty_period) *
                                                    get_pop_r.une_amt *
                                                    get_pop_r.act_amt /
                                                    get_pop_r.une_amt,
                                                    2), --11-10-2012 add act_amt
                     t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                               'Y',
                                                               'Y'),
                                                 t.code_combination_id)
               where t.customer_trx_line_id =
                     get_pop_r.customer_trx_line_id
                 and t.account_class IN ('UNEARN')
                 and t.revenue_adjustment_id = l_adjustment_id;
            else
              -- 08-oct-2013 update product line
              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                               'Y',
                                                               'N'),
                                                 t.code_combination_id)
               where t.customer_trx_line_id =
                     get_pop_r.customer_trx_line_id
                 and t.account_class IN ('REV')
                 and t.revenue_adjustment_id = l_adjustment_id;

              update ar.ra_cust_trx_line_gl_dist_all t
                 set t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
                                                               'Y',
                                                               'Y'),
                                                 t.code_combination_id)
               where t.customer_trx_line_id =
                     get_pop_r.customer_trx_line_id
                 and t.account_class IN ('UNEARN')
                 and t.revenue_adjustment_id = l_adjustment_id;

            end if;
          end if;
        end loop; -- period
        commit; -- ether all periods save or none

      end loop;
    end loop;
    update ra_cust_trx_line_gl_dist_all rctg
       set rctg.attribute1 = 'Y'
     where rctg.request_id = l_program_request_id;
    commit;
  exception
    when others then
      errbuf  := 'procedure Earned_warrenty_revenue failed - ' ||
                 substr(sqlerrm, 1, 240);
      retcode := 2;
  end Earned_warrenty_revenue;

  procedure Create_warrenty_Invoices(errbuf  out varchar2,
                                     retcode out varchar2,
                                     p_call_api IN VARCHAR2 DEFAULT 'N', 
                                     p_item_id  IN NUMBER DEFAULT NULL) is
    l_return_status        varchar2(1);
    l_msg_count            number;
    l_msg_data             varchar2(2000);
    l_batch_id             number;
    l_cnt                  number := 0;
    l_batch_source_rec     ar_invoice_api_pub.batch_source_rec_type;
    l_trx_header_tbl       ar_invoice_api_pub.trx_header_tbl_type;
    l_trx_lines_tbl        ar_invoice_api_pub.trx_line_tbl_type;
    l_trx_dist_tbl         ar_invoice_api_pub.trx_dist_tbl_type;
    l_trx_salescredits_tbl ar_invoice_api_pub.trx_salescredits_tbl_type;
    l_customer_trx_id      number;
    l_header_id            number;
    l_ship_date            date;
    l_line_id              number;
    l_dist_id              number;
    l_amt                  number;
    l_agg_amt              number;
    l_tot_amt              number;
    l_portion              number;
    l_item_code            mtl_system_items_b.segment1%type;
    l_item_desc            mtl_system_items_b.description%type;
    l_terms_id number;

    cursor c_errors is
      SELECT gt.error_message FROM ar_trx_errors_gt gt;

    cursor c_poly_rates is
      select WR.RATE,
             WR.WARRANTY_PERIOD,
             WR.INVENTORY_ITEM_ID,
             WR.CHANNEL,
             WR.FROM_DATE,
             NVL(WR.TO_DATE, SYSDATE + 1) TO_DATE
        from XXAR_WARRANTY_RATES wr
       where wr.org_id = fnd_global.ORG_ID
         and xxhz_party_ga_util.is_system_item(wr.inventory_item_id) = 'Y'
         AND wr.inventory_item_id = NVL(p_item_id,wr.inventory_item_id)
          ;------------------------

    cursor c_fdm_rates is
      select WR.RATE,
             WR.WARRANTY_PERIOD,
             XXGL_UTILS_PKG.GET_DFF_VALUE_DESCRIPTION(1013892,
                                                      WR.LOCATION_CODE) LOCATION_CODE,
             WR.INVENTORY_ITEM_ID,
             WR.CHANNEL,
             WR.FROM_DATE,
             NVL(WR.TO_DATE, SYSDATE + 1) TO_DATE
        from XXAR_WARRANTY_RATES wr
       where wr.org_id = 737
         and XXINV_UTILS_PKG.IS_FDM_SYSTEM_ITEM(wr.INVENTORY_ITEM_ID) = 'Y'
         AND wr.inventory_item_id = NVL(p_item_id,wr.inventory_item_id)
        ; --------------------------------------------
    cursor c_poly_lines(l_item_id   number,
                        l_channel   varchar2,
                        l_from_date date,
                        l_to_date   date,
                        l_rate      number) is
      select case
               when rbs.name = 'ORDER ENTRY' then
                l_rate
               else
                (l_rate * -1)
             end rate,
             -- wr.warranty_period,
             rg.gl_date,
             rg.code_combination_id,
             rta.trx_number,
             rta.invoice_currency_code,
             rcl.customer_trx_line_id,
             rbs.name,
             rta.org_id,
             rg.amount,
             rg.acctd_amount,
             gl_currency_api.get_closest_rate('USD',
                                              rta.invoice_currency_code,
                                              nvl(rta.exchange_date,
                                                  rta.trx_date),
                                              'Corporate',
                                              10) conv_rate,
             rcl.attribute10,
             hca.cust_account_id,
             oh.order_number,
             nvl(ol.actual_shipment_date, rta.trx_date) actual_shipment_date
        from ra_customer_trx_lines        rcl,
             ra_cust_trx_line_gl_dist_all rg,
             ra_customer_trx_all          rta,
             oe_order_lines_all           ol,
             oe_order_headers_all         oh,
             -- xxar_warranty_rates          wr,
             ra_batch_sources_all   rbs,
             ra_cust_trx_types_all  rcta,
             hz_cust_site_uses_all  hcu,
             hz_cust_acct_sites_all hcs,
             hz_cust_accounts       hca
       where rcl.interface_line_attribute6 = ol.line_id
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hca.cust_account_id = hcs.cust_account_id
         and oh.header_id = ol.header_id
            -- and xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
         and rta.cust_trx_type_id = rcta.cust_trx_type_id
         and nvl(rcta.attribute5, 'N') = 'Y'
         and fnd_global.ORG_ID = rcl.org_id
         and ol.inventory_item_id = l_item_id --wr.inventory_item_id
         and nvl(oh.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = l_channel --wr.channel
         and rta.customer_trx_id = rcl.customer_trx_id
         and rbs.name in ('ORDER ENTRY', 'ORDER ENTRY CM')
         and rg.user_generated_flag is null
         and rta.trx_date between /*wr.from_date*/
             l_from_date and nvl( /*wr.to_date*/ l_to_date, sysdate + 1)
           -- and rta.trx_date between '01-apr-2014' and '30-jun-2014'-----------------
         and rg.customer_trx_line_id = rcl.customer_trx_line_id
         and nvl(rg.amount, 0) != 0
         and rg.account_class = 'REV'
         and rbs.batch_source_id = rta.batch_source_id
       --  and rta.trx_number in ( /*'1023933',*/ '1022745')----------------
        and not exists
      (select 1
                from ra_customer_trx_all rth, ra_customer_trx_lines_all rtl
               where rth.cust_trx_type_id =
                     fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
                                                NULL,
                                                NULL,
                                                NULL,
                                                fnd_global.ORG_ID)
                 and rth.customer_trx_id = rtl.customer_trx_id
                 and rtl.sales_order = oh.order_number
                 and rtl.inventory_item_id=rcl.inventory_item_id)

       and not exists
      (select 1
               from ra_cust_trx_line_gl_dist_all rg1
              where rg1.customer_trx_line_id = rcl.customer_trx_line_id
                and rg1.account_class = 'UNEARN'
                and rg1.user_generated_flag is not null)
      ;
    cursor c_fdm_lines(l_item_id       number,
                       l_channel       varchar2,
                       l_from_date     date,
                       l_to_date       date,
                       l_location_code varchar2,
                       l_rate          number) is
      select case
               when rbs.name = 'ORDER ENTRY' then
                l_rate -- wr.rate
               else
                ( /*wr.rate*/
                 l_rate * -1)
             end rate,
             --wr.warranty_period,
             rg.gl_date,
             rta.trx_number,
             rcl.customer_trx_line_id,
             rta.invoice_currency_code,
             rbs.name,
             rta.org_id,
             rg.code_combination_id,
             rg.amount,
             rg.acctd_amount,
             gl_currency_api.get_closest_rate('USD',
                                              rta.invoice_currency_code,
                                              nvl(rta.exchange_date,
                                                  rta.trx_date),
                                              'Corporate',
                                              10) conv_rate,
             rcl.attribute10,
             hca.cust_account_id,
             oh.order_number,
             nvl(ol.actual_shipment_date, rta.trx_date) actual_shipment_date

        from ra_customer_trx_lines        rcl,
             ra_cust_trx_line_gl_dist_all rg,
             ra_customer_trx_all          rta,
             oe_order_lines_all           ol,
             oe_order_headers_all         oh,
             -- xxar_warranty_rates          wr,
             ra_batch_sources_all   rbs,
             ra_cust_trx_types_all  rcta,
             gl_code_combinations   gcc,
             hz_cust_site_uses_all  hcu,
             hz_cust_acct_sites_all hcs,
             hz_party_sites         hps,
             hz_locations           hl,
             hz_cust_accounts       hca
       where xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
                                                                                                  nvl(gcc.segment6,
                                                                                                      '803'))) =
             l_location_code
            --xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
         and hcu.site_use_id = rta.bill_to_site_use_id
         and hcs.cust_acct_site_id = hcu.cust_acct_site_id
         and hps.party_site_id = hcs.party_site_id
         and hl.location_id = hps.location_id
         and hca.cust_account_id = hcs.cust_account_id
         and rcl.interface_line_attribute6 = ol.line_id
         and oh.header_id = ol.header_id
            -- and xxinv_utils_pkg.is_fdm_system_item(ol.inventory_item_id) = 'Y'
         and rta.cust_trx_type_id = rcta.cust_trx_type_id
         and nvl(rcta.attribute5, 'N') = 'Y'
            --and wr.org_id = 737
         and ol.inventory_item_id = l_item_id --wr.inventory_item_id
         and nvl(oh.attribute7,
                 decode(hca.sales_channel_code,
                        'INDIRECT',
                        'Indirect deal',
                        'DIRECT',
                        'Direct deal',
                        hca.sales_channel_code)) = l_channel --wr.channel
         and rta.customer_trx_id = rcl.customer_trx_id
         and rbs.name in ('ORDER ENTRY', 'ORDER ENTRY CM')
         and rg.user_generated_flag is null
         and rta.trx_date between l_from_date and l_to_date --wr.from_date and nvl(wr.to_date, sysdate + 1)
          --and rta.trx_date between '01-apr-2014' and '30-jun-2014'----------------
         and rg.customer_trx_line_id = rcl.customer_trx_line_id
         and nvl(rg.amount, 0) != 0
         and rg.account_class = 'REV'
        --      and rta.trx_number='1022745'----------------
         and rbs.batch_source_id = rta.batch_source_id
         and gcc.code_combination_id(+) = hcu.gl_id_rev --rg.code_combination_id
         and xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
       and not exists
      (select 1
               from ra_cust_trx_line_gl_dist_all rg1
              where rg1.customer_trx_line_id = rcl.customer_trx_line_id
                and rg1.account_class = 'UNEARN'
                and rg1.user_generated_flag is not null)
               and not exists
      (select 1
               from ra_customer_trx_all rth, ra_customer_trx_lines_all rtl
              where rth.cust_trx_type_id =
                    fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
                                               NULL,
                                               NULL,
                                               NULL,
                                               fnd_global.ORG_ID)
                and rth.customer_trx_id = rtl.customer_trx_id
                and rtl.sales_order = oh.order_number
                and rtl.inventory_item_id=rcl.inventory_item_id)
      ;
  begin
    write_log('BEGIN CREATE_WARRENTY_INVOICES');
    
    SELECT rb.batch_source_id
      into l_batch_id
      FROM ra_batch_sources rb
     where rb.name = 'Warranty Invoices'; --'ORDER ENTRY';
     select Default_Term
     into l_terms_id
     from RA_CUST_TRX_TYPES
     where CUST_TRX_TYPE_ID=fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           fnd_global.ORG_ID);

    write_log('Found batch_id '||l_batch_id);

    -------------------------------------------------------------------------------------
    for i in c_poly_rates loop
      write_log('***** Begin c_poly_rates loop for inventory_item_id '||i.inventory_item_id||' *****');
      select mb.segment1, mb.description
        into l_item_code, l_item_desc
        from mtl_system_items_b mb
       where mb.inventory_item_id = i.INVENTORY_ITEM_ID
         and mb.organization_id =
             xxinv_utils_pkg.get_master_organization_id;
      write_log('l_item_code: '||l_item_code||'l_item_desc: '||l_item_desc);
      
      for j in c_poly_lines(i.INVENTORY_ITEM_ID,
                            i.CHANNEL,
                            i.FROM_DATE,
                            i.to_date,
                            i.RATE) loop
        
        write_log('***** Begin c_poly_lines loop for inventory_item_id '||i.inventory_item_id||' *****');
        write_log('i.CHANNEL   : '||i.CHANNEL);
        write_log('i.FROM_DATE : '||i.FROM_DATE);
        write_log('i.to_date   : '||i.to_date);
        write_log('i.RATE      : '||i.RATE);

      -- Ofer Suad  CHG0032979 New Logic of Warranty Invoices -add intilize tables
        l_trx_header_tbl.delete;
        l_trx_lines_tbl.delete;
        l_trx_dist_tbl.delete;
        l_trx_salescredits_tbl.delete;

        l_header_id := 0;
        l_line_id   := 0;
        l_dist_id   := 0;
        l_agg_amt   := 0;

        write_log('before calc l_portion');
        l_portion := 1 - (j.actual_shipment_date -
                     (TRUNC(j.actual_shipment_date, 'MONTH') - 1)) /
                     (LAST_DAY(j.actual_shipment_date) -
                     (TRUNC(j.actual_shipment_date, 'MONTH') - 1));
        write_log('l_portion: '||l_portion);
        
        l_tot_amt := round(-i.rate * (1 - j.attribute10 / 100) *
                           j.conv_rate,
                           2);
        write_log('l_tot_amt: '||l_tot_amt);
        
        l_header_id := l_header_id + 1;
        l_line_id := l_line_id + 1;
        l_trx_header_tbl(1).trx_header_id := l_header_id;
        l_trx_header_tbl(1).trx_currency:=j.invoice_currency_code;
        l_trx_header_tbl(1).bill_to_customer_id := j.cust_account_id;
        l_trx_header_tbl(1).primary_salesrep_id := -3;
        l_trx_header_tbl(1).term_id:=l_terms_id;
        l_trx_header_tbl(1).cust_trx_type_id := fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           fnd_global.ORG_ID);
        write_log('cust_trx_type_id: '||l_trx_header_tbl(1).cust_trx_type_id);
        
        l_trx_header_tbl(1).invoicing_rule_id := -2;
        -- l_trx_header_tbl(1).reference_number := j.order_number;
        -- l_trx_header_tbl(1).interface_header_attribute1 := j.order_number;

        ----------------------------------
        l_batch_source_rec.batch_source_id := l_batch_id;
        -------------------
        l_trx_lines_tbl(1).trx_header_id := l_header_id;
        l_trx_lines_tbl(1).trx_line_id := l_line_id;
        l_trx_lines_tbl(1).line_number := l_line_id;
        l_trx_lines_tbl(1).quantity_invoiced := 1;
        l_trx_lines_tbl(1).unit_selling_price := l_tot_amt;
        l_trx_lines_tbl(1).line_type := 'LINE';
        l_trx_lines_tbl(1).SALES_ORDER := j.order_number;
        l_trx_lines_tbl(1).INVENTORY_ITEM_ID := i.inventory_item_id;
        l_trx_lines_tbl(1).ACCOUNTING_RULE_ID := 1;
        l_trx_lines_tbl(1).RULE_START_DATE := j.gl_date;

        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'REV';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := j.code_combination_id;
        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
        
        write_log('before call to get_vsoe_ccid for code_combination_id: '||j.code_combination_id);
        l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                       'N',
                                                                       'Y');

        write_log('After call to get_vsoe_ccid returning: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
        
        for l in 1 .. i.WARRANTY_PERIOD + 1 loop
          write_log('Begin LOOP through warranty period '||i.WARRANTY_PERIOD);
          
          l_amt := round((i.rate * (1 - j.attribute10 / 100) * j.conv_rate) /
                         i.WARRANTY_PERIOD,
                         2);
          if l = 1 then
            l_amt := l_amt * l_portion;
          end if;
          l_agg_amt := l_agg_amt + l_amt;

          if l = i.WARRANTY_PERIOD + 1 then
            -- if l_agg_amt+l_tot_amt>0 then
            l_amt := l_amt - (l_agg_amt + l_tot_amt);
            /*else
            l_amt:=l_amt-(l_agg_amt+l_tot_amt);
            end if;*/
          end if;
          l_line_id   := l_line_id + 1;
          
          write_log('before calc ship date');
          l_ship_date := TRUNC(add_months(j.actual_shipment_date +
                                          fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'),
                                          l_line_id - 2),
                               'month');
          write_log('after calc ship date l_ship_date: '||l_ship_date);

          l_trx_lines_tbl(l_line_id).trx_header_id := l_header_id;
          l_trx_lines_tbl(l_line_id).trx_line_id := l_line_id;
          l_trx_lines_tbl(l_line_id).line_number := l_line_id;
          l_trx_lines_tbl(l_line_id).quantity_invoiced := 1;
          l_trx_lines_tbl(l_line_id).SALES_ORDER := j.order_number;
          l_trx_lines_tbl(l_line_id).unit_selling_price := l_amt;

          l_trx_lines_tbl(l_line_id).ACCOUNTING_RULE_ID := 1;
          l_trx_lines_tbl(l_line_id).RULE_START_DATE := l_ship_date;

          l_trx_lines_tbl(l_line_id).line_type := 'LINE';
          l_trx_lines_tbl(l_line_id).description := 'VSOE Line For Order ' ||
                                                    j.order_number ||
                                                    ' Item ' || l_item_code || '-' ||
                                                    l_item_desc;
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'REV';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
          
          write_log('before first call to get_vsoe_ccid for dist for code_combination_id: '||j.code_combination_id);
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                         'N',
                                                                         'N'); --5377898;
          write_log('After first call to get_vsoe_ccid for dist returning: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
          
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
          
          write_log('before second call to get_vsoe_ccid for dist for code_combination_id: '||j.code_combination_id);
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                         'N',
                                                                         'Y'); -- 5377892;
          
          write_log('After second call to get_vsoe_ccid for dist returning: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
          
          l_trx_salescredits_tbl(l_line_id).SALESREP_ID := -3;
          l_trx_salescredits_tbl(l_line_id).TRX_LINE_ID := l_line_id;
          l_trx_salescredits_tbl(l_line_id).TRX_salescredit_ID := l_line_id;

          write_log('END LOOP through warranty period '||i.WARRANTY_PERIOD);
        end loop;

        write_log('Before API Call');
        
        IF p_call_api = 'Y' THEN       
          AR_INVOICE_API_PUB.create_single_invoice(p_api_version          => 1.0,
                                                   p_batch_source_rec     => l_batch_source_rec,
                                                   p_trx_header_tbl       => l_trx_header_tbl,
                                                   p_trx_lines_tbl        => l_trx_lines_tbl,
                                                   p_trx_dist_tbl         => l_trx_dist_tbl,
                                                   p_trx_salescredits_tbl => l_trx_salescredits_tbl,
                                                   x_customer_trx_id      => l_customer_trx_id,
                                                   x_return_status        => l_return_status,
                                                   x_msg_count            => l_msg_count,
                                                   x_msg_data             => l_msg_data);

          write_log('After API Call l_customer_trx_id :'||l_customer_trx_id||' l_return_status: '||l_return_status);

          IF l_return_status = fnd_api.g_ret_sts_error OR
             l_return_status = fnd_api.g_ret_sts_unexp_error THEN
            fnd_file.put_line(fnd_file.LOG,
                              'unexpected errors found!' || l_msg_data);
          ELSE

            SELECT count(*) Into l_cnt From ar_trx_errors_gt;
            IF l_cnt = 0 THEN
              fnd_file.put_line(fnd_file.LOG,
                                'Customer Trx id ' || l_customer_trx_id);
            ELSE

              fnd_file.put_line(fnd_file.LOG,
                                'Transaction not Created, Please check ar_trx_errors_gt table');
              for k in c_errors loop
                fnd_file.put_line(fnd_file.LOG, k.error_message);
              end loop;
            END IF;
          end if;
        END IF;
      write_log('***** End c_poly_lines loop for inventory_item_id '||i.inventory_item_id||' *****');
      end loop;
      commit;
    write_log('***** End c_poly_rates loop for inventory_item_id '||i.inventory_item_id||' *****');
    end loop;
    for i in c_fdm_rates loop
    write_log('***** Begin c_fdm_rates loop for inventory_item_id '||i.inventory_item_id||' *****');
    
    select mb.segment1, mb.description
        into l_item_code, l_item_desc
        from mtl_system_items_b mb
       where mb.inventory_item_id = i.INVENTORY_ITEM_ID
         and mb.organization_id =
             xxinv_utils_pkg.get_master_organization_id;

      write_log('l_item_code: '||l_item_code||' l_item_desc: '||l_item_desc);

      for j in c_fdm_lines(i.inventory_item_id,
                           i.channel,
                           i.from_date,
                           i.to_date,
                           i.location_code,
                           i.rate) loop

        write_log('***** Begin c_fdm_lines loop for inventory_item_id '||i.inventory_item_id||' *****');
        write_log('i.CHANNEL   : '||i.CHANNEL);
        write_log('i.FROM_DATE : '||i.FROM_DATE);
        write_log('i.to_date   : '||i.to_date);
        write_log('i.RATE      : '||i.RATE);

        -- Ofer Suad  CHG0032979 New Logic of Warranty Invoices -add intilize tables
        l_trx_header_tbl.delete;
        l_trx_lines_tbl.delete;
        l_trx_dist_tbl.delete;
        l_trx_salescredits_tbl.delete;
        l_header_id := 0;
        l_line_id   := 0;
        l_dist_id   := 0;
        l_agg_amt   := 0;

        write_log('Before l_portion calc');
        l_portion := 1 - (j.actual_shipment_date -
                     (TRUNC(j.actual_shipment_date, 'MONTH') - 1)) /
                     (LAST_DAY(j.actual_shipment_date) -
                     (TRUNC(j.actual_shipment_date, 'MONTH') - 1));

        write_log('l_portion: '||l_portion);
        
        l_tot_amt := round(-i.rate * (1 - j.attribute10 / 100) *
                           j.conv_rate,
                           2);
        
        write_log('l_tot_amt: '||l_tot_amt);
        
        l_header_id := l_header_id + 1;
        l_line_id := l_line_id + 1;
        l_trx_header_tbl(1).trx_header_id := l_header_id;
         l_trx_header_tbl(1).trx_currency:=j.invoice_currency_code;
        l_trx_header_tbl(1).primary_salesrep_id := -3;
        l_trx_header_tbl(1).term_id:=l_terms_id;
        l_trx_header_tbl(1).bill_to_customer_id := j.cust_account_id;
        
        write_log('Before cust_trx_type_id for fnd_global.ORG_ID '||fnd_global.ORG_ID);
        l_trx_header_tbl(1).cust_trx_type_id := fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           fnd_global.ORG_ID);
        write_log('After cust_trx_type_id: '||l_trx_header_tbl(1).cust_trx_type_id);
        
        l_trx_header_tbl(1).invoicing_rule_id := -2;
        -- l_trx_header_tbl(1).reference_number := j.order_number;
        -- l_trx_header_tbl(1).interface_header_attribute1 := j.order_number;

        ----------------------------------
        l_batch_source_rec.batch_source_id := l_batch_id;
        -------------------
        l_trx_lines_tbl(1).trx_header_id := l_header_id;
        l_trx_lines_tbl(1).trx_line_id := l_line_id;
        l_trx_lines_tbl(1).line_number := l_line_id;
        l_trx_lines_tbl(1).quantity_invoiced := 1;
        l_trx_lines_tbl(1).unit_selling_price := l_tot_amt;
        l_trx_lines_tbl(1).line_type := 'LINE';
        l_trx_lines_tbl(1).SALES_ORDER := j.order_number;
        l_trx_lines_tbl(1).INVENTORY_ITEM_ID := i.inventory_item_id;
        l_trx_lines_tbl(1).ACCOUNTING_RULE_ID := 1;
        l_trx_lines_tbl(1).RULE_START_DATE := j.gl_date;

        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'REV';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := j.code_combination_id;
        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
        
        write_log('Before get_vsoe_ccid for code_combination_id: '||j.code_combination_id);
        l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                       'Y',
                                                                       'Y');

        write_log('After get_vsoe_ccid returning code_combination_id: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
        
        for l in 1 .. i.WARRANTY_PERIOD + 1 loop
          write_log('Begin loop through warranty period for '||i.WARRANTY_PERIOD);
          
          l_amt := round((i.rate * (1 - j.attribute10 / 100) * j.conv_rate) /
                         i.WARRANTY_PERIOD,
                         2);
          if l = 1 then
            l_amt := l_amt * l_portion;
          end if;
          l_agg_amt := l_agg_amt + l_amt;

          if l = i.WARRANTY_PERIOD + 1 then
            -- if l_agg_amt+l_tot_amt>0 then
            l_amt := l_amt - (l_agg_amt + l_tot_amt);
            /*else
            l_amt:=l_amt-(l_agg_amt+l_tot_amt);
            end if;*/
          end if;
          l_line_id   := l_line_id + 1;
          
          write_log('Before l_ship_date');
          l_ship_date := TRUNC(add_months(j.actual_shipment_date +
                                          fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'),
                                          l_line_id - 2),
                               'month');
          write_log('After l_ship_date: '||l_ship_date);

          l_trx_lines_tbl(l_line_id).trx_header_id := l_header_id;
          l_trx_lines_tbl(l_line_id).trx_line_id := l_line_id;
          l_trx_lines_tbl(l_line_id).line_number := l_line_id;
          l_trx_lines_tbl(l_line_id).quantity_invoiced := 1;
          l_trx_lines_tbl(l_line_id).SALES_ORDER := j.order_number;
          l_trx_lines_tbl(l_line_id).unit_selling_price := l_amt;

          l_trx_lines_tbl(l_line_id).ACCOUNTING_RULE_ID := 1;
          l_trx_lines_tbl(l_line_id).RULE_START_DATE := l_ship_date;

          l_trx_lines_tbl(l_line_id).line_type := 'LINE';
          l_trx_lines_tbl(l_line_id).description := 'VSOE Line For Order ' ||
                                                    j.order_number ||
                                                    ' Item ' || l_item_code || '-' ||
                                                    l_item_desc;
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'REV';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
          
          write_log('before first call to get_vsoe_ccid for dist for code_combination_id: '||j.code_combination_id);
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                         'Y',
                                                                         'N'); --5377898;
          write_log('After first call to get_vsoe_ccid for dist returning: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
          
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).ATTRIBUTE1 := 'Y';
          
          write_log('before second call to get_vsoe_ccid for dist for code_combination_id: '||j.code_combination_id);
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
                                                                         'Y',
                                                                         'Y'); -- 5377892;

          write_log('After second call to get_vsoe_ccid for dist returning: '||l_trx_dist_tbl(l_dist_id).code_combination_id);
        end loop;
        
        write_log('Before API Call');

        IF p_call_api = 'Y' THEN   
          AR_INVOICE_API_PUB.create_single_invoice(p_api_version          => 1.0,
                                                   p_batch_source_rec     => l_batch_source_rec,
                                                   p_trx_header_tbl       => l_trx_header_tbl,
                                                   p_trx_lines_tbl        => l_trx_lines_tbl,
                                                   p_trx_dist_tbl         => l_trx_dist_tbl,
                                                   p_trx_salescredits_tbl => l_trx_salescredits_tbl,
                                                   x_customer_trx_id      => l_customer_trx_id,
                                                   x_return_status        => l_return_status,
                                                   x_msg_count            => l_msg_count,
                                                   x_msg_data             => l_msg_data);

          write_log('After API Call l_customer_trx_id :'||l_customer_trx_id||' l_return_status: '||l_return_status);

          IF l_return_status = fnd_api.g_ret_sts_error OR
             l_return_status = fnd_api.g_ret_sts_unexp_error THEN
            fnd_file.put_line(fnd_file.LOG,
                              'unexpected errors found!' || l_msg_data);
          ELSE

            SELECT count(*) Into l_cnt From ar_trx_errors_gt;
            IF l_cnt = 0 THEN
              fnd_file.put_line(fnd_file.LOG,
                                'Customer Trx id ' || l_customer_trx_id);
            ELSE

              fnd_file.put_line(fnd_file.LOG,
                                'Transaction not Created, Please check ar_trx_errors_gt table');
              for k in c_errors loop
                fnd_file.put_line(fnd_file.LOG, k.error_message);
              end loop;
            END IF;
          end if;
        END IF;
        
        write_log('***** End c_fdm_lines loop for inventory_item_id '||i.inventory_item_id||' *****');
      end loop;
      commit;
      write_log('***** End c_fdm_rates loop for inventory_item_id '||i.inventory_item_id||' *****');
    end loop;

    -------------------------------------------------------------------------------------

  end Create_warrenty_Invoices;

end XXAR_WARRANTY_RATES_DEBUG_PKG;
/

SHOW ERRORS
