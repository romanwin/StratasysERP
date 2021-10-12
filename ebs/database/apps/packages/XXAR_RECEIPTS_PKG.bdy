CREATE OR REPLACE PACKAGE BODY "APPS"."XXAR_RECEIPTS_PKG" IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXAR_RECEIPTS_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    12-JAN-2015
  Purpose:         Submits Program "Process Lockboxes" to process Bank LockBox File
                   Programs Called:
                   1. Process Lockboxes --> Custom Program calls this
                   2. Process Lockboxes (Process Lockboxes) --> Program "Process Lockboxes" calls this which eventually creates receipts in AR
  Program Style:   Stored Package BODY
  ---------------------------------------------------------------------------------------------------
  Concurrent : XXAR_RECEIPTS_INBOUND/XX: AR Receipt Creation
  ---------------------------------------------------------------------------------------------------
  Ver   When           Who             Descr
  ----  -------------  -------------   --------------------------------------------------------------
  1.0   12-JAN-2015    Sandeep Akula   Initial Version -- CHG0033827
  2.0   12/10/2020     Roman W.        CHG0048738 - Update Notified User Logic for XX: AR Receipt Creation
  XXAR_NOTIFIED_USER_LIST notf_role1
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE MAIN(errbuf                   OUT VARCHAR2,
                 retcode                  OUT NUMBER,
                 p_bpel_instance_id       IN NUMBER,
                 p_file_name              IN VARCHAR2,
                 p_file_path              IN VARCHAR2,
                 p_transmission_format_id IN NUMBER,
                 p_control_file           IN VARCHAR2,
                 p_lockbox_id             IN NUMBER) IS
  
    ------------------------------
    --    Local Definition
    ------------------------------
    CURSOR xxar_lockbox_notify_cur is
      select flvv.LOOKUP_CODE notf_role
        from FND_LOOKUP_TYPES_VL fltv, FND_LOOKUP_VALUES_VL flvv
       where fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
         and fltv.LOOKUP_TYPE = 'XXAR_LOCKBOX_NOTIFY'
         and flvv.ENABLED_FLAG = 'Y'
         and trunc(sysdate) between
             nvl(flvv.START_DATE_ACTIVE, trunc(sysdate)) and
             nvl(flvv.END_DATE_ACTIVE, trunc(sysdate));
  
    l_instance_name   v$database.name%type;
    l_error_message   varchar2(32767) := '';
    l_request_id      NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    l_prg_exe_counter VARCHAR2(10);
    l_lbx_request_id  NUMBER;
    LBX_SUBMIT_EXCP EXCEPTION;
    LBX_ERROR       EXCEPTION;
    LBX_WARNING     EXCEPTION;
    l_err_code               NUMBER;
    l_err_msg                VARCHAR2(200);
    l_transmission_name      VARCHAR2(300);
    l_transmission_format_ID NUMBER;
    l_lockbox_id             NUMBER;
    l_mail_list              VARCHAR2(2000);
    l_mail_to                VARCHAR2(2000); -- CHG0048738
  
    -- Error Notification Variables
    l_notf_bpel_id   varchar2(100) := '';
    l_notf_file_name varchar2(100) := '';
    l_notf_file_path varchar2(100) := '';
    l_notf_requestor varchar2(200) := '';
    l_notf_subject   varchar2(2000) := '';
    l_notf_data      varchar(32767) := '';
    --l_notf_role1 varchar2(200) := 'NATHAN.JOHNSON';
    --l_notf_role2 varchar2(200) := 'ERIK.MORGAN';
  
    l_completed   BOOLEAN;
    l_phase       VARCHAR2(200);
    l_vstatus     VARCHAR2(200);
    l_dev_phase   VARCHAR2(200);
    l_dev_status  VARCHAR2(200);
    l_message     VARCHAR2(200);
    l_status_code VARCHAR2(1);
  
    -- Variables for Print Options
    l_boolean1     BOOLEAN;
    l_boolean2     BOOLEAN;
    l_printer_name VARCHAR2(100) := 'noprint';
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
  
    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Inside Program');
  
    l_prg_exe_counter := '0';
  
    -- Deriving the Instance Name
  
    l_error_message := 'Instance Name could not be found';
    SELECT NAME INTO l_INSTANCE_NAME FROM V$DATABASE;
  
    l_prg_exe_counter := '1';
  
    /* Getting data elements for Error Notification*/
    l_error_message := 'Error Occured while getting Notification Details for Request ID :' ||
                       l_request_id;
    select trim(substr(argument_text,
                       1,
                       instr(argument_text, ',', 1, 1) - 1)),
           trim(substr(argument_text,
                       instr(argument_text, ',', 1, 1) + 1,
                       instr(argument_text, ',', 1, 2) -
                       instr(argument_text, ',', 1, 1) - 1)),
           trim(substr(argument_text,
                       instr(argument_text, ',', 1, 2) + 1,
                       instr(argument_text, ',', 1, 3) -
                       instr(argument_text, ',', 1, 2) - 1)),
           requestor
      into l_notf_bpel_id,
           l_notf_file_name,
           l_notf_file_path,
           l_notf_requestor
      from fnd_conc_req_summary_v
     where request_id = l_request_id;
  
    l_prg_exe_counter := '2';
  
    l_error_message := 'Error Occured while deriving value for l_notf_data';
    l_notf_data     := 'BPEL Instance ID:' || l_notf_bpel_id || chr(10) ||
                       'LockBox File Name:' || l_notf_file_name || chr(10) ||
                       'File Path:' || l_notf_file_path || chr(10) ||
                       'Requestor:' || l_notf_requestor;
  
    l_prg_exe_counter := '3';
  
    l_error_message     := 'Error Occured while deriving l_transmission_name';
    l_transmission_name := '';
    SELECT trim(substr(p_file_name,
                       instr(p_file_name, '.', 1, 3) + 1,
                       instr(p_file_name, '.', 1, 4) -
                       instr(p_file_name, '.', 1, 3) - 1))
      INTO l_transmission_name
      FROM dual;
  
    l_prg_exe_counter := '4';
  
    l_error_message := 'Error Occured while deriving l_notf_subject';
    l_notf_subject  := '';
    l_notf_subject  := 'LockBox File could be processed for Transmission :' ||
                       l_transmission_name;
  
    l_prg_exe_counter := '5';
  
    /*l_error_message := 'Error Occured while deriving l_transmission_name';
    l_transmission_format_ID := '';
    select transmission_format_ID
    into l_transmission_format_ID
    from ar_transmission_formats
    where format_name = p_transmission_format;
    
    l_prg_exe_counter := '6';
    
    l_error_message := 'Error Occured while deriving l_lockbox_id';
    l_lockbox_id := '';
    select Lockbox_ID
    into l_lockbox_id
    from ar_lockboxes
    where Lockbox_Number = p_lockbox_number; */
  
    l_prg_exe_counter := '8';
  
    /* Rem by Roman W. 12/10/2020 CHG0048738
       
       --Add First Role to Notification and set Notification Options 
     l_error_message := 'Error Occured in fnd_request.add_notification:First';
     l_boolean2 := fnd_request.add_notification (user => l_notf_role1,
                                                 on_normal  => 'Y',
                                                 on_warning => 'Y',
                                                 on_error   => 'Y');
    
      --Add Second Role to Notification and set Notification Options
      l_error_message := 'Error Occured in fnd_request.add_notification:Second';
     l_boolean2 := fnd_request.add_notification (user => l_notf_role2,
                                                 on_normal  => 'Y',
                                                 on_warning => 'Y',
                                                 on_error   => 'Y');
    */
    --Add Role to Notification and set Notification Options -- Added By Roman W. 12/10/2020 CHG0048738
    for xxar_lockbox_notify_ind in xxar_lockbox_notify_cur loop
    
      l_error_message := 'Error Occured in fnd_request.add_notification: ' ||
                         xxar_lockbox_notify_ind.notf_role;
    
      l_boolean2 := fnd_request.add_notification(user       => xxar_lockbox_notify_ind.notf_role,
                                                 on_normal  => 'Y',
                                                 on_warning => 'Y',
                                                 on_error   => 'Y');
    
    end loop;
  
    l_prg_exe_counter := '9';
  
    l_error_message  := 'Error Occured while Calling the Standard LockBox Program';
    l_lbx_request_id := fnd_request.Submit_Request(application => 'AR',
                                                   program     => 'ARLPLB', -- Process Lockboxes
                                                   argument1   => 'Y', -- NEW_TRANSMISSION
                                                   argument2   => NULL, -- LB_TRANSMISSION_ID
                                                   argument3   => NULL, -- ORIG_REQUEST_ID
                                                   argument4   => l_transmission_name, -- TRANSMISSION_NAME
                                                   argument5   => 'Y', -- SUBMIT_IMPORT
                                                   argument6   => p_file_path || '/' ||
                                                                  p_file_name, -- DATA_FILE
                                                   argument7   => p_control_file, -- CNTRL_FILE
                                                   argument8   => p_transmission_format_id, -- TRANSMISSION_FORMAT_ID
                                                   argument9   => 'Y', -- SUBMIT_VALIDATION
                                                   argument10  => 'Y', -- PAY_UNRELATED_INVOICES
                                                   argument11  => p_lockbox_id, -- LOCKBOX_ID
                                                   argument12  => NULL, -- GL_DATE
                                                   argument13  => 'A', -- REPORT_FORMAT
                                                   argument14  => 'N', -- COMPLETE_BATCHES_ONLY
                                                   argument15  => 'N', -- SUBMIT_POSTBATCH
                                                   argument16  => 'N', -- ALTERNATE_NAME_SEARCH
                                                   argument17  => 'Y', -- IGNORE_INVALID_TXN_NUM
                                                   argument18  => NULL, -- USSGL_TRANSACTION_CODE
                                                   argument19  => FND_GLOBAL.ORG_ID, -- ORG_ID
                                                   argument20  => 'N', -- APP_UNEARN_DISC
                                                   argument21  => '1', -- NO_OF_INSTANCES
                                                   argument22  => 'L', -- SUBMISSION_TYPE
                                                   argument23  => NULL -- SCORING_MODEL
                                                   );
    COMMIT;
    l_prg_exe_counter := '10';
  
    IF l_lbx_request_id = 0 THEN
      l_prg_exe_counter := '11';
      RAISE LBX_SUBMIT_EXCP;
    
    ELSE
      l_prg_exe_counter := '12';
      apps.fnd_file.put_line(apps.fnd_file.log,
                             'Submitted the Lockbox concurrent program with request_id :' ||
                             l_lbx_request_id);
    END IF;
  
    COMMIT;
    l_prg_exe_counter := '21';
  
  EXCEPTION
    WHEN LBX_SUBMIT_EXCP THEN
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
                         l_prg_exe_counter || ' - ' || SQLERRM;
      retcode         := '2';
      errbuf          := 'LockBox Program Could not be submitted' ||
                         chr(10) || 'Error Message :' || l_error_message;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                 p_program_short_name => 'XXAR_RECEIPTS_INBOUND');
    
      -- Added By Roman W. 12/10/2020 CHG0048738
      for xxar_lockbox_notify_ind in xxar_lockbox_notify_cur loop
        xxobjt_wf_mail.send_mail_text(p_to_role => l_mail_to, -- Added By Roman W. 12/10/2020 CHG0048738
                                      --p_to_role     => l_notf_role2, -- Rem By Roman W. 12/10/2020 CHG0048738
                                      p_cc_mail     => l_mail_list,
                                      p_subject     => l_notf_subject,
                                      p_body_text   => 'LockBox Program' ||
                                                       ' Submit Exception Failure' ||
                                                       chr(10) || chr(10) ||
                                                       '*******  Technical Details *********' ||
                                                       chr(10) ||
                                                       'XX: AR Receipt Creation Program Request Id :' ||
                                                       l_request_id ||
                                                       chr(10) ||
                                                       'Process Lockboxes Program Request Id :' ||
                                                       l_lbx_request_id ||
                                                       chr(10) ||
                                                       'Exception : LBX_SUBMIT_EXCP' ||
                                                       chr(10) ||
                                                       'Error Message :' ||
                                                       errbuf || chr(10) ||
                                                       '*******  Parameters *********' ||
                                                       chr(10) ||
                                                       l_notf_data,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
        exit;
      end loop;
    
    WHEN OTHERS THEN
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
                         l_prg_exe_counter || ' - ' || SQLERRM;
      FND_FILE.PUT_LINE(FND_FILE.LOG, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                 p_program_short_name => 'XXAR_RECEIPTS_INBOUND');
    
      -- Added by Roman W. 12/10/2020 CHG0048738
      for xxar_lockbox_notify_ind in xxar_lockbox_notify_cur loop
        xxobjt_wf_mail.send_mail_text(p_to_role => xxar_lockbox_notify_ind.notf_role, -- Added By Roman W. 12/10/2020 CHG0048738
                                      -- p_to_role     => l_notf_role2, -- Rem By Roman W. 12/10/2020 CHG0048738
                                      p_cc_mail     => l_mail_list,
                                      p_subject     => l_notf_subject,
                                      p_body_text   => 'XX: AR Receipt Creation Program - Failure' ||
                                                       chr(10) || chr(10) ||
                                                       '*******  Technical Details *********' ||
                                                       chr(10) ||
                                                       'XX: AR Receipt Creation Program Request Id :' ||
                                                       l_request_id ||
                                                       chr(10) ||
                                                       'Process Lockboxes Program Request Id :' ||
                                                       l_lbx_request_id ||
                                                       chr(10) ||
                                                       'Exception : OTHERS' ||
                                                       chr(10) ||
                                                       'Error Message :' ||
                                                       errbuf || chr(10) ||
                                                       '*******  Parameters *********' ||
                                                       chr(10) ||
                                                       l_notf_data,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
        exit;
      end loop;
  END MAIN;
END XXAR_RECEIPTS_PKG;
/
