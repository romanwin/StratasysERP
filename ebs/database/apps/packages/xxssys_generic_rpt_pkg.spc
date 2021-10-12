CREATE OR REPLACE PACKAGE xxssys_generic_rpt_pkg AS

-- ---------------------------------------------------------------------------------------------
-- Name: xxssys_generic_rpt_pkg
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used by the XXOBJ_GENERIC_RPT.xml data template.  It is also used
--          to submit the 'XX: Objet Generic Report' program and burst it if necessary.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------

  -- Parameters for XXOBJ_GENERIC_RPT.xml data template
  p_request_id                NUMBER;
  p_report_title              VARCHAR2(240);
  p_report_title_lex          VARCHAR2(240);
  p_report_pre_text1          VARCHAR2(240);
  p_report_pre_text2          VARCHAR2(240);
  p_report_post_text1         VARCHAR2(240);
  p_report_post_text2         VARCHAR2(240);
  p_email_subject             VARCHAR2(240);
  p_email_subject_lex         VARCHAR2(240);
  p_email_body1               VARCHAR2(240);
  p_email_body2               VARCHAR2(240);
  p_email_signature           VARCHAR2(240);
  p_order_by                  VARCHAR2(500);
  p_order_by_lex              VARCHAR2(500);  
  p_file_name                 VARCHAR2(30);
  p_file_name_lex             VARCHAR2(30);
  p_key_column                VARCHAR2(30);
  p_purge_table_flag          VARCHAR2(1) DEFAULT 'Y';  
  p_template_appl_code        xdo_templates_b.application_short_name%TYPE;
  p_template_code             xdo_templates_b.template_code%TYPE;
  p_template_output_format    xdo_templates_b.default_output_type%TYPE; 
  p_template_language         xdo_templates_b.default_language%TYPE; 
  p_template_territory        xdo_templates_b.default_territory%TYPE; 
  p_email_body                VARCHAR2(1000);
  p_report_pre_text           VARCHAR2(1000);
  p_report_post_text          VARCHAR2(1000);

  FUNCTION before_report
  RETURN BOOLEAN;
 
  FUNCTION after_report
  RETURN BOOLEAN;

  PROCEDURE ins_xxssys_generic_rpt(
    p_xxssys_generic_rpt_rec  IN  xxssys_generic_rpt%ROWTYPE,
    x_return_status           OUT VARCHAR2,
    x_return_message          OUT VARCHAR2
  );

  PROCEDURE wait_for_request(
    p_request_id      IN NUMBER,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2
  );
  
  PROCEDURE submit_request(
    p_burst_flag                IN VARCHAR2 DEFAULT 'Y',
    p_request_id                IN NUMBER,
    p_l_report_title            IN VARCHAR2 DEFAULT NULL,
    p_l_report_pre_text1        IN VARCHAR2 DEFAULT NULL,
    p_l_report_pre_text2        IN VARCHAR2 DEFAULT NULL,
    p_l_report_post_text1       IN VARCHAR2 DEFAULT NULL,
    p_l_report_post_text2       IN VARCHAR2 DEFAULT NULL,
    p_l_email_subject           IN VARCHAR2 DEFAULT NULL,
    p_l_email_body1             IN VARCHAR2 DEFAULT NULL,
    p_l_email_body2             IN VARCHAR2 DEFAULT NULL,
    p_l_email_signature         IN VARCHAR2 DEFAULT NULL,
    p_l_order_by                IN VARCHAR2 DEFAULT NULL,
    p_l_file_name               IN VARCHAR2 DEFAULT NULL,    
    p_l_key_column              IN VARCHAR2 DEFAULT NULL,    
    p_l_purge_table_flag        IN VARCHAR2 DEFAULT 'Y',
    p_l_template_code           IN xdo_templates_b.template_code%TYPE           DEFAULT NULL,         
    p_l_template_appl_code      IN xdo_templates_b.application_short_name%TYPE  DEFAULT NULL,
    p_l_template_output_format  IN xdo_templates_b.default_output_type%TYPE     DEFAULT NULL,
    p_l_template_language       IN xdo_templates_b.default_language%TYPE        DEFAULT NULL, 
    p_l_template_territory      IN xdo_templates_b.default_territory%TYPE       DEFAULT NULL,    
    x_return_status             OUT VARCHAR2,
    x_return_message            OUT VARCHAR2
  );  

  PROCEDURE main(
    errbuff                     OUT VARCHAR2, 
    retcode                     OUT VARCHAR2,                    
    p_burst_flag                IN VARCHAR2 DEFAULT 'Y',
    p_request_id                IN NUMBER,
    p_l_report_title            IN VARCHAR2 DEFAULT NULL,
    p_l_report_pre_text1        IN VARCHAR2 DEFAULT NULL,
    p_l_report_pre_text2        IN VARCHAR2 DEFAULT NULL,
    p_l_report_post_text1       IN VARCHAR2 DEFAULT NULL,
    p_l_report_post_text2       IN VARCHAR2 DEFAULT NULL,    
    p_l_email_subject           IN VARCHAR2 DEFAULT NULL,
    p_l_email_body1             IN VARCHAR2 DEFAULT NULL,
    p_l_email_body2             IN VARCHAR2 DEFAULT NULL,
    p_l_email_signature         IN VARCHAR2 DEFAULT NULL,
    p_l_order_by                IN VARCHAR2 DEFAULT NULL,
    p_l_file_name               IN VARCHAR2 DEFAULT NULL,    
    p_l_key_column              IN VARCHAR2 DEFAULT NULL,    
    p_l_purge_table_flag        IN VARCHAR2 DEFAULT 'Y',
    p_l_template_code           IN xdo_templates_b.template_code%TYPE           DEFAULT NULL,         
    p_l_template_appl_code      IN xdo_templates_b.application_short_name%TYPE  DEFAULT NULL,
    p_l_template_output_format  IN xdo_templates_b.default_output_type%TYPE     DEFAULT NULL,   
    p_l_template_language       IN xdo_templates_b.default_language%TYPE        DEFAULT NULL, 
    p_l_template_territory      IN xdo_templates_b.default_territory%TYPE       DEFAULT NULL     
  ); 

  PROCEDURE clean_xxssys_generic_rpt( 
    errbuff       OUT VARCHAR2, 
    retcode       OUT VARCHAR2,
    p_request_id  IN  NUMBER
  );
  
END xxssys_generic_rpt_pkg;

/
SHOW ERRORS
