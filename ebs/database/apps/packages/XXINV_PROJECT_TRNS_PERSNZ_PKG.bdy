create or replace PACKAGE BODY      XXINV_PROJECT_TRNS_PERSNZ_PKG AS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXINV_PROJECT_TRNS_PERSNZ_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    03-JUN-2014
Purpose:         Used in Inventory Personalizations for Project related Transactions 
Program Style:   Stored Package Body
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
03-JUN-2014        1.0                  Sandeep Akula    Initial Version 
---------------------------------------------------------------------------------------------------*/

FUNCTION PROJ_TASK_CAPITALIZABLE_FLAG(P_PROJECT_ID IN NUMBER,
                                      P_TASK_ID IN NUMBER)
RETURN VARCHAR2 IS
l_flag  VARCHAR2(1) := '';
BEGIN

begin
select pt.billable_flag
into l_flag
from pa_projects_all ppa,
     pa_tasks pt,
     pa_project_types_all ppta
where ppa.project_id = pt.project_id and
      ppa.project_type = ppta.project_type and
      ppa.project_id = p_project_id and
      pt.task_id = p_task_id and
      pt.billable_flag = 'Y' and
      upper(ppta.project_type_class_code) = 'CAPITAL';
exception
when others then
l_flag := null;
end;

IF l_flag IS NULL THEN
RETURN('N');
ELSE
RETURN('Y');
END IF;

END PROJ_TASK_CAPITALIZABLE_FLAG;

FUNCTION SSUS_GET_ACCOUNT_STRING_ID
RETURN NUMBER IS
l_ccid NUMBER := '';
BEGIN

begin
SELECT code_combination_id
INTO l_ccid
FROM GL_CODE_COMBINATIONS_kfv
WHERE concatenated_segments = '26.000.181210.000.000.00.000.0000';
exception
when others then
l_ccid := '';
end;

RETURN(l_ccid);
END SSUS_GET_ACCOUNT_STRING_ID;

FUNCTION SSUS_VALIDATE_DEPT_ACCOUNT(P_ACCT_STRING IN VARCHAR2)
RETURN VARCHAR2 IS
l_company varchar2(100) := '';
l_dept varchar2(100) := '';
l_account varchar2(100) := '';
l_product varchar2(100) := '';
l_location varchar2(100) := '';
l_intercompany varchar2(100) := '';
l_future_division varchar2(100) := '';
l_future varchar2(100) := '';
BEGIN

begin
select
trim(SUBSTR(P_ACCT_STRING,1,instr(P_ACCT_STRING,'.','1')-1)), -- company,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,1)+1,instr(P_ACCT_STRING,'.',1,2)-instr(P_ACCT_STRING,'.',1,1)-1)), -- department,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,2)+1,instr(P_ACCT_STRING,'.',1,3)-instr(P_ACCT_STRING,'.',1,2)-1)), -- account,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,3)+1,instr(P_ACCT_STRING,'.',1,4)-instr(P_ACCT_STRING,'.',1,3)-1)), -- product,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,4)+1,instr(P_ACCT_STRING,'.',1,5)-instr(P_ACCT_STRING,'.',1,4)-1)), -- location,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,5)+1,instr(P_ACCT_STRING,'.',1,6)-instr(P_ACCT_STRING,'.',1,5)-1)), -- intercompany,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,6)+1,instr(P_ACCT_STRING,'.',1,7)-instr(P_ACCT_STRING,'.',1,6)-1)), -- future_division,
trim(SUBSTR(P_ACCT_STRING,instr(P_ACCT_STRING,'.',1,7)+1)) --future
into l_company,
l_dept,
l_account,
l_product,
l_location,
l_intercompany,
l_future_division,
l_future
from dual;
exception
when others then
l_company := '';
l_dept := '';
l_account := '';
l_product := '';
l_location := '';
l_intercompany := '';
l_future_division := '';
l_future := '';
end;

IF l_dept <> '000' AND (l_account BETWEEN '600000' AND '699999') THEN

 IF l_product = '000' AND l_location = '000' AND l_intercompany = '00' AND l_future_division = '000' AND l_future = '0000' THEN
    RETURN('Y');
 ELSE
    RETURN('N');
 END IF;
 
ELSE
RETURN('N');
END IF;

END SSUS_VALIDATE_DEPT_ACCOUNT;

FUNCTION SSUS_CAPITAL_PROJECT_MSG
RETURN VARCHAR2 IS
l_msg VARCHAR2(32767) := '';
BEGIN
fnd_message.set_name('XXOBJT','XXINV_PA_CAPITAL_PROJECT_MSG');
l_msg := fnd_message.get;
RETURN(l_msg);
END SSUS_CAPITAL_PROJECT_MSG;

FUNCTION SSUS_NON_CAPITAL_PROJECT_MSG
RETURN VARCHAR2 IS
l_msg VARCHAR2(32767) := '';
BEGIN
fnd_message.set_name('XXOBJT','XXINV_PA_NONCAPITAL_PROJ_MSG');
l_msg := fnd_message.get;
RETURN(l_msg);
END SSUS_NON_CAPITAL_PROJECT_MSG;

FUNCTION SSUS_VALIDATE_ACCTFLEX_STRUC(p_inventory_org_id IN NUMBER)
RETURN VARCHAR2 IS
l_cnt  NUMBER;
BEGIN

begin
select    count(*)
into  l_cnt
from    HR_ORGANIZATION_INFORMATION hoi,
          hr_operating_units hou,
          gl_sets_of_books  sob,
          org_organization_definitions ood,
	        FND_ID_FLEX_STRUCTURES FIFS 
	where   TO_NUMBER(hoi.org_information3) = hou.organization_id 
  and     hoi.org_information_context = 'Accounting Information' 
  and     hou.set_of_books_id = sob.set_of_books_id
  and     hoi.organization_id = ood.organization_id
  and     sob.chart_of_accounts_id = FIFS.ID_FLEX_NUM
  and     fifs.id_flex_code = 'GL#'
  and     ood.organization_id = p_inventory_org_id
  and     FIFS.ID_FLEX_STRUCTURE_CODE = 'XX_STRATASYS_USD'; -- SSUS Accounting Flexfield Structure 
EXCEPTION
when others then
l_cnt := '0';
end;

IF l_cnt > '0' THEN
RETURN('Y');
ELSE
RETURN('N');
END IF;

END SSUS_VALIDATE_ACCTFLEX_STRUC;

END XXINV_PROJECT_TRNS_PERSNZ_PKG;
/
