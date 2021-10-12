create or replace package xxinv_trx_in_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxinv_trx_in_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxinv_trx_in_pkg
  -- Created:
  -- Author:
  -------------------------------------------------------------------------------------------------------------------------------
  -- Purpose: CUST750 - Process Incoming transactions CR1044
  -------------------------------------------------------------------------------------------------------------------------------
  -- Version  Date        Performer         Comments
  ----------  ----------  ----------------  -------------------------------------------------------------------------------------
  --     1.0  24.9.13     yuval tal         initial build
  --     1.1  01.04.14    yuval tal         CHG0031650 : add  clean_rcv_interface
  --     1.2  01.12.17    bellona banerjee  CHG0041294 : add  create_allocation
  --     3.0  27-02-2018  Roman.W/Dovik     CHG0042242 : assighn and un-assighn intangible item
  --                                           added procedur : 1)set_item_ship_set_to_null
  --                                                            2)combine_delivery_by_ship_set
  --                                                            3)combine_delivery_by_order
  --                                                            4)ship_confirm_delivery_check
  --                                           to procedure added profile "XX_APPEND_INTANGIBLE_DELIVERIES" condition if "Y" then
  --                                           called procedure "ship_confirm_delivery_check"
  --    3.1  21-06-2018  Bellona(TCS)       CHG0042444 - Created new PL/SQL Table type variable as part of
  --                                             changes to avoid too many rows error when delivery detail has been split.
  --    3.2  09/11/2018  Roman W.           CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --    3.3  05.09.19    Bellona(TCS)       CHG0046435 - TPL Handle Pack - COC document by Email - new procedure print_coc_document
  --                                                                                               added.
  -------------------------------------------------------------------------------------------------------------------------------

  c_success CONSTANT VARCHAR2(300) := 'SUCCESS';
  c_new     CONSTANT VARCHAR2(300) := 'NEW';
  c_error   CONSTANT VARCHAR2(300) := 'ERROR';

  --CHG0042444 Record type created
  TYPE ddrectyp IS RECORD(
    req_qty NUMBER,
    dd_id   NUMBER);
  --CHG0042444 Table type created
  TYPE ddtabtyp IS TABLE OF ddrectyp INDEX BY BINARY_INTEGER;
  --CHG0042444 table type variable created
  dd_tab ddtabtyp; -- declare PL/SQL table

  FUNCTION get_order_creator_mail(p_delivery_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_pto_included(p_delivery_id NUMBER) RETURN VARCHAR2;
  PROCEDURE validate_rcv_data(errbuf            OUT VARCHAR2,
		      retcode           OUT VARCHAR2,
		      p_doc_type        VARCHAR2,
		      p_source_code     VARCHAR2,
		      p_organization_id NUMBER DEFAULT NULL);
  FUNCTION get_shipment_alert_body(p_shipment_header_id NUMBER)
    RETURN VARCHAR2;

  PROCEDURE main_rcv_trx(errbuf      OUT VARCHAR2,
		 retcode     OUT VARCHAR2,
		 p_user_name VARCHAR2);

  PROCEDURE get_user_details(p_user_name       VARCHAR2,
		     p_user_id         OUT NUMBER,
		     p_resp_id         OUT NUMBER,
		     p_resp_appl_id    OUT NUMBER,
		     p_organization_id OUT NUMBER,
		     p_err_code        OUT NUMBER,
		     p_err_message     OUT VARCHAR2);

  PROCEDURE handle_internal_material_trx(errbuf      OUT VARCHAR2,
			     retcode     OUT VARCHAR2,
			     p_user_name VARCHAR2);

  PROCEDURE handle_rcv_internal_trx(errbuf      OUT VARCHAR2,
			retcode     OUT VARCHAR2,
			p_user_name VARCHAR2);

  PROCEDURE handle_rcv_po_trx(errbuf      OUT VARCHAR2,
		      retcode     OUT VARCHAR2,
		      p_user_name VARCHAR2);

  PROCEDURE handle_rcv_rma_trx(errbuf      OUT VARCHAR2,
		       retcode     OUT VARCHAR2,
		       p_user_name VARCHAR2);

  PROCEDURE handle_rcv_mo_trx(errbuf      OUT VARCHAR2,
		      retcode     OUT VARCHAR2,
		      p_user_name VARCHAR2);

  PROCEDURE update_rcv_status(errbuf        OUT VARCHAR2,
		      retcode       OUT VARCHAR2,
		      p_source_code VARCHAR2,
		      p_status      VARCHAR2,
		      p_err_message VARCHAR2,
		      p_trx_id      NUMBER DEFAULT NULL,
		      p_doc_type    VARCHAR2 DEFAULT NULL,
		      p_group_id    NUMBER DEFAULT NULL);

  PROCEDURE print_commercial_invoice(p_err_message  OUT VARCHAR2,
			 p_err_code     OUT VARCHAR2,
			 p_request_id   OUT NUMBER,
			 p_user_name    VARCHAR2,
			 p_delivery_id  NUMBER,
			 p_calling_proc VARCHAR2); --CHG0046435

  PROCEDURE print_packing_list(p_err_message  OUT VARCHAR2,
		       p_err_code     OUT VARCHAR2,
		       p_request_id   OUT NUMBER,
		       p_user_name    VARCHAR2,
		       p_delivery_id  NUMBER,
		       p_calling_proc VARCHAR2); --CHG0046435

  ----------------------------------------------------------------
  -- Purpose: print_coc_document submits program XX: Materials COC
  -- called from procedure handle_pick_trx
  -----------------------------------------------------------------
  -- Ver   Date       Performer        Comments
  -- ----  --------   --------------   ---------------------------
  -- 1.0   05.09.19   Bellona(TCS)        CHG0046435 - For the manufacturing readiness project- phase II
  --                                      , we need to issue to APJ the COC document by
  --                                       Email (HK,CN,KR) and to add it to JP PL set.
  -----------------------------------------------------------------
  PROCEDURE print_coc_document(p_err_message  OUT VARCHAR2,
		       p_err_code     OUT VARCHAR2,
		       p_request_id   OUT NUMBER,
		       p_user_name    VARCHAR2,
		       p_delivery_id  NUMBER,
		       p_calling_proc VARCHAR2);

  PROCEDURE handle_pick_trx(errbuf      OUT VARCHAR2,
		    retcode     OUT VARCHAR2,
		    p_user_name VARCHAR2);

  --------------------------------------------------------------------
  --  name:            create_allocation
  --  create by:       Bellona Banerjee
  --  Revision:        1.0
  --  creation date:   28/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To create reservation from inv_replenish_detail_pub.line_details_pub
  --
  --------------------------------------------------------------------
  --   ver        date         name               desc
  --   1.0    28.11.2017    Bellona Banerjee      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------
  PROCEDURE create_allocation(p_move_order_no      IN NUMBER,
		      p_move_order_line_no IN NUMBER,
		      p_move_order_line_id IN NUMBER,
		      p_picked_quantity    IN NUMBER,
		      p_reservation_id     IN NUMBER,
		      p_organization_id    IN NUMBER,
		      p_errbuf             OUT VARCHAR2,
		      p_retcode            OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:          is_delivery_exists
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To check if delivery name exist
  --------------------------------------------------------------------
  --  ver        date         name                desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------

  FUNCTION is_delivery_exists(p_delivery_name VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            create_delivery
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To create delivery_name from WSH_DELIVERIES_PUB.create_update_delivery
  --
  --------------------------------------------------------------------
  --   ver       date         name                 desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------

  PROCEDURE create_delivery(p_delivery_name      IN VARCHAR2,
		    p_delivery_detail_id IN NUMBER,
		    p_out_delivery_id    OUT NUMBER,
		    p_errbuf             OUT VARCHAR2,
		    p_retcode            OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            assign_delivery_detail
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To assign  delivery_detail_id to delivery_name
  --
  --------------------------------------------------------------------
  --   ver        date         name              desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------

  PROCEDURE assign_delivery_detail(p_delivery_name      IN VARCHAR2,
		           p_delivery_detail_id IN NUMBER,
		           p_delivery_id        IN NUMBER,
		           p_errbuf             OUT VARCHAR2,
		           p_retcode            OUT VARCHAR2);

  PROCEDURE handle_pack_trx(errbuf      OUT VARCHAR2,
		    retcode     OUT VARCHAR2,
		    p_user_name VARCHAR2);
  --------------------------------------------------------------------
  --  name:          get_delivery_id
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To get delivery id from
  --------------------------------------------------------------------
  --  ver         date         name              desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------
  FUNCTION get_delivery_id(p_delivery_name VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------------------------------------
  --   Ver    When        Who               Description
  --  ------  ----------  -------------     --------------------------------------------------------
  --     1.0  27-02-2018  Roman.W/Dovik     CHG0042242 : assighn and un-assighn intangible item
  --------------------------------------------------------------------------------------------------
  PROCEDURE handle_ship_confirm_trx(errbuf      OUT VARCHAR2,
			retcode     OUT VARCHAR2,
			p_user_name VARCHAR2);

  FUNCTION is_fully_received(p_shipment_header_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_delivery_picked(p_delivery_id NUMBER) RETURN VARCHAR2;

  PROCEDURE get_packing_slip_info(p_packing_slip       IN VARCHAR2,
		          l_organization_id    NUMBER,
		          l_receipt_num        OUT VARCHAR2,
		          l_shipment_header_id OUT NUMBER);

  FUNCTION is_full_qty_picked(p_move_order_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_all_delivery_lines_staged(p_delivery_id NUMBER) RETURN VARCHAR2;

  PROCEDURE get_revision(p_item_code       VARCHAR2,
		 p_mode            NUMBER ---> 1 - Lowest in Stock, 2 - Highest in System
		,
		 p_organization_id NUMBER,
		 p_revision        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_subinv          VARCHAR2 DEFAULT NULL,
		 p_locator_id      NUMBER DEFAULT NULL,
		 p_serial          VARCHAR2 DEFAULT NULL,
		 p_lot_number      VARCHAR2 DEFAULT NULL); --RETURN VARCHAR2;

  FUNCTION is_revision_control(p_item_code       VARCHAR2,
		       p_organization_id NUMBER) RETURN VARCHAR2;
  FUNCTION check_env_string(p_env VARCHAR2) RETURN NUMBER;
  FUNCTION get_user_id(p_user_name VARCHAR2) RETURN NUMBER;
  PROCEDURE clean_rcv_interface(p_err_msg  OUT VARCHAR2,
		        p_err_code OUT NUMBER,
		        p_trx_id   NUMBER);
  FUNCTION is_lot_serial_the_same(p_out_lot_serial VARCHAR2,
		          p_in_lot_serial  VARCHAR2) RETURN VARCHAR2;
  PROCEDURE delete_xxinv_trx_resend_orders(errbuf      OUT VARCHAR2,
			       retcode     OUT VARCHAR2,
			       p_doc_type  IN VARCHAR2,
			       p_header_id IN NUMBER);
  FUNCTION is_job_components_picked(p_organization_id NUMBER,
			p_job_id          NUMBER) RETURN VARCHAR2;
  FUNCTION is_full_qty_issued(p_move_order_line_id NUMBER) RETURN VARCHAR2;
  PROCEDURE update_assembly_serial(p_job_id NUMBER);
  PROCEDURE handle_wip_issue_trx(errbuf      OUT VARCHAR2,
		         retcode     OUT VARCHAR2,
		         p_user_name VARCHAR2);
  PROCEDURE handle_wip_completion_trx(errbuf      OUT VARCHAR2,
			  retcode     OUT VARCHAR2,
			  p_user_name IN VARCHAR2,
			  p_job_id    IN NUMBER);
  PROCEDURE get_wip_completion_sub_loc(errbuf     OUT VARCHAR2,
			   retcode    OUT VARCHAR2,
			   p_comp_sub OUT VARCHAR2,
			   p_comp_loc OUT VARCHAR2,
			   p_job_id   IN NUMBER);

  PROCEDURE move_stock(errbuf      OUT VARCHAR2,
	           retcode     OUT VARCHAR2,
	           p_user_name IN VARCHAR2,
	           p_from_sub  IN VARCHAR2,
	           p_from_loc  IN NUMBER,
	           p_to_sub    IN VARCHAR2,
	           p_to_loc    IN NUMBER);

  -------------------------------------------------------------------------------------
  -- Ver When        Who        Description
  -- --- ----------  ---------  -------------------------------------------------------
  -- 3.5 13-06-2018  R.W.       CHG0043197
  -------------------------------------------------------------------------------------
  FUNCTION is_valid_delivery(p_delivery_id NUMBER) RETURN VARCHAR2;

  ----------------------------------------------------------------------------------------------------
  -- Ver    When        Who      Description
  -- -----  ----------  -------  ---------------------------------------------------------------------
  -- 1.0    18-03-2018  Roman.W  CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  ----------------------------------------------------------------------------------------------------
  PROCEDURE set_item_ship_set_to_null(p_ship_set_id IN NUMBER,
			  p_error_code  OUT NUMBER,
			  p_error_desc  OUT VARCHAR2);

  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman.W   CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --                               procedure combine delivery with intangible items only by Ship Set,
  ---------------------------------------------------------------------------------------------------
  PROCEDURE combine_delivery_by_ship_set(p_delivery_id IN NUMBER,
			     p_ship_set_id IN NUMBER,
			     p_error_code  OUT NUMBER,
			     p_error_desc  OUT VARCHAR2);

  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman.W   CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --                               procedure combine delivery with intangible items only by Order,
  ---------------------------------------------------------------------------------------------------
  PROCEDURE combine_delivery_by_order(p_delivery_id IN NUMBER,
			  p_header_id   IN NUMBER,
			  p_error_code  OUT NUMBER,
			  p_error_desc  OUT VARCHAR2);

  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman.W   CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  ---------------------------------------------------------------------------------------------------
  PROCEDURE ship_confirm_delivery_check(p_delivery_id IN NUMBER,
			    p_error_code  OUT NUMBER,
			    p_error_desc  OUT VARCHAR2);

  -----------------------------------------------------------------------------------
  -- Ver      When        Who           Description
  -- -------  ----------  ------------  ----------------------------------------------
  -- 1.0      27-05-2018  Roman W.      CHG0042242 - Eliminate Ship Confirm errors due
  --                                          to Intangible Items
  ------------------------------------------------------------------------------------
  PROCEDURE update_log_status(p_status     IN VARCHAR2,
		      p_error_code OUT NUMBER,
		      p_error_desc OUT VARCHAR2);

  ------------------------------------------------------------------------------------
  -- Ver      When        Who           Description
  -- -------  ----------  ------------  ----------------------------------------------
  -- 1.0      27-05-2018  Roman W.      CHG0042242 - Eliminate Ship Confirm errors due
  --                                          to Intangible Items
  ------------------------------------------------------------------------------------
  PROCEDURE insert_to_log(p_log_dta    IN xxinv_trx_delivery_audit_tbl%ROWTYPE,
		  p_error_code OUT NUMBER,
		  p_error_desc OUT VARCHAR2);

  ------------------------------------------------------------------------------------
  -- Ver      When        Who           Description
  -- -------  ----------  ------------  ----------------------------------------------
  -- 1.0      27-05-2018  Yuval tal       CHG0046435 - Eliminate Ship Confirm errors due
  --                                          to Intangible Items
  ------------------------------------------------------------------------------------                        
  FUNCTION is_report_submitted(p_calling_proc VARCHAR2,
		       p_report_type  VARCHAR2,
		       p_delivery_id  NUMBER) RETURN VARCHAR2;

END xxinv_trx_in_pkg;
/