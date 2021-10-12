CREATE OR REPLACE PACKAGE BODY XXGL_BALANCES_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_BALANCES_OUTBOUND_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    28-JULY-2014
Purpose:         Send GL Balances to Blackline for Account Reconciliation
Program Style:   Stored Package BODY
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
28-JULY-2014        1.0                  Sandeep Akula    Initial Version (CHG0032798)
17-NOV-2014         1.1                  Sandeep Akula    Added Procedure SUBLEDGER_MAIN (CHG0033074)
15-DEC-2014         1.1                  Sandeep Akula    Modified Cursor C_GL_BALANCES sql in Procedure MAIN-- CHG0034095
27-MAR-2015         1.2                  mmazanet         CHG0034887.  See changes in main and subledger procedures comments
10-JUL-2018         1.3                  Bellona(TCS)     CHG0042900-Remove Company`s from the Blackline Outbound Extract
---------------------------------------------------------------------------------------------------*/
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    INSERT_GL_BAL_RUNTIME_DATA
  Author's Name:   Sandeep Akula
  Date Written:    28-JULY-2014
  Purpose:         This Procedure Inserts GL balances program run time data into Custom Table
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  28-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032798
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE INSERT_GL_BAL_RUNTIME_DATA(P_SOURCE IN VARCHAR2,
P_REQUEST_ID IN NUMBER,
P_PROGRAM_SHORT_NAME IN VARCHAR2,
P_REQUESTER IN VARCHAR2 DEFAULT NULL,
P_FILE_NAME IN VARCHAR2 DEFAULT NULL,
P_EXTRACT_DATE IN VARCHAR2 DEFAULT NULL,
P_LINES_EXTRACTED IN NUMBER DEFAULT NULL,
P_FILE_DIRECTORY IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE1 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE2 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE3 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE4 IN VARCHAR2 DEFAULT NULL,
P_OUT_MSG OUT VARCHAR2) IS
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

begin
INSERT INTO XXGL_BALANCES_STAGING
  ( SEQUENCE_NUMBER,
    SOURCE,
    PROGRAM_SHORT_NAME,
    REQUEST_ID,
    REQUESTER,
    EXTRACT_DATE,
    LINES_EXTRACTED,
    FILE_DIRECTORY,
    FILE_NAME,
    CREATION_DATE,
    CREATED_BY,
    LAST_UPDATE_DATE,
    LAST_UPDATED_BY,
    ATTRIBUTE1,
    ATTRIBUTE2,
    ATTRIBUTE3,
    ATTRIBUTE4
  )
  VALUES
  ( XXGL_BALANCES_SEQ.NEXTVAL,
    P_SOURCE,
    P_PROGRAM_SHORT_NAME,
    P_REQUEST_ID,
    P_REQUESTER,
    P_EXTRACT_DATE,
    P_LINES_EXTRACTED,
    P_FILE_DIRECTORY,
    P_FILE_NAME,
    SYSDATE,
    FND_GLOBAL.USER_ID,
    SYSDATE,
    FND_GLOBAL.USER_ID,
    P_ATTRIBUTE1,
    P_ATTRIBUTE2,
    P_ATTRIBUTE3,
    P_ATTRIBUTE4
  );

P_OUT_MSG := NULL;

EXCEPTION
WHEN OTHERS THEN
FND_FILE.PUT_LINE(FND_FILE.LOG,'Error Occured while loading data in the staging table. Error is :'||SQLERRM);
P_OUT_MSG := 'Error Occured while loading data in the staging table. Error is :'||SQLERRM;
END;

COMMIT;

END INSERT_GL_BAL_RUNTIME_DATA;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MAIN
  Author's Name:   Sandeep Akula
  Date Written:    28-JULY-2014
  Purpose:         This Procedure generates GL Balances file for Blackline
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  28-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032798
  15-DEC-2014         1.1                  Sandeep Akula     Modified Cursor C_GL_BALANCES sql -- CHG0034095
  27-MAR-2015         1.2                  mmazanet          CHG0034887.  replaced hard-coded statement...
                                                                AND gl_books.NAME  = 'Stratasys US'
                                                             ...with a lookup (lookup_type = 'XXGL_BALANCES_OUT_BOOKS')
                                                             since we now look at multiple gl_books.
  10-JUL-2018         1.3                  Bellona(TCS)      CHG0042900-Remove Company`s from the Blackline Outbound Extract															 
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_data_dir IN VARCHAR2,
               p_period_name IN VARCHAR2) IS

-- Cursor SQL Taken from Dwayne Zona Design Document
CURSOR C_GL_BALANCES(cp_period_name IN VARCHAR2) IS
SELECT
  gl_combos.SEGMENT1 as entity,
  gl_combos.SEGMENT3 as account,
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT2 else null end as department, -- Commented  12/15/2014 SAkula (CHG0034095)
  null as department, -- Added Column 12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT4, -- subaccount  -- Commented  12/15/2014 SAkula (CHG0034095)
  null as segment4, -- Added Column 12/15/2014 SAkula (CHG0034095)
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT5 else null end as product, -- Commented  12/15/2014 SAkula (CHG0034095)
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT6 else null end as location,  -- Commented  12/15/2014 SAkula (CHG0034095)
  null as product, -- Added Column 12/15/2014 SAkula (CHG0034095)
  null as location, -- Added Column 12/15/2014 SAkula (CHG0034095)
  gl_combos.SEGMENT7 as intercompany,
  --gl_combos.SEGMENT8,  -- project -- Commented  12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT9 as future1, -- Commented  12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT10 as future2, -- Commented  12/15/2014 SAkula (CHG0034095)
  null as segment8, -- Added Column 12/15/2014 SAkula (CHG0034095)
  null as future1, -- Added Column 12/15/2014 SAkula (CHG0034095)
  null as future2, -- Added Column 12/15/2014 SAkula (CHG0034095)
  replace(valu_tl.DESCRIPTION,chr(9),'') DESCRIPTION,
  NULL AS AccountReference,
  case when  gl_combos.ACCOUNT_TYPE in ('A', 'L', 'O', 'R') then 'A' else 'I' end AS FinancialStatement,
  DECODE (gl_combos.ACCOUNT_TYPE, 'A','Asset','L', 'Liability', 'Q', 'Equity', 'R', 'Revenue', 'E', 'Expense', NULL) as AccountType,
  'TRUE' AS ActiveAccount,
  DECODE ((ABS(sum(gl_balances.PERIOD_NET_CR)) + ABS(sum(gl_balances.PERIOD_NET_DR))), 0, 'FALSE', 'TRUE') AS ActivityInPeriod,
  /*Insert Field for Functional Currency*/ null AS Currency_Func,
  gl_balances.CURRENCY_CODE AS Currency_Acct,
  to_char((select end_Date from gl_periods
                where period_set_name = 'OBJET_CALENDAR'
                and period_name = cp_period_name),'MM/DD/YYYY') as PeriodEndDate,
  /*Insert Field for Reporting Currency Balance*/ null as RptCurBal,
  /*Insert Field for Functional Currency Balance*/ null as FunctCurBal,
  sum((gl_balances.BEGIN_BALANCE_DR + gl_balances.PERIOD_NET_DR - gl_balances.BEGIN_BALANCE_CR - gl_balances.PERIOD_NET_CR)) AccountBalance
FROM
  GL_BALANCES gl_balances,
  GL_CODE_COMBINATIONS gl_combos,
  GL_ledgers gl_books,
  APPLSYS.FND_FLEX_VALUES valu,
  APPLSYS.FND_FLEX_VALUES_TL valu_tl,
  -- Added for CHG0034887
  fnd_lookup_values_vl      ffv
WHERE gl_balances.CODE_COMBINATION_ID = gl_combos.CODE_COMBINATION_ID
  AND gl_combos.SUMMARY_FLAG = 'N'
  AND valu.FLEX_VALUE_SET_ID = '1020162' -- XXGL_ACCOUNT_SS
  AND valu.FLEX_VALUE_ID = valu_tl.FLEX_VALUE_ID
  and valu_tl.language = 'US'
  AND gl_combos.SEGMENT3 = valu.FLEX_VALUE
  -- Added for CHG0034887
  AND ffv.lookup_type     = 'XXGL_BALANCES_OUT_BOOKS'
  AND ffv.enabled_flag    =  'Y'
  AND ffv.meaning         = gl_books.NAME
  AND gl_books.ledger_id = gl_balances.ledger_ID
  AND gl_balances.PERIOD_NAME = cp_period_name
  AND gl_balances.CURRENCY_CODE = 'USD'
  AND gl_balances.ACTUAL_FLAG = 'A'
  -- Added for CHG0042900
  AND NOT exists( select 1 from fnd_lookup_values_vl      ffv1
  where 1=1
  AND ffv1.lookup_type     = 'XXGL_BLACKLINE_OUTBOUND'
  AND ffv1.enabled_flag    =  'Y'
  AND gl_combos.SEGMENT1   = ffv1.meaning )  
GROUP BY
  gl_combos.SEGMENT1,
  gl_combos.SEGMENT3,
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT2 else null end,  -- Commented  12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT4,  -- Commented  12/15/2014 SAkula (CHG0034095)
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT5 else null end,  -- Commented  12/15/2014 SAkula (CHG0034095)
  --case when gl_combos.ACCOUNT_TYPE in ('R', 'E') then SEGMENT6 else null end, -- Commented  12/15/2014 SAkula (CHG0034095)
  gl_combos.SEGMENT7,
  --gl_combos.SEGMENT8,  -- Commented  12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT9,  -- Commented  12/15/2014 SAkula (CHG0034095)
  --gl_combos.SEGMENT10,  -- Commented  12/15/2014 SAkula (CHG0034095)
  valu_tl.DESCRIPTION,
  case when gl_combos.ACCOUNT_TYPE in ('A', 'L', 'O', 'R') then 'A' else 'I' end,
  DECODE (gl_combos.ACCOUNT_TYPE, 'A','Asset','L', 'Liability', 'Q', 'Equity', 'R', 'Revenue', 'E', 'Expense', NULL),
  gl_balances.CURRENCY_CODE
ORDER BY segment1, segment3,segment7;


file_handle               UTL_FILE.FILE_TYPE;
l_instance_name   v$database.name%type;
l_directory       VARCHAR2(2000);
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

-- Added Variables SAkula 07/23/2014 (CHG0032820)
-- Error Notification Variables
l_notf_data_directory varchar2(500) := '';
l_notf_period_name varchar2(100) := '';
l_notf_requestor varchar2(200) := '';
l_notf_data varchar(32767) := '';
l_notf_program_short_name varchar2(100) := '';

BEGIN

 l_prg_exe_counter := '0';

  /* Getting data elements for Error Notification*/
l_error_message := 'Error Occured while getting Notification Details for Request ID :'||l_request_id;
begin
select trim(substr(argument_text,1,instr(argument_text,',',1,1)-1)) data_directory,
trim(substr(argument_text,instr(argument_text,',',1,1)+1)) period_name,
requestor,
program_short_name
into l_notf_data_directory,l_notf_period_name,l_notf_requestor,l_notf_program_short_name
from fnd_conc_req_summary_v
where request_id = l_request_id;
exception
when others then
null;
end;

l_prg_exe_counter := '1';

l_notf_data := 'Data Directory:'||l_notf_data_directory||chr(10)||
               'Period Name:'||l_notf_period_name||chr(10)||
               'Requestor:'||l_notf_requestor;

l_prg_exe_counter := '2';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;


                      -- Deriving the Directory Path

                       l_error_message := 'Directory Path Could not be Found';
                        SELECT p_data_dir
                        INTO  l_DIRECTORY
                        FROM DUAL;

        l_prg_exe_counter := '3';

l_file_name:= '';
l_error_message := ' Error Occured while Deriving l_file_name';
l_file_name := 'BL_ACCT_BAL_'||P_PERIOD_NAME||'_'||to_char(sysdate,'MMDDRRRRHH24MISS')||'.txt.tmp';  -- Creating file with .tmp extension so that BPEL cannot process the file
l_prg_exe_counter := '4';

 -- File Handle for Outbound File
 l_error_message := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
FILE_HANDLE  := UTL_FILE.FOPEN(l_DIRECTORY,l_file_name,'W',32767);
l_prg_exe_counter := '5';
l_count := '0';

l_error_message := 'Error Occured While Opening Cursor c_gl_balances';
for c_1 in c_gl_balances(p_period_name) loop
l_prg_exe_counter := '6';

l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
UTL_FILE.PUT_LINE(FILE_HANDLE,c_1.entity||CHR(9)|| -- Entity Unique Identifier
c_1.account||CHR(9)||                              -- Account Number
c_1.department||CHR(9)||                           -- key3
c_1.segment4||CHR(9)||                             -- key4
c_1.product||CHR(9)||                              -- key5
c_1.location||CHR(9)||                             -- key6
c_1.intercompany||CHR(9)||                         -- key7
c_1.segment8||CHR(9)||                             -- key8
c_1.future1||CHR(9)||                              -- key9
c_1.future2||CHR(9)||                              -- key10
c_1.description||CHR(9)||                          -- Account Description
c_1.AccountReference||CHR(9)||                     -- Account Reference
c_1.FinancialStatement||CHR(9)||                   -- Financial Statement
c_1.AccountType||CHR(9)||                          -- Account Type
c_1.ActiveAccount||CHR(9)||                        -- Active Account
c_1.ActivityInPeriod||CHR(9)||                     -- Activity In Period
c_1.Currency_Func||CHR(9)||                        -- Functional Currency
c_1.Currency_Acct||CHR(9)||                        -- Account Currency
c_1.PeriodEndDate||CHR(9)||                        -- Period End Date
c_1.RptCurBal||CHR(9)||                            -- GL Reporting Balance
c_1.FunctCurBal||CHR(9)||                          -- GL Functional Balance
c_1.AccountBalance                              -- GL Account Balance
);

      l_prg_exe_counter := '7';
      l_count := l_count + 1;  -- Count of Records

END LOOP;
l_prg_exe_counter := '8';

IF l_count > '0' THEN
l_prg_exe_counter := '9';

l_insert_msg := '';
l_error_message := 'Error Occured while calling procedure INSERT_GL_BAL_RUNTIME_DATA';
-- Loading data into Custom staging table
INSERT_GL_BAL_RUNTIME_DATA(P_SOURCE => 'BLACKLINE',
                           P_REQUEST_ID => l_request_id,
                           P_PROGRAM_SHORT_NAME => l_notf_program_short_name,
                           P_REQUESTER => l_notf_requestor,
                           P_FILE_NAME => l_file_name,
                           P_EXTRACT_DATE => TO_CHAR(SYSDATE,'MM/DD/RRRR'),
                           P_LINES_EXTRACTED => l_count,
                           P_FILE_DIRECTORY => p_data_dir,
                           P_OUT_MSG => l_insert_msg);

l_prg_exe_counter := '10';

IF l_insert_msg IS NOT NULL THEN
l_prg_exe_counter := '10.1';
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound INSERT TABLE Failure for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

END IF;


  l_prg_exe_counter := '10.2';
         -- Output File

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Request ID: ' || L_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||l_DIRECTORY) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_data_dir   :'||p_data_dir);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_period_name   :'||p_period_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Temp File Name is : '||l_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'The File Name is : '||substr(l_file_name,0,length(l_file_name)-4));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Record Count is : '||(l_count));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'----------------------------------------------');
        l_prg_exe_counter := '11';

   l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
         l_prg_exe_counter := '12';

-- Renaming the file name so that BPEL Processes the File
BEGIN
          l_prg_exe_counter := '12.1';
          UTL_FILE.frename(l_DIRECTORY,l_file_name,l_DIRECTORY,substr(l_file_name,0,length(l_file_name)-4),TRUE);
EXCEPTION
WHEN OTHERS THEN
l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while Renaming the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
RAISE FILE_RENAME_EXCP;
END;

l_prg_exe_counter := '12.2';

ELSE
l_prg_exe_counter := '13';
 l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
l_prg_exe_counter := '14';
 BEGIN
          l_prg_exe_counter := '15';
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLBALOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL Balances Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL Balances Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL Balances file for Period :'||p_period_name||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL Balances Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END MAIN;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    SUBLEDGER_MAIN
  Author's Name:   Sandeep Akula
  Date Written:    17-NOV-2014
  Purpose:         This Procedure generates GL SubLedger Activity file for Blackline
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-NOV-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033074
  27-MAR-2015        1.1                  mmazanet          CHG0034887.  replaced hard-coded statement...
                                                                and l.name = 'Stratasys US'
                                                             ...with a lookup (lookup_type = 'XXGL_BALANCES_OUT_BOOKS')
                                                             since we now look at multiple gl_books.
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE SUBLEDGER_MAIN(errbuf OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_data_dir IN VARCHAR2,
                         p_period_name IN VARCHAR2) IS

-- Cursor SQL Taken from Dwayne Zona Design Document
CURSOR C_SUBLEDGER_DATA(cp_period_name IN VARCHAR2) IS
SELECT
cc.segment1 as Company,
cc.segment3 as Account,
--case when cc.ACCOUNT_TYPE = 'R' then SEGMENT2 else null end as department, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
null as department, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
--cc.segment4, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
null as segment4, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
--case when cc.ACCOUNT_TYPE = 'R' then SEGMENT5 else null end as product,  -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
--case when cc.ACCOUNT_TYPE = 'R' then SEGMENT6 else null end as location,  -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
null as product, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
null as location, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
cc.segment7 as intercompany,
--SEGMENT8, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
null as segment8, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
--cc.SEGMENT9 as future1, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
--cc.SEGMENT10 as future2, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
null as future1, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
null as future2, -- Added as per Dwayne's Latest Code 12/12/2014 SAkula
app.application_name as source,
'Balance_subledger' as Balance_Type,
to_char((select end_Date
         from gl_periods
         where period_set_name = 'OBJET_CALENDAR'
         and period_name = cp_period_name),'MM/DD/YYYY') as PeriodEndDate,
null as alternate_balance,
null as reporting_balance,
sum(nvl(xal.accounted_dr,0)) - sum(nvl(xal.accounted_cr,0)) as account_balance,
sum(nvl(xal.entered_dr,0)) - sum(nvl(xal.entered_cr,0)) as amount,
xal.currency_code
FROM FND_APPLICATION_TL app,
     xla_ae_headers xah,
     xla_ae_lines xal,
     gl_code_combinations cc,
     gl_ledgers l,
     -- Added for CHG0034887
     fnd_lookup_values_vl      ffv
WHERE
xah.application_id = app.application_id
and language = 'US'
and xal.ae_header_id = xah.ae_header_id
and xal.application_id = xah.application_id
and xal.code_combination_id = cc.code_combination_id
--and gl_transfer_status_code = 'Y'
and accounting_entry_status_code = 'F'
and balance_type_code = 'A'
and  ( (cc.ACCOUNT_TYPE in ('A', 'L', 'O') and xah.period_name in  (select y.period_name from gl_periods X, gl_periods Y
                                                                    where x.period_set_name = 'OBJET_CALENDAR'
                                                                      and x.period_set_name = y.period_set_name
                                                                      and x.period_name = cp_period_name -- Period Parameter
                                                                      and x.end_date >= y.end_Date
                                                                      and y.end_Date >= '31-DEC-2013')) -- life to date for balance sheet
  or   (cc.ACCOUNT_TYPE = 'R'             and xah.period_name in (select y.period_name from gl_periods X, gl_periods Y
                                                                    where x.period_set_name = 'OBJET_CALENDAR'
                                                                      and x.period_set_name = y.period_set_name
                                                                      and x.period_name = cp_period_name -- Period Parameter
                                                                      and x.period_year = y.period_year
                                                                      and x.period_num >= y.period_num)) ) -- current year for income statement
and xah.ledger_id = l.ledger_id
-- Added for CHG0034887
AND ffv.lookup_type     = 'XXGL_BALANCES_OUT_BOOKS'
AND ffv.enabled_flag    =  'Y'
AND ffv.meaning         = l.name
and cc.segment3 in (SELECT flvv.lookup_code
                    FROM FND_LOOKUP_TYPES_VL fltv,
                         FND_LOOKUP_VALUES_VL flvv
                    WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
                      AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
                      AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
                      AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_BL_SUBLEDGER_EXTR'  -- LookUp Name
                      AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE)))
GROUP BY app.application_name,
         cc.segment1,
         cc.segment3,
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT2 else null end, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --cc.segment4, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT5 else null end,    -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT6 else null end,  -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         cc.segment7,
         --SEGMENT8, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --SEGMENT9, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         -- SEGMENT10, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         xal.currency_code
ORDER BY cc.segment1,
         cc.segment3,
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT2 else null end, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT5 else null end,   -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --case when cc.ACCOUNT_TYPE = 'R' then SEGMENT6 else null end,  -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         cc.segment7,
         --cc.SEGMENT8, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --cc.SEGMENT9, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         --cc.SEGMENT10, -- Commented as per Dwayne's Latest Code 12/12/2014 SAkula
         currency_code,
         app.application_name;



file_handle               UTL_FILE.FILE_TYPE;
l_instance_name   v$database.name%type;
l_directory       VARCHAR2(2000);
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

-- Error Notification Variables
l_notf_data_directory varchar2(500) := '';
l_notf_period_name varchar2(100) := '';
l_notf_requestor varchar2(200) := '';
l_notf_data varchar(32767) := '';
l_notf_program_short_name varchar2(100) := '';

BEGIN

 l_prg_exe_counter := '0';

  /* Getting data elements for Error Notification*/
l_error_message := 'Error Occured while getting Notification Details for Request ID :'||l_request_id;
begin
select trim(substr(argument_text,1,instr(argument_text,',',1,1)-1)) data_directory,
trim(substr(argument_text,instr(argument_text,',',1,1)+1)) period_name,
requestor,
program_short_name
into l_notf_data_directory,l_notf_period_name,l_notf_requestor,l_notf_program_short_name
from fnd_conc_req_summary_v
where request_id = l_request_id;
exception
when others then
null;
end;

l_prg_exe_counter := '1';

l_notf_data := 'Data Directory:'||l_notf_data_directory||chr(10)||
               'Period Name:'||l_notf_period_name||chr(10)||
               'Requestor:'||l_notf_requestor;

l_prg_exe_counter := '2';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;


                      -- Deriving the Directory Path

                       l_error_message := 'Directory Path Could not be Found';
                        SELECT p_data_dir
                        INTO  l_DIRECTORY
                        FROM DUAL;

        l_prg_exe_counter := '3';

l_file_name:= '';
l_error_message := ' Error Occured while Deriving l_file_name';
l_file_name := 'BL_SUBLGR_'||P_PERIOD_NAME||'_'||to_char(sysdate,'MMDDRRRRHH24MISS')||'.txt.tmp';  -- Creating file with .tmp extension so that BPEL cannot process the file
l_prg_exe_counter := '4';

 -- File Handle for Outbound File
 l_error_message := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
FILE_HANDLE  := UTL_FILE.FOPEN(l_DIRECTORY,l_file_name,'W',32767);
l_prg_exe_counter := '5';
l_count := '0';

l_error_message := 'Error Occured While Opening Cursor c_gl_balances';
for c_1 in c_subledger_data(p_period_name) loop
l_prg_exe_counter := '6';

l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
UTL_FILE.PUT_LINE(FILE_HANDLE,c_1.company||CHR(9)||  -- Entity Unique Identifier (Company Segment)
c_1.account||CHR(9)||                              -- Account Segment
c_1.department||CHR(9)||                           -- Department Segment
c_1.segment4||CHR(9)||                             -- Segment4 (Currently not used in Stratasys COA)
c_1.product||CHR(9)||                              -- Product Segment
c_1.location||CHR(9)||                             -- Location Segment
c_1.intercompany||CHR(9)||                         -- Intercompany Segment
c_1.segment8||CHR(9)||                             -- Segment8 (Currently not used in Stratasys COA)
c_1.future1||CHR(9)||                              -- Future Segment
c_1.future2||CHR(9)||                              -- FUTURE(DIVISION) Segment
c_1.source||CHR(9)||                               -- Source Application
c_1.balance_type||CHR(9)||                         -- Balance Type
c_1.periodenddate||CHR(9)||                        -- Period End Date
c_1.alternate_balance||CHR(9)||                    -- Alternate Balance
c_1.reporting_balance||CHR(9)||                    -- Reporting Balance
c_1.account_balance||CHR(9)||                      -- Account Balance
c_1.amount||CHR(9)||                               -- Amount
c_1.currency_code                                  -- Currency Code
);

      l_prg_exe_counter := '7';
      l_count := l_count + 1;  -- Count of Records

END LOOP;
l_prg_exe_counter := '8';

IF l_count > '0' THEN
l_prg_exe_counter := '9';

l_insert_msg := '';
l_error_message := 'Error Occured while calling procedure INSERT_GL_BAL_RUNTIME_DATA';
-- Loading data into Custom staging table
INSERT_GL_BAL_RUNTIME_DATA(P_SOURCE => 'BLACKLINE_SUBLEDGER',
                           P_REQUEST_ID => l_request_id,
                           P_PROGRAM_SHORT_NAME => l_notf_program_short_name,
                           P_REQUESTER => l_notf_requestor,
                           P_FILE_NAME => l_file_name,
                           P_EXTRACT_DATE => TO_CHAR(SYSDATE,'MM/DD/RRRR'),
                           P_LINES_EXTRACTED => l_count,
                           P_FILE_DIRECTORY => p_data_dir,
                           P_OUT_MSG => l_insert_msg);

l_prg_exe_counter := '10';

IF l_insert_msg IS NOT NULL THEN
l_prg_exe_counter := '10.1';
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound INSERT TABLE Failure for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

END IF;


  l_prg_exe_counter := '10.2';
         -- Output File

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Request ID: ' || L_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||l_DIRECTORY) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_data_dir   :'||p_data_dir);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_period_name   :'||p_period_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Temp File Name is : '||l_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'The File Name is : '||substr(l_file_name,0,length(l_file_name)-4));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Record Count is : '||(l_count));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'----------------------------------------------');
        l_prg_exe_counter := '11';

   l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
         l_prg_exe_counter := '12';

-- Renaming the file name so that BPEL Processes the File
BEGIN
          l_prg_exe_counter := '12.1';
          UTL_FILE.frename(l_DIRECTORY,l_file_name,l_DIRECTORY,substr(l_file_name,0,length(l_file_name)-4),TRUE);
EXCEPTION
WHEN OTHERS THEN
l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while Renaming the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
RAISE FILE_RENAME_EXCP;
END;

l_prg_exe_counter := '12.2';

ELSE
l_prg_exe_counter := '13';
 l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
l_prg_exe_counter := '14';
 BEGIN
          l_prg_exe_counter := '15';
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'NO_DATA_FOUND Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'UTL_FILE.INVALID_PATH Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'UTL_FILE.READ_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'UTL_FILE.WRITE_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'FILE_RENAME_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
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
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
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
                                                           p_program_short_name => 'XXGLSUBLEDGEROUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'GL SubLedger Outbound Failed for Blackline'||' - '||l_request_id,
                              p_body_text   => 'GL SubLedger Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create GL SubLedger file for Period :'||p_period_name||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* GL SubLedger Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END SUBLEDGER_MAIN;
END XXGL_BALANCES_OUTBOUND_PKG;
/
