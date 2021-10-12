CREATE OR REPLACE PACKAGE xxgl_ledger_report_pkg IS

   ---------------------------------------------------------------------------
   -- $Header: xxgl_ledger_report_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxgl_ledger_report_pkg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: upload table data for ledger report
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   PROCEDURE calc_openning_balances(in_gl_comb_id          IN NUMBER,
                                    in_period_name         IN VARCHAR2,
                                    p_ledger_id            IN NUMBER,
                                    out_functional_balance OUT NUMBER /*,
                                                                                                                             out_reporting_balance  out number*/);

   PROCEDURE gather_information(errbuf        OUT VARCHAR2,
                                retcode       OUT VARCHAR2,
                                p_from_period IN VARCHAR2,
                                p_to_period   IN VARCHAR2,
                                p_ledger_id   IN NUMBER);

END xxgl_ledger_report_pkg;
/

