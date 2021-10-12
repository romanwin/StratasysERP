create or replace package body xxar_warranty_rates_pkg IS

  --------------------------------------------------------------------
  --  name:            XXAR_WARRANTY_RATES_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --  1.1  25/07/2013  Dalit A. Raviv    add commit to unEarned_warrenty_revenue
  --  1.2  17/04/2019  Ofer Suad         CHG0045252 -  ignore avg discount when list price is zero
  --  1.3  30/07/2019  Ofer Suad		 CHG0045976 -  VSOE system does not take into account SDM system
  --------------------------------------------------------------------

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
  --  1.5  25/01/2015 Ofer Suad  CHG0034240 Apply warranty on CM
  --  1.6  21/04/2015 Ofer Suad  CHG0035120 Exclude IC sales to Non-Oracle companies from VSOE
  --  1.7  30/07/17   yuval tal  CHG0040061 modifu curso in Create_warrenty_Invoices
  --  1.8  23/07/2017 yuval tal  INC0098151 Replace item id condition to improve perfomance
  --  1.9  13/08/2017 Ofer Suad  INC0099639 Add Hint to improve perfomance
  --  1.10 16/10/2017 Ofer Suad  CHG0041688 -  Support System Kit Item\
  --  1.11 17/04/2019 Ofer Suad  CHG0045252 -  ignore avg discount when list price is zero
  --  1.12 17/11/2019 Ofer Suad  CHG0046674- when order lines has more than 1 system and it has multiple ship set
  --------------------------------------------------------------------
  PROCEDURE ins_check_line(p_user_id            IN NUMBER,
		   p_warrenty_rates_tbl IN t_warrenty_rates_tbl,
		   p_error_code         OUT VARCHAR2,
		   p_error_desc         OUT VARCHAR2) IS

    l_rate_id NUMBER := NULL;

  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
    FOR i IN p_warrenty_rates_tbl.first .. p_warrenty_rates_tbl.last LOOP
      SELECT xxar_warranty_rates_s.nextval
      INTO   l_rate_id
      FROM   dual;

      INSERT INTO xxar_warranty_rates
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
      VALUES
        (l_rate_id,
         p_warrenty_rates_tbl(i).org_id,
         p_warrenty_rates_tbl(i).channel,
         p_warrenty_rates_tbl(i).inventory_item_id,
         p_warrenty_rates_tbl(i).warranty_period,
         p_warrenty_rates_tbl(i).rate,
         p_warrenty_rates_tbl(i).to_date + 1,
         p_warrenty_rates_tbl(i).location_code,
         NULL,
         SYSDATE,
         p_user_id,
         fnd_global.login_id,
         SYSDATE,
         p_user_id);
    END LOOP;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'Problem insert - ' || substr(SQLERRM, 1, 240);
  END ins_check_line;
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                    FIND the GL account with VSOE product line
  --------------------------------------------------------------------

  FUNCTION get_vsoe_ccid(p_sys_ccid  NUMBER,
		 is_fdm_item VARCHAR2,
		 is_unearned VARCHAR2) RETURN NUMBER IS
    l_new_cc_id      NUMBER;
    l_app_short_name fnd_application.application_short_name%TYPE;
    l_delimiter      fnd_id_flex_structures.concatenated_segment_delimiter%TYPE;
    ok               BOOLEAN := FALSE;
    seg_war          fnd_flex_ext.segmentarray;
    num_segments     INTEGER;
    l_result         BOOLEAN := FALSE;

    l_segment3  gl_code_combinations.segment5%TYPE;
    l_segment4  gl_code_combinations.segment5%TYPE;
    l_segment5  gl_code_combinations.segment5%TYPE;
    l_segment6  gl_code_combinations.segment5%TYPE;
    l_segment7  gl_code_combinations.segment5%TYPE;
    l_segment8  gl_code_combinations.segment5%TYPE;
    l_segment9  gl_code_combinations.segment5%TYPE;
    l_segment10 gl_code_combinations.segment5%TYPE;

    CURSOR c_old_seg IS
      SELECT gcc_sys.chart_of_accounts_id,
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

      FROM   gl_code_combinations gcc_sys
      WHERE  gcc_sys.code_combination_id = p_sys_ccid;
  BEGIN

    l_new_cc_id := NULL;
    FOR i IN c_old_seg LOOP

      IF is_fdm_item != 'Y' THEN
        l_segment5 := fnd_profile.value('XX_VSOE_POLY_PRODUCT_LINE');
      ELSE
        l_segment5 := fnd_profile.value('XX_VSOE_FDM_PRODUCT_LINE');
      END IF;

      SELECT fap.application_short_name,
	 fifs.concatenated_segment_delimiter
      INTO   l_app_short_name,
	 l_delimiter
      FROM   fnd_application        fap,
	 fnd_id_flexs           fif,
	 fnd_id_flex_structures fifs
      WHERE  fif.application_id = fap.application_id
      AND    fif.id_flex_code = 'GL#'
      AND    fifs.application_id = fif.application_id
      AND    fifs.id_flex_code = fif.id_flex_code
      AND    fifs.id_flex_num = i.chart_of_accounts_id;

      IF is_unearned != 'Y' THEN
        l_segment3 := i.segment3;
      ELSE
        l_segment3 := fnd_profile.value('XX_VSOE_UNEAREBD_ACCOUNT');
      END IF;

      BEGIN
        SELECT gcc_war.code_combination_id
        INTO   l_new_cc_id
        FROM   gl_code_combinations gcc_war
        WHERE  i.segment1 = gcc_war.segment1
        AND    i.segment2 = gcc_war.segment2
        AND    l_segment3 = gcc_war.segment3
        AND    nvl(i.segment4, 0) = nvl(gcc_war.segment4, 0)
        AND    l_segment5 = gcc_war.segment5
        AND    i.segment6 = gcc_war.segment6
        AND    i.segment7 = gcc_war.segment7
        AND    nvl(i.segment8, 0) = nvl(gcc_war.segment8, 0)
        AND    i.segment9 = gcc_war.segment9
        AND    nvl(i.segment10, 0) = nvl(gcc_war.segment10, 0);

      EXCEPTION
        WHEN OTHERS THEN

          l_result := fnd_flex_ext.get_segments(l_app_short_name,
				'GL#',
				i.chart_of_accounts_id,
				i.code_combination_id,
				num_segments,
				seg_war);

          IF i.chart_of_accounts_id = 50308 THEN
	seg_war(3) := l_segment3;
	seg_war(5) := l_segment5;

          ELSE
	seg_war(3) := l_segment3;
	seg_war(4) := l_segment5;
	seg_war(5) := i.segment6;
	seg_war(6) := i.segment7;
	seg_war(7) := i.segment10;
	seg_war(8) := i.segment9;

          END IF;

          ok := fnd_flex_ext.get_combination_id(l_app_short_name,
				'GL#',
				i.chart_of_accounts_id,
				SYSDATE,
				num_segments,
				seg_war,
				l_new_cc_id);
          IF ok THEN
	-- this means the CCID is OK
	NULL;
          ELSE
	fnd_file.put_line(fnd_file.log,
		      'vsoe ccid not found for ' || p_sys_ccid);
	RETURN NULL;
          END IF;
      END;
      -- fnd_file.put_line(fnd_file.log, 'l_new_cc_id ' || l_new_cc_id);
    END LOOP;
    RETURN l_new_cc_id;
  END;

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
    INTO   l_count
    FROM   xxar_warranty_rates xwr
    WHERE  xwr.org_id = p_warrenty_rates_rec.org_id
    AND    xwr.location_code = p_warrenty_rates_rec.location_code
    AND    xwr.channel = p_warrenty_rates_rec.channel
    AND    xwr.inventory_item_id = p_warrenty_rates_rec.inventory_item_id
    AND    p_warrenty_rates_rec.from_date BETWEEN xwr.from_date AND
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
  PROCEDURE unearned_warrenty_revenue(errbuf  OUT VARCHAR2,
			  retcode OUT VARCHAR2) IS

    CURSOR c_poly_rates IS
      SELECT wr.rate,
	 wr.warranty_period,
	 wr.inventory_item_id,
	 wr.channel,
	 wr.from_date,
	 nvl(wr.to_date, SYSDATE + 1) to_date
      FROM   xxar_warranty_rates wr
      WHERE  wr.org_id = fnd_global.org_id
      AND    xxhz_party_ga_util.is_system_item(wr.inventory_item_id) = 'Y';

    CURSOR c_poly_lines(l_item_id   NUMBER,
		l_channel   VARCHAR2,
		l_from_date DATE,
		l_to_date   DATE,
		l_rate      NUMBER) IS
      SELECT CASE
	   WHEN rbs.name = 'ORDER ENTRY' THEN
	    l_rate
	   ELSE
	    (l_rate * -1)
	 END rate,
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
      FROM   ra_customer_trx_lines        rcl,
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
      WHERE  rcl.interface_line_attribute6 = ol.line_id
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    oh.header_id = ol.header_id
	-- and xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
      AND    rta.cust_trx_type_id = rcta.cust_trx_type_id
      AND    nvl(rcta.attribute5, 'N') = 'Y'
      AND    fnd_global.org_id = rcl.org_id
      AND    ol.inventory_item_id = l_item_id --wr.inventory_item_id
      AND    nvl(oh.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = l_channel --wr.channel
      AND    rta.customer_trx_id = rcl.customer_trx_id
      AND    rbs.name IN ('ORDER ENTRY', 'ORDER ENTRY CM')
      AND    rg.user_generated_flag IS NULL
      AND    rta.trx_date BETWEEN /*wr.from_date*/
	 l_from_date AND nvl( /*wr.to_date*/ l_to_date, SYSDATE + 1)
      AND    rg.customer_trx_line_id = rcl.customer_trx_line_id
      AND    nvl(rg.amount, 0) != 0
      AND    rg.account_class = 'REV'
      AND    rbs.batch_source_id = rta.batch_source_id
      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_cust_trx_line_gl_dist_all rg1
	  WHERE  rg1.customer_trx_line_id = rcl.customer_trx_line_id
	  AND    rg1.account_class = 'UNEARN'
	  AND    rg1.user_generated_flag IS NOT NULL);

    CURSOR c_fdm_rates IS
      SELECT wr.rate,
	 wr.warranty_period,
	 xxgl_utils_pkg.get_dff_value_description(1013892,
				      wr.location_code) loc,
	 wr.inventory_item_id,
	 wr.channel,
	 wr.from_date,
	 nvl(wr.to_date, SYSDATE + 1) to_date
      FROM   xxar_warranty_rates wr
      WHERE  wr.org_id = 737
      AND    xxinv_utils_pkg.is_fdm_system_item(wr.inventory_item_id) = 'Y';

    CURSOR c_fdm_lines(l_item_id       NUMBER,
	           l_channel       VARCHAR2,
	           l_from_date     DATE,
	           l_to_date       DATE,
	           l_location_code VARCHAR2,
	           l_rate          NUMBER) IS
      SELECT CASE
	   WHEN rbs.name = 'ORDER ENTRY' THEN
	    l_rate -- wr.rate
	   ELSE
	    ( /*wr.rate*/
	     l_rate * -1)
	 END rate,
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

      FROM   ra_customer_trx_lines        rcl,
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
      WHERE  xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
								  nvl(gcc.segment6,
								      '803'))) =
	 l_location_code
	--xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hps.party_site_id = hcs.party_site_id
      AND    hl.location_id = hps.location_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    rcl.interface_line_attribute6 = ol.line_id
      AND    oh.header_id = ol.header_id
	-- and xxinv_utils_pkg.is_fdm_system_item(ol.inventory_item_id) = 'Y'
      AND    rta.cust_trx_type_id = rcta.cust_trx_type_id
      AND    nvl(rcta.attribute5, 'N') = 'Y'
	--and wr.org_id = 737
      AND    ol.inventory_item_id = l_item_id --wr.inventory_item_id
      AND    nvl(oh.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = l_channel --wr.channel
      AND    rta.customer_trx_id = rcl.customer_trx_id
      AND    rbs.name IN ('ORDER ENTRY', 'ORDER ENTRY CM')
      AND    rg.user_generated_flag IS NULL
      AND    rta.trx_date BETWEEN l_from_date AND l_to_date --wr.from_date and nvl(wr.to_date, sysdate + 1)
      AND    rg.customer_trx_line_id = rcl.customer_trx_line_id
      AND    nvl(rg.amount, 0) != 0
      AND    rg.account_class = 'REV'
      AND    rbs.batch_source_id = rta.batch_source_id
      AND    gcc.code_combination_id(+) = hcu.gl_id_rev --rg.code_combination_id
      AND    xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_cust_trx_line_gl_dist_all rg1
	  WHERE  rg1.customer_trx_line_id = rcl.customer_trx_line_id
	  AND    rg1.account_class = 'UNEARN'
	  AND    rg1.user_generated_flag IS NOT NULL);

    l_revenue_adj_rec    ar_revenue_adjustment_pvt.rev_adj_rec_type;
    l_return_status      VARCHAR2(100);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(1000);
    l_adjustment_id      NUMBER;
    l_adjustment_number  VARCHAR2(1000);
    l_sus                NUMBER;
    l_program_request_id NUMBER := -1;
  BEGIN
    retcode              := 0;
    errbuf               := NULL;
    l_program_request_id := fnd_global.conc_request_id;

    FOR j IN c_poly_rates LOOP
      FOR i IN c_poly_lines(j.inventory_item_id,
		    j.channel,
		    j.from_date,
		    j.to_date,
		    j.rate) LOOP
        fnd_file.put_line(fnd_file.log, 'Trx Number Poly ' || i.trx_number);
        SELECT nvl(SUM(nvl(amount, 0)), 0)
        INTO   l_sus
        FROM   ra_cust_trx_line_gl_dist_all rda
        WHERE  rda.customer_trx_line_id = i.customer_trx_line_id
        AND    rda.account_class = 'SUSPENSE';

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

        ar_revenueadjust_pub.unearn_revenue(p_api_version       => 2.0,
			        p_init_msg_list     => fnd_api.g_true,
			        x_return_status     => l_return_status,
			        x_msg_count         => l_msg_count,
			        x_msg_data          => l_msg_data,
			        p_rev_adj_rec       => l_revenue_adj_rec,
			        p_org_id            => i.org_id,
			        x_adjustment_id     => l_adjustment_id,
			        x_adjustment_number => l_adjustment_number);
        IF l_msg_count != 0 THEN
          dbms_output.put_line(substr(l_msg_data, 0, 190));
          /*retcode := 2;
          errbuf  := 'Trx Number ' || i.trx_number || ' Line id - ' ||
                     i.customer_trx_line_id || ' - ' ||
                     substr(l_msg_data, 0, 190);*/
          fnd_file.put_line(fnd_file.log,
		    'Trx Number ' || i.trx_number || ' Line id - ' ||
		    i.customer_trx_line_id || ' - ' ||
		    substr(l_msg_data, 0, 190));
          ROLLBACK;
        END IF;
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
        UPDATE ar.ra_cust_trx_line_gl_dist_all t
        SET    t.code_combination_id = get_vsoe_ccid(t.code_combination_id,
				     'N',
				     'Y')
        WHERE  t.customer_trx_line_id = i.customer_trx_line_id
        AND    t.account_class IN ('UNEARN')
        AND    t.revenue_adjustment_id = l_adjustment_id;

        -- end if;
        COMMIT;
      END LOOP;
    END LOOP;

    FOR j IN c_fdm_rates LOOP
      FOR i IN c_fdm_lines(j.inventory_item_id,
		   j.channel,
		   j.from_date,
		   j.to_date,
		   j.loc,
		   j.rate) LOOP
        fnd_file.put_line(fnd_file.log, 'Trx Number FDM ' || i.trx_number);
        SELECT nvl(SUM(nvl(amount, 0)), 0)
        INTO   l_sus
        FROM   ra_cust_trx_line_gl_dist_all rda
        WHERE  rda.customer_trx_line_id = i.customer_trx_line_id
        AND    rda.account_class = 'SUSPENSE';

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

        ar_revenueadjust_pub.unearn_revenue(p_api_version       => 2.0,
			        p_init_msg_list     => fnd_api.g_true,
			        x_return_status     => l_return_status,
			        x_msg_count         => l_msg_count,
			        x_msg_data          => l_msg_data,
			        p_rev_adj_rec       => l_revenue_adj_rec,
			        p_org_id            => i.org_id,
			        x_adjustment_id     => l_adjustment_id,
			        x_adjustment_number => l_adjustment_number);
        IF l_msg_count != 0 THEN
          dbms_output.put_line(substr(l_msg_data, 0, 190));
          /* retcode := 2;
          errbuf  := 'Trx Number ' || i.trx_number || ' Line id - ' ||
                     i.customer_trx_line_id || ' - ' ||
                     substr(l_msg_data, 0, 190);*/
          fnd_file.put_line(fnd_file.log,
		    'Trx Number ' || i.trx_number || ' Line id - ' ||
		    i.customer_trx_line_id || ' - ' ||
		    substr(l_msg_data, 0, 190));
          ROLLBACK;
        END IF;
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
        UPDATE ar.ra_cust_trx_line_gl_dist_all t
        SET    t.code_combination_id = get_vsoe_ccid(t.code_combination_id,
				     'Y',
				     'Y')
        WHERE  t.customer_trx_line_id = i.customer_trx_line_id

        AND    t.account_class = 'UNEARN'
        AND    t.revenue_adjustment_id = l_adjustment_id;

        -- end if;
        COMMIT;
      END LOOP;
    END LOOP;
    UPDATE ra_cust_trx_line_gl_dist_all rctg
    SET    rctg.attribute1 = 'Y'
    WHERE  rctg.request_id = l_program_request_id;
    COMMIT;
  END unearned_warrenty_revenue;

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
  PROCEDURE earned_warrenty_revenue(errbuf  OUT VARCHAR2,
			retcode OUT VARCHAR2) IS

    CURSOR get_pop_poly_c IS
      SELECT SUM(nvl(rctl.amount, 0)) une_amt,
	 SUM(nvl(rctl.acctd_amount, 0)) act_amt,
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
      FROM   ra_customer_trx_lines_all    rla, -- inv line
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
      WHERE  msib.inventory_item_id = rla.inventory_item_id
      AND    msib.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    rla.org_id = fnd_global.org_id --solved  Perfomance issue
      AND    gcc.code_combination_id = rctl.code_combination_id
      AND    xxhz_party_ga_util.is_system_item(oola.inventory_item_id) = 'Y'
      AND    rta.customer_trx_id = rla.customer_trx_id
      AND    rbs.batch_source_id = rta.batch_source_id
      AND    rctl.customer_trx_line_id = rla.customer_trx_line_id
      AND    rctl.account_class = 'UNEARN'
      AND    rctl.revenue_adjustment_id IS NOT NULL
      AND    rla.revenue_amount != 0
      AND    rctl.attribute1 = 'Y'
      AND    wr.rate > 0
      AND    rla.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')

	--  and rta.trx_number='1002902'
      AND    oola.header_id = ooha.header_id
      AND    oola.line_id = rla.interface_line_attribute6
      AND    wr.org_id = rla.org_id
      AND    oola.inventory_item_id = wr.inventory_item_id
      AND    nvl(ooha.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = wr.channel
      AND    rta.trx_date BETWEEN wr.from_date AND
	 nvl(wr.to_date, SYSDATE + 1)
      GROUP  BY rla.customer_trx_line_id,
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
      HAVING abs(SUM(nvl(rctl.amount, 0))) / wr.rate > 0.02;
    --   08/04/2014  Ofer Suad CHG0031891 Fix perfomance issue
    CURSOR c_fdm_war IS
      SELECT wr.warranty_period,
	 xxgl_utils_pkg.get_dff_value_description(1013892,
				      wr.location_code) location_code,
	 wr.rate,
	 wr.inventory_item_id,
	 wr.channel,
	 wr.from_date,
	 nvl(wr.to_date, SYSDATE + 1) to_date
      FROM   xxar_warranty_rates wr
      WHERE  wr.rate > 0
      AND    wr.org_id = 737
      AND    xxinv_utils_pkg.is_fdm_system_item(wr.inventory_item_id) = 'Y';

    CURSOR get_pop_fdm_c(location_code VARCHAR2,
		 l_item_id     NUMBER,
		 l_channel     VARCHAR2,
		 l_from_date   DATE,
		 l_to_date     DATE,
		 l_rate        NUMBER) IS
    ------------------
      SELECT SUM(nvl(rctl.amount, 0)) une_amt,
	 SUM(nvl(rctl.acctd_amount, 0)) act_amt,
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
      FROM   ra_customer_trx_lines_all    rla, -- inv line
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
      WHERE  xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
								  nvl(gcc.segment6,
								      '803'))) =
	 location_code --USA Defualt

	-- xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hps.party_site_id = hcs.party_site_id
      AND    hl.location_id = hps.location_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    msib.inventory_item_id = rla.inventory_item_id
      AND    msib.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    gcc.code_combination_id(+) = hcu.gl_id_rev --rctl.code_combination_id
	-- and xxinv_utils_pkg.is_fdm_system_item(oola.inventory_item_id) = 'Y'
	--   and rta.trx_number='1021811'-------------------------------
      AND    rta.customer_trx_id = rla.customer_trx_id
      AND    rbs.batch_source_id = rta.batch_source_id
      AND    rctl.customer_trx_line_id = rla.customer_trx_line_id
      AND    rla.org_id = fnd_global.org_id --solved  Perfomance issue
      AND    rctl.account_class = 'UNEARN'
      AND    rctl.revenue_adjustment_id IS NOT NULL
      AND    rla.revenue_amount != 0
	--and rta.trx_number='1011032'
	--and wr.rate > 0
      AND    rctl.attribute1 = 'Y'
      AND    rla.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')
      AND    oola.header_id = ooha.header_id
      AND    oola.line_id = rla.interface_line_attribute6
	--  and wr.org_id = 737
      AND    oola.inventory_item_id = l_item_id -- wr.inventory_item_id
      AND    nvl(ooha.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = l_channel --wr.channel
	-- and rta.trx_date between wr.from_date and nvl(wr.to_date, sysdate + 1)
      AND    rta.trx_date BETWEEN l_from_date AND l_to_date
      AND    xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
      GROUP  BY rla.customer_trx_line_id,
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
      HAVING abs(SUM(nvl(rctl.amount, 0))) / /*wr.rate*/
      l_rate > 0.02;
    l_program_request_id NUMBER := -1;
    ------------------

    --l_unearned_account  varchar2(100) := null;
    -- l_warranty_period   number := null;
    l_ship_days         NUMBER := NULL;
    l_revenue_adj_rec   ar_revenue_adjustment_pvt.rev_adj_rec_type;
    l_return_status     VARCHAR2(100);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(1000);
    l_adjustment_id     NUMBER;
    l_adjustment_number VARCHAR2(1000);
    l_ship_date         DATE := NULL;
    l_sus               NUMBER;
    l_portion           NUMBER;
    l_agg_portion       NUMBER;
    l_amount            NUMBER;
    --l_rev number;

  BEGIN
    errbuf               := NULL;
    retcode              := 0;
    l_program_request_id := fnd_global.conc_request_id;
    --l_unearned_account := fnd_profile.value('XXAR_VSOE_WARRANTY_UNEARNED_ACCOUNT'); -- 251307
    l_ship_days := fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'); -- 60

    FOR get_pop_r IN get_pop_poly_c LOOP

      -- period loop

      l_agg_portion := 0;

      FOR i IN 1 .. get_pop_r.warranty_period + 1 LOOP

        SELECT nvl(SUM(nvl(amount, 0)), 0)
        INTO   l_sus
        FROM   ra_cust_trx_line_gl_dist_all rda
        WHERE  rda.customer_trx_line_id = get_pop_r.customer_trx_line_id
        AND    rda.account_class = 'SUSPENSE';

        IF i = 1 THEN
          l_portion     := 1 -
		   (get_pop_r.actual_shipment_date -
		   (trunc(get_pop_r.actual_shipment_date, 'MONTH') - 1)) /
		   (last_day(get_pop_r.actual_shipment_date) -
		   (trunc(get_pop_r.actual_shipment_date, 'MONTH') - 1));
          l_agg_portion := l_portion;
        ELSIF i = get_pop_r.warranty_period + 1 THEN
          --  l_portion:=(LAST_DAY(get_pop_r.actual_shipment_date)-get_pop_r.actual_shipment_date)/(LAST_DAY(get_pop_r.actual_shipment_date)-(TRUNC(get_pop_r.actual_shipment_date,'MONTH') -1));
          l_portion := get_pop_r.warranty_period - l_agg_portion;
        ELSE
          l_portion     := 1;
          l_agg_portion := l_agg_portion + 1;
        END IF;

        l_amount := trunc((1 / get_pop_r.warranty_period) *
		  get_pop_r.une_amt * /*nvl(1-get_pop_r.attribute10/100,1)**/
		  l_portion,
		  2);

        IF l_portion != 0 THEN

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

          IF l_msg_count != 0 THEN
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
	ROLLBACK;
	EXIT;
          END IF;

          IF l_sus != 0 THEN
	UPDATE ar.ra_cust_trx_line_gl_dist_all t
	SET    t.amount              = trunc((l_portion /
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
	WHERE  t.customer_trx_line_id = get_pop_r.customer_trx_line_id
	AND    t.account_class IN ('REV')
	AND    t.revenue_adjustment_id = l_adjustment_id;

	UPDATE ar.ra_cust_trx_line_gl_dist_all t
	SET    t.amount              = -trunc((l_portion /
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
	WHERE  t.customer_trx_line_id = get_pop_r.customer_trx_line_id
	AND    t.account_class IN ('UNEARN')
	AND    t.revenue_adjustment_id = l_adjustment_id;
          ELSE
	-- 08-oct-2013 update product line
	UPDATE ar.ra_cust_trx_line_gl_dist_all t
	SET    t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
					 'N',
					 'N'),
			           t.code_combination_id)
	WHERE  t.customer_trx_line_id = get_pop_r.customer_trx_line_id
	AND    t.account_class IN ('REV')
	AND    t.revenue_adjustment_id = l_adjustment_id;

	UPDATE ar.ra_cust_trx_line_gl_dist_all t
	SET    t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
					 'N',
					 'Y'),
			           t.code_combination_id)
	WHERE  t.customer_trx_line_id = get_pop_r.customer_trx_line_id
	AND    t.account_class IN ('UNEARN')
	AND    t.revenue_adjustment_id = l_adjustment_id;
          END IF;
        END IF;
      END LOOP; -- period
      COMMIT; -- ether all periods save or none
    END LOOP; -- invoice population

    FOR j IN c_fdm_war LOOP

      FOR get_pop_r IN get_pop_fdm_c(j.location_code,
			 j.inventory_item_id,
			 j.channel,
			 j.from_date,
			 j.to_date,
			 j.rate) LOOP

        NULL;

        -- period loop
        FOR i IN 1 .. j.warranty_period + 1 LOOP

          SELECT nvl(SUM(nvl(amount, 0)), 0)
          INTO   l_sus
          FROM   ra_cust_trx_line_gl_dist_all rda
          WHERE  rda.customer_trx_line_id = get_pop_r.customer_trx_line_id
          AND    rda.account_class = 'SUSPENSE';
          IF i = 1 THEN
	l_portion     := 1 - (get_pop_r.actual_shipment_date -
		     (trunc(get_pop_r.actual_shipment_date,
			     'MONTH') - 1)) /
		     (last_day(get_pop_r.actual_shipment_date) -
		     (trunc(get_pop_r.actual_shipment_date,
			     'MONTH') - 1));
	l_agg_portion := l_portion;
          ELSIF i = j.warranty_period + 1 THEN
	--  l_portion:=(LAST_DAY(get_pop_r.actual_shipment_date)-get_pop_r.actual_shipment_date)/(LAST_DAY(get_pop_r.actual_shipment_date)-(TRUNC(get_pop_r.actual_shipment_date,'MONTH') -1));
	l_portion := j.warranty_period - l_agg_portion;
          ELSE
	l_portion     := 1;
	l_agg_portion := l_agg_portion + 1;
          END IF;

          l_amount := trunc((1 / j.warranty_period) * get_pop_r.une_amt * /*nvl(1-get_pop_r.attribute10/100,1)**/
		    l_portion);

          --   fnd_file.put_line(fnd_file.log,'amt '||l_amount);

          IF l_portion != 0 THEN

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

	IF l_msg_count != 0 THEN
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
	  ROLLBACK;
	  EXIT;
	END IF;

	--  fnd_file.put_line(fnd_file.log,'amt '||(trunc((l_portion /get_pop_r.warranty_period\*l_warranty_period*\ ) *
	--                                          get_pop_r.une_amt,
	--                                           2)));

	IF l_sus != 0 THEN
	  UPDATE ar.ra_cust_trx_line_gl_dist_all t
	  SET    t.amount              = trunc((l_portion /
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
	  WHERE  t.customer_trx_line_id =
	         get_pop_r.customer_trx_line_id
	  AND    t.account_class IN ('REV')
	  AND    t.revenue_adjustment_id = l_adjustment_id;

	  UPDATE ar.ra_cust_trx_line_gl_dist_all t
	  SET    t.amount              = -trunc((l_portion /
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
	  WHERE  t.customer_trx_line_id =
	         get_pop_r.customer_trx_line_id
	  AND    t.account_class IN ('UNEARN')
	  AND    t.revenue_adjustment_id = l_adjustment_id;
	ELSE
	  -- 08-oct-2013 update product line
	  UPDATE ar.ra_cust_trx_line_gl_dist_all t
	  SET    t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
					   'Y',
					   'N'),
				 t.code_combination_id)
	  WHERE  t.customer_trx_line_id =
	         get_pop_r.customer_trx_line_id
	  AND    t.account_class IN ('REV')
	  AND    t.revenue_adjustment_id = l_adjustment_id;

	  UPDATE ar.ra_cust_trx_line_gl_dist_all t
	  SET    t.code_combination_id = nvl(get_vsoe_ccid(t.code_combination_id,
					   'Y',
					   'Y'),
				 t.code_combination_id)
	  WHERE  t.customer_trx_line_id =
	         get_pop_r.customer_trx_line_id
	  AND    t.account_class IN ('UNEARN')
	  AND    t.revenue_adjustment_id = l_adjustment_id;

	END IF;
          END IF;
        END LOOP; -- period
        COMMIT; -- ether all periods save or none

      END LOOP;
    END LOOP;
    UPDATE ra_cust_trx_line_gl_dist_all rctg
    SET    rctg.attribute1 = 'Y'
    WHERE  rctg.request_id = l_program_request_id;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'procedure Earned_warrenty_revenue failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END earned_warrenty_revenue;

  ----------------------------------------------------------------------
  -- create_warrenty_invoices
  ----------------------------------------------------------------------
  --  ver  date       name       desc
  --  ---  ---------  ---------  ---------------------------------------
  --  1.2  30/07/17   yuval tal  CHG0040061 modify cursors (c_poly_lines and c_fdm_lines)
  --                             prevent warranty creation on Lease and consgment transactions.
  --  1.2  23/04/2014 Ofer Suad  CHG0045252
  --  1.3  30/07/2019 Ofer Suad	 CHG0045976 - To decide if warranty rate should be picked
  --                   						  based on operating unit or Customer location
  ----------------------------------------------------------------------
  PROCEDURE create_warrenty_invoices(errbuf  OUT VARCHAR2,
			 retcode OUT VARCHAR2) IS
    l_return_status        VARCHAR2(1);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_batch_id             NUMBER;
    l_cnt                  NUMBER := 0;
    l_batch_source_rec     ar_invoice_api_pub.batch_source_rec_type;
    l_trx_header_tbl       ar_invoice_api_pub.trx_header_tbl_type;
    l_trx_lines_tbl        ar_invoice_api_pub.trx_line_tbl_type;
    l_trx_dist_tbl         ar_invoice_api_pub.trx_dist_tbl_type;
    l_trx_salescredits_tbl ar_invoice_api_pub.trx_salescredits_tbl_type;
    l_customer_trx_id      NUMBER;
    l_header_id            NUMBER;
    l_ship_date            DATE;
    l_line_id              NUMBER;
    l_dist_id              NUMBER;
    l_amt                  NUMBER;
    l_agg_amt              NUMBER;
    l_tot_amt              NUMBER;
    l_portion              NUMBER;
    l_item_code            mtl_system_items_b.segment1%TYPE;
    l_item_desc            mtl_system_items_b.description%TYPE;
    l_terms_id             NUMBER;

    CURSOR c_errors IS
      SELECT gt.error_message
      FROM   ar_trx_errors_gt gt;

    CURSOR c_poly_rates IS
      SELECT wr.rate,
	 wr.warranty_period,
	 wr.inventory_item_id,
	 wr.channel,
	 wr.from_date,
	 nvl(wr.to_date, SYSDATE + 1) to_date
      FROM   xxar_warranty_rates wr
      WHERE  wr.org_id = fnd_global.org_id
     -- AND    xxhz_party_ga_util.is_system_item(wr.inventory_item_id) = 'Y'	--CHG0045976
     and xxinv_item_classification.is_system_item(wr.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id) = 'Y'  --CHG0045976
     and get_Item_technology_rule(wr.inventory_item_id)='OPERATING_UNIT'; ------------------------ --CHG0045976

    CURSOR c_fdm_rates IS
      SELECT wr.rate,
	 wr.warranty_period,
	 xxgl_utils_pkg.get_dff_value_description(1013892,
				      wr.location_code) location_code,
	 wr.inventory_item_id,
	 wr.channel,
	 wr.from_date,
	 nvl(wr.to_date, SYSDATE + 1) to_date
      FROM   xxar_warranty_rates wr
      WHERE  wr.org_id = 737
      --AND    xxinv_utils_pkg.is_fdm_system_item(wr.inventory_item_id) = 'Y' 	--CHG0045976
      and xxinv_item_classification.is_system_item(wr.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id) = 'Y' --CHG0045976
     and get_Item_technology_rule(wr.inventory_item_id)='CUSTOMER_LOCATION';					  --CHG0045976

    CURSOR c_poly_lines(l_item_id   NUMBER,
		l_channel   VARCHAR2,
		l_from_date DATE,
		l_to_date   DATE,
		l_rate      NUMBER) IS
      SELECT /*+ index(OL OE_ORDER_LINES_N3) */
       CASE --INC0099639 Add Hint to improve perfomance
         WHEN rcta.type = 'CM' THEN
          (l_rate * -1) --CHG0034240 on credit memo should be negative amount
         ELSE
          l_rate
       END rate,
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
			    nvl(rta.exchange_date, rta.trx_date),
			    'Corporate',
			    10) conv_rate,
       rcl.attribute10,
       hca.cust_account_id,
       oh.order_number,
       ol.line_number,
       nvl(ol.actual_shipment_date, rta.trx_date) actual_shipment_date,
       rcta.type,
       mtu.serial_number -- CHG0034240-  Get teh serial number to Disco report
      FROM   ra_customer_trx_lines        rcl,
	 ra_cust_trx_line_gl_dist_all rg,
	 ra_customer_trx_all          rta,
	 oe_order_lines_all          ol,
	 oe_order_headers_all         oh,
	 -- xxar_warranty_rates          wr,
	 ra_batch_sources_all   rbs,
	 ra_cust_trx_types_all  rcta,
	 hz_cust_site_uses_all  hcu,
	 hz_cust_acct_sites_all hcs,
	 hz_cust_accounts       hca,
	 --CHG0034240  ad mtl tables  - Only materail transacion will get warranty
	 mtl_material_transactions mmt,
	 mtl_unit_transactions     mtu
      WHERE  rcl.interface_line_attribute6 = to_char(ol.line_id)
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    oh.header_id = ol.header_id
	-- and xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
      AND    rta.cust_trx_type_id = rcta.cust_trx_type_id
      AND    nvl(rcta.attribute8, 'N') = 'Y' --CHG0034240  Instead of attribute8 - in order to apply on CM
      AND    fnd_global.org_id = rcl.org_id
      AND    ol.inventory_item_id = l_item_id --wr.inventory_item_id
      AND    nvl(oh.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = l_channel --wr.channel
      AND    rta.customer_trx_id = rcl.customer_trx_id
      AND    rbs.name IN ('ORDER ENTRY', 'ORDER ENTRY CM')
      AND    rg.user_generated_flag IS NULL
      AND    rta.trx_date BETWEEN /*wr.from_date*/
	--CHG0034240 CM will be only from 01-Jan-2015 before that date it was calcualted manully
	 decode(rcta.type, 'CM', '01-Jan-2015', l_from_date) AND
	 nvl( /*wr.to_date*/ l_to_date, SYSDATE + 1)
	-- and rta.trx_date between '01-apr-2014' and '30-jun-2014'-----------------
      AND    rg.customer_trx_line_id = rcl.customer_trx_line_id
      AND    rg.amount != 0
      AND    rg.account_class = 'REV'
      AND    rbs.batch_source_id = rta.batch_source_id
	--CHG0034240 ad mtl tables  - Only materail transacion will get warranty
	-- AND mmt.trx_source_line_id = ol.line_id
	-- CHG0041688 -  Support System Kit Item
      AND    mmt.trx_source_line_id = CASE
	   WHEN ol.item_type_code = 'KIT' THEN
	    (SELECT oll1.line_id
	     FROM   oe_order_lines_all oll1
	     WHERE  oll1.header_id = ol.header_id
	     AND    oll1.top_model_line_id = ol.line_id
	    -- AND    xxhz_party_ga_util.is_system_item(oll1.inventory_item_id) = 'Y'
      and xxinv_item_classification.is_system_item(oll1.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id)= 'Y'
	     AND    oll1.line_id != oll1.top_model_line_id
	     AND    rownum = 1)
	   ELSE
	    ol.line_id
	 END
      AND    mmt.transaction_type_id IN (33, 15)
      AND    mtu.transaction_id = mmt.transaction_id
	--CHG0035120 Exclude IC sales to Non-Oracle companies from VSOE
      AND    nvl(xxgl_utils_pkg.replace_cc_segment(rg.cust_trx_line_gl_dist_id,
				   'SEGMENT7'),
	     '00') = '00'
	--  and rta.trx_number in ( /*'1023933',*/ '1022745')----------------
      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_customer_trx_all       rth,
	         ra_customer_trx_lines_all rtl
	  WHERE  rth.cust_trx_type_id =
	         fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
				NULL,
				NULL,
				NULL,
				fnd_global.org_id)
	  AND    rth.customer_trx_id = rtl.customer_trx_id
	  AND    rtl.sales_order = oh.order_number
	  AND    rth.org_id = fnd_global.org_id --INC0099639 Add Hint to improve perfomance
	  AND    rth.bill_to_customer_id = hca.cust_account_id --INC0099639 Add Hint to improve perfomance
	  AND    nvl(rtl.sales_order_line, ol.line_number) =
	         ol.line_number --CHG0034240 in case we have 2 lines of same item in 1 order
           and mtu.serial_number=rtl.attribute2--  CHG0046674- when order lines has more than 1 system and it has multiple ship set  
	  AND    rtl.inventory_item_id = rcl.inventory_item_id)

      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_cust_trx_line_gl_dist_all rg1
	  WHERE  rg1.customer_trx_line_id = rcl.customer_trx_line_id
	  AND    rg1.account_class = 'UNEARN'
	  AND    rg1.user_generated_flag IS NOT NULL)
	--CHG0040061

      AND    NOT EXISTS
       (SELECT 1
	  FROM   oe_order_lines_all        ol,
	         mtl_material_transactions mmt1,
	         mtl_unit_transactions     mtu1
	  WHERE  ol.inventory_item_id = l_item_id --mtu.inventory_item_id  INC0098151 Replace item id condition to improve perfomance
	  AND    mmt1.trx_source_line_id = ol.line_id
	  AND    ol.line_type_id =
	         fnd_profile.value('XXAR_WARRANTY_FA_RETURN_LINE') --1920
	  AND    mtu1.transaction_id = mmt1.transaction_id
	  AND    mtu1.serial_number = mtu.serial_number --'K00663' --
	  )
      -- end CHG0040061
      and get_list_price(ol.top_model_line_id,ol.unit_list_price)<>0--CHG0045252 -  ignore avg discount when list price is zero
      ;

    CURSOR c_fdm_lines(l_item_id       NUMBER,
	           l_channel       VARCHAR2,
	           l_from_date     DATE,
	           l_to_date       DATE,
	           l_location_code VARCHAR2,
	           l_rate          NUMBER) IS
      SELECT /*+ index(OL OE_ORDER_LINES_N3) */
       CASE --INC0099639 Add Hint to improve perfomance
         WHEN rcta.type = 'CM' THEN
          (l_rate * -1) --CHG0034240 on credit memo should be negative amount
         ELSE
          l_rate
       END rate,
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
			    nvl(rta.exchange_date, rta.trx_date),
			    'Corporate',
			    10) conv_rate,
       rcl.attribute10,
       hca.cust_account_id,
       oh.order_number,
       ol.line_number,
       nvl(ol.actual_shipment_date, rta.trx_date) actual_shipment_date,
       rcta.type,
       mut.serial_number -- CHG0034240-  Get teh serial number to Disco report
      FROM   ra_customer_trx_lines        rcl,
	 ra_cust_trx_line_gl_dist_all rg,
	 ra_customer_trx_all          rta,
	 oe_order_lines_all           ol,
	 oe_order_headers_all         oh,
	 -- xxar_warranty_rates          wr,
	 ra_batch_sources_all   rbs,
	 ra_cust_trx_types_all  rcta,
	-- gl_code_combinations   gcc,
	 hz_cust_site_uses_all  hcu,
	 hz_cust_acct_sites_all hcs,
	 hz_party_sites         hps,
	 hz_locations           hl,
	 hz_cust_accounts       hca,
	 --CHG0034240 ad mtl tables  - Only materail transacion will get warranty
	 mtl_material_transactions mmt,
	 mtl_unit_transactions     mut
      WHERE  xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
					get_location_segemnt(hps.party_site_id)			 						      )) =--CHG0045252 -  ignore avg discount when list price is zero
	 l_location_code
	--xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)
      AND    hcu.site_use_id = rta.bill_to_site_use_id
      AND    hcs.cust_acct_site_id = hcu.cust_acct_site_id
      AND    hps.party_site_id = hcs.party_site_id
      AND    hl.location_id = hps.location_id
      AND    hca.cust_account_id = hcs.cust_account_id
      AND    rcl.interface_line_attribute6 = to_char(ol.line_id)
      AND    oh.header_id = ol.header_id
	-- and xxinv_utils_pkg.is_fdm_system_item(ol.inventory_item_id) = 'Y'
      AND    rta.cust_trx_type_id = rcta.cust_trx_type_id
      AND    nvl(rcta.attribute8, 'N') = 'Y' --CHG0034240  Instead of attribute8 - in order to apply on CM
	--and wr.org_id = 737
      AND    ol.inventory_item_id = l_item_id --wr.inventory_item_id
      AND    nvl(oh.attribute7,
	     decode(hca.sales_channel_code,
		'INDIRECT',
		'Indirect deal',
		'DIRECT',
		'Direct deal',
		hca.sales_channel_code)) = l_channel --wr.channel
      AND    rta.customer_trx_id = rcl.customer_trx_id
      AND    rbs.name IN ('ORDER ENTRY', 'ORDER ENTRY CM')
      AND    rg.user_generated_flag IS NULL
	--CHG0034240 CM will be only from 01-Jan-2015 before that date it was calcualted manully
      AND    rta.trx_date BETWEEN
	 decode(rcta.type, 'CM', '01-Jan-2015', l_from_date) AND
	 l_to_date --wr.from_date and nvl(wr.to_date, sysdate + 1)
	--and rta.trx_date between '01-apr-2014' and '30-jun-2014'----------------
      AND    rg.customer_trx_line_id = rcl.customer_trx_line_id
      AND    rg.amount != 0
      AND    rg.account_class = 'REV'
	--      and rta.trx_number='1022745'----------------
      AND    rbs.batch_source_id = rta.batch_source_id
    --  AND    gcc.code_combination_id(+) = hcu.gl_id_rev --rg.code_combination_id -- CHG0045252
      AND    xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
	--CHG0034240 ad mtl tables  - Only materail transacion will get warranty
	-- AND mmt.trx_source_line_id = ol.line_id
	-- CHG0041688 -  Support System Kit Item
      AND    mmt.trx_source_line_id = CASE
	   WHEN ol.item_type_code = 'KIT' THEN
	    (SELECT oll1.line_id
	     FROM   oe_order_lines_all oll1
	     WHERE  oll1.header_id = ol.header_id
	     AND    oll1.top_model_line_id = ol.line_id
	     --AND    xxinv_utils_pkg.is_fdm_system_item(oll1.inventory_item_id) = 'Y'
       and xxinv_item_classification.is_system_item(oll1.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id) = 'Y'
	     AND    oll1.line_id != oll1.top_model_line_id
	     AND    rownum = 1)
	   ELSE
	    ol.line_id
	 END
      AND    mmt.transaction_id = mut.transaction_id
      AND    mmt.transaction_type_id IN (33, 15)
      AND    nvl(xxgl_utils_pkg.replace_cc_segment(rg.cust_trx_line_gl_dist_id,
				   'SEGMENT7'),
	     '00') = '00' --CHG0035120 Exclude IC sales to Non-Oracle companies from VSOE
      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_cust_trx_line_gl_dist_all rg1
	  WHERE  rg1.customer_trx_line_id = rcl.customer_trx_line_id
	  AND    rg1.account_class = 'UNEARN'
	  AND    rg1.user_generated_flag IS NOT NULL)
      AND    NOT EXISTS
       (SELECT 1
	  FROM   ra_customer_trx_all       rth,
	         ra_customer_trx_lines_all rtl
	  WHERE  rth.cust_trx_type_id =
	         fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
				NULL,
				NULL,
				NULL,
				fnd_global.org_id)
	  AND    rth.customer_trx_id = rtl.customer_trx_id
	  AND    rtl.sales_order = oh.order_number
	  AND    rth.org_id = fnd_global.org_id --INC0099639 Add Hint to improve perfomance
	  AND    rth.bill_to_customer_id = hca.cust_account_id --INC0099639 Add Hint to improve perfomance
	  AND    nvl(rtl.sales_order_line, ol.line_number) =
	         ol.line_number --CHG0034240 in case we have 2 lines of same item in 1 order
            and mut.serial_number=rtl.attribute2--  CHG0046674- when order lines has more than 1 system and it has multiple ship set
	  AND    rtl.inventory_item_id = rcl.inventory_item_id)

	--CHG0040061

      AND    NOT EXISTS
       (SELECT 1
	  FROM   oe_order_lines_all        ol,
	         mtl_material_transactions mmt1,
	         mtl_unit_transactions     mtu1
	  WHERE  ol.inventory_item_id = l_item_id --mut.inventory_item_id -- INC0098151 Replace item id condition to improve perfomance
	  AND    mmt1.trx_source_line_id = ol.line_id
	  AND    ol.line_type_id =
	         fnd_profile.value('XXAR_WARRANTY_FA_RETURN_LINE') --1920
	  AND    mtu1.transaction_id = mmt1.transaction_id
	  AND    mtu1.serial_number = mut.serial_number --'K00663' --
	  ) -- end CHG0040061
     and get_list_price(ol.top_model_line_id,ol.unit_list_price)<>0;--CHG0045252 -  ignore avg discount when list price is zero

    xxmaster_org_id mtl_parameters.organization_id%TYPE := NULL; -- INC0099639 store master organization id.

  BEGIN
    /******** BEGIN ************/

    xxmaster_org_id := xxinv_utils_pkg.get_master_organization_id(); -- INC0099639 optimization. Store master organization_id and use it later instead of calling the function each loop.

    SELECT rb.batch_source_id
    INTO   l_batch_id
    FROM   ra_batch_sources rb
    WHERE  rb.name = 'Warranty Invoices'; --'ORDER ENTRY';
    SELECT default_term
    INTO   l_terms_id
    FROM   ra_cust_trx_types
    WHERE  cust_trx_type_id =
           fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
			  NULL,
			  NULL,
			  NULL,
			  fnd_global.org_id);

    -------------------------------------------------------------------------------------
    FOR i IN c_poly_rates LOOP
      SELECT mb.segment1,
	 mb.description
      INTO   l_item_code,
	 l_item_desc
      FROM   mtl_system_items_b mb
      WHERE  mb.inventory_item_id = i.inventory_item_id
      AND    mb.organization_id = xxmaster_org_id; -- INC0099639

      FOR j IN c_poly_lines(i.inventory_item_id,
		    i.channel,
		    i.from_date,
		    i.to_date,
		    i.rate) LOOP

        -- Ofer Suad  CHG0032979 New Logic of Warranty Invoices -add intilize tables
        l_trx_header_tbl.delete;
        l_trx_lines_tbl.delete;
        l_trx_dist_tbl.delete;
        l_trx_salescredits_tbl.delete;

        l_header_id := 0;
        l_line_id   := 0;
        l_dist_id   := 0;
        l_agg_amt   := 0;

        l_portion := 1 - (j.actual_shipment_date -
	         (trunc(j.actual_shipment_date, 'MONTH') - 1)) /
	         (last_day(j.actual_shipment_date) -
	         (trunc(j.actual_shipment_date, 'MONTH') - 1));

        l_tot_amt := round(-j.rate * (1 - nvl(j.attribute10, 0) / 100) *
		   j.conv_rate);
        l_header_id := l_header_id + 1;
        l_line_id := l_line_id + 1;
        l_trx_header_tbl(1).trx_header_id := l_header_id;
        l_trx_header_tbl(1).trx_currency := j.invoice_currency_code;
        l_trx_header_tbl(1).bill_to_customer_id := j.cust_account_id;
        l_trx_header_tbl(1).primary_salesrep_id := -3;
        l_trx_header_tbl(1).term_id := l_terms_id;
        l_trx_header_tbl(1).cust_trx_type_id := fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
						   NULL,
						   NULL,
						   NULL,
						   fnd_global.org_id);
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
        l_trx_lines_tbl(1).sales_order := j.order_number;
        l_trx_lines_tbl(1).sales_order_line := j.line_number;
        l_trx_lines_tbl(1).attribute2 := j.serial_number;
        l_trx_lines_tbl(1).inventory_item_id := i.inventory_item_id;
        l_trx_lines_tbl(1).accounting_rule_id := 1;
        l_trx_lines_tbl(1).rule_start_date := j.gl_date;

        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'REV';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := j.code_combination_id;
        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
					           'N',
					           'Y');

        FOR l IN 1 .. i.warranty_period + 1 LOOP
          l_amt := round((j.rate * (1 - nvl(j.attribute10, 0) / 100) *
		 j.conv_rate) / i.warranty_period);
          IF l = 1 THEN
	l_amt := l_amt * l_portion;
          END IF;
          l_agg_amt := l_agg_amt + l_amt;

          IF l = i.warranty_period + 1 THEN
	-- if l_agg_amt+l_tot_amt>0 then
	l_amt := l_amt - (l_agg_amt + l_tot_amt);
	/*else
            l_amt:=l_amt-(l_agg_amt+l_tot_amt);
            end if;*/
          END IF;
          l_line_id   := l_line_id + 1;
          l_ship_date := trunc(add_months(j.actual_shipment_date +
			      fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'),
			      l_line_id - 2),
		       'month');

          l_trx_lines_tbl(l_line_id).trx_header_id := l_header_id;
          l_trx_lines_tbl(l_line_id).attribute2 := j.serial_number;
          l_trx_lines_tbl(l_line_id).trx_line_id := l_line_id;
          l_trx_lines_tbl(l_line_id).line_number := l_line_id;
          l_trx_lines_tbl(l_line_id).quantity_invoiced := 1;
          l_trx_lines_tbl(l_line_id).sales_order := j.order_number;
          l_trx_lines_tbl(l_line_id).sales_order_line := j.line_number;
          l_trx_lines_tbl(l_line_id).unit_selling_price := l_amt;

          l_trx_lines_tbl(l_line_id).accounting_rule_id := 1;
          l_trx_lines_tbl(l_line_id).rule_start_date := l_ship_date;

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
          l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
						 'N',
						 'N'); --5377898;
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
						 'N',
						 'Y'); -- 5377892;
          l_trx_salescredits_tbl(l_line_id).salesrep_id := -3;
          l_trx_salescredits_tbl(l_line_id).trx_line_id := l_line_id;
          l_trx_salescredits_tbl(l_line_id).trx_salescredit_id := l_line_id;

        END LOOP;

        ar_invoice_api_pub.create_single_invoice(p_api_version          => 1.0,
				 p_batch_source_rec     => l_batch_source_rec,
				 p_trx_header_tbl       => l_trx_header_tbl,
				 p_trx_lines_tbl        => l_trx_lines_tbl,
				 p_trx_dist_tbl         => l_trx_dist_tbl,
				 p_trx_salescredits_tbl => l_trx_salescredits_tbl,
				 x_customer_trx_id      => l_customer_trx_id,
				 x_return_status        => l_return_status,
				 x_msg_count            => l_msg_count,
				 x_msg_data             => l_msg_data);

        IF l_return_status = fnd_api.g_ret_sts_error OR
           l_return_status = fnd_api.g_ret_sts_unexp_error THEN
          fnd_file.put_line(fnd_file.log,
		    'unexpected errors found!' || l_msg_data);
        ELSE

          SELECT COUNT(*)
          INTO   l_cnt
          FROM   ar_trx_errors_gt;
          IF l_cnt = 0 THEN
	fnd_file.put_line(fnd_file.log,
		      'Customer Trx id ' || l_customer_trx_id);
          ELSE

	fnd_file.put_line(fnd_file.log,
		      'Transaction not Created, Please check ar_trx_errors_gt table');
	FOR k IN c_errors LOOP
	  fnd_file.put_line(fnd_file.log, k.error_message);
	END LOOP;
          END IF;
        END IF;
      END LOOP;
      COMMIT;
    END LOOP;
    FOR i IN c_fdm_rates LOOP

      SELECT mb.segment1,
	 mb.description
      INTO   l_item_code,
	 l_item_desc
      FROM   mtl_system_items_b mb
      WHERE  mb.inventory_item_id = i.inventory_item_id
      AND    mb.organization_id = xxmaster_org_id; -- INC0099639

      FOR j IN c_fdm_lines(i.inventory_item_id,
		   i.channel,
		   i.from_date,
		   i.to_date,
		   i.location_code,
		   i.rate) LOOP
        -- Ofer Suad  CHG0032979 New Logic of Warranty Invoices -add intilize tables
        l_trx_header_tbl.delete;
        l_trx_lines_tbl.delete;
        l_trx_dist_tbl.delete;
        l_trx_salescredits_tbl.delete;
        l_header_id := 0;
        l_line_id   := 0;
        l_dist_id   := 0;
        l_agg_amt   := 0;

        l_portion := 1 - (j.actual_shipment_date -
	         (trunc(j.actual_shipment_date, 'MONTH') - 1)) /
	         (last_day(j.actual_shipment_date) -
	         (trunc(j.actual_shipment_date, 'MONTH') - 1));

        l_tot_amt := round(-j.rate * (1 - nvl(j.attribute10, 0) / 100) *
		   j.conv_rate);
        l_header_id := l_header_id + 1;
        l_line_id := l_line_id + 1;
        l_trx_header_tbl(1).trx_header_id := l_header_id;
        l_trx_header_tbl(1).trx_currency := j.invoice_currency_code;
        l_trx_header_tbl(1).primary_salesrep_id := -3;
        l_trx_header_tbl(1).term_id := l_terms_id;
        l_trx_header_tbl(1).bill_to_customer_id := j.cust_account_id;
        l_trx_header_tbl(1).cust_trx_type_id := fnd_profile.value_specific('XXAR_WARANTY_TRX_TYPE_ID',
						   NULL,
						   NULL,
						   NULL,
						   fnd_global.org_id);
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
        l_trx_lines_tbl(1).attribute2 := j.serial_number;
        l_trx_lines_tbl(1).unit_selling_price := l_tot_amt;
        l_trx_lines_tbl(1).line_type := 'LINE';
        l_trx_lines_tbl(1).sales_order := j.order_number;
        l_trx_lines_tbl(1).sales_order_line := j.line_number;
        l_trx_lines_tbl(1).inventory_item_id := i.inventory_item_id;
        l_trx_lines_tbl(1).accounting_rule_id := 1;
        l_trx_lines_tbl(1).rule_start_date := j.gl_date;

        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'REV';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := j.code_combination_id;
        l_dist_id := l_dist_id + 1;
        l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
        l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
        l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
        l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
        l_trx_dist_tbl(l_dist_id).percent := 100;
        l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
        l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
					           'Y',
					           'Y');

        FOR l IN 1 .. i.warranty_period + 1 LOOP
          l_amt := round((j.rate * (1 - nvl(j.attribute10, 0) / 100) *
		 j.conv_rate) / i.warranty_period);
          IF l = 1 THEN
	l_amt := l_amt * l_portion;
          END IF;
          l_agg_amt := l_agg_amt + l_amt;

          IF l = i.warranty_period + 1 THEN
	-- if l_agg_amt+l_tot_amt>0 then
	l_amt := l_amt - (l_agg_amt + l_tot_amt);
	/*else
            l_amt:=l_amt-(l_agg_amt+l_tot_amt);
            end if;*/
          END IF;
          l_line_id   := l_line_id + 1;
          l_ship_date := trunc(add_months(j.actual_shipment_date +
			      fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS'),
			      l_line_id - 2),
		       'month');

          l_trx_lines_tbl(l_line_id).trx_header_id := l_header_id;
          l_trx_lines_tbl(l_line_id).trx_line_id := l_line_id;
          l_trx_lines_tbl(l_line_id).line_number := l_line_id;
          l_trx_lines_tbl(l_line_id).quantity_invoiced := 1;
          l_trx_lines_tbl(l_line_id).sales_order := j.order_number;
          l_trx_lines_tbl(l_line_id).sales_order_line := j.line_number;
          l_trx_lines_tbl(l_line_id).unit_selling_price := l_amt;
          l_trx_lines_tbl(l_line_id).attribute2 := j.serial_number;
          l_trx_lines_tbl(l_line_id).accounting_rule_id := 1;
          l_trx_lines_tbl(l_line_id).rule_start_date := l_ship_date;

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
          l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
						 'Y',
						 'N'); --5377898;
          l_dist_id := l_dist_id + 1;
          l_trx_dist_tbl(l_dist_id).trx_line_id := l_line_id;
          l_trx_dist_tbl(l_dist_id).trx_header_id := l_header_id;
          l_trx_dist_tbl(l_dist_id).trx_dist_id := l_dist_id;
          l_trx_dist_tbl(l_dist_id).account_class := 'UNEARN';
          l_trx_dist_tbl(l_dist_id).percent := 100;
          l_trx_dist_tbl(l_dist_id).attribute1 := 'Y';
          l_trx_dist_tbl(l_dist_id).code_combination_id := get_vsoe_ccid(j.code_combination_id,
						 'Y',
						 'Y'); -- 5377892;

        END LOOP;

        ar_invoice_api_pub.create_single_invoice(p_api_version          => 1.0,
				 p_batch_source_rec     => l_batch_source_rec,
				 p_trx_header_tbl       => l_trx_header_tbl,
				 p_trx_lines_tbl        => l_trx_lines_tbl,
				 p_trx_dist_tbl         => l_trx_dist_tbl,
				 p_trx_salescredits_tbl => l_trx_salescredits_tbl,
				 x_customer_trx_id      => l_customer_trx_id,
				 x_return_status        => l_return_status,
				 x_msg_count            => l_msg_count,
				 x_msg_data             => l_msg_data);

        IF l_return_status = fnd_api.g_ret_sts_error OR
           l_return_status = fnd_api.g_ret_sts_unexp_error THEN
          fnd_file.put_line(fnd_file.log,
		    'unexpected errors found!' || l_msg_data);
        ELSE

          SELECT COUNT(*)
          INTO   l_cnt
          FROM   ar_trx_errors_gt;
          IF l_cnt = 0 THEN
	fnd_file.put_line(fnd_file.log,
		      'Customer Trx id ' || l_customer_trx_id);
          ELSE

	fnd_file.put_line(fnd_file.log,
		      'Transaction not Created, Please check ar_trx_errors_gt table');
	FOR k IN c_errors LOOP
	  fnd_file.put_line(fnd_file.log, k.error_message);
	END LOOP;
          END IF;
        END IF;
      END LOOP;
      COMMIT;
    END LOOP;

    -------------------------------------------------------------------------------------

  END create_warrenty_invoices;
 --------------------------------------------------------------------
  --  name:            get_list_price
  --  create by:       Ofer.suad
  --  Revision:        1.11
  --  creation date:   17/04/2019
  --------------------------------------------------------------------
  --         CHG0045252 -  ignore avg discount when list price is zero
  --  purpose          Get the price list of order lines
  --                    if this is PTO line -> get list price from parent
    --------------------------------------------------------------------
  function get_list_price (p_top_model_line_id number,p_list_price number)
    return number
    is
    l_ret number;
    begin
      if p_list_price<>0 then
         l_ret:= p_list_price;
     elsif p_top_model_line_id is null then
       l_ret:= 0;
       else
         select ola.unit_list_price
         into  l_ret
         from oe_order_lines_all ola
         where ola.line_id=p_top_model_line_id;

       end if;
    return l_ret;
end get_list_price;

  --------------------------------------------------------------------
  --  name:            get_location_segemnt
  --  create by:       Ofer.suad
  --  Revision:        1.11
  --  creation date:   17/04/2019
  --------------------------------------------------------------------
  --CHG0045252 -  ignore avg discount when list price is zero
  --  purpose :
  --                   Get customer location based on State
    --------------------------------------------------------------------
function get_location_segemnt (p_party_site_id number) return varchar2
  is
  l_ret varchar2 (25);

  begin
    select min(ffv.FLEX_VALUE)
    into l_ret
  from hz_party_sites         hps,
       hz_locations           hl,
       fnd_territories_tl     ft,
       FND_FLEX_VALUES_VL     ffv
 where hps.party_site_id=p_party_site_id
   and hl.location_id = hps.location_id
   and ft.language = 'US'
   and ft.territory_code = hl.country
   and ffv.FLEX_VALUE_SET_ID = 1013892
   and ffv.DESCRIPTION = ft.territory_short_name;
   return l_ret;
 exception
   when others then
     return '000';

  end get_location_segemnt;

   --------------------------------------------------------------------
  --  name:            get_item_technology_rule
  --  create by:       Ofer.suad
  --  Revision:        1.11
  --  creation date:   25/07/2019
  --------------------------------------------------------------------
  --CHG0045976 -  get_item_technology_rule
  --  purpose :
  --                   To decide if warranty rate should be picked based on operating unit or
  --                   Customer location
    --------------------------------------------------------------------
    function get_item_technology_rule (p_inventory_item_id number) return varchar2
      is
      l_vsoe_rule varchar2(25);
      begin
        begin
        SELECT ffv.ATTRIBUTE1
        into l_vsoe_rule
     FROM mtl_item_categories mic, mtl_categories_b_kfv mc,
     FND_FLEX_VALUES_VL ffv,fnd_flex_value_sets ffvs
     WHERE mic.category_id = mc.category_id
       AND mic.inventory_item_id = p_inventory_item_id -- 13003
       AND mic.organization_id = 91
       AND mic.category_set_id = 1100000221
       and ffv.FLEX_VALUE_SET_ID=ffvs.FLEX_VALUE_SET_ID
       and ffvs.flex_value_set_name='XXINV_TECHNOLOGY'
       and ffv.FLEX_VALUE=mc.segment6;

       exception
         when others then
           l_vsoe_rule:=null;
           end ;
           return l_vsoe_rule;

      end get_item_technology_rule;

  ----------------------------------
END xxar_warranty_rates_pkg;
/
