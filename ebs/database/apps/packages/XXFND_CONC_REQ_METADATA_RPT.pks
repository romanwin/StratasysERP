CREATE OR REPLACE PACKAGE APPS.xxfnd_conc_req_metadata_rpt AS
---------------------------------------------------------------------------------------
--  name:            xxfnd_conc_req_metadata_rpt
--  create by:       S3 Project
--  Revision:        1.0
--  creation date:   05-APR-2017
--  Object Type :    Package Specification      
---------------------------------------------------------------------------------------
--  purpose :        
---------------------------------------------------------------------------------------
--  ver  date          name                 desc
--  1.0                S3 Project           initial build - Created During S3 Project
--  1.1  05-APR-2017   Lingaraj Sarangi     Finilizing Deployment on 12.1.3
---------------------------------------------------------------------------------------
  
   /* Constants*/
    c_output_header CONSTANT VARCHAR2(200) :=  '***Beginning of Output: ';
    c_output_footer CONSTANT VARCHAR2(200) :=  '***End of Output: ';
    
    /* Debug Constants*/
    c_debug_level NUMBER := 10;  --0: Off, 10: On, 
    
    /* Paramaters defined for Concurrent Request */
    P_CONCURRENT_REQUEST_ID NUMBER;

    FUNCTION f_conc_req_hdr_md (
      p_concurent_request_id IN NUMBER
    ) RETURN APPS.XXFND_CR_MD_HDR_TABLE_TYPE;
    
    FUNCTION f_conc_req_param_md (
      p_concurent_request_id IN NUMBER
    ) RETURN APPS.XXFND_CR_MD_PARAM_TABLE_TYPE;

END xxfnd_conc_req_metadata_rpt;
/
