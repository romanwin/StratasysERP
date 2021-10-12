create or replace package body xxoe_order_acknowledgment_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               xxoe_order_acknowledgment_pkg
  --  create by:          Yuval Tal
  --  $Revision:          1.0
  --  creation date:      10/02/2011
  --  Description:        Sales order approval process
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/02/2011    Michal Tzvik    initial build
  --  1.1   08/04/2015    Diptasurjya     CHG0036213 - submit_aerospace_ack, submit_aerospace_email added
  --  1.2   07/03/2017    Lingaraj        CHG0040074 - Warranty extension - DACH
  --                                      Added a new Procedure get_warranty_extension_msg
  --  1.3   04/04/2019    Diptasurjya     INC0153072 - Reduce program wait time in submit_order_ack_by_mail
  --                                      Change submit_order_ack_by_mail to insert audit record even if
  --                                      no delivery email addresses could be derived
  --  1.4  08/21/2019    Diptasurjya      CHG0045128 - remove ship and bill email identifier
  --------------------------------------------------------------------

  --------------------------------------------
  PROCEDURE submit_order_acknowledgment(p_header_id IN NUMBER) IS
    l_layout     BOOLEAN;
    l_request_id NUMBER;
  BEGIN

    l_layout     := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                           template_code      => 'XXOEORDACK',
                                           template_language  => 'en',
                                           template_territory => 'US',
                                           output_format      => 'PDF');
    l_request_id := fnd_request.submit_request(application => 'XXOBJT1',
                                               program     => 'XXOEORDACK',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => p_header_id);

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('==========Error: ' || SQLERRM);
  END;

  ---------------------------------------------
  -- get_mail_distribution
  ----------------------------------------------
  FUNCTION get_contact_mail_distribution(p_header_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
    CURSOR c IS
      SELECT t.email_address email_address
        FROM xxoe_site_use_contact_v t, oe_order_headers_all h
       WHERE h.invoice_to_org_id = t.site_use_id
         AND h.invoice_to_contact_id = t.contact_id
         AND t.email_address IS NOT NULL
         AND h.header_id = p_header_id
         AND rownum = 1;

  BEGIN

    FOR i IN c LOOP
      l_tmp := i.email_address;
    END LOOP;

    RETURN l_tmp;

  END;

  --------------------------------------------------------------------
  --  Name      :        submit_order_ack_by_mail
  --  Created By:        Michal Tzvik
  --  Revision:          1.0
  --  Creation Date:     10/02/2011
  --------------------------------------------------------------------
  --  Purpose :          submit XXOEORDACK send output to email
  --------------------------------------------------------------------
  --  Ver  Date          Name              Desc
  --  1.0  10/02/2011    Michal Tzvik      Initial Build
  --  1.1  04/04/2019    Diptasurjya       INC0153072 - Reduce program wait time
  --                                       In case of no email addresses, enter record in audit table
  --  1.2  08/21/2019    Diptasurjya       CHG0045128 - remove ship and bill email identifier
  --------------------------------------------------------------------

  PROCEDURE submit_order_ack_by_mail(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2) IS

    CURSOR c IS
      SELECT * FROM xxoe_order_ack_mail_v /*oe_order_headers_all*/ t;
    -- WHERE t.order_number = '141494'; --  t;
    l_layout          BOOLEAN;
    l_request_id      NUMBER;
    l_email_body      VARCHAR2(500);
    l_email_body2     VARCHAR2(500);
    l_email_body3     VARCHAR2(500);
    l_mail_to         VARCHAR2(500);
    l_mail_to_creator VARCHAR2(500);
    continue_exception EXCEPTION;

    l_bill_mail_suffix  varchar2(10) := '(BILL)';  -- CHG0045128 added
    l_ship_mail_suffix  varchar2(10) := '(SHIP)';  -- CHG0045128 added
    l_cust_mail_suffix  varchar2(10) := '(CUST)';  -- CHG0045128 added

    --
    l_wait_result     BOOLEAN;
    l_phase           VARCHAR2(20);
    l_status          VARCHAR2(20);
    l_dev_phase       VARCHAR2(20);
    l_dev_status      VARCHAR2(20);
    l_message1        VARCHAR2(20);
    lb_result         BOOLEAN;
    l_legal_entity_id NUMBER;
    l_entity_name     VARCHAR2(50);
    CURSOR c_split(c_str VARCHAR) IS
      SELECT *
        FROM (SELECT TRIM(substr(txt,
                                 instr(txt, ',', 1, LEVEL) + 1,
                                 instr(txt, ',', 1, LEVEL + 1) -
                                 instr(txt, ',', 1, LEVEL) - 1)) AS token
                FROM (SELECT ',' || c_str || ',' AS txt FROM dual)
              CONNECT BY LEVEL <=
                         length(txt) - length(REPLACE(txt, ',', '')) - 1)
       WHERE token IS NOT NULL;

  BEGIN
    retcode := 0;

    IF nvl(fnd_profile.VALUE('XXOEACKMAIL'), 'N') = 'N' THEN
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        '----->  Unable to continue due to profile XXOEACKMAIL');

      RETURN;

    END IF;

    --  BEGIN
    /*  fnd_global.apps_initialize(3850, 20420, 1);
    mo_global.set_org_context(p_org_id_char     => 81,
                              p_sp_id_char      => NULL,
                              p_appl_short_name => 'PO');*/

    -- END;
    FOR i IN c LOOP
      fnd_file.put_line(fnd_file.log,
                        'Start mail process for order #' || i.order_number);
      BEGIN

        SELECT xxhr_util_pkg.get_person_email(u.employee_id),
               upper(replace(replace(replace(h.attribute19,l_bill_mail_suffix,''),l_ship_mail_suffix,''),l_cust_mail_suffix,''))  -- CHG0045128 replace bill and ship identifiers
          INTO l_mail_to_creator, l_mail_to
          FROM fnd_user u, oe_order_headers_all h
         WHERE u.user_id = h.created_by
           AND h.header_id = i.header_id;

        /*INC0153072 - If no email address provided and order creator has no employee assignment
                       then enter record in mail audit table and continue to next record in loop
                       no need to generate document and call email program unneccesarily*/
        if l_mail_to_creator is null and l_mail_to is null then
          INSERT INTO xxobjt_mail_audit
              (source_code,
               creation_date,
               created_by,
               email,
               pk1,
               pk2,
               pk3)
            VALUES
              ('XXOEORDACK',
               SYSDATE,
               fnd_global.user_id,
               null,
               i.header_id,
               NULL,
               NULL);

          commit;

          continue;
        end if;
        -- INC0153072 end

        --l_mail_to := get_mail_distribution(i.header_id); --'yuval.tal@objet.com'; --get_mail_list;

        -- submit ack report
        l_layout := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                           template_code      => 'XXOEORDACK',
                                           template_language  => 'en',
                                           template_territory => 'US',
                                           output_format      => 'PDF');

        l_layout := fnd_request.set_print_options(copies => 0);

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXOEORDACK',
                                                   description => NULL,
                                                   start_time  => NULL,
                                                   sub_request => FALSE,
                                                   argument1   => i.header_id,
                                                   argument2   => 'Y');

        COMMIT;

        IF l_request_id = 0 THEN
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Unable to submit Order Acknowledgment report for order_number=' ||
                            i.order_number);
          RAISE continue_exception;
        ELSE
          -- wait for end report
          lb_result := fnd_concurrent.wait_for_request(l_request_id,
                                                       1,  -- INC0153072 reduce from 10 to 1
                                                       120,
                                                       l_phase,
                                                       l_status,
                                                       l_dev_phase,
                                                       l_dev_status,
                                                       l_message1);
          COMMIT;
          IF l_dev_phase = 'COMPLETE' THEN
            IF l_dev_status = 'WARNING' OR l_dev_status = 'ERROR' THEN
              retcode := 1;
              fnd_file.put_line(fnd_file.log,
                                'report failed : l_request_id=' ||
                                l_request_id || ' order no =' ||
                                i.order_number);
              RAISE continue_exception;
            ELSIF l_dev_status = 'NORMAL' THEN
              dbms_output.put_line('Success');
            END IF;
          END IF;
        END IF;

        -- submit mail program
        SELECT t.default_legal_context_id
          INTO l_legal_entity_id
          FROM hr_operating_units t
         WHERE t.organization_id = i.org_id;

        l_entity_name := xxar_utils_pkg.get_company_name(p_legal_entity_id => l_legal_entity_id,
                                                         p_org_id          => i.org_id);

        fnd_message.set_name('XXOBJT', 'XXOE_ACKMAIL_MSG1');
        fnd_message.set_token('ORDER_NO', i.order_number);
        fnd_message.set_token('CUSTOMER_PO', i.cust_po_number);
        l_email_body := fnd_message.get;
        fnd_message.set_name('XXOBJT', 'XXOE_ACKMAIL_MSG2');
        l_email_body2 := fnd_message.get;

        fnd_message.set_name('XXOBJT', 'XXOE_ACKMAIL_MSG3');
        fnd_message.set_token('LEGAL_ENTITY', l_entity_name);
        l_email_body3 := fnd_message.get;

        IF nvl(ltrim(rtrim(l_mail_to)), 'N') = 'N' THEN
          l_email_body := 'No  distribution mails were found !!!' ||
                          chr(13) || chr(13) || chr(13) || l_email_body;

        END IF;
        l_email_body  := REPLACE(l_email_body, ' ', '_');
        l_email_body2 := REPLACE(nvl(l_email_body2, '_'), ' ', '_');
        l_email_body3 := REPLACE(nvl(l_email_body3, '_'), ' ', '_');

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXSENDREQTOMAIL', --'XXSENDREQOUTPDFGEN',
                                                   argument1   => 'Order_Acknowledgment', -- Mail Subject
                                                   argument2   => l_email_body, -- Mail Body
                                                   argument3   => l_email_body2, -- Mail Body1
                                                   argument4   => l_email_body3, -- Mail Body2
                                                   argument5   => 'XXOEORDACK', -- Concurrent Short Name
                                                   argument6   => l_request_id, -- Request id
                                                   argument7   => REPLACE(l_mail_to || ',' ||
                                                                          l_mail_to_creator,
                                                                          ' ',
                                                                          '_'), -- Mail Recipient      --'Dalit.Raviv@Objet.com',--'saar.nagar@Objet.com',
                                                   argument8   => 'OrderAcknowledgment', -- Report Name (each run can get different name)
                                                   argument9   => i.order_number, -- Report Subject Number (Sr Number, SO Number...)
                                                   argument10  => 'PDF', -- Concurrent Output Extension - PDF, EXCEL ...
                                                   argument11  => 'pdf', -- File Extension to Send - pdf, exl
                                                   argument12  => 'N' -- Delete Concurrent Output - Y/N

                                                   );

        -- update order header table
        COMMIT;

        IF l_request_id = 0 THEN
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Failed to submit XXSENDREQTOMAIL for order_number=' ||
                            i.order_number);
          RAISE continue_exception;
        ELSE

          -- insert audit log
          FOR j IN c_split(l_mail_to || ',' || l_mail_to_creator) LOOP
            INSERT INTO xxobjt_mail_audit
              (source_code,
               creation_date,
               created_by,
               email,
               pk1,
               pk2,
               pk3)
            VALUES
              ('XXOEORDACK',
               SYSDATE,
               fnd_global.user_id,
               j.token,
               i.header_id,
               NULL,
               NULL);

          END LOOP;

        END IF;

        COMMIT;
      EXCEPTION
        WHEN continue_exception THEN
          NULL;

        WHEN OTHERS THEN
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Unable to submit Order Acknowledgment report for order_number=' ||
                            i.order_number || ' ' || SQLERRM);
      END;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := SQLERRM;
  END;

  --------------------------------------------------------------------
  --  Name      :        submit_aerospace_ack
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     09/21/2015
  --------------------------------------------------------------------
  --  Purpose :          CHG0036213 - This procedure will be called from
  --                     the order header workflow XX: Order Flow - Generic
  --                     to check if applicable items exist at line level
  --                     and submit the Order Acknowledgement program
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  09/21/2015    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE submit_aerospace_ack(p_header_id      IN NUMBER,
                                 x_request_id     OUT number,
                                 x_status         OUT varchar2,
                                 x_status_message OUT varchar2) IS
    l_ord_num                    number;
    l_org_id                     number;
    l_header_id                  number;
    l_conc_id                    number;
    l_order_aerospace_item_count number := 0;

    l_user_id number;
    l_resp_id number;
    l_appl_id number;

    v_phase      VARCHAR2(80) := NULL;
    v_status     VARCHAR2(80) := NULL;
    v_dev_phase  VARCHAR2(80) := NULL;
    v_dev_status VARCHAR2(80) := NULL;
    v_message    VARCHAR2(240) := NULL;
    v_req_st     BOOLEAN;

    l_status     varchar2(10) := 'SUCCESS';
    l_status_msg varchar2(2000);
    e_error exception;
  BEGIN
    --g_log_program_unit := 'submit_aerospace_ack';

    select org_id
      into l_org_id
      from oe_order_headers_all ooha
     where header_id = p_header_id;

    if xxhz_util.get_ou_lang(l_org_id) = 'JA' then
      l_conc_id := fnd_request.submit_request(application => 'XXOBJT',
                                              program     => 'XXOEORDACK_JPN',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => p_header_id,
                                              argument2   => 'Y');
    else
      l_conc_id := fnd_request.submit_request(application => 'XXOBJT',
                                              program     => 'XXOEORDACK',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => p_header_id,
                                              argument2   => 'Y');
    end if;

    IF l_conc_id > 0 then
      COMMIT;

      LOOP
        v_req_st := APPS.FND_CONCURRENT.WAIT_FOR_REQUEST(request_id => l_conc_id,
                                                         interval   => 0,
                                                         max_wait   => 0,
                                                         phase      => v_phase,
                                                         status     => v_status,
                                                         dev_phase  => v_dev_phase,
                                                         dev_status => v_dev_status,
                                                         message    => v_message);
        EXIT WHEN v_dev_phase = 'COMPLETE';
      END LOOP;
      x_request_id := l_conc_id;

      if v_dev_status <> 'NORMAL' then
        l_status     := 'ERROR';
        l_status_msg := 'Order Acknowledgement program finished with errors.';
      end if;

      COMMIT;
    ELSE
      l_status     := 'ERROR';
      l_status_msg := 'Order Acknowledgement program could not be submitted';
    END IF;

    x_status         := l_status;
    x_status_message := l_status_msg;
  END submit_aerospace_ack;

  --------------------------------------------------------------------
  --  Name      :        submit_aerospace_email
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     09/21/2015
  --------------------------------------------------------------------
  --  Purpose :          CHG0036213 - This procedure will be called from
  --                     the concurrent program XXOMAEROSPACEORDACK to
  --                     submit XXOEORDACK and XML Bursting program for that request
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  09/21/2015    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE submit_aerospace_email(errbuf      OUT VARCHAR2,
                                   retcode     OUT VARCHAR2,
                                   p_header_id IN varchar2) IS
    l_ord_num                    number;
    l_org_id                     number;
    l_header_id                  number;
    l_ack_conc_id                number;
    l_conc_id                    number;
    l_order_aerospace_item_count number := 0;

    l_user_id number;
    l_resp_id number;
    l_appl_id number;

    l_ack_status     varchar2(10);
    l_ack_status_msg varchar2(2000);
    l_status         varchar2(10);
    l_status_msg     varchar2(2000);
    e_error exception;
  BEGIN
    --g_log_program_unit := 'submit_aerospace_email';

    submit_aerospace_ack(p_header_id,
                         l_ack_conc_id,
                         l_ack_status,
                         l_ack_status_msg);

    if l_ack_status = 'SUCCESS' then
      --fnd_global.APPS_INITIALIZE(l_user_id,l_resp_id,l_appl_id);

      l_conc_id := fnd_request.submit_request(application => 'XDO',
                                              program     => 'XDOBURSTREP',
                                              description => NULL,
                                              start_time  => SYSDATE,
                                              sub_request => FALSE,
                                              argument1   => NULL,
                                              argument2   => l_ack_conc_id,
                                              argument3   => 'Y');

      if l_conc_id = 0 then
        fnd_file.put_line(fnd_file.LOG,
                          'ERROR: XML Bursting program could not be submitted for request ID ' ||
                          l_ack_conc_id);
        raise e_error;
      end if;
    else
      fnd_file.put_line(fnd_file.LOG,
                        'ERROR: Acknowledgement program submission: ' ||
                        l_ack_status_msg);
      raise e_error;
    end if;

    errbuf  := 'SUCCESS';
    retcode := 0;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.LOG, 'ERROR: ' || SQLERRM);
      errbuf  := 'ERROR';
      retcode := 2;
  END submit_aerospace_email;
  --------------------------------------------------------------------
  --  customization code: CHG0040074
  --  name:               get_warranty_extension_msg
  --  create by:          Lingaraj Sarangi
  --  Revision:           1.0
  --  creation date:      07-Mar-2017
  --  Purpose :           This is the Procedure which support the dynamic sql.
  --  Return Value:       VARCHAR2
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   07-Mar-2017   Lingaraj Sarangi    Initial Build: CHG0040074
  ----------------------------------------------------------------------
  PROCEDURE get_warranty_extension_msg(p_oh_header_id IN NUMBER, --Order Header Id
                                       x_ret_msg      OUT VARCHAR2,
                                       x_errcode      OUT VARCHAR2,
                                       x_errbuf       OUT VARCHAR2) IS
    cursor c_dyn_sql is
      select flex_value seq,
             (attribute1 || ' ' || attribute2 || ' ' || attribute3 || ' ' ||
             attribute4) sqlqry,
             attribute5 message_name
        from fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
       where ffvs.flex_value_set_id = ffvv.flex_value_set_id
         and ffvs.flex_value_set_name = 'XXOEORDERACK_DYNAMIC_TEXT'
         and enabled_flag = 'Y';

    l_ret_val NUMBER;
  BEGIN
    x_errcode := fnd_api.g_ret_sts_success;
    x_ret_msg := NULL;

    For rec in c_dyn_sql Loop
      l_ret_val := 0;

      EXECUTE IMMEDIATE rec.sqlqry
        INTO l_ret_val
        USING p_oh_header_id;

      IF l_ret_val > 0 and nvl(rec.message_name, 'X') <> 'X' Then
        fnd_message.clear;
        fnd_message.set_name('XXOBJT', rec.message_name);
        x_ret_msg := (CASE
                       WHEN x_ret_msg IS NULL THEN
                        ''
                       ELSE
                        (x_ret_msg || chr(10))
                     END) || fnd_message.get;
      End If;

    End Loop;

  Exception
    When Others Then
      x_ret_msg := Null;
      x_errcode := fnd_api.g_ret_sts_error;
      x_errbuf  := sqlerrm;
  END get_warranty_extension_msg;

END xxoe_order_acknowledgment_pkg;
/
