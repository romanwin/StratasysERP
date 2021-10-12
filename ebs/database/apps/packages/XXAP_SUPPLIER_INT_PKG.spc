create or replace package XXAP_SUPPLIER_INT_PKG is

  --------------------------------------------------------------------------
  -- Purpose: This Package will Help to interface and update supplier information
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Upload Attribute7 (Supplier Tier)
  ---------------------------------------------------------------------------
  
  
  --------------------------------------------------------------------------
  -- Purpose: This procedure is the main program which will called by concurrent program
  --          
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Upload file & Call Validation and other required processing Logic
  ---------------------------------------------------------------------------     
  PROCEDURE upload_supplier_data(
                        errbuf          OUT VARCHAR2,
                        retcode         OUT VARCHAR2,
                        p_table_name    IN VARCHAR2,
                        p_template_name IN VARCHAR2,
                        p_file_name     IN VARCHAR2,
                        p_directory     IN VARCHAR2
                        ); 

end XXAP_SUPPLIER_INT_PKG;
/