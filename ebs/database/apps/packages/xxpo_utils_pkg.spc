create or replace package xxpo_utils_pkg IS

  --------------------------------------------------------------------
  --  name:            xxpo_utils_pkg
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   31/08/2009
  --------------------------------------------------------------------
  --  purpose :        Generic package for PO
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  31/08/2009  XXX            initial build
  --  1.1  02.12.2010  yuval tal      add get_blanket_total
  --                                  change get_last_po_price
  --                                  get_last_po_entity
  --  1.2  26/12/2010  Eran Baram     add trunc at get_acceptance procedure
  --  1.3  18.3.2012   yuval tal      support releasees
  --  1.5  16.12.12    yuval tal      cr624:  add is_quotation_exists,is_po_exists
  --  1.6  4.4.13      yuval tal      cr643 : add get_item_schedule_group_name , get_open_po_info Shipping backlog - Add additional columns for tracing Inter SO
  --  1.7  19.06.13    yuval tal      bugfix 831:Last PO price  Currency- at notification
  --                                  get_formatted_amount add paramter  p_release_num
  --  1.8  5-SEP-2014  Sandeep Akula  Added Functions get_matching_type,get_project_number,get_task_number,get_expenditure_org (CHG0031574)
  --  1.9  16/12/2014  Dalit A. Raviv add function get_sourcing_rule
  --  1.10 16/03/2015  Dalit A. RAviv CHG0034192 - add function get_vs_email
  --  1.11  9.12.15    yuval tal      CHG0037199 change  Vendor Scheduler at Site level  modify get_vs_email,get_vs_name
  --                                  add get_vs_person_id
  --  1.12 25.08.2016  L.Sarangi      CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --                                  Added a new function & Procedure <get_item_costForPO> to show the item cost in the PO Approval Notification
  -- 1.13 12.6.17      yuval tal        CHG0040374 - modify  get_last_po_price add  parameter p_ou_id
  -- 1.19 03-Jul-2018  dan melamed     CHG0043185 - Implement price tolarance checks for P.O vs P.R Approval.
  --                                   CHG0043332 - Eliminate the option to place P.O Without P.R
  -- 2.0  05-Nov-2018  Lingaraj        CHG0043863-CTASK0038483-New Logic for Default Buyer
  ------------------------------------------------------------------

  FUNCTION get_po_win_title(p_po_num VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_linkage_rate(p_po_num VARCHAR2) RETURN NUMBER;

  FUNCTION get_linkage_amount(p_po_num VARCHAR2, p_amount NUMBER)
    RETURN NUMBER;

  PROCEDURE do_linkage(p_po_num        po_headers_all.segment1%TYPE,
                       p_po_line_id    po_lines_all.po_line_id%TYPE,
                       p_from_currency po_headers_all.currency_code%TYPE,
                       p_to_currency   po_headers_all.currency_code%TYPE,
                       p_base_date     DATE);

  PROCEDURE get_linkage(p_po_num VARCHAR2,
                        p_rate   OUT NUMBER,
                        p_curr   OUT po_headers_all.currency_code%TYPE,
                        p_level  VARCHAR2 DEFAULT 'LINES');

  PROCEDURE should_do_linkage(p_req_distribution_id po_distributions_all.req_distribution_id%TYPE,
                              p_curr_return         OUT po_headers_all.currency_code%TYPE,
                              p_date_return         OUT DATE);

  PROCEDURE get_po_type_num_curr(p_po_header_id po_headers_all.po_header_id%TYPE,
                                 p_type         OUT po_headers_all.type_lookup_code%TYPE,
                                 p_curr         OUT po_headers_all.currency_code%TYPE,
                                 p_num          OUT po_headers_all.segment1%TYPE,
                                 p_date         OUT po_headers_all.rate_date%TYPE);
  /*  procedure xxx;  */
  FUNCTION get_last_linkage_creation(p_po_number      VARCHAR2,
                                     p_release_number NUMBER) RETURN DATE;
  FUNCTION get_linkage_date(p_po_num VARCHAR2) RETURN DATE;

  PROCEDURE get_linkage_plus(p_po_num          VARCHAR2,
                             p_rate            OUT NUMBER,
                             p_curr            OUT po_headers_all.currency_code%TYPE,
                             p_date            OUT DATE,
                             p_conversion_type OUT clef062_po_index_esc_set.conversion_type%TYPE);

  FUNCTION get_po_destination(p_po_header_id NUMBER) RETURN VARCHAR2;

  FUNCTION check_inventory_destination(p_po_header_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_vs_person_id(p_vendor_site_id NUMBER) RETURN NUMBER;
  FUNCTION get_vs_name(p_vendor_site_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_vs_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/03/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034192 - DFT Automatically alert of risky Kanban
  --                   use in alert XX_INV_RISKY_KANBAN
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/03/2015  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_vs_email(p_vendor_site_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_supplier_currency(p_vendor_id      NUMBER,
                                 p_vendor_site_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_rtv_qty(p_line_location_id NUMBER) RETURN NUMBER;

  FUNCTION get_acceptance_desc(p_header_id  NUMBER,
                               p_release_id NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  FUNCTION highlight_record_check(p_item_id          NUMBER,
                                  p_supplier_id      NUMBER,
                                  p_supplier_site_id NUMBER,
                                  p_req_currency     VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_formatted_amount(p_po_number   VARCHAR2,
                                p_po_currency VARCHAR2,
                                p_line_price  NUMBER,
                                p_release_num NUMBER) RETURN VARCHAR2;

  FUNCTION calc_po_price(p_from_cur VARCHAR2,
                         p_to_cur   VARCHAR2,
                         p_price    NUMBER) RETURN NUMBER;

  FUNCTION get_line_type_basis(p_line_type_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_last_po_price
  --  create by:       Yaniv Nitzan
  --  Revision:        1.0
  --  creation date:   25/04/2010
  --------------------------------------------------------------------
  --  purpose :        enable to retrieve the last PO price acording to reference
  --                   date to be provided as param for specific part number
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/04/2010  Yaniv Nitzan   initial build
  -- 1.1 12.6.17      yuval tal       CHG0040374 - modify  get_last_po_price add  parameter p_ou_id

  --------------------------------------------------------------------
  FUNCTION get_last_po_price(p_item_id NUMBER,
                             p_date    DATE,
                             p_ou_id   NUMBER DEFAULT 81) RETURN NUMBER;
  FUNCTION get_last_rcv_po_price(p_item_id NUMBER, p_date DATE) RETURN NUMBER;
  --------------------------------------------------------------------
  --  name:            get_last_po_entity
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/05/2010
  --------------------------------------------------------------------
  --  purpose :        enable to retrieve the last PO buyer name acording to reference
  --                   date to be provided as param for specific part number
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/05/2010  Dalit A. Raviv initial build
  --------------------------------------------------------------------
  FUNCTION get_last_po_entity(p_item_id NUMBER,
                              p_date    DATE,
                              p_entity  VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_last_rcv_receipt_num(p_item_id NUMBER, p_date DATE)
    RETURN VARCHAR2;
  ----------------------------------------------------------------
  -- get_blanket_total_amt
  -- for personalization in blanket form
  --  1.0  25/05/2010  yuval. tal  initial build
  ----------------------------------------------------------------

  FUNCTION get_blanket_total_amt(p_po_header_id NUMBER) RETURN NUMBER;

  ----------------------------------------------------------------
  -- update_suggested_buyer [obsolete - Donot Use]
  -- for personalization in req form
  --  1.0  21.1.13  yuval. tal  initial build
  --  1.2  05.NOV.18    Lingaraj      CHG0043863 - Procedure obsolete
  --                                  Use Procedure- update_suggested_buyer2
  -----------------------------------------------------------------------
  PROCEDURE update_suggested_buyer_old(p_requisition_header_id NUMBER);
  
  --------------------------------------------------------------------
  --  name:            update_suggested_buyer
  --  create by:       Lingaraj
  --  Revision:        1.0
  --  creation date:   05-Nov-2018
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05-Nov-2018 Lingaraj        CHG0043863-CTASK0038483-New Logic for Default Buyer
  --------------------------------------------------------------------
  PROCEDURE update_suggested_buyer(p_requisition_header_id NUMBER,
                                    p_module                VARCHAR2 DEFAULT 'xxpo_utils_pkg.update_suggested_buyer',
                                    p_debug                 NUMBER DEFAULT 0);

  ----------------------------------------------------------------
  -- get_default_buyer
  -- for personalization in req form
  --  1.0  28.4.11  yuval. tal  initial build
  -- p_type : ID/NAME
  ----------------------------------------------------------------

  FUNCTION get_default_buyer(p_requisition_header_id NUMBER,
                             p_type                  VARCHAR2,
                             p_category_id           NUMBER,
                             p_requestor_id          NUMBER) RETURN VARCHAR2;
  
  ----------------------------------------------------------------
  -- get_inv_num_for_po
  -- for disc report
  --  1.0  15.6.11  Ofer. Suad  initial build

  ----------------------------------------------------------------

  FUNCTION get_inv_num_for_po(p_shipment_id NUMBER) RETURN VARCHAR2;
  ----------------------------------------------------------------
  -- get_inv_amt_for_po
  -- for disc report
  --  1.0  15.6.11  Ofer. Suad  initial build

  ----------------------------------------------------------------
  FUNCTION get_inv_usd_amt_for_po(p_shipment_id NUMBER) RETURN NUMBER;
  ----------------------------------------------------------------
  -- get_inv_amt_for_po
  -- for disc report
  --  1.0  15.6.11  Ofer. Suad  initial build

  ----------------------------------------------------------------
  FUNCTION get_inv_amt_for_po(p_shipment_id NUMBER) RETURN NUMBER;

  FUNCTION get_first_approve_date(p_po_header_id NUMBER, p_type VARCHAR2)
    RETURN DATE;

  ---------------------------------------
  -- is_po_exists
  ---------------------------------------
  FUNCTION is_po_exists(p_org_id       NUMBER,
                        p_po_header_id NUMBER,
                        p_po_line_id   NUMBER,
                        p_item_id      NUMBER,
                        p_vendor_id    NUMBER) RETURN VARCHAR2;

  ---------------------------------------
  -- is_quotation_exists
  ---------------------------------------
  FUNCTION is_quotation_exists(p_org_id    NUMBER,
                               p_item_id   NUMBER,
                               p_vendor_id NUMBER) RETURN VARCHAR2;
  ---------------------------------------
  -- get_item_schedule_group_name
  ---------------------------------------

  FUNCTION get_item_schedule_group_name(p_item_id         NUMBER,
                                        p_organization_id NUMBER)
    RETURN VARCHAR2;
  -------------------------------------------
  -- get_open_po_info

  ------------------------------------------
  FUNCTION get_open_po_info(p_item_id NUMBER) RETURN VARCHAR2;
  -------------------------------------------
  -- get_req_info
  ------------------------------------------
  FUNCTION get_req_info(p_item_id NUMBER) RETURN VARCHAR2;
  -------------------------------------------
  -- get_open_po_quantity
  -------------------------------------------
  FUNCTION get_open_po_quantity(p_item_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_matching_type
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Matching Type for the PO (This Function does not check if the PO was matched to a Invoice)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_matching_type(p_header_id   IN NUMBER,
                             p_line_id     IN NUMBER,
                             p_release_num IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_project_number
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Project Number on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_project_number(p_project_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_task_number
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Task Number on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION get_task_number(p_project_id IN NUMBER, p_task_id IN NUMBER)
    RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_expenditure_org
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Expenditure Organization on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_expenditure_org(p_organization_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_item_sourcing_rule
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2014 09:09:38
  --------------------------------------------------------------------
  --  purpose :        retrieve sourcing rulee by item, if null look at the item category
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  16/12/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_item_sourcing_rule(p_organization_id   IN NUMBER,
                                  p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_item_costForPO
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   25/08/2016
  --------------------------------------------------------------------
  --  purpose :        retrieve Item Cost for PO Notification
  --                   This Item Cost will be displayed in the PO Approval Notification
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  25/08/2016  L.Sarangi       initial build
  --                                   CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --------------------------------------------------------------------
  PROCEDURE get_item_costforpo(p_po_line_id    IN po_lines_all.po_line_id%TYPE,
                               p_item_cost     OUT cst_item_costs.item_cost%TYPE,
                               p_currency_code OUT VARCHAR2,
                               p_error_code    OUT NUMBER,
                               p_error         OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            get_item_costForPO
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   25/08/2016
  --------------------------------------------------------------------
  --  purpose :        retrieve Item Cost for PO Notification
  --                   This Item Cost will be displayed in the PO Approval Notification
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  25/08/2016  L.Sarangi       initial build
  --                                   CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --------------------------------------------------------------------
  FUNCTION get_item_costforpo(p_po_line_id po_lines_all.po_line_id%TYPE)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            do_pre_submission_check
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   03-Jul-2018
  --------------------------------------------------------------------
  --  purpose :        Validation called by the HOOK in PO_CUSTOM_SUBMISSION_CHECK_PVT
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  03-Jul-2018 dan melamed     CHG0043185 - PR-PO price tolerance
  --------------------------------------------------------------------

  PROCEDURE do_pre_submission_check(p_api_version       IN NUMBER,
                                    p_document_id       IN NUMBER,
                                    p_action_requested  IN VARCHAR2,
                                    p_document_type     IN VARCHAR2,
                                    p_document_subtype  IN VARCHAR2,
                                    p_document_level    IN VARCHAR2,
                                    p_document_level_id IN NUMBER,
                                    p_requested_changes IN PO_CHANGES_REC_TYPE,
                                    p_check_asl         IN BOOLEAN,
                                    p_req_chg_initiator IN VARCHAR2,
                                    p_origin_doc_id     IN NUMBER,
                                    p_online_report_id  IN NUMBER,
                                    p_user_id           IN NUMBER,
                                    p_login_id          IN NUMBER,
                                    p_sequence          IN OUT NOCOPY NUMBER,
                                    x_return_status     OUT NOCOPY VARCHAR2);

function get_conv_rate(p_rate_date date, p_backup_date date, p_from_currency varchar2) return number;  
  
END xxpo_utils_pkg;
/