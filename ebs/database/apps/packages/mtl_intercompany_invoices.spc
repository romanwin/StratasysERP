CREATE OR REPLACE PACKAGE mtl_intercompany_invoices AS
  /* $Header: INVICIVS.pls 120.3 2006/03/29 05:37:21 sbitra noship $ */

  FUNCTION get_transfer_price(i_transaction_id IN NUMBER,
                              i_price_list_id  IN NUMBER,
                              i_sell_ou_id     IN NUMBER,
                              i_ship_ou_id     IN NUMBER,
                              o_currency_code  OUT NOCOPY VARCHAR2,
                              x_return_status  OUT NOCOPY VARCHAR2,
                              x_msg_count      OUT NOCOPY NUMBER,
                              x_msg_data       OUT NOCOPY VARCHAR2,
                              i_order_line_id  IN NUMBER DEFAULT NULL)
    RETURN NUMBER;
  --Bug 5118727 Added new parameter I_order_line_id to get_transfer_price

  PROCEDURE callback(i_event                IN VARCHAR2,
                     i_transaction_id       IN NUMBER,
                     i_report_header_id     IN NUMBER,
                     i_customer_trx_line_id IN NUMBER);

END mtl_intercompany_invoices;
/
