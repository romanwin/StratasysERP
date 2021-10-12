CREATE OR REPLACE PACKAGE BODY xxinv_resin_rep_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXINV_RESIN_REP
  --  create by:          YUVAL TAL
  --  $Revision:          1.0 $
  --  creation date:      9.8.10
  --  Purpose :           SUPPORT XMLP XXINVRESINREP  
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    9.8.10    YUVAL TAL            initial build
  --  1.1    06.5.12   yuval tal          distribute_resin_report:   AND t.program_short_name = 'XXINVRESINREP';
  ----------------------------------------------------------------------- 

  ----------------------------------------
  -- distribute_resin_report

  -- check in which ou items exists and send report 
  ----------------------------------------

  PROCEDURE distribute_resin_report(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_mail_recipients VARCHAR2) IS
    CURSOR c_mail IS
      SELECT DISTINCT email
        FROM xxobjt_mail_list_v t
       WHERE t.email = nvl(p_mail_recipients, email)
         AND t.program_short_name = 'XXINVRESINREP';
  
    l_request_id NUMBER;
    l_result     BOOLEAN;
  
  BEGIN
  
    FOR i IN c_mail LOOP
      l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                         template_code      => 'XXINVRESINREP',
                                         template_language  => 'en',
                                         template_territory => 'US',
                                         output_format      => 'PDF');
    
      l_result     := fnd_request.set_print_options(printer     => fnd_profile.value('PRINTER'),
                                                    copies      => 0,
                                                    save_output => TRUE);
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXINVRESINREP',
                                                 argument1   => i.email);
      COMMIT;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      errbuf := 'General exception - xxinv_resin_rep.distribute_resin_report :' ||
                substr(SQLERRM, 1, 250);
      fnd_file.put_line(fnd_file.log, substr(errbuf, 1, 250));
      retcode := 2;
  END;
  ---------------------------------------------------
  -- AFTER_REPORT
  -- 
  -- send  doc by mail 
  ---------------------------------------------------
  FUNCTION after_report(p_mail_recipients VARCHAR2) RETURN BOOLEAN IS
  
    l_request_id NUMBER;
    --  l_contact_mail VARCHAR2(100);
    --l_cont_name VARCHAR2(360);
  
    l_email_subject VARCHAR2(200) := p_operating_unit || '_Resin_Report';
    l_email_body    VARCHAR2(1500);
    l_email_body1   VARCHAR2(1500) := chr(13);
    l_email_body2   VARCHAR2(1500) := chr(13);
  BEGIN
  
    -- l_contact_mail := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit,
    --          'XXINVRESINREP');
    -- l_contact_mail := nvl(l_contact_mail,
    --     fnd_profile.VALUE('XXSYS_ORACLE_OPERATION_MAIL'));
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSENDREQOUTPDFGEN',
                                               argument1   => l_email_subject,
                                               argument2   => l_email_body,
                                               argument3   => l_email_body1,
                                               argument4   => l_email_body2,
                                               argument5   => 'XXINVRESINREP',
                                               argument6   => fnd_global.conc_request_id,
                                               argument7   => p_mail_recipients,
                                               argument8   => 'ResinReport',
                                               argument9   => fnd_global.conc_request_id);
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
    
  END;

END xxinv_resin_rep_pkg;
/
