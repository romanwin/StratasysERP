CREATE OR REPLACE PACKAGE BODY XXOBJT_PA_INV_ACCOUNT_PKG AS
  --------------------------------------------------------------------   
   -- Author  : VENU KANDI
  -- Created : 06/14/2013 
  -- Purpose : PA WF Customization 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/14/2013  Venu Kandi        initial build
  --  1.1  05/06/2014  Venu Kandi        CHG0031957 - Update workflow account generator for 000 
  --                                     on expense projects when asset/liability
  --------------------------------------------------------------------   

  PROCEDURE get_company_from_exp_org_dff(itemtype IN  VARCHAR2,
			                             itemkey  IN  VARCHAR2,
			                             actid    IN  NUMBER,
			                             funcmode IN  VARCHAR2,
			                             result   OUT nocopy VARCHAR2)
  IS
  	lv_company_id VARCHAR2(100);
	ln_exp_org_id NUMBER;
  BEGIN

  IF (funcmode = 'RUN') THEN

  	  ln_exp_org_id := wf_engine.GetItemAttrText(itemtype, itemkey,'EXPENDITURE_ORGANIZATION_ID');

	  select attribute4 company_id
	  into lv_company_id
	  from HR_ALL_ORGANIZATION_UNITS
	  where organization_id = ln_exp_org_id; -- exp org

	  wf_engine.SetItemAttrText(itemtype, itemkey, 'COMPANY_ID_FROM_EXP_ORG_DFF', lv_company_id);

  END IF;

  -- return success
  RETURN;

  END get_company_from_exp_org_dff;

  PROCEDURE get_dept_from_exp_org_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2)
  IS
  	lv_department VARCHAR2(100);
	ln_exp_org_id 	 NUMBER;
  BEGIN

  IF (funcmode = 'RUN') THEN

  	  ln_exp_org_id := wf_engine.GetItemAttrText(itemtype, itemkey,'EXPENDITURE_ORGANIZATION_ID');

	  select attribute5 department
	  into lv_department
	  from HR_ALL_ORGANIZATION_UNITS
	  where organization_id = ln_exp_org_id; -- exp org

	  wf_engine.SetItemAttrText(itemtype, itemkey, 'DEPARTMENT_ID_FROM_EXP_ORG_DFF', lv_department);

  END IF;

  -- return success
  RETURN;

  END get_dept_from_exp_org_dff;

  PROCEDURE get_cip_acct_from_exp_type_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2)
  IS
    lv_cip_account VARCHAR2(10);
	lv_exp_type    VARCHAR2(100);
  BEGIN

  IF (funcmode = 'RUN') THEN

	lv_exp_type := wf_engine.GetItemAttrText(itemtype, itemkey,'EXPENDITURE_TYPE');

  	select attribute2 cip_account
    into lv_cip_account
	from PA_EXPENDITURE_TYPES
    where expenditure_type = lv_exp_type;

    wf_engine.SetItemAttrText(itemtype, itemkey, 'CIP_ACCT_ID_FROM_EXP_TYPE_DFF', lv_cip_account);

  END IF;

  -- return success
  RETURN;

  END get_cip_acct_from_exp_type_dff;

  PROCEDURE get_exp_acct_from_exp_type_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2)
  IS
    lv_expense_account VARCHAR2(10);
    lv_exp_type        VARCHAR2(100);
  BEGIN

  IF (funcmode = 'RUN') THEN

    lv_exp_type := wf_engine.GetItemAttrText(itemtype, itemkey,'EXPENDITURE_TYPE');

  	select attribute1 expense_account
    into lv_expense_account
	from PA_EXPENDITURE_TYPES
    where expenditure_type = lv_exp_type;

    wf_engine.SetItemAttrText(itemtype, itemkey, 'EXP_ACCT_ID_FROM_EXP_TYPE_DFF', lv_expense_account);

  END IF;

  -- return success
  RETURN;

  END get_exp_acct_from_exp_type_dff;

  PROCEDURE get_proj_type_class_code(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2)
  IS
    lv_project_type           VARCHAR2(30);
    lv_proj_type_class_code   VARCHAR2(30);
  BEGIN

  IF (funcmode = 'RUN') THEN

    lv_project_type := wf_engine.GetItemAttrText(itemtype, itemkey,'PROJECT_TYPE');

  	select project_type_class_code
    into lv_proj_type_class_code
	from PA_PROJECT_TYPES_ALL
    where project_type = lv_project_type;

    wf_engine.SetItemAttrText(itemtype, itemkey, 'PROJECT_TYPE_CLASS_CODE', lv_proj_type_class_code);

  END IF;

  -- return success
  RETURN;

  END get_proj_type_class_code;

  PROCEDURE get_project_type_prepaid(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2)
  IS
  	lv_account_value VARCHAR2(30);
	lv_project_type	 VARCHAR2(100);
  BEGIN
  
  IF (funcmode = 'RUN') THEN

    lv_project_type := wf_engine.GetItemAttrText(itemtype, itemkey,'PROJECT_TYPE');
	
	BEGIN
	
  	SELECT segment_value
	INTO lv_account_value
  	FROM PA_SEGMENT_VALUE_LOOKUPS 
  	WHERE SEGMENT_VALUE_LOOKUP_SET_ID = (SELECT SEGMENT_VALUE_LOOKUP_SET_ID
	  							  	  	 FROM PA_SEGMENT_VALUE_LOOKUP_SETS
									 	 WHERE SEGMENT_VALUE_LOOKUP_SET_NAME = 'PROJECT_TYPE_PREPAID')
	AND   SEGMENT_VALUE_LOOKUP =  lv_project_type;
	
	wf_engine.SetItemAttrText(itemtype, itemkey, 'PROJECT_TYPE_PREPAID_ACCOUNT', lv_account_value);
	
	result := 'COMPLETE:Y';
	
	EXCEPTION
	WHEN OTHERS THEN 
		 null;
		 result := 'COMPLETE:N';
	END;
	
  END IF;
  
  -- return success
  RETURN;
  
  END get_project_type_prepaid;

END XXOBJT_PA_INV_ACCOUNT_PKG;
/
