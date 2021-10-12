CREATE OR REPLACE PACKAGE BODY xxcs_coupon_pkg IS

  --------------------------------------------------------------------
  --  name:            XXCS_COUPON_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --  1.1  22/07/2012  Dalit A. Raviv    Procedure main - add add training PN to coupon card
  --  1.2  30/07/2012  Dalit A. Raviv    Procedure main - After adding training part to the coupon number
  --                                     when compare to list_line_no it is not the same value. need to add substr.
  --  1.3   1.12.13     Yuval Tal        CR1163-Service - Customization support new operating unit 737
  --------------------------------------------------------------------

  g_user_id NUMBER := nvl(fnd_profile.value('USER_ID'), 2470);
  g_env     VARCHAR2(20) := NULL;

  --------------------------------------------------------------------
  --  name:            insert_coupon_hist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --                   Insert row to history table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_coupon_hist(p_coupon_hist_rec IN t_coupon_hist_rec,
                               p_err_code        OUT NUMBER,
                               p_err_desc        OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_hist_id NUMBER := NULL;
  BEGIN
  
    BEGIN
      SELECT xxcs_coupon_history_s.nextval INTO l_hist_id FROM dual;
    END;
  
    INSERT INTO xxcs_coupon_history
      (hist_id,
       counpon_number,
       sales_order_num,
       system_type,
       serial_number,
       customer_name,
       valid_date,
       send_mail,
       org_id,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (l_hist_id,
       p_coupon_hist_rec.counpon_number,
       p_coupon_hist_rec.sales_order_num,
       p_coupon_hist_rec.system_type,
       p_coupon_hist_rec.serial_number,
       p_coupon_hist_rec.customer_name,
       SYSDATE + 365,
       'Y',
       p_coupon_hist_rec.org_id,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Procedure insert_coupon_hist - Failed - ' ||
                        substr(SQLERRM, 1, 240));
      ROLLBACK;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_coupon_hist - Failed - ' ||
                    substr(SQLERRM, 1, 240);
  END insert_coupon_hist;

  --------------------------------------------------------------------
  --  name:            copy_file
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --                   Copy coupon report output from appl/conc/out
  --                   to /UtlFiles/shared/TEST/CS/coupon
  --                   TEST  /TestApps/oracle/TEST/SharedFiles/logs/appl/conc/out
  --                   DEV   /DevApps/oracle/DEV/SharedFiles/logs/appl/conc/out
  --                   PATCH /PtchApps/oracle/PTCH/SharedFiles/logs/appl/conc/out
  --                   YES   /YesApps/oracle/YES/SharedFiles/logs/appl/conc/out
  --                   PROD  /ProdApps/oracle/PROD/SharedFiles/logs/appl/conc/out

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE copy_file(p_dir       IN VARCHAR2,
                      p_file_name IN VARCHAR2,
                      p_err_code  OUT NUMBER) IS
  
    l_dest_dir   VARCHAR2(100);
    l_request_id NUMBER;
    --
    --l_wait_result boolean;
    l_phase      VARCHAR2(20);
    l_status     VARCHAR2(20);
    l_dev_phase  VARCHAR2(20);
    l_dev_status VARCHAR2(20);
    l_message    VARCHAR2(100);
    l_result     BOOLEAN;
    l_error_flag BOOLEAN := FALSE;
    l_count      NUMBER := 0;
  BEGIN
    l_dest_dir := '/UtlFiles/shared/' || g_env || '/CS/coupon';
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXMVFILE',
                                               argument1   => p_dir,
                                               argument2   => p_file_name,
                                               argument3   => l_dest_dir,
                                               argument4   => p_file_name);
    COMMIT;
  
    WHILE l_error_flag = FALSE LOOP
      l_count  := l_count + 1;
      l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                  5,
                                                  86400,
                                                  l_phase,
                                                  l_status,
                                                  l_dev_phase,
                                                  l_dev_status,
                                                  l_message);
    
      IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
        l_error_flag := TRUE;
        p_err_code   := 0;
      ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
        l_error_flag := TRUE;
        p_err_code   := 1;
        fnd_file.put_line(fnd_file.log,
                          'Request finished in error or warrning, no file moved. try again later. - ' ||
                          l_message);
      ELSIF l_count > 10 THEN
        l_error_flag := TRUE;
        p_err_code   := 1;
        fnd_file.put_line(fnd_file.log,
                          'Request finished in error or warrning, no file moved. try again later. - ' ||
                          l_message);
      END IF; -- dev_phase
    END LOOP; -- l_error_flag
  
  END copy_file;

  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   send report output as mail to user that run the report.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION afterreport(p_request_id IN NUMBER) RETURN BOOLEAN IS
    l_dir VARCHAR2(150) := NULL;
    --l_request_id number;
    l_file_name VARCHAR2(150) := NULL;
    l_err_code  NUMBER := 0;
  
  BEGIN
  
    l_dir := fnd_profile.value('XXOBJT_CONC_OUTPUT_DIRECTORY');
    --l_request_id := fnd_global.conc_request_id;
    l_file_name := 'XXCS_COUPONS_' || p_request_id || '_1.PDF';
    copy_file(p_dir       => l_dir, -- i v
              p_file_name => l_file_name, -- i v
              p_err_code  => l_err_code); -- o n
  
    IF l_err_code <> 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
    
  END afterreport;

  --------------------------------------------------------------------
  --  name:            get_send_mail_to
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/06/2012
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --
  --                   1) get alert name and return the list connect to it
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_send_mail_to(p_alert_name IN VARCHAR2) RETURN VARCHAR2 IS
    --l_env       varchar2(100)  := null;
    l_mail_list VARCHAR2(1500) := NULL;
  BEGIN
    --l_env :=  xxobjt_fnd_attachments.get_environment_name;
    --if l_env = 'PROD' then
    l_mail_list := xxobjt_general_utils_pkg.get_alert_mail_list(p_alert_name,
                                                                ';');
    --else
    --  l_mail_list := 'Dalit.raviv@objet.com';
    --end if;
    RETURN l_mail_list;
  END get_send_mail_to;

  --------------------------------------------------------------------
  --  name:            get_send_mail_to
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/06/2012
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --
  --                   1) get org_id and return the alert name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/06/2012  Dalit A. Raviv    initial build
  -- 1.1   1.12.13     Yuval Tal         CR1163-Service - Customization support new operating unit 737
  --------------------------------------------------------------------
  FUNCTION get_alert_name(p_org_id IN NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_org_id = 81 THEN
      RETURN 'XXCS_TRAINING_COUPON_EM';
    ELSIF p_org_id = 89 THEN
      RETURN 'XXCS_TRAINING_COUPON_US';
    ELSIF p_org_id = 737 THEN
      RETURN 'XXCS_TRAINING_COUPON_US';
    ELSIF p_org_id = 96 THEN
      RETURN 'XXCS_TRAINING_COUPON_EU';
    ELSIF p_org_id IN (103, 161) THEN
      RETURN 'XXCS_TRAINING_COUPON_AP';
    ELSE
      RETURN NULL;
    END IF;
  END get_alert_name;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --
  --                   1) get population to generate Coupon report
  --                   2) send coupon report output as mail to mail list
  --                   3) insert row to xxcs_coupon_history table to know
  --                      which order line (OM) was sent allready.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --  1.1  22/07/2012  Dalit A. Raviv    Add add training PN to coupon card
  --                                     change cursor pop.
  --  1.2  30/07/2012  Dalit A. Raviv    After adding training part to the coupon number
  --                                     when compare to list_line_no it is not the same value.
  --                                     need to add substr.
  --------------------------------------------------------------------
  PROCEDURE main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_header_id IN NUMBER) IS
  
    -- get coupon population
    CURSOR coupon_pop_c IS
    --  1.1  22/07/2012  Dalit A. Raviv
      SELECT pa.list_line_no || ' (' || training_part.segment1 || ')' coupon_number,
             oh.order_number,
             ol.ordered_item,
             msib.description system_type,
             cii.serial_number,
             hp.party_name,
             oh.org_id,
             ol.line_number
        FROM oe_order_lines_all ol,
             oe_order_headers_all oh,
             oe_price_adjustments pa,
             qp_list_headers_all qp,
             mtl_system_items_b msib,
             hz_parties hp,
             hz_cust_accounts hca,
             csi_item_instances cii,
             (SELECT msi.segment1, qms.product_attr_value
                FROM qp_modifier_summary_v qms,
                     qp_list_headers       qh,
                     qp_pricing_attr_get_v qpa,
                     mtl_system_items_b    msi
               WHERE 1 = 1
                 AND qh.list_header_id = qms.list_header_id
                 AND qpa.product_attr_value = to_char(msi.inventory_item_id)
                 AND qpa.list_header_id = qms.list_header_id
                 AND qms.parent_list_line_id = qpa.parent_list_line_id
                 AND msi.organization_id = 91
                 AND qh.name = 'XX_BUY_GET'
                 AND msi.item_type = 'XXOBJ_SER_EXP'
                 AND nvl(qms.end_date_active, SYSDATE + 1) > SYSDATE) training_part
       WHERE oh.header_id = ol.header_id
         AND ol.inventory_item_id = msib.inventory_item_id
         AND pa.list_header_id = qp.list_header_id
         AND hca.party_id = hp.party_id
         AND oh.sold_to_org_id = hca.cust_account_id
         AND ol.line_id = cii.last_oe_order_line_id -- to remove this outer joine !!!!!!!!!!!!!
         AND cii.inventory_item_id = ol.inventory_item_id
         AND msib.organization_id = 91
         AND ol.line_id = pa.line_id
         AND pa.list_line_type_code = 'CIE'
         AND qp.attribute8 = 'Y'
         AND ol.ordered_item = training_part.product_attr_value
         AND NOT EXISTS (SELECT 1
                FROM xxcs_coupon_history hist
               WHERE pa.list_line_no =
                     substr(hist.counpon_number,
                            1,
                            instr(hist.counpon_number, '(') - 2))
            --where  hist.counpon_number = pa.list_line_no)
         AND p_header_id IS NULL
      UNION
      -- ability to run coupon for specific sales order.
      SELECT pa.list_line_no || ' (' || training_part.segment1 || ')' coupon_number,
             oh.order_number,
             ol.ordered_item,
             msib.description system_type,
             cii.serial_number,
             hp.party_name,
             oh.org_id,
             ol.line_number
        FROM oe_order_lines_all ol,
             oe_order_headers_all oh,
             oe_price_adjustments pa,
             qp_list_headers_all qp,
             mtl_system_items_b msib,
             hz_parties hp,
             hz_cust_accounts hca,
             csi_item_instances cii,
             (SELECT msi.segment1, qms.product_attr_value
                FROM qp_modifier_summary_v qms,
                     qp_list_headers       qh,
                     qp_pricing_attr_get_v qpa,
                     mtl_system_items_b    msi
               WHERE 1 = 1
                 AND qh.list_header_id = qms.list_header_id
                 AND qpa.product_attr_value = to_char(msi.inventory_item_id)
                 AND qpa.list_header_id = qms.list_header_id
                 AND qms.parent_list_line_id = qpa.parent_list_line_id
                 AND msi.organization_id = 91
                 AND qh.name = 'XX_BUY_GET'
                 AND msi.item_type = 'XXOBJ_SER_EXP'
                 AND nvl(qms.end_date_active, SYSDATE + 1) > SYSDATE) training_part
       WHERE oh.header_id = ol.header_id
         AND ol.inventory_item_id = msib.inventory_item_id
         AND pa.list_header_id = qp.list_header_id
         AND hca.party_id = hp.party_id
         AND oh.sold_to_org_id = hca.cust_account_id
         AND ol.line_id = cii.last_oe_order_line_id -- to remove this outer joine !!!!!!!!!!!!!
         AND cii.inventory_item_id = ol.inventory_item_id
         AND msib.organization_id = 91
         AND ol.line_id = pa.line_id
         AND pa.list_line_type_code = 'CIE'
         AND qp.attribute8 = 'Y'
         AND ol.ordered_item = training_part.product_attr_value
         AND oh.header_id = p_header_id;
    --  1.1  22/07/2012  Dalit A. Raviv
  
    /*select pa.list_line_no        Coupon_Number,
           oh.order_number,
           ol.ordered_item,
           msib.description       system_type,
           cii.serial_number,
           hp.party_name,
           oh.org_id
    from   oe_order_lines_all     ol,
           oe_order_headers_all   oh,
           oe_price_adjustments   pa,
           qp_list_headers_all    qp,
           mtl_system_items_b     msib,
           hz_parties             hp,
           hz_cust_accounts       hca,
           csi_item_instances     cii
    where  oh.header_id           = ol.header_id
    and    ol.inventory_item_id   = msib.inventory_item_id
    and    pa.list_header_id      = qp.list_header_id
    and    hca.party_id           = hp.party_id
    and    oh.sold_to_org_id      = hca.cust_account_id
    and    ol.line_id             = cii.last_oe_order_line_id -- to remove this outer joine !!!!!!!!!!!!!
    and    cii.inventory_item_id  = ol.inventory_item_id
    and    msib.organization_id   = 91
    and    ol.line_id             = pa.line_id
    and    pa.list_line_type_code = 'CIE'
    and    qp.attribute8          = 'Y'
    and    not exists             (select 1
                                   from   xxcs_coupon_history hist
                                   where  hist.counpon_number = pa.list_line_no)
    and    p_header_id            is null
    union all
    select pa.list_line_no        Coupon_Number,
           oh.order_number,
           ol.ordered_item,
           msib.description       system_type,
           cii.serial_number,
           hp.party_name,
           oh.org_id
    from   oe_order_lines_all     ol,
           oe_order_headers_all   oh,
           oe_price_adjustments   pa,
           qp_list_headers_all    qp,
           mtl_system_items_b     msib,
           hz_parties             hp,
           hz_cust_accounts       hca,
           csi_item_instances     cii
    where  oh.header_id           = ol.header_id
    and    ol.inventory_item_id   = msib.inventory_item_id
    and    pa.list_header_id      = qp.list_header_id
    and    hca.party_id           = hp.party_id
    and    oh.sold_to_org_id      = hca.cust_account_id
    and    ol.line_id             = cii.last_oe_order_line_id -- to remove this outer joine !!!!!!!!!!!!!
    and    cii.inventory_item_id  = ol.inventory_item_id
    and    msib.organization_id   = 91
    and    ol.line_id             = pa.line_id
    and    pa.list_line_type_code = 'CIE'
    and    qp.attribute8          = 'Y'
    and    oh.header_id           = p_header_id;
    --and rownum = 1; -- TO REMOVE AFTER DEBUG*/
  
    l_coupon_hist_rec t_coupon_hist_rec;
    l_err_code        NUMBER := 0;
    l_err_desc        VARCHAR2(2000) := NULL;
  
    --l_to_mail      varchar(100)   := null;
    l_template     BOOLEAN;
    l_request_id   NUMBER := NULL;
    l_error_flag   BOOLEAN := FALSE;
    l_phase        VARCHAR2(100);
    l_status       VARCHAR2(100);
    l_dev_phase    VARCHAR2(100);
    l_dev_status   VARCHAR2(100);
    l_message      VARCHAR2(100);
    l_return_bool  BOOLEAN;
    l_req_id       NUMBER;
    l_att2_proc    VARCHAR2(150) := NULL;
    l_att3_proc    VARCHAR2(150) := NULL;
    l_to_user_name VARCHAR2(150) := NULL;
    l_cc           VARCHAR2(150) := NULL;
    l_subject      VARCHAR2(360) := NULL;
    l_move         BOOLEAN;
  
    l_alert_name VARCHAR2(150) := NULL;
    l_env        VARCHAR2(50) := NULL;
  
    general_exception EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_env := xxobjt_fnd_attachments.get_environment_name;
    g_env := l_env;
  
    FOR coupon_pop_r IN coupon_pop_c LOOP
      l_request_id := NULL;
      l_error_flag := FALSE;
      l_phase      := NULL;
      l_status     := NULL;
      l_dev_phase  := NULL;
      l_dev_status := NULL;
      l_message    := NULL;
      l_req_id     := NULL;
    
      -- Set Xml Publisher report template
      l_template := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                           template_code      => 'XXCS_COUPONS',
                                           template_language  => 'en',
                                           output_format      => 'PDF',
                                           template_territory => NULL);
      IF l_template <> TRUE THEN
        -- Didn't find Template
        fnd_file.put_line(fnd_file.log,
                          '-----------------------------------');
        fnd_file.put_line(fnd_file.log,
                          '------ Can not Find Template ------');
        fnd_file.put_line(fnd_file.log,
                          '-----------------------------------');
        errbuf  := 'Can not Find Template';
        retcode := 2;
        RAISE general_exception;
      ELSE
        ----------------------------------------------
        -- 1) run report
        ----------------------------------------------
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXCS_COUPONS',
                                                   description => NULL,
                                                   start_time  => NULL,
                                                   sub_request => FALSE,
                                                   argument1   => coupon_pop_r.coupon_number,
                                                   argument2   => coupon_pop_r.order_number,
                                                   argument3   => coupon_pop_r.system_type,
                                                   argument4   => coupon_pop_r.serial_number,
                                                   argument5   => coupon_pop_r.party_name,
                                                   argument6   => coupon_pop_r.org_id);
        -- check concurrent success
        IF l_request_id = 0 THEN
        
          fnd_file.put_line(fnd_file.log, 'Failed to print report -----');
          fnd_file.put_line(fnd_file.log, 'Err - ' || SQLERRM);
          errbuf  := 'Failed to print report';
          retcode := 2;
          RAISE general_exception;
        ELSE
          fnd_file.put_line(fnd_file.log, 'Success to print report -----');
          -- must commit the request
          COMMIT;
          ----------------------------------------------
          -- 2) weit for finish until the request finished
          ----------------------------------------------
          WHILE l_error_flag = FALSE LOOP
            l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                             5,
                                                             86400,
                                                             l_phase,
                                                             l_status,
                                                             l_dev_phase,
                                                             l_dev_status,
                                                             l_message);
          
            IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
              l_error_flag := TRUE;
            ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
              l_error_flag := TRUE;
              errbuf       := 'Request finished in error or warrning, no email send';
              retcode      := 1;
              fnd_file.put_line(fnd_file.log,
                                'Request finished in error or warrning, no email send. try again later. - ' ||
                                l_message);
            END IF; -- dev_phase
          END LOOP; -- l_error_flag
        
          IF l_error_flag = TRUE AND l_dev_status = 'NORMAL' THEN
            ----------------------------------------------
            -- 3) copy output file from conc/out to oracle utilefile dir
            ----------------------------------------------
            l_move := afterreport(l_request_id);
            IF NOT l_move THEN
              fnd_file.put_line(fnd_file.log,
                                'Failed to copy report output');
              errbuf  := 'Failed to copy report output';
              retcode := 2;
              RAISE general_exception;
            END IF;
            ----------------------------------------------
            -- 4) send output to list
            ----------------------------------------------
            -- Call the procedure
            IF l_env = 'PROD' THEN
              l_to_user_name := fnd_profile.value('XXCS_TRAINING_COUPON_MAIN_USER');
              l_alert_name   := get_alert_name(coupon_pop_r.org_id);
              l_cc           := get_send_mail_to(l_alert_name);
            ELSE
              l_to_user_name := 'DALIT.RAVIV';
              l_cc           := 'oradev@objet.com'; -- 'Moshe.Lavi@objet.com'
            END IF;
          
            l_subject   := 'Advanced Operator' || '''' || 's Course Coupon';
            l_err_code  := 0;
            l_err_desc  := NULL;
            l_att2_proc := NULL;
            l_att3_proc := NULL;
          
            xxobjt_wf_mail.send_mail_body_proc(p_to_role     => l_to_user_name, -- i v
                                               p_cc_mail     => l_cc, -- i v
                                               p_bcc_mail    => NULL, -- i v
                                               p_subject     => l_subject, -- i v
                                               p_body_proc   => 'xxcs_wf_send_mail_pkg.prepare_coupon_body', -- i v
                                               p_att1_proc   => 'xxcs_wf_send_mail_pkg.prepare_coupon_attachment/' ||
                                                                l_request_id, -- i v
                                               p_att2_proc   => l_att2_proc, -- i v
                                               p_att3_proc   => l_att3_proc, -- i v
                                               p_err_code    => l_err_code, -- o n
                                               p_err_message => l_err_desc); -- o v
          
            ----------------------------------------------
            -- 5) insert row to xxcs_coupon_history table
            ----------------------------------------------
            IF l_err_code = 0 THEN
              l_err_code                        := NULL;
              l_err_desc                        := NULL;
              l_coupon_hist_rec.counpon_number  := coupon_pop_r.coupon_number;
              l_coupon_hist_rec.sales_order_num := coupon_pop_r.order_number;
              l_coupon_hist_rec.system_type     := coupon_pop_r.system_type;
              l_coupon_hist_rec.serial_number   := coupon_pop_r.serial_number;
              l_coupon_hist_rec.customer_name   := coupon_pop_r.party_name;
              l_coupon_hist_rec.org_id          := coupon_pop_r.org_id;
              insert_coupon_hist(p_coupon_hist_rec => l_coupon_hist_rec, -- i t_coupon_hist_rec
                                 p_err_code        => l_err_code, -- o n
                                 p_err_desc        => l_err_desc); -- o v
            ELSE
              fnd_file.put_line(fnd_file.log,
                                'Error Send Mail - ' || l_err_desc);
            END IF; -- send mail
          END IF; -- concurrent finish to run
        END IF; -- l_request_id
      END IF; -- l_template
    END LOOP;
  
  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXE - main - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END;

END xxcs_coupon_pkg;
/
