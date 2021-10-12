create or replace package xxom_auto_hold_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOM_AUTO_HOLD_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/04/2013  Dalit A. Raviv    initial build
  --  1.1  24/08/2014  Dalit A. Raviv    add procedure apply_hold_book_wf CHG0032401
  --  1.2  19/04/2015  Dalit A. Raviv    CHG0034419 Add Customer support auto hold functionality
  --                                     new function check_CS_condition
  --                                     update get_approver_and_fyi
  --  1.3  13/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     New function/ Procedures:
  --                                     submit_wf, release_approval_holds, main_doc_approval_wf
  -- 1.4 7.2.16        yuval tal         CHG0033846 - add get_manual_adj4order,get_manual_adj4line
  -- 1.5  3.3.16       yuval tal         INC0059630 - add get_order_discount_pct
  -- 1.6  07/02/2018  Lingaraj           CHG0041892 - Validation rules and holds on Book
  --                                     Procedure - apply_hold - Added to Specification
  -- 1.7  04/02/2018   Diptasurjya       CHG0041892 - Change payment term hold checking for Strataforce
  -- 1.8  28-Aug-2018  Lingaraj          CHG0043573 - Adjust Discount approval process to support CA order types
  -- 1.9  06-Nov-2018  Diptasurjya       CHG0044277 - Sales order hold performance improvement
  --------------------------------------------------------------------

  --g_xxom_ah_tab_type xxom_ah_tab_type;

  --------------------------------------------------------------------
  --  name:            get_dynamic_condition_sql
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   run the dynamic sql from setup table and return
  --                   if to put hold Yes/No (get so_header_number)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_dynamic_sql(p_entity_id    IN VARCHAR2,
                            p_auto_hold_id IN NUMBER,
                            p_sql_text     IN VARCHAR2,
                            p_subject      IN VARCHAR2,
                            p_return       OUT VARCHAR2,
                            p_err_code     OUT NUMBER,
                            p_err_msg      OUT VARCHAR2);

  PROCEDURE get_dynamic_condition_sql(p_entity_id    IN NUMBER,
                                      p_auto_hold_id IN NUMBER,
                                      p_sql_text     IN VARCHAR2,
                                      p_apply_hold   OUT VARCHAR2,
                                      p_hold_note    OUT VARCHAR2,
                                      p_err_code     OUT NUMBER,
                                      p_err_msg      OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_hold_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Get hold name by the hold id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_hold_name(p_hold_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            release_hold_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Release Hold using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_hold_wf(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2);

  PROCEDURE release_hold(errbuf            OUT VARCHAR2,
                         retcode           OUT VARCHAR2,
                         p_header_id       IN NUMBER,
                         p_org_id          IN NUMBER,
                         p_hold_id         IN NUMBER,
                         p_user_id         IN NUMBER,
                         p_release_comment IN VARCHAR2,
                         p_release_reson   IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            apply_hold_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Procedure that called from the wf and call to apply_hiold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold_wf(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            apply_hold_book
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/08/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold_book_wf(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2);

  PROCEDURE apply_hold_book(errbuf         OUT VARCHAR2,
                            retcode        OUT VARCHAR2,
                            p_so_line_id   IN NUMBER,
                            p_org_id       IN NUMBER,
                            p_user_id      IN NUMBER,
                            p_so_header_id IN NUMBER,
                            p_hold_id      IN NUMBER DEFAULT NULL);

  --------------------------------------------------------------------
  --  name:            apply_hold_book_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold_book_conc(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_so_line_id   IN NUMBER,
                                 p_org_id       IN NUMBER,
                                 p_user_id      IN NUMBER,
                                 p_so_header_id IN NUMBER,
                                 p_hold_id      IN NUMBER DEFAULT NULL);

  --------------------------------------------------------------------
  --  name:            is_hold_needed_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if need to put hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE is_open_hold_exists_wf(itemtype  IN VARCHAR2,
                                   itemkey   IN VARCHAR2,
                                   actid     IN NUMBER,
                                   funcmode  IN VARCHAR2,
                                   resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            is_cc_needed_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE is_cc_needed_wf(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_user_action_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   handle user action in release action
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
                                 itemkey   IN VARCHAR2,
                                 actid     IN NUMBER,
                                 funcmode  IN VARCHAR2,
                                 resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_sql4
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Call from set up form - check that dynamic sql is valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_sql4(p_sql_text VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_sql5
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Call from set up form - check that dynamic sql is valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_sql5(p_sql_text VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_hold_exist_at_setup
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if hold id exists at setup
  --                   call from trigger xxoe_hold_sources_all_aur_t
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_hold_exist_at_setup(p_hold_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            release_notification
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   called from db trigger
  --                   for after hold released which is done from application (not notification)
  --                   the release will continue wf and will send release notifications
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_notification(p_so_header_id IN NUMBER,
                                 p_hold_id      IN NUMBER);

  --------------------------------------------------------------------
  --  name:            release_notification_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   release notification concurrent
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_notification_conc(errbuf         OUT VARCHAR2,
                                      retcode        OUT VARCHAR2,
                                      p_so_header_id IN NUMBER,
                                      p_hold_id      IN NUMBER);

  --------------------------------------------------------------------
  --  name:            initiate_hold_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Handle set WF variables, and initiate the WF itself
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE initiate_hold_process(errbuf             OUT VARCHAR2,
                                  retcode            OUT VARCHAR2,
                                  p_batch_id         IN VARCHAR2,
                                  p_so_header_id     IN NUMBER,
                                  p_so_number        IN VARCHAR2,
                                  p_delivery_id      IN NUMBER,
                                  p_header_type_name IN VARCHAR2,
                                  p_cust_po_number   IN VARCHAR2,
                                  p_customer_id      IN NUMBER,
                                  p_auto_hold_id     IN NUMBER,
                                  p_hold_note        IN VARCHAR2,
                                  p_org_id           IN NUMBER,
                                  p_wf_item_key      OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            main_handle_holds
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Handle Auto Holds
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_handle_holds(errbuf       OUT VARCHAR2,
                              retcode      OUT VARCHAR2,
                              p_batch_id   IN NUMBER,
                              p_hold_stage IN VARCHAR2,
                              p_request_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:            main_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        Call from trigger xx_fnd_concurrent_requests_trg
  --                   Handle the holds for Denied Parties and Auto hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_conc(errbuf       OUT VARCHAR2,
                      retcode      OUT VARCHAR2,
                      p_batch_id   IN NUMBER,
                      p_request_id IN NUMBER,
                      p_hold_stage IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        Call from trigger xx_fnd_concurrent_requests_trg
  --                   Handle the holds for Denied Parties and Auto hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_batch_id   IN NUMBER,
                 p_request_id IN NUMBER,
                 p_hold_stage IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            close_inprocess_hold_wf_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   program that will run once a week/month..
  --                   the program will locate all open WF , and will check per order
  --                   if the hold Manually released.
  --                   if all holds for this order where released so we need to close
  --                   the WF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE close_inprocess_hold_wf_conc(errbuf  OUT VARCHAR2,
                                         retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_order_source
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   04/02/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0041892 - Get order source name for a given line_id or header_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2018  Diptasurjya       initial build
  --  1.1  11/06/2018  Diptasurjya       CHG0044277 - Remove specification for this function
  --------------------------------------------------------------------
  /*FUNCTION get_order_source(p_so_line_id   IN NUMBER,
                            p_so_header_id IN NUMBER) RETURN VARCHAR2;*/

  --------------------------------------------------------------------
  --  name:            chek_discount_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   check if order have manual discount, and if the
  --                   discount threshold exists at setup tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION chek_discount_condition(p_so_line_id IN NUMBER,
                                   p_ref_code   IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_approver_and_fyi
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get the approver by so_line_id and order type
  --                   use at the Auto Hold setup - Approver Sql
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_approver_and_fyi(p_header_id     IN NUMBER,
                                 p_ref_code      IN VARCHAR2,
                                 p_approver      OUT VARCHAR2,
                                 p_fyi_mail_list OUT VARCHAR2,
                                 p_log_code      OUT VARCHAR2,
                                 p_log_msg       OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_order_type_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get if order type exists at the setup to put hold.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_order_type_condition(p_so_line_id IN NUMBER,
                                      p_ref_code   IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            check_CS_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/04/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   CHG0034419 - Add Customer support auto hold functionality
  --                   This function check if to put SO under CS hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/04/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_cs_condition(p_so_line_id IN NUMBER,
                              p_ref_code   IN VARCHAR2,
                              p_category   IN VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            is_pt_threshold_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get if by order type and line_id there is a
  --                   setup for threshold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_pt_threshold_exist(p_so_line_id IN NUMBER,
                                 p_ref_code   IN VARCHAR2) RETURN VARCHAR;

  --------------------------------------------------------------------
  --  name:            is_attachment_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   check if specific attachment exists at header/line level
  --                   if YES put the order in Hold.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_attachment_exist(p_so_line_id  IN NUMBER,
                               p_attach_name IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            main_book
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --                   will run from concurrent program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_send_aggregate_mail(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            prepare_agg_body_msg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Handle prepare the approver message
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/08/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_agg_body_msg(document_id   IN VARCHAR2,
                                 display_type  IN VARCHAR2,
                                 document      IN OUT NOCOPY CLOB,
                                 document_type IN OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            is_discount_overlap
  --  create by:       Lingaraj
  --  Revision:        1.0
  --  creation date:   26/08/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use from the parameter form - validate that there
  --                   is no overlap of the discount and threshold
  --                   from - to numbers
  --------------------------------------------------------------------
  --  ver  when        who          desc
  --  ---  ----------  -----------  ----------------------------------
  --  1.0  26/08/2018  Lingaraj     CHG0043573 - Adjust Discount approval process to support CA order types
  --------------------------------------------------------------------
  FUNCTION is_discount_overlap(p_order_type_id  IN NUMBER,
                               p_reference_code IN VARCHAR2,
                               p_approval_hold_id IN NUMBER,
                               p_from_per_dis   IN NUMBER,
                               p_to_per_dis     IN NUMBER,
                               p_min_dis        IN NUMBER,
                               p_max_dis        IN NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            is_overlap_numbers
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use from the parameter form - validate that there
  --                   is no overlap of the discount/payment term threshold
  --                   from - to numbers
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_overlap_numbers(p_order_type_id  IN NUMBER,
                              p_reference_code IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            prepare_agg_body_msg_frw
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/10/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use at the FRW to print the region of the Hold information
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/10/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION prepare_agg_body_msg_frw(p_auto_hold_ids IN VARCHAR2)
    RETURN xxom_autohold_tab_type;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_approver
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      09/07/2015
  --  Purpose :           submit_wf
  --                      this procedure create wf instance and start the wf
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   09/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE submit_wf(p_so_header_id      IN NUMBER,
                      p_org_id            IN NUMBER DEFAULT NULL,
                      p_so_created_by     IN NUMBER DEFAULT NULL,
                      p_invoice_to_org_id IN NUMBER DEFAULT NULL,
                      p_doc_code          IN VARCHAR2,
                      p_hold_id           IN NUMBER,
                      p_order_hold_id     IN NUMBER,
                      p_auto_hold_id      IN NUMBER,
                      p_hold_created_by   IN NUMBER,
                      x_err_code          OUT VARCHAR2,
                      x_err_msg           OUT VARCHAR2,
                      x_itemkey           OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               release_approval_holds
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      13/07/2015
  --  Purpose :
  --
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   13/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE release_approval_holds(errbuf            OUT VARCHAR2,
                                   retcode           OUT VARCHAR2,
                                   p_doc_instance_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:            main_doc_approval_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/07/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   this procedure will locate all SO that have hold -> Credit Check Failure
  --                   and send for approvals using WF - XX Document Approval
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/07/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_doc_approval_wf(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_so_header_id IN NUMBER,
                                 p_date         IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            is_open_hold_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if open hold exists
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  -- 1.1  28.9.17      Yuval Tal         CHG0041582 add prepay_hold_release_conc :  releasing prepayment holds automatically
  --------------------------------------------------------------------
  FUNCTION is_open_hold_exists(p_so_header_id IN NUMBER,
                               p_hold_id      IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_manual_adj4order(p_header_id NUMBER) RETURN NUMBER;

  FUNCTION get_manual_adj4line(p_header_id NUMBER,
                                p_line_id NUMBER)RETURN NUMBER;

  PROCEDURE get_order_discount_pct(p_header_id           NUMBER,
                                   p_sum_adjusted_amount OUT NUMBER,
                                   p_total_order_amount  OUT NUMBER,
                                   p_discount            OUT NUMBER);

  PROCEDURE prepay_hold_release_conc(errbuf    OUT VARCHAR2,
                                     retcode   OUT VARCHAR2,
                                     p_hold_id NUMBER);

  --------------------------------------------------------------------
  --  name:            apply_hold
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Apply Hold using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --  1.1  07/02/2018  Lingaraj          CHG0041892 - Validation rules and holds on Book
  --                                     Procedure was available before , only added to Specification Part
  --                                     and Allowed to call from other Procedure
  --------------------------------------------------------------------
  PROCEDURE apply_hold(errbuf         OUT VARCHAR2,
                       retcode        OUT VARCHAR2,
                       p_so_header_id IN NUMBER,
                       p_org_id       IN NUMBER,
                       p_user_id      IN NUMBER,
                       p_hold_id      IN NUMBER,
                       p_hold_notes   IN VARCHAR2
                       );

  --------------------------------------------------------------------
  --  name:            purge_auto_hold_audit
  --  create by:       Diptasurjya
  --  Revision:        1.0
  --  creation date:   30/10/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0044277 - purge hold audit data CLOSED/CANCELLED SO header ID
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/10/2018  Diptasurjya       initial build
  --------------------------------------------------------------------
  procedure purge_auto_hold_audit (p_err_code    OUT NUMBER,
                                   p_err_message OUT VARCHAR2);
END xxom_auto_hold_pkg;
/
