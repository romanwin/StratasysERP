CREATE OR REPLACE PACKAGE XXAR_OPYO_PKG is
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.2   26/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance
  -----------------------------------------------------------------------------------------------------

  C_DIRECTORY     CONSTANT VARCHAR2(300) := 'XXAR_OPYO_DIR';
  C_ARC_DIRECTORY CONSTANT VARCHAR2(300) := 'XXAR_OPYO_ARC_DIR';

  C_STRAT_BUYERS_FILE_NAME   CONSTANT VARCHAR2(300) := 'BUYERS_STRATASYS.csv';
  C_STRAT_INVOICES_FILE_NAME CONSTANT VARCHAR2(300) := 'INVOICES_STRATASYS.csv';
  C_STRAT_RECIEPTS_FILE_NAME CONSTANT VARCHAR2(300) := 'RECEIPTS_STRATASYS.csv';

  C_STRAT_BUYERS_FILE_NAME_ZIP   CONSTANT VARCHAR2(300) := 'BUYERS_STRATASYS.zip';
  C_STRAT_INVOICES_FILE_NAME_ZIP CONSTANT VARCHAR2(300) := 'INVOICES_STRATASYS.zip';
  C_STRAT_RECIEPTS_FILE_NAME_ZIP CONSTANT VARCHAR2(300) := 'RECEIPTS_STRATASYS.zip';

  -------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  --------------------------------------
  -- 1.0   09/09/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2);
  ----------------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  -------------------------------------------------
  -- 1.0   02/09/2020  Roman W.    CHG0048031 - calculation closest conversion rate
  ----------------------------------------------------------------------------------
  function get_closest_conversion_rate(p_date            DATE,
                                       p_from            VARCHAR2,
                                       p_to              VARCHAR2,
                                       p_conversion_type VARCHAR2)
    return DATE;
  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   14/09/2020   Roman W.    CHG0048031- coma delimiter handling in "hl.address1"
  -----------------------------------------------------------------------------------------------------
  function remove_special_char(p_str varchar2) return varchar2;

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_buyers_clob(p_error_code OUT VARCHAR2,
                                  p_error_desc OUT VARCHAR2,
                                  p_clob       OUT CLOB);

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_invoices_clob(p_error_code OUT VARCHAR2,
                                    p_error_desc OUT VARCHAR2,
                                    p_clob       OUT CLOB);

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -----------------------------------------------------------------------------------------------------
  procedure get_strat_reciepts_clob(p_error_code OUT VARCHAR2,
                                    p_error_desc OUT VARCHAR2,
                                    p_clob       OUT CLOB);

  -----------------------------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  -------------------------------------------------------------------
  -- 1.0   12/08/2020   Roman W.    CHG0048031- Daily upload of customer open balances to OPYO BI tool
  -- 1.2   20/10/2020   Roman W.    CHG0048802 - improve invoice file creation performance
  -----------------------------------------------------------------------------------------------------
  procedure extract_files_prog(errbuf         out varchar2,
                               retcode        out varchar2,
                               p_location     in varchar2,
                               p_arc_location in varchar2,
                               p_file_name    in varchar2);

end XXAR_OPYO_PKG;
/
