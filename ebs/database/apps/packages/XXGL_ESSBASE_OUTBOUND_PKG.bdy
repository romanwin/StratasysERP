create or replace PACKAGE BODY APPS.XXGL_ESSBASE_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_ESSBASE_OUTBOUND_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    28-MAY-2015
Purpose:         Send GL Balances to Essbase
Program Style:   Stored Package BODY
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
28-MAY-2015        1.0                  Sandeep Akula    Initial Version (CHG0034720)
---------------------------------------------------------------------------------------------------*/

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    CHECK_ACCOUNT_IN_VALUESET
  Author's Name:   Sandeep Akula
  Date Written:    28-MAY-2015
  Purpose:         This Function checks if the account exists in value set XXGL_ESSBASE_FLIPED_SIGN_ACCOUNTS.
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  28-MAY-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034720
  ---------------------------------------------------------------------------------------------------*/
FUNCTION CHECK_ACCOUNT_IN_VALUESET(p_account IN VARCHAR2)
RETURN VARCHAR2 IS
l_value fnd_flex_values_vl.flex_value%type;
BEGIN

select ffvv.flex_value
into l_value
from fnd_flex_value_sets ffvs,
     fnd_flex_values_vl ffvv
where ffvs.flex_value_set_id = ffvv.flex_value_set_id and
      ffvs.flex_value_set_name = 'XXGL_ESSBASE_FLIPED_SIGN_ACCOUNTS' and
      ffvv.enabled_flag = 'Y' and
      ffvv.flex_value = p_account and 
      trunc(sysdate) between trunc(nvl(start_date_active,sysdate)) and trunc(nvl(end_date_active,sysdate));

RETURN(l_value);

EXCEPTION
WHEN OTHERS THEN
RETURN(NULL);
END CHECK_ACCOUNT_IN_VALUESET;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MAIN
  Author's Name:   Sandeep Akula
  Date Written:    28-MAY-2015
  Purpose:         This Procedure generates GL Balances file for Essbase
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  28-MAY-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034720
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_dir IN VARCHAR2,
               p_balance_type IN VARCHAR2,
               p_period_from IN VARCHAR2,
               p_period_to IN VARCHAR2,
               p_spool_output IN VARCHAR2) IS


CURSOR C_GL_BALANCES IS
select bb.actual_flag|| chr(9) ||
       gcc.segment3 || chr(9) || 
       bb.period_name || chr(9) || 
       gcc.segment2 || chr(9) || 
       gcc.segment5 || chr(9) || 
       gcc.segment6 || chr(9) ||
       gcc.segment7 || chr(9) || 
       gcc.segment1 || chr(9) ||
       /*decode(gcc.segment3,'202010',-1,
                           '101353',-1,
                           '111963',-1,
                           '231125',-1,
                           '231181',-1,
                           '203030',-1,
                           '162100',-1,
                           '203020',-1,
                           '161110',-1,
                           '199000',-1,
                           '199100',-1,
                           '190000',-1,
                           '111962',-1,
                           '111960',-1,
                           '252110',-1,
                           '185112',-1,
                           '141122',-1,
                           '231140',-1,1) **/
       decode(gcc.segment3,xxgl_essbase_outbound_pkg.check_account_in_valueset(gcc.segment3),-1,1) *                  
       (sum(decode(gcc.account_type, 'R', -1, 'L', decode(actual_flag,'A', -1,1), 'O', -1, 1) *
            (nvl(bb.period_net_dr, 0) - nvl(bb.period_net_cr, 0) +
             decode(gcc.segment3,
                    '632500',
                    0,
                    decode(gcc.account_type,
                           'R',
                           0,
                           'E',
                           0,
                           nvl(bb.begin_balance_dr, 0) -
                           nvl(bb.begin_balance_cr, 0)))))) amt,
       bb.period_name,
       bb.period_year, -- Added Column 04/07/2015 SAkula CHG0035062
       bb.period_num,  -- Added Column 04/07/2015 SAkula CHG0035062
       bb.actual_flag
/* sum(nvl(bb.period_net_dr, 0) - nvl(bb.period_net_cr, 0) +
nvl(bb.begin_balance_dr, 0) - nvl(bb.begin_balance_cr, 0))*/
from gl_code_combinations gcc, gl_balances bb, gl_ledgers gl
where bb.code_combination_id = gcc.code_combination_id
      -- and bb.period_name = 'MAR-14'
   --and bb.actual_flag = 'A'
   and gl.ledger_id = bb.ledger_id
   and gcc.summary_flag = 'N'
   and bb.currency_code = 'USD'
   and gl.currency_code = 'USD'
   and bb.actual_flag IN (SELECT * FROM TABLE(xx_in_list(p_balance_type))) 
   and bb.period_year >= TO_NUMBER(SUBSTR(p_period_from,5,4))
   and bb.period_num >= CASE WHEN SUBSTR(p_period_from,1,3) = 'ADJ' THEN 13 ELSE TO_NUMBER(TO_CHAR(TO_DATE(SUBSTR(p_period_from,1,3),'MONTH'),'MM')) END
   and bb.period_year <= TO_NUMBER(SUBSTR(p_period_to,5,4))
   and bb.period_num <= CASE WHEN SUBSTR(p_period_to,1,3) = 'ADJ' THEN 13 ELSE TO_NUMBER(TO_CHAR(TO_DATE(SUBSTR(p_period_to,1,3),'MONTH'),'MM')) END
   and (bb.actual_flag<>'B' or exists(select 1
                                      from gl_budget_versions gbv
                                      where gbv.budget_version_id=bb.budget_version_id
                                      and gbv.status='C'))
group by bb.actual_flag|| chr(9) || gcc.segment3 || chr(9) || bb.period_name || chr(9) ||
          gcc.segment2 || chr(9) || gcc.segment5 || chr(9) || gcc.segment6 ||
          chr(9) || gcc.segment7 || chr(9) || gcc.segment1,
          gcc.segment1,
          gcc.segment3,
          bb.period_name,
          bb.period_year, -- Added Column 04/07/2015 SAkula CHG0035062
          bb.period_num, -- Added Column 04/07/2015 SAkula CHG0035062
          bb.actual_flag 
--having /*sum(nvl(bb.period_net_dr, 0) - nvl(bb.period_net_cr, 0) +
--nvl(bb.begin_balance_dr, 0) - nvl(bb.begin_balance_cr, 0))*/
--sum(nvl(bb.period_net_dr, 0) - nvl(bb.period_net_cr, 0) + decode(gcc.account_type, 'R', 0, 'E', 0, nvl(bb.begin_balance_dr, 0) - nvl(bb.begin_balance_cr, 0))) != 0
order by gcc.segment1;


file_handle               UTL_FILE.FILE_TYPE;
l_instance_name   v$database.name%type;
l_programid       NUMBER := apps.fnd_global.conc_program_id ;
l_request_id      NUMBER:= fnd_global.conc_request_id;
l_prog            fnd_concurrent_programs_vl.user_concurrent_program_name%type;
l_sysdate         VARCHAR2(100);
l_file_creation_date VARCHAR2(100);
l_count           NUMBER := '';
l_prg_exe_counter        NUMBER := '';
l_file_name              VARCHAR2(200) := '';
l_error_message          varchar2(32767) := '';
l_mail_list VARCHAR2(500);
l_err_code  NUMBER;
l_err_msg   VARCHAR2(200);
FILE_RENAME_EXCP EXCEPTION;
l_insert_msg VARCHAR2(32767) := '';
l_dir_statement VARCHAR2(1000);

-- Error Notification Variables
l_notf_requestor varchar2(200) := '';
l_notf_data varchar(32767) := '';
l_notf_program_short_name varchar2(100) := '';

BEGIN

 l_prg_exe_counter := '0';

  /* Getting data elements for Error Notification*/
l_error_message := 'Error Occured while getting Notification Details for Request ID :'||l_request_id;
begin
select requestor,program_short_name
into l_notf_requestor,l_notf_program_short_name
from fnd_conc_req_summary_v
where request_id = l_request_id;
exception
when others then
null;
end;

l_prg_exe_counter := '1';

l_notf_data := 'Balance Type:'||p_balance_type||chr(10)||
               'Period From:'||p_period_from||chr(10)||
               'Period To:'||p_period_to||chr(10)||
               'Spool Output:'||p_spool_output;

l_prg_exe_counter := '2';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;
                   
l_prg_exe_counter := '3';
   
l_error_message := 'Error Occured while executing dynamic SQL for directory creation';     
l_dir_statement := 'CREATE OR REPLACE DIRECTORY XXGL_ESSBASE_BALANCES_OUT_DIR AS '||''''||p_dir||'''';

l_prg_exe_counter := '3.1';        

l_error_message := 'Error Occured while performing EXECUTE IMMEDIATE';
BEGIN
EXECUTE IMMEDIATE l_dir_statement;
END;

l_prg_exe_counter := '3.2';  
        

IF p_spool_output = 'Y' THEN

l_count := '0';
l_error_message := 'Error Occured While Opening Cursor c_gl_balances';
FOR c_1 IN c_gl_balances LOOP
l_prg_exe_counter := '4';

l_error_message   := 'Error Occured in FND_FILE.OUTPUT';
FND_FILE.PUT_LINE(FND_FILE.OUTPUT,c_1.amt);

      l_prg_exe_counter := '5';
      l_count := l_count + 1;  -- Count of Records

END LOOP;

IF l_count > '0' THEN
l_prg_exe_counter := '5.1';

         -- Log File

        FND_FILE.PUT_LINE(FND_FILE.LOG,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.LOG,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.LOG,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.LOG,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID: ' || L_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'p_balance_type   :'||p_balance_type);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'p_period_from   :'||p_period_from);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'p_period_to   :'||p_period_to);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'p_spool_output   :'||p_spool_output);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Directory Path is : ' ||p_dir) ;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'No File Created as Spool Output is set to Y');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'----------------------------------------------');
        l_prg_exe_counter := '5.2';

END IF;

l_prg_exe_counter := '5.3';

ELSE

l_file_name:= '';
l_error_message := ' Error Occured while Deriving l_file_name';
l_file_name := 'EssbaseHourlyLoad'||'.txt.tmp';  -- Creating file with .tmp extension so that BPEL cannot process the file
l_prg_exe_counter := '4';

 -- File Handle for Outbound File
 l_error_message := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
FILE_HANDLE  := UTL_FILE.FOPEN('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name,'W',32767);
l_prg_exe_counter := '5';
l_count := '0';

l_error_message := 'Error Occured While Opening Cursor c_gl_balances';
FOR c_1 IN c_gl_balances LOOP
l_prg_exe_counter := '6';

l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
UTL_FILE.PUT_LINE(FILE_HANDLE,c_1.amt);

      l_prg_exe_counter := '7';
      l_count := l_count + 1;  -- Count of Records

END LOOP;

l_prg_exe_counter := '8';

IF l_count > '0' THEN
l_prg_exe_counter := '9';

         -- Log File

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Request ID: ' || L_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||p_dir) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_balance_type   :'||p_balance_type);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_period_from   :'||p_period_from);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_period_to   :'||p_period_to);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_spool_output   :'||p_spool_output);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||p_dir) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Temp File Name is : '||l_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'The File Name is : '||substr(l_file_name,0,length(l_file_name)-4));      
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Record Count is : '||(l_count));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'----------------------------------------------');
        l_prg_exe_counter := '10';

   l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
         l_prg_exe_counter := '11';
         
-- Renaming the file name so that BPEL Processes the File 
BEGIN
          l_prg_exe_counter := '12';
          UTL_FILE.frename('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name,'XXGL_ESSBASE_BALANCES_OUT_DIR',substr(l_file_name,0,length(l_file_name)-4),TRUE);
EXCEPTION
WHEN OTHERS THEN
l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while Renaming the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
RAISE FILE_RENAME_EXCP;
END;
        
l_prg_exe_counter := '12.1';

ELSE
l_prg_exe_counter := '13';
 l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
l_prg_exe_counter := '14';
 BEGIN
          l_prg_exe_counter := '15';
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;

l_prg_exe_counter := '16';
END IF;
l_prg_exe_counter := '17';

END IF; -- MAIN END IF 

EXCEPTION
WHEN NO_DATA_FOUND THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'NO_DATA_FOUND Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.INVALID_PATH THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'UTL_FILE.INVALID_PATH Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.READ_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'UTL_FILE.READ_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.WRITE_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'UTL_FILE.WRITE_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN FILE_RENAME_EXCP THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : FILE_RENAME_EXCP - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : FILE_RENAME_EXCP - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'FILE_RENAME_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);                              
WHEN OTHERS THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove ('XXGL_ESSBASE_BALANCES_OUT_DIR',l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGL_ESSBASE_BALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Essbase'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_from||' AND '||p_period_to||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END MAIN;
END XXGL_ESSBASE_OUTBOUND_PKG;
/

