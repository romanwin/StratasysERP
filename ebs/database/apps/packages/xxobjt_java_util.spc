CREATE OR REPLACE PACKAGE xxobjt_java_util AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoices_upload   $
  ---------------------------------------------------------------------------
  -- Package: xxap_invoices_upload
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: WF  Send mail
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  16.08.11   yuval tal            Initial Build

  ---------------------------------------------------------------------------
  /*    dbms_java.grant_permission('APPS',
  'SYS:java.io.FilePermission',
  '/UtlFiles/AP/UnMatchInvoices/*',
  'execute');
  
   dbms_java.grant_permission('APPS',
  'SYS:java.io.FilePermission',
  '/UtlFiles/AP/ScanInvoices/*',
  'execute');
  
  */

  FUNCTION exe_host_comd(p_cmd VARCHAR2) RETURN VARCHAR2 AS
    LANGUAGE JAVA NAME 'XXDBJavaUtil.exeHostCMD(java.lang.String) return java.lang.String';

  FUNCTION get_dir_files(p_dir VARCHAR2) RETURN VARCHAR2 AS
    LANGUAGE JAVA NAME 'XXDBJavaUtil.getDirFiles(java.lang.String) return java.lang.String';
END;
/
