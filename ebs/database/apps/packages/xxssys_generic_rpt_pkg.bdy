CREATE OR REPLACE PACKAGE BODY xxssys_generic_rpt_pkg AS

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

g_log         VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
g_log_module  VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE write_log(p_msg  VARCHAR2)
   IS 
   BEGIN
      IF g_log = 'Y' AND 'xxssys.generic_rpt.xxssys_generic_rpt_pkg' LIKE LOWER(g_log_module) THEN
        fnd_log.STRING(
          log_level => fnd_log.LEVEL_UNEXPECTED,
          module    => 'xxssys.generic_rpt.xxssys_generic_rpt_pkg',
          message   => p_msg);
      END IF;
   END write_log;  

-- ---------------------------------------------------------------------------------------------
-- Name: before_report
-- --------------------------------------------------------------------------------------------
-- Purpose: Before report trigger for the XXOBJ_GENERIC_RPT.xml data template.  Lexical parameters
--          are used so components can be dynamic.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------   
  FUNCTION before_report
  RETURN BOOLEAN
  IS 
  BEGIN
    write_log('Begin before_report');
    write_log('p_purge_table_flag: '||p_purge_table_flag);
    
    P_REPORT_TITLE_LEX  := P_REPORT_TITLE;
    P_EMAIL_SUBJECT_LEX := P_EMAIL_SUBJECT;
    P_FILE_NAME_LEX     := P_FILE_NAME;
    P_EMAIL_BODY        := P_EMAIL_BODY1||P_EMAIL_BODY2||P_EMAIL_SIGNATURE;
    P_REPORT_PRE_TEXT   := P_REPORT_PRE_TEXT1||P_REPORT_PRE_TEXT2;
    P_REPORT_POST_TEXT  := P_REPORT_POST_TEXT1||P_REPORT_POST_TEXT2;
    P_ORDER_BY_LEX      := P_ORDER_BY;
    
    write_log('P_ORDER_BY: '||P_ORDER_BY_LEX);
    
    write_log('End before_report');
    RETURN TRUE;
  EXCEPTION 
    WHEN OTHERS THEN 
      write_log('Unexpected error occurred in before_report: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      RETURN FALSE;
  END before_report;

-- ---------------------------------------------------------------------------------------------
-- Name: after_report
-- --------------------------------------------------------------------------------------------
-- Purpose: After report trigger for the XXOBJ_GENERIC_RPT.xml data template.  
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------   
  FUNCTION after_report
  RETURN BOOLEAN
  IS
  BEGIN
    write_log('Begin after_report');
    write_log('p_purge_table_flag: '||p_purge_table_flag);
    
    IF p_purge_table_flag = 'Y' THEN
      DELETE FROM xxssys_generic_rpt
      WHERE request_id = p_request_id;
      write_log('Deleted '||SQL%ROWCOUNT||' rows from xxssys_generic_rpt.');  
    END IF;
    
    RETURN TRUE;
  EXCEPTION 
    WHEN OTHERS THEN 
      write_log('Unexpected error occurred in after_report: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      RETURN FALSE;
  END after_report;

-- ---------------------------------------------------------------------------------------------
-- Name: submit request
-- --------------------------------------------------------------------------------------------
-- Purpose: Inserts data into the xxssys_generic_rpt table, which is used for reporting.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------   
  PROCEDURE ins_xxssys_generic_rpt(
    p_xxssys_generic_rpt_rec  IN  xxssys_generic_rpt%ROWTYPE,
    x_return_status           OUT VARCHAR2,
    x_return_message          OUT VARCHAR2
  )
  IS PRAGMA AUTONOMOUS_TRANSACTION;
    l_request_id  NUMBER;
    l_dummy       VARCHAR2(1);
    e_error       EXCEPTION;
  BEGIN
    write_log('ins_xxssys_generic_rpt');

    -- Verify that a header row exists for the request_id.  This determines the column headers on the report.
    IF p_xxssys_generic_rpt_rec.header_row_flag <> 'Y' THEN
      BEGIN
        SELECT 'Y'
        INTO l_dummy
        FROM xxssys_generic_rpt
        WHERE header_row_flag = 'Y'
        AND   request_id      = p_xxssys_generic_rpt_rec.request_id;
        
      EXCEPTION 
        WHEN TOO_MANY_ROWS THEN
          x_return_message := 'Error: Only one header row can exist per request_id';
          RAISE e_error;
        WHEN NO_DATA_FOUND THEN
          x_return_message := 'Error: There must be one header row per request_id';
          RAISE e_error;
        WHEN OTHERS THEN  
          x_return_message := 'Unexpected Error searching for header row: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
          RAISE e_error;
      END;
    END IF;
    
    INSERT INTO xxssys_generic_rpt(
      request_id,
      header_row_flag,
      email_to,
      email_subject,
      email_body,
      col1,
      col2,
      col3,
      col4,
      col5, 
      col6,
      col7,
      col8,
      col_msg
    )
    VALUES(                                               
      p_xxssys_generic_rpt_rec.request_id,
      p_xxssys_generic_rpt_rec.header_row_flag,
      p_xxssys_generic_rpt_rec.email_to,
      p_xxssys_generic_rpt_rec.email_subject,
      p_xxssys_generic_rpt_rec.email_body,
      p_xxssys_generic_rpt_rec.col1,
      p_xxssys_generic_rpt_rec.col2,
      p_xxssys_generic_rpt_rec.col3,
      p_xxssys_generic_rpt_rec.col4,
      p_xxssys_generic_rpt_rec.col5,
      p_xxssys_generic_rpt_rec.col6,
      p_xxssys_generic_rpt_rec.col7,
      p_xxssys_generic_rpt_rec.col8,
      p_xxssys_generic_rpt_rec.col_msg
    );
    
    COMMIT;
    
    x_return_status := 'S';
    write_log('End ins_xxssys_generic_rpt');
  EXCEPTION
    WHEN e_error THEN    
      x_return_status := 'E';
    WHEN OTHERS THEN
      x_return_status   := 'E';
      x_return_message  := 'Unexpected error occurred in ins_xxssys_generic_rpt: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
  END ins_xxssys_generic_rpt;  

-- ---------------------------------------------------------------------------------------------
-- Name: wait_for_request
-- --------------------------------------------------------------------------------------------
-- Purpose: Wrapper procedure for fnd_concurrent.wait_for_request.  This forces the 
--          calling request to wait for the p_request_id to finish before it can finish.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------   
  PROCEDURE wait_for_request(
    p_request_id      IN NUMBER,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2)
  IS
    l_phase             VARCHAR2(240); 
    l_status            VARCHAR2(240); 
    l_request_phase     VARCHAR2(240); 
    l_request_status    VARCHAR2(240); 
    l_finished          BOOLEAN;   
    l_message           VARCHAR2(240);
  BEGIN 
    write_log('Calling fnd_concurrent.wait_for_request for request_id '||p_request_id);

    -- Wait for request to complete
    l_finished := fnd_concurrent.wait_for_request(
      request_id => p_request_id,                             
      interval   => 0,                             
      max_wait   => 0,                             
      phase      => l_phase,                             
      status     => l_status,                             
      dev_phase  => l_request_phase,                             
      dev_status => l_request_status,                             
      message    => l_message
    );

    IF NOT l_finished THEN
      x_return_status := 'E';
    END IF;
    
    IF ( UPPER(l_request_status) <> 'NORMAL') THEN 
      write_log('Request ID '||p_request_id
                  ||' returned with a satus of '||l_request_status); 
      x_return_status := 'E';
    ELSE
      x_return_status := 'S';
    END IF; 
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'fnd_concurrent.wait_for_request errored with '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      x_return_status  := 'E';
  END wait_for_request; 
  
-- ---------------------------------------------------------------------------------------------
-- Name: submit_request
-- --------------------------------------------------------------------------------------------
-- Purpose: Submits the 'XX: Objet Generic Report' program and burst it if necessary.  Program 
--          will wait for concurrent requests to complete, then return error condition to the 
--          calling program, if an error occurs.
--          
-- Parameters:
--          p_burst_flag
--            Y/N parameter which determines if the report should be bursted 
--          p_request_id
--            This is the request_id from the calling program. 
--          p_l_report_title 
--            Determines report title on generic report rtf
--          p_l_report_pre_text1 
--            Text before detail section on report rtf
--          p_l_report_pre_text2 
--            Continuation of p_l_report_pre_text1
--          p_l_report_post_text1
--            Text after detail section on report rtf
--          p_l_report_post_text2
--            Continuation of p_l_report_post_text1
--          p_l_email_subject
--            If report is bursted, this determines subject of email
--          p_l_email_body1   
--            If report is bursted, this determines body of email
--          p_l_email_body2   
--            Continuation of p_email_body1
--          p_l_email_signature   
--            Continuation of p_email_body2
--          p_l_order_by
--            Determines how XXSSYS_GENERIC_RPT data template should sort detail data
--          p_l_file_name    
--            If report is bursted, this determines the attachment name
--          p_l_key_col
--            If report is bursted, this dtermines what the key field is for bursting
--          p_l_purge_table  
--            This determines if we want to Purge our records from the XXSSYS_GENERIC_RPT table, after reporting.
--          p_l_template_code 
--            This is the code of the XML Template we want to use for reporting 
--          p_l_template_appl_code      
--            Application code of the XML Template.  
--          p_l_template_output_format
--            Default output of XML Template.  
--          p_l_template_language 
--            Language of the XML Template 
--          p_l_template_territory     
--            Territory code of the XML Template 
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/01/2014  MMAZANET    Initial Creation for CHG0032431.
-- ---------------------------------------------------------------------------------------------   
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
  ) 
  IS PRAGMA AUTONOMOUS_TRANSACTION;
    l_request_id              NUMBER;
    l_burst_request_id        NUMBER;
    l_add_layout              BOOLEAN;
    l_return_status           VARCHAR2(1);
    
    l_template_code           xdo_templates_b.template_code%TYPE          := p_l_template_code;
    l_template_appl_code      xdo_templates_b.application_short_name%TYPE := p_l_template_appl_code;
    l_template_output_format  xdo_templates_b.default_output_type%TYPE    := p_l_template_output_format;
    l_template_language       xdo_templates_b.default_language%TYPE       := p_l_template_language;
    l_template_territory      xdo_templates_b.default_territory%TYPE      := p_l_template_territory;
    e_error                   EXCEPTION;
  BEGIN
    write_log('Begin submit_request');
    
    -- Set defaults
    IF l_template_code IS NULL THEN
      l_template_code := 'XXSSYS_GENERIC_RPT';
    END IF;
    
    IF l_template_appl_code IS NULL THEN
      l_template_appl_code := 'XXOBJT';
    END IF;
    
    IF l_template_output_format IS NULL THEN
      l_template_output_format := 'excel';
    END IF;

    IF l_template_language IS NULL THEN
      l_template_language := 'en';
    END IF;
    
    IF l_template_territory IS NULL THEN
      l_template_territory := 'US';
    END IF;    
    
    
    write_log('l_template_code          : '||l_template_code);
    write_log('l_template_appl_code     : '||l_template_appl_code);
    write_log('l_template_output_format : '||l_template_output_format);
    
    -- Add layout for XML Publisher Report
    IF fnd_request.add_layout (
                        template_appl_name   => l_template_appl_code,
                        template_code        => l_template_code,
                        template_language    => l_template_language, 
                        template_territory   => l_template_territory, 
                        output_format        => UPPER(l_template_output_format)
                     ) 
    THEN
      NULL;
    ELSE 
      x_return_message := 'Error: Template layout could not be added';
      RAISE e_error;
    END IF;
    
    -- Submit request for XXSSYS_GENERIC_RPT XML Publisher Report
    l_request_id := fnd_request.submit_request( 
      application         => 'XXOBJT',             
      program             => 'XXSSYS_GENERIC_RPT', 
      description         => '',                   
      start_time          => '',                   
      sub_request         => FALSE,                
      argument1           => TO_CHAR(p_request_id),
      argument2           => p_l_report_title,    
      argument3           => p_l_report_pre_text1,  
      argument4           => p_l_report_pre_text2,  
      argument5           => p_l_report_post_text1, 
      argument6           => p_l_report_post_text2, 
      argument7           => p_l_email_subject,   
      argument8           => p_l_email_body1,     
      argument9           => p_l_email_body2,     
      argument10          => p_l_email_signature,
      argument11          => p_l_order_by,
      argument12          => p_l_file_name,       
      argument13          => p_l_key_column,      
      argument14          => p_l_purge_table_flag,
      argument15          => l_template_appl_code,
      argument16          => l_template_code,
      argument17          => l_template_output_format,
      argument18          => l_template_language,
      argument19          => l_template_territory
    );
    
    COMMIT;
    write_log('l_request_id: '||l_request_id);  
    IF l_request_id = 0 THEN
      x_return_message  := 'Failed to submit request for reporting';
      RAISE e_error;
    END IF;
    
    -- Wait for XXSSYS_GENERIC_RPT request to complete and check status
    wait_for_request(
      p_request_id     => l_request_id,
      x_return_status  => l_return_status,
      x_return_message => x_return_message
    );
          
    IF l_return_status = 'E' THEN
      x_return_message  := 'Request for reporting failed.  See request_id '||l_request_id||' output for details.';
      RAISE e_error;
    END IF;
    
    -- Handle Bursting
    IF p_burst_flag = 'Y' THEN
      l_burst_request_id := fnd_request.submit_request(
        application         => 'XDO',
        program             => 'XDOBURSTREP',
        description         => NULL,
        start_time          => NULL,
        sub_request         => FALSE,
        argument1           => 'N',
        argument2           => l_request_id,
        argument3           => 'Y'
      );
      
      COMMIT;
      write_log('l_request_id: '||l_burst_request_id);  
      IF l_burst_request_id = 0 THEN
        x_return_message  := 'Failed to burst request';
        RAISE e_error;
      END IF;

      -- Wait for bursting request to complete and check status
      wait_for_request(
        p_request_id     => l_burst_request_id,
        x_return_status  => l_return_status,
        x_return_message => x_return_message
      );
      
      IF l_return_status = 'E' THEN
        x_return_message  := 'Request for bursting failed.  See l_burst_request_id '||l_request_id||' output for details.';
        RAISE e_error;
      END IF;
      
    END IF;

    x_return_status := 'S';
    write_log('End submit_request');
  EXCEPTION
    WHEN e_error THEN    
      x_return_status := 'E';    
    WHEN OTHERS THEN
      x_return_status   := 'E';
      x_return_message  := 'Unexpected error occurred in submit_request: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
  END submit_request;  

  --------------------------------------------------------------------------
  -- main
  --------------------------------------------------------------------------
  -- Perpose: wrapper function for submit_request
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ------------------------------------
  -- 1.1      25.11.14  mmazanet        Initial creation for CHG0032431.
  --------------------------------------------------------------------------
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
  ) 
  IS 
    l_return_status    VARCHAR2(1);
    l_return_message   VARCHAR2(500);
  BEGIN
    submit_request(
      p_burst_flag                =>  p_burst_flag,
      p_request_id                =>  p_request_id,
      p_l_report_title            =>  p_l_report_title,
      p_l_report_pre_text1        =>  p_l_report_pre_text1,
      p_l_report_pre_text2        =>  p_l_report_pre_text2,
      p_l_report_post_text1       =>  p_l_report_post_text1,
      p_l_report_post_text2       =>  p_l_report_post_text2,  
      p_l_email_subject           =>  p_l_email_subject,
      p_l_email_body1             =>  p_l_email_body1,
      p_l_email_body2             =>  p_l_email_body2,
      p_l_email_signature         =>  p_l_email_signature,
      p_l_order_by                =>  p_l_order_by,
      p_l_file_name               =>  p_l_file_name,  
      p_l_key_column              =>  p_l_key_column,  
      p_l_purge_table_flag        =>  p_l_purge_table_flag,
      p_l_template_code           =>  p_l_template_code,       
      p_l_template_appl_code      =>  p_l_template_appl_code,
      p_l_template_output_format  =>  p_l_template_output_format, 
      p_l_template_language       =>  p_l_template_language,
      p_l_template_territory      =>  p_l_template_territory,   
      x_return_status             =>  l_return_status,
      x_return_message            =>  l_return_message
    );
    
    IF l_return_status <> 'S' THEN
      retcode := 2;
      errbuff := 'Error: '||l_return_message; 
    ELSE
      fnd_file.put_line(fnd_file.output,'Report successfully Submitted.');
    END IF;
      
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuff := 'Error: '||DBMS_UTILITY.FORMAT_ERROR_STACK; 
  END main;

  --------------------------------------------------------------------------
  -- clean_xxssys_generic_rpt
  --------------------------------------------------------------------------
  -- Perpose: Program to clear out records from xxssys_generic_rpt.  Ideally
  --          this would be done in the after_report trigger of the 
  --          XXSSYS_GENERIC_RPT XML Publisher data template, but users can
  --          opt not to delete from the table at that point.
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ------------------------------------
  -- 1.1      25.11.14  mmazanet        Initial creation for CHG0032431.
  --------------------------------------------------------------------------
  PROCEDURE clean_xxssys_generic_rpt( 
    errbuff       OUT VARCHAR2, 
    retcode       OUT VARCHAR2,
    p_request_id  IN  NUMBER)
  IS
  BEGIN
    -- 99 means truncate table.
    IF p_request_id = 99 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxssys_generic_rpt';
      fnd_file.put_line(fnd_file.output,'All Records successfully deleted from xxssys_generic_rpt');
    ELSE
      DELETE FROM xxssys_generic_rpt
      WHERE request_id = p_request_id;
      fnd_file.put_line(fnd_file.output,SQL%ROWCOUNT||' Records successfully deleted from xxssys_generic_rpt');
    END IF;
  EXCEPTION 
    WHEN OTHERS THEN 
      retcode := 2;
      fnd_file.put_line(fnd_file.output,'Unexpected error occurred in submit_request: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END clean_xxssys_generic_rpt;

END xxssys_generic_rpt_pkg;

/
SHOW ERRORS