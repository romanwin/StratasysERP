create or replace PACKAGE xxiby_pay_aprroval_util IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXIBY_PAY_APRROVAL_UTIL.spc
  Author's Name:   Sandeep Akula
  Date Written:    24-DEC-2014
  Purpose:         Payment Approval Process Utilities
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  24-DEC-2014        1.0                  Sandeep Akula    Initial Version (CHG0033620)
  10-AUG-2015        1.1                  Sandeep Akula    CHG0035411 - 1. Added new columns in highest_payment_amt_rec record type
                                                                        2. Added New functions get_approval_currency_code, get_approval_curr_conv_rate, get_currency_conv_info, get_currency_conversion_detail
                                                                        3. Added new record type currency_conversion_rec
  ---------------------------------------------------------------------------------------------------*/
  g_curr_request_id NUMBER := fnd_global.conc_request_id;

  TYPE required_approver_rec IS RECORD(
    approver_name  VARCHAR2(100),
    approver_id    NUMBER,
    approver_group VARCHAR2(60));

  TYPE required_approver_tbl IS TABLE OF required_approver_rec;

  TYPE optional_approver_rec IS RECORD(
    approver_name  VARCHAR2(100),
    approver_id    NUMBER,
    approver_group VARCHAR2(60));

  TYPE optional_approver_tbl IS TABLE OF optional_approver_rec;

  TYPE suppl_approver_rec IS RECORD(
    approver_name  VARCHAR2(100),
    approver_id    NUMBER,
    approver_group VARCHAR2(60));

  TYPE suppl_approver_tbl IS TABLE OF suppl_approver_rec;

  TYPE highest_payment_amt_rec IS RECORD(
    payment_amount NUMBER, 
    converted_payment_amount NUMBER, -- Added new column in the record 10-AUG-2015 SAkula CHG0035411
    payment_id     NUMBER,
    payment_currency VARCHAR2(10), -- Added new column in the record 10-AUG-2015 SAkula CHG0035411
    converted_payment_currency VARCHAR2(10), -- Added new column in the record 10-AUG-2015 SAkula CHG0035411
    rnk            NUMBER);

  TYPE signer_group_rec IS RECORD(single_limit_amount NUMBER,
                                  signer_group  VARCHAR2(60),
                                  joint_limit_amount NUMBER);
                                  
  TYPE currency_conversion_rec IS RECORD(conversion_rate NUMBER,
                                         conversion_date VARCHAR2(20));                                         

  FUNCTION get_approval_currency_code(p_payment_id IN NUMBER)
  RETURN VARCHAR2;
  
  FUNCTION get_approval_curr_conv_rate(p_payment_id IN NUMBER,
                                       p_payment_currency IN VARCHAR2)
  RETURN NUMBER;
  
  FUNCTION get_currency_conv_info(p_payment_id IN NUMBER,
                                  p_payment_currency IN VARCHAR2)
  RETURN currency_conversion_rec;
  
  FUNCTION get_pay_process_req_status(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_first_approver(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_highest_payment_rec(p_payment_service_request_id IN NUMBER)
    RETURN highest_payment_amt_rec;

  FUNCTION get_no_of_active_groups(p_payment_service_request_id IN NUMBER)
  RETURN NUMBER;

  FUNCTION get_lowest_group(p_payment_service_request_id IN NUMBER)
  RETURN signer_group_rec;

  FUNCTION get_highest_group(p_payment_service_request_id IN NUMBER)
  RETURN signer_group_rec;

  FUNCTION get_groupa_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupa_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupa_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupb_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupb_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupb_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupc_single_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupc_joint_limit(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_groupc_primary_approver(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION pay_template_validations_sl1 RETURN VARCHAR2;

  FUNCTION ppr_processing_tab_valdatn_sl2(p_checkrun_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION ppr_show_approve_button_sl3 RETURN VARCHAR2;

  FUNCTION pay_workflow_status_sl5(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION activate_ppr_approval_sl5(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_highest_payment_amt_sl6(p_payment_service_request_id IN NUMBER)
    RETURN NUMBER;

  PROCEDURE submit_approval_workflow_sl6(p_payment_service_request_id IN NUMBER,
			     p_approvers                  IN VARCHAR2,
			     --p_final_approver_flag IN VARCHAR2,
			     p_err_code    OUT VARCHAR2,
			     p_err_message OUT VARCHAR2);

  FUNCTION get_default_required_appvr_sl6(p_payment_service_request_id IN NUMBER)
  --p_highest_payment_amt IN NUMBER)
   RETURN NUMBER;

  FUNCTION is_req_approver_updatable_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION required_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
  --p_highest_amt IN NUMBER
   RETURN required_approver_tbl
    PIPELINED;

  FUNCTION show_optional_approver_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION optional_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
  --p_highest_amt IN NUMBER)
   RETURN optional_approver_tbl
    PIPELINED;

  FUNCTION show_supplemental_approver_sl6(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION supplemental_approver_lov_sl6(p_payment_service_request_id IN NUMBER)
  --p_highest_amt IN NUMBER)
   RETURN suppl_approver_tbl
    PIPELINED;

  FUNCTION remove_proposed_pay_button_sl7(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION remove_reject_items_button_sl8(p_payment_service_request_id IN NUMBER)
    RETURN VARCHAR2;

  PROCEDURE get_ack_email(p_ack_level  IN NUMBER,
		  p_orgnlmsgid IN NUMBER,
		  p_to_email   OUT VARCHAR2,
		  p_cc_email   OUT VARCHAR2);

  FUNCTION get_doc_status(p_payment_service_request_id IN NUMBER,
		  p_doc_id                     IN NUMBER)
    RETURN VARCHAR2;

  PROCEDURE get_approvers_order(p_approvers_string IN VARCHAR2,
		        p_flag             IN VARCHAR2,
		        p_final_approvers  OUT VARCHAR2,
		        p_err_code         OUT VARCHAR2,
		        p_err_msg          OUT VARCHAR2);

  PROCEDURE submit_report(p_doc_instance_id IN NUMBER,
		  p_err_code        OUT NUMBER,
		  p_err_message     OUT VARCHAR2);

  FUNCTION move_output_file(p_file_name IN VARCHAR2)
  RETURN VARCHAR2;

  PROCEDURE get_notification_attachment(document_id   IN VARCHAR2,
			                                  display_type  IN VARCHAR2,
			                                  document      IN OUT BLOB,
			                                  document_type IN OUT VARCHAR2);

  PROCEDURE get_notification_body(document_id   IN VARCHAR2,
		          display_type  IN VARCHAR2,
		          document      IN OUT NOCOPY CLOB,
		          document_type IN OUT NOCOPY VARCHAR2);

  PROCEDURE get_notification_subject(p_doc_instance_id IN NUMBER,
			 p_subject         OUT VARCHAR2,
			 p_err_code        OUT NUMBER,
			 p_err_message     OUT VARCHAR2);
 
   --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    generate_reference_link
  Author's Name:   Michal Tzvik
  Date Written:    01-FEB-2015
  Purpose:         This Function builds the reference link ("View Additional Details") of the Approval Notification
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  01-FEB-2015        1.0                  Michal Tzvik     Initial Version -- CHG0033620
  17-SEP-2015        1.1                  Michal Tzvik     CHG0035411 - Change from procedure to function  
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE generate_reference_link(p_doc_instance_id IN NUMBER,
			p_err_code        OUT NUMBER,
			p_err_message     OUT VARCHAR2); 
      
  FUNCTION get_reference_link(p_doc_instance_id IN NUMBER) 
  RETURN VARCHAR2;
  

  PROCEDURE abort_workflow(p_err_code                   OUT NUMBER,
                           p_err_message                OUT VARCHAR2,
                           p_payment_service_request_id IN NUMBER DEFAULT NULL,
                           p_checkrun_id                IN NUMBER DEFAULT NULL);

  PROCEDURE BEFORE_APPROVAL_VALIDATIONS(p_err_code                   OUT NUMBER,
                                        p_err_message                OUT VARCHAR2,
                                        p_payment_service_request_id IN NUMBER);
                                        
  FUNCTION get_currency_conversion_detail(p_payment_service_request_id IN NUMBER)
  RETURN VARCHAR2;

END xxiby_pay_aprroval_util;
/
