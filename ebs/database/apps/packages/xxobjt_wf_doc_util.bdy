CREATE OR REPLACE PACKAGE BODY xxobjt_wf_doc_util IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_WF_DOC_UTIL
  --  create by:       Yuval tal
  --  Revision:        1.2
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
  --                                     2. Add constants:
  --                                       c_status_error
  --                                       c_status_inprocess
  --                                     3. Add procedures: get_apps_initialize_params
  --                                                        get_fyi_role_custom_wf
  --                                                        set_doc_status
  --                                                        custom_failure_wf
  --                                                        set_doc_in_process_wf
  --                                                        set_doc_error_wf
  --                                                        end_main_wf
  --                                                        pre_approve_custom_wf
  --                                     4. update get_next_approver_wf:
  --                                         Set value for xxobjt_wf_doc_instance.approver_person_id
  --                                     5. update check_user_action_wf:
  --                                         Avoid user from approving his request by getting to "Notifications From Me" in Worklist
  --                                     6. Remove call to "update_instance" from initiate_approval_process, and add this code to a new
  --                                        WF function after "Start" in order to handle bug: status is not chandeg to APPROVED in autosign
  --                                     7. Procedure update_instance: Change assignment to start_date and end_date fields
  --                                     8. build_approval_hierarchy: Add logic for new field ENABLE_SELF_APPROVA
  --                                     9. post_approve_custom_wf: initiate new attribute IS_CUSTOM_PRE_APPROVE_EXISTS
  --
  --  1.4  01.01.2015  Michal Tzvik      CHG0033620:
  --                                     1. create_instance: Set SKIP_BUILD_HIERARCHY = 'N'
  --                                     2. Add procedure insert_custom_approvals
  --                                     3. check_user_action_wf: Support funcmode QUESTION and ANSWER
  --                                     4. Add PROCEDURE is_reference_link_exists
  --                   yuval tal         CHG0033620 :
  --                                     abort process : igonore abort wf process   if process not active
  --  1.5  13/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     new function get_last_approver_user_id
  --                                     chaneg logic at initiate_approval_process

  --  1.6  30.07.2015 Michal Tzvik       CHG0035411: add parameter p_note to PROCEDURE initiate_approval_process
  --  1.7  22-07-2019 Lingaraj          CHG0045539: modify check_user_action_wf - Item Creation Workflow
  --       30.4.19    yuval             CHG0045539  add re_route2role/approve
  --------------------------------------------------------------------
  -- Private constant declarations
  g_pkg_name     VARCHAR2(50) := 'xxobjt_wf_doc_util';
  g_item_type    VARCHAR2(50) := 'XXWFDOC';
  g_process_name VARCHAR2(50) := 'MAIN';

  -- 18.11.2014 Michal Tzvik CHG0031865
  c_status_error     CONSTANT VARCHAR2(15) := 'ERROR';
  c_status_inprocess CONSTANT VARCHAR2(15) := 'IN_PROCESS';

  c_debug_module CONSTANT VARCHAR2(100) := 'xxwf.document_approval.xxobjt_wf_doc_util.';

  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               set_doc_status
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           Handle failure in post custom:
  --                      1. Set recrd status = ERROR
  --                      2. Save error message in history table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   26/10/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE set_doc_status(p_status   IN VARCHAR2,
		   p_end_date IN DATE,
		   itemtype   IN VARCHAR2,
		   itemkey    IN VARCHAR2,
		   actid      IN NUMBER,
		   funcmode   IN VARCHAR2,
		   resultout  OUT NOCOPY VARCHAR2) IS
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
    l_his_rec          xxobjt_wf_doc_history%ROWTYPE;
  BEGIN
  
    -- UPDATE DOC INSTANCE
    IF funcmode = 'RUN' THEN
      l_doc_instance_upd.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
						itemkey  => itemkey,
						aname    => 'DOC_INSTANCE_ID');
      l_doc_instance_upd.wf_item_key     := itemkey;
      l_doc_instance_upd.doc_status      := p_status;
      l_doc_instance_upd.end_date        := p_end_date;
    
      update_instance(l_err_code, l_err_msg, l_doc_instance_upd);
    
      IF p_status = c_status_error THEN
        -- insert record in INFO status
        l_his_rec.action_code      := 'INFO';
        l_his_rec.role_name        := fnd_global.user_name;
        l_his_rec.action_date      := SYSDATE;
        l_his_rec.seq_no           := -2;
        l_his_rec.person_id        := fnd_global.employee_id;
        l_his_rec.doc_instance_id  := l_doc_instance_upd.doc_instance_id;
        l_his_rec.role_description := wf_directory.getroledisplayname(fnd_global.user_name);
        l_his_rec.note             := wf_engine.getitemattrtext(itemtype => itemtype,
					    itemkey  => itemkey,
					    aname    => 'ERR_MESSAGE');
        insert_history_record(l_err_code, l_err_msg, l_his_rec);
      END IF;
    
    END IF;
    resultout := wf_engine.eng_completed;
  
  END set_doc_status;

  ----------------------------------
  -- check_sql
  --
  -- check sql for custom post approve/reject  func and custom subject
  ----------------------------------

  PROCEDURE check_sql(p_sql VARCHAR2) IS
  
    l_val1 NUMBER;
    l_val2 VARCHAR2(1000); -- Michal Tzvik (change from 50 to 1000)
  
  BEGIN
    EXECUTE IMMEDIATE p_sql
      USING 1, OUT l_val1, OUT l_val2;
  
  END;
  ----------------------------------
  -- check_role_sql
  --
  -- check sql for dynamic role
  ----------------------------------

  PROCEDURE check_role_sql(p_sql VARCHAR2) IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(1000);
    l_role     VARCHAR2(50);
  BEGIN
    EXECUTE IMMEDIATE p_sql
      USING 1, OUT l_err_code, OUT l_err_msg, OUT l_role;
  
  END;

  ---------------------------------
  --  get_dynamic_role
  --
  -- get role name from sql
  -- out :
  -- p_out_role_name role_name for notification approval
  ---------------------------------
  PROCEDURE get_dynamic_role(p_err_code        OUT NUMBER,
		     p_err_msg         OUT VARCHAR2,
		     p_dynamic_role    VARCHAR2,
		     p_doc_instance_id NUMBER,
		     p_out_role_name   OUT VARCHAR2) IS
  
    l_sql_text xxobjt_wf_dyn_roles.sql_text%TYPE;
  
  BEGIN
    p_err_code := 0;
  
    SELECT t.sql_text
    INTO   l_sql_text
    FROM   xxobjt_wf_dyn_roles t
    WHERE  t.dynamic_role = p_dynamic_role;
  
    EXECUTE IMMEDIATE l_sql_text
      USING p_doc_instance_id, OUT p_err_code, OUT p_err_msg, OUT p_out_role_name;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_err_code := 1;
      p_err_msg  := 'Error:get_dynamic_role: Role Code ' || p_dynamic_role ||
	        ' does not exists';
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error:get_dynamic_role: dynamic_role=' ||
	        p_dynamic_role || ' doc_instance_id=' ||
	        p_doc_instance_id || p_err_msg || SQLERRM;
  END;

  --------------------------------------------------------------------
  --  name:            is_approved_by
  --  create by:       Yuval tal
  --  Revision:        1.1
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        check if role exists in approval history with APPROVE action
  --                   out : Y / N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --  1.1  17/07/2013  Dalit A. Raviv    add handle of person_id
  --                                     in case the role is position look at the person id
  --------------------------------------------------------------------
  FUNCTION is_approved_by(p_doc_instance_id NUMBER,
		  p_role_name       VARCHAR2,
		  p_person_id       NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
      FROM   xxobjt_wf_doc_history t
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    (t.role_name = p_role_name OR t.person_id = p_person_id) -- 17/07/2013
      AND    t.action_code = 'APPROVE';
  
    l_tmp VARCHAR2(1);
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'N');
  
  END;

  --------------------------------------------------------------------
  --  name:            get_next_approver_wf
  --  create by:       Yuval Tal
  --  Revision:        1.1
  --  creation date:   xxx
  --------------------------------------------------------------------
  --  purpose :        called from wf XXWFDOC
  --                   get next approver according to approval path generated at beginning of WF
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx          Yuval Tal         initial build
  --  1.1  17/07/2013  Dalit A. Raviv    add ability to pass level of approval (-2)
  --                                     mean that this level have no_action (skip it)
  --  1.2  30/09/2014  Michal Tzvik      CHG0031856: 1. Set value for xxobjt_wf_doc_instance.approver_person_id
  --  1.3  22/01/2015  Michal Tzvik      Fix bug: no_data_found when role_name is -2
  --------------------------------------------------------------------
  PROCEDURE get_next_approver_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2) IS
    l_err_code        NUMBER;
    l_err_msg         VARCHAR2(150);
    l_doc_instance_id NUMBER;
    l_current_seq     NUMBER;
    l_calc_role       VARCHAR2(50);
    l_role_exception EXCEPTION;
    l_approver_exists_flag VARCHAR2(1);
    l_from_role            VARCHAR2(50);
    l_his_rec              xxobjt_wf_doc_history%ROWTYPE;
  
    l_approver_person_id NUMBER; -- CHG0031856 30/09/2014  Michal Tzvik
    CURSOR c(c_instance_id NUMBER,
	 c_seq         NUMBER) IS
      SELECT *
      FROM   xxobjt_wf_doc_history_tmp h
      WHERE  h.doc_instance_id = c_instance_id
      AND    h.seq_no > c_seq
      ORDER  BY h.seq_no;
  BEGIN
    IF funcmode = 'RUN' THEN
    
      l_approver_exists_flag := 'N';
      l_current_seq          := wf_engine.getitemattrnumber(itemtype => itemtype,
					itemkey  => itemkey,
					aname    => 'CURRENT_SEQ_APPR');
      l_doc_instance_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
					itemkey  => itemkey,
					aname    => 'DOC_INSTANCE_ID');
    
      l_from_role := wf_engine.getitemattrtext(itemtype => itemtype,
			           itemkey  => itemkey,
			           aname    => 'FROM_ROLE');
    
      FOR i IN c(l_doc_instance_id, l_current_seq) LOOP
      
        l_calc_role            := ''; -- 1.3 22/01/2015 Michal Tzvik
        l_approver_exists_flag := 'Y';
        -- check dyn role
        IF i.dynamic_role IS NOT NULL AND i.online_calc_ind = 'Y' THEN
          get_dynamic_role(l_err_code,
		   l_err_msg,
		   i.dynamic_role,
		   l_doc_instance_id,
		   l_calc_role);
        
          IF l_err_code = 1 THEN
	wf_engine.setitemattrtext(itemtype => itemtype,
			  itemkey  => itemkey,
			  aname    => 'ERR_MESSAGE',
			  avalue   => l_err_msg);
	RAISE l_role_exception;
          END IF;
        
        END IF;
      
        l_calc_role := nvl(l_calc_role, i.role_name); -- 1.3 22/01/2015 Michal Tzvik
        -- CHG0031856  30/09/2014  Michal Tzvik: Get value for approval_person_id
        IF --nvl(l_calc_role, i.role_name) IS NOT NULL THEN
        -- 1.3  22/01/2015  Michal Tzvik Fix bug: no_data_found when role_name is -2 OR position
         nvl(l_calc_role, '-2') != '-2' AND l_calc_role NOT LIKE 'POS:%' THEN
          SELECT fu.employee_id
          INTO   l_approver_person_id
          FROM   fnd_user fu
          WHERE  fu.user_name = nvl(l_calc_role, i.role_name);
        END IF;
      
        -- set new approver/seq
        UPDATE xxobjt_wf_doc_instance d
        SET    d.current_seq_appr   = i.seq_no,
	   d.approver_person_id = l_approver_person_id -- CHG0031856  30/09/2014  Michal Tzvik
        WHERE  d.doc_instance_id = l_doc_instance_id;
        wf_engine.setitemattrnumber(itemtype => itemtype,
			itemkey  => itemkey,
			aname    => 'CURRENT_SEQ_APPR',
			avalue   => i.seq_no);
      
        wf_engine.setitemattrtext(itemtype => itemtype,
		          itemkey  => itemkey,
		          aname    => 'CURRENT_APPROVER',
		          avalue   => nvl(l_calc_role, i.role_name));
      
        -- insert record in waiting status
        l_his_rec.action_code           := 'WAITING';
        l_his_rec.dynamic_role          := i.dynamic_role;
        l_his_rec.role_name             := nvl(l_calc_role, i.role_name);
        l_his_rec.doc_instance_id       := l_doc_instance_id;
        l_his_rec.one_time_approval_ind := i.one_time_approval_ind;
        l_his_rec.seq_no                := i.seq_no;
        insert_history_record(l_err_code, l_err_msg, l_his_rec);
      
        --
        -- check for auto approve approver = prior approver/submit person
        --
        IF l_from_role = l_his_rec.role_name THEN
          /* wf_directory.getroleorigsysinfo(role           => l_from_role,
          orig_system    => l_orig_system,
          orig_system_id => l_person_id);*/
        
          fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_AUTO_SIGN_MSG');
          update_doc_history(l_err_code,
		     l_err_msg,
		     l_doc_instance_id,
		     fnd_global.employee_id,
		     'APPROVE',
		     l_his_rec.role_name,
		     fnd_message.get);
          --'Auto Sign: current approver equal prior approver
        
          l_approver_exists_flag := 'N';
          --
          --  check one time approval
          -- 17/07/2013 add param to is_approved_by
        ELSIF is_approved_by(l_doc_instance_id,
		     l_his_rec.role_name,
		     l_his_rec.person_id) = 'Y' AND
	  nvl(i.one_time_approval_ind, 'N') = 'Y' THEN
          fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_ONE_TIME_APP_MSG');
          update_doc_history(l_err_code,
		     l_err_msg,
		     l_doc_instance_id,
		     fnd_global.employee_id,
		     'APPROVE',
		     l_his_rec.role_name,
		     fnd_message.get); -- 'Auto Sign: User approved Document in the Past');
          l_approver_exists_flag := 'N';
        
          -- check ignore position
          --  1.1  17/07/2013  Dalit A. Raviv
        ELSIF l_his_rec.role_name = '-2' THEN
        
          update_doc_history(l_err_code,
		     l_err_msg,
		     l_doc_instance_id,
		     -2,
		     'NO_ACTION', -- 17/07/2013
		     l_his_rec.role_name,
		     i.note);
        
          l_approver_exists_flag := 'N';
        
        ELSE
          EXIT; -- exit loop
        END IF;
      
      END LOOP;
    
      resultout := wf_engine.eng_completed || ':' || l_approver_exists_flag;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
	          'get_next_approver_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          SQLERRM);
      RAISE;
    
  END;

  --------------------------------------------------------------------
  --  name:            build_approval_hierarchy
  --  create by:       Yuval Tal
  --  Revision:        1.1
  --  creation date:   xxx
  --------------------------------------------------------------------
  --  purpose :        called from wf XXWFDOC
  --                   build approval hierarchy
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx          Yuval Tal         initial build
  --  1.1  17/07/2013  Dalit A. Raviv    add ability to pass level of approval (-2)
  --  1.2  25/12/2014  Michal Tzvik      CHG0031856: Add logic for handling new field: ENABLE_SELF_APPROVAL
  --------------------------------------------------------------------
  PROCEDURE build_approval_hierarchy(p_err_code        OUT NUMBER,
			 p_err_msg         OUT VARCHAR2,
			 p_doc_instance_id NUMBER) IS
  
    CURSOR c_apr IS
      SELECT l.*,
	 s.doc_status,
	 -- 1.2  25/12/2014  Michal Tzvik
	 s.requestor_person_id,
	 fu.user_name requestor_user_name
      FROM   xxobjt_wf_appr_header  h,
	 xxobjt_wf_appr_lines   l,
	 xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance s,
	 -- 1.2  25/12/2014  Michal Tzvik
	 fnd_user fu
      WHERE  s.doc_id = d.doc_id
      AND    d.appr_id = h.appr_id
      AND    h.appr_id = l.appr_id
      AND    s.doc_instance_id = p_doc_instance_id
	-- 1.2  25/12/2014  Michal Tzvik
      AND    fu.user_id = s.user_id;
  
    l_calc_role VARCHAR2(50);
    l_in_process_exception EXCEPTION;
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(500);
  
    l_role_exception EXCEPTION;
  BEGIN
  
    p_err_code := 0;
    FOR i IN c_apr LOOP
      l_calc_role := NULL;
    
      IF c_apr%ROWCOUNT = 1 THEN
        DELETE FROM xxobjt_wf_doc_history_tmp t
        WHERE  t.doc_instance_id = p_doc_instance_id;
      
      END IF;
    
      -- build temp table
    
      -- check dyn
      IF i.dynamic_role IS NOT NULL AND nvl(i.online_calc_ind, 'N') = 'N' THEN
        get_dynamic_role(l_err_code,
		 l_err_msg,
		 i.dynamic_role,
		 p_doc_instance_id,
		 l_calc_role);
      
        IF l_err_code = 1 OR (l_calc_role IS NULL AND l_err_code <> -2) THEN
          p_err_msg := l_err_msg;
          RAISE l_role_exception;
        END IF;
      
      END IF;
    
      -- 1.2  25/12/2014  Michal Tzvik: start
      IF i.requestor_user_name = l_calc_role AND
         i.enable_self_approval = 'N' THEN
        BEGIN
          SELECT fu.user_name
          INTO   l_calc_role
          FROM   fnd_user fu
          WHERE  fu.employee_id =
	     xxhr_util_pkg.get_suppervisor_id(p_person_id      => i.requestor_person_id,
				  p_effective_date => trunc(SYSDATE),
				  p_bg_id          => 0);
        EXCEPTION
          WHEN OTHERS THEN
	p_err_msg := 'Failed to get approver''s suppervisor: ' ||
		 SQLERRM;
	RAISE l_role_exception;
        END;
      END IF;
      -- 1.2  25/12/2014  Michal Tzvik: end
    
      INSERT INTO xxobjt_wf_doc_history_tmp
        (doc_instance_id,
         seq_no,
         
         role_name,
         role_description,
         dynamic_role,
         online_calc_ind,
         one_time_approval_ind,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         note)
      
      VALUES
        (p_doc_instance_id,
         i.seq_no,
         decode(l_err_code,
	    -2,
	    to_char(l_err_code),
	    nvl(l_calc_role, i.role_name)), --  1.1  17/07/2013  Dalit A. Raviv
         NULL, -- i.role_description,
         i.dynamic_role,
         i.online_calc_ind,
         i.one_time_approval_ind,
         NULL,
         NULL,
         SYSDATE,
         fnd_global.user_id,
         NULL,
         decode(l_err_code, '-2', l_err_msg) --  1.1  17/07/2013  Dalit A. Raviv
         );
    
    --
    
    END LOOP;
  EXCEPTION
  
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error:build_approval_hierarchy:' || p_err_msg ||
	        SQLERRM;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               build_approval_hierarchy_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           called from wf XXWFDOC
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   13/11/2014    Michal Tzvik    CHG0031856: change resultout to sucsses/failed
  --                                      instead of completed.
  -----------------------------------------------------------------------
  PROCEDURE build_approval_hierarchy_wf(itemtype  IN VARCHAR2,
			    itemkey   IN VARCHAR2,
			    actid     IN NUMBER,
			    funcmode  IN VARCHAR2,
			    resultout OUT NOCOPY VARCHAR2) IS
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(255);
    l_doc_instance_id NUMBER;
    l_xx_internal_exception EXCEPTION;
  BEGIN
  
    resultout := wf_engine.eng_completed || ':' || 'SUCCESS';
  
    l_doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOC_INSTANCE_ID');
    build_approval_hierarchy(l_err_code, l_err_message, l_doc_instance_id);
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'SUCCESS';
    
    ELSE
    
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => l_err_message);
      RAISE l_xx_internal_exception;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => substr(l_err_message, 1, 255));
      wf_core.context(g_pkg_name,
	          'build_approval_hierarchy_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          l_err_message || ' ' || SQLERRM);
      --  RAISE;
  END build_approval_hierarchy_wf;
  ---------------------------------
  -- get_doc_id
  ---------------------------------
  FUNCTION get_doc_id(p_doc_code VARCHAR2) RETURN NUMBER IS
    l_doc_id NUMBER;
  BEGIN
  
    SELECT doc_id
    INTO   l_doc_id
    FROM   xxobjt_wf_docs t
    WHERE  t.doc_code = p_doc_code;
    RETURN l_doc_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ---------------------------------
  -- get_dynamic_role_desc
  ---------------------------------
  FUNCTION get_dynamic_role_desc(p_dyn_role_code VARCHAR2) RETURN VARCHAR2 IS
    l_name xxobjt_wf_dyn_roles.name%TYPE;
  BEGIN
    SELECT NAME
    INTO   l_name
    FROM   xxobjt_wf_dyn_roles t
    WHERE  t.dynamic_role = p_dyn_role_code
    AND    nvl(t.enable_ind, 'N') = 'Y';
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  ---------------------------------
  -- get_doc_info
  ---------------------------------
  FUNCTION get_doc_info(p_doc_id NUMBER) RETURN xxobjt_wf_docs%ROWTYPE IS
    l_rec xxobjt_wf_docs%ROWTYPE;
  BEGIN
  
    SELECT *
    INTO   l_rec
    FROM   xxobjt_wf_docs t
    WHERE  t.doc_id = p_doc_id;
  
    RETURN l_rec;
  END;
  ---------------------------------
  -- get_doc_name
  ---------------------------------
  FUNCTION get_doc_name(p_doc_id NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
    RETURN get_doc_info(p_doc_id).doc_name;
  
  END;
  ---------------------------------
  -- get_doc_instance_id
  ---------------------------------
  FUNCTION get_doc_instance_id RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT xxobjt_wf_doc_instance_seq.nextval
    INTO   l_tmp
    FROM   dual;
  
    RETURN l_tmp;
  
  END;

  ---------------------------------
  -- get_doc_instance_info
  ---------------------------------

  FUNCTION get_doc_instance_info(p_doc_instance_id NUMBER)
    RETURN xxobjt_wf_doc_instance%ROWTYPE IS
    l_rec xxobjt_wf_doc_instance%ROWTYPE;
  BEGIN
  
    SELECT *
    INTO   l_rec
    FROM   xxobjt_wf_doc_instance
    WHERE  doc_instance_id = p_doc_instance_id;
  
    RETURN l_rec;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ---------------------------------
  -- get_doc_status_desc
  ---------------------------------

  FUNCTION get_doc_status_desc(p_doc_instance_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(15);
  BEGIN
  
    SELECT doc_status
    INTO   l_tmp
    FROM   xxobjt_wf_doc_instance
    WHERE  doc_instance_id = p_doc_instance_id;
  
    RETURN xxobjt_general_utils_pkg.get_valueset_desc('XXOBJT_WF_DOC_STATUS',
				      l_tmp);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ---------------------------------
  -- get_doc_status
  ---------------------------------

  FUNCTION get_doc_status(p_doc_instance_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(15);
  BEGIN
  
    SELECT doc_status
    INTO   l_tmp
    FROM   xxobjt_wf_doc_instance
    WHERE  doc_instance_id = p_doc_instance_id;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               initiate_approval_process
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           called from wf XXWFDOC
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   13/11/2014    Michal Tzvik    CHG0031856:
  --                                      1. Move call to "update_instance" from initiate_approval_process
  --                                         to build_approval_hierarchy_wf in order to handle bug: status is not chandeg to APPROVED in autosign
  --                                      2. Initiate new attribute: IS_CUSTOM_PRE_APPROVE_EXISTS
  --  1.2   29/12/2014    Michal Tzvik    CHG0033620:
  --                                      1. Initiate new attributes: XX_ATTACHMENT, SKIP_BUILD_HIERARCHY, #HIDE_MOREINFO
  --  1.3   13/07/2015    Dalit A. Raviv  CHG0035495 - Workflow for credit check Hold on SO

  --  1.6   30/07/2015    Michal Tzvik    CHG0035411: add parameter p_note. It will be displayed in notifications.
  -----------------------------------------------------------------------
  PROCEDURE initiate_approval_process(p_err_code        OUT NUMBER,
			  p_err_msg         OUT VARCHAR2,
			  p_doc_instance_id NUMBER,
			  p_wf_item_key     OUT VARCHAR2,
			  p_note            IN VARCHAR2 DEFAULT NULL -- 1.6 CHG0035411 Michal Tzvik 30.07.2015
			  ) IS
  
    l_doc_rec      xxobjt_wf_docs%ROWTYPE;
    l_his_rec      xxobjt_wf_doc_history%ROWTYPE;
    l_instance_rec xxobjt_wf_doc_instance%ROWTYPE;
    --l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_subject VARCHAR2(500);
    my_exception EXCEPTION;
  
    l_err_code       NUMBER;
    l_err_msg        VARCHAR2(1000);
    l_requestor_role VARCHAR2(50);
    l_creator_role   VARCHAR2(50);
    l_role_desc      VARCHAR2(200);
  BEGIN
    p_err_code := 0;
    p_err_msg  := '';
  
    IF p_doc_instance_id IS NULL THEN
      p_err_msg := 'Instance id is null';
      RAISE my_exception;
    END IF;
  
    -- get info
  
    l_instance_rec := get_doc_instance_info(p_doc_instance_id);
  
    -- check role
    wf_directory.getusername(p_orig_system    => 'PER',
		     p_orig_system_id => l_instance_rec.creator_person_id,
		     p_name           => l_creator_role,
		     p_display_name   => l_role_desc);
  
    IF l_creator_role IS NULL THEN
      p_err_msg := 'Creator role is not valid for person id = ' ||
	       l_instance_rec.creator_person_id;
      RAISE my_exception;
    END IF;
  
    wf_directory.getusername(p_orig_system    => 'PER',
		     p_orig_system_id => l_instance_rec.requestor_person_id,
		     p_name           => l_requestor_role,
		     p_display_name   => l_role_desc);
  
    IF l_requestor_role IS NULL THEN
      p_err_msg := 'Requestor role is not valid for person id = ' ||
	       l_instance_rec.requestor_person_id;
      RAISE my_exception;
    END IF;
  
    -- check doc_id
    IF l_instance_rec.doc_id IS NULL THEN
      p_err_msg := 'Doc instance no ' || p_doc_instance_id || ' not found';
      RAISE my_exception;
    END IF;
    l_doc_rec := get_doc_info(l_instance_rec.doc_id);
    -- check status
    IF nvl(l_instance_rec.doc_status, 'NEW') IN ('APPROVED', 'IN_PROCESS') THEN
    
      p_err_msg := 'Unable to submit Doc In status Approved/In process';
    
      RAISE my_exception;
    
    END IF;
  
    --
    SELECT xxobjt_wf_doc_item_key_seq.nextval
    INTO   p_wf_item_key
    FROM   dual;
  
    wf_engine.createprocess(itemtype   => g_item_type,
		    itemkey    => p_wf_item_key,
		    user_key   => p_doc_instance_id,
		    owner_role => fnd_global.user_name,
		    process    => g_process_name);
  
    --  genetal attribute init
    IF l_doc_rec.custom_subject_func IS NOT NULL THEN
      BEGIN
        EXECUTE IMMEDIATE l_doc_rec.custom_subject_func
          USING l_instance_rec.doc_instance_id, OUT l_err_code, OUT l_subject;
      EXCEPTION
      
        WHEN OTHERS THEN
        
          p_err_msg := 'Bad Dynamic Subject Generation ' || SQLERRM;
          RAISE my_exception;
      END;
    ELSE
      l_subject := l_doc_rec.doc_name;
    END IF;
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SUBJECT_MESSAGE',
		      avalue   => l_subject);
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SEND_REQUESTOR_APR',
		      avalue   => nvl(l_doc_rec.send_apr_requestor,
			          'N'));
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SEND_REQUESTOR_REJECT',
		      avalue   => nvl(l_doc_rec.send_reject_requestor,
			          'N'));
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SEND_CREATOR_REJECT',
		      avalue   => nvl(l_doc_rec.send_reject_creator,
			          'N'));
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SEND_CREATOR_APR',
		      avalue   => nvl(l_doc_rec.send_apr_creator,
			          'N'));
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'WF_ADMINISTRATOR',
		      avalue   => nvl(l_doc_rec.admin_owner_role,
			          'SYSADMIN')); -- 17.07.2014 Michal Tzvik: Add nvl
  
    wf_engine.setitemattrnumber(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'DOC_INSTANCE_ID',
		        avalue   => p_doc_instance_id);
  
    wf_engine.setitemattrnumber(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'DOC_ID',
		        avalue   => l_instance_rec.doc_id);
  
    IF instr(lower(l_doc_rec.notification_function), 'jsp:') > 0 THEN
      -- 1.3 13/07/2015 Dalit A. Raviv
      -- CHG0035495 - Workflow for credit check Hold on SO
      IF instr(lower(l_doc_rec.notification_function), '?') > 0 THEN
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => p_wf_item_key,
		          aname    => 'FWK_FUNCTION',
		          avalue   => l_doc_rec.notification_function ||
			          '&DocInstanceId=' ||
			          p_doc_instance_id);
      
        -- handle #History
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => p_wf_item_key,
		          aname    => '#HISTORY',
		          avalue   => 'JSP:/OA_HTML/OA.jsp?OAFunc=XXOBJT_WF_DOC_APP_HIST' ||
			          '&DocInstanceId=' ||
			          p_doc_instance_id);
      ELSE
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => p_wf_item_key,
		          aname    => 'FWK_FUNCTION',
		          avalue   => l_doc_rec.notification_function ||
			          '?DocInstanceId=' ||
			          p_doc_instance_id);
      
        -- handle #History
        wf_engine.setitemattrtext(itemtype => g_item_type,
		          itemkey  => p_wf_item_key,
		          aname    => '#HISTORY',
		          avalue   => 'JSP:/OA_HTML/OA.jsp?OAFunc=XXOBJT_WF_DOC_APP_HIST' ||
			          '?DocInstanceId=' ||
			          p_doc_instance_id);
      END IF;
    
    ELSE
      wf_engine.setitemattrtext(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'FWK_FUNCTION',
		        avalue   => l_doc_rec.notification_function || '/' ||
			        p_doc_instance_id);
    
    END IF;
  
    wf_engine.setitemattrnumber(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'CURRENT_SEQ_APPR',
		        avalue   => 0);
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'CREATOR_ROLE',
		      avalue   => l_creator_role);
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'REQUESTOR_ROLE',
		      avalue   => l_requestor_role);
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'FROM_ROLE',
		      avalue   => fnd_global.user_name); --FND_GLOBAL.USER_NAME);
  
    -- 28.12.2014 Michal Tzvik CHG0031856: Start
    IF l_doc_rec.custom_pre_apr_func IS NULL THEN
      wf_engine.setitemattrtext(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'IS_CUSTOM_PRE_APPROVE_EXISTS',
		        avalue   => 'N');
    ELSE
      wf_engine.setitemattrtext(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'IS_CUSTOM_PRE_APPROVE_EXISTS',
		        avalue   => 'Y');
    END IF;
    -- CHG0031856: End
  
    -- 29.12.2014 Michal Tzvik CHG00330620: Start
    IF l_doc_rec.attachment_function IS NOT NULL THEN
      wf_engine.setitemattrtext(itemtype => g_item_type,
		        itemkey  => p_wf_item_key,
		        aname    => 'XX_ATTACHMENT',
		        avalue   => l_doc_rec.attachment_function || '/' ||
			        p_doc_instance_id);
    END IF;
  
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => 'SKIP_BUILD_HIERARCHY',
		      avalue   => nvl(l_instance_rec.skip_build_hierarchy,
			          'N'));
    wf_engine.setitemattrtext(itemtype => g_item_type,
		      itemkey  => p_wf_item_key,
		      aname    => '#HIDE_MOREINFO',
		      avalue   => nvl(l_doc_rec.hide_moreinfo, 'N'));
  
    -- CHG00330620: End
  
    -- insert history
    l_his_rec.action_code      := 'SUBMIT';
    l_his_rec.role_name        := fnd_global.user_name;
    l_his_rec.action_date      := SYSDATE;
    l_his_rec.seq_no           := -1;
    l_his_rec.person_id        := fnd_global.employee_id;
    l_his_rec.doc_instance_id  := p_doc_instance_id;
    l_his_rec.role_description := wf_directory.getroledisplayname(fnd_global.user_name);
    l_his_rec.note             := substr(p_note, 1, 500); -- 1.6 Michal Tzvik CHG0035411
    -- xxhr_util_pkg.get_person_full_name(fnd_global.employee_id);
  
    insert_history_record(l_err_code, l_err_msg, l_his_rec);
    COMMIT;
    -- dbms_lock.sleep(1);
    wf_engine.startprocess(itemtype => g_item_type,
		   itemkey  => p_wf_item_key);
  
    COMMIT;
  
    /*  -- CHG0031856  Michal Tzvik 13.11.2014: Move this code to function build_approval_hierarchy_wf
        -- update doc instance
        l_doc_instance_upd.wf_item_key      := p_wf_item_key;
        l_doc_instance_upd.doc_status       := 'IN_PROCESS';
        l_doc_instance_upd.start_date       := SYSDATE;
        l_doc_instance_upd.end_date         := NULL;
        l_doc_instance_upd.doc_instance_id  := p_doc_instance_id;
        l_doc_instance_upd.current_seq_appr := 0;
        update_instance(l_err_code, l_err_msg, l_doc_instance_upd);
        COMMIT;
    */
    p_err_msg := 'Document Submitted Successfully.';
  EXCEPTION
  
    WHEN my_exception THEN
      p_err_code := 1;
      p_err_msg  := 'Error:initiate_process:' || p_err_msg;
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error:initiate_process:' || p_err_msg || SQLERRM;
    
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               end_main_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           Update table xxobjt_wf_doc_instance
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   19/11/2014    Michal Tzvik    CHG0031856: Change assignment to start_date and end_date fields
  --  1.2   03/02/2015    Michal Tzvik    Bug fix: upate user_id, resp_id, resp_appl_id
  -----------------------------------------------------------------------
  PROCEDURE update_instance(p_err_code            OUT NUMBER,
		    p_err_msg             OUT VARCHAR2,
		    p_doc_instance_header IN OUT xxobjt_wf_doc_instance%ROWTYPE) IS
  
    l_required_field EXCEPTION;
  
  BEGIN
    p_err_code := 0;
    p_err_msg  := '';
  
    IF p_doc_instance_header.doc_instance_id IS NULL THEN
      p_err_msg := 'Doc instance id is reqiured';
      RAISE l_required_field;
    END IF;
    --
  
    UPDATE xxobjt_wf_doc_instance x
    SET    x.last_update_date = SYSDATE,
           x.wf_item_key      = nvl(p_doc_instance_header.wf_item_key,
			x.wf_item_key),
           x.last_updated_by  = fnd_global.user_id,
           x.doc_status       = nvl(p_doc_instance_header.doc_status,
			x.doc_status),
           
           x.start_date = nvl(nvl(p_doc_instance_header.start_date,
		          x.start_date),
		      SYSDATE), -- CHG0031856 Michal Tzvik 19.11.2014: add nvl with sysdate
           x.end_date   = decode(p_doc_instance_header.doc_status,
		         'APPROVED',
		         SYSDATE, /*NULL*/
		         p_doc_instance_header.end_date), -- CHG0031856 Michal Tzvik 19.11.2014: replace NULL with parameter, since it must be populated at end of the process, no matter what is the status (ERROR, REJECTED...)
           
           requestor_person_id = nvl(p_doc_instance_header.requestor_person_id,
			 x.requestor_person_id),
           creator_person_id   = nvl(p_doc_instance_header.creator_person_id,
			 x.creator_person_id),
           x.current_seq_appr  = nvl(p_doc_instance_header.current_seq_appr,
			 x.current_seq_appr),
           x.appr_id           = nvl(p_doc_instance_header.appr_id,
			 x.appr_id),
           x.n_attribute1      = nvl(p_doc_instance_header.n_attribute1,
			 x.n_attribute1),
           x.n_attribute2      = nvl(p_doc_instance_header.n_attribute2,
			 x.n_attribute2),
           x.n_attribute3      = nvl(p_doc_instance_header.n_attribute3,
			 x.n_attribute3),
           x.n_attribute4      = nvl(p_doc_instance_header.n_attribute4,
			 x.n_attribute4),
           x.n_attribute5      = nvl(p_doc_instance_header.n_attribute5,
			 x.n_attribute5),
           x.attribute1        = nvl(p_doc_instance_header.attribute1,
			 x.attribute1),
           x.attribute2        = nvl(p_doc_instance_header.attribute2,
			 x.attribute2),
           x.attribute3        = nvl(p_doc_instance_header.attribute3,
			 x.attribute3),
           x.attribute4        = nvl(p_doc_instance_header.attribute4,
			 x.attribute4),
           x.attribute5        = nvl(p_doc_instance_header.attribute5,
			 x.attribute5),
           x.attribute6        = nvl(p_doc_instance_header.attribute6,
			 x.attribute6),
           x.attribute7        = nvl(p_doc_instance_header.attribute7,
			 x.attribute7),
           x.attribute8        = nvl(p_doc_instance_header.attribute8,
			 x.attribute8),
           x.attribute9        = nvl(p_doc_instance_header.attribute9,
			 x.attribute9),
           x.attribute10       = nvl(p_doc_instance_header.attribute10,
			 x.attribute10),
           x.d_attribute1      = nvl(p_doc_instance_header.d_attribute1,
			 x.d_attribute1),
           x.d_attribute2      = nvl(p_doc_instance_header.d_attribute2,
			 x.d_attribute2),
           x.d_attribute3      = nvl(p_doc_instance_header.d_attribute3,
			 x.d_attribute3),
           --  1.2   03/02/2015    Michal Tzvik
           x.user_id      = nvl(x.user_id, fnd_global.user_id),
           x.resp_id      = nvl(x.resp_id, fnd_global.resp_id),
           x.resp_appl_id = nvl(x.resp_appl_id, fnd_global.resp_appl_id)
    WHERE  x.doc_instance_id = p_doc_instance_header.doc_instance_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error: update_instance:' || p_err_msg || SQLERRM;
  END update_instance;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               create_instance
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   17/07/2014    Michal Tzvik    CHG0031856: add fields to table xxobjt_wf_doc_instance:
  --                                      user_id, resp_id, resp_appl_id
  --  1.2   01/01/2015    Michal Tzvik    CHG0033620: Set SKIP_BUILD_HIERARCHY = 'N'
  --                                      Change validation on requestor_person_id and creator_person_id
  -----------------------------------------------------------------------
  PROCEDURE create_instance(p_err_code            OUT NUMBER,
		    p_err_msg             OUT VARCHAR2,
		    p_doc_instance_header IN OUT xxobjt_wf_doc_instance%ROWTYPE,
		    p_doc_code            VARCHAR2 DEFAULT NULL) IS
  
    l_doc_info_rec     xxobjt_wf_docs%ROWTYPE;
    l_doc_instance_rec xxobjt_wf_doc_instance%ROWTYPE;
    l_required_field EXCEPTION;
    --  l_err_message VARCHAR2(200);
  BEGIN
    p_err_code := 0;
    p_err_msg  := '';
  
    -- check doc status
    IF p_doc_instance_header.doc_instance_id IS NOT NULL THEN
      l_doc_instance_rec := get_doc_instance_info(p_doc_instance_header.doc_instance_id);
      IF l_doc_instance_rec.doc_status IN ('APPROVED', 'IN_PROCESS') THEN
      
        p_err_code := 1;
        p_err_msg  := 'Action Failed , Document already in status ' ||
	          l_doc_instance_rec.doc_status;
        RETURN;
      END IF;
    END IF;
    -- check required
    IF p_doc_code IS NOT NULL THEN
      p_doc_instance_header.doc_id := get_doc_id(p_doc_code);
      IF p_doc_instance_header.doc_id IS NULL THEN
        p_err_msg := 'Doc Code Is not Valid';
        RAISE l_required_field;
      END IF;
    END IF;
  
    --    IF p_doc_instance_header.requestor_person_id IS NULL THEN
    IF nvl(p_doc_instance_header.requestor_person_id, -1) = -1 THEN
      -- 1.2 Michal Tzvik 27.01.2015: change condition because fnd_global.employee id=-1 when apps is not initialized
      fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_FIELD_REQUIRED');
      fnd_message.set_token('FIELD', 'requestor');
      p_err_msg := fnd_message.get;
      RAISE l_required_field;
    END IF;
  
    --    IF p_doc_instance_header.creator_person_id IS NULL THEN
    IF nvl(p_doc_instance_header.creator_person_id, -1) = -1 THEN
      -- 1.2 Michal Tzvik 27.01.2015: change condition because fnd_global.employee id=-1 when apps is not initialized
      fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_FIELD_REQUIRED');
      fnd_message.set_token('FIELD', 'Creator');
      p_err_msg := fnd_message.get;
      RAISE l_required_field;
    END IF;
  
    IF p_doc_instance_header.doc_id IS NULL THEN
      fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_FIELD_REQUIRED');
      fnd_message.set_token('FIELD', 'Doc Id');
      p_err_msg := fnd_message.get;
      RAISE l_required_field;
    END IF;
  
    IF p_doc_instance_header.doc_instance_id IS NULL THEN
      p_doc_instance_header.doc_instance_id := get_doc_instance_id();
      -- get doc_id info
      l_doc_info_rec := get_doc_info(p_doc_instance_header.doc_id);
    
    END IF;
  
    BEGIN
    
      INSERT INTO xxobjt_wf_doc_instance
        (doc_instance_id,
         doc_id,
         doc_status,
         requestor_person_id,
         creator_person_id,
         org_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         appr_id,
         n_attribute1,
         n_attribute2,
         n_attribute3,
         n_attribute4,
         n_attribute5,
         attribute1,
         attribute2,
         attribute3,
         attribute4,
         attribute5,
         attribute6,
         attribute7,
         attribute8,
         attribute9,
         attribute10,
         d_attribute1,
         d_attribute2,
         d_attribute3,
         -- CHG0031856 17.07.2014 Michal Tzvik
         user_id,
         resp_id,
         resp_appl_id,
         --CHG0033620  01.01.2015 Michal Tzvik
         skip_build_hierarchy)
      VALUES
        (p_doc_instance_header.doc_instance_id,
         p_doc_instance_header.doc_id,
         'NEW', -- doc_status,
         
         p_doc_instance_header.requestor_person_id,
         p_doc_instance_header.creator_person_id,
         fnd_global.org_id,
         SYSDATE,
         fnd_global.user_id,
         SYSDATE,
         fnd_global.user_id,
         fnd_global.login_id,
         l_doc_info_rec.appr_id,
         p_doc_instance_header.n_attribute1,
         p_doc_instance_header.n_attribute2,
         p_doc_instance_header.n_attribute3,
         p_doc_instance_header.n_attribute4,
         p_doc_instance_header.n_attribute5,
         p_doc_instance_header.attribute1,
         p_doc_instance_header.attribute2,
         p_doc_instance_header.attribute3,
         p_doc_instance_header.attribute4,
         p_doc_instance_header.attribute5,
         p_doc_instance_header.attribute6,
         p_doc_instance_header.attribute7,
         p_doc_instance_header.attribute8,
         p_doc_instance_header.attribute9,
         p_doc_instance_header.attribute10,
         p_doc_instance_header.d_attribute1,
         p_doc_instance_header.d_attribute2,
         p_doc_instance_header.d_attribute3,
         -- CHG0031856 17.07.2014 Michal Tzvik
         nvl(p_doc_instance_header.user_id, fnd_global.user_id),
         nvl(p_doc_instance_header.resp_id, fnd_global.resp_appl_id),
         nvl(p_doc_instance_header.resp_appl_id, fnd_global.resp_appl_id),
         --CHG0033620  01.01.2015 Michal Tzvik
         'N' -- SKIP_BUILD_HIERARCHY
         );
    
    EXCEPTION
      WHEN dup_val_on_index THEN
        p_doc_instance_header.appr_id := l_doc_info_rec.appr_id;
      
        update_instance(p_err_code            => p_err_code,
		p_err_msg             => p_err_msg,
		p_doc_instance_header => p_doc_instance_header);
      
    END;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error: create_instance:' || p_err_msg || SQLERRM;
  END;
  ---------------------------------
  -- abort_process
  ----------------------------------------------------------------------
  --  ver   date         name             desc
  --  1.1   16.2.2015    yuval tal        CHG0033620 add exception to wf_engine.abortprocess
  -----------------------------------------------------------------------
  PROCEDURE abort_process(p_err_code        OUT NUMBER,
		  p_err_msg         OUT VARCHAR2,
		  p_doc_instance_id NUMBER) IS
    l_instance_rec xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code     NUMBER;
    l_err_msg      VARCHAR2(200);
    l_his_rec      xxobjt_wf_doc_history%ROWTYPE;
  BEGIN
    p_err_code     := 0;
    p_err_msg      := 'Process aborted successfuly';
    l_instance_rec := get_doc_instance_info(p_doc_instance_id);
  
    BEGIN
      --CHG0033620
      wf_engine.abortprocess(g_item_type, l_instance_rec.wf_item_key);
    
    EXCEPTION
      --CHG0033620
      WHEN OTHERS THEN
        IF instr(SQLERRM, 'is not active.') > 0 THEN
          NULL;
        ELSE
          RAISE;
        END IF;
    END; -- CHG0033620
  
    -- close all waiting history lines
    -- update_doc_history
    update_doc_history(p_err_code,
	           p_err_msg,
	           p_doc_instance_id,
	           fnd_global.employee_id,
	           'NO_ACTION',
	           fnd_global.user_name);
    -- insert history
  
    l_his_rec.note            := NULL;
    l_his_rec.action_code     := 'CANCEL';
    l_his_rec.role_name       := fnd_global.user_name;
    l_his_rec.action_date     := SYSDATE;
    l_his_rec.doc_instance_id := p_doc_instance_id;
  
    insert_history_record(l_err_code, l_err_msg, l_his_rec);
    --
  
    l_instance_rec.doc_status := 'CANCELLED';
    l_instance_rec.end_date   := SYSDATE;
  
    update_instance(p_err_code, p_err_msg, l_instance_rec);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Abort Failed :' || SQLERRM;
  END;
  ---------------------------------
  -- update_doc_instance_status
  ---------------------------------
  PROCEDURE update_doc_instance_status(p_err_code        OUT NUMBER,
			   p_err_msg         OUT VARCHAR2,
			   p_doc_instance_id NUMBER,
			   p_doc_status      VARCHAR2) IS
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
  
    UPDATE xxobjt_wf_doc_instance t
    SET    t.doc_status       = p_doc_status,
           t.end_date         = decode(p_doc_status,
			   'APPROVED',
			   SYSDATE,
			   NULL),
           t.last_update_date = SYSDATE,
           t.last_updated_by  = fnd_global.user_id
    WHERE  t.doc_instance_id = p_doc_instance_id;
  
  EXCEPTION
  
    WHEN OTHERS THEN
    
      p_err_code := 1;
      p_err_msg  := SQLERRM;
  END;

  ---------------------------------
  -- update_doc_instance_key
  ---------------------------------
  PROCEDURE update_doc_instance_key(p_err_code        OUT NUMBER,
			p_err_msg         OUT VARCHAR2,
			p_doc_instance_id NUMBER,
			p_wf_item_key     VARCHAR2) IS
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
  
    UPDATE xxobjt_wf_doc_instance t
    SET    t.wf_item_key      = p_wf_item_key,
           t.last_update_date = SYSDATE,
           t.last_updated_by  = fnd_global.user_id
    WHERE  t.doc_instance_id = p_doc_instance_id;
  
  EXCEPTION
  
    WHEN OTHERS THEN
    
      p_err_code := 1;
      p_err_msg  := SQLERRM;
  END;

  ---------------------------------
  -- insert_history_record
  ---------------------------------
  PROCEDURE insert_history_record(p_err_code OUT NUMBER,
		          p_err_msg  OUT VARCHAR2,
		          p_his_rec  xxobjt_wf_doc_history%ROWTYPE) IS
  BEGIN
  
    p_err_code := 0;
    p_err_msg  := NULL;
    INSERT INTO xxobjt_wf_doc_history
      (doc_instance_id,
       action_code,
       person_id,
       role_name,
       role_description,
       action_date,
       note,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       dynamic_role,
       seq_no)
    VALUES
      (p_his_rec.doc_instance_id,
       p_his_rec.action_code,
       p_his_rec.person_id,
       p_his_rec.role_name,
       wf_directory.getroledisplayname(p_his_rec.role_name), -- p_his_rec.role_description,
       p_his_rec.action_date,
       p_his_rec.note,
       fnd_global.user_id,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.login_id,
       p_his_rec.dynamic_role,
       p_his_rec.seq_no);
  EXCEPTION
  
    WHEN OTHERS THEN
      p_err_code := 0;
      p_err_msg  := 'Error in  insert_history_record :' || SQLERRM;
  END;

  ---------------------------------
  -- update_doc_history
  ---------------------------------
  PROCEDURE update_doc_history(p_err_code        OUT NUMBER,
		       p_err_msg         OUT VARCHAR2,
		       p_doc_instance_id NUMBER,
		       p_person_id       NUMBER,
		       p_action_code     VARCHAR2,
		       p_context_user    VARCHAR2,
		       p_note            VARCHAR2 DEFAULT NULL) IS
    my_exception EXCEPTION;
  
  BEGIN
  
    p_err_code := 0;
    p_err_msg  := NULL;
    UPDATE xxobjt_wf_doc_history t
    SET    t.action_date      = SYSDATE,
           t.action_code      = p_action_code,
           t.person_id        = p_person_id,
           t.last_update_date = SYSDATE,
           t.context_user     = p_context_user,
           t.last_updated_by  = fnd_global.user_id,
           note               = t.note ||
		        decode(TRIM(p_note),
			   NULL,
			   NULL,
			   ' ' || TRIM(p_note))
    WHERE  t.doc_instance_id = p_doc_instance_id
          
    AND    t.action_code = 'WAITING';
    /* AND fnd_global.employee_id IN
    (SELECT x.user_orig_system_id
       FROM wf_user_roles x
      WHERE x.role_name = t.role_name);*/
  
    IF SQL%NOTFOUND THEN
      p_err_msg := 'No record found in history table in status waiting for current approver';
      RAISE my_exception;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error in update_doc_history :' || p_err_msg || ' ' ||
	        SQLERRM;
  END;

  --------------------------------------------------------------------
  --  name:            check_user_action_wf
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   xxx
  --------------------------------------------------------------------
  --  purpose :        called from wf XXWFDOC
  --                   handle user action in approval notification
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx          Yuval Tal         initial build
  --  1.1  06/11/2014  Michal Tzvik      CHG0031856: Avoid user from approving his request by getting to "Notifications From Me" in Worklist
  --  1.2  01/02/2015  Michal Tzvik      CHG0033620: Support QUESTION and ANSWER
  --  1.3  22-Apr-2019 Lingaraj          CHG0045539: use new flag  to allow requestor to approve
  --                                                 exec dyn sql after user approval
  --                    yuval tal                    modify forwad section
  -------------------------------------------------------------------
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2) IS
  
    l_doc_instance_id NUMBER;
    l_nid             NUMBER;
    l_result          VARCHAR2(500);
    --  l_person_id       NUMBER;
    --l_orig_system VARCHAR2(30);
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(200);
    l_his_rec  xxobjt_wf_doc_history%ROWTYPE;
  
    -- CHG0031856 Michal Tzvik 06.11.2014
    l_approver_username   VARCHAR2(100);
    l_requestor_person_id NUMBER;
    l_approver_person_id  NUMBER;
  
    --
    l_context_text               VARCHAR2(100);
    l_context_user               VARCHAR2(100);
    l_context_original_recipient VARCHAR2(100);
    l_context_new_role           VARCHAR2(100);
    l_context_from_role          VARCHAR2(100);
    l_context_recipient_role     VARCHAR2(100);
  
    l_proc_name VARCHAR2(50) := 'check_user_action_wf';
    -- Begin CHG0045539
    l_sql               xxobjt_wf_docs.custom_after_apr_func%TYPE;
    l_forward_person_id NUMBER; --CHG0045539
    CURSOR c_sql IS
      SELECT d.custom_post_user_apr_func
      FROM   xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance i
      WHERE  i.doc_id = d.doc_id
      AND    i.doc_instance_id = l_doc_instance_id;
  
    l_requestor_can_approve VARCHAR2(1);
    -- End CHG0045539
  BEGIN
  
    l_nid    := wf_engine.context_nid;
    l_result := wf_notification.getattrtext(l_nid, 'RESULT');
  
    l_doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOC_INSTANCE_ID');
  
    -- 12.02.2015 Michal Tzvik: Move this code to here, before "IF funcmode=..."
    -- context_user =email:Yuval.Tal@stratasys.com -- when answer from mail
    l_approver_username := upper(REPLACE(REPLACE(upper(wf_engine.context_new_role) /*context_user*/,
				 'EMAIL:'),
			     '@STRATASYS.COM')); -- 12.02.2015 Michal Tzvik: replace context_user with context_new_role
  
    -- 12.02.2015 Michal Tzvik
    l_context_recipient_role     := upper(REPLACE(REPLACE(upper(wf_engine.context_recipient_role),
				          'EMAIL:'),
				  '@STRATASYS.COM'));
    l_context_text               := upper(REPLACE(REPLACE(upper(wf_engine.context_text),
				          'EMAIL:'),
				  '@STRATASYS.COM'));
    l_context_user               := upper(REPLACE(REPLACE(upper(wf_engine.context_user),
				          'EMAIL:'),
				  '@STRATASYS.COM'));
    l_context_original_recipient := upper(REPLACE(REPLACE(upper(wf_engine.context_original_recipient),
				          'EMAIL:'),
				  '@STRATASYS.COM'));
    l_context_from_role          := upper(REPLACE(REPLACE(upper(wf_engine.context_from_role),
				          'EMAIL:'),
				  '@STRATASYS.COM'));
    l_context_new_role           := l_approver_username;
  
    l_approver_person_id := fnd_global.employee_id;
    -- CHG0031856 Michal Tzvik 06.11.2014: Start (1)
    IF nvl(l_approver_person_id, -1) < 0 THEN
      BEGIN
        SELECT fu.employee_id
        INTO   l_approver_person_id
        FROM   fnd_user fu
        WHERE  fu.user_name = l_approver_username;
        /*EXCEPTION
        WHEN OTHERS THEN
          NULL;*/
      END;
    END IF;
    -- CHG0031856 Michal Tzvik 06.11.2014: End (1)
    -- 12.02.2015 Michal Tzvik: End
  
    IF funcmode = 'RUN' THEN
      resultout := wf_engine.eng_completed || ':' || l_result;
    ELSIF funcmode = 'RESPOND' THEN
    
      -- Debug Message
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || l_proc_name,
	         message   => ' l_doc_instance_id=' || l_doc_instance_id ||
		          ' funcmode=' || funcmode ||
		          ' context_user_comment =' ||
		          wf_engine.context_user_comment ||
		          ' getattrtext' ||
		          wf_notification.getattrtext(l_nid, 'NOTE') ||
		          ' context_TEXT =' ||
		          wf_engine.context_text ||
		          ' context_user =' ||
		          wf_engine.context_user ||
		          'context_recipient_role =' ||
		          wf_engine.context_recipient_role ||
		          'context_original_recipient =' ||
		          wf_engine.context_original_recipient ||
		          'context_from_role =' ||
		          wf_engine.context_from_role ||
		          'context_new_role  =' ||
		          wf_engine.context_new_role ||
		          'context_more_info_role  =' ||
		          wf_engine.context_more_info_role ||
		          'context_user_key =' ||
		          wf_engine.context_user_key);
    
      l_his_rec.note := wf_notification.getattrtext(l_nid, 'NOTE');
      -- in case of reject note is reqiured
    
      IF l_result = 'REJECT' AND l_his_rec.note IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_FIELD_REQUIRED');
        fnd_message.set_token('FIELD', 'Note');
      
        app_exception.raise_exception;
      
        -- CHG0031856 Michal Tzvik 06.11.2014: Start (2)
        -- Avoid user from approving his request by getting to "Notifications From Me" in Worklist
      ELSIF l_result = 'APPROVE' THEN
        --Begin CHG0045539
        BEGIN
          l_err_code := NULL;
          l_err_msg  := NULL;
        
          OPEN c_sql;
          FETCH c_sql
	INTO l_sql;
          CLOSE c_sql;
        
          IF l_sql IS NOT NULL THEN
	EXECUTE IMMEDIATE l_sql
	  USING l_doc_instance_id, OUT l_err_code, OUT l_err_msg;
          END IF;
        
        EXCEPTION
          WHEN OTHERS THEN
	l_err_code := 1;
	l_err_msg  := SQLERRM;
        END;
      
        IF l_err_code = 1 THEN
          --resultout := wf_engine.eng_completed || ':' || 'FAIL';
          l_err_msg := 'Error in xxobjt_wf_doc_util.check_user_action_wf function: ' ||
	           l_err_msg;
          wf_engine.setitemattrtext(itemtype => itemtype,
			itemkey  => itemkey,
			aname    => 'ERR_MESSAGE',
			avalue   => l_err_msg);
        
          fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_GENERAL_MSG');
          fnd_message.set_token('MSG', l_err_msg);
          app_exception.raise_exception;
        END IF;
        --End CHG0045539
      
        SELECT xwdi.requestor_person_id,
	   nvl(d.requestor_can_approve, 'N') --CHG0045539
        INTO   l_requestor_person_id,
	   l_requestor_can_approve
        FROM   xxobjt_wf_doc_instance xwdi,
	   xxobjt_wf_docs         d
        WHERE  d.doc_id = xwdi.doc_id
        AND    xwdi.doc_instance_id = l_doc_instance_id;
      
        IF l_requestor_person_id = l_approver_person_id AND
           l_requestor_can_approve = 'N' THEN
          fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_SELF_APPROVAL');
          app_exception.raise_exception;
        END IF;
        -- CHG0031856 Michal Tzvik 06.11.2014: End (2)
      END IF;
    
      IF l_context_user --l_approver_username -- CHG0031856 Michal Tzvik 06.11.2014 replace: upper(REPLACE(REPLACE(wf_engine.context_user, 'email:'),'@stratasys.com'))
         != /*wf_engine.*/
         l_context_recipient_role THEN
        l_his_rec.note := l_his_rec.note || ' Action performed by ' ||
		  wf_engine.context_text;
      END IF;
    
      update_doc_history(l_err_code,
		 l_err_msg,
		 l_doc_instance_id,
		 fnd_global.employee_id,
		 l_result, /*wf_engine.*/
		 l_context_user,
		 l_his_rec.note);
    
      IF l_err_code = 1 THEN
        wf_engine.setitemattrtext(itemtype => itemtype,
		          itemkey  => itemkey,
		          aname    => 'ERR_MESSAGE',
		          avalue   => l_err_msg);
      
        fnd_message.set_name('XXOBJT', 'XXOBJT_WF_DOC_GENERAL_MSG');
        fnd_message.set_token('MSG', l_err_msg);
        app_exception.raise_exception;
      
      END IF;
      --
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'FROM_ROLE',
		        avalue   => /*wf_engine.*/ l_context_user);
      --
      resultout := wf_engine.eng_completed || ':' || l_result;
    
    ELSIF funcmode IN ('FORWARD', 'TRANSFER') THEN
    
      l_his_rec.note := wf_engine.context_user_comment; -- 07.09.2014 Michal Tzvik: replace  wf_notification.getattrtext(l_nid, 'NOTE');
    
      -- history handle
    
      /* wf_directory.getroleorigsysinfo(role           => wf_engine.context_recipient_role,
      orig_system    => l_orig_system,
      orig_system_id => l_person_id);*/
    
      update_doc_history(l_err_code,
		 l_err_msg,
		 l_doc_instance_id,
		 fnd_global.employee_id,
		 'FORWARD', /*wf_engine.*/
		 l_context_user,
		 l_his_rec.note);
    
      SELECT h.dynamic_role,
	 
	 t.current_seq_appr + 0.1
      INTO   l_his_rec.dynamic_role,
	 l_his_rec.seq_no
      
      FROM   xxobjt_wf_doc_instance t,
	 xxobjt_wf_doc_history  h
      WHERE  t.doc_instance_id = l_doc_instance_id
      AND    t.doc_instance_id = h.doc_instance_id
      AND    current_seq_appr = h.seq_no;
    
      l_his_rec.note            := NULL;
      l_his_rec.action_code     := 'WAITING';
      l_his_rec.role_name       :=  /*wf_engine.*/
       l_context_new_role; -- 11.02.2015 Michal Tzvik: replace context_text with context_new_role
      l_his_rec.doc_instance_id := l_doc_instance_id;
    
      -- get forward person id CHG0045539
      BEGIN
      
        SELECT employee_id
        INTO   l_forward_person_id
        FROM   fnd_user u
        WHERE  u.user_name = l_context_new_role;
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END; -- end --CHG0045539
      insert_history_record(l_err_code, l_err_msg, l_his_rec);
    
      UPDATE xxobjt_wf_doc_instance t
      SET    current_seq_appr     = l_his_rec.seq_no,
	 t.approver_person_id = nvl(l_forward_person_id,
			    t.approver_person_id) --CHG0045539
      WHERE  doc_instance_id = l_doc_instance_id;
    
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'CURRENT_APPROVER',
		        avalue   => /*wf_engine.*/ l_context_new_role); -- 11.02.2015 Michal Tzvik: replace context_text with context_new_role
    
      -- CHG0045539 update CURRENT_SEQ_APPR
      wf_engine.setitemattrnumber(itemtype => itemtype,
		          itemkey  => itemkey,
		          aname    => 'CURRENT_SEQ_APPR',
		          avalue   => l_his_rec.seq_no);
    
      -- end CHG0045539 CURRENT_SEQ_APPR
    
      resultout := wf_engine.eng_completed;
    
    ELSIF funcmode = 'QUESTION' THEN
      -- 1.2  01/02/2015  Michal Tzvik
    
      l_his_rec.note := wf_engine.context_user_comment;
      IF l_context_user != l_context_new_role THEN
        l_his_rec.note := l_his_rec.note || ' Action performed by ' ||
		  wf_engine.context_user;
      END IF;
      -- wf_notification.getattrtext(l_nid, 'NOTE');
    
      -- history handle
      update_doc_history(l_err_code,
		 l_err_msg,
		 l_doc_instance_id,
		 fnd_global.employee_id,
		 'QUESTION',
		 l_context_from_role,
		 l_his_rec.note);
    
      l_his_rec.note            := NULL;
      l_his_rec.action_code     := 'WAITING';
      l_his_rec.role_name       := l_context_new_role;
      l_his_rec.doc_instance_id := l_doc_instance_id;
      insert_history_record(l_err_code, l_err_msg, l_his_rec);
    
      --wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'CURRENT_APPROVER', avalue => wf_engine.context_text);
    
      --      wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'DOC_ACTION', avalue => 'QUESTION');
    
      -- wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'NOTE', avalue => wf_engine.context_user_comment);
    
      --  insert_pre_action_history(itemtype,
      --  itemkey, actid, 'QUESTION', resultout);
    
      --wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'MORE_INFO_USER_NAME', avalue => wf_engine.context_new_role);
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'MORE_INFO_USER_NAME',
		        avalue   => l_context_new_role);
    
      /*  insert_pre_action_history(itemtype,
      itemkey,
      actid,
      'ANSWER',
      resultout);*/
    
      resultout := wf_engine.eng_completed || ':' || wf_engine.eng_null;
    
    ELSIF funcmode = 'ANSWER' THEN
      -- 1.2  01/02/2015  Michal Tzvik
    
      --wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'NOTE', avalue => wf_engine.context_user_comment);
    
      -- wf_engine.setitemattrtext(itemtype => itemtype, itemkey => itemkey, aname => 'DOC_ACTION', avalue => 'ANSWER');
    
      --      update_action_history(itemtype, itemkey, actid, funcmode, resultout);
    
      l_his_rec.note := wf_engine.context_user_comment;
      IF l_context_user != l_context_text THEN
        l_his_rec.note := l_his_rec.note || ' Action performed by ' ||
		  wf_engine.context_text;
      END IF;
      -- wf_notification.getattrtext(l_nid, 'NOTE');
    
      -- history handle
      update_doc_history(l_err_code,
		 l_err_msg,
		 l_doc_instance_id,
		 fnd_global.employee_id,
		 'ANSWER',
		 l_context_user,
		 l_his_rec.note);
    
      l_his_rec.note            := NULL;
      l_his_rec.action_code     := 'WAITING';
      l_his_rec.role_name       := l_context_original_recipient;
      l_his_rec.doc_instance_id := l_doc_instance_id;
    
      insert_history_record(l_err_code, l_err_msg, l_his_rec);
    
      resultout := wf_engine.eng_completed || ':' || wf_engine.eng_null;
    
    ELSE
    
      resultout := wf_engine.eng_completed || ':' || wf_engine.eng_null;
    END IF;
  
  END;

  ----------------------------------------
  ---   post_approve_wf
  --
  --    called from wf XXWFDOC
  ----------------------------------------
  PROCEDURE post_approve_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
  BEGIN
  
    -- UPDATE DOC INSTANCE
    IF funcmode = 'RUN' THEN
      l_doc_instance_upd.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
						itemkey  => itemkey,
						aname    => 'DOC_INSTANCE_ID');
      l_doc_instance_upd.doc_status      := 'APPROVED';
      l_doc_instance_upd.end_date        := SYSDATE;
    
      update_instance(l_err_code, l_err_msg, l_doc_instance_upd);
    
      DELETE FROM xxobjt_wf_doc_history_tmp t
      WHERE  t.doc_instance_id = l_doc_instance_upd.doc_instance_id;
    
    END IF;
    resultout := wf_engine.eng_completed;
  
  END;

  ----------------------------------------
  ---   post_rejecte_wf
  --
  --    called from wf XXWFDOC
  ---------------------------------------
  PROCEDURE post_reject_wf(itemtype  IN VARCHAR2,
		   itemkey   IN VARCHAR2,
		   actid     IN NUMBER,
		   funcmode  IN VARCHAR2,
		   resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
  BEGIN
  
    -- UPDATE DOC INSTANCE
    IF funcmode = 'RUN' THEN
      l_doc_instance_upd.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
						itemkey  => itemkey,
						aname    => 'DOC_INSTANCE_ID');
      l_doc_instance_upd.doc_status      := 'REJECTED';
      l_doc_instance_upd.end_date        := SYSDATE;
    
      update_instance(l_err_code, l_err_msg, l_doc_instance_upd);
    
      DELETE FROM xxobjt_wf_doc_history_tmp t
      WHERE  t.doc_instance_id = l_doc_instance_upd.doc_instance_id;
    
    END IF;
    resultout := wf_engine.eng_completed;
  
  END;

  --

  ----------------------------------------
  ---   post_approve_custom_wf
  --
  --    called from wf XXWFDOC
  ----------------------------------------
  PROCEDURE post_approve_custom_wf(itemtype  IN VARCHAR2,
		           itemkey   IN VARCHAR2,
		           actid     IN NUMBER,
		           funcmode  IN VARCHAR2,
		           resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance xxobjt_wf_doc_instance%ROWTYPE;
    l_sql          xxobjt_wf_docs.custom_after_apr_func%TYPE;
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(200);
  
    CURSOR c_sql IS
      SELECT d.custom_after_apr_func
      FROM   xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance i
      WHERE  i.doc_id = d.doc_id
      AND    i.doc_instance_id = l_doc_instance.doc_instance_id;
  
  BEGIN
    resultout := wf_engine.eng_completed || ':' || 'SUCCESS';
  
    l_doc_instance.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'DOC_INSTANCE_ID');
  
    IF funcmode = 'RUN' THEN
      OPEN c_sql;
      FETCH c_sql
        INTO l_sql;
      CLOSE c_sql;
    
      IF l_sql IS NOT NULL THEN
      
        EXECUTE IMMEDIATE l_sql
          USING l_doc_instance.doc_instance_id, OUT l_err_code, OUT l_err_msg;
      
      END IF;
    END IF;
  
    IF l_err_code = 1 THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in custom_after_apr_func: ' ||
			        l_err_msg);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in post_approve_custom_wf: ' ||
			        SQLERRM);
  END post_approve_custom_wf;

  ----------------------------------------
  ---   post_reject_custom_wf
  --
  --    called from wf XXWFDOC
  ----------------------------------------
  PROCEDURE post_reject_custom_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code     NUMBER;
    l_err_msg      VARCHAR2(200);
    l_sql          xxobjt_wf_docs.custom_after_apr_func%TYPE;
  
    CURSOR c_sql IS
      SELECT d.custom_after_reject_func
      FROM   xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance i
      WHERE  i.doc_id = d.doc_id
      AND    i.doc_instance_id = l_doc_instance.doc_instance_id;
  
  BEGIN
    resultout                      := wf_engine.eng_completed || ':' ||
			  'SUCCESS';
    l_doc_instance.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'DOC_INSTANCE_ID');
    IF funcmode = 'RUN' THEN
      OPEN c_sql;
      FETCH c_sql
        INTO l_sql;
      CLOSE c_sql;
    
      IF l_sql IS NOT NULL THEN
      
        EXECUTE IMMEDIATE l_sql
          USING l_doc_instance.doc_instance_id, OUT l_err_code, OUT l_err_msg;
      
      END IF;
    END IF;
  
    IF l_err_code = 1 THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in custom_after_reject_func: ' ||
			        l_err_msg);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in post_reject_custom_wf: ' ||
			        SQLERRM);
  END post_reject_custom_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               get_apps_initialize_params
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   17/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_apps_initialize_params(p_doc_instance_id IN xxobjt_wf_doc_instance.doc_instance_id%TYPE,
			   x_user_id         OUT NUMBER,
			   x_resp_id         OUT NUMBER,
			   x_resp_appl_id    OUT NUMBER) IS
  BEGIN
    SELECT xwdi.user_id,
           xwdi.resp_id,
           xwdi.resp_appl_id
    INTO   x_user_id,
           x_resp_id,
           x_resp_appl_id
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_apps_initialize_params;

  --------------------------------------------------------------------
  --  customization code: CHG0031856- SOD-Customer Update Workflow
  --  name:               get_fyi_role
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      17/07/2014
  --  Purpose :
  --  Parameters:
  -----------

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_fyi_role(p_dist_roles_list IN VARCHAR2,
		p_doc_instance_id IN NUMBER) RETURN VARCHAR2 IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_role_name VARCHAR2(1000);
    l_role_desc VARCHAR2(1000);
    --l_body        VARCHAR2(2000);
    --l_err_code    NUMBER;
    --l_err_message VARCHAR2(500);
    --l_subject     VARCHAR2(500);
  
  BEGIN
  
    IF instr(TRIM(REPLACE(p_dist_roles_list, ',', ' ')), ' ') > 0 THEN
    
      l_role_name := upper('XXWFDOC_FYI_' || p_doc_instance_id || '_' ||
		   to_char(SYSDATE, 'HH24MISS'));
    
      BEGIN
        wf_directory.createadhocrole(role_name               => l_role_name,
			 role_display_name       => l_role_desc,
			 LANGUAGE                => NULL,
			 territory               => NULL,
			 role_description        => 'Document_Approval',
			 notification_preference => 'MAILHTML',
			 role_users              => p_dist_roles_list,
			 email_address           => NULL,
			 fax                     => NULL,
			 status                  => 'ACTIVE',
			 expiration_date         => SYSDATE + 1,
			 parent_orig_system      => -1,
			 parent_orig_system_id   => -1,
			 owner_tag               => NULL);
        /*  exception
        when others then
          rollback;
          return '';*/
      END;
    
      COMMIT;
    
    ELSE
      l_role_name := p_dist_roles_list;
    
    END IF;
  
    RETURN l_role_name;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_fyi_role;

  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               get_fyi_role_custom_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           get concatenated users for FYI notification
  --                      called from wf XXWFDOC
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   17/07/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_fyi_role_custom_wf(itemtype  IN VARCHAR2,
		           itemkey   IN VARCHAR2,
		           actid     IN NUMBER,
		           funcmode  IN VARCHAR2,
		           resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code     NUMBER;
    l_err_msg      VARCHAR2(200);
    l_sql          xxobjt_wf_docs.custom_after_apr_func%TYPE;
    l_role_name    VARCHAR2(150);
  
    CURSOR c_sql IS
      SELECT d.custom_fyi_role_list
      FROM   xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance i
      WHERE  i.doc_id = d.doc_id
      AND    i.doc_instance_id = l_doc_instance.doc_instance_id;
  
  BEGIN
    resultout                      := wf_engine.eng_completed || ':' || 'N';
    l_doc_instance.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'DOC_INSTANCE_ID');
    IF funcmode = 'RUN' THEN
      OPEN c_sql;
      FETCH c_sql
        INTO l_sql;
      CLOSE c_sql;
    
      IF l_sql IS NOT NULL THEN
      
        EXECUTE IMMEDIATE l_sql
          USING l_doc_instance.doc_instance_id, OUT l_err_code, OUT l_err_msg;
      
        IF l_err_code = 1 THEN
          wf_engine.setitemattrtext(itemtype => itemtype,
			itemkey  => itemkey,
			aname    => 'ERR_MESSAGE',
			avalue   => l_err_msg);
          --RAISE l_role_exception;
          resultout := wf_engine.eng_completed || ':' || 'N';
        ELSE
          IF l_err_msg IS NULL THEN
	resultout := wf_engine.eng_completed || ':' || 'N';
          
          ELSE
	l_role_name := get_fyi_role(l_err_msg,
			    l_doc_instance.doc_instance_id);
          
	IF l_role_name IS NULL THEN
	  resultout := wf_engine.eng_completed || ':' || 'N';
	  wf_engine.setitemattrtext(itemtype => itemtype,
			    itemkey  => itemkey,
			    aname    => 'ERR_MESSAGE',
			    avalue   => 'Failed to create FYI role');
	ELSE
	  wf_engine.setitemattrtext(itemtype => itemtype,
			    itemkey  => itemkey,
			    aname    => 'FYI_ROLE_NAME',
			    avalue   => l_role_name);
	
	  resultout := wf_engine.eng_completed || ':' || 'Y';
	END IF;
          END IF;
        END IF;
      
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'N';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in get_fyi_role_custom_wf: ' ||
			        SQLERRM);
  END get_fyi_role_custom_wf;
  /*
  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               post_approve_custom_failure_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           Handle failure in post approval custom:
  --                      1. Set recrd status = ERROR
  --                      2. Save error message in history table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   26/10/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE post_approve_custom_failure_wf(itemtype  IN VARCHAR2,
                                           itemkey   IN VARCHAR2,
                                           actid     IN NUMBER,
                                           funcmode  IN VARCHAR2,
                                           resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
    l_his_rec          xxobjt_wf_doc_history%ROWTYPE;
  BEGIN
  
    set_doc_status(c_status_error, SYSDATE, itemtype, itemkey, actid, funcmode, resultout);
  
    resultout := wf_engine.eng_completed;
  
  END post_approve_custom_failure_wf;
  
  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               post_reject_custom_failure_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           Handle failure in post reject custom:
  --                      1. Set recrd status = ERROR
  --                      2. Save error message in history table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   27/10/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE post_reject_custom_failure_wf(itemtype  IN VARCHAR2,
                                          itemkey   IN VARCHAR2,
                                          actid     IN NUMBER,
                                          funcmode  IN VARCHAR2,
                                          resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
    l_his_rec          xxobjt_wf_doc_history%ROWTYPE;
  BEGIN
  
    set_doc_status(c_status_error, SYSDATE, itemtype, itemkey, actid, funcmode, resultout);
  
    resultout := wf_engine.eng_completed;
  
  END post_reject_custom_failure_wf;*/

  --------------------------------------------------------------------
  --  customization code:
  --  name:               set_doc_in_process_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18.11.2014
  --  Purpose :           called from wf XXWFDOC
  --                      Set field doc_status to IN_PROCESS
  --                      And clear EEROR_MESSAGE
  --                      when WF starts or after retry
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/11/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE set_doc_in_process_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2) IS
    --l_err_code        NUMBER;
    l_err_message VARCHAR2(150);
    --l_doc_instance_id NUMBER;
    l_xx_internal_exception EXCEPTION;
  
  BEGIN
  
    set_doc_status(c_status_inprocess,
	       NULL,
	       itemtype,
	       itemkey,
	       actid,
	       funcmode,
	       resultout);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'ERR_MESSAGE',
		      avalue   => '');
    resultout := wf_engine.eng_completed;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
	          'set_in_process_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          l_err_message || ' ' || SQLERRM);
      RAISE;
  END set_doc_in_process_wf;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               set_doc_error_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18.11.2014
  --  Purpose :           called from wf XXWFDOC
  --                      Set field doc_status to ERROR
  --                      when WF starts or after retry
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/11/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE set_doc_error_wf(itemtype  IN VARCHAR2,
		     itemkey   IN VARCHAR2,
		     actid     IN NUMBER,
		     funcmode  IN VARCHAR2,
		     resultout OUT NOCOPY VARCHAR2) IS
    --l_err_code        NUMBER;
    l_err_message VARCHAR2(150);
    --l_doc_instance_id NUMBER;
    l_xx_internal_exception EXCEPTION;
  
  BEGIN
  
    set_doc_status(c_status_error,
	       NULL,
	       itemtype,
	       itemkey,
	       actid,
	       funcmode,
	       resultout);
    resultout := wf_engine.eng_completed;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
	          'set_in_process_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          l_err_message || ' ' || SQLERRM);
      RAISE;
  END set_doc_error_wf;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               end_main_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18.11.2014
  --  Purpose :           called from wf XXWFDOC
  --                      Set field end_date to sysdate
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/11/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE end_main_wf(itemtype  IN VARCHAR2,
		itemkey   IN VARCHAR2,
		actid     IN NUMBER,
		funcmode  IN VARCHAR2,
		resultout OUT NOCOPY VARCHAR2) IS
    l_err_code    NUMBER;
    l_err_message VARCHAR2(150);
    --l_doc_instance_id NUMBER;
    l_xx_internal_exception EXCEPTION;
    l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
  
  BEGIN
  
    -- UPDATE DOC INSTANCE
    IF funcmode = 'RUN' THEN
      l_doc_instance_upd.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
						itemkey  => itemkey,
						aname    => 'DOC_INSTANCE_ID');
      l_doc_instance_upd.end_date        := SYSDATE;
    
      update_instance(l_err_code, l_err_message, l_doc_instance_upd);
    END IF;
    resultout := wf_engine.eng_completed;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
	          'end_main_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          l_err_message || ' ' || SQLERRM);
      RAISE;
  END end_main_wf;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               pre_approve_custom_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      28.12.2014
  --  Purpose :           called from wf XXWFDOC
  --                      Execute code of new field CUSTOM_PRE_APR_FUNC
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/12/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE pre_approve_custom_wf(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2) IS
    l_doc_instance xxobjt_wf_doc_instance%ROWTYPE;
    l_sql          xxobjt_wf_docs.custom_after_apr_func%TYPE;
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(200);
  
    CURSOR c_sql IS
      SELECT d.custom_pre_apr_func
      FROM   xxobjt_wf_docs         d,
	 xxobjt_wf_doc_instance i
      WHERE  i.doc_id = d.doc_id
      AND    i.doc_instance_id = l_doc_instance.doc_instance_id;
  
  BEGIN
    resultout := wf_engine.eng_completed || ':' || 'SUCCESS';
  
    l_doc_instance.doc_instance_id := wf_engine.getitemattrnumber(itemtype => itemtype,
					      itemkey  => itemkey,
					      aname    => 'DOC_INSTANCE_ID');
  
    IF funcmode = 'RUN' THEN
      OPEN c_sql;
      FETCH c_sql
        INTO l_sql;
      CLOSE c_sql;
    
      IF l_sql IS NOT NULL THEN
      
        EXECUTE IMMEDIATE l_sql
          USING l_doc_instance.doc_instance_id, OUT l_err_code, OUT l_err_msg;
      
      END IF;
    END IF;
  
    IF l_err_code = 1 THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in custom_after_apr_func: ' ||
			        l_err_msg);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'FAIL';
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'ERR_MESSAGE',
		        avalue   => 'Error in pre_approve_custom_wf: ' ||
			        SQLERRM);
  END pre_approve_custom_wf;
  --------------------------------------------------------------------
  --  customization code: CHG0031856
  --  name:               post_approve_custom_failure_wf
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           Handle failure in running custom code:
  --                      1. Set recrd status = ERROR
  --                      2. Save error message in history table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   26/10/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE custom_failure_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
    --l_doc_instance_upd xxobjt_wf_doc_instance%ROWTYPE;
    --l_err_code         NUMBER;
    --l_err_msg          VARCHAR2(200);
    --l_his_rec          xxobjt_wf_doc_history%ROWTYPE;
  BEGIN
  
    set_doc_status(c_status_error,
	       SYSDATE,
	       itemtype,
	       itemkey,
	       actid,
	       funcmode,
	       resultout);
  
    resultout := wf_engine.eng_completed;
  
  END custom_failure_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0033620
  --  name:               insert_custom_approvals
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           use for insert user pre-defined approvals
  --                      for specific doc_instance_id. (It replace
  --                      build_approval_hierarchy)
  --  Parameters:
  --    p_err_code - 0 = success, 1 = error
  --    p_err_msg  - error message
  --    p_doc_instance_id
  --    p_approval_person_id_list - comma delimitted list of approvers' person_id
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   01.01.2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE insert_custom_approvals(p_err_code                OUT NUMBER,
			p_err_msg                 OUT VARCHAR2,
			p_doc_instance_id         NUMBER,
			p_approval_person_id_list VARCHAR2) IS
  
    CURSOR c_approvers IS
      SELECT regexp_substr(p_approval_person_id_list, '[^,]+', 1, LEVEL) person_id
      FROM   dual
      CONNECT BY regexp_substr(p_approval_person_id_list, '[^,]+', 1, LEVEL) IS NOT NULL;
  
    l_seq          NUMBER := 0;
    l_role_name    fnd_user.user_name%TYPE;
    l_doc_instance xxobjt_wf_doc_instance%ROWTYPE;
  BEGIN
    p_err_msg  := '';
    p_err_code := 0;
  
    SELECT *
    INTO   l_doc_instance
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
    IF l_doc_instance.doc_status NOT IN ('NEW', 'CANCELLED', 'REJECTED') THEN
      p_err_msg  := 'Error: insert_custom_approvals: status should be NEW, CANCELLED or REJECTED.';
      p_err_code := 1;
      RETURN;
    END IF;
  
    DELETE FROM xxobjt_wf_doc_history_tmp t
    WHERE  t.doc_instance_id = p_doc_instance_id;
  
    FOR r_approver IN c_approvers LOOP
      l_seq := l_seq + 1;
    
      SELECT fu.user_name
      INTO   l_role_name
      FROM   fnd_user fu
      WHERE  1 = 1
	-- If requestor is also defined as approver,
	-- then approver will be the suppervisor
      AND    fu.employee_id = decode(r_approver.person_id,
			 l_doc_instance.requestor_person_id,
			 xxhr_util_pkg.get_suppervisor_id(p_person_id      => l_doc_instance.requestor_person_id,
					          p_effective_date => trunc(SYSDATE),
					          p_bg_id          => 0),
			 r_approver.person_id);
    
      INSERT INTO xxobjt_wf_doc_history_tmp
        (doc_instance_id,
         seq_no,
         role_name,
         role_description,
         dynamic_role,
         online_calc_ind,
         one_time_approval_ind,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         note)
      VALUES
        (p_doc_instance_id,
         l_seq,
         l_role_name,
         NULL, -- role_description
         NULL, -- dynamic_role
         NULL, -- online_calc_ind
         NULL, -- one_time_approval_ind
         SYSDATE,
         fnd_global.user_id,
         SYSDATE,
         fnd_global.user_id,
         NULL,
         'Custom approvals');
    
    END LOOP;
  
    UPDATE xxobjt_wf_doc_instance xwdi
    SET    xwdi.skip_build_hierarchy = 'Y'
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_msg  := 'Error: insert_custom_approvals: ' || SQLERRM;
      p_err_code := 1;
  END insert_custom_approvals;

  --------------------------------------------------------------------
  --  customization code: CHG0033620
  --  name:               is_reference_link_exists
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :           use to decide which notification to display
  --                      NEED_APPR_MSG or  NEED_APPR_WITH_LINK_MSG
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   26.02.2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE is_reference_link_exists(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2) IS
    l_reference_link VARCHAR2(2000);
  BEGIN
    l_reference_link := wf_engine.getitemattrtext(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'REFERENCE_LINK');
    IF l_reference_link IS NOT NULL THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;
  END is_reference_link_exists;

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
    RETURN NUMBER IS
  
    l_last_user_id NUMBER;
  
  BEGIN
    -- get user who did the last approval
    SELECT --seq, context_user,h1.person_id,doc_instance_id,
     CASE
       WHEN instr(h1.context_user, '@') > 1 THEN
        nvl((SELECT u.user_id
	FROM   per_all_people_f p,
	       fnd_user         u
	WHERE  trunc(SYSDATE) BETWEEN p.effective_start_date AND
	       p.effective_end_date
	AND    upper(p.email_address) =
	       upper(substr(h1.context_user,
		         instr(h1.context_user, 'email:') + 6))
	AND    u.employee_id = p.person_id),
	0)
       ELSE
        nvl((SELECT u.user_id
	FROM   fnd_user u
	WHERE  u.user_name = h1.context_user),
	0) -- 0 = SYSADMIN
     END approver
    INTO   l_last_user_id
    FROM   xxobjt_wf_doc_history_v h1
    WHERE  seq = (SELECT MAX(seq)
	      FROM   xxobjt_wf_doc_history_v h2
	      WHERE  h2.doc_instance_id = h1.doc_instance_id)
    AND    doc_instance_id = p_doc_instance_id;
  
    RETURN l_last_user_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL; -- 0 = SYSADMIN
  END get_last_approver_user_id;

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
		  p_err_message     OUT VARCHAR2) IS
    l_current_seq_appr NUMBER;
    l_notification_id  NUMBER;
  BEGIN
    p_err_code := 0;
    -- validate
    BEGIN
      SELECT d.current_seq_appr
      INTO   l_current_seq_appr
      FROM   xxobjt_wf_doc_history  h,
	 xxobjt_wf_doc_instance d
      WHERE  h.doc_instance_id = p_doc_instance_id
      AND    d.doc_instance_id = h.doc_instance_id
      AND    h.seq_no = p_route_to_seq;
    
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 1;
        p_err_message := 'Unable to route back to seq :' || p_route_to_seq ||
		 ', seq not found.';
        RETURN;
    END;
  
    -- validate notification
  
    BEGIN
      SELECT n.notification_id
      INTO   l_notification_id
      FROM   wf_notifications n
      WHERE  n.message_type = 'XXWFDOC'
      AND    user_key = p_doc_instance_id
      AND    n.status = 'OPEN';
      -- AND    n.recipient_role = fnd_global.user_name;
    
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 1;
        p_err_message := 'Open notification not found for user ' ||
		 fnd_global.user_name;
        RETURN;
    END;
  
    --- push seq forward
    UPDATE xxobjt_wf_doc_history_tmp t
    SET    t.seq_no = t.seq_no + 2
    WHERE  t.doc_instance_id = p_doc_instance_id
    AND    t.seq_no > l_current_seq_appr;
  
    INSERT INTO xxobjt_wf_doc_history_tmp
      (doc_instance_id,
       seq_no,
       role_name,
       role_description,
       dynamic_role,
       online_calc_ind,
       one_time_approval_ind,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       note
       
       )
      SELECT doc_instance_id,
	 l_current_seq_appr + 1,
	 role_name,
	 role_description,
	 dynamic_role,
	 online_calc_ind,
	 one_time_approval_ind,
	 last_update_date,
	 last_updated_by,
	 creation_date,
	 created_by,
	 last_update_login,
	 note
      FROM   xxobjt_wf_doc_history_tmp t
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    t.seq_no = p_route_to_seq;
  
    INSERT INTO xxobjt_wf_doc_history_tmp
      (doc_instance_id,
       seq_no,
       role_name,
       role_description,
       dynamic_role,
       online_calc_ind,
       one_time_approval_ind,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       note
       
       )
      SELECT doc_instance_id,
	 l_current_seq_appr + 2,
	 role_name,
	 role_description,
	 dynamic_role,
	 online_calc_ind,
	 one_time_approval_ind,
	 last_update_date,
	 last_updated_by,
	 creation_date,
	 created_by,
	 last_update_login,
	 note
      FROM   xxobjt_wf_doc_history_tmp t
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    t.seq_no = l_current_seq_appr;
  
    -- COMMIT;
    wf_notification.setattrtext(l_notification_id, 'RESULT', 'APPROVE');
    wf_notification.setattrtext(l_notification_id,
		        'NOTE',
		        'Delegation Message:' || p_note);
    wf_notification.respond(nid             => l_notification_id,
		    respond_comment => NULL);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Unable to route ' || ' Current seq=' ||
	           l_current_seq_appr || SQLERRM;
  END;

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
	        p_err_message     OUT VARCHAR2) IS
  
    --  l_current_seq_appr NUMBER;
    l_notification_id NUMBER;
  BEGIN
    p_err_code := 0;
  
    -- validate notification
  
    BEGIN
      SELECT n.notification_id
      INTO   l_notification_id
      FROM   wf_notifications n
      WHERE  n.message_type = 'XXWFDOC'
      AND    user_key = p_doc_instance_id
      AND    n.status = 'OPEN'
      AND    n.recipient_role = fnd_global.user_name;
    
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 1;
        p_err_message := 'Open notification not found for user ' ||
		 fnd_global.user_name;
        RETURN;
    END;
  
    wf_notification.setattrtext(l_notification_id, 'RESULT', 'APPROVE');
    wf_notification.setattrtext(l_notification_id, 'NOTE', p_note);
    wf_notification.respond(nid             => l_notification_id,
		    respond_comment => p_note);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Unable to Approve ' || SQLERRM;
  END;

END xxobjt_wf_doc_util;
/
