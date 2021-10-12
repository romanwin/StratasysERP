create or replace package XXHR_API_PKG is

  -- Author  : DAN.MELAMED
  -- Created : 1/16/2018 10:00:08 AM
  -- Purpose : Interface between Success Factors (SF) and Oracle HR for Stratasys

  procedure process_employees(p_sourcename      varchar2,
                              p_source_id       varchar2,
                              p_error_code      out varchar2,
                              p_error_message   out varchar2,
                              p_processing_bulk IN OUT xxhr_emp_tab);
  --procedure get_code_comb_id( p_finance_company varchar2, p_company varchar2,  p_finance_dept varchar2, p_finance_account varchar2, p_out_ccid out number, p_out_ledger_id out number);

end XXHR_API_PKG;
/
