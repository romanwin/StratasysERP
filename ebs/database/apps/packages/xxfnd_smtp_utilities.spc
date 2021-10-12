CREATE OR REPLACE PACKAGE xxfnd_smtp_utilities AS
  ---------------------------------------------------------------------------
  -- $Header: xxfnd_smtp_utilities 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxfnd_smtp_utilities
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: SMTP Send mail
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  25.8.10    yuval tal       add utl_mail
  ---------------------------------------------------------------------------
  PROCEDURE send_mail(p_sender    IN VARCHAR2 DEFAULT NULL,
                      p_recipient IN VARCHAR2,
                      p_subject   IN VARCHAR2,
                      p_body      IN VARCHAR2,
                      p_from_name IN VARCHAR2);
                      
  PROCEDURE send_mail2(p_sender    IN VARCHAR2 DEFAULT NULL,
                       p_recipient IN VARCHAR2,
                       p_subject   IN VARCHAR2,
                       p_body      IN VARCHAR2,
                       p_cc        VARCHAR2 DEFAULT NULL,
                       p_bcc       VARCHAR2 DEFAULT NULL,
                       p_mime_type VARCHAR2 DEFAULT 'text/html');
                       
  PROCEDURE testmail(fromm VARCHAR2,
                     too   VARCHAR2,
                     sub   VARCHAR2,
                     BODY  VARCHAR2,
                     port  NUMBER);

  PROCEDURE conc_send_mail(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_sender_name IN VARCHAR2,
                           p_recipient   IN VARCHAR2,
                           p_subject     IN VARCHAR2,
                           p_body        IN VARCHAR2);

END xxfnd_smtp_utilities;
/

