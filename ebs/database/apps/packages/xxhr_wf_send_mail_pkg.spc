CREATE OR REPLACE PACKAGE xxhr_wf_send_mail_pkg AUTHID CURRENT_USER IS

  --------------------------------------------------------------------
  --  name:            XXHR_WF_SEND_MAIL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.4 
  --  creation date:   27/01/2011 09:14:43
  --------------------------------------------------------------------
  --  purpose :        HR project - Handle all WF send mail, HTML body 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/01/2011  Dalit A. Raviv    initial build
  --  1.1  23/10/2011  Dalit A. Raviv    add procedure prepare_salary_clob_body
  --  1.2  27/10/2011  Dalit A. Raviv    add procedure prepare_mng_emps_birthday_body
  --  1.3  20/11/2012  yuval tal         modify prepare_position_changed_body 
  --                                     add proc  prepare_position_chg_opr_body
  --  1.4  27/06/2013  Dalit A. Raviv    Handle HR packages and apps_view
  --                                     add AUTHID CURRENT_USER to spec
  --  1.5  20/08/2014  Dalit A. Raviv    add procedure prepare_Interface_body CHG0032233
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:            prepare_salary_clob_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/01/2011
  --------------------------------------------------------------------
  --  purpose:         procedure taht prepare the CLOB string to attach to 
  --                   the mail body that send
  --  In  Params:      p_document_id   - batch_id of log_interface table
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show 
  --                   p_document_type - TEXT/HTML - LOG.HTML  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  PROCEDURE prepare_salary_clob_body(p_document_id   IN VARCHAR2,
                                     p_display_type  IN VARCHAR2,
                                     p_document      IN OUT CLOB,
                                     p_document_type IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            prepare_AD_clob_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/10/2011
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to 
  --                   the mail body that send
  --  In  Params:      p_document_id   - process_mode = 'PREMAIL' 
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show 
  --                   p_document_type - TEXT/HTML - LOG.HTML  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  PROCEDURE prepare_ad_clob_body(p_document_id   IN VARCHAR2,
                                 p_display_type  IN VARCHAR2,
                                 p_document      IN OUT CLOB,
                                 p_document_type IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            prepare_mng_emps_birthday_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/10/2011
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to 
  --                   the mail body that send
  --  In  Params:      p_document_id   - manager id
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show 
  --                   p_document_type - TEXT/HTML - LOG.HTML  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  PROCEDURE prepare_mng_emps_birthday_body(p_document_id   IN VARCHAR2,
                                           p_display_type  IN VARCHAR2,
                                           p_document      IN OUT CLOB,
                                           p_document_type IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            prepare_position_changed_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/02/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to 
  --                   the mail body that send
  --  In  Params:      p_document_id   - send mail code 'P'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show 
  --                   p_document_type - TEXT/HTML - LOG.HTML  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  PROCEDURE prepare_position_changed_body(p_document_id   IN VARCHAR2,
                                          p_display_type  IN VARCHAR2,
                                          p_document      IN OUT CLOB,
                                          p_document_type IN OUT VARCHAR2);

  -- 
  --------------------------------------------------------------------
  --  name:            prepare_position_chg_opr_body
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   20.11.2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --                   CUST482    CR-518  HR  HR  Employee Position Changed -Add old position/ supervisor position  Hierarchy  locations  
  --  In  Params:      p_document_id   - send mail code 'P'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19.11.2012  yuval tal      initial build 
  --                                  CUST482   CR-518  HR  HR  Employee Position Changed -Add old position/ supervisor position  Hierarchy  locations  

  --------------------------------------------------------------------
  PROCEDURE prepare_position_chg_opr_body(p_document_id   IN VARCHAR2,
                                          p_display_type  IN VARCHAR2,
                                          p_document      IN OUT CLOB,
                                          p_document_type IN OUT VARCHAR2);
  
  --------------------------------------------------------------------
  --  name:            prepare_Interface_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/08/2014
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --                   CHG0032233 - Upload HR data into Oracle 
  --  In  Params:      p_document_id   - l_count_e||'|'||l_count_s||'|'||l_total
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/08/2014  Dalit A. Raviv    initial build 
  --                                     CHG0032233 - Upload HR data into Oracle  
  --------------------------------------------------------------------                                        
  procedure prepare_Interface_body (p_document_id   in varchar2,
                                    p_display_type  in varchar2,
                                    p_document      in out clob,
                                    p_document_type in out varchar2);                                          

END xxhr_wf_send_mail_pkg;

 
/
