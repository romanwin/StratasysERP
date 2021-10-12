create or replace package xxcust_document_submitter_pkg
-- =========================================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------------------
-- Program name                     Creation Date    Original Ver    Created by
-- XXCUST_DOCUMENT_SUBMITTER_PKG      29-Dec-2016      1.0             Saugata
-- -----------------------------------------------------------------------------------------
-- Usage: This will be used as main package for form "Auto Submit Docs" . This is the 
-- package specification.
-- -----------------------------------------------------------------------------------------
-- Description: This is a interface script. This will be used as SFDC to install 
--              base update program.Related to GAP 494. Interface to update IB 
--        from SFDC to Oracle.
-- CR#      : CHG0039163
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------------------
-- Modification History:
-- Modified Date          Version        Done by               Change Description
-- 29-Dec-2016            1.0            Saugata(TCS)           Initial Build: CHG0039163
-- 19-Feb-2017            1.1            Lingaraj.Sarangi(TCS)  Initial Build: CHG0039163
-- =========================================================================================
 AS
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               submit_document_set
  --  create by:          Saugata(TCS)
  --  Revision:           1.0
  --  creation date:      29-Dec-2016 
  --  Purpose :           This is the main procedure                     
  ----------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   29-Dec-2016   Saugata(TCS)     Initial Build: CHG0039163
  ----------------------------------------------------------------------
  PROCEDURE submit_document_set(x_errbuf   OUT VARCHAR2,
		        x_retcode  OUT VARCHAR2,
		        p_set_code IN VARCHAR2,
		        p_org_id   IN NUMBER,
		        p_key      IN VARCHAR2); 
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               get_dyn_sql_value
  --  create by:          Saugata(TCS)
  --  Revision:           1.0
  --  creation date:      29-Dec-2016 
  --  Purpose :           This is the function which support the dynamic sql.
  --  Return Value:       VRACHAR2                             
  ----------------------------------------------------------------------
  --  ver   date          name       desc
  --  1.0   29-Dec-2016     Saugata(TCS)    Initial Build: CHG0039163
  ----------------------------------------------------------------------
  FUNCTION get_dyn_sql_value(p_string IN VARCHAR2,
		     p_key    IN VARCHAR2) RETURN VARCHAR2;
  
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               validate_sql
  --  create by:          Lingaraj Sarangi
  --  Revision:           1.0
  --  creation date:      19/02/2017
  --  Purpose :           Returns TRUE or FALSE Boolean Value
  --                      This Function will verify that is the Dynamic Query is Correct or Nor.
  --                      Function will be called from XXCUSTREPSET.fmb.
  --  Return Value:     BOLLEAN  
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19/02/2017    Lingaraj Sarangi    Initial Build: CHG0039163
  ----------------------------------------------------------------------
  FUNCTION validate_sql(p_query IN VARCHAR2) RETURN BOOLEAN;
                        
END xxcust_document_submitter_pkg;
/