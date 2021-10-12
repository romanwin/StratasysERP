CREATE OR REPLACE PACKAGE xxtas_interface AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxtas_interface   $
  ---------------------------------------------------------------------------
  -- Package: xxtas_interface
  -- Created:
  -- Author  : yuval tal
  --------------------------------------------------------------------------
  -- Perpose: CUST 641 CombTas Interfaces
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.2.2013  yuval tal      Initial Build
  --     1.1  16.6.2013  yuval atl      bugfix 830 Expense Concurrent cannot run in loop : add import_invoices_conc

  /*PROCEDURE submit_daily_rate(p_errbuff OUT VARCHAR2,
                                p_errcode OUT VARCHAR2,
                                p_from_date VARCHAR2);
  */
  PROCEDURE update_last_gl_rate(p_err_code    OUT NUMBER,
		        p_err_message OUT VARCHAR2);

  PROCEDURE submit_combtas_generic(p_errbuff   OUT VARCHAR2,
		           p_errcode   OUT VARCHAR2,
		           p_type      VARCHAR2,
		           p_from_date VARCHAR2,
		           p_group_id  NUMBER);

  PROCEDURE import_invoices_conc(p_err_message    OUT VARCHAR2,
		         p_err_code       OUT NUMBER,
		         p_table_source   VARCHAR2,
		         p_ap_import_flag VARCHAR2);

END;
/
