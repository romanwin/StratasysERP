CREATE OR REPLACE PACKAGE xxobjt_wf_doc_util AUTHID CURRENT_USER IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_WF_DOC_UTIL
  --  create by:       Yuval tal
  --  Revision:        1.1
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        CUST611 : document approval engine
  --                   support workflow XXWFDOC
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     yuval tal         initial Build
  --  1.1  8.01.13     yuval tal         add abort_process
  --  1.2  17/07/2013  Dalit A. Raviv    handle NO_ACTION (skip level)
  --                                     procedure is_approved_by
  --                                     procedure get_next_approver_wf
  --                                     Procedure build_approval_hierarchy
  --  1.3  17/07/2014  Michal Tzvik      CHG0031856:
  --                                     1. update create_instance:
  --                                        add fields to table xxobjt_wf_doc_instance:
  --                                        user_id, resp_id, resp_appl_id
  --                                     2. Add procedures: get_apps_initialize_params
  --                                                        get_fyi_role_custom_wf
  --                                                        custom_failure_wf
  --                                                        set_doc_in_process_wf
  --                                                        set_doc_error_wf
  --                                                        end_main_wf
  --                                                        pre_approve_custom_wf
  --  1.4  01.01.2015  Michal Tzvik      CHG0033620:
  --                                     1. Add procedure insert_custom_approvals
  --                                     2. Add PROCEDURE is_reference_link_exists
  --  1.5  13/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     NEW FUNCTION get_last_approver_user_id
  --  1.6  30.07.2015 Michal Tzvik       CHG0035411: add parameter p_note to PROCEDURE initiate_approval_process
  --  1.7  30.4.19    yuval             CHG0045539  add re_route2role/approve
  --------------------------------------------------------------------

  -- Public function and procedure declarations
  PROCEDURE check_sql(p_sql VARCHAR2);
  PROCEDURE check_role_sql(p_sql VARCHAR2);
  FUNCTION get_doc_info(p_doc_id NUMBER) RETURN xxobjt_wf_docs%ROWTYPE;
  FUNCTION get_dynamic_role_desc(p_dyn_role_code VARCHAR2) RETURN VARCHAR2;
  FUNCTION get_doc_instance_id RETURN NUMBER;
  FUNCTION get_doc_name(p_doc_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_doc_status(p_doc_instance_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_doc_status_desc(p_doc_instance_id NUMBER) RETURN VARCHAR2;
  -- process
  FUNCTION get_doc_instance_info(p_doc_instance_id NUMBER)
    RETURN xxobjt_wf_doc_instance%ROWTYPE;

  PROCEDURE create_instance(p_err_code            OUT NUMBER,
		    p_err_msg             OUT VARCHAR2,
		    p_doc_instance_header IN OUT xxobjt_wf_doc_instance%ROWTYPE,
		    p_doc_code            VARCHAR2 DEFAULT NULL);

  PROCEDURE update_instance(p_err_code            OUT NUMBER,
		    p_err_msg             OUT VARCHAR2,
		    p_doc_instance_header IN OUT xxobjt_wf_doc_instance%ROWTYPE);

  PROCEDURE initiate_approval_process(p_err_code OUT NUMBER,
			  p_err_msg  OUT VARCHAR2,
			  
			  p_doc_instance_id NUMBER,
			  p_wf_item_key     OUT VARCHAR2,
			  p_note            IN VARCHAR2 DEFAULT NULL -- CHG0035411 Michal Tzvik 30.07.2015
			  );

  PROCEDURE update_doc_instance_key(p_err_code        OUT NUMBER,
			p_err_msg         OUT VARCHAR2,
			p_doc_instance_id NUMBER,
			p_wf_item_key     VARCHAR2);

  PROCEDURE build_approval_hierarchy(p_err_code        OUT NUMBER,
			 p_err_msg         OUT VARCHAR2,
			 p_doc_instance_id NUMBER);

  PROCEDURE abort_process(p_err_code        OUT NUMBER,
		  p_err_msg         OUT VARCHAR2,
		  p_doc_instance_id NUMBER);
  -- workflow

  PROCEDURE get_next_approver_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2);

  PROCEDURE build_approval_hierarchy_wf(itemtype  IN VARCHAR2,
			    itemkey   IN VARCHAR2,
			    actid     IN NUMBER,
			    funcmode  IN VARCHAR2,
			    resultout OUT NOCOPY VARCHAR2);

  PROCEDURE post_approve_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2);

  PROCEDURE post_reject_wf(itemtype  IN VARCHAR2,
		   itemkey   IN VARCHAR2,
		   actid     IN NUMBER,
		   funcmode  IN VARCHAR2,
		   resultout OUT NOCOPY VARCHAR2);

  PROCEDURE post_approve_custom_wf(itemtype  IN VARCHAR2,
		           itemkey   IN VARCHAR2,
		           actid     IN NUMBER,
		           funcmode  IN VARCHAR2,
		           resultout OUT NOCOPY VARCHAR2);

  PROCEDURE post_reject_custom_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2);

  --  notification action
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2);

  -- history

  PROCEDURE insert_history_record(p_err_code OUT NUMBER,
		          p_err_msg  OUT VARCHAR2,
		          p_his_rec  xxobjt_wf_doc_history%ROWTYPE);

  PROCEDURE update_doc_history(p_err_code        OUT NUMBER,
		       p_err_msg         OUT VARCHAR2,
		       p_doc_instance_id NUMBER,
		       p_person_id       NUMBER,
		       p_action_code     VARCHAR2,
		       p_context_user    VARCHAR2,
		       p_note            VARCHAR2 DEFAULT NULL);

  PROCEDURE get_dynamic_role(p_err_code        OUT NUMBER,
		     p_err_msg         OUT VARCHAR2,
		     p_dynamic_role    VARCHAR2,
		     p_doc_instance_id NUMBER,
		     p_out_role_name   OUT VARCHAR2);

  -- FUNCTION is_approved_by(p_doc_instance_id NUMBER, p_role_name VARCHAR2)
  -- RETURN VARCHAR2;
  ---

  -- CHG0031856 17.07.2014 Michal Tzvik
  PROCEDURE get_apps_initialize_params(p_doc_instance_id IN xxobjt_wf_doc_instance.doc_instance_id%TYPE,
			   x_user_id         OUT NUMBER,
			   x_resp_id         OUT NUMBER,
			   x_resp_appl_id    OUT NUMBER);

  PROCEDURE get_fyi_role_custom_wf(itemtype  IN VARCHAR2,
		           itemkey   IN VARCHAR2,
		           actid     IN NUMBER,
		           funcmode  IN VARCHAR2,
		           resultout OUT NOCOPY VARCHAR2);

  PROCEDURE custom_failure_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_doc_in_process_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_doc_error_wf(itemtype  IN VARCHAR2,
		     itemkey   IN VARCHAR2,
		     actid     IN NUMBER,
		     funcmode  IN VARCHAR2,
		     resultout OUT NOCOPY VARCHAR2);

  PROCEDURE end_main_wf(itemtype  IN VARCHAR2,
		itemkey   IN VARCHAR2,
		actid     IN NUMBER,
		funcmode  IN VARCHAR2,
		resultout OUT NOCOPY VARCHAR2);

  PROCEDURE pre_approve_custom_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2);

  PROCEDURE insert_custom_approvals(p_err_code                OUT NUMBER,
			p_err_msg                 OUT VARCHAR2,
			p_doc_instance_id         NUMBER,
			p_approval_person_id_list VARCHAR2);
  FUNCTION get_doc_id(p_doc_code VARCHAR2) RETURN NUMBER;

  PROCEDURE is_reference_link_exists(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_last_approver_user_id
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      13/07/2015
  --  Purpose :           get_last_approver_user_id
  --                      by doc_instance_id get the last approver user
  --                      because this program run from user scheduler and from sysadmin
  --                      the apps initialize is not setup.
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   13/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  FUNCTION get_last_approver_user_id(p_doc_instance_id IN NUMBER)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               re_route_approval
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :          re-route flow
  --  add to approval history tmp  previous approver ahead + current approver
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   30.4.19       yuval tal
  --
  -----------------------------------------------------------------------
  PROCEDURE re_route2role(p_doc_instance_id NUMBER,
		  p_route_to_seq    NUMBER,
		  p_note            VARCHAR2,
		  p_err_code        OUT NUMBER,
		  p_err_message     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code:
  --  name:               approve
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :          re-route flow
  --  approve notification from Form
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   30.4.19       yuval tal
  --
  -----------------------------------------------------------------------
  PROCEDURE approve(p_doc_instance_id NUMBER,
	        p_note            VARCHAR2,
	        p_err_code        OUT NUMBER,
	        p_err_message     OUT VARCHAR2);
END xxobjt_wf_doc_util;
/
