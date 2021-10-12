CREATE OR REPLACE PACKAGE xxhz_gam_site_pkg IS
  --------------------------------------------------------------------
  --  name:            XXHZ_GAM_SITE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        CUST630 - GAM dashboard interface
  --                   There will be an interface between Oracle and GAM site.
  --                   1. A program will run every night and provide data about the GAM/KAM customers. 
  --                   2. It will create XML files of the required data.
  --                   3. The files will be put on a specific directory.
  --                   4. The GAM site developers will connect to that directory and pull the data.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        Handle the main program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE main(errbuf   OUT VARCHAR2,
                 retcode  OUT VARCHAR2,
                 p_entity IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_service_agreement
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        If the result will be 0 then send true else send false
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_service_agreement(p_parent_party_id IN NUMBER,
                                 p_cust_account_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_file_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        get the file name according to subject
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_file_name(p_entity IN VARCHAR2) RETURN VARCHAR2;

END xxhz_gam_site_pkg;
/
