CREATE OR REPLACE PACKAGE xxconv_install_base_pkg IS
--------------------------------------------------------------------
--  name:            XXCONV_INSTALL_BASE_PKG
--  create by:       XXX
--  Revision:        1.0
--  creation date:   XX.XX.XXXX
--------------------------------------------------------------------
--  purpose :        Handle all conversions for Install Base
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  XX.XX.XXXX  XXX               initial build
--  1.1  22/08/2012  Dalit A. raviv    add procedure Update_SW_version
--------------------------------------------------------------------
   PROCEDURE create_instance(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
   
   PROCEDURE upload_associations_employees(errbuf         Out Varchar2,
                                           errcode        Out Varchar2,
                                           p_location     In Varchar2,
                                           p_filename     In Varchar2,
                                           p_ignore_first_headers_line  In Varchar2 DEFAULT 'N',
                                           p_validate_only_flag         In Varchar2);
                                           
   FUNCTION get_field_from_utl_file_line(p_line_str      IN VARCHAR2,  
                                         p_field_number  IN NUMBER) RETURN VARCHAR2;
                                         
  --------------------------------------------------------------------
  --  name:            Update_SW_version
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/08/2012
  --------------------------------------------------------------------
  --  purpose :        Handle conversions of SW_versions values at Install Base
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/08/2012  Dalit A. raviv    initial build
  --------------------------------------------------------------------
  procedure Update_SW_version  (errbuf         out varchar2,
                                retcode        out varchar2,
                                p_location     in  varchar2,  -- /UtlFiles/HR
                                p_filename     in  varchar2) ;
                                                                     
END xxconv_install_base_pkg;
/
