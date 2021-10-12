CREATE OR REPLACE PACKAGE "XXINV_WF_ITEM_APPROVAL_PKG" AUTHID CURRENT_USER IS
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
  --  1.1    23.4.2020    yuval atl         CHG0047747 - add reassign_with_inactive
  -- *****************************************************************************************

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
  FUNCTION get_buyer_user_name(p_item_id NUMBER) RETURN VARCHAR2;

  PROCEDURE submit_request(p_inv_item_id NUMBER,
		   p_mode        VARCHAR2,
		   p_old_status  VARCHAR2,
		   p_new_status  VARCHAR2);

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
		      p_mode        VARCHAR2,
		      p_old_status  VARCHAR2,
		      p_new_status  VARCHAR2);

  -- *****************************************************************************************
  -- Object Name:  get_approver
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       p_role_code         In     ???
  --       x_role_name         Out    ???
  --       x_err_code          Out    ???
  --       x_err_message       Out    ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  PROCEDURE get_approver(x_err_code        OUT NUMBER,
		 x_err_message     OUT VARCHAR2,
		 p_doc_instance_id IN NUMBER,
		 p_role_code       IN VARCHAR2,
		 x_role_name       OUT VARCHAR2);

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
  --
  -- *****************************************************************************************
  FUNCTION get_approval_doc_code(p_inv_item_id NUMBER,
		         p_mode        VARCHAR2,
		         p_old_status  VARCHAR2,
		         p_new_status  VARCHAR2,
		         p_item_type   VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;

  -- *****************************************************************************************
  -- Object Name:  sync_item
  -- Type       :   Procedure
  -- Create By  :   Yuval tal
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
  PROCEDURE sync_item(errbuf            OUT VARCHAR2,
	          retcode           OUT NUMBER,
	          p_doc_instance_id NUMBER);

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
		       x_err_message     OUT VARCHAR2);

  -- *****************************************************************************************
  -- Object Name:  get_role
  -- Type       :  Function
  -- Create By  :  Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    : ????????
  -- ------------------------------------------------------------
  -- Parameters :
  --       Name                Type   Purpose
  --       --------            ----   -----------
  --       p_doc_instance_id   In     ???
  --       p_user_id           In     ???
  --       p_role_code         In     ???
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  FUNCTION get_user_role(p_doc_instance_id NUMBER,
		 p_user_name       VARCHAR2) RETURN VARCHAR2;

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
		          document_type IN OUT NOCOPY VARCHAR2);

  -- get_field_security_info
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
			p_enterable       OUT VARCHAR2);

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
	      p_err_message     OUT VARCHAR2);

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
	        p_err_message     OUT VARCHAR2);

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
  --
  -----------------------------------------------------------------------

  PROCEDURE check_required_fields(p_doc_instance_id NUMBER,
		          
		          p_err_code    OUT NUMBER,
		          p_err_message OUT VARCHAR2);

  -----------------------------------
  -- upsertItemCategories
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
		          p_err_message       OUT VARCHAR2);

  -----------------------------------
  -- process_item_category
  ------------------------------------
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
		           p_err_message       OUT VARCHAR2);
  ------------------------------------
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
			      p_err_message OUT VARCHAR2);

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
		           p_err_message     OUT VARCHAR2);

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
		          p_err_message          OUT VARCHAR2);

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
	         p_err_message     OUT VARCHAR2);

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
  --
  -- *****************************************************************************************
  PROCEDURE submit_sync_item_request(p_doc_instance_id NUMBER,
			 p_err_code        OUT NUMBER,
			 p_err_message     OUT VARCHAR2);
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

  FUNCTION get_applicable_system_name(p_categoty_id NUMBER) RETURN VARCHAR2;

  -----------------------------------------------------------------------
  PROCEDURE reassign_with_inactive(p_err_message OUT VARCHAR2,
		           p_err_code    OUT VARCHAR2,
		           p_from_role   VARCHAR2,
		           p_to_role     VARCHAR2,
		           p_note        VARCHAR2);

END xxinv_wf_item_approval_pkg;
/
