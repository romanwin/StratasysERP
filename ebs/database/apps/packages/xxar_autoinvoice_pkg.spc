create or replace package xxar_autoinvoice_pkg IS

  --------------------------------------------------------------------
  --  name:              XXAR_AUTOINVOICE_PKG
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     31/08/2009
  --------------------------------------------------------------------
  --  purpose :          Auto invoice modifications
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  31/08/2009    XXX               initial build
  --  1.1  XX/xx/XXxx    Daniel Katz
  --  1.2  28/06/2011    Ofer Suad         add procedure handle_contracts_from_om_trx
  --                                       Update accounting rule and DE tax code for Service contracts from OM
  -- 1.3  13/10/2013      ofer Suad         Changes to support ssys bundle sale orders and new chart of account CR -1122
  -- 1.4 16/02/2014       Ofer Suad        Add Lease contracts logic
  --  3.6  10-Feb-2016   Ofer Suad         CHG0037700-  fix 100% Resin credit accounting
  -- 3.7 18-Aug-2016     yuval tal         CHG0038192  add calculate_avarage_discount
  -- 3.8 10-May-2019     Bellona(TCS)      CHG0045219  add exclude_from_avg_discount
  --------------------------------------------------------------------

  -- Public type declarations
  FUNCTION get_precision(p_currency_code VARCHAR2) RETURN NUMBER;
  PRAGMA RESTRICT_REFERENCES(get_precision, WNDS, WNPS);

  FUNCTION safe_devisor(p_devisor NUMBER) RETURN NUMBER;
  PRAGMA RESTRICT_REFERENCES(get_precision, WNDS, WNPS);

  FUNCTION get_price_list_for_resin(p_line_id    NUMBER,
            p_price_list NUMBER,
            p_attribute4 NUMBER) RETURN NUMBER;
  PRAGMA RESTRICT_REFERENCES(get_precision, WNDS, WNPS);

  FUNCTION get_acc_resin_credit_avg_bal(p_cust_acct_id  NUMBER,
                p_org_id        NUMBER,
                p_currency      VARCHAR2,
                p_pos_amount    NUMBER,
                x_return_status OUT VARCHAR2)
    RETURN NUMBER;

  PROCEDURE process_trx_lines(errbuf                      OUT VARCHAR2,
              retcode                     OUT NUMBER,
              p_num_of_instances          IN VARCHAR2,
              p_organization              NUMBER,
              p_batch_source_id           IN ra_batch_sources.batch_source_id%TYPE,
              p_batch_source_name         IN VARCHAR2,
              p_default_date              IN VARCHAR2 DEFAULT NULL,
              p_trans_flexfield           IN VARCHAR2 DEFAULT NULL,
              p_trx_type_id               IN ra_cust_trx_types.cust_trx_type_id%TYPE DEFAULT NULL,
              p_low_bill_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
              p_high_bill_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
              p_low_bill_to_cust_name     IN hz_parties.party_name%TYPE DEFAULT NULL,
              p_high_bill_to_cust_name    IN hz_parties.party_name%TYPE DEFAULT NULL,
              p_low_gl_date               IN VARCHAR2 DEFAULT NULL,
              p_high_gl_date              IN VARCHAR2 DEFAULT NULL,
              p_low_ship_date             IN VARCHAR2 DEFAULT NULL,
              p_high_ship_date            IN VARCHAR2 DEFAULT NULL,
              p_low_trans_number          IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
              p_high_trans_number         IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
              p_low_sales_order_num       IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
              p_high_sales_order_num      IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
              p_neg_prep_as_credit        IN VARCHAR2, --added by daniel katz on 19-sep-10
              p_low_invoice_date          IN VARCHAR2 DEFAULT NULL,
              p_high_invoice_date         IN VARCHAR2 DEFAULT NULL,
              p_low_ship_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
              p_high_ship_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
              p_low_ship_to_cust_name     IN hz_parties.party_name%TYPE DEFAULT NULL,
              p_high_ship_to_cust_name    IN hz_parties.party_name%TYPE DEFAULT NULL,
              p_base_due_date_on_trx_date IN fnd_lookups.meaning%TYPE DEFAULT NULL,
              p_due_date_adj_days         IN NUMBER DEFAULT NULL);
  FUNCTION is_service_item(p_inventory_item_id NUMBER) RETURN NUMBER;

  --  Ofer Suad - 13/10/2013 - Boundle transactions
  FUNCTION get_price_list_dist(p_line_id    NUMBER,
               p_price_list NUMBER,
               p_attribute4 NUMBER) RETURN NUMBER;

  --Ofer Suad         CHG0037700-  fix 100% Resin credit accounting
  FUNCTION is_resin_credit_item(p_item_id NUMBER) RETURN VARCHAR2;

  ---

  FUNCTION get_item_price(p_line_id NUMBER) RETURN NUMBER;

  -- end  #CHG0038192
  FUNCTION calculate_avarage_discount(pn_header_id    NUMBER,
              pn_order_number NUMBER,
              x_rate          OUT NUMBER,
              x_return_status OUT VARCHAR2,
              x_err_msg       OUT VARCHAR2)
    RETURN NUMBER;
  
---------------------------------------------------------------------------------
--  Ver   When         Who              Descr
--  ----  -----------  ---------------  -----------------------------------------
--  1.0   10-May-2019  Bellona(TCS)     CHG0045219  add exclude_from_avg_discount 
---------------------------------------------------------------------------------
  FUNCTION exclude_from_avg_discount (p_line_id number) return varchar2;
    
END xxar_autoinvoice_pkg;
/