CREATE OR REPLACE PACKAGE xxobjt_changes_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_CHANGES_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.2 
  --  creation date:   19/11/2012 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        SOX
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  --  1.1  03/12/2012  Dalit A. Raviv    add procedure get_request_message_clob
  --  1.2  07/01/2013  Dalit A. Raviv    add procedure insert_history
  --------------------------------------------------------------------   

  --------------------------------------------------------------------
  --  name:            upload_change_detial
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/11/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE upload_change_detial(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            get_request_message_clob
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/12/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_request_message_clob(document_id   VARCHAR2,
                                     display_type  VARCHAR2,
                                     document      IN OUT NOCOPY CLOB,
                                     document_type IN OUT NOCOPY VARCHAR2);
    
  --------------------------------------------------------------------
  --  name:            insert_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   07/01/2013 
  --------------------------------------------------------------------
  --  purpose :        insert new row to history table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                 
  Procedure insert_history (p_request_id          in  number,
                           	p_change_id           in  number,
                            p_request_status      in  varchar2,
                            p_request_status_date in  date,
                            p_status_changed_by   in  number,
                            p_last_updated_by     in  number,
                            p_errbuf              out varchar2, 
                            p_retcode             out number  ) ;                                  

                         
  /*PROCEDURE get_request_message_test(errbuf  OUT VARCHAR2,
                                     retcode OUT NUMBER ,
                                     --document_id   varchar2,
                                     --display_type  varchar2,
                                     --document      in out nocopy varchar2, -- document := l_message
                                     --document_type in out nocopy varchar2
                                     );*/

END XXOBJT_CHANGES_PKG;
/
