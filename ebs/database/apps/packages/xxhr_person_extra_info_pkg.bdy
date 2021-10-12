CREATE OR REPLACE PACKAGE BODY xxhr_person_extra_info_pkg IS
  --------------------------------------------------------------------
  --  name:              XXHR_PERSON_EXTRA_INFO_PKG
  --  create by:         Dalit A. Raviv
  --  Revision:          1.4
  --  creation date:     08/05/2011 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :          HR project - Handle Person Extra Information details
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  08/05/2011    Dalit A. Raviv    initial build
  --  1.1  30/11/2011    Dalit A. Raviv    correct main select of send_outgoing_form procedure
  --                                       select correction - support termination that
  --                                       is early then today.
  --  1.2  30/12/2012    Dalit A. Raviv    procedure get_send_mail_to - Organization heirarchy changes.
  --                                       changes in names -> Objet to Stratasys
  --  1.3  19/02/2013    Dalit A. Raviv    Procedure send_outgoing_form var l_to_mail set to varchar2(200).
  --  1.4  21/01/2014    Dalit A. Raviv    Add send outgoing form to territories
  --  1.5  11/01/2015    Michal Tzvik      CHG0034263: FUNCTION get_send_mail_to: use parameter p_territory instead of hard code
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_lookup_code_meaning
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2011
  --------------------------------------------------------------------
  --  purpose :        translate lookup code to meaning
  --  in params:       lookup type (name)
  --                   lookup code
  --  return:          lookup code meaning
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011   Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_lookup_code_meaning(p_lookup_type IN VARCHAR2,
                                   p_lookup_code IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_meaning VARCHAR2(80) := NULL;
  BEGIN
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = p_lookup_type
    AND    lv.language = 'US'
    AND    lookup_code = p_lookup_code;
  
    RETURN l_meaning;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_lookup_code;
  END get_lookup_code_meaning;

  --------------------------------------------------------------------
  --  name:            check_fin_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/05/2011  Happy Birthday my Li-Or (19)
  --------------------------------------------------------------------
  --  purpose :        check if there are elements of 'Loan IL','Signing Bonus IL'
  --                   for this employee/contractor
  --  in params:       p_person_id
  --  return:          Y/N -> Y - need to send mail to Carmit, No - no need
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/05/2011   Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_fin_mail(p_person_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_count NUMBER := NULL;
  
  BEGIN
    SELECT COUNT(1)
    INTO   l_count
    FROM   pay_input_values_f         inpval,
           pay_element_types_f        TYPE,
           pay_element_links_f        link,
           pay_element_entry_values_f VALUE,
           pay_element_entries_f      entry,
           per_all_people_f           paf,
           per_all_assignments_f      paa
    WHERE  type.element_type_id = link.element_type_id
    AND    entry.element_link_id = link.element_link_id
    AND    entry.entry_type IN ('A', 'R', 'E')
    AND    value.element_entry_id = entry.element_entry_id
    AND    value.effective_start_date = entry.effective_start_date
    AND    value.effective_end_date = entry.effective_end_date
    AND    inpval.input_value_id = value.input_value_id
    AND    inpval.name = 'Amount'
    AND    type.element_name IN
           ('Loan IL', 'Loan US', 'Eligibility Retention Loan to Grant IL', 'Eligibility Retention Loan to Grant US')
    AND    trunc(SYSDATE) BETWEEN entry.effective_start_date AND
           entry.effective_end_date
    AND    paa.assignment_id = entry.assignment_id
    AND    trunc(SYSDATE) BETWEEN paa.effective_start_date AND
           paa.effective_end_date
    AND    paa.person_id = paf.person_id
    AND    trunc(SYSDATE) BETWEEN paf.effective_start_date AND
           paf.effective_end_date
    AND    paf.person_id = p_person_id
    AND    paa.primary_flag = 'Y';
  
    IF l_count > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

  --------------------------------------------------------------------
  --  name:            get_send_mail_to
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2011
  --------------------------------------------------------------------
  --  purpose :        get the list of people to send the mail to.
  --  in params:       p_organization_id - to know to which HR manager
  --                                       the person relate to.
  --                   p_teritory        - HR sysadmin is different between teritories
  --  return:          strinfg with all email address to send to
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011  Dalit A. Raviv    initial build
  --  1.1  30/12/2012  Dalit A. Raviv    Organization heirarchy changes - changes in names -> Objet to Stratasys
  --  1.2  21/01/2014  Dalit A. Raviv    Add send mail to EMEA and APJ
  --                                     change the mail list to be keep at XX_SEND_MAIL VS
  --  1.3  11/01/2015  Michal Tzvik      CHG0034263: use parameter p_territory instead of hard code
  --------------------------------------------------------------------
  FUNCTION get_send_mail_to(p_organization_id IN NUMBER,
                            p_teritory        IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_to_mail      VARCHAR2(500) := NULL;
    l_hr_mng_id    NUMBER := NULL;
    l_hr_mng_email VARCHAR2(100) := NULL;
    l_delimiter    VARCHAR2(10) := ', '; --'|'
  
  BEGIN
    l_hr_mng_id    := xxhr_util_pkg.get_org_hr_divisional_person(p_organization_id);
    l_hr_mng_email := xxhr_util_pkg.get_person_email(l_hr_mng_id);
  
    IF p_teritory IN ('Corp US', 'NA') THEN
      --l_to_mail := xxobjt_general_utils_pkg.get_alert_mail_list('XXHR_END|US','|');--fnd_profile.VALUE('XXHR_US_SUPER_USER_MAIL');
      --l_hr_mng_id    := xxhr_util_pkg.get_org_hr_divisional_person(p_organization_id);
      --l_hr_mng_email := xxhr_util_pkg.get_person_email (l_hr_mng_id);
      --l_to_mail      := l_hr_mng_email;
      NULL;
      ---- CHG0034263 11/01/2015  Michal Tzvik: use parameter p_territory instead of hard code
    
      /*ELSIF p_teritory IN ('Corp IL', 'LATAM') THEN
        --l_to_mail      := fnd_profile.VALUE('XXHR_IL_SUPER_USER_MAIL');
        l_to_mail := xxobjt_general_utils_pkg.get_alert_mail_list('XXHR_END|IL', l_delimiter);
        --l_hr_mng_id    := xxhr_util_pkg.get_org_hr_divisional_person(p_organization_id);
        --l_hr_mng_email := xxhr_util_pkg.get_person_email (l_hr_mng_id);
        IF l_hr_mng_email IS NOT NULL THEN
          l_to_mail := l_to_mail || l_delimiter || l_hr_mng_email;
        END IF;
      
      ELSIF p_teritory IN ('APJ') THEN
        l_to_mail := xxobjt_general_utils_pkg.get_alert_mail_list('XXHR_END|APJ', l_delimiter);
        IF l_hr_mng_email IS NOT NULL THEN
          l_to_mail := l_to_mail || l_delimiter || l_hr_mng_email;
        END IF;*/
    ELSIF p_teritory IN ('EMEA') THEN
      l_to_mail := xxobjt_general_utils_pkg.get_alert_mail_list('XXHR_END|EU', l_delimiter);
      IF l_hr_mng_email IS NOT NULL THEN
        l_to_mail := l_to_mail || l_delimiter || l_hr_mng_email;
      END IF;
    ELSE
      ---- CHG0034263 11/01/2015  Michal Tzvik: use parameter p_territory instead of hard code 
      -- l_to_mail := fnd_profile.value('XXHR_IL_SUPER_USER_MAIL'); 
      l_to_mail := xxobjt_general_utils_pkg.get_alert_mail_list('XXHR_END|' ||
                                                                p_teritory, l_delimiter);
      IF l_hr_mng_email IS NOT NULL THEN
        l_to_mail := l_to_mail || l_delimiter || l_hr_mng_email;
      END IF;
    END IF;
  
    RETURN l_to_mail;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN fnd_profile.value('XXHR_ELEMENT_SEND_MAIL_BCC'); -- Dalit.raviv@Stratasys.com
  
  END get_send_mail_to;

  --------------------------------------------------------------------
  --  name:            send_outgoing_form
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2011
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel sending outgoing form to
  --                   HR maintenance person.
  --  in params:       p_person_id  - Unique id
  --                   retcode      - 0    success other fialed
  --                   errbuf       - null success other fialed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2011  Dalit A. Raviv    initial build
  --  1.1  30/11/2011  Dalit A. Raviv    correct main select of send_outgoing_form procedure
  --                                     select correction - support termination that
  --                                     is early then today.
  --  1.2  30/12/2012  Dalit A. Raviv    change name of file from Objet_Out_Going_Form to Stratasys_OutGoingForm
  --  1.3  19/02/2013  Dalit A. Raviv    variable l_to_mail set to varchar2(200).
  --  1.4  21/01/2014  Dalit A. Raviv    Add send outgoing form to territories, and change to use
  --                                     add delivery option instead of using send mail program(bin)
  --------------------------------------------------------------------
  PROCEDURE send_outgoing_form(errbuf      OUT VARCHAR2,
                               retcode     OUT VARCHAR2,
                               p_person_id IN NUMBER) IS
  
    CURSOR get_population_c IS
      SELECT 'EMP' entity,
             paf.person_id person_id,
             paf.last_name last_name,
             paf.first_name first_name,
             nvl(paf.employee_number, paf.npw_number) emp_num,
             paa.organization_id organization_id,
             xxhr_util_pkg.get_person_org_name(paf.person_id, paa.effective_start_date, 0) dept,
             xxhr_util_pkg.get_organization_by_hierarchy(paa.organization_id, 'DIV', 'NAME') division,
             xxhr_util_pkg.get_organization_by_hierarchy(paa.organization_id, 'TER', 'NAME') teritory
      FROM   per_all_people_f       paf,
             per_periods_of_service pps,
             per_all_assignments_f  paa
      WHERE  trunc(SYSDATE) BETWEEN paf.effective_start_date AND
             paf.effective_end_date
      AND    paf.person_id = pps.person_id
      AND    paf.person_id = paa.person_id
            -- 1.1 Dalit A. Raviv 30/11/2011
            --and    trunc(sysdate)                   between paa.effective_start_date and paa.effective_end_date
      AND    paa.effective_start_date =
             (SELECT MAX(paa1.effective_start_date)
               FROM   per_all_assignments_f paa1
               WHERE  paa1.person_id = paf.person_id)
            -- end 1.1
      AND    pps.actual_termination_date =
             (SELECT MAX(pps1.actual_termination_date)
               FROM   per_periods_of_service pps1
               WHERE  pps1.person_id = paf.person_id)
      AND    (paf.person_id = p_person_id OR p_person_id IS NULL)
      AND    paa.primary_flag = 'Y'
      UNION
      SELECT 'CWK' entity,
             paf.person_id person_id,
             paf.last_name last_name,
             paf.first_name first_name,
             nvl(paf.employee_number, paf.npw_number) emp_num,
             paa.organization_id organization_id,
             xxhr_util_pkg.get_person_org_name(paf.person_id, paa.effective_start_date, 0) dept,
             xxhr_util_pkg.get_organization_by_hierarchy(paa.organization_id, 'DIV', 'NAME') division,
             xxhr_util_pkg.get_organization_by_hierarchy(paa.organization_id, 'TER', 'NAME') teritory
      FROM   per_all_people_f         paf,
             per_periods_of_placement ppp,
             per_all_assignments_f    paa
      WHERE  trunc(SYSDATE) BETWEEN paf.effective_start_date AND
             paf.effective_end_date
      AND    paf.person_id = ppp.person_id
      AND    paf.person_id = paa.person_id
            -- 1.1 Dalit A. Raviv 30/11/2011
            --and    trunc(sysdate)                   between paa.effective_start_date and paa.effective_end_date
      AND    paa.effective_start_date =
             (SELECT MAX(paa1.effective_start_date)
               FROM   per_all_assignments_f paa1
               WHERE  paa1.person_id = paf.person_id)
            -- end 1.1
      AND    ppp.actual_termination_date =
             (SELECT MAX(ppp1.actual_termination_date)
               FROM   per_periods_of_placement ppp1
               WHERE  ppp1.person_id = paf.person_id)
      AND    (paf.person_id = p_person_id OR p_person_id IS NULL)
      AND    paa.primary_flag = 'Y';
  
    l_to_mail    VARCHAR(500) := NULL; --  1.3  19/02/2013  Dalit A. Raviv
    l_template   BOOLEAN;
    l_request_id NUMBER := NULL;
    l_error_flag BOOLEAN := FALSE;
    l_phase      VARCHAR2(100);
    l_status     VARCHAR2(100);
    l_dev_phase  VARCHAR2(100);
    l_dev_status VARCHAR2(100);
    l_message    VARCHAR2(100);
    --l_return_bool   boolean;
    l_req_id    NUMBER;
    l_full_name VARCHAR2(360) := NULL;
    l_emp_num   VARCHAR2(50) := NULL;
    --l_email_body    varchar2(1500):= 'Attached file contain Person OutGoing Form. '||chr(13);
    --l_email_body1   varchar2(1500):= 'Please do not reply to this email. '||chr(13);
    --l_email_body2   varchar2(1500):= 'This mailbox does not allow incoming messages. ';
    --  1.4  21/01/2014  Dalit A. Raviv
    l_template_code VARCHAR2(50) := NULL;
    l_subject       VARCHAR2(500) := NULL;
    l_profile       VARCHAR2(100) := fnd_profile.value('XXHR_OUTGOING_SENDMAIL');
    l_from          VARCHAR2(150) := NULL;
    l_result1       BOOLEAN;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    FOR get_population_r IN get_population_c LOOP
      fnd_file.put_line(fnd_file.log, '-----------------------------------');
      --l_to_mail      := null;
      l_request_id := NULL;
      l_error_flag := FALSE;
      l_phase      := NULL;
      l_status     := NULL;
      l_dev_phase  := NULL;
      l_dev_status := NULL;
      l_message    := NULL;
      l_req_id     := NULL;
      l_full_name  := NULL;
      l_emp_num    := NULL;
    
      -- get to mail address
      l_to_mail := get_send_mail_to(get_population_r.organization_id, get_population_r.teritory);
    
      fnd_file.put_line(fnd_file.log, 'Employee - ' ||
                         get_population_r.emp_num || ' - ' ||
                         get_population_r.first_name || ', ' ||
                         get_population_r.last_name);
      -- Set Xml Publisher report template
      -- 21/01/2014 Dalit Raviv Handle territories
      IF get_population_r.teritory IN ('Corp IL', 'LATAM') THEN
        l_template_code := 'XXHR_OUTGOING_FORM';
      ELSIF get_population_r.teritory IN ('APJ') THEN
        l_template_code := 'XXHR_OUTGOING_FORM_APJ';
      ELSIF get_population_r.teritory IN ('EMEA') THEN
        l_template_code := 'XXHR_OUTGOING_FORM_EMEA';
      ELSE
        l_template_code := 'XXHR_OUTGOING_FORM';
      END IF;
    
      l_subject := 'Stratasys End employment check list - ' ||
                   get_population_r.emp_num || ' - ' ||
                   get_population_r.first_name || ', ' ||
                   get_population_r.last_name; -- Subject
      -- get from mail 
      l_from := fnd_profile.value('XXHR_OUTGOING_FROM_EMAIL');
      IF l_from IS NULL THEN
        BEGIN
          IF l_profile IS NULL THEN
            SELECT p.profile_value
            INTO   l_from
            FROM   xxobjt_profiles_v p
            WHERE  p.profile_option_name = 'XXHR_OUTGOING_FROM_EMAIL'
            AND    p.level_type = 'Site';
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            BEGIN
              SELECT p.email_address
              INTO   l_from
              FROM   fnd_user         fu,
                     per_all_people_f p
              WHERE  fu.employee_id = p.person_id
              AND    trunc(SYSDATE) BETWEEN p.effective_start_date AND
                     p.effective_end_date
              AND    fu.user_id = fnd_global.user_id;
            EXCEPTION
              WHEN OTHERS THEN
                IF xxagile_util_pkg.get_bpel_domain = 'production' THEN
                  l_from := 'oracleprod@stratasys.com';
                ELSE
                  l_from := 'oradev@stratasys.com';
                END IF;
            END;
        END;
      END IF;
    
      --l_from    := 'Dalit.Raviv@stratasys.com';
      --l_to_mail := 'Dalit.Raviv@stratasys.com';
      l_result1 := fnd_request.add_delivery_option(TYPE => 'E', -- this one to specify the delivery option as Email
                                                   p_argument1 => l_subject, -- subject for the mail
                                                   p_argument2 => l_from, -- from address
                                                   p_argument3 => l_to_mail, -- to address
                                                   p_argument4 => NULL, -- cc address to be specified here. 
                                                   nls_language => ''); -- language option 
    
      IF fnd_request.set_print_options(copies => 0) THEN
        NULL;
      END IF;
      l_template := fnd_request.add_layout(template_appl_name => 'XXOBJT', template_code => l_template_code, template_language => 'en', output_format => 'PDF', template_territory => 'US');
    
      IF l_template = TRUE THEN
      
        -- Run out going form
        l_request_id := fnd_request.submit_request(application => 'XXOBJT', program => 'XXHR_OUTGOING_FORM', description => NULL, start_time => NULL, sub_request => FALSE, argument1 => get_population_r.person_id, -- P_PERSON_ID
                                                   argument2 => 'N'); -- P_FINANCE_YN
        -- check concurrent success
        IF l_request_id = 0 THEN
        
          fnd_file.put_line(fnd_file.log, 'Failed to print report -----');
          fnd_file.put_line(fnd_file.log, 'Err - ' || SQLERRM);
          errbuf  := 'Failed to print report';
          retcode := 2;
        ELSE
          fnd_file.put_line(fnd_file.log, 'Success to print report -----');
          -- must commit the request
          COMMIT;
        END IF; -- l_request_id concurrent run
      ELSE
        --
        -- Didn't find Template
        --
        fnd_file.put_line(fnd_file.log, '-----------------------------------');
        fnd_file.put_line(fnd_file.log, '------ Can not Find Template ------');
        fnd_file.put_line(fnd_file.log, '-----------------------------------');
        errbuf  := 'Can not Find Template';
        retcode := 2;
      END IF; -- l_template
    
    -- send mail to the bookkeeper (Carmit)
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - send_outgoing_form - Failed - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 2;
  END send_outgoing_form;

END xxhr_person_extra_info_pkg;
/
