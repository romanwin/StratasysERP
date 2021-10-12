create or replace package xxoe_utils_pkg IS
  --
  --  DO NOT PUT IN THIS PACKAGE ANY DML COMMANDS !!!!!!!!!!!!!!!!!!!!!!
  --
  --
  --------------------------------------------------------------------
  --  name:            XXOE_UTILS_PKG
  --  create by:       RanS
  --  Revision:        1.11
  --  creation date:   25/10/2009
  --------------------------------------------------------------------
  --  purpose :        various utilities for OE
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/10/2009  RanS            initial build
  --  1.1  02/02/2009  Dalit A. raviv  Resin Balance customization
  --  1.2  15/07/2010  Yuval Tal       add procedure get_order_average_dicount
  --  1.4  02/01/2011  Yuval Tal       add get_requestor_name+ get_requisition_number
  --                                   (used in XXWSH_SHIPPING_DETAILS_V)
  -- 1.5   1.2.11      yuval tal       add is_hazard_delivery
  -- 1.6   30.10.11     yuval tal      add get_line_ship_to_territory -- CR329
  -- 1.7   20.5.12     dovik pollak    add function is_coupon_item
  -- 1.8   23.7.13     yuval tal       add show_dental_alert
  -- 1.9   03.12.13    Dovik pollak/
  --                   Ofer Suad       CR 1122  add bundle functionality
  -- 1.10  19/02/2014  Dalit A. Raviv  REP009 - Order Acknowledgment\
  --                                   CR1327 Adjustment for Dental Advantage Sticker
  --                                   add function - show_dis_get_line
  -- 1.11  09/03/2014  Dalit A. Raviv  OCHG0031347 - Get shipping instructions
  -- 1.12  06.4.14     yuval tal       CHG0031865 modify show_dis_get_line : change p_line_id type from number to char
  -- 1.13  09.06.14    yuval tal       CHG0032388 - add function  get_cancelation_comment
  -- 1.14  01.7.14     yuval tal       CHG0031508 - Salesforce Customer support Implementation  CTASK0014413  - add get_SO_line_delivery
  -- 1.15  07.09.2014  Michal Tzvik    CHG0032651 - add function om_print_config_option
  -- 1.16  21.10.2014  Ofer Suad       CHG0032650  PTOs: Average Discount Calculation and Revenue Distribution
  -- 1.17  28.10.2014  Michal Tzvik    CHG0033456  Customs Clearance Charges for FOC Service Part
  --                                              - Add function: is_item_service_contract
  -- 1.171 24.11.2014  Michal Tzvik    CHG0033602 - Add function: is_service_contract
  -- 1.18  22.01.2015  Michal Tzvik    CHG0033848 - Add function get_qp_list_price
  -- 1.19  28.01.2015  Michal Tzvik    CHG0034428 - Add function calc_avg_discount
  -- 1.20  26.04.2015  Michal Tzvik    CHG0034991 - Add parameter p_org_id to FUNCTION get_resin_balance
  -- 1.21  07.03.2016 Lingaraj Sarangi CHG0037863 -DG- Add indication on Shipping Docs for Non Restricted items
  -- 1.22  21.7.2016  yuval tal        CHG0038970  modify  add safe_devisor/get_precision
  --                                    get_price_list_dist proc  from  xxar_autoinvoice_pkg.get_price_list_dist
  -- 1.23  12.1.2017  Dipta            CHG0039567- Add new function get_resin_credit_description
  --                   Chatterjee      to return Resin Credit line item description
  -- 1.25  14.2.2017  Adi Safin        CHG0040093 -  interface to bring the SN for warranty PN's
  --                                   Added a New Function <is_item_service_warranty>
  -- 1.26  04.04.2017 L.Sarangi        CHG0040389: Resin Credit  - add an option to link resin credit consumption orders to resin credit purchase order
  --                                   Function <get_original_so_resin_balance> Created
  -- 1.27  09/26/2017 Dipta Chatterjee CHG0041334 - Add new function get_resin_credit_for_bundle to be used by OIC
  --                                   setup for calculating the resin credit included within bundle item order lines
  -- 1.28  19.02.2018 bellona banerjee CHG0041294- Added P_Delivery_Name to is_hazard_delivery and is_dg_restricted_delivery
  --                   as part of delivery_id to delivery_name conversion
  -- 1.29  10.01.2019 Diptasurjya      CHG0044828 - Add new function get_order_approver_info
  -- 1.30  21.08.2019 bellona banerjee CHG0045507 - Add new function get_modif_reason_msg
  -- 1.31  08/21/2019 Diptasurjya      CHG0045128 - Add function generate_ack_dist_list to Build email distribution list based on input parameters
  -- 1.32  10/24/2019 Diptasurjya      CHG0046640 - Add new funtion modifier_elibility_type for qualifier attribute
  -- 1.4   24/03/2020 Roman W.         CHG0047653 - Commercial Invoice - Change logic for Zero price for SP items
  -- 1.5   04/02/2021 Roman W.         CHG0049362 - ECO country excluding from notifications
  --                                                added function "get_ship_to_country_code"
  -- 1.6  01-JUN-2021 Diptasurjya      INC0233284 - Add new function get_order_totals
  --  DO NOT PUT IN THIS PACKAGE ANY DML COMMANDS !!!!!!!!!!!!!!!!!!!!!!
  --

  --------------------------------------------------------------------
  FUNCTION get_so_line_delivery(p_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_requestor_name(p_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_requisition_number(p_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_initial_order(p_order_type_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0034428
  --  name:               calc_avg_discount
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      28/01/2015
  --  Purpose :           Returns Y if the supplied order type require
  --                      average discount calculation
  --                      In case of some error returns E.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/01/2015    Michal Tzvik    Initial Build: CHG0034428
  ----------------------------------------------------------------------
  FUNCTION calc_avg_discount(p_order_type_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_item_resin(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_resin_balance(p_customer_num VARCHAR2,
                             p_currency     VARCHAR2,
                             p_order_num    NUMBER DEFAULT NULL,
                             p_org_id       NUMBER DEFAULT NULL) -- 26/04/2015 Michal Tzvik CHG0034991 : Add parameter p_org_id
   RETURN NUMBER;

  FUNCTION is_item_resin_credit(p_inventory_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_coupon_item(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION calc_resin_credit(p_form_total   NUMBER,
                             p_line_prev    NUMBER,
                             p_line_new     NUMBER,
                             p_currency     VARCHAR2,
                             p_customer_num VARCHAR2,
                             p_order_num    NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_exists_resin_balance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   02/02/2009
  --------------------------------------------------------------------
  --  purpose :        get So resin credit balance from data base
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_exists_resin_balance(p_customer_num VARCHAR2,
                                    p_currency     VARCHAR2,
                                    p_order_num    NUMBER DEFAULT NULL)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_global_sum_rc_value
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   03/02/2009
  --------------------------------------------------------------------
  --  purpose :        Calc global sum value
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_global_sum_rc_value(p_global_sum      NUMBER,
                                   p_line_unit_price NUMBER,
                                   p_global_hist     NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_order_resin_balance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   07/02/2009
  --------------------------------------------------------------------
  --  purpose :        Calc order resin balance without the current record.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_order_resin_balance(p_customer_num  VARCHAR2,
                                   p_currency      VARCHAR2,
                                   p_order_line_id NUMBER,
                                   p_order_num     NUMBER DEFAULT NULL)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_item_type
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   07/02/2009
  --------------------------------------------------------------------
  --  purpose :        Calc order resin balance without the current record.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_item_type(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_order_average_dicount
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   15/07/2010
  --------------------------------------------------------------------
  --  purpose :        Calc order average dicount under conditions.
  --
  --------------------------------------------------------------------
  --  ver  date        name          desc
  --  1.0  15/07/2010  yuval tal     add get_order_average_discount
  --  2.0  26/12/2010  yuval tal     add GA logic
  --------------------------------------------------------------------
  FUNCTION get_order_average_discount(p_header_id IN NUMBER) RETURN VARCHAR2;

  --FUNCTION is_hazard_delivery(p_delivery_id NUMBER) RETURN VARCHAR2;      -- CHG0041294 on 19/02/2018 for delivery id to name change
  FUNCTION is_hazard_delivery(p_delivery_name VARCHAR2) RETURN VARCHAR2; -- CHG0041294 on 19/02/2018 for delivery id to name change

  FUNCTION get_line_ship_to_territory(p_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION show_dental_alert(p_order_number     VARCHAR2,
                             p_item_id          NUMBER,
                             p_current_quantity NUMBER,
                             p_unit_limit       NUMBER,
                             p_month_back       NUMBER) RETURN NUMBER;
  FUNCTION get_chm_pack_of(p_item_id NUMBER) RETURN NUMBER;

  FUNCTION is_comp_bundle_line(p_line_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_bundle_line(p_line_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            show_dis_get_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/02/2014
  --------------------------------------------------------------------
  --  purpose :        REP009 - Order Acknowledgment
  --                   CR1327 - Adjustment for Dental Advantage Sticker
  --                   The function will look if the oe_line have adjustment from
  --                   type discount, and will check for each adjustment found
  --                   at the modifier what is the value at the modifier att3.
  --                   this will determine if to show or not the line at reports.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  19/02/2014  Dalit A. Raviv  initial build
  --  1.1   06.4.14    yuval tal       CHG0031865 modify show_dis_get_line : change p_line_id type from number to char
  --------------------------------------------------------------------
  FUNCTION show_dis_get_line(p_line_id IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_shipping_instructions
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/03/2014
  --------------------------------------------------------------------
  --  purpose :        get shipp to instructions by so header id and ship to location id
  --                   ship_to_org_id from the So show the ship to location information
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_shipping_instructions( --p_so_header_id   in number,
                                     p_ship_to_org_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_cancelation_comment(p_header_id NUMBER,
                                   p_line_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0032650
  --  name:               is_model_line
  --  create by:          Ofer Suad
  --  Revision:
  --  creation date:     21.10.2014
  --  Purpose :           Return Y if it is PTO parent line
  ----------------------------------------------------------------------

  FUNCTION is_model_line(p_line_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0032650
  --  name:               is_option_line
  --  create by:          Ofer Suad
  --  Revision:
  --  creation date:     21.10.2014
  --  Purpose :           Return Y if it is PTO child line
  ----------------------------------------------------------------------
  FUNCTION is_option_line(p_line_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0032651
  --  name:               om_print_config_option
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if so line is ATO or PTO. Else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   01.09.2014    Michal Tzvik    Initial Build
  -------------------------------------------------------
  FUNCTION om_print_config_option(p_so_line_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            IS_LINE_ORDER_UNDER_CONTRACT
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   07/10/2014
  --------------------------------------------------------------------
  --  purpose :        Function for Custom clearence report. Check according order line id
  --                   if it RMA(return & Replace) order (depot repair or SFDC) and the Printer is under contract
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  07/10/2014  Adi Safin        initial build
  --------------------------------------------------------------------
  FUNCTION is_line_order_under_contract(p_line_id IN NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0033602
  --  name:               is_item_service_contract
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if item is Service Contract, else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   04.11.2014    Michal Tzvik    Initial Build
  -------------------------------------------------------
  FUNCTION is_item_service_contract(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0033848
  --  name:               get_qp_list_price
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Get price from price list. Used when price_list in so line is 0
  --                      (PTO component lines, for example)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22.01.2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_qp_list_price(p_line_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            is_DG_Restricted_delivery
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   07-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037863
  --                   DG- Add indication on Shipping Docs for Non Restricted items
  --                   The function will return Y if the delivery conatins any DG Restricted Item
  --                   Will Return N , if the delivery conatins any DG non Restricted Item only or Non DG item and DG non restricted Item
  --                   Will Return null,if the delivery conatins only Non DG Item
  --------------------------------------------------------------------
  --  ver  date         name                 desc
  --  1.0  07-Mar-2016  Lingaraj Sarangi     initial version
  --------------------------------------------------------------------
  --FUNCTION is_dg_restricted_delivery(p_delivery_id NUMBER) RETURN VARCHAR2;    -- CHG0041294 on 19/02/2018 for delivery id to name change
  FUNCTION is_dg_restricted_delivery(p_delivery_name VARCHAR2)
    RETURN VARCHAR2; -- CHG0041294 on 19/02/2018 for delivery id to name change

  FUNCTION get_precision(p_currency_code VARCHAR2) RETURN NUMBER;
  FUNCTION get_price_list_dist(p_line_id    NUMBER,
                               p_price_list NUMBER,
                               p_attribute4 NUMBER) RETURN NUMBER;

  ------------------------------------------------------------
  -- Name: get_resin_credit_description
  -- Description: Returns the resin credit line description
  -- If resin amount is 0 or less null is returned
  ------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   12/28/2016    Dipta Chatterjee  CHG0039567- Resin Credit balance is not correct
  ------------------------------------------------------------
  FUNCTION get_resin_credit_description(p_line_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0040093
  --  name:               is_item_service_warranty
  --  create by:          Adi Safin
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if item is Service Warranty, else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   14.02.2017    Adi Safin    Initial Build
  -------------------------------------------------------
  FUNCTION is_item_service_warranty(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

  --customization code : CHG0040389
  -- Name         : get_original_so_resin_balance
  -- Description  : Returns the balance of Orinal SO's resin credit per customer and currency,
  --                excluding the current order.
  --                If no balance exists returns 0.
  -- create by    :Lingaraj Sarangi
  ------------------------------------------------------------
  --  ver  date         name                desc
  --  1.0  04.04.2017   Lingaraj Sarangi    CHG0040389 :Initial Build
  ------------------------------------------------------------
  FUNCTION get_original_so_resin_balance(p_customer_num      VARCHAR2,
                                         p_currency          VARCHAR2,
                                         p_exclude_order_num NUMBER,
                                         p_org_so_num        NUMBER,
                                         p_org_id            NUMBER DEFAULT NULL,
                                         p_line_status       VARCHAR2 DEFAULT NULL)
    RETURN NUMBER;
  ------------------------------------------------------------
  -- Name: get_resin_credit_for_bundle
  -- Description: Returns the resin credit issued as part of a bundle item
  -- This function will take the order line id of the bundle item as input
  -- and try to find all resin_credit lines that were created as part of the bundle item line
  -- This will then return the sum of all the resin credit amounts (attribute4)
  --
  -- Usage: OIC Collection parameter setup for system transaction collection
  ------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   09/20/2017    Dipta Chatterjee  CHG0041334- Return resin credt amount issued as part of bundle item
  ------------------------------------------------------------
  function get_resin_credit_for_bundle(p_line_id          IN number,
                                       p_comm_line_api_id IN varchar2 DEFAULT null)
    return number;

  --------------------------------------------------------------------------------------------------
  --  name:              get_order_status_for_sforce
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     08/08/2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0043691  : Fetch order header status for Strataforce
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   08/08/2018    Diptasurjya          CHG0043691 - Initial build
  --------------------------------------------------------------------------------------------------
  function get_order_status_for_sforce(p_header_id number) return varchar2;

  --------------------------------------------------------------------------------------------------
  --  name:              get_order_approver_info
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     01/10/2019
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0044828  : Build a string to show the current approvers of Sales Order
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   01/10/2019    Diptasurjya          CHG0044828 - Initial build
  --------------------------------------------------------------------------------------------------
  function get_order_approver_info(p_header_id number) return varchar2;

  -----------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------
  -- 1.0     2019-08-13  Roman W.    CHG0045507 - For Order with discount at line level,
  --                                   the field "Modification Reason" needs to be set as mandatory
  -----------------------------------------------------------------------------------------
  function get_modif_reason_msg(p_header_id number) return varchar2;

  --------------------------------------------------------------------------------------------------
  --  name:              generate_ack_dist_list
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     08/21/2019
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0045128  : Build email distribution list based on input parameters
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   08/21/2019    Diptasurjya          CHG0045128 - Initial build
  --------------------------------------------------------------------------------------------------
  FUNCTION generate_ack_dist_list(p_order_type_id      NUMBER,
                                  p_ship_contact_id    NUMBER,
                                  p_bill_contact_id    NUMBER,
                                  p_sold_contact_id    NUMBER,
                                  p_existing_dist_list varchar2,
                                  p_distribution_type  varchar2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  --  name:              modifier_elibility_type
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     10/10/2019
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0046640  : Determine if an item is eligible for QP discounts based on item category
  --                                   Item Version
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   10/10/2019    Diptasurjya          CHG0046640 - Initial build
  --------------------------------------------------------------------------------------------------
  function modifier_elibility_type(p_inventory_item_id IN NUMBER)
    return varchar2;

  ----------------------------------------------------------------------------------------------------
  -- Ver   When         Who            Descr
  -- ----  -----------  -------------  ---------------------------------------------------------------
  -- 1.0   24/03/2020   Roman W.       CHG0047653 - Commercial Invoice - Change logic for Zero price for SP items
  ----------------------------------------------------------------------------------------------------
  function is_line_order_sp_zero(p_line_id number) return varchar2;

  --------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  -------------------------------------------
  -- 1.0   04/02/2021  Roman W.        CHG0049362 - ECO country excluding from notifications
  --------------------------------------------------------------------------------
  --  function get_ship_to_country_code(p_line_id NUMBER) return varchar2;

  --------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  -------------------------------------------
  -- 1.0   04/02/2021  Roman W.        CHG0049362 - ECO country excluding from notifications
  --------------------------------------------------------------------------------
  function get_ship_to_country_code(p_ship_to_org_id NUMBER) return varchar2;
  
  --------------------------------------------------------------------------------------------------
  --  name:              get_order_totals
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     1-JUN-2021
  --------------------------------------------------------------------------------------------------
  --  purpose :          INC0233284  : Calculate the order amount for order header ID
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   1-JUN-2021    Diptasurjya          INC0233284 - Initial build
  --------------------------------------------------------------------------------------------------
  function get_order_totals(p_header_id NUMBER,
                            p_converted_currency VARCHAR2 default NULL) return number;
  
END xxoe_utils_pkg;
/
