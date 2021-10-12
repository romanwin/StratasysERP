create or replace PACKAGE BODY XXGL_CONCUR_INBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXGL_CONCUR_INBOUND_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    07-OCT-2014
Purpose:         Concur Expenses Validation Package
Program Style:   Stored Package Body
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
07-OCT-2014        1.0                  Sandeep Akula    Initial Version (CHG0033357)
03-NOV-2014        1.1                  Sandeep Akula     Added Logic to Pull Category Name from Lookup -- CHG0033761
12-NOV-2014        1.2                  Sandeep Akula     Added Variable l_account_type and Added SQL to dervie the account type based on the Natural account -- CHG0033813
25-NOV-2014        1.3                  Sandeep Akula     Commented Amount Logic in Procedure MAIN; so that Inbound completes sucessfully -- CHG0033962
07-JUL-2015        1.4                  Sandeep Akula     Added New Functions COMPANY_EXISTS_CNT, GET_LEDGER_NAME and GET_LIABILITY_ACCOUNT to the Package -- CHG0035548
                                                          Removed Harcoding from Procedure MAIN. Ledger ID, Liability account derivation and creation of balancing entry will be dependent on value stored in lookup XXGL_CONCUR_COMPANIES -- CHG0035548
---------------------------------------------------------------------------------------------------*/
G_CURR_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    COMPANY_EXISTS_CNT
  Author's Name:   Sandeep Akula
  Date Written:    07-JUL-2015
  Purpose:         Checks if the Company code exists in lookup XXGL_CONCUR_COMPANIES  
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  07-JUL-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035548
  ---------------------------------------------------------------------------------------------------*/
FUNCTION COMPANY_EXISTS_CNT(p_company IN VARCHAR2)
RETURN VARCHAR2 IS
l_cnt NUMBER;
BEGIN

begin
SELECT count(*)
INTO l_cnt
FROM FND_LOOKUP_TYPES_VL fltv,
     FND_LOOKUP_VALUES_VL flvv
WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
  AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
  AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
  AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_CONCUR_COMPANIES'
  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE))
  AND UPPER(flvv.lookup_code) = p_company;
exception
when others then
l_cnt := 0;
end;

RETURN(l_cnt);
END COMPANY_EXISTS_CNT;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_LEDGER_NAME
  Author's Name:   Sandeep Akula
  Date Written:    07-JUL-2015
  Purpose:         Derives the Ledger Name based on the Company Code from the Lookup XXGL_CONCUR_COMPANIES
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  07-JUL-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035548
  ---------------------------------------------------------------------------------------------------*/
FUNCTION GET_LEDGER_NAME(p_company IN VARCHAR2)
RETURN VARCHAR2 IS
l_ledger_name FND_LOOKUP_VALUES_VL.description%type;
BEGIN

begin
SELECT upper(flvv.description)
INTO l_ledger_name
FROM FND_LOOKUP_TYPES_VL fltv,
     FND_LOOKUP_VALUES_VL flvv
WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
  AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
  AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
  AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_CONCUR_COMPANIES'
  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE))
  AND UPPER(flvv.lookup_code) = p_company;
exception
when others then
l_ledger_name := NULL;
end;

RETURN(l_ledger_name);
END GET_LEDGER_NAME;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_LIABILITY_ACCOUNT
  Author's Name:   Sandeep Akula
  Date Written:    07-JUL-2015
  Purpose:         Derives the Liability Account String based on the Company Code from the Lookup XXGL_CONCUR_COMPANIES
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  07-JUL-2015        1.0                  Sandeep Akula     Initial Version -- CHG0035548
  ---------------------------------------------------------------------------------------------------*/
FUNCTION GET_LIABILITY_ACCOUNT(p_company IN VARCHAR2)
RETURN VARCHAR2 IS
l_account FND_LOOKUP_VALUES_VL.attribute1%type;
BEGIN

begin
SELECT flvv.attribute1
INTO l_account
FROM FND_LOOKUP_TYPES_VL fltv,
     FND_LOOKUP_VALUES_VL flvv
WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
  AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
  AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
  AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_CONCUR_COMPANIES'
  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE))
  AND UPPER(flvv.lookup_code) = p_company;
exception
when others then
l_account := NULL;
end;

RETURN(l_account);
END GET_LIABILITY_ACCOUNT;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MAIN
  Author's Name:   Sandeep Akula
  Date Written:    07-OCT-2014
  Purpose:         Validates Concur Expense data loaded into GL Interface Table by BPEL Process
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  07-OCT-2014        1.0                  Sandeep Akula     Initial Version -- CHG0033357
  03-NOV-2014        1.1                  Sandeep Akula     Added Logic to Pull Category Name from Lookup -- CHG0033761
  12-NOV-2014        1.2                  Sandeep Akula     Added Variable l_account_type and Added SQL to dervie the account type based on the Natural account -- CHG0033813
  25-NOV-2014        1.3                  Sandeep Akula     Commented Amount Logic; so that Inbound completes sucessfully -- CHG0033962
  07-JUL-2015        1.4                  Sandeep Akula     Removed Hard Coding from Cursor c_balanced_enteries SQL  -- CHG0035548
                                                            Removed Hard Coding from Ledger ID derivation SQL  -- CHG0035548
                                                            Removed Hard Coding from the INSERT statement into GL_INTERFACE table. Now Code Combination ID will be Inserted instead of individual segments -- CHG0035548
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_file_name IN VARCHAR2,
               p_bpel_instance_id IN NUMBER) IS

CURSOR C_DATA(cp_bpel_id IN NUMBER) IS
SELECT rowid,
       segment1 report_org_unit_1,
       attribute3 journal_debit_or_credit,
       to_number(attribute4) journal_amount,
       reference24 payment_type_code,
       reference21 report_org_unit_3,
       reference22 report_org_unit_4,
       attribute5 employee_last_name,
       attribute6 employee_first_name,
       transaction_date,
       segment3, -- Added column 11/12/2014 SAkula CHG0033813
       company_exists_cnt(segment1) cmpy_exists_cnt, -- Added Column 07/07/2015 SAkula CHG0035548 
       get_ledger_name(segment1) ledger_name -- Added Column 07/07/2015 SAkula CHG0035548 
FROM  gl_interface
WHERE reference25 = cp_bpel_id and
      upper(attribute1) = 'DETAIL';


CURSOR C_BALANCED_ENTRIES(cp_bpel_id IN NUMBER) IS
SELECT  --sum(to_number(attribute4)) j_amt,
       (sum(nvl(entered_dr, 0)) - sum(nvl(entered_cr, 0))) j_amt, -- Added 11/26/2014 SAkula CHG0033962
       segment1 report_org_unit_1,
       reference24 payment_type_code,
       accounting_date batch_date,
       currency_code,
       reference1 batchid,
       get_ledger_name(segment1) ledger_name, -- Added Column 07/07/2015 SAkula CHG0035548 
       get_liability_account(segment1) liab_acct  -- Added Column 07/07/2015 SAkula CHG0035548 
       --reference26 report_id,
       --reference27 report_key
FROM gl_interface
WHERE reference25 = cp_bpel_id and
      upper(attribute1) = 'DETAIL' and
      --segment1 IN ('26','37') -- Only create Balancing entries for Company 26 and 37 -- Commented 07/07/2015 SAkula
      company_exists_cnt(segment1) > 0 -- Added 07/07/2015 SAkula CHG0035548 -- Only create Balancing entries for Companies listed in the lookup XXGL_CONCUR_COMPANIES
group by segment1, --report_org_unit_1
         reference24, -- payment_type_code
         accounting_date, --batchdate
         currency_code,
         reference1;
         --reference26,
         --reference27;

l_file_list  VARCHAR2(32767) := '';
l_ledger_id  NUMBER;
report_org_unit1_excp  EXCEPTION;
payment_type_code_excp EXCEPTION;
FILE_AMT_MISMATCH_EXCP EXCEPTION;
FILE_INTERFACE_MISMATCH_EXCP EXCEPTION;
FILE_NAME_MISSING_EXCP EXCEPTION;
BPEL_ID_MISSING_EXCP   EXCEPTION;
l_entered_cr  NUMBER;
l_entered_dr  NUMBER;
l_category_name varchar2(500);
l_reference10 varchar2(500);
l_bal_entered_cr  NUMBER;
l_bal_entered_dr  NUMBER;
l_bal_je_line_num NUMBER;
l_err_code  NUMBER;
l_err_msg   VARCHAR2(500);
l_instance_name   v$database.name%type;
l_directory       VARCHAR2(2000);
l_request_id      NUMBER:= fnd_global.conc_request_id;
l_prg_exe_counter        NUMBER := '';
l_error_message          varchar2(32767) := '';
l_mail_list VARCHAR2(500);
l_notf_requestor varchar2(200) := '';
l_file_header_amt NUMBER;
l_file_line_amt NUMBER;
l_intf_entered_dr NUMBER;
l_intf_entered_cr NUMBER;
l_intf_group_id NUMBER;
l_role_name   VARCHAR2(100) := FND_PROFILE.VALUE('XXGL_CONCUR_NOTF_ROLE');
l_account_type varchar2(1);  -- Added Variable 11/12/2014 SAkula (CHG0033813)
l_ccid NUMBER; -- Added Variable 07/07/2015 SAkula CHG0035548 

BEGIN
FND_FILE.PUT_LINE(FND_FILE.LOG,'Inside Procedure MAIN');
l_prg_exe_counter := '0';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;

         l_prg_exe_counter := '1';

  /* Getting data elements for Error Notification*/
l_error_message := 'Error Occured while getting Notification Details for Request ID :'||l_request_id;
begin
select requestor
into l_notf_requestor
from fnd_conc_req_summary_v
where request_id = l_request_id;
exception
when others then
null;
end;

l_prg_exe_counter := '2';

 IF p_file_name IS NULL THEN
    RAISE FILE_NAME_MISSING_EXCP;
 END IF;

l_prg_exe_counter := '2.1';

 IF p_bpel_instance_id IS NULL THEN
    RAISE BPEL_ID_MISSING_EXCP;
 END IF;

l_prg_exe_counter := '2.2';

l_error_message := 'Error Occured while deriving value for l_file_header_amt';
l_file_header_amt := '';
select to_number(attribute2)
into l_file_header_amt
from gl_interface
where reference25 = p_bpel_instance_id and
      upper(attribute1) = 'EXTRACT';

l_prg_exe_counter := '3';

l_error_message := 'Error Occured while deriving value for l_file_line_amt';
l_file_line_amt := '';
select sum(to_number(attribute4))
into l_file_line_amt
from gl_interface
where reference25 = p_bpel_instance_id and
      upper(attribute1) = 'DETAIL';

l_prg_exe_counter := '4';

IF l_file_header_amt <> l_file_line_amt THEN
RAISE FILE_AMT_MISMATCH_EXCP;
END IF;

l_prg_exe_counter := '5';

l_intf_group_id:= '';
l_error_message := 'Error Occured while deriving l_intf_group_id';
SELECT xxobjt.XXGL_CONCUR_SEQ.NEXTVAL
INTO l_intf_group_id
FROM DUAL;

l_prg_exe_counter := '5.1';

FND_FILE.PUT_LINE(FND_FILE.LOG,'Beginning of Cursor c_data');
l_error_message := 'Error Occured while opening cursor C_DATA for file :'||p_file_name;
for c_2 in C_DATA(p_bpel_instance_id) loop

l_prg_exe_counter := '6';
l_error_message := 'Error Occured in IF condition for report_org_unit_1';
--IF c_2.report_org_unit_1 IN ('26','37') THEN   Commented 07/07/2015 SAkula CHG0035548 
IF c_2.cmpy_exists_cnt > 0 THEN  -- Added 07/07/2015 SAkula CHG0035548 

l_prg_exe_counter := '7';
l_ledger_id := '';
l_error_message := 'Error Occured while derving l_ledger_id';
select ledger_id
into l_ledger_id
from gl_ledgers
--where upper(name) = 'STRATASYS US';  -- Commented 07/07/2015 SAkula CHG0035548 
where upper(name) = c_2.ledger_name; -- Added 07/07/2015 SAkula CHG0035548 

l_prg_exe_counter := '8';
ELSE
l_prg_exe_counter := '9';
l_ledger_id := NULL;
--RAISE report_org_unit1_excp;  Allow the records to be loaded into GL_INTERFACE table and let Journal Import Handle the Error Handling
END IF;

l_prg_exe_counter := '10';
l_category_name := '';
l_error_message := 'Error Occured while derving l_category_name (Cursor C_DATA)';
/*IF c_2.payment_type_code = 'CBCP' THEN
l_category_name := 'XX_P-card_CB';
ELSIF c_2.payment_type_code = 'IBIP' THEN
l_category_name := 'XX_P-card_IB';
ELSIF c_2.payment_type_code = 'CASH' THEN
l_category_name := 'XX_OOP';
ELSE
l_category_name := NULL;
--RAISE payment_type_code_excp;   Allow the records to be loaded into GL_INTERFACE table and let Journal Import Handle the Error Handling
END IF;  */
-- Added Logic to Pull Category Name from Lookup 11/03/2014 SAkula CHG0033761
begin
SELECT flvv.meaning
INTO l_category_name
FROM FND_LOOKUP_TYPES_VL fltv,
     FND_LOOKUP_VALUES_VL flvv
WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
  AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
  AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
  AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_CONCUR_CATEGORY_MAP'
  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE))
  AND UPPER(flvv.lookup_code) = c_2.payment_type_code;
exception
when others then
l_category_name := 'CONCUR-UNASSIGNED';
end;

l_prg_exe_counter := '11';

l_reference10 := '';
l_error_message := 'Error Occured while derving l_reference10';
l_reference10 := c_2.report_org_unit_3||'-'||
                 c_2.report_org_unit_4||'-'||
                 c_2.employee_first_name||'-'||
                 c_2.employee_last_name||'-'||
                 to_char(c_2.transaction_Date,'MM-DD');

l_prg_exe_counter := '12';
-- 11/12/2014 SAkula -- Added SQL to dervie the account type based on the Natural account (CHG0033813) BEGIN
l_account_type := '';
begin
SELECT TRIM(SUBSTR(COMPILED_VALUE_ATTRIBUTES,5,1))
INTO l_account_type
FROM FND_FLEX_VALUES_VL FV,
     FND_FLEX_VALUE_SETS FVS
WHERE FVS.FLEX_VALUE_SET_ID = FV.FLEX_VALUE_SET_ID
AND FLEX_VALUE_SET_NAME     = 'XXGL_ACCOUNT_SS'
AND flex_value              = c_2.segment3; --Journal Account Code
exception
when others then
l_account_type := null;
end;
-- END CHG0033813

l_prg_exe_counter := '12.1';

l_error_message := 'Error Occured while Inserting into GL_INTERFACE';
UPDATE GL_INTERFACE
SET LEDGER_ID = l_ledger_id,
    SET_OF_BOOKS_ID = l_ledger_id,
    GROUP_ID = l_intf_group_id, --l_ledger_id,
    --ENTERED_CR = DECODE(c_2.journal_debit_or_credit,'CR',c_2.journal_amount,NULL), -- Commented 11/26/2014 SAkula CHG0033962
    --ENTERED_DR = DECODE(c_2.journal_debit_or_credit,'DR',c_2.journal_amount,NULL), -- Commented 11/26/2014 SAkula CHG0033962
    ENTERED_CR = (CASE WHEN c_2.journal_amount < '0' THEN abs(c_2.journal_amount) ELSE NULL END), -- Added 11/26/2014 SAkula CHG0033962
    ENTERED_DR = (CASE WHEN c_2.journal_amount >= '0' THEN c_2.journal_amount ELSE NULL END), -- Added 11/26/2014 SAkula CHG0033962
    USER_JE_CATEGORY_NAME = l_category_name,
    REFERENCE10 = l_reference10,
    STATUS = 'NEW',
    USER_JE_SOURCE_NAME = 'Concur',
    SEGMENT2 = (CASE l_account_type WHEN 'E' THEN SEGMENT2 ELSE '000' END) -- Added 11/12/2014 SAkula  CHG0033813
WHERE rowid = c_2.rowid and
      reference25 = p_bpel_instance_id and
      attribute1 = 'DETAIL';


    l_prg_exe_counter := '13';
end loop;

l_prg_exe_counter := '14';
FND_FILE.PUT_LINE(FND_FILE.LOG,'End of Cursor c_data');

l_prg_exe_counter := '14.1';
-- If ?Report Entry is Personal Flag? (Position 68) = ?Y? and is individual paid ((Position 126) = ?CASH?), do not load the record into the open interface table.
l_error_message := 'Error Occured while deleting Records from GL_INTERFACE which have Individual Paid Flag = Y and Report Entry Personal Flag is Y for file :'||p_file_name;
DELETE FROM GL_INTERFACE
WHERE reference25 = p_bpel_instance_id and
      upper(attribute1) = 'DETAIL' and
      ATTRIBUTE7 = 'Y' and -- Report Entry Is Personal Flag
      REFERENCE24 = 'CASH';


l_prg_exe_counter := '15';
l_bal_je_line_num := '';
l_error_message := 'Error Occured while deriving l_bal_je_line_num';
SELECT max(je_line_num)
INTO l_bal_je_line_num
FROM gl_interface
WHERE reference25 = p_bpel_instance_id and
      upper(attribute1) = 'DETAIL';

l_prg_exe_counter := '16';
FND_FILE.PUT_LINE(FND_FILE.LOG,'Beginning of Cursor C_BALANCED_ENTRIES');
l_error_message := 'Error Occured while opening cursor c_balanced_entries';
for c_3 in C_BALANCED_ENTRIES(p_bpel_instance_id) loop

l_prg_exe_counter := '17';

l_ledger_id := '';
l_error_message := 'Cursor C_BALANCED_ENTRIES: Error Occured while derving l_ledger_id';
select ledger_id
into l_ledger_id
from gl_ledgers
--where upper(name) = 'STRATASYS US';  -- Commented 07/07/2015 SAkula CHG0035548 
where upper(name) = c_3.ledger_name; -- Added 07/07/2015 SAkula CHG0035548 

l_prg_exe_counter := '17.1';
l_category_name := '';
l_error_message := 'Error Occured while deriving l_category_name(Cursor C_BALANCED_ENTRIES)';
/*IF c_3.payment_type_code = 'CBCP' THEN
l_category_name := 'XX_P-card_CB';
ELSIF c_3.payment_type_code = 'IBIP' THEN
l_category_name := 'XX_P-card_IB';
ELSIF c_3.payment_type_code = 'CASH' THEN
l_category_name := 'XX_OOP';
END IF;*/
-- Added Logic to Pull Category Name from Lookup 11/03/2014 SAkula CHG0033761
begin
SELECT flvv.meaning
INTO l_category_name
FROM FND_LOOKUP_TYPES_VL fltv,
     FND_LOOKUP_VALUES_VL flvv
WHERE fltv.SECURITY_GROUP_ID  = flvv.SECURITY_GROUP_ID
  AND fltv.VIEW_APPLICATION_ID = flvv.VIEW_APPLICATION_ID
  AND fltv.LOOKUP_TYPE = flvv.LOOKUP_TYPE
  AND UPPER(fltv.LOOKUP_TYPE) = 'XXGL_CONCUR_CATEGORY_MAP'
  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvv.START_DATE_ACTIVE) AND NVL(flvv.END_DATE_ACTIVE,TRUNC(SYSDATE))
  AND UPPER(flvv.lookup_code) = c_3.payment_type_code;
exception
when others then
l_category_name := 'CONCUR-UNASSIGNED';
end;

l_prg_exe_counter := '18';

l_bal_entered_cr := '';
l_bal_entered_dr := '';
l_error_message := 'Error Occured while checking for c3.j_amt';
IF c_3.j_amt > '0' THEN
l_bal_entered_cr := c_3.j_amt;
l_bal_entered_dr := null;
ELSIF c_3.j_amt < '0' THEN
l_bal_entered_cr := null;
l_bal_entered_dr := c_3.j_amt;
END IF;
l_prg_exe_counter := '19';

l_error_message := 'Error Occured while Incrementing l_bal_je_line_num';
l_bal_je_line_num := l_bal_je_line_num + 1;

l_prg_exe_counter := '19.1';

-- Added 07/07/2015 SAkula CHG0035548 
l_error_message := 'Balancing Entry Cursor: Error Occured while Deriving CCID for report org Unit :'||c_3.report_org_unit_1;
select code_combination_id
into l_ccid
from gl_code_combinations_kfv
where concatenated_segments = c_3.liab_acct;

l_prg_exe_counter := '20';
l_error_message := 'Error Occured while inserting into GL_INTERFACE';
INSERT INTO GL_INTERFACE(STATUS,
                         LEDGER_ID,
                         SET_OF_BOOKS_ID,
                         GROUP_ID,
                         ACCOUNTING_DATE,
                         TRANSACTION_DATE,
                         ACTUAL_FLAG,
                         CREATED_BY,
                         CURRENCY_CODE,
                         DATE_CREATED,
                         JE_LINE_NUM,
                         CODE_COMBINATION_ID, -- Added 07/07/2015 SAkula CHG0035548 
                         --SEGMENT1, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT2, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT3, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT4, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT5, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT6, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT7, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT8, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT9, -- Commented 07/07/2015 SAkula CHG0035548 
                         --SEGMENT10, -- Commented 07/07/2015 SAkula CHG0035548 
                         ENTERED_CR,
                         ENTERED_DR,
                         USER_JE_CATEGORY_NAME,
                         USER_JE_SOURCE_NAME,
                         REFERENCE1,
                         REFERENCE4,
                         REFERENCE6,
                         REFERENCE10,
                         REFERENCE21,
                         REFERENCE22,
                         REFERENCE24,
                         REFERENCE25
                         --REFERENCE26,
                         --REFERENCE27
                         )
                  VALUES('NEW',   -- STATUS
                         l_ledger_id, -- LEDGER_ID
                         l_ledger_id,  -- SET_OF_BOOKS_ID
                         l_intf_group_id, -- GROUP_ID
                         --l_ledger_id,  -- GROUP_ID
                         c_3.batch_date,  -- ACCOUNTING_DATE
                         SYSDATE,  -- TRANSACTION_DATE
                         'A',  --ACTUAL_FLAG
                         FND_GLOBAL.USER_ID,  -- CREATED_BY
                         c_3.currency_code,  -- CURRENCY_CODE
                         SYSDATE,  -- DATE_CREATED
                         l_bal_je_line_num,  -- JE_LINE_NUM
                         l_ccid,   -- CODE_COMBINATION_ID  -- Added 07/07/2015 SAkula CHG0035548 
                         --decode(c_3.report_org_unit_1,'26','26','37','26',c_3.report_org_unit_1),  -- SEGMENT1 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'000', -- SEGMENT2 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'201265', -- SEGMENT3 -- Commented 07/07/2015 SAkula CHG0035548 
                         --NULL,  -- SEGMENT4 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'000',  -- SEGMENT5 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'000',  -- SEGMENT6 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'00',  -- SEGMENT7 -- Commented 07/07/2015 SAkula CHG0035548 
                         --NULL,  -- SEGMENT8 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'0000',  -- SEGMENT9 -- Commented 07/07/2015 SAkula CHG0035548 
                         --'000',  -- SEGMENT10 -- Commented 07/07/2015 SAkula CHG0035548 
                         l_bal_entered_cr,  --ENTERED_CR
                         l_bal_entered_dr,  -- ENTERED_DR
                         l_category_name,  -- USER_JE_CATEGORY_NAME
                         'Concur',  -- USER_JE_SOURCE_NAME
                         c_3.batchid,  -- REFERENCE1
                         c_3.batchid, -- REFERENCE4
                         p_file_name, -- REFERENCE6
                         NULL,  -- REFERENCE10
                         NULL, -- REFERENCE21
                         NULL, -- REFERENCE22
                         c_3.payment_type_code, -- REFERENCE24
                         p_bpel_instance_id -- REFERENCE25
                         --c_3.report_id, -- REFERENCE26
                         --c_3.report_key  -- REFERENCE27
                       );

l_prg_exe_counter := '21';
end loop;
FND_FILE.PUT_LINE(FND_FILE.LOG,'End of Cursor C_BALANCED_ENTRIES');

l_prg_exe_counter := '22';

l_intf_entered_cr := '';
l_intf_entered_dr := '';
l_error_message := 'Error Occured while deriving l_bal_je_line_num';
select sum(entered_dr),sum(entered_cr)
into l_intf_entered_dr,l_intf_entered_cr
from gl_interface
where user_je_source_name = 'Concur' and
      reference25 = p_bpel_instance_id and
      upper(attribute1) = 'DETAIL';

 l_prg_exe_counter := '23';

-- Commented so that Inbound completes sucessfully 11/25/2014 SAkula  (CHG0033962)
-- IF l_file_header_amt <>  (l_intf_entered_dr+l_intf_entered_cr)/2 THEN
--   RAISE FILE_INTERFACE_MISMATCH_EXCP;
-- END IF;

l_prg_exe_counter := '24';

l_error_message := 'Error Occured while deleting File Header Records from GL_INTERFACE for file :'||p_file_name;
DELETE FROM GL_INTERFACE
WHERE reference25 = p_bpel_instance_id and
      upper(attribute1) = 'EXTRACT';

l_prg_exe_counter := '25';

l_error_message := 'Error Occured while updating GL_INTERFACE for file :'||p_file_name||' and DETAIL records';
UPDATE GL_INTERFACE
SET ATTRIBUTE1 = NULL,
    ATTRIBUTE2 = NULL,
    ATTRIBUTE3 = NULL,
    ATTRIBUTE4 = NULL,
    ATTRIBUTE5 = NULL,
    ATTRIBUTE6 = NULL,
    ATTRIBUTE7 = NULL
WHERE reference25 = p_bpel_instance_id and
      attribute1 = 'DETAIL';


l_prg_exe_counter := '26';
COMMIT;
EXCEPTION
WHEN BPEL_ID_MISSING_EXCP THEN
l_error_message := 'BPEL Instance ID is NULL for File :'||p_file_name;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLCONCURIN');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Concur Inbound Failure',
                              p_body_text   => 'Concur Inbound Request Id :'||l_request_id||chr(10)||
                                               'BPEL Instance ID :'||p_bpel_instance_id||chr(10)||
                                               'Could not process the file data in GL Interface Table as BPEL Instance ID Passed from BPEL Process is NULL'||chr(10)||
                                               'Program Needs a BPEL Instance ID to process data'||chr(10)||
                                               'Requestor :'||l_notf_requestor||chr(10)||
                                               'BPEL_ID_MISSING_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

WHEN FILE_NAME_MISSING_EXCP THEN
l_error_message := 'Data File Name is NULL for BPEL Instance Id :'||p_bpel_instance_id;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLCONCURIN');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Concur Inbound Failure',
                              p_body_text   => 'Concur Inbound Request Id :'||l_request_id||chr(10)||
                                               'BPEL Instance ID :'||p_bpel_instance_id||chr(10)||
                                               'Could not process the file data in GL Interface Table as Data File name passed from BPEL Process is NULL'||chr(10)||
                                               'Program Needs a file name to process data'||chr(10)||
                                               'Requestor :'||l_notf_requestor||chr(10)||
                                               'FILE_NAME_MISSING_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

WHEN FILE_AMT_MISMATCH_EXCP THEN
ROLLBACK;
l_error_message := 'File Header Amount and sum of Journal Line Amounts do not match for File :'||p_file_name;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLCONCURIN');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Concur Inbound Failure for File'||' - '||p_file_name,
                              p_body_text   => 'Concur Inbound Request Id :'||l_request_id||chr(10)||
                                               'BPEL Instance ID :'||p_bpel_instance_id||chr(10)||
                                               'Could not process the file data in GL Interface Table'||chr(10)||
                                               'File data validations in GL Interface are Rollbacked'||chr(10)||
                                               'Requestor :'||l_notf_requestor||chr(10)||
                                               'FILE_AMT_MISMATCH_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN FILE_INTERFACE_MISMATCH_EXCP THEN
ROLLBACK;
l_error_message := 'File Header Amount and sum of Journal Line Amounts in GL_INTERFACE do not match for File :'||p_file_name;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLCONCURIN');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Concur Inbound Failure for File'||' - '||p_file_name,
                              p_body_text   => 'Concur Inbound Request Id :'||l_request_id||chr(10)||
                                               'BPEL Instance ID :'||p_bpel_instance_id||chr(10)||
                                               'Could not process the file data in GL Interface Table'||chr(10)||
                                               'File data validations in GL Interface are Rollbacked'||chr(10)||
                                               'Requestor :'||l_notf_requestor||chr(10)||
                                               'FILE_INTERFACE_MISMATCH_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN OTHERS THEN
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXGLCONCURIN');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Concur Inbound Failure for File',
                              p_body_text   => 'MAIN OTHERS Exception'||chr(10)||
                                               'Concur Inbound Request Id :'||l_request_id||chr(10)||
                                               'BPEL Instance ID :'||p_bpel_instance_id||chr(10)||
                                               'Could not process the file data in GL Interface Table'||chr(10)||
                                               'File data validations in GL Interface are Rollbacked'||chr(10)||
                                               'Requestor :'||l_notf_requestor||chr(10)||
                                               'OTHERS Exception (Main)'||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

END MAIN;

/******************************************************************************************************

 Revision:   1.0
 Package Name:    CONCUR_INTF_DATAPURGE
 Authors Name:   Sandeep Akula
 Date Written:    21-OCT-2014
 Purpose:         Deletes data from GL_INTERFACE Table older than 60 days
 Program Style:   PROCEDURE
 Called From:
 Calls To:
 Maintenance History:
 Date:          Version                   Name            Remarks
 -----------    ----------------         -------------   ------------------
 21-OCT-2014        1.0                  Sandeep Akula    Initial Version (CHG0033357)
 ---------------------------------------------------------------------------------------------------*/
/*****************************************************************************************************  */

PROCEDURE CONCUR_INTF_DATAPURGE(errbuf OUT VARCHAR2,
                                retcode OUT NUMBER,
                                p_retention_period IN NUMBER) IS

BEGIN

delete from gl_interface
where upper(user_je_source_name) like '%CONCUR%' and
      ledger_id IS NULL and
      trunc(SYSDATE-date_created) > p_retention_period;

FND_FILE.put_line(fnd_file.log,'Parameter :'||p_retention_period);
FND_FILE.put_line(fnd_file.log,'Completed Sucessfully');
COMMIT;
EXCEPTION
   WHEN OTHERS THEN
     ROLLBACK;
     retcode := '2';
     errbuf := SQLERRM;
     FND_FILE.put_line(fnd_file.log,'Others Exception :'||sqlerrm);
END CONCUR_INTF_DATAPURGE;
END XXGL_CONCUR_INBOUND_PKG;
/
