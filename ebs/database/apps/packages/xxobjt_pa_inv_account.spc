CREATE OR REPLACE PACKAGE XXOBJT_PA_INV_ACCOUNT_PKG AS
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
			    result   OUT nocopy VARCHAR2);

  PROCEDURE get_dept_from_exp_org_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2);

  PROCEDURE get_cip_acct_from_exp_type_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2);

  PROCEDURE get_exp_acct_from_exp_type_dff(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2);

  PROCEDURE get_proj_type_class_code(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2);
    
  --------------------------------------------------------------------
  --  name:            get_project_type_prepaid
  --  create by:       Venu Kandi
  --  Revision:        1.0 
  --  creation date:   05/06/2014 
  --------------------------------------------------------------------
  --  purpose :        procedure will get project prepaid value from lookup set
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/06/2014  Venu Kandi        initial build
  --------------------------------------------------------------------   
 
  PROCEDURE get_project_type_prepaid(itemtype IN  VARCHAR2,
			    itemkey  IN  VARCHAR2,
			    actid    IN  NUMBER,
			    funcmode IN  VARCHAR2,
			    result   OUT nocopy VARCHAR2);
  
END XXOBJT_PA_INV_ACCOUNT_PKG;
/
