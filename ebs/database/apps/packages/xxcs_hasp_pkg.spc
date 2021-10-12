CREATE OR REPLACE PACKAGE xxcs_hasp_pkg AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xx_cs_hasp_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xx_cs_hasp_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: support hasp interface process cust419
  --------------------------------------------------------------------------
  -- Version  Date         Performer       Comments
  ----------  --------     --------------  -------------------------------------
  --     1.0  04.06.12     Yuval Tal        Initial Build
  --     1.1  31.07.2014   Michal Tzvik     CHG0032163: Unified platform V2C HASP Process
  --                                        Add procedure is_sales_order_exist_wf
  --    1.2   8.2.18       yuval tal        CHG0042312 get_safenet_user_pass  add parameter to
  --    1.3   09/04/2019   Bellona B.       INC0153077 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  --    1.4   18/05/2019   Roman W.         INC0156901 - HASP process not completeWhen clicking resubmit
  --  1.5    15.12.20      yuval tal       CHG0048579 -  call_safenet_oic  
  ---------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Version  When        Who           Comments
  ----------  ----------  ------------  ---------------------------------------
  --  1.0     10/04/2019  Bellona B.    initial build -> print log messages
  -----------------------------------------------------------------------------
  PROCEDURE message(p_msg VARCHAR2);

  PROCEDURE initiate_hasp_table(p_err_message OUT VARCHAR2,
		        p_err_code    OUT NUMBER);

  ---------------------------------------------------------------------------
  -- Ver      When         Who             Comments
  -- -------  -----------  --------------  -------------------------------------
  -- 1.0      18/05/2019   Roman W.        INC0156901 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  ---------------------------------------------------------------------------
  PROCEDURE is_row_locked(p_hasp_interface_id IN NUMBER,
		  p_is_locked         OUT VARCHAR2,
		  p_error_code        OUT VARCHAR2,
		  p_error_desc        OUT VARCHAR2);
  ---------------------------------------------------------------------------
  -- Ver      When         Who             Comments
  -- -------  -----------  --------------  -------------------------------------
  -- 1.0      09/04/2019   Bellona B.      INC0153077 - called from XXCSHASP.fmb
  --                                            submits conc program XXCS: Hasp Initiate Process
  ---------------------------------------------------------------------------
  PROCEDURE form_initiate_process(p_err_code          OUT VARCHAR2,
		          p_err_message       OUT VARCHAR2,
		          p_request_id        OUT NUMBER,
		          p_hasp_interface_id IN NUMBER DEFAULT NULL);

  PROCEDURE initiate_process(p_err_code          OUT NUMBER,
		     p_err_message       OUT VARCHAR2,
		     p_hasp_interface_id NUMBER DEFAULT NULL);
  PROCEDURE check_initial_params(p_hasp_interface_id NUMBER,
		         p_err_code          OUT NUMBER,
		         p_err_message       OUT VARCHAR2);
  PROCEDURE check_initial_params_wf(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2);

  PROCEDURE call_safenet_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2);
  PROCEDURE call_safenet(p_hasp_interface_id NUMBER,
		 p_err_code          OUT NUMBER,
		 p_err_message       OUT VARCHAR2);

  PROCEDURE get_safenet_user_pass(p_user_name      OUT VARCHAR2,
		          p_password       OUT VARCHAR2,
		          p_safenet_server OUT VARCHAR2,
		          p_endpoint_url   OUT VARCHAR2,
		          p_port           OUT VARCHAR2, ---- CHG0042312
		          p_env            IN OUT VARCHAR2,
		          p_err_code       OUT VARCHAR2,
		          p_err_msg        OUT VARCHAR2);

  PROCEDURE upload_files(p_hasp_interface_id NUMBER,
		 p_err_code          OUT NUMBER,
		 p_err_message       OUT VARCHAR2);

  PROCEDURE upload_files_wf(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2);

  PROCEDURE download_files_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  PROCEDURE download_files(p_hasp_interface_id NUMBER,
		   p_err_code          OUT NUMBER,
		   p_pz_status         OUT NUMBER,
		   p_err_message       OUT VARCHAR2);

  FUNCTION get_ftp_jndi_info(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
  FUNCTION xml_extract_no_exception(p_xml       IN xmltype,
			p_xpath     IN VARCHAR2,
			p_namespace IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;

  PROCEDURE update_header_err_wf(itemtype  IN VARCHAR2,
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2);
  PROCEDURE track_selector_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  PROCEDURE is_sales_order_exist_wf(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2);

  PROCEDURE update_hasp_header(p_hasp_interface_id NUMBER);

  PROCEDURE call_safenet_oic(p_hasp_interface_id         NUMBER,
		     p_safenet_user              VARCHAR2,
		     p_safenet_password          VARCHAR2,
		     p_file_dir                  VARCHAR2,
		     p_file_prefix               VARCHAR2,
		     p_hasp_root_dir             VARCHAR2,
		     p_hasp_root_dir_bck         VARCHAR2,
		     x_response_hasp_order_id    OUT VARCHAR2,
		     x_response_bpel_instance_id OUT VARCHAR2,
		     x_response_file_name        OUT VARCHAR2,
		     x_final_root_dir_name       OUT VARCHAR2,
		     x_err_code                  OUT NUMBER,
		     x_err_message               OUT VARCHAR2);

END;
/
