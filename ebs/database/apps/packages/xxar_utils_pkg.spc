CREATE OR REPLACE PACKAGE XXAR_UTILS_PKG AUTHID CURRENT_USER IS

--------------------------------------------------------------------
--  name:            XXAR_UTILS_PKG
--  create by:       MAOZ.DEKEL & GABRIEL JERUSALMI
--  Revision:        1.0
--  creation date:   31/08/2009 11:41:48 AM
--------------------------------------------------------------------
--  purpose :        AR generic package
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  31/08/2009                   Initial Build
--  1.1  20.8.2013   yuval tal        CR-970 add function is_account_dist
--  1.2  21.8.2013   vitaly           CR-983 get_customer_open_balance and get_customer_credit_limit_amt added
--  1.3  4-aug-2015  Sandeep Akula    CHG0035932 - Added Function get_company_WEEE_num 
--  1.4  02-Aug-2015 Dalit A. RAviv   CHG0035495 - Workflow for credit check Hold on SO
--                                    Modify function get_exposure_amt, add function get_usd_overdue_amount, get_location_territory
--------------------------------------------------------------------

  TYPE busin_type_table_type IS TABLE OF VARCHAR2(80) INDEX BY BINARY_INTEGER;  
  busin_type busin_type_table_type;
    
  TYPE cust_loc_parent_table_type IS TABLE OF VARCHAR2(80) INDEX BY BINARY_INTEGER;  
  cust_loc_parent cust_loc_parent_table_type;
  
  FUNCTION get_company_name(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_company_reg_number(p_legal_entity_id NUMBER,
                                  p_org_id          NUMBER) RETURN VARCHAR2;
                                  
  FUNCTION get_company_add_reg_num(p_legal_entity_id NUMBER,
                                   p_org_id          NUMBER) RETURN VARCHAR2;
                                   
  FUNCTION get_company_url(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_company_email(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_company_phone(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_company_fax(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_company_address(p_legal_entity_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION sum_prepayment(p_trx_number VARCHAR2, p_profile_prepay VARCHAR2) RETURN NUMBER;

  PROCEDURE xxar_create_code_assignment(p_class VARCHAR2);

  FUNCTION check_tax_lines(p_cust_trx_id NUMBER) RETURN NUMBER;
  
  FUNCTION get_currency_symbol(p_currency VARCHAR2) RETURN VARCHAR2;
  
  FUNCTION get_cont_phone(p_contact_id IN NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_cont_fax(p_contact_id IN NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_party_name(p_site_use_id NUMBER) RETURN VARCHAR2;
  
  --------------------------------------------------------------------
  --  name:            get_item_cost
  --  create by:       daniel katz
  --  Revision:        1.0
  --  creation date:   xx-xxx-xxxx
  --------------------------------------------------------------------
  --  purpose :        for sales report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx-xxx-xxxx daniel katz       initial build
  --------------------------------------------------------------------
  FUNCTION get_item_cost(p_organization_id NUMBER,
                         p_inventory_item  NUMBER,
                         p_date_as_of      DATE) RETURN NUMBER;
  
  --------------------------------------------------------------------
  --  name:            get_item_last_il_cost_ic_trx
  --  create by:       daniel katz
  --  Revision:        1.0
  --  creation date:   xx-xxx-xxxx
  --------------------------------------------------------------------
  --  purpose :        for ratam report
  --                   it finds the last cost of the item from internal shipping from IL 
  --                   to the relevant Operating Unit before the date in the parameter. 
  --                   if it doesn't find then it looks for the cost as of 31-aug-09.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx-xxx-xxxx daniel katz       initial build
  --------------------------------------------------------------------
  FUNCTION get_item_last_il_cost_ic_trx(p_transfer_organization_id NUMBER,
                                        p_inventory_item           NUMBER,
                                        p_before_date              DATE) RETURN NUMBER;

  FUNCTION set_rev_reco_main_busin_type RETURN NUMBER;
  
  FUNCTION set_rev_reco_cust_loc_parent RETURN NUMBER;
  
  FUNCTION get_rev_reco_main_busin_type(p_party_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_rev_reco_cust_loc_parent(p_segment6 VARCHAR2) RETURN VARCHAR2;
  
  --------------------------------------------------------------------
  --  name:            get_print_inv_qty
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   01-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for printed invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01-mar-2012 Ofer Suad         initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_qty(p_sales_order_source      VARCHAR2,
                             p_contract_item_type_code VARCHAR2,
                             p_quantity                NUMBER,
                             p_oe_line_id              NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_print_inv_uom
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   01-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for printed invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01-mar-2012 Ofer Suad         initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_uom(p_sales_order_source      VARCHAR2,
                             p_contract_item_type_code VARCHAR2,
                             p_quantity                NUMBER,
                             p_uom_code                VARCHAR2,
                             p_oe_line_id              NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_print_inv_uom
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   13/05/2012
  --------------------------------------------------------------------
  --  purpose :        for printed invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2012  Vitaly K.         initial build
  --------------------------------------------------------------------
  FUNCTION get_print_inv_uom_tl(p_sales_order_source      VARCHAR2,
                                p_contract_item_type_code VARCHAR2,
                                p_quantity                NUMBER,
                                p_uom_code                VARCHAR2,
                                p_oe_line_id              NUMBER,
                                p_item_id                 NUMBER,
                                p_organization_id         NUMBER,
                                p_org_id                  NUMBER DEFAULT NULL)
    RETURN VARCHAR2;
  
  --------------------------------------------------------------------
  --  name:            get_exposure_amt
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   08-mar-2012
  --------------------------------------------------------------------
  --  purpose :        for credit limit_report get customer exposure according to balance type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08-mar-2012 Ofer Suad         initial build
  --  1.1  02/08/2015  Dalit A. RAviv    add parameter org_id (CHG0035495, WF for credit check Hold on SO)
  --------------------------------------------------------------------
  FUNCTION get_exposure_amt(p_cust_account_id NUMBER,
                            p_balance_types   VARCHAR2,
                            p_base_cauurency  VARCHAR2,
                            p_org_id          number default null) RETURN NUMBER;
  
  --------------------------------------------------------------------
  --  name:            get_usd_overdue_amount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/08/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   get customer credit profile - overdue amount in USD
  --                   function can get the overdue amt by ou
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/08/2015  Dalit A. RAviv    initial build
  --------------------------------------------------------------------
  function get_usd_overdue_amount (p_cust_account_id in number,
                                   p_org_id          in number) return number;
                                   
  --------------------------------------------------------------------
  --  name:            create_and_apply_receipt
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   25-jun-2012
  --------------------------------------------------------------------
  --  purpose :        for i store with CC payemnrts
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25-jun-2012 Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE create_and_apply_receipt(errbuf  OUT VARCHAR2,
                                     retcode OUT NUMBER);

  FUNCTION get_term_name_tl(p_term_id NUMBER, p_org_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION is_account_dist(p_cust_account_id NUMBER) RETURN VARCHAR2;
  
  FUNCTION get_customer_open_balance(p_cust_account_id NUMBER,
                                     p_currency_code   VARCHAR2) RETURN NUMBER;
                                     
  FUNCTION get_customer_credit_limit_amt(p_cust_account_id NUMBER,
                                         p_currency_code   VARCHAR2) RETURN NUMBER;
                                         
  --------------------------------------------------------------------
  --  name:            get_company_WEEE_num
  --  create by:       SAkula
  --  Revision:        1.0
  --  creation date:   04-Aug-2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035932 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04-Aug-2015 SAkula            initial build
  --------------------------------------------------------------------
  FUNCTION get_company_WEEE_num(p_legal_entity_id IN NUMBER,
                                p_org_id          IN NUMBER) RETURN VARCHAR2;
                                
  --------------------------------------------------------------------
  --  name:            get_location_territory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29-Sep-2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495
  --                   return the territory of customer/site/site_use
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29-Sep-2015 Dalit A. Raviv    initial build 
  --------------------------------------------------------------------
  function get_location_territory (p_site_id     in number,
                                   p_site_use_id in number,
                                   p_customer_id in number) return varchar2;                                                                        
                                         
END xxar_utils_pkg;
/
