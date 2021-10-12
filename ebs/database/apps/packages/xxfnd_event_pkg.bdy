CREATE OR REPLACE PACKAGE BODY xxfnd_event_pkg IS
  ---------------------------------------------------------------------------
  --  name:               xxfnd_event_pkg
  --  create by:          DCHATTERJEE
  --  $Revision:          1.0
  --  creation date:      05-NOV-2019
  --  Purpose :           FND Business event handler package
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05-NOV-2019   Diptasurjya     CHG0045880 - Initial Build
  --  1.1   18-NOV-2019   Diptasurjya     INC0175411 - Add program status check in procedure conc_request_event_process
  --                                      
  -----------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          logging process
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  04-NOV-2019  Diptasurjya Chatterjee        CHG0045880 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log(p_string VARCHAR2) IS
    pragma autonomous_transaction;
    g_log         VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
  BEGIN
    IF g_log = 'Y' THEN
      if fnd_global.CONC_REQUEST_ID > 0 then
        fnd_file.put_line(fnd_file.log, p_string);
      else
         fnd_log.STRING(
            log_level => fnd_log.LEVEL_UNEXPECTED,
            module    => 'xxssys.xxfnd_event_pkg',
            message   => p_string);

      end if;
    END IF;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          This Procedure is used to send Mail for errors from events
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  04-NOV-2019  Diptasurjya Chatterjee        CHG0045880 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail_autonomous(p_program_name_to IN VARCHAR2,
            p_program_name_cc IN VARCHAR2,
            p_subject         IN VARCHAR2,
            p_body            IN VARCHAR2) IS
    pragma autonomous_transaction;
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);
  BEGIN
    log('send_mail_autonomous: Inside mailing program');
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                p_program_short_name => p_program_name_to);
    log('send_mail_autonomous: Mail To List: '||l_mail_to_list);

    l_mail_cc_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                p_program_short_name => p_program_name_cc);
	  log('send_mail_autonomous: Mail CC List: '||l_mail_to_list);

    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
              p_cc_mail     => l_mail_cc_list,
              p_subject     => p_subject,
              p_body_text   => p_body,
              p_err_code    => l_err_code,
              p_err_message => l_err_msg);
    log('send_mail_autonomous: Mail sending complete');
  END send_mail_autonomous;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          This function will be used as Rule function for activated business events
  --          for concurrent request
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  04-NOV-2019  Diptasurjya Chatterjee        CHG0045880 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE handle_pl_simulation_cancel(errbuf            OUT NUMBER,
                                        retcode           OUT VARCHAR2,
                                        p_simulation_id   IN NUMBER,
                                        p_request_id      IN number,
                                        p_status          IN varchar2,
                                        p_user_id         IN number,
                                        p_completion_text IN varchar2) IS

    l_user_id  number;
  BEGIN
    errbuf := 0;
    retcode := 'SUCCESS';
    log('handle_pl_simulation_cancel: Inside PL Simulation processor');

    l_user_id := nvl(p_user_id,fnd_global.USER_ID);

    log('handle_pl_simulation_cancel: Start update after cancel of PL simulation program');
    update XXOM_PL_UPD_SIMULATION_HDR xph
       set xph.simulation_status = 'RE-SIMULATE',
           xph.last_updated_by = l_user_id,
           xph.last_update_date = sysdate,
           xph.simulation_status_message = 'Simulation '||nvl(p_completion_text,'Request was cancelled')
     where xph.simulation_status = 'IN_PROCESS'
       and xph.simulation_status_message = 'Simulation in progress'
       and xph.simulation_request_id = nvl(p_request_id,xph.simulation_request_id)
       and xph.simulation_id = nvl(p_simulation_id,xph.simulation_id)
       and p_status = 'X';
    log('handle_pl_simulation_cancel: '||SQL%rowcount||' simulation records updated successfully');
    commit;

    log('handle_pl_simulation_cancel: Start update after cancel of PL upload program');
    update XXOM_PL_UPD_SIMULATION_HDR xph
       set xph.simulation_status = 'APPROVED',
           xph.last_updated_by = l_user_id,
           xph.last_update_date = sysdate,
           xph.simulation_status_message = 'Upload '||nvl(p_completion_text,'Request was cancelled')
     where xph.simulation_status = 'IN_PROCESS'
       and xph.simulation_status_message = 'PL Upload in progress'
       and xph.upload_request_id = nvl(p_request_id,xph.upload_request_id)
       and xph.simulation_id = nvl(p_simulation_id,xph.simulation_id)
       and p_status = 'X';
    log('handle_pl_simulation_cancel: '||SQL%rowcount||' simulation records updated successfully');
    commit;

  EXCEPTION WHEN OTHERS THEN
    errbuf := 2;
    retcode := 'ERROR';
    log('handle_pl_simulation_cancel: ERROR: '||sqlerrm);
    send_mail_autonomous(p_program_name_to => 'XXOMPLUPD_TO',
                         p_program_name_cc => 'XXOMPLUPD_CC',
                         p_subject => 'Request Cancel Event Failure - PL WF Simulation request '||p_request_id,
                         p_body => 'Dear Admin, The business event subscription for PL Simulation request '||p_request_id||' cancellation has encountered errors. Please handle accordingly. ERROR:'||sqlerrm);
  END handle_pl_simulation_cancel;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          This function will be used as Rule function for activated business events
  --          for concurrent request
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  04-NOV-2019  Diptasurjya Chatterjee        CHG0045880 - Initial Build
  -- 1.1  18-NOV-2019  Diptasurjya Chatterjee        INC0175411 - Add cancel status check before calling 
  --                                                 sub programs
  -- --------------------------------------------------------------------------------------------

  FUNCTION conc_request_event_process(p_subscription_guid IN RAW,
              p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2 IS
    l_eventname           VARCHAR2(200);
    l_wf_parameter_list_t wf_parameter_list_t;
    l_concurrent_request_id number;
    l_concurrent_program_id number;
    l_concurrent_program_name varchar2(30);
    l_request_status        varchar2(10);
    l_completion_text       varchar2(2000);

    l_callback_errbuf       varchar2(2000);
    l_callback_retcode      number;

    l_user_id                   NUMBER := 0;
    l_resp_id                   NUMBER := 0;
    l_appl_id                   NUMBER := 0;

  BEGIN
    log('conc_request_event_process: Enter business event rule function ');
    l_eventname := p_event.geteventname();
    l_eventname := p_event.geteventname();
    l_user_id   := p_event.getvalueforparameter('USER_ID');
    l_resp_id   := p_event.getvalueforparameter('RESP_ID');
    l_appl_id   := p_event.getvalueforparameter('RESP_APPL_ID');

    l_concurrent_request_id := p_event.getvalueforparameter('REQUEST_ID');
    l_concurrent_program_id := p_event.getvalueforparameter('CONCURRENT_PROGRAM_ID');
    l_request_status := p_event.getvalueforparameter('STATUS');
    l_completion_text := p_event.getvalueforparameter('COMPLETION_TEXT');

    log('conc_request_event_process: After fetching BE parameters');
    log('conc_request_event_process: Request ID: '||l_concurrent_request_id);
    log('conc_request_event_process: Program ID: '||l_concurrent_program_id);
    log('conc_request_event_process: Request Status: '||l_request_status);
    log('conc_request_event_process: Completion Text: '||l_completion_text);

    select fcp.CONCURRENT_PROGRAM_NAME
      into l_concurrent_program_name
      from fnd_concurrent_programs_vl fcp
     where fcp.CONCURRENT_PROGRAM_ID = l_concurrent_program_id;

    log('conc_request_event_process: Program Name: '||l_concurrent_program_name);

    IF l_eventname = 'oracle.apps.fnd.concurrent.request.completed' THEN
      log('conc_request_event_process: Event Name: oracle.apps.fnd.concurrent.request.completed');
      if l_concurrent_program_name = 'XXOMPLUPD' 
        and nvl(l_concurrent_request_id,0) > 0 
        and l_request_status = 'X' then  -- INC0175411 add cancel status check
        log('conc_request_event_process: program eligible for PL Simulation subscription firing');
        handle_pl_simulation_cancel(errbuf            => l_callback_errbuf,
                                    retcode           => l_callback_retcode,
                                    p_simulation_id   => null,
                                    p_request_id      => l_concurrent_request_id,
                                    p_status          => l_request_status,
                                    p_user_id         => l_user_id,
                                    p_completion_text => l_completion_text);
      end if;
    END IF;

    log('conc_request_event_process: Event processing successful');
    RETURN 'SUCCESS';

  EXCEPTION
    WHEN OTHERS THEN
      log('conc_request_event_process: Event processing error '||sqlerrm);
      wf_core.context('xxfnd_event_pkg',
            'function subscription',
            p_event.geteventname(),
            p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'ERROR');

      RETURN 'ERROR';

  END conc_request_event_process;

END xxfnd_event_pkg;
/
