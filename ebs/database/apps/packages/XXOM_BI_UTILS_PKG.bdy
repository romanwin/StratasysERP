create or replace package body xxom_bi_utils_pkg is
  --
  --------------------------------------------------------------------
  --  name:            xxom_bi_utils_pkg
  --  cust:            chg0043884 - package to be called for program xxom: populate xxbi_oe_order_lines_all
  --  create by:       bellona banerjee
  --  revision:        1.0
  --  creation date:   07/09/2018
  --------------------------------------------------------------------
  --  purpose :        package created to populate xxbi_oe_order_lines_all table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  bellona(tcs)   initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            message
  --  create by:       bellona(tcs)
  --  creation date:   12/09/2018
  --------------------------------------------------------------------
  --  purpose :        write log messages
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  bellona(tcs)      chg0043884- initial build
  --------------------------------------------------------------------
  procedure message(p_msg         varchar2,
                    p_destination number default fnd_file.log) is
  begin
    if fnd_global.conc_program_id != -1 then
      fnd_file.put_line(p_destination,
                        to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS - ') ||
                        p_msg);
    else
      dbms_output.put_line(to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS - ') ||
                           p_msg);
    end if;
  
  end;
  --------------------------------------------------------------------
  --  name:            save_profile
  --  create by:       bellona(tcs)
  --  creation date:   12/09/2018
  --------------------------------------------------------------------
  --  purpose :        save last run time of program xxom: populate xxbi_oe_order_lines_all
  --                   into profile xxom_order_lines_conc_last_run
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  bellona(tcs)    chg0043884-initial build
  --------------------------------------------------------------------
  procedure save_profile(p_date       in date,
                         p_error_code out varchar2,
                         p_error_desc out varchar2) as
    --
    --pragma autonomous_transaction;
    l_profile_check boolean;
    l_date          varchar2(30);
    --
  begin
  
    p_error_code := '0';
    p_error_desc := null;
  
    if p_date is null then
      l_date := to_char(sysdate, 'DD-MON-YYYY HH24:MI:SS');
    else
      l_date := to_char(p_date, 'DD-MON-YYYY HH24:MI:SS');
    end if;
  
    l_profile_check := fnd_profile.save(x_name       => 'XXOM_ORDER_LINES_CONC_LAST_RUN',
                                        x_value      => l_date,
                                        x_level_name => 'SITE');
  
    if l_profile_check then
      p_error_code := '0';
      p_error_desc := 'Profile XXOM_ORDER_LINES_CONC_LAST_RUN set successfully to ' ||
                      l_date;
      message(p_error_desc);
    else
      p_error_code := '1';
      p_error_desc := 'Profile XXOM_ORDER_LINES_CONC_LAST_RUN Update Failed at site Level. Error:' ||
                      sqlerrm;
      message(p_error_desc);
    end if;
  
    commit;
  
  end save_profile;
  ---------------------------------------------------------------------
  -- ver       when        who        description
  -- --------  ----------  ---------  ---------------------------------
  -- 1.0       17/10/2018  roman w.   chg0043884-initial build
  ---------------------------------------------------------------------
  procedure is_parameters_valid(p_date_from  in date,
                                p_date_to    in date,
                                p_error_code out number,
                                p_error_desc out varchar2) is
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    if p_date_from > p_date_to then
      p_error_code := '2';
      p_error_desc := 'Date FROM should be less when Date TO ';
    end if;
  end is_parameters_valid;
  --------------------------------------------------------------------
  -- ver      when        who           description
  -- -------  ----------  ------------  -------------------------------
  -- 1.0      17/10/2018  roman w.      chg0043884 - initial build
  --------------------------------------------------------------------
  function get_min_last_udate_dt return date is
    --------------------------------
    --     local definition
    --------------------------------
    l_ret_val date;
    --------------------------------
    --     code section
    --------------------------------
  begin
  
    select min(oola.last_update_date)
      into l_ret_val
      from oe_order_lines_all oola;
  
    return l_ret_val;
  
  end get_min_last_udate_dt;

  --------------------------------------------------------------------
  -- ver      when        who           description
  -- -------  ----------  ------------  -------------------------------
  -- 1.0      17/10/2018  roman w.      chg0043884 - initial build
  --------------------------------------------------------------------
  function get_max_last_udate_dt return date is
    --------------------------------
    --     local definition
    --------------------------------
    l_ret_val date;
    --------------------------------
    --     code section
    --------------------------------
  begin
    select max(oola.last_update_date)
      into l_ret_val
      from oe_order_lines_all oola;
  
    return l_ret_val;
  
  end get_max_last_udate_dt;

  --------------------------------------------------------------------
  --  ver  when        who         desc
  --  ---  ----------  ----------  -----------------------------------
  --  1.0  12/09/2018  roman w.    chg0043884-initial build
  --------------------------------------------------------------------
  procedure calculate_period(p_in_date_from  in date,
                             p_in_date_to    in date,
                             p_out_date_from out date,
                             p_out_date_to   out date,
                             p_error_code    out varchar2,
                             p_error_desc    out varchar2) is
    --------------------------------
    --     local definition
    --------------------------------
    l_min_last_update_dt     date;
    l_max_last_update_dt     date;
    l_profile_value          varchar2(300);
    l_default_minutes_period number;
    --------------------------------
    --     code section
    --------------------------------
  begin
  
    l_min_last_update_dt := get_min_last_udate_dt;
    l_max_last_update_dt := get_max_last_udate_dt;
    l_profile_value      := fnd_profile.VALUE('XXOM_BI_UTILS_MINUTES_FORWARD_PERIOD');
    begin
      EXECUTE IMMEDIATE 'select ' || l_profile_value || ' from dual'
        into l_default_minutes_period;
    exception
      when others then
        l_default_minutes_period := xxom_bi_utils_pkg.C_DEFAULT_PERIOD;
    end;
    -- calculate date from
    if p_in_date_from is not null then
      p_out_date_from := p_in_date_from;
    else
      p_out_date_from := nvl(fnd_conc_date.string_to_date(fnd_profile.value('XXOM_ORDER_LINES_CONC_LAST_RUN')),
                             l_min_last_update_dt);
    end if;
  
    -- calculate date to
    p_out_date_to := nvl(p_in_date_to,
                         (p_out_date_from + l_default_minutes_period));
  
    if p_out_date_to > sysdate then
      p_out_date_to := sysdate;
    end if;
  
    message('p_in_date_from - ' ||
            to_char(p_in_date_from, 'DD/MM/YYYY HH24:MI:SS'));
    message('p_in_date_to - ' ||
            to_char(p_in_date_to, 'DD/MM/YYYY HH24:MI:SS'));
    message('p_out_date_from - ' ||
            to_char(p_out_date_from, 'DD/MM/YYYY HH24:MI:SS'));
    message('p_out_date_to - ' ||
            to_char(p_out_date_to, 'DD/MM/YYYY HH24:MI:SS'));
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION xxom_bi_utils_pkg.calculate_period(' ||
                      to_char(p_in_date_from, 'DD/MM/YYYY HH24:MI:SS') || ',' ||
                      to_char(p_in_date_to, 'DD/MM/YYYY HH24:MI:SS') ||
                      ') - ' || sqlerrm;
      message(p_error_desc);
    
  end calculate_period;

  --------------------------------------------------------------------
  --  name:            pop_xxbi_oe_order_lines_all
  --  create by:       bellona(tcs)
  --  creation date:   12/09/2018
  --------------------------------------------------------------------
  --  purpose :        main procedure to populate xxbi_oe_order_lines_all
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  bellona(tcs)    chg0043884-initial build
  --                                       concurrent : xxom: populate xxbi_oe_order_lines_all
  --------------------------------------------------------------------
  procedure pop_xxbi_oe_order_lines_all(errbuf      out varchar2,
                                        retcode     out varchar2,
                                        p_date_from in varchar2,
                                        p_date_to   in varchar2) is
  
    cursor c_get_eligible_records(c_date_from in date, c_date_to in date) is
      select oola.line_id,
             oola.unit_list_price,
             oola.attribute4,
             oola.creation_date,
             oola.inventory_item_id,
             oola.price_list_id l_price_list_id,
             (select ooha.price_list_id
                from oe_order_headers_all ooha
               where ooha.header_id = oola.header_id
                 and ooha.org_id = oola.org_id) h_price_list_id,
             oola.pricing_date
        from oe_order_lines_all oola
       where 1 = 1
         and oola.last_update_date between c_date_from and c_date_to;
  
    l_row_count                    number;
    l_oe_order_line_id             number;
    l_is_option_line               varchar2(1);
    l_is_bundle_line               varchar2(1);
    l_is_model_line                varchar2(1);
    l_is_comp_bundle_line          varchar2(1);
    l_price_list_dist              number;
    l_price_list_for_resin         number;
    l_is_get_item_line             varchar2(1);
    l_lst_price_by_headr_price_lst number;
    l_lst_price_by_line_price_lst  number;
    l_item_cogs_at_creation_date   number;
    l_request_id                   number;
    l_last_update_date             date;
    l_last_updated_by              number(15);
    l_created_by                   number(15);
    l_creation_date                date;
  
    l_i          number := 1;
    l_count      number;
    l_date_from  date;
    l_date_to    date;
    l_line_count number;
  begin
    retcode := '0';
    errbuf  := null;
    message('p_date_from : ' || p_date_from);
    message('p_date_to : ' || p_date_to);
  
    l_date_from := fnd_conc_date.string_to_date(p_date_from);
    l_date_to   := fnd_conc_date.string_to_date(p_date_to);
  
    calculate_period(l_date_from,
                     l_date_to,
                     l_date_from,
                     l_date_to,
                     retcode,
                     errbuf);
  
    if retcode != '0' then
      message(errbuf);
      return;
    end if;
  
    is_parameters_valid(l_date_from, l_date_to, retcode, errbuf);
  
    if retcode != '0' then
      message(errbuf);
      return;
    end if;
  
    select count(*)
      into l_line_count
      from oe_order_lines_all oola
     where 1 = 1
       and oola.last_update_date between l_date_from and l_date_to;
  
    message('Line count : ' || l_line_count);
  
    for l_rec in c_get_eligible_records(l_date_from, l_date_to) --c_get_eligible_records(p_last_run_dt)
     loop
      begin
        message('LINE_ID :' || l_rec.line_id);
        --using functions to populate columns in table type variable
        l_oe_order_line_id := l_rec.line_id;
      
        l_is_option_line := xxoe_utils_pkg.is_option_line(l_rec.line_id);
      
        l_is_bundle_line := xxoe_utils_pkg.is_bundle_line(l_rec.line_id);
      
        l_is_model_line := xxoe_utils_pkg.is_model_line(l_rec.line_id);
      
        l_is_comp_bundle_line := xxoe_utils_pkg.is_comp_bundle_line(l_rec.line_id);
      
        l_price_list_dist := xxar_autoinvoice_pkg.get_price_list_dist(l_rec.line_id,
                                                                      l_rec.unit_list_price,
                                                                      l_rec.attribute4);
      
        l_price_list_for_resin := xxar_autoinvoice_pkg.get_price_list_for_resin(l_rec.line_id,
                                                                                l_rec.unit_list_price,
                                                                                l_rec.attribute4);
      
        l_is_get_item_line             := xxqp_get_item_avg_dis_pkg.is_get_item_line(l_rec.line_id);
        l_lst_price_by_headr_price_lst := xxqp_get_item_avg_dis_pkg.get_price(l_rec.inventory_item_id,
                                                                              l_rec.h_price_list_id,
                                                                              l_rec.pricing_date,
                                                                              l_rec.line_id);
      
        l_lst_price_by_line_price_lst := xxqp_get_item_avg_dis_pkg.get_price(l_rec.inventory_item_id,
                                                                             l_rec.l_price_list_id,
                                                                             l_rec.pricing_date,
                                                                             l_rec.line_id);
      
        l_item_cogs_at_creation_date := xxcst_ratam_pkg.get_il_std_cost(null,
                                                                        l_rec.creation_date,
                                                                        l_rec.inventory_item_id);
      
        select count(*)
          into l_count
          from xxbi_oe_order_lines_all line_tbl
         where line_tbl.oe_order_line_id = l_oe_order_line_id;
      
        if l_count > 0 then
        
          update xxbi_oe_order_lines_all line_tbl
             set oe_order_line_id               = l_oe_order_line_id,
                 is_option_line                 = l_is_option_line,
                 is_bundle_line                 = l_is_bundle_line,
                 is_model_line                  = l_is_model_line,
                 is_comp_bundle_line            = l_is_comp_bundle_line,
                 price_list_dist                = l_price_list_dist,
                 price_list_for_resin           = l_price_list_for_resin,
                 is_get_item_line               = l_is_get_item_line,
                 list_price_by_headr_price_list = l_lst_price_by_headr_price_lst,
                 list_price_by_line_price_list  = l_lst_price_by_line_price_lst,
                 item_cogs_at_creation_date     = l_item_cogs_at_creation_date,
                 request_id                     = fnd_global.conc_request_id,
                 last_update_date               = sysdate,
                 last_updated_by                = fnd_global.user_id,
                 created_by                     = fnd_global.user_id,
                 creation_date                  = sysdate
           where line_tbl.oe_order_line_id = l_oe_order_line_id;
        
        else
        
          insert into xxbi_oe_order_lines_all
            (oe_order_line_id,
             is_option_line,
             is_bundle_line,
             is_model_line,
             is_comp_bundle_line,
             price_list_dist,
             price_list_for_resin,
             is_get_item_line,
             list_price_by_headr_price_list,
             list_price_by_line_price_list,
             item_cogs_at_creation_date,
             request_id,
             last_update_date,
             last_updated_by,
             created_by,
             creation_date)
          values
            (l_oe_order_line_id,
             l_is_option_line,
             l_is_bundle_line,
             l_is_model_line,
             l_is_comp_bundle_line,
             l_price_list_dist,
             l_price_list_for_resin,
             l_is_get_item_line,
             l_lst_price_by_headr_price_lst,
             l_lst_price_by_line_price_lst,
             l_item_cogs_at_creation_date,
             fnd_global.conc_request_id,
             sysdate,
             fnd_global.user_id,
             fnd_global.user_id,
             sysdate);
        end if;
      
        if mod(l_i, 100) = 0 then
          commit;
        end if;
      
        l_i := l_i + 1;
      
      exception
        when others then
          retcode := '1';
          errbuf  := 'EXCEPTION_LOOP: please chaeck LOG file';
          message('EXCEPTION_LOOP: LINE_ID = ' || l_rec.line_id || ' . ' ||
                  sqlerrm);
      end;
    end loop;
  
    save_profile(l_date_to, retcode, errbuf);
  
  exception
    when others then
      retcode := 1;
      errbuf  := 'Procedure pop_XXBI_OE_ORDER_LINES_ALL - Failed - ' ||
                 substr(sqlerrm, 1, 240);
  end pop_xxbi_oe_order_lines_all;

  --------------------------------------------------------------------
  --  ver  date        name           desc
  -- ----  ----------  -------------  --------------------------------
  --  1.0  07/11/2018  Roman W.       CHG0043884-initial build
  --------------------------------------------------------------------                                    
  procedure delete_old_rows_oe_order_lines(errbuf  out varchar2,
                                           retcode out varchar2)
  
   IS
    l_last_run_dt   DATE := fnd_conc_date.string_to_date(fnd_profile.value_specific('XXOM_ORDER_LINES_CONC_LAST_RUN'));
    l_profile_value VARCHAR2(300) := fnd_profile.value_specific('XXOM_ORDER_LINES_DELETE_DAYS_BACK');
    l_rec           NUMBER := 0;
  
  BEGIN
  
    message('Value in profile XXOM_ORDER_LINES_CONC_LAST_RUN: ' ||
            to_char(l_last_run_dt, 'DD/MM/YYYY HH24:MI:SS'));
    message('Value in profile XXOM_ORDER_LINES_DELETE_DAYS_BACK: ' ||
            l_profile_value);
  
    IF l_last_run_dt IS NULL THEN
      l_last_run_dt := SYSDATE;
    END IF;
  
    IF l_profile_value IS NULL THEN
      retcode := '2';
      errbuf  := 'Value in profile XXOM_ORDER_LINES_CONC_LAST_RUN is missing.';
      message(errbuf);
      return;
    END IF;
  
    select count(1)
      into l_rec
      from xxbi_oe_order_lines_all xoola
     where xoola.last_update_date < (l_last_run_dt - l_profile_value);
  
    message(l_rec || ' rows to be deleted');
  
    delete from xxbi_oe_order_lines_all xoola
     where xoola.last_update_date < (l_last_run_dt - l_profile_value);
  
    message(SQL%ROWCOUNT || ' rows deleted successfully');
    COMMIT;
  exception
    when others then
      ROLLBACK;
      retcode := 1;
      errbuf  := 'Procedure delete_old_rows_oe_order_lines - Failed - ' ||
                 substr(sqlerrm, 1, 240);
  END delete_old_rows_oe_order_lines;

end xxom_bi_utils_pkg;
/