CREATE OR REPLACE PACKAGE xxom_sf2oa_interface AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxom_sf2oa_interface   $
  ---------------------------------------------------------------------------
  -- Package: xxom_sf2oa_interface
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: interface between Syss salsforce and oracle apps
  -- CUST   515
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0   29.7.12    yuval tal     Initial Build
  --     1.3  03.02.13 yuval tal        CR662 : add new fields : UOM line level , Shipping_Comments, User_Email in header level
  --                                    remove time from maintanance date format in
  --     1.4  15.09.13 yuval tal        CR1028 :
  --                                    1. fix cursor c_account (remove OU restrict)
  --                                    2. support new fields  p_accounting_rule_id     p_service_start_date,p_service_end_date
  --                                       add parameters to insert_line, modify create_order
  --     16.01.14   yuval tal           CR1238 : modify proc insert _header, insert_line, create_order
  -- insert_header

  PROCEDURE insert_header(p_auth_string            VARCHAR2,
                          p_operation              VARCHAR2,
                          p_ordered_date           VARCHAR2,
                          p_organization_code      VARCHAR2,
                          p_cust_account_number    VARCHAR2,
                          p_shipping_site_num      VARCHAR2,
                          p_invoice_site_num       VARCHAR2,
                          p_cust_po                VARCHAR2,
                          p_orig_sys_document_ref  VARCHAR2,
                          p_ship_to_contact_num    VARCHAR2,
                          p_invoice_to_contact_num VARCHAR2,
                          p_shipping_method_code   VARCHAR2,
                          p_freight_terms_code     VARCHAR2,
                          p_currency_code          VARCHAR2,
                          p_bpel_instance_id       NUMBER,
                          p_shipping_comments      VARCHAR2,
                          p_email                  VARCHAR2,
                          p_salesrep_id            NUMBER,
                          p_attribute10            VARCHAR2,
                          p_price_list_id          NUMBER,
                          p_org_id                 NUMBER,
                          p_err_code               OUT NUMBER,
                          p_err_message            OUT VARCHAR2,
                          p_interface_header_id    OUT NUMBER);

  FUNCTION get_order_type_name(p_order_type_id NUMBER) RETURN VARCHAR2;
  PROCEDURE insert_line(p_interface_header_id    NUMBER,
                        p_line_number            VARCHAR2,
                        p_ordered_item           VARCHAR2,
                        p_ordered_quantity       VARCHAR2,
                        p_return_reason_code     VARCHAR2,
                        p_unit_selling_price     VARCHAR2,
                        p_maintenance_start_date VARCHAR2,
                        p_maintenance_end_date   VARCHAR2,
                        p_serial_number          VARCHAR2,
                        p_source_type_code       VARCHAR2,
                        p_organization_code      VARCHAR2,
                        p_uom                    VARCHAR2,
                        p_accounting_rule_id     VARCHAR2,
                        p_service_start_date     VARCHAR2,
                        p_service_end_date       VARCHAR2,
                        p_reference_header_id    NUMBER,
                        p_reference_line_id      NUMBER,
                        p_err_code               OUT NUMBER,
                        p_err_message            OUT VARCHAR2);

  PROCEDURE create_order(p_header_seq      NUMBER,
                         p_err_code        OUT VARCHAR2,
                         p_err_message     OUT VARCHAR2,
                         p_order_number    OUT NUMBER,
                         p_order_header_id OUT NUMBER,
                         p_order_status    OUT VARCHAR2);

  PROCEDURE get_order_type_details(p_org_id           NUMBER,
                                   p_operation        NUMBER,
                                   p_order_type_id    OUT NUMBER,
                                   p_pos_line_type_id OUT NUMBER,
                                   p_neg_line_type_id OUT NUMBER,
                                   p_resp_id          OUT NUMBER);

  PROCEDURE create_order_api(p_org_id     NUMBER,
                             p_user_id    NUMBER,
                             p_resp_id    NUMBER,
                             p_appl_id    NUMBER,
                             p_header_rec oe_order_pub.header_rec_type,
                             p_line_tbl   oe_order_pub.line_tbl_type,
                             --   p_line_adj_tbl_type oe_order_pub.line_adj_tbl_type,
                             p_order_number OUT NUMBER,
                             p_header_id    OUT NUMBER,
                             p_order_status OUT VARCHAR2,
                             p_err_code     OUT VARCHAR2,
                             p_err_message  OUT VARCHAR2);

END;
/
