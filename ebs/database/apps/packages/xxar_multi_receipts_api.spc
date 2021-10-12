CREATE OR REPLACE PACKAGE xxar_multi_receipts_api IS

  -- Author  : INNAA
  -- Created : 7/8/2009 12:55:36 PM
  -- Purpose :

  PROCEDURE create_cash (p_currency_code      VARCHAR2,
                         p_amount             NUMBER,
                         p_cc_num             VARCHAR2,
                         p_receipt_date       DATE,
                         p_gl_date            DATE,
                         p_maturity_date      DATE,
                         p_cust_account_id    NUMBER,
                         p_bank_account_id    NUMBER,
                         p_site_use_id        NUMBER,
                         p_reference_num      NUMBER,
                         p_method_id          NUMBER,
                         p_comments           VARCHAR2,
                         p_cash_rcpt_id  OUT  NUMBER,
                         p_return_status OUT  VARCHAR2,
                         p_error_data    OUT  VARCHAR2);

  PROCEDURE apply_cash (p_cash_receipt_id    NUMBER,
                        p_receipt_number     VARCHAR2,
                        p_receipt_date       DATE,
                        p_customer_trx_id    NUMBER,
                        p_trx_number         VARCHAR2,
                        p_amount_applied     NUMBER,
                        p_apply_date         DATE DEFAULT SYSDATE,
                        p_gl_date            DATE DEFAULT SYSDATE,
                        p_return_status OUT  VARCHAR2,
                        p_error_data    OUT  VARCHAR2);

  PROCEDURE reverse_cash (p_reference          NUMBER,
                          p_doc_num            NUMBER,
                          p_rev_gl_date        DATE DEFAULT SYSDATE,
                          p_category_code      VARCHAR2,
                          p_reason_code        VARCHAR2,
                          p_return_status OUT  VARCHAR2,
                          p_error_data    OUT  VARCHAR2);
END xxar_multi_receipts_api;
/

