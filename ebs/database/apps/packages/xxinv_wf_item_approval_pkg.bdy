CREATE OR REPLACE PACKAGE BODY "XXINV_WF_ITEM_APPROVAL_PKG" IS
  -- *****************************************************************************************
  -- Object Name:  xxinv_wf_item_approval_pkg
  -- Type       :   Package
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : document approval engine , support workflow XXWFDOC
  --
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --  1.1    12.9.19      YUVAL TAL         CHG0046494  - MODIFY GET_APPROVER /submit_sync_item_request/ sync_item
  --                                                  ADD get_applicable_system_name / REASSIGN
  --  1.2    14.11.19     yuval tal         CHG0046825 - modify get_approver/check_required_fields/get_approval_doc_code
  --  1.3    19.03.20     yuval tal         CHG0047452 - modify get_approval_doc_code
  --  1.4    22.4.20      yuval tal         CHG0047747 - add reassign_with_inactive - support reassign from inactive user

  -- *****************************************************************************************

  -- *****************************************************************************************
  -- Object Name:   logger
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : log messages to concurrent log and fnd Logs
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name             Type   Purpose
  --       --------         ----   -----------
  --       p_log_line       In     Varchar Message for logging purpose
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE logger(p_log_line VARCHAR2) IS
    l_msg VARCHAR2(4000);
  BEGIN
    IF TRIM(p_log_line) IS NOT NULL OR p_log_line != chr(10) THEN
      l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
	   p_log_line;
    END IF;
    --  dbms_output.put_line(substr(l_msg, 1, 250));
    --      ----------------------------------------------
    --    Ge
    --    ----------------------------------------------
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(substr(l_msg, 1, 250));
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  END logger;

  -- *****************************************************************************************
  -- Object Name:  submit_request
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Called By  : XXMTL_SYSTEM_ITEMS_AIUR_TRG2 (Trigger)
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name             Type   Purpose
  --       --------         ----   -----------
  --       p_inv_item_id    In     ???
  --       p_mode           In     ???
  --       p_old_status     In     ???
  --       p_new_status     In     ???
  --       x_err_code       Out    ???
  --       x_err_message    Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE submit_request(p_inv_item_id NUMBER,
		   p_mode        VARCHAR2,
		   p_old_status  VARCHAR2,
		   p_new_status  VARCHAR2) IS
    l_setmode    BOOLEAN;
    l_request_id NUMBER;
  BEGIN
    -- -----------------------
    -- this Procedure is getting Called from Trigger
    -- -----------------------
  
    l_setmode    := fnd_request.set_mode(TRUE);
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
			           program     => 'XXINVWFITEM',
			           description => 'XXINV Item Workflow',
			           sub_request => FALSE,
			           start_time  => to_char((SYSDATE +
					          3 / 24 / 60),
					          'DD-MON-YYYY HH24:MI:SS'),
			           argument1   => p_inv_item_id,
			           argument2   => p_mode,
			           argument3   => p_old_status,
			           argument4   => p_new_status);
    -- COMMIT;
  
    IF nvl(l_request_id, 0) = 0 THEN
      logger('Concurrent Program XXINVWFITEM failed to submit.');
    ELSE
      logger('Concurrent Program XXINVWFITEM  submitted successfully with Request Id :' ||
	 l_request_id);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      logger('UNEXPECTED Error in xxinv_wf_item_approval_pkg.submit_request:' ||
	 to_char(SQLCODE) || '-' || SQLERRM);
  END submit_request;

  --------
  -------- concurrent program ?????
  --------
  -- *****************************************************************************************
  -- Object Name:  initiate_approval
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name             Type   Purpose
  --       --------         ----   -----------
  --       p_inv_item_id    In     ???
  --       p_mode           In     ???
  --       p_old_status     In     ???
  --       p_new_status     In     ???
  --       x_err_code       Out    ???
  --       x_err_message    Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE initiate_approval(errbuf        OUT VARCHAR2,
		      retcode       OUT NUMBER,
		      p_inv_item_id NUMBER,
		      p_mode        VARCHAR2, -- INSERT/UPDATE
		      p_old_status  VARCHAR2,
		      p_new_status  VARCHAR2) IS
    l_doc_code        VARCHAR2(240);
    l_doc_instance_id NUMBER;
    -- l_mode                VARCHAR2(100);
    l_doc_instance_header xxobjt_wf_doc_instance%ROWTYPE;
  
    l_err_code NUMBER;
    -- l_err_msg  VARCHAR2(1000);
    l_key VARCHAR2(50);
  
    goto_end_exception EXCEPTION;
  BEGIN
  
    -- get wf track
    -----------------
    l_doc_code := get_approval_doc_code(p_inv_item_id,
			    p_mode,
			    p_old_status,
			    p_new_status);
  
    IF l_doc_code IS NULL THEN
      retcode := 1;
      errbuf  := 'Item is not appllicable for Workflow';
      logger(errbuf);
      RETURN;
    
    END IF;
  
    --Check if  there is already workflow in status IN_PROCESS ,SUCCESS for item
  
    BEGIN
    
      SELECT t.doc_instance_id
      INTO   l_doc_instance_id
      FROM   xxobjt_wf_doc_instance t,
	 xxobjt_wf_docs         d,
	 xxinv_wf_track_v       tr
      WHERE  t.doc_id = d.doc_id
      AND    n_attribute1 = p_inv_item_id
      AND    doc_status IN ('NEW', 'IN_PROCESS', 'SUCCESS')
      AND    d.doc_code = tr.doc_code -- IN ('ITEM_CLTW', 'ITEM_SP', 'ITEM_SALE')
      AND    d.doc_code = l_doc_code;
    
      retcode := 1;
      errbuf  := 'Unable to submit WF, there is already Active/Success workflow no :' ||
	     l_doc_instance_id;
    
      logger(errbuf);
      RAISE goto_end_exception;
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
    --  Create instance
    -- Initiating Workflow Document Instance
    ----------------------------------------------
  
    l_doc_instance_header.user_id             := fnd_global.user_id; -- 3850; -- fnd_global.user_id;
    l_doc_instance_header.resp_id             := fnd_global.resp_id;
    l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
    l_doc_instance_header.requestor_person_id := fnd_global.employee_id; --1961; --fnd_global.employee_id;
    l_doc_instance_header.creator_person_id   := fnd_global.employee_id; -- 1961; --fnd_global.employee_id;
  
    l_doc_instance_header.n_attribute1 := p_inv_item_id;
    l_doc_instance_header.attribute1   := xxinv_utils_pkg.get_item_segment(p_inv_item_id,
						   91);
  
    logger('Create Instance');
    xxobjt_wf_doc_util.create_instance(p_err_code            => l_err_code,
			   p_err_msg             => errbuf,
			   p_doc_instance_header => l_doc_instance_header,
			   p_doc_code            => l_doc_code);
  
    IF l_err_code != 0 THEN
    
      logger('Error in create instance =' || errbuf);
      RAISE goto_end_exception;
    END IF;
  
    logger('Create Instance:l_doc_instance_header.doc_instance_id=' ||
           l_doc_instance_header.doc_instance_id);
  
    -- Populate table with initial values
    logger('Populate table with initial values');
    INSERT INTO xxinv_wf_item_data
      (doc_instance_id,
       inventory_item_id,
       last_update_date,
       creation_date,
       created_by,
       last_updated_by,
       recommended_stock_1_10,
       recommended_stock_11_50,
       recommended_stock_51,
       recommended_eng_stock)
    VALUES
      (l_doc_instance_header.doc_instance_id,
       p_inv_item_id,
       SYSDATE,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.user_id,
       219159,
       219160,
       219161,
       219162);
  
    INSERT INTO xxinv_wf_item_data_lines
      (doc_instance_id,
       child_type,
       n_attribute1,
       c_attribute1,
       creation_date,
       last_update_date,
       last_updated_by,
       created_by)
      SELECT l_doc_instance_header.doc_instance_id,
	 'APPLICABLE SYSTEM',
	 m.category_id,
	 'N',
	 SYSDATE,
	 SYSDATE,
	 fnd_global.user_id,
	 fnd_global.user_id
      FROM   mtl_categories_v m
      WHERE  m.structure_id = 50511
      AND    nvl(m.disable_date, SYSDATE + 1) > SYSDATE
      AND    nvl(m.enabled_flag, 'N') = 'Y';
  
    COMMIT;
  
    -- Initiate approval
    logger('Initiate approval');
  
    xxobjt_wf_doc_util.initiate_approval_process(p_err_code        => l_err_code,
				 p_err_msg         => errbuf,
				 p_doc_instance_id => l_doc_instance_header.doc_instance_id,
				 p_wf_item_key     => l_key);
  
    logger('Key=' || l_key);
  
    IF l_err_code != 0 THEN
    
      logger('Error in initiate approval  =' || errbuf);
      retcode := 2;
    END IF;
  
    /*
    In case of failure
    p_err_code =2
    send mail to admin User  TBD
    according to field admin_user_role   in table xxobjt_wf_docs
    
    
    use :
    xxobjt_wf_mail .send_mail_text*/
  
  EXCEPTION
    WHEN goto_end_exception THEN
      retcode := 1;
    
    WHEN OTHERS THEN
      logger(SQLERRM);
      retcode := 2;
  END initiate_approval;

  -- *****************************************************************************************
  -- Object Name:  get_approver
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : used in doc approval setup to get item approval roles
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       p_role_code         In     ???
  --       x_role_name         Out    ???
  --       x_err_code          Out    ???
  --       x_err_message       Out    ???
  --  ------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --                                        logic will be based on collection quality plan table
  --  1.1   12.9.19      yuval tal          CHG0046494  - change logic for ITEM_FIN
  -- 1.2    14.11.19     yuval tal          CHG0046825 - add wh User support
  -- ------------------------------------------------------------------------------------------------
  PROCEDURE get_approver(x_err_code        OUT NUMBER,
		 x_err_message     OUT VARCHAR2,
		 p_doc_instance_id IN NUMBER,
		 p_role_code       IN VARCHAR2,
		 x_role_name       OUT VARCHAR2) IS
  
    CURSOR c_doc IS
      SELECT d.doc_code,
	 t.n_attribute1
      
      FROM   xxobjt_wf_doc_instance t,
	 xxobjt_wf_docs         d
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    d.doc_id = t.doc_id;
  
    l_segment3 VARCHAR2(50);
    l_segment4 VARCHAR2(50);
    l_segment6 VARCHAR2(50);
    -- l_doc_code                    VARCHAR2(50);
    l_planning_make_buy_code      NUMBER;
    l_q_xxinv_item_wf_approvers_v q_xxinv_item_wf_approvers_v%ROWTYPE;
    l_replacing_item_id           NUMBER;
  BEGIN
    x_err_code := 0;
  
    FOR i IN c_doc LOOP
      -- get replacing item
    
      SELECT d.replacing_item_id
      INTO   l_replacing_item_id
      FROM   xxinv_wf_item_data d
      WHERE  d.doc_instance_id = p_doc_instance_id;
    
      SELECT mc.segment3,
	 mc.segment4,
	 mc.segment6,
	 planning_make_buy_code
      INTO   l_segment3,
	 l_segment4,
	 l_segment6,
	 l_planning_make_buy_code
      FROM   mtl_item_categories mic,
	 mtl_categories_kfv  mc,
	 mtl_system_items_b  msi
      WHERE  msi.organization_id = 91
      AND    msi.inventory_item_id = mic.inventory_item_id
      AND    mic.category_id = mc.category_id
      AND    mic.category_set_id = 1100000221
      AND    mic.inventory_item_id = i.n_attribute1
      AND    mic.organization_id =
	 xxinv_utils_pkg.get_master_organization_id;
    
      IF i.doc_code = 'ITEM_SP' THEN
        SELECT *
        INTO   l_q_xxinv_item_wf_approvers_v
        FROM   q_xxinv_item_wf_approvers_v t
        WHERE  t.xx_wf_type = i.doc_code
        AND    t.xx_technology_ph = l_segment6
        AND    t.xx_product_family_ph = l_segment3
        AND    t.xx_product_sub_family_ph = l_segment4;
      
      ELSE
      
        SELECT *
        INTO   l_q_xxinv_item_wf_approvers_v
        FROM   q_xxinv_item_wf_approvers_v t
        WHERE  t.xx_wf_type = i.doc_code;
      
      END IF;
    
      CASE p_role_code
        WHEN 'ITEM_ADMIN' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_admin;
        WHEN
        
         'ITEM_PRICING' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_pricing;
        
        WHEN 'ITEM_FIN' THEN
          --CHG0046494  -- IN SP IF BUY ITEM FIN NOT REQUIRED
          --  x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_finance;
          IF i.doc_code = 'ITEM_SP' AND
	 xxinv_utils_pkg.get_item_make_buy_code(i.n_attribute1, 91) = 2 THEN
	x_role_name := -2;
          ELSE
	x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_finance;
          END IF;
        
      ---
        WHEN 'ITEM_PRICING_OP' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_pricing_op;
        WHEN 'ITEM_PRICING_VALIDATION' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_pricing_op;
        WHEN 'ITEM_ADMIN' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_admin;
        WHEN 'ITEM_CPQ' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_cpq;
        WHEN 'ITEM_BUYER' THEN
          x_role_name := coalesce(get_buyer_user_name(i.n_attribute1),
		          l_q_xxinv_item_wf_approvers_v.xx_wf_item_buyer,
		          '-2');
        WHEN 'ITEM_PLANNER1' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_planner;
        WHEN 'ITEM_PLANNER2' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_planner;
        
        WHEN 'ITEM_OPS' THEN
          -- only for make items
          CASE l_planning_make_buy_code
	WHEN 1 THEN
	  x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_ops;
	ELSE
	  x_role_name := '-2';
          END CASE; -- -2 = not required
      
        WHEN 'ITEM_PSM' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_psm;
        WHEN 'ITEM_PM' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_pm;
          --CHG0045539
        WHEN 'ITEM_WH' THEN
          x_role_name := l_q_xxinv_item_wf_approvers_v.xx_wf_item_wh;
        
      -- end CHG0045539
        ELSE
          x_role_name := NULL;
      END CASE;
    
      --- check buyer
      IF l_replacing_item_id != -2 AND i.doc_code = 'ITEM_SP' AND
        
         p_role_code IN ('ITEM_BUYER' /*, 'ITEM_PSO'*/) THEN
        x_role_name := '-2'; --not required
      
      END IF;
    
    END LOOP;
  
    IF x_role_name IS NULL THEN
      x_err_code    := 1;
      x_err_message := 'No Approver Found for Role ' || p_role_code ||
	           ' technology=' || l_segment6 || ' product_family=' ||
	           l_segment3 || ' product_sub_family=' || l_segment4 ||
	           ' Please check setup in q_xxinv_item_wf_approvers_v';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code    := 1;
      x_err_message := 'No Approver Found for Role ' || p_role_code ||
	           ' technology=' || l_segment6 || ' product_family=' ||
	           l_segment3 || ' product_sub_family=' || l_segment4 ||
	           ' Please check setup in q_xxinv_item_wf_approvers_v';
    
  END get_approver;

  -- *****************************************************************************************
  -- Object Name:  get_approval_doc_code
  -- Type       :   Function
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_inv_item_id       In     ???
  --       p_mode              In     ???
  --       p_old_status        Out    ???
  --       p_new_status        Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --  1.1    14.11.19     yuval tal         CHG0046825 - add logic to intiate sales item -Active PTO
  --  1.2    19.03.20     yuval tal         CHG0047452 - change status list to be fetch from collection view
  --
  -- *****************************************************************************************
  FUNCTION get_approval_doc_code(p_inv_item_id NUMBER,
		         p_mode        VARCHAR2,
		         p_old_status  VARCHAR2,
		         p_new_status  VARCHAR2,
		         p_item_type   VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_is_item_fg       VARCHAR2(1);
    l_customer_support VARCHAR2(50);
    l_item_type        VARCHAR2(50);
    l_item_new_status  VARCHAR2(50);
    l_doc_code         VARCHAR2(20);
  BEGIN
  
    ---
  
    --
    logger('p_mode=' || p_mode);
    l_is_item_fg := xxinv_item_classification.is_item_fg(p_inv_item_id);
  
    IF p_item_type IS NULL THEN
      l_item_type := xxinv_item_classification.get_item_type(p_inv_item_id);
    ELSE
      l_item_type := p_item_type;
    END IF;
  
    l_customer_support := xxinv_utils_pkg.get_category_segment(p_segment_name      => 'SEGMENT1',
					   p_category_set_id   => 1100000221,
					   p_inventory_item_id => p_inv_item_id);
  
    IF p_new_status IS NULL THEN
      SELECT t.inventory_item_status_code
      INTO   l_item_new_status
      FROM   mtl_system_items_b t
      WHERE  inventory_item_id = p_inv_item_id
      AND    organization_id = 91;
    ELSE
      l_item_new_status := p_new_status;
    END IF;
  
    logger('is_item_fg=' || l_is_item_fg);
    logger('item_type=' || l_item_type);
    logger('customer_support=' || l_customer_support);
    logger('old_status=' || p_old_status);
    logger('current item_status=' || l_item_new_status);
  
    SELECT doc_code
    INTO   l_doc_code
    FROM   (SELECT 'ITEM_CLTW' doc_code
	FROM   dual
	WHERE  p_mode = 'INSERT'
	AND    l_is_item_fg = 'Y'
	AND    l_customer_support = 'Customer Support'
	AND    l_item_type IN ('XXSSYS_SC_GENERIC',
		           'XXOBJ_SER',
		           'XXOBJ_SER_EXP',
		           'XXSSYS_WARRANTY',
		           'XXSSYS_SC_DIAMOND',
		           'XXSSYS_SC_EMERALD',
		           'XXSSYS_SC_PARTNER_DIAMOND',
		           'XXSSYS_SC_PARTNER_EMERALD',
		           'XXSSYS_SC_PARTNER_SAPPHIRE',
		           'XXSSYS_SC_SAPPHIRE')
	UNION ALL
	SELECT 'ITEM_SP'
	FROM   dual
	WHERE  xxinv_item_classification.is_item_fg(p_inv_item_id) = 'Y'
	AND    l_customer_support = 'Customer Support'
	AND    ((p_mode = 'INSERT' AND
	        l_item_new_status IN
	        (SELECT status
	          FROM   q_xxinv_item_wf_status_initi_v t
	          WHERE  xx_wf_type = 'ITEM_SP'
	          AND    action_type = 'INSERT')) OR
	        (p_mode = 'UPDATE' AND
	        p_old_status IN
	        (SELECT status
	          FROM   q_xxinv_item_wf_status_initi_v t
	          WHERE  xx_wf_type = 'ITEM_SP'
	          AND    action_type = 'UPDATE'
	          AND    version = 'OLD') AND
	        l_item_new_status IN
	        (SELECT status
	          FROM   q_xxinv_item_wf_status_initi_v t
	          WHERE  xx_wf_type = 'ITEM_SP'
	          AND    action_type = 'UPDATE'
	          AND    version = 'NEW')))
	UNION ALL
	SELECT 'ITEM_SALE'
	FROM   dual
	WHERE  xxinv_item_classification.is_item_fg(p_inv_item_id) = 'Y'
	AND    l_customer_support != 'Customer Support'
	AND    ((p_mode = 'INSERT' AND
	        l_item_new_status IN
	        ('XX_ALPHA', 'XX_BETA', 'XX_PROD', 'Active PTO')) OR
	        (p_mode = 'UPDATE' AND
	        p_old_status IN
	        (SELECT status
	          FROM   q_xxinv_item_wf_status_initi_v t
	          WHERE  xx_wf_type = 'ITEM_SALE'
	          AND    action_type = 'UPDATE'
	          AND    version = 'OLD') AND
	        l_item_new_status IN
	        (SELECT status
	          FROM   q_xxinv_item_wf_status_initi_v t
	          WHERE  xx_wf_type = 'ITEM_SALE'
	          AND    action_type = 'UPDATE'
	          AND    version = 'NEW')
	        
	        )))
    WHERE  rownum = 1;
  
    RETURN l_doc_code;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END get_approval_doc_code;

  -- *****************************************************************************************
  -- Object Name:  post_user_response
  -- Type       :  Procedure
  -- Create By  :  Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       x_err_code          Out    ???
  --       x_err_message       Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE post_user_response(p_doc_instance_id NUMBER,
		       x_err_code        OUT VARCHAR2, --1/0
		       x_err_message     OUT VARCHAR2) IS
  BEGIN
    NULL;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code    := 1;
      x_err_message := SQLERRM;
  END post_user_response;

  -- *****************************************************************************************
  -- Object Name:  get_user_role
  -- Type       :  Function
  -- Create By  :  Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       p_user_NAME           In     ???

  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  FUNCTION get_user_role(p_doc_instance_id NUMBER,
		 p_user_name       VARCHAR2) RETURN VARCHAR2 IS
    l_dynamic_role VARCHAR2(240);
  BEGIN
    SELECT dynamic_role
    INTO   l_dynamic_role
    FROM   xxobjt_wf_doc_history  h,
           xxobjt_wf_doc_instance t
    WHERE  h.doc_instance_id = p_doc_instance_id
    AND    h.doc_instance_id = t.doc_instance_id
    AND    role_name = p_user_name
    AND    t.current_seq_appr = h.seq_no;
  
    RETURN l_dynamic_role;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '';
  END;

  -- *****************************************************************************************
  -- Object Name:  get_notification_body
  -- Type       :  Procedure
  -- Create By  :  Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name             Type    Purpose
  --       --------         ----    -----------
  --       document_id      In      ???
  --       display_type     In      ???
  --       document         In/Out  ???
  --       document_type    In/Out  ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE get_notification_body(document_id   IN VARCHAR2,
		          display_type  IN VARCHAR2,
		          document      IN OUT NOCOPY CLOB,
		          document_type IN OUT NOCOPY VARCHAR2) IS
  
    g_item_type VARCHAR2(100) := 'XXWFDOC';
    -- c_debug_module CONSTANT VARCHAR2(100) := 'xxap.payment_approval.xxiby_pay_aprroval_util.';
  
    l_doc_instance_id NUMBER := to_number(document_id);
    l_history_clob    CLOB;
    -- l_body_msg        VARCHAR2(32767);
  
    /* CURSOR c_info IS
    SELECT *
    FROM   xxobjt_wf_doc_instance t
    WHERE  t.doc_instance_id = l_doc_instance_id;*/ -- n_attribute1 = item_id
  
  BEGIN
  
    -- Debug Message
    /*    fnd_log.string(log_level => fnd_log.level_event,
    module    => c_debug_module || 'get_notification_body',
    message   => 'fnd_global.user_id=' || fnd_global.user_id ||
                 ' fnd_global.resp_id=' || fnd_global.resp_id ||
                 ' fnd_global.resp_appl_id=' ||
                 fnd_global.resp_appl_id ||
                 ' fnd_global.employee_id=' ||
                 fnd_global.employee_id || ' document_id :' ||
                 document_id || ' display_type :' ||
                 display_type || ' l_numeric_format_mask :' ||
                 l_numeric_format_mask);*/
  
    l_doc_instance_id := to_number(document_id);
  
    document_type := 'text/html';
    document      := ' ';
    dbms_lob.append(document,
	        '<p> <font face="Verdana" style="color:darkblue" size="3">
	        <strong>Item Approval workflow</strong> </font> </p>');
    dbms_lob.append(document,
	        '<font face="arial" style="color:black;" size="2">');
  
    -- add history
    l_history_clob := NULL;
    dbms_lob.append(document,
	        '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
			display_type  => '',
			document      => l_history_clob,
			document_type => document_type);
  
    dbms_lob.append(document, l_history_clob);
  
    /* EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
                     module    => c_debug_module || 'get_notification_body',
                     message   => 'OTHERS Exception SQL Error :' || SQLERRM);*/
  
  END get_notification_body;

  -- get_buyer_user_name
  --  ------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --                                        logic will be based on collection quality plan table
  --
  -- ------------------------------------------------------------------------------------------------

  FUNCTION get_buyer_user_name(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_user_name              VARCHAR2(50);
    l_planning_make_buy_code NUMBER; --1 make 2 buy
  BEGIN
  
    SELECT /*item_org.* ,*/
     item_org.planning_make_buy_code,
     (SELECT p.user_name buyer
      FROM   apps.fnd_user p
      WHERE  p.employee_id = nvl(m.attribute27, m.buyer_id))
    INTO   l_planning_make_buy_code,
           l_user_name
    FROM   (SELECT msi.planning_make_buy_code,
	       msi.inventory_item_id,
	       msi.segment1 item,
	       CASE mic.segment6
	         WHEN 'FDM' THEN
	          739
	         ELSE
	          CASE mic.segment1
		WHEN 'MATERIAL' THEN
		 734
		ELSE
		 735
	          END
	       END buyer_org,
	       msi.inventory_item_status_code,
	       msi.item_type,
	       mic.segment7,
	       mic.segment1,
	       mic.segment6
	FROM   mtl_system_items_b    msi,
	       mtl_item_categories_v mic
	WHERE  1 = 1
	      --and   msi.segment1 = 'OBJ-03200'
	AND    msi.inventory_item_id = p_item_id
	AND    msi.organization_id = 91
	AND    msi.inventory_item_id = mic.inventory_item_id
	AND    msi.organization_id = mic.organization_id
	AND    mic.segment7 = 'FG'
	AND    mic.category_set_id = 1100000221) item_org,
           mtl_system_items_b m
    WHERE  m.inventory_item_id = item_org.inventory_item_id
    AND    m.organization_id = item_org.buyer_org;
  
    IF l_planning_make_buy_code = 2 THEN
      RETURN l_user_name;
    ELSE
      RETURN '-2'; -- not required
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  -- *****************************************************************************************
  -- Object Name:  get_field_security_info
  -- Type       :  Function
  -- Create By  :  Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :
  /*.      1. If status ?APPROVED? = all fields in read only
  2.  profile XXINVWF_ADMIN =?Y? ? all fields editable
  3.  if p_user_id =owner then
  a.  base on view XXINV_WF_ROLES_FLDS_SECURITY_V
  b.  fields
  4.  else : all fields in read only*/

  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE get_field_security_info(p_doc_instance_id NUMBER,
			p_field_name      VARCHAR2,
			p_person_id       VARCHAR2 DEFAULT fnd_global.employee_id,
			p_required        OUT VARCHAR2,
			p_enterable       OUT VARCHAR2) IS
    l_approver_person_id NUMBER;
    l_user_role          VARCHAR2(50);
    l_doc_code           VARCHAR2(20);
    l_user_name          VARCHAR2(50);
  BEGIN
  
    p_required  := 'N';
    p_enterable := 'N';
  
    IF xxobjt_wf_doc_util.get_doc_status(p_doc_instance_id) NOT IN
       ('IN_PROCESS') THEN
      -- logger('Status='||xxobjt_wf_doc_util.get_doc_status(p_doc_instance_id));
      RETURN;
    ELSIF fnd_profile.value('XXINVWF_ADMIN') = 'Y' THEN
      p_required  := 'N';
      p_enterable := 'Y';
      RETURN;
    ELSE
      -- check owner=loged user  and role
      -- fetch detaild from view
    
      SELECT approver_person_id,
	 d.doc_code
      INTO   l_approver_person_id,
	 l_doc_code
      FROM   xxobjt_wf_doc_instance t,
	 xxobjt_wf_docs         d
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    d.doc_id = t.doc_id;
    
      IF l_approver_person_id = p_person_id THEN
        -- FETCH FROM VIEW
      
        SELECT user_name
        INTO   l_user_name
        FROM   fnd_user
        WHERE  employee_id = p_person_id;
      
        -- l_user_role := 'ITEM_CPQ'; --'ITEM_PM';
        l_user_role := get_user_role(p_doc_instance_id => p_doc_instance_id,
			 p_user_name       => l_user_name);
      
        -- open view cursor
        BEGIN
          SELECT t.required_flag,
	     t.enterable_flag
          INTO   p_required,
	     p_enterable
          FROM   xxinv_wf_roles_flds_security_v t
          WHERE  t.doc_code = l_doc_code
          AND    t.role_code = l_user_role
          AND    t.field_name = p_field_name;
        
        EXCEPTION
          WHEN no_data_found THEN
	p_required  := 'N';
	p_enterable := 'N';
        END;
      END IF;
    
    END IF;
  
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               approve
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :          used from item approval form to support  next button
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
  
  BEGIN
  
    -- check required fields
  
    check_required_fields(p_doc_instance_id => p_doc_instance_id,
		  
		  p_err_code    => p_err_code,
		  p_err_message => p_err_message);
  
    IF p_err_code = 0 THEN
      xxobjt_wf_doc_util.approve(p_doc_instance_id,
		         p_note,
		         p_err_code,
		         p_err_message);
    END IF;
  
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               check_required_field
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :  heck all fields filled according to track /approver
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   30.4.19       yuval tal       check all fields filled according to track /approver
  --   1.2  18.11.19      yuval tal       CHG0046825 - remove & , it cause extract of xmltype to fail
  -----------------------------------------------------------------------

  PROCEDURE check_required_fields(p_doc_instance_id NUMBER,
		          
		          p_err_code    OUT NUMBER,
		          p_err_message OUT VARCHAR2) IS
  
    CURSOR c_data_exists IS
      SELECT 1
      FROM   xxinv_wf_item_data
      WHERE  doc_instance_id = p_doc_instance_id;
  
    CURSOR c_stage IS
      SELECT h.dynamic_role,
	 d.doc_code,
	 i.current_seq_appr
      FROM   xxobjt_wf_doc_instance i,
	 xxobjt_wf_docs         d,
	 xxobjt_wf_doc_history  h
      WHERE  h.doc_instance_id = i.doc_instance_id
      AND    i.doc_id = d.doc_id
      AND    h.seq_no = i.current_seq_appr
      AND    i.doc_instance_id = p_doc_instance_id;
  
    CURSOR c_security_check(c_doc_code  VARCHAR2,
		    c_role_code VARCHAR2) IS
      SELECT t.required_flag,
	 t.enterable_flag,
	 t.field_name
      
      FROM   xxinv_wf_roles_flds_security_v t
      WHERE  t.doc_code = c_doc_code
      AND    t.role_code = c_role_code;
    --  AND    t.field_name <> 'APPLICABLE_SYSTEM';
  
    l_tmp NUMBER;
    TYPE t_arr IS TABLE OF VARCHAR2(1000) INDEX BY VARCHAR2(50);
    l_arr t_arr;
  BEGIN
    p_err_code := 0;
    -- check data exists
  
    OPEN c_data_exists;
    FETCH c_data_exists
      INTO l_tmp;
    CLOSE c_data_exists;
  
    IF l_tmp IS NULL THEN
    
      p_err_code    := 1;
      p_err_message := 'No data found in xxinv_wf_item_data for p_doc_instance_id=' ||
	           p_doc_instance_id;
      RETURN;
    
    END IF;
  
    -- move approval data to array key = FIELD name and value = field value
  
    DECLARE
      l_xml CLOB; --CHG0046825
    
      CURSOR c IS
        SELECT column_name
        FROM   all_tab_columns
        WHERE  table_name = 'XXINV_WF_ITEM_DATA';
      l_value VARCHAR2(2000);
    BEGIN
    
      l_xml := dbms_xmlgen.getxml('select * from xxinv_wf_item_data where DOC_INSTANCE_ID=' ||
		          to_char(p_doc_instance_id));
    
      l_xml := REPLACE(l_xml, '&'); -- CHG0046825
      FOR i IN c LOOP
      
        SELECT extractvalue(xmltype(l_xml), 'ROWSET/ROW/' || i.column_name)
        INTO   l_value
        FROM   dual;
      
        l_arr(i.column_name) := l_value;
        logger(i.column_name || ' = ' || l_value);
      
      END LOOP;
    
      -- check applicable system
      BEGIN
        l_tmp := NULL;
      
        SELECT 1
        INTO   l_tmp
        FROM   xxinv_wf_item_data_lines
        WHERE  doc_instance_id = p_doc_instance_id
        AND    child_type = 'APPLICABLE SYSTEM'
        AND    c_attribute1 = 'Y'
        AND    rownum = 1;
      
        l_arr('APPLICABLE_SYSTEM') := 'APPLICABLE_SYSTEM';
        logger('APPLICABLE_SYSTEM' || ' = ' || 'Exists');
      EXCEPTION
      
        WHEN OTHERS THEN
          l_arr('APPLICABLE_SYSTEM') := '';
          logger('APPLICABLE_SYSTEM' || ' = ');
        
      END;
    
    END;
  
    -----
  
    FOR i IN c_stage LOOP
      -- for track and role
      FOR j IN c_security_check(i.doc_code, i.dynamic_role) LOOP
        -- loop on relevant fields to check
        IF j.required_flag = 'Y' AND l_arr(j.field_name) IS NULL THEN
        
          logger('Field  ' || j.field_name || ' must be filled .');
          p_err_code := 1;
          --p_err_message := 'Field  ' || j.field_name || ' must be filled .';
          p_err_message := p_err_message || (CASE
		     WHEN p_err_message IS NOT NULL THEN
		      ','
		     ELSE
		      ''
		   END) || j.field_name;
          --RETURN;
        END IF;
      
      END LOOP;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := substr('check_required_fields.' || SQLERRM, 1, 250);
  END;
  FUNCTION is_category_assignment_found(p_item_id           NUMBER,
			    p_category_set_name VARCHAR2,
			    p_category_id       NUMBER)
    RETURN VARCHAR2 IS
    l_ret_val VARCHAR2(1);
  BEGIN
    SELECT 'Y'
    INTO   l_ret_val
    FROM   mtl_item_categories_v x
    WHERE  inventory_item_id = p_item_id
    AND    organization_id = 91
    AND    category_set_name = p_category_set_name
    AND    category_id = p_category_id;
  
    RETURN l_ret_val;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_category_assignment_found;

  PROCEDURE delete_category_assignment(p_item_id NUMBER) IS
    CURSOR c_cat_list IS
      SELECT category_id,
	 category_set_id,
	 category_set_name
      FROM   mtl_item_categories_v
      WHERE  inventory_item_id = p_item_id
      AND    organization_id = 91
	--and CATEGORY_SET_NAME = p_category_set_name
      AND    category_set_name IN
	 ('SALES Price Book Product Type',
	   'CS Price Book Product Type',
	   'CS Recommended stock')
      ORDER  BY category_set_id;
  
    l_msg_index_out NUMBER;
    l_error_message VARCHAR2(4000);
    l_return_status VARCHAR2(80);
  
    l_error_code NUMBER;
    l_msg_count  NUMBER;
    l_msg_data   VARCHAR2(2000);
  
    l_prog_step VARCHAR2(20);
    l_rec_cnt   NUMBER := 0;
  BEGIN
    logger('Delete_Category_Assignment.');
    FOR rec IN c_cat_list LOOP
      l_rec_cnt := l_rec_cnt + 1;
      logger('    CATEGORY SET NAME - ' || rec.category_set_name ||
	 ' And Category ID ' || rec.category_id);
    
      inv_item_category_pub.delete_category_assignment(p_api_version       => 1.0, --IN   NUMBER,
				       p_init_msg_list     => fnd_api.g_true, --IN   VARCHAR2 DEFAULT FND_API.G_FALSE,
				       p_commit            => fnd_api.g_true, --IN   VARCHAR2 DEFAULT FND_API.G_FALSE,
				       x_return_status     => l_return_status, --OUT  NOCOPY VARCHAR2,
				       x_errorcode         => l_error_code, --OUT  NOCOPY NUMBER,
				       x_msg_count         => l_msg_count, --OUT  NOCOPY NUMBER,
				       x_msg_data          => l_msg_data, --OUT  NOCOPY VARCHAR2,
				       p_category_id       => rec.category_id, --IN   NUMBER,
				       p_category_set_id   => rec.category_set_id, --IN   NUMBER,
				       p_inventory_item_id => p_item_id, --IN   NUMBER,
				       p_organization_id   => 91 --,IN   NUMBER
				       );
      l_error_message := l_msg_data;
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        FOR i IN 1 .. l_msg_count LOOP
          apps.fnd_msg_pub.get(p_msg_index     => i,
		       p_encoded       => fnd_api.g_false,
		       p_data          => l_msg_data,
		       p_msg_index_out => l_msg_index_out);
        
          IF l_error_message IS NULL THEN
	l_error_message := substr(l_msg_data, 1, 250);
          ELSE
	l_error_message := l_error_message || ' /' ||
		       substr(l_msg_data, 1, 250);
          END IF;
        END LOOP;
        logger('Error in Category Assignment Deleation :' ||
	   l_error_message);
        logger('');
      END IF;
    END LOOP;
    IF l_rec_cnt = 0 THEN
      logger('No Existing Category Assignment[SALES Price Book Product Type/' ||
	 'CS Price Book Product Type/CS Recommended stock] found for Deleation.');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      logger('Error in Delete_Category_Assignment:' || SQLERRM);
  END delete_category_assignment;
  -- *****************************************************************************************
  -- Object Name:  sync_item
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : push temp item data to oracle table via API/open interface table
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       x_err_code          Out    ???
  --       x_err_message       Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --  1.1 12.9.19         yuval tal         CHG0046494  - add relation with new optional replacement item
  --
  -- *****************************************************************************************
  PROCEDURE sync_item(errbuf            OUT VARCHAR2,
	          retcode           OUT NUMBER,
	          p_doc_instance_id NUMBER) IS
  
    CURSOR c_item_data IS
      SELECT o.doc_code,
	 d.*
      FROM   xxinv_wf_item_data     d,
	 xxobjt_wf_docs         o,
	 xxobjt_wf_doc_instance ins
      WHERE  d.doc_instance_id = p_doc_instance_id
      AND    ins.doc_instance_id = d.doc_instance_id
      AND    o.doc_id = ins.doc_id;
  
    CURSOR c_applicable_systems IS
      SELECT n_attribute1 category_id
      FROM   xxinv_wf_item_data_lines t
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    t.child_type = 'APPLICABLE SYSTEM'
      AND    t.c_attribute1 = 'Y';
  
    l_err_code             NUMBER;
    l_err_message          VARCHAR2(4000);
    l_relationship_type_id NUMBER;
    myexception EXCEPTION;
    l_category_id                 NUMBER;
    l_applicable_sys_cat_set_name VARCHAR2(50);
    l_err_flag                    NUMBER := 0;
  
  BEGIN
    --- check flow status  ???????? TBD
    -- process_item_attributes
    logger('Begin Sync_Item Process');
    logger('Call Procedure process_item_attribute with Doc Instance Id :' ||
           p_doc_instance_id);
    process_item_attribute(p_doc_instance_id, l_err_code, l_err_message);
    l_err_flag := greatest(l_err_flag, l_err_code);
  
    logger('+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
    logger('MTL_SYSTEM_ITEMS_B : Process Item Attributes :' ||
           (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
           (CASE WHEN l_err_code != 0 THEN
	chr(10) || rpad(' ', 22, ' ') || '  Error Message :' ||
	l_err_message ELSE '' END));
  
    FOR i IN c_item_data LOOP
      logger('');
      logger(' Inventory Item Id  :' || i.inventory_item_id);
      logger(' Item Code          :' ||
	 xxinv_utils_pkg.get_item_segment(i.inventory_item_id, 91));
    
      --------------------------------
      logger('PRINTER_ITEM_ID => ' || i.printer_item_id);
      logger('FIRST_QTY_MAIN => ' || i.first_qty_main);
      logger('FIRST_QTY_US => ' || i.first_qty_us);
      logger('FIRST_QTY_EU => ' || i.first_qty_eu);
      logger('FIRST_QTY_APJ => ' || i.first_qty_apj);
      logger('RECOMMENDED_STOCK_11_50 => ' || i.recommended_stock_11_50);
      logger('VISIBLE_IN_PB => ' || i.visible_in_pb);
      logger('E_COMMERS => ' || i.e_commers);
      logger('EXCLUDE_FROM_CPQ => ' || i.exclude_from_cpq);
      logger('INTERNAL_USE_ONLY => ' || i.internal_use_only);
      logger('DIMENTIONS => ' || i.dimentions);
      logger('VISUAL_SP_CATALOG => ' || i.visual_sp_catalog);
      logger('GENERAL_COMMENT => ' || i.general_comment);
      logger('ONHAND_IND => ' || i.onhand_ind);
      logger('ROUTING => ' || i.routing);
      logger('BUY_ITEM_COST => ' || i.buy_item_cost);
      logger('LAST_UPDATE_DATE => ' || i.last_update_date);
      logger('LAST_UPDATED_BY => ' || i.last_updated_by);
      logger('CS_CATEGORY => ' || i.cs_category);
      logger('REMARK_SP_CAT => ' || i.remark_sp_cat);
      logger('ITEM_LONG_DESCRIPTION => ' || i.item_long_description);
      logger('INVENTORY_ITEM_ID => ' || i.inventory_item_id);
      logger('DOC_INSTANCE_ID => ' || i.doc_instance_id);
      logger('CREATION_DATE => ' || i.creation_date);
      logger('CREATED_BY => ' || i.created_by);
      logger('RECOMMENDED_STOCK_51 => ' || i.recommended_stock_51);
      logger('RECOMMENDED_ENG_STOCK => ' || i.recommended_eng_stock);
      logger('RETURNABLE_PART => ' || i.returnable_part);
      logger('PART_FAMILY => ' || i.part_family);
      logger('ACTIVITY_ANALYSIS => ' || i.activity_analysis);
      logger('CHECK_PH => ' || i.check_ph);
      logger('RECOMMENDED_STOCK_1_10 => ' || i.recommended_stock_1_10);
      logger('LAST_UPDATE_LOGIN => ' || i.last_update_login);
      logger('SERVICE_CONSUMABLE => ' || i.service_consumable);
      logger('SP_FOR_BETA => ' || i.sp_for_beta);
      logger('PUBLISH_MYSSYS => ' || i.publish_myssys);
      logger('FIRST_YEAR_CONSUMPTION_QTY => ' ||
	 i.first_year_consumption_qty);
      logger('INVENTORY_EXPECTED_DATE => ' || i.inventory_expected_date);
      logger('REPLACING_ITEM_ID => ' || i.replacing_item_id);
      logger('REPLACEMENT_ITEM_ID_OPTIONAL => ' ||
	 i.replacement_item_id_opt); --CHG0046494
      --------------------------------
      -- item_category
      -------------------------------
    
      logger('');
      --Remove All Assigment Then Reassign Again
      delete_category_assignment(i.inventory_item_id);
    
      IF i.doc_code = 'ITEM_SP' THEN
        -- CS Recommended stock 1-10
        IF i.recommended_stock_1_10 IS NOT NULL THEN
          process_item_category2(p_item_id           => i.inventory_item_id,
		         p_category_set_name => 'CS Recommended stock',
		         p_category_id       => i.recommended_stock_1_10,
		         p_err_code          => l_err_code,
		         p_err_message       => l_err_message);
        
          --l_err_flag := greatest(l_err_flag, l_err_code);
          l_err_flag := nvl(l_err_code, 0);
          logger('Category : CS Recommended stock 1-10:[CATEGORY_ID-' ||
	     i.recommended_stock_1_10 || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : CS Recommended stock 1-10 : No Value Available to Sync.');
        END IF;
      
        logger('');
      
        --- recommended_stock_11_50
      
        IF i.recommended_stock_11_50 IS NOT NULL THEN
          process_item_category2(p_item_id           => i.inventory_item_id,
		         p_category_set_name => 'CS Recommended stock',
		         p_category_id       => i.recommended_stock_11_50,
		         p_err_code          => l_err_code,
		         p_err_message       => l_err_message);
        
          l_err_flag := greatest(l_err_flag, l_err_code);
        
          logger('Category : CS Recommended stock 11-50 :[CATEGORY_ID-' ||
	     i.recommended_stock_11_50 || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : CS Recommended stock 11-50 : No Value Available to Sync.');
        END IF;
        ----- CS Recommended stock 51
        logger('');
        IF i.recommended_stock_51 IS NOT NULL THEN
          process_item_category2(p_item_id           => i.inventory_item_id,
		         p_category_set_name => 'CS Recommended stock',
		         p_category_id       => i.recommended_stock_51,
		         p_err_code          => l_err_code,
		         p_err_message       => l_err_message);
        
          l_err_flag := greatest(l_err_flag, l_err_code);
        
          logger('Category : CS Recommended stock 51 :[CATEGORY_ID-' ||
	     i.recommended_stock_51 || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : CS Recommended stock 51 : No Value Available to Sync.');
        END IF;
      
        logger('');
        --'CS Recommended stock'
        IF i.recommended_eng_stock IS NOT NULL THEN
          process_item_category2(p_item_id           => i.inventory_item_id,
		         p_category_set_name => 'CS Recommended stock',
		         p_category_id       => i.recommended_eng_stock,
		         p_err_code          => l_err_code,
		         p_err_message       => l_err_message);
        
          logger('Category : CS Recommended stock :[CATEGORY_ID-' ||
	     i.recommended_eng_stock || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : CS Recommended stock [recommended_eng_stock] : No Value Available to Sync.');
        END IF;
      
      END IF;
    
      ----------------------------------------------------------------
    
      logger('');
      -- Visible in MySSYS
      IF i.publish_myssys IS NOT NULL THEN
        IF i.doc_code NOT IN ('ITEM_SP', 'ITEM_CLTW') THEN
          process_item_category(p_item_id           => i.inventory_item_id,
		        p_category_set_name => 'Visible in MySSYS',
		        p_key_seg_no        => 1,
		        p_seg1              => i.publish_myssys,
		        p_err_code          => l_err_code,
		        p_err_message       => l_err_message);
          l_err_flag := greatest(l_err_flag, l_err_code);
        
          logger('Category : Visible in MySSYS :[SEGMENT1- ' ||
	     i.publish_myssys || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : Visible in MySSYS: Excluded from Syncing, As workflow Type is:' ||
	     i.doc_code);
        END IF;
      ELSE
        logger('Category : Visible in MySSYS : No Value to Sync');
      END IF;
    
      logger('');
      ---Visible in PB
      IF i.visible_in_pb IS NOT NULL THEN
        IF i.doc_code NOT IN ('ITEM_SP', 'ITEM_CLTW') THEN
          process_item_category(p_item_id           => i.inventory_item_id,
		        p_category_set_name => 'Visible in PB',
		        p_key_seg_no        => 1,
		        p_seg1              => i.visible_in_pb,
		        p_err_code          => l_err_code,
		        p_err_message       => l_err_message);
          l_err_flag := greatest(l_err_flag, l_err_code);
          logger('Category : Visible in PB :[SEGMENT1- ' ||
	     i.visible_in_pb || ']' ||
	     (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	     chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	     l_err_message);
        ELSE
          logger('Category : Visible in PB :Excluded from Syncing, As workflow Type is:' ||
	     i.doc_code);
        END IF;
      ELSE
        logger('Category : Visible in PB : No Value to Sync');
      END IF;
    
      logger('');
      --'Exclude from CPQ'
      IF i.exclude_from_cpq IS NOT NULL THEN
        process_item_category(p_item_id           => i.inventory_item_id,
		      p_category_set_name => 'Exclude from CPQ',
		      p_key_seg_no        => 1,
		      p_seg1              => i.exclude_from_cpq,
		      p_err_code          => l_err_code,
		      p_err_message       => l_err_message);
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Category : Exclude from CPQ :[SEGMENT1- ' ||
	   i.exclude_from_cpq || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	   l_err_message);
      ELSE
        logger('Category : Exclude from CPQ : No Value to Sync');
      END IF;
    
      logger('');
      --Internal Use Only
      IF i.internal_use_only IS NOT NULL THEN
        process_item_category(p_item_id           => i.inventory_item_id,
		      p_category_set_name => 'Internal Use Only',
		      p_key_seg_no        => 1,
		      p_seg1              => i.internal_use_only,
		      p_err_code          => l_err_code,
		      p_err_message       => l_err_message);
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Category : Internal Use Only :[SEGMENT1- ' ||
	   i.internal_use_only || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	   l_err_message);
      ELSE
        logger('Category : Internal Use Only : No Value to Sync');
      END IF;
      ---
      logger('');
      --Activity Analysis
      IF i.activity_analysis IS NOT NULL THEN
        process_item_category2(p_item_id           => i.inventory_item_id,
		       p_category_set_name => 'Activity Analysis',
		       p_category_id       => i.activity_analysis,
		       p_err_code          => l_err_code,
		       p_err_message       => l_err_message);
      
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Category : Activity Analysis :[Category ID- ' ||
	   i.activity_analysis || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	   l_err_message);
      ELSE
        logger('Category : Activity Analysis : No Value to Sync');
      END IF;
      ---
    
      ---
      logger('');
      --CS Category Set
      IF i.cs_category IS NOT NULL THEN
        process_item_category2(p_item_id           => i.inventory_item_id,
		       p_category_set_name => 'CS Category Set',
		       p_category_id       => i.cs_category,
		       p_err_code          => l_err_code,
		       p_err_message       => l_err_message);
      
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Category : CS Category Set :[Category ID- ' ||
	   i.cs_category || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   chr(10) || rpad(' ', 22, ' ') || ' Message :' ||
	   l_err_message);
      ELSE
        logger('Category : CS Category Set : No Value to Sync');
      END IF;
      ---
    
      logger('');
      -- process_item_relation 2- Substitute  - 5 service
      -- logger('Start Processing Replacing Item.');
      -- logger('replacing_item_id #'||i.replacing_item_id);
      -- logger('doc_code          #'||i.doc_code);
      IF nvl(i.replacing_item_id, -2) != -2 THEN
        IF i.doc_code IN ('ITEM_SALE', 'ITEM_SP') THEN
          l_relationship_type_id := 2;
        ELSIF i.doc_code = 'ITEM_CLTW' THEN
          l_relationship_type_id := 5;
        END IF;
        --logger('relationship_type_id  #'||l_relationship_type_id);
      
        --logger('Call to process_item_relation.');
        process_item_relation(p_relationship_type_id => l_relationship_type_id,
		      p_item_id              => i.replacing_item_id,
		      p_new_related_item_id  => i.inventory_item_id,
		      p_err_code             => l_err_code,
		      p_err_message          => l_err_message);
      
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Item Relationship [relationship_type_id- ' ||
	   l_relationship_type_id || ']' || '[item_id- ' ||
	   i.inventory_item_id || ']' || '[replacing_item_id- ' ||
	   i.replacing_item_id || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   (CASE WHEN l_err_code != 0 THEN
	    chr(10) || rpad(' ', 22, ' ') || '  Error Message :' ||
	    l_err_message ELSE '' END));
      
      END IF;
    
      --CHG0046494
      ---- add relation with second replacement item
    
      IF nvl(i.replacement_item_id_opt, -2) != -2 THEN
        IF i.doc_code IN ('ITEM_SALE', 'ITEM_SP') THEN
          l_relationship_type_id := 2;
        ELSIF i.doc_code = 'ITEM_CLTW' THEN
          l_relationship_type_id := 5;
        END IF;
      
        process_item_relation(p_relationship_type_id => l_relationship_type_id,
		      p_item_id              => i.replacement_item_id_opt,
		      p_new_related_item_id  => i.inventory_item_id,
		      p_err_code             => l_err_code,
		      p_err_message          => l_err_message);
      
        l_err_flag := greatest(l_err_flag, l_err_code);
      
        logger('Item Relationship [relationship_type_id- ' ||
	   l_relationship_type_id || ']' || '[item_id- ' ||
	   i.inventory_item_id || ']' || '[replacing_item_id- ' ||
	   i.replacement_item_id_opt || ']' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   (CASE WHEN l_err_code != 0 THEN
	    chr(10) || rpad(' ', 22, ' ') || '  Error Message :' ||
	    l_err_message ELSE '' END));
      
      END IF;
      --end CHG0046494
    
      -----------------------------
      -- process_item_attachments
      -------------------------------
      -- l_category_id := 1001089 -- PZText
      BEGIN
        SELECT category_id
        INTO   l_category_id
        FROM   fnd_doc_categories_active_vl
        WHERE  user_name = 'PZ Text';
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    
      -- logger('Category Id of PZ Text :'||l_category_id);
      -- logger('remark_sp_cat #'||i.remark_sp_cat);
      IF i.remark_sp_cat IS NOT NULL THEN
        -- logger('Call to process_item_short_attachment');
        process_item_short_attachment(i.inventory_item_id,
			  91,
			  l_category_id,
			  i.remark_sp_cat,
			  l_err_code,
			  l_err_message);
        l_err_flag := greatest(l_err_flag, l_err_code);
        logger('Item short Attachment :' ||
	   (CASE WHEN l_err_code != 0 THEN 'Failure' ELSE 'Success' END) ||
	   (CASE WHEN l_err_code != 0 THEN
	    chr(10) || rpad(' ', 22, ' ') || '  Error Message :' ||
	    l_err_message ELSE '' END));
      END IF;
    
      ---------------------------------------
      -- applicable systems
      -----------------------------------------
      --CS Price Book Product
      --SALES Price Book Product Type
      logger(chr(10));
      logger('----------------------------------------');
      logger('Start processing Applicable System.');
      logger('----------------------------------------');
    
      FOR j IN c_applicable_systems LOOP
        logger('');
        logger('*******************************************************************************');
      
        IF i.doc_code = 'ITEM_SALE' THEN
          l_applicable_sys_cat_set_name := 'SALES Price Book Product Type';
        ELSE
          l_applicable_sys_cat_set_name := 'CS Price Book Product Type';
        END IF;
      
        logger('DOC CODE :' || i.doc_code);
        logger('Applicable system Cat Set name :' ||
	   l_applicable_sys_cat_set_name);
        logger('Category id :' || j.category_id);
      
        IF l_applicable_sys_cat_set_name IS NOT NULL AND
           j.category_id IS NOT NULL THEN
          IF is_category_assignment_found(i.inventory_item_id,
			      l_applicable_sys_cat_set_name,
			      j.category_id) = 'N' THEN
	process_item_category2(p_item_id           => i.inventory_item_id,
		           p_category_set_name => l_applicable_sys_cat_set_name,
		           p_category_id       => j.category_id,
		           p_err_code          => l_err_code,
		           p_err_message       => l_err_message);
          
	l_err_flag := greatest(l_err_flag, l_err_code);
	--logger('Error  Flag :'|| l_err_flag);
	IF l_err_code > 0 THEN
	  logger('Category Sync failed with Error Messgage :' ||
	         l_err_code || '-' || l_err_message);
	ELSE
	  logger('Category Sync Sucessful.' || l_err_message);
	END IF;
          ELSE
	logger('Assignment found. Nothing to Update.');
          END IF;
        
        END IF;
      
        logger('*******************************************************************************');
      END LOOP;
    
      /*If c_applicable_systems%ROWCOUNT = 0 Then
         logger('- No Records found for Process.');
      End If;*/
      -- send alert mail
    
      IF l_err_flag != 0 THEN
        DECLARE
          CURSOR c_admin_roles IS
	SELECT level_meaning role_name
	FROM   xxobjt_profiles_v t
	WHERE  t.profile_name = 'XXINVWF_ADMIN'
	AND    level_type = 'USER'
	AND    profile_value = 'Y';
        BEGIN
          FOR j IN c_admin_roles LOOP
	xxobjt_wf_mail.send_mail_text(p_to_role     => j.role_name,
			      p_subject     => 'Error while sync item: ' ||
				           xxinv_utils_pkg.get_item_segment(i.inventory_item_id,
							        91) ||
				           ' data to oracle tables',
			      p_body_text   => 'Please check request id' ||
				           fnd_global.conc_request_id,
			      p_err_code    => l_err_code,
			      p_err_message => l_err_message);
          END LOOP;
        
        END;
      
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN myexception THEN
      retcode := 2;
      errbuf  := l_err_message;
      logger('Custom Exception Raised with Error :' || errbuf);
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := l_err_message;
      logger('OTHERS Exception Raised with Error :' || errbuf);
    
  END sync_item;

  -----------------------------------
  -- process_item_category
  ------------------------------------
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :sync item categories
  -- ------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --

  PROCEDURE process_item_category(p_item_id           NUMBER,
		          p_category_set_name VARCHAR2,
		          p_key_seg_no        NUMBER,
		          p_seg1              VARCHAR2,
		          p_seg2              VARCHAR2 DEFAULT NULL,
		          p_seg3              VARCHAR2 DEFAULT NULL,
		          p_seg4              VARCHAR2 DEFAULT NULL,
		          p_seg5              VARCHAR2 DEFAULT NULL,
		          p_seg6              VARCHAR2 DEFAULT NULL,
		          p_seg7              VARCHAR2 DEFAULT NULL,
		          p_err_code          OUT NUMBER,
		          p_err_message       OUT VARCHAR2) IS
  
    CURSOR c_check_categoty_assign IS
    
      SELECT category_id,
	 category_set_id
      FROM   mtl_item_categories_v x
      WHERE  inventory_item_id = p_item_id
      AND    organization_id = 91
      AND    upper(category_set_name) = upper(p_category_set_name);
    --AND    (p_key_seg_no = 0 OR
    --(p_key_seg_no >= 1 AND
    --nvl(x.segment1, '~') = coalesce(p_seg1, x.segment1, '~')));
  
    l_category_id     NUMBER;
    l_new_category_id NUMBER;
    l_category_set_id NUMBER;
  
    --
  
    l_msg_index_out NUMBER;
    l_error_message VARCHAR2(4000);
    x_return_status VARCHAR2(80);
  
    x_error_code NUMBER;
    x_msg_count  NUMBER;
    x_msg_data   VARCHAR2(2000);
    myexception EXCEPTION;
    l_concat_test VARCHAR2(4000);
    l_prog_step   VARCHAR2(20);
  BEGIN
  
    p_err_code    := 0;
    p_err_message := NULL;
    l_prog_step   := 'Step 10';
    l_concat_test := (p_seg1 || p_seg2 || p_seg3 || p_seg4 || p_seg5 ||
	         p_seg6 || p_seg7);
    IF l_concat_test IS NULL THEN
      --logger('No Value Passed to procedure process_item_category, for p_category_set_name#' ||
      --p_category_set_name);
      RETURN;
    END IF;
  
    --check category assigned
    --if yes update else assign
    OPEN c_check_categoty_assign;
    FETCH c_check_categoty_assign
      INTO l_category_id,
           l_category_set_id;
    CLOSE c_check_categoty_assign;
    /*
    If is_category_assignment_found(p_item_id,p_category_set_name,l_category_id) = 'Y' Then
        p_err_message := 'Assignment Found. Nothing to Update.';
        --p_err_code := 1;
        Return;
    else
       logger('l_category_id :'||l_category_id);
       logger('Assignment Not found.');
    End If;
    */
    l_prog_step := 'Step 15';
  
    IF l_category_id IS NOT NULL THEN
    
      -- check category changed
    
      -- fetch new category
      BEGIN
        SELECT mcb.category_id
        INTO   l_new_category_id
        FROM   mtl_categories_b mcb
        WHERE  nvl(mcb.segment1, '~') = coalesce(p_seg1, mcb.segment1, '~')
        AND    nvl(mcb.segment2, '~') = coalesce(p_seg2, mcb.segment2, '~')
        AND    nvl(mcb.segment3, '~') = coalesce(p_seg3, mcb.segment3, '~')
        AND    nvl(mcb.segment4, '~') = coalesce(p_seg4, mcb.segment4, '~')
        AND    nvl(mcb.segment5, '~') = coalesce(p_seg5, mcb.segment5, '~')
        AND    nvl(mcb.segment6, '~') = coalesce(p_seg6, mcb.segment6, '~')
        AND    nvl(mcb.segment7, '~') = coalesce(p_seg7, mcb.segment7, '~')
        AND    mcb.structure_id =
	   (SELECT mcs_b.structure_id
	     FROM   mtl_category_sets_b mcs_b
	     WHERE  mcs_b.category_set_id = l_category_set_id);
      
      EXCEPTION
        WHEN no_data_found THEN
          p_err_message := 'No categoty found for' || p_category_set_name || ' ' ||
		   p_seg1 || '.' || p_seg2 || '.' || p_seg3 || '.' ||
		   p_seg4 || '.' || p_seg5 || '.' || p_seg6 || '.' ||
		   p_seg7;
          p_err_code    := 1;
          RAISE myexception;
        
      END;
    
      l_prog_step := 'Step 20';
      --logger('New / OLD  :'||l_new_category_id ||'/'||l_category_id);
      IF l_new_category_id != l_category_id THEN
        inv_item_category_pub.update_category_assignment(p_api_version       => 1.0,
				         p_init_msg_list     => fnd_api.g_false,
				         p_commit            => fnd_api.g_true,
				         x_return_status     => x_return_status,
				         x_errorcode         => x_error_code,
				         x_msg_count         => x_msg_count,
				         x_msg_data          => x_msg_data,
				         p_category_id       => l_new_category_id,
				         p_category_set_id   => l_category_set_id,
				         p_inventory_item_id => p_item_id,
				         p_organization_id   => 91,
				         p_old_category_id   => l_category_id);
      
        IF x_return_status <> fnd_api.g_ret_sts_success THEN
          p_err_code := 1;
          FOR i IN 1 .. x_msg_count LOOP
	apps.fnd_msg_pub.get(p_msg_index     => i,
		         p_encoded       => fnd_api.g_false,
		         p_data          => x_msg_data,
		         p_msg_index_out => l_msg_index_out);
          
	IF l_error_message IS NULL THEN
	  l_error_message := substr(x_msg_data, 1, 250);
	ELSE
	  l_error_message := l_error_message || ' /' ||
		         substr(x_msg_data, 1, 250);
	END IF;
          END LOOP;
        
          p_err_message := l_error_message;
        
          --logger('*****************************************');
          --logger('API Error : ' || l_error_message);
          --logger('*****************************************');
          --ELSE
          --p_err_message := ('Created Category Assiginment from Item id : ' ||
          -- p_item_id || ' Successfully');
          --logger('*****************************************');
          --logger('Created Category Assiginment from Item id : ' ||
          --p_item_id || ' Successfully');
          --logger('*****************************************');
        END IF;
      ELSE
        p_err_message := 'Nothing to update';
      END IF; -- category changed
    
    ELSE
      --logger('Category ID is null.');
      l_prog_step := 'Step 30';
      --- Insert
    
      SELECT mcs_tl.category_set_id
      INTO   l_category_set_id
      FROM   mtl_category_sets_tl mcs_tl
      WHERE  upper(mcs_tl.category_set_name) = upper(p_category_set_name)
      AND    mcs_tl.language = 'US';
      l_prog_step := 'Step 32';
      BEGIN
        SELECT mcb.category_id
        INTO   l_category_id
        FROM   mtl_categories_b mcb
        WHERE  nvl(mcb.segment1, '~') = coalesce(p_seg1, mcb.segment1, '~')
        AND    nvl(mcb.segment2, '~') = coalesce(p_seg2, mcb.segment2, '~')
        AND    nvl(mcb.segment3, '~') = coalesce(p_seg3, mcb.segment3, '~')
        AND    nvl(mcb.segment4, '~') = coalesce(p_seg4, mcb.segment4, '~')
        AND    nvl(mcb.segment5, '~') = coalesce(p_seg5, mcb.segment5, '~')
        AND    nvl(mcb.segment6, '~') = coalesce(p_seg6, mcb.segment6, '~')
        AND    nvl(mcb.segment7, '~') = coalesce(p_seg7, mcb.segment7, '~')
        AND    mcb.structure_id =
	   (SELECT mcs_b.structure_id
	     FROM   mtl_category_sets_b mcs_b
	     WHERE  mcs_b.category_set_id = l_category_set_id);
      EXCEPTION
        WHEN no_data_found THEN
          p_err_message := 'No categoty found for' || p_category_set_name || ' ' ||
		   p_seg1 || '.' || p_seg2 || '.' || p_seg3 || '.' ||
		   p_seg4 || '.' || p_seg5 || '.' || p_seg6 || '.' ||
		   p_seg7;
          p_err_code    := 1;
          RAISE myexception;
        
      END;
      l_prog_step := 'Step 35';
      inv_item_category_pub.create_category_assignment(p_api_version       => 1.0,
				       p_init_msg_list     => fnd_api.g_true,
				       p_commit            => fnd_api.g_true,
				       x_return_status     => x_return_status,
				       x_errorcode         => x_error_code,
				       x_msg_count         => x_msg_count,
				       x_msg_data          => x_msg_data,
				       p_category_id       => l_category_id,
				       p_category_set_id   => l_category_set_id,
				       p_inventory_item_id => p_item_id,
				       p_organization_id   => 91);
    
      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        FOR i IN 1 .. x_msg_count LOOP
          apps.fnd_msg_pub.get(p_msg_index     => i,
		       p_encoded       => fnd_api.g_false,
		       p_data          => x_msg_data,
		       p_msg_index_out => l_msg_index_out);
        
          IF l_error_message IS NULL THEN
	l_error_message := substr(x_msg_data, 1, 250);
          ELSE
	l_error_message := l_error_message || ' /' ||
		       substr(x_msg_data, 1, 250);
          END IF;
        END LOOP;
        l_prog_step   := 'Step 40';
        p_err_code    := 1;
        p_err_message := l_error_message;
        --logger('*****************************************');
        --logger('API Error : ' || l_error_message);
        --logger('*****************************************');
        --ELSE
        --logger('*****************************************');
        --logger('Created Category Assiginment from Item id : ' || p_item_id ||
        --' Successfully');
        --logger('*****************************************');
      END IF;
    
    END IF;
    l_prog_step := 'Step 50';
  EXCEPTION
    WHEN myexception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Unexpected Error in process_item_category.After ' ||
	           l_prog_step || chr(10) ||
	           'Category Assiginment from Item id : ' || p_item_id ||
	           ' failed for ' || p_category_set_name || chr(10) ||
	           SQLERRM;
    
  END process_item_category;

  -----------------------------------
  -- process_item_category
  ------------------------------------
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :sync item categories
  -- ------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  ---------------------------------------------------------------------------------------------

  PROCEDURE process_item_category2(p_item_id           NUMBER,
		           p_category_set_name VARCHAR2,
		           p_category_id       NUMBER,
		           p_multi_flag        VARCHAR2 DEFAULT 'N',
		           p_err_code          OUT NUMBER,
		           p_err_message       OUT VARCHAR2) IS
  
    CURSOR c_check_categoty_assign IS
    
      SELECT category_id,
	 category_set_id
      FROM   mtl_item_categories_v x
      WHERE  inventory_item_id = p_item_id
      AND    organization_id = 91
      AND    category_set_name = p_category_set_name
      AND    ((p_multi_flag = 'Y' AND category_id = p_category_id) OR
	p_multi_flag = 'N');
  
    l_category_id     NUMBER;
    l_category_set_id NUMBER;
  
    --
  
    l_msg_index_out NUMBER;
    l_error_message VARCHAR2(4000);
    x_return_status VARCHAR2(80);
  
    x_error_code NUMBER;
    x_msg_count  NUMBER;
    x_msg_data   VARCHAR2(2000);
    myexception EXCEPTION;
    l_prog_step VARCHAR2(20);
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
  
    IF p_category_id IS NULL THEN
      RETURN;
    END IF;
    l_prog_step := 'Step 10';
    BEGIN
    
      SELECT mcs_tl.category_set_id
      INTO   l_category_set_id
      FROM   mtl_category_sets_tl mcs_tl
      WHERE  mcs_tl.category_set_name = p_category_set_name
      AND    mcs_tl.language = 'US';
    
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 1;
        p_err_message := 'Category Set :' || p_category_set_name ||
		 ', not found in mtl_category_sets_tl.';
        logger(p_err_message);
        RAISE myexception;
    END;
    l_prog_step := 'Step 15';
  
    OPEN c_check_categoty_assign;
    FETCH c_check_categoty_assign
      INTO l_category_id,
           l_category_set_id;
    CLOSE c_check_categoty_assign;
    l_prog_step := 'Step 20';
  
    IF l_category_id = p_category_id THEN
    
      --  category exists and identical
    
      logger('Category already assigned ');
    
    ELSIF l_category_id IS NULL OR
          p_category_set_name IN
          ('SALES Price Book Product Type',
           'CS Price Book Product Type',
           'CS Recommended stock') THEN
      -- category set doesnt exists
    
      --- Insert
      l_prog_step := 'Step 25';
      inv_item_category_pub.create_category_assignment(p_api_version       => 1.0,
				       p_init_msg_list     => fnd_api.g_true,
				       p_commit            => fnd_api.g_true,
				       x_return_status     => x_return_status,
				       x_errorcode         => x_error_code,
				       x_msg_count         => x_msg_count,
				       x_msg_data          => x_msg_data,
				       p_category_id       => p_category_id,
				       p_category_set_id   => l_category_set_id,
				       p_inventory_item_id => p_item_id,
				       p_organization_id   => 91);
      l_prog_step := 'Step 26';
      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        FOR i IN 1 .. x_msg_count LOOP
          apps.fnd_msg_pub.get(p_msg_index     => i,
		       p_encoded       => fnd_api.g_false,
		       p_data          => x_msg_data,
		       p_msg_index_out => l_msg_index_out);
        
          IF l_error_message IS NULL THEN
	l_error_message := substr(x_msg_data, 1, 250);
          ELSE
	l_error_message := l_error_message || ' /' ||
		       substr(x_msg_data, 1, 250);
          END IF;
        END LOOP;
        l_prog_step   := 'Step 30';
        p_err_code    := 1;
        p_err_message := l_error_message;
        --logger('*****************************************');
        logger('API Error : ' || l_error_message);
        --logger('*****************************************');
      ELSE
        l_prog_step := 'Step 35';
        --logger('*****************************************');
        p_err_code := 0;
        --p_err_message := 'Created Category Assiginment from Item id : ' ||
        -- p_item_id || ' Successfully';
      
        logger(p_err_message);
        --logger('*****************************************');
      END IF;
    ELSIF l_category_id != p_category_id THEN
      -- update
      l_prog_step := 'Step 40';
      inv_item_category_pub.update_category_assignment(p_api_version       => 1.0,
				       p_init_msg_list     => fnd_api.g_false,
				       p_commit            => fnd_api.g_true,
				       x_return_status     => x_return_status,
				       x_errorcode         => x_error_code,
				       x_msg_count         => x_msg_count,
				       x_msg_data          => x_msg_data,
				       p_category_id       => p_category_id,
				       p_category_set_id   => l_category_set_id,
				       p_inventory_item_id => p_item_id,
				       p_organization_id   => 91,
				       p_old_category_id   => l_category_id);
      l_prog_step := 'Step 41';
      --logger('x_return_status :'||x_return_status);
      --logger('x_error_code :'||x_error_code);
      --logger('x_msg_count :'||x_msg_count);
      --logger('x_msg_data :'||substr(x_msg_data, 1, 250));
    
      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_code  := 1;
        l_prog_step := 'Step 42';
        FOR i IN 1 .. x_msg_count LOOP
          --logger('Error Index :'||i);
          apps.fnd_msg_pub.get(p_msg_index     => i,
		       p_encoded       => fnd_api.g_false,
		       p_data          => x_msg_data,
		       p_msg_index_out => l_msg_index_out);
        
          --logger(x_msg_data);
          IF l_error_message IS NULL THEN
	l_error_message := substr(x_msg_data, 1, 250);
          ELSE
	l_error_message := l_error_message || ' /' ||
		       substr(x_msg_data, 1, 250);
          END IF;
        
        END LOOP;
        l_prog_step   := 'Step 43';
        p_err_message := l_error_message;
      
        --logger('*****************************************');
        logger('API Error : ' || l_error_message);
        --logger('*****************************************');
      ELSE
        l_prog_step := 'Step 44';
        p_err_code  := 0;
        --p_err_message := ('Created Category Assiginment from Item id : ' ||
        -- p_item_id || ' Successfully');
        --logger('*****************************************');
        logger(p_err_message);
        --logger('*****************************************');
      
      END IF;
    ELSE
      p_err_message := 'Nothing to update';
    END IF; -- category changed
  
  EXCEPTION
    WHEN myexception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Unexpected Error process_item_category2 : Item id= ' ||
	           p_item_id || chr(10) || ', failed assignment for ' ||
	           p_category_set_name || '. Error After ' ||
	           l_prog_step || ',' || SQLERRM;
    
  END process_item_category2;

  -----------------------------------
  -- add_Item_Relation
  ------------------------------------
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :add Item Relation
  -- ------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --

  PROCEDURE process_item_relation(p_relationship_type_id NUMBER,
		          p_item_id              NUMBER,
		          p_new_related_item_id  NUMBER,
		          p_err_code             OUT NUMBER,
		          p_err_message          OUT VARCHAR2) IS
  
    -- API generic
    l_init_msg_list VARCHAR2(2) := fnd_api.g_true;
    l_commit        VARCHAR2(2) := fnd_api.g_false;
    x_msg_list      error_handler.error_tbl_type;
    x_return_status VARCHAR2(2);
    x_msg_count     NUMBER := 0;
  
    -- User info
    -- l_user_id        NUMBER := -1;
    --  l_resp_id        NUMBER := -1;
    -- l_application_id NUMBER := -1;
    l_rowcnt NUMBER := 1;
    --  l_user_name         VARCHAR2(30) := 'PLMMGR';
    --  l_resp_name         VARCHAR2(30) := 'Development Manager';
  
    -- API specific
    l_rel_item_rec_type mtl_related_items_pub.rel_item_rec_type;
    l_pln_info_tbl_type mtl_related_items_pub.pln_info_tbl_type;
    l_cust_ref_tbl_type mtl_related_items_pub.cust_ref_tbl_type;
  BEGIN
    p_err_message := NULL;
    p_err_code    := 0;
  
    /* -- Get the user_id
    SELECT user_id
    INTO l_user_id
    FROM fnd_user
    WHERE user_name = l_user_name;
    
    -- Get the application_id and responsibility_id
    SELECT application_id, responsibility_id
    INTO l_application_id, l_resp_id
    FROM fnd_responsibility_vl
    WHERE responsibility_name = l_resp_name;*/
  
    --   FND_GLOBAL.APPS_INITIALIZE(l_user_id, l_resp_id, l_application_id);
    -- logger('Initialized applications context: '|| l_user_id || ' '|| l_resp_id ||' '|| l_application_id );
  
    l_rel_item_rec_type.transaction_type := 'CREATE';
    -- Primary Key Columns
    l_rel_item_rec_type.inventory_item_id    := p_item_id;
    l_rel_item_rec_type.organization_id      := 91;
    l_rel_item_rec_type.related_item_id      := p_new_related_item_id; -- To item
    l_rel_item_rec_type.relationship_type_id := p_relationship_type_id; -- 2; -- 1 - Related , 2- Substitute
    -- to take new values of rel item and type in update mode.
    l_rel_item_rec_type.related_item_id_upd_val      := NULL;
    l_rel_item_rec_type.relationship_type_id_upd_val := NULL;
    l_rel_item_rec_type.reciprocal_flag              := 'Y';
    l_rel_item_rec_type.start_date                   := NULL;
    l_rel_item_rec_type.end_date                     := NULL;
    -- l_Rel_Item_Rec_Type.planning_enabled_flag := 'Y';
  
    /*  l_Pln_Info_Tbl_Type(1).Transaction_Type          := 'CREATE';
    l_Pln_Info_Tbl_Type(1).Inventory_Item_Id         := 506217;
    l_Pln_Info_Tbl_Type(1).Organization_Id           := 204;
    l_Pln_Info_Tbl_Type(1).Related_Item_Id           := 506218;   -- To item
    l_Pln_Info_Tbl_Type(1).Relationship_Type_Id      := 2;
    l_Pln_Info_Tbl_Type(1).Pln_Info_Id               := NULL;
    l_Pln_Info_Tbl_Type(1).Substitution_Set          := 'Discrete';
    l_Pln_Info_Tbl_Type(1).Partial_Fulfillment_Flag  := 'Y';
    l_Pln_Info_Tbl_Type(1).Start_Date                := NULL;
    l_Pln_Info_Tbl_Type(1).End_Date                  := NULL;
    l_Pln_Info_Tbl_Type(1).All_Customers_Flag        :=  'N' ;
    
    -- Only if All_Customers_Flag = 'N'
    l_Cust_Ref_Tbl_Type(1).Transaction_Type       := 'CREATE';
    l_Cust_Ref_Tbl_Type(1).Inventory_Item_Id      :=  506217;
    l_Cust_Ref_Tbl_Type(1).Organization_Id        :=  204;
    l_Cust_Ref_Tbl_Type(1).Related_Item_Id        :=  506218;   -- To item
    l_Cust_Ref_Tbl_Type(1).Relationship_Type_Id   :=  2;
    l_Cust_Ref_Tbl_Type(1).Pln_Info_Id            := NULL;
    l_Cust_Ref_Tbl_Type(1).Customer_Id            :=  5454;
    l_Cust_Ref_Tbl_Type(1).Site_Use_Id            :=  12168;
    l_Cust_Ref_Tbl_Type(1).Start_Date             := NULL ;
    l_Cust_Ref_Tbl_Type(1).End_Date               := NULL;*/
  
    -- call API to load ICC
    logger('=====================================');
    logger('Calling MTL_RELATED_ITEMS_PUB.Process_Rel_Item');
  
    mtl_related_items_pub.process_rel_item(p_commit        => l_commit,
			       p_init_msg_list => l_init_msg_list,
			       p_rel_item_rec  => l_rel_item_rec_type,
			       p_pln_info_tbl  => l_pln_info_tbl_type,
			       p_cust_ref_tbl  => l_cust_ref_tbl_type,
			       x_return_status => x_return_status,
			       x_msg_count     => x_msg_count,
			       x_msg_list      => x_msg_list);
  
    logger('=====================================');
    logger('Return Status: ' || x_return_status);
  
    IF (x_return_status <> fnd_api.g_ret_sts_success) THEN
      logger('Error Messages :');
      error_handler.get_message_list(x_message_list => x_msg_list); -- x_msg_count
      FOR i IN 1 .. x_msg_list.count LOOP
        logger(x_msg_list(i).message_text);
      END LOOP;
    END IF;
    logger('=====================================');
  
  EXCEPTION
    WHEN OTHERS THEN
      logger('Exception Occured :');
      logger(SQLCODE || ':' || SQLERRM);
      logger('=====================================');
      RAISE;
    
  END;

  -----------------------------------
  -- process_item_attribute
  ------------------------------------
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :sync item attributes on mtl_system_items_b
  -- ------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --

  PROCEDURE process_item_attribute(p_doc_instance_id NUMBER,
		           p_err_code        OUT NUMBER,
		           p_err_message     OUT VARCHAR2) IS
  
    CURSOR c_item_data IS
    /*SELECT *
                                                                                                                                                                                                                                                                                                                                                                                                                                                          FROM   xxinv_wf_item_data
                                                                                                                                                                                                                                                                                                                                                                                                                                                          WHERE  doc_instance_id = p_doc_instance_id;*/
      SELECT o.doc_code,
	 d.*
      FROM   xxinv_wf_item_data     d,
	 xxobjt_wf_docs         o,
	 xxobjt_wf_doc_instance ins
      WHERE  d.doc_instance_id = p_doc_instance_id
      AND    ins.doc_instance_id = d.doc_instance_id
      AND    o.doc_id = ins.doc_id;
  
    l_item_tbl_typ  ego_item_pub.item_tbl_type;
    x_item_table    ego_item_pub.item_tbl_type;
    x_return_status VARCHAR2(1);
    x_msg_count     NUMBER(10);
    x_message_list  error_handler.error_tbl_type;
  BEGIN
    p_err_code    := 0;
    p_err_message := 0;
    FOR i IN c_item_data LOOP
    
      l_item_tbl_typ(1).transaction_type := ego_item_pub.g_ttype_update;
      l_item_tbl_typ(1).inventory_item_id := i.inventory_item_id;
      l_item_tbl_typ(1).organization_id := 91;
      l_item_tbl_typ(1).attribute12 := i.returnable_part;
      l_item_tbl_typ(1).long_description := i.item_long_description;
      l_item_tbl_typ(1).attribute26 := i.service_consumable;
    
      IF i.doc_code NOT IN ('ITEM_SP', 'ITEM_CLTW', 'ITEM_SALE') THEN
        l_item_tbl_typ(1).orderable_on_web_flag := i.e_commers;
      END IF;
    
      ego_item_pub.process_items(p_api_version   => 1.0,
		         p_init_msg_list => fnd_api.g_true,
		         p_commit        => fnd_api.g_true,
		         p_item_tbl      => l_item_tbl_typ,
		         x_item_tbl      => x_item_table,
		         x_return_status => x_return_status,
		         x_msg_count     => x_msg_count);
    
      logger('x_return_status of ego_item_pub.process_items : ' ||
	 x_return_status);
    
      error_handler.get_message_list(x_message_list);
    
      IF (x_return_status = fnd_api.g_ret_sts_success) THEN
        logger('Call to ego_item_pub.process_items, Completed with Success.');
        FOR i IN 1 .. x_item_table.count LOOP
          logger('Inventory Item Id :' ||
	     to_char(x_item_table(i).inventory_item_id));
          logger('Organization Id   :' ||
	     to_char(x_item_table(i).organization_id));
        END LOOP;
      ELSE
        logger('Call to ego_item_pub.process_items, Completed with Error.' ||
	   ' Error Messgaes:');
        p_err_code := 1;
      
        error_handler.get_message_list(x_message_list => x_message_list);
      
        IF x_message_list.count > 0 THEN
          logger('Error Message List :--');
        END IF;
        FOR i IN 1 .. x_message_list.count LOOP
          logger('(' || i || ') ' || x_message_list(i).message_text);
        END LOOP;
      
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END process_item_attribute;

  -----------------------------------
  -- process_item_short_attachment
  ------------------------------------
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :sync item short_attachment on mtl_system_items_b
  -- ------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --

  PROCEDURE process_item_short_attachment(p_item_id     NUMBER,
			      p_org_id      NUMBER,
			      p_category_id NUMBER,
			      p_short_text  VARCHAR2,
			      p_err_code    OUT NUMBER,
			      p_err_message OUT VARCHAR2) IS
    l_document_id NUMBER;
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
    IF p_short_text IS NOT NULL THEN
      --- check exists
    
      /*  UPDATE fnd_documents_short_text fdst
      SET    fdst.short_text = p_short_text
      WHERE  fdst.media_id
              AND    EXISTS
               (SELECT 1
                      FROM   fnd_document_datatypes fdt
                      WHERE  fdt.language = 'US'
                      AND    fdt.name = 'SHORT_TEXT'
                      AND    fdt.datatype_id = fadfv.datatype_id)*/
      --  AND    fadfv.entity_name = p_entity_name
      --  AND    fadfv.pk1_value = p_org_id
      --  AND    fadfv.pk2_value = p_item_id
    
      --  AND    fdst..category_id = fdct.category_id
    
      xxobjt_fnd_attachments.create_short_text_att(err_code      => p_err_code,
				   err_msg       => p_err_message,
				   p_document_id => l_document_id,
				   p_category_id => p_category_id,
				   p_entity_name => 'MTL_SYSTEM_ITEMS',
				   p_file_name   => NULL,
				   p_title       => '',
				   p_description => '',
				   p_short_text  => p_short_text,
				   --  p_short_text_message_name => :p_short_text_message_name,
				   p_pk1 => 91,
				   p_pk2 => p_item_id,
				   p_pk3 => NULL);
    END IF;
  
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               abort
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :         abort process
  --  abort item approval  from Form
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   30.4.19       yuval tal
  --
  -----------------------------------------------------------------------
  PROCEDURE abort(p_doc_instance_id NUMBER,
	      p_note            VARCHAR2,
	      p_err_code        OUT NUMBER,
	      p_err_message     OUT VARCHAR2) IS
  
    l_status VARCHAR2(50);
  
  BEGIN
  
    IF xxobjt_wf_doc_util.get_doc_status(p_doc_instance_id) NOT IN
       ('IN_PROCESS', 'ERROR') THEN
      p_err_code    := 1;
      p_err_message := 'Action not valid , WorkFlow is not active .';
    ELSE
    
      xxobjt_wf_doc_util.abort_process(p_err_code        => p_err_code,
			   p_err_msg         => p_err_message,
			   p_doc_instance_id => p_doc_instance_id);
    END IF;
  
  END;
  --------------------------------------------------------------------
  --  customization code:
  --  name:               reassign_with_Inactive
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :         reassign owner and futute approvers to new role
  -- called by prof XXINV WF Reassign/XXINVWFREASSIGN
  ----------------------------------------------------------------------
  --  ver   date          name            desc

  --  1.1   22.4.20       yuval tal    CHG0047747 - initial - support reassign from inactive user
  -----------------------------------------------------------------------
  PROCEDURE reassign_with_inactive(p_err_message OUT VARCHAR2,
		           p_err_code    OUT VARCHAR2,
		           p_from_role   VARCHAR2,
		           p_to_role     VARCHAR2,
		           p_note        VARCHAR2) IS
    l_active_user_flag          BOOLEAN;
    l_end_date                  DATE;
    l_count                     NUMBER;
    l_employee_name             VARCHAR2(100);
    l_employee_id               NUMBER;
    l_is_err_notification_found NUMBER := 0; -- not found =0 found =1
  
    CURSOR c IS
      SELECT i.current_seq_appr,
	 i.doc_instance_id,
	 t.item_type,
	 t.item_key,
	 t.activity_name,
	 t.notification_id,
	 activity_status_code --,
      --   t.*
      FROM   wf_item_activity_statuses_v  t,
	 xxinv_wf_item_doc_instance_v i,
	 xxobjt_wf_doc_history_tmp    h
      WHERE  h.doc_instance_id = i.doc_instance_id
      AND    i.current_seq_appr = h.seq_no
      AND    t.item_type = 'XXWFDOC'
      AND    i.wf_item_key = t.item_key
      AND    h.role_name = p_from_role
      AND    t.activity_end_date IS NULL
      AND    activity_status_code = 'ERROR';
  
    l_err_code    VARCHAR2(1);
    l_err_message VARCHAR2(1000);
  BEGIN
    l_err_code := 0;
    --- get user atatus
    l_active_user_flag := wf_directory.useractive(p_from_role);
    -- if not active then
    -- enable user
    -- find error notifications and retry
    -- update history table
  
    IF NOT l_active_user_flag THEN
      logger('Reassign user is Inactive');
      -- activate user
      SELECT hr_general.decode_person_name(u.employee_id) person_name,
	 employee_id,
	 end_date
      INTO   l_employee_name,
	 l_employee_id,
	 l_end_date
      FROM   fnd_user u
      WHERE  user_name = p_from_role;
      --
      -- check failure notification  and retry
    
      FOR i IN c LOOP
        l_is_err_notification_found := 1;
        IF c%ROWCOUNT = 1 THEN
          -- eanble user only if at least one errro found
          logger('Enable user');
          fnd_user_pkg.enableuser(end_date => SYSDATE + 1,
		          username => p_from_role);
        
          COMMIT;
          dbms_lock.sleep(120); -- wait till user will be active for retry
        
        END IF;
      
        logger(c%ROWCOUNT || ': Retry XXWFDOC/item_key=' || i.item_key);
        wf_engine.handleerror(itemtype => 'XXWFDOC',
		      itemkey  => i.item_key,
		      activity => 'NEED_APPR_NOTIFICATION',
		      command  => 'RETRY',
		      RESULT   => NULL);
      
        UPDATE xxobjt_wf_doc_history h
        SET    person_id        = l_employee_id,
	   role_description = l_employee_name
        WHERE  doc_instance_id = i.doc_instance_id
        AND    seq_no = i.current_seq_appr
        AND    action_code = 'WAITING';
      
        COMMIT;
      END LOOP;
      IF l_is_err_notification_found = 1 THEN
      
        SELECT COUNT(*)
        INTO   l_count
        FROM   wf_item_activity_statuses_v  t,
	   xxinv_wf_item_doc_instance_v i,
	   xxobjt_wf_doc_history_tmp    h
        WHERE  h.doc_instance_id = i.doc_instance_id
        AND    i.current_seq_appr = h.seq_no
        AND    t.item_type = 'XXWFDOC'
        AND    i.wf_item_key = t.item_key
        AND    h.role_name = p_from_role
        AND    t.activity_end_date IS NULL
        AND    activity_status_code = 'ERROR';
      
        logger('After retry, open error count=' || l_count);
      
        IF l_count != 0 THEN
          l_err_message := 'Error: Not All notification failures were reassign , see log';
          logger('--------------------------------------------------------');
          logger('Error: Not All notification failures were reassign !!');
          logger('Please ReRun progrm');
          logger('--------------------------------------------------------');
          l_err_code := 2;
        END IF;
      
      END IF;
    
    END IF; -- end inactive user check
  
    logger('call Reassign procedure');
  
    -- call regular reassign while user is active
    reassign(p_from_role       => p_from_role,
	 p_to_role         => p_to_role,
	 p_note            => p_note,
	 p_doc_instance_id => NULL,
	 p_err_code        => p_err_code,
	 p_err_message     => p_err_message);
  
    -- disable user in case it was inactive and we activated it on  start
  
    IF NOT (l_active_user_flag) AND wf_directory.useractive(p_from_role) THEN
      -- disable user
      logger('Disable reassign user');
      fnd_user_pkg.updateuser(x_user_name   => p_from_role,
		      x_owner       => 'CUST',
		      x_end_date    => l_end_date,
		      x_description => 'User Disabled as part of item approval reassin prc');
    
    END IF;
    p_err_message := p_err_message || ' ' || l_err_message;
    p_err_code    := greatest(p_err_code, l_err_code);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      logger(substr(SQLERRM, 1, 200));
      p_err_code    := greatest(p_err_code, l_err_code);
      p_err_message := 'Unable to Reassign from : ' || p_from_role || ' ' ||
	           SQLERRM;
    
      IF NOT (l_active_user_flag) AND wf_directory.useractive(p_from_role) THEN
        logger('Disable reassign user');
        fnd_user_pkg.updateuser(x_user_name   => p_from_role,
		        x_owner       => 'CUST',
		        x_end_date    => l_end_date,
		        x_description => 'Usere Disable as part of item approval reassin prc');
        COMMIT;
      
      END IF;
      COMMIT;
    
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               reassign
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :         reassign owner and futute approvers to new role
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   30.4.19       yuval tal
  --  1.2   19.9.19       YUVAL TAL    CHG0046494 - add parameter

  -----------------------------------------------------------------------
  PROCEDURE reassign(p_from_role       VARCHAR2,
	         p_to_role         VARCHAR2,
	         p_note            VARCHAR2,
	         p_doc_instance_id NUMBER, --CHG0046494
	         p_err_code        OUT NUMBER,
	         p_err_message     OUT VARCHAR2) IS
  
    CURSOR c_future_approvers IS
      SELECT ht.*
      FROM   xxobjt_wf_doc_instance    t,
	 xxobjt_wf_doc_history_tmp ht,
	 xxobjt_wf_docs            d,
	 xxinv_wf_track_v          tr
      WHERE  d.doc_id = t.doc_id
      AND    t.doc_status = 'IN_PROCESS'
      AND    ht.doc_instance_id = t.doc_instance_id
      AND    p_doc_instance_id IS NULL --CHG0046494
      AND    ht.role_name = p_from_role
      AND    ht.seq_no > t.current_seq_appr
      AND    d.doc_code = tr.doc_code; -- IN ('ITEM_SALE', 'ITEM_CLTW', 'ITEM_SP');
  
    CURSOR c_forward_approvers IS
      SELECT n.notification_id
      FROM   xxobjt_wf_doc_instance t,
	 wf_notifications       n,
	 xxobjt_wf_docs         d,
	 xxinv_wf_track_v       tr
      WHERE  d.doc_id = t.doc_id
      AND    t.doc_instance_id = nvl(p_doc_instance_id, t.doc_instance_id) --CHG0046494
      AND    t.doc_status = 'IN_PROCESS'
      AND    n.message_type = 'XXWFDOC'
      AND    user_key = t.doc_instance_id
      AND    n.status = 'OPEN'
      AND    n.recipient_role = p_from_role
      AND    d.doc_code = tr.doc_code; --IN ('ITEM_SALE', 'ITEM_CLTW', 'ITEM_SP');
    l_notification_count  NUMBER;
    l_notification_count1 NUMBER;
  
  BEGIN
    p_err_code := 0;
  
    -- UPDATE  future approvers
  
    FOR i IN c_future_approvers LOOP
    
      UPDATE xxobjt_wf_doc_history_tmp t
      SET    role_name          = p_to_role,
	 note               = 'Reassign from ' || p_from_role,
	 t.last_update_date = SYSDATE
      WHERE  t.doc_instance_id = i.doc_instance_id
      AND    seq_no = i.seq_no;
    
      logger('update future =' || i.doc_instance_id);
      p_err_message         := 'Future reassign =' ||
		       c_future_approvers%ROWCOUNT;
      l_notification_count1 := c_future_approvers%ROWCOUNT;
    END LOOP;
  
    -- forward_approvers
  
    FOR i IN c_forward_approvers LOOP
      logger('notification_id =' || i.notification_id);
      wf_notification.forward(nid             => i.notification_id,
		      new_role        => p_to_role,
		      forward_comment => p_note);
    
      l_notification_count := c_forward_approvers%ROWCOUNT;
    END LOOP;
    IF l_notification_count IS NOT NULL THEN
      p_err_message := p_err_message || ' Notification reassign=' ||
	           l_notification_count;
    END IF;
  
    IF nvl(l_notification_count, 0) = 0 AND
       nvl(l_notification_count1, 0) = 0 THEN
      p_err_message := ' No open assignments found';
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 1;
      p_err_message := 'xxinv_wf_item_approval_pkg.reassign :' ||
	           substr(SQLERRM, 1, 200);
  END;

  -- *****************************************************************************************
  -- Object Name:  submit_sync_item_request
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Called By  : ????????
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name               Type   Purpose
  --       --------           ----   -----------
  --       p_doc_instance_id    In     ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    31-May-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --  1.1    12.9.19      YUVAL TAL         CHG0046494 - add AUTONOMOUS_TRANSACTION
  -- *****************************************************************************************
  PROCEDURE submit_sync_item_request(p_doc_instance_id NUMBER,
			 
			 p_err_code    OUT NUMBER,
			 p_err_message OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --CHG0046494
    l_request_id NUMBER;
    l_setmode    BOOLEAN;
  BEGIN
    --track_my_flow('submit_sync_item_request Called :'||p_doc_instance_id);
    -- -----------------------
    -- this Procedure is getting Called from "Sync to Oracle"  doc approval action setup
    --------------------------
    -- --CHG0046494
    IF fnd_global.resp_appl_id = -1 THEN
      fnd_global.apps_initialize(user_id      => fnd_global.user_id,
		         resp_id      => 51577,
		         resp_appl_id => 1);
    END IF;
    -- end --CHG0046494
  
    l_setmode    := fnd_request.set_mode(TRUE);
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
			           program     => 'XXINVWFSYNC',
			           description => 'XXINV WF Sync Item',
			           sub_request => FALSE,
			           argument1   => p_doc_instance_id);
  
    p_err_code := 0;
    --track_my_flow('Request id :'||l_request_id);
    IF nvl(l_request_id, 0) = 0 THEN
      logger('Concurrent Program "XXINV WF Sync Item(XXINVWFSYNC)" failed to submit.');
    
      UPDATE xxobjt_wf_doc_instance t
      SET    t.n_attribute2 = l_request_id,
	 attribute3     = substr('user=' || fnd_global.user_name || ' ' ||
			 fnd_message.get || 'RESP_ID=' ||
			 fnd_global.resp_id,
			 1,
			 240)
      WHERE  doc_instance_id = p_doc_instance_id;
      p_err_code    := 1;
      p_err_message := 'user=' || fnd_global.user_name || ' ' ||
	           fnd_message.get;
    ELSE
      logger('Concurrent Program "XXINV WF Sync Item(XXINVWFSYNC)"  submitted successfully with Request Id :' ||
	 l_request_id);
    
      UPDATE xxobjt_wf_doc_instance t
      SET    t.n_attribute2 = l_request_id,
	 attribute3     = 'user=' || fnd_global.user_name ||
		      ' l_request_id=' || l_request_id ||
		      ' RESP_ID=' || fnd_global.resp_id
      WHERE  doc_instance_id = p_doc_instance_id;
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      UPDATE xxobjt_wf_doc_instance t
      SET    t.n_attribute2 = l_request_id,
	 attribute3     = substr(fnd_message.get, 1, 240)
      WHERE  doc_instance_id = p_doc_instance_id;
      p_err_code    := 1;
      p_err_message := fnd_message.get || ' ' || substr(SQLERRM, 1, 50);
      logger('UNEXPECTED Error in xxinv_wf_item_approval_pkg.submit_sync_item_request:' ||
	 to_char(SQLCODE) || '-' || SQLERRM);
      COMMIT;
  END submit_sync_item_request;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_applicable_system_name
  --  create by:
  --  Revision:           1.0
  --  creation date:
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   12.9.19       yuval tal      CHG0046494   used in form XXINVWFITEMDATA
  --
  -----------------------------------------------------------------------

  FUNCTION get_applicable_system_name(p_categoty_id NUMBER) RETURN VARCHAR2 IS
    l_applicable_system VARCHAR2(500);
  BEGIN
    SELECT m.segment1 applicable_system
    INTO   l_applicable_system
    FROM   mtl_categories_v m
    WHERE  m.structure_id = 50511
    AND    nvl(m.disable_date, SYSDATE + 1) > SYSDATE
    AND    nvl(m.enabled_flag, 'N') = 'Y'
    AND    m.category_id = p_categoty_id; --:XXINV_WF_ITEM_DATA_LINES_EDIT.N_ATTRIBUTE1;
  
    RETURN l_applicable_system;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

END xxinv_wf_item_approval_pkg;
/
