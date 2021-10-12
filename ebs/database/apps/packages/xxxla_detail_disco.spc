CREATE OR REPLACE PACKAGE xxxla_detail_disco IS
--------------------------------------------------------------------
--  name:            XXXLA_DETAIL_DISCO
--  create by:       DANIEL.KATZ
--  Revision:        1.0
--  creation date:   12/19/2010
--------------------------------------------------------------------
--  purpose :        xla details report
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/19/2010  DANIEL.KATZ       initial build
--  1.1  28/10/2014  Ofer Suad         CHG0033589
--                                     XLA Detail Report - add project accounting journal and RECEIVING_SUB_LEDGER data
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            test_upl_detail_data
  --  create by:       DANIEL.KATZ
  --  Revision:        1.0
  --  creation date:   12/19/2010
  --------------------------------------------------------------------
  --  purpose :        xla details report
  --                   procedure to test the data (for all relevant lines in relevant periods by last updated date)
  --                   in the XXXLA_SLA_EXPENSE_DETAILS table and insert the data to relevant lines related to accounting dates.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/19/2010  DANIEL.KATZ       initial build
  --  1.1  28/10/2014  Ofer Suad         CHG0033589
  --                                     XLA Detail Report - add project accounting journal and RECEIVING_SUB_LEDGER data
  -- 1.2   18/01/2015  Ofer Suad         CHG0034238 -  Add set and get Account/Department parents
   
  
  PROCEDURE test_upl_detail_data(errbuf          OUT VARCHAR2,
                                 retcode         OUT NUMBER,
                                 p_ledger_set_id IN NUMBER);

  FUNCTION log_union(p_string VARCHAR2) RETURN NUMBER;
  -- 18/01/2015  Ofer Suad         CHG0034238 -  Add set and get Account/Department parents
  FUNCTION set_account_parent RETURN NUMBER;
  FUNCTION get_account_parent(p_coa_and_child varchar2) RETURN varchar2;
  
  FUNCTION set_dept_parent RETURN NUMBER;
  FUNCTION get_dept_parent(p_coa_and_child varchar2) RETURN varchar2;
  
  FUNCTION get_dept_parent_desc(p_coa_and_child varchar2) RETURN varchar2;
  FUNCTION get_account_parent_desc(p_coa_and_child varchar2) RETURN varchar2;
  
  TYPE parent_accounts IS TABLE OF VARCHAR2(240) INDEX BY VARCHAR2(30);
  TYPE parent_depts IS TABLE OF VARCHAR2(240) INDEX BY VARCHAR2(30); 
  
   TYPE parent_account_desc IS TABLE OF VARCHAR2(240) INDEX BY VARCHAR2(30);
   TYPE parent_dept_desc IS TABLE OF VARCHAR2(240) INDEX BY VARCHAR2(30); 
    
END xxxla_detail_disco;

 
/