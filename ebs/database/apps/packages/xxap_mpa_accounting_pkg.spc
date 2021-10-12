CREATE OR REPLACE PACKAGE xxap_mpa_accounting_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxap_mpa_accounting_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxap_mpa_accounting_pkg
  -- Created: SHAIEH
  -- Author  : RTLX_CUSTOM_SOURCE - AP MPA accounting setup - package to get default prepaid expenses account
  --------------------------------------------------------------------------
  -- Perpose: Agile procedures
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  03/12/13 Ofer Suad        CR1123 :Cahnge logic of defualt acount to support new COA
  ---------------------------------------------------------------------------
  FUNCTION get_default_prepaid_acct(p_org_id                       IN NUMBER,
                                    p_invoice_distribution_id      IN NUMBER,
                                    p_invoice_distribution_account IN NUMBER)
    RETURN NUMBER;
  --                                   this is the invoice distribution account id
END xxap_mpa_accounting_pkg;
/
