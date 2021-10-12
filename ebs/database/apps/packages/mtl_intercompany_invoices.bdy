CREATE OR REPLACE PACKAGE BODY mtl_intercompany_invoices AS
  /* $Header: INVICIVB.pls 120.2 2006/03/29 05:41:10 sbitra noship $ */

  FUNCTION get_transfer_price(i_transaction_id IN NUMBER,
                              i_price_list_id  IN NUMBER,
                              i_sell_ou_id     IN NUMBER,
                              i_ship_ou_id     IN NUMBER,
                              o_currency_code  OUT NOCOPY VARCHAR2,
                              x_return_status  OUT NOCOPY VARCHAR2,
                              x_msg_count      OUT NOCOPY NUMBER,
                              x_msg_data       OUT NOCOPY VARCHAR2,
                              i_order_line_id  IN NUMBER DEFAULT NULL)
    RETURN NUMBER IS
    --Bug 5118727 Added new parameter I_order_line_id to get_transfer_price
  
    --  This function can be replaced by custom code to establish the
    --  transfer price used in intercompany invoicing.  When this
    --  function returns NULL, the transfer pricing algorithm in the base
    --  application code will be used to establish the transfer price.
    --
    --  Otherwise, the returned number coupled with the returned currency
    --  in O_currency_code will be used as the transfer price.
  
  BEGIN
    o_currency_code := NULL;
    x_return_status := fnd_api.g_ret_sts_success;
    x_msg_count     := 0;
    x_msg_data      := NULL;
  
    RETURN(xxpo_advanced_price_pkg.get_transfer_price(i_transaction_id,
                                                      i_price_list_id,
                                                      i_sell_ou_id,
                                                      i_ship_ou_id,
                                                      o_currency_code,
                                                      x_return_status,
                                                      x_msg_count,
                                                      x_msg_data,
                                                      i_order_line_id));
  
    --return(NULL);
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END get_transfer_price;

  PROCEDURE callback(i_event                IN VARCHAR2,
                     i_transaction_id       IN NUMBER,
                     i_report_header_id     IN NUMBER,
                     i_customer_trx_line_id IN NUMBER) IS
  
    --  This procedure defines various callbacks in the intercompany
    --  invoicing programs which can be replaced with custom code to
    --  provide addition and modification to the existing invoice creation
    --  logic.
    --
    --  Valid events are:
    --
    --  RA_INTERFACE_LINES -
    --    after an insert into RA_INTERFACE_LINES in the AR invoice
    --    creation program.  The transaction_id can be used to identify
    --    the row in RA_INTERFACE_LINES using the transaction flex column
    --    INTERFACE_LINE_ATTRIBUTE7.
    --
    --  AP_EXPENSE_REPORT_HEADERS -
    --    after the insert into AP_EXPENSE_REPORT_HEADERS in the AP
    --    invoice creation program.  The report_header_id should be used
    --    to identify the row inserted.
    --
    --  AP_EXPENSE_REPORT_LINES -
    --    after the insert into AP_EXPENSE_REPORT_LINES in the AP invoice
    --    creation program.  The report_header_id along with
    --    customer_trx_line_id, which is mapped to reference_1 column,
    --    should be used to identify the row.
  
  BEGIN
    IF (i_event = 'RA_INTERFACE_LINES') THEN
      NULL;
    ELSIF (i_event = 'AP_EXPENSE_REPORT_HEADERS') THEN
      NULL;
    ELSIF (i_event = 'AP_EXPENSE_REPORT_LINES') THEN
      NULL;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END callback;

END mtl_intercompany_invoices;
/
