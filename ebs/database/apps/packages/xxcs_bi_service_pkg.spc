create or replace package XXCS_BI_SERVICE_PKG is

  -- Author  : DMN_ILAN
  -- Created : 9/1/2009 10:41:28 AM
  -- add -- objet function  -- 5-10-2009
  -- Purpose :

  -- Public function and procedure declarations
  function get_param_date_value(P_bi_param_code in varchar2,
                                P_bi_param_sec  in varchar2 DEFAULT null)
    return date;

  function get_param_char_value(P_bi_param_code in varchar2,
                                P_bi_param_sec  in varchar2 DEFAULT NULL)
    return varchar2;

  function get_param_number_value(P_bi_param_code in varchar2,
                                  P_bi_param_sec  varchar2 DEFAULT null)
    return number;

  function get_Curr_ledger_id return number;
  function get_Curr_Currency_code return varchar2;
  -- objet function  -- 5-10-2009

  FUNCTION get_lookup_meaning(p_lookup_type         VARCHAR2,
                              p_lookup_code         VARCHAR2,
                              p_view_application_id number DEFAULT NULL)
    RETURN VARCHAR2;
  PRAGMA RESTRICT_REFERENCES(get_lookup_meaning, WNDS, WNPS);

  FUNCTION get_avail_to_reserve(p_inventory_item_id NUMBER,
                                p_organization_id   NUMBER) RETURN NUMBER;

  FUNCTION get_conversion_rate(p_from_currency VARCHAR2,
                               p_to_currency VARCHAR2,
                               p_conv_date DATE,
                               p_conv_type VARCHAR2 default 'Corporate') RETURN NUMBER;

  FUNCTION get_primary_currency(P_ORG_ID number) RETURN VARCHAR2;

-- end objet function
end XXCS_BI_SERVICE_PKG;
/

