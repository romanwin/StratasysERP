CREATE OR REPLACE PACKAGE BODY xxfnd_smtp_utilities AS
--------------------------------------------------------------------
--  name:            xxfnd_smtp_utilities
--  create by:       XXX
--  Revision:        1.0 
--  creation date:   XX/XX/XXXX
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  XX/XX/XXXX  XXX              initial build
--------------------------------------------------------------------   
 
  --------------------------------------------------------------------
  --  name:            send_mail
  --  create by:       XXX 
  --  Revision:        1.0 
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        update full phone number at person EIT - IT
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  XX/XX/XXXX  XXX              initial build
  --  1.1  02/09/2012  Dalit A. Raviv   Mail server where change
  --                                    add profile that will hold the name of the mail server
  --------------------------------------------------------------------  
  PROCEDURE send_mail(p_sender    IN VARCHAR2,
                      p_recipient IN VARCHAR2,
                      p_subject   IN VARCHAR2,
                      p_body      IN VARCHAR2,
                      p_from_name IN VARCHAR2) IS
    mail_subject VARCHAR2(200);
    recipient    VARCHAR2(150);
    sender       VARCHAR2(50);
    --cc_recipient   VARCHAR2(50)  := 'firoz.kaiser@oracle.com';
    --mailhost  VARCHAR2(100) := 'SEPIA.2OBJET.COM';
    -- 1.1 02/09/2012 Dalit A. Raviv
    mailhost  VARCHAR2(100) := fnd_profile.value('XXOBJT_MAIL_SERVER_NAME');
    mail_conn utl_smtp.connection;
    PROCEDURE send_header(NAME IN VARCHAR2, header IN VARCHAR2) AS
    BEGIN
      utl_smtp.write_data(mail_conn,
                          NAME || ': ' || header || utl_tcp.crlf);
    END;
    -- Main Procedure
  BEGIN
    recipient    := p_recipient;
    mail_subject := p_subject;
    sender       := nvl(p_sender, 'OracleApps_NoReply@objet.com'); --p_sender;
    -- Open SMTP Connection
    mail_conn := utl_smtp.open_connection(mailhost);
    utl_smtp.helo(mail_conn, mailhost);
    utl_smtp.mail(mail_conn, sender);
    utl_smtp.rcpt(mail_conn, recipient);
    -- UTL_SMTP.RCPT(mail_conn,'cc:' || cc_recipient );
    utl_smtp.open_data(mail_conn);
    -- Header of Mail
    send_header('MIME-Version', '1.0');
    send_header('Content-type', 'text/html');
    send_header('Date', to_char(SYSDATE, 'dd Mon yy hh24:mi:ss'));
    send_header('From', p_from_name || '<' || sender || '>');
    send_header('To', '"Recipient" <' || recipient || '>');
    --   SEND_HEADER('cc', '"Admin" <' || cc_recipient || '>');
    send_header('Subject', mail_subject);
    -- Body of mail
    utl_smtp.write_data(mail_conn, utl_tcp.crlf || '<text><body>');
    utl_smtp.write_raw_data(mail_conn,
                            utl_raw.cast_to_raw(utl_tcp.crlf ||
                                                '<FONT COLOR="blue"FACE="Courier New">' ||
                                                p_body || '</FONT>'));
    --            UTL_SMTP.WRITE_DATA(mail_conn,UTL_TCP.CRLF  || p_body);
    -- Footer of mail
    utl_smtp.write_data(mail_conn,
                        utl_tcp.crlf ||
                        '<hr></hr><font
			face="Verdana" size=-2 color="blue">Mail generated on <b>' ||
                        to_char(SYSDATE, 'Mon dd yyyy') || '</b> at <b>' ||
                        to_char(SYSDATE, 'hh:mi:ss AM') ||
                        '</b></font></body></text>');
    -- Close SMTP Connection
    utl_smtp.close_data(mail_conn);
    utl_smtp.quit(mail_conn);
    -- Catch Exceptions
  EXCEPTION
    WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
      utl_smtp.quit(mail_conn);
      raise_application_error(-20412,
                              'Failed to send mail due to the following error: ' ||
                              SQLERRM);
  END;
  
  --------------------------------------
  -- send_mail2
  --------------------------------------
  PROCEDURE send_mail2(p_sender    IN VARCHAR2 DEFAULT NULL,
                       p_recipient IN VARCHAR2,
                       p_subject   IN VARCHAR2,
                       p_body      IN VARCHAR2,
                       p_cc        VARCHAR2 DEFAULT NULL,
                       p_bcc       VARCHAR2 DEFAULT NULL,
                       p_mime_type VARCHAR2 DEFAULT 'text/html') IS
  
    l_sender VARCHAR2(50);
    l_body   VARCHAR2(32000);
    l_env    VARCHAR2(50);
  
  BEGIN
  
    SELECT initcap(NAME) INTO l_env FROM v$database;
  
    l_body   := p_body;
    l_sender := nvl(p_sender, 'Oracle' || l_env || '_NoReply@objet.com'); --p_sender;
  
    IF p_mime_type = 'text/html'
    
     THEN
      l_body := l_body ||
                '<hr></hr><font
    face="Verdana" size=-2 color="blue">Mail generated on <b>' ||
                to_char(SYSDATE, 'Mon dd yyyy') || '</b> at <b>' ||
                to_char(SYSDATE, 'hh:mi:ss AM') || '</b></font>';
    END IF;
  
    utl_mail.send(sender     => l_sender,
                  recipients => p_recipient,
                  cc         => p_cc,
                  bcc        => p_bcc,
                  subject    => p_subject,
                  message    => l_body,
                  mime_type  => p_mime_type);
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20412,
                              'Failed to send mail due to the following error: ' ||
                              SQLERRM);
  END;
  ------------------------------------
  PROCEDURE testmail(fromm VARCHAR2,
                     too   VARCHAR2,
                     sub   VARCHAR2,
                     BODY  VARCHAR2,
                     port  NUMBER) IS
    objconnection utl_smtp.connection;
    --vrdata        VARCHAR2(32000);
  BEGIN
    objconnection := utl_smtp.open_connection('172.30.0.4', port);
    utl_smtp.helo(objconnection, 'objet.com');
    utl_smtp.mail(objconnection, fromm);
    utl_smtp.rcpt(objconnection, too);
    utl_smtp.open_data(objconnection);
  
    utl_smtp.write_data(objconnection,
                        'From: ' || '"' || 'Sender' || '" <' ||
                        'EMAIL ADDRESS' || '>' || utl_tcp.crlf);
    utl_smtp.write_data(objconnection,
                        'To: ' || '"' || 'Recipient' || '" <' ||
                        'EMAIL ADDRESS' || '>' || utl_tcp.crlf);
    utl_smtp.write_data(objconnection, 'Subject: ' || sub || utl_tcp.crlf);
    utl_smtp.write_data(objconnection,
                        'MIME-Version: ' || '1.0' || utl_tcp.crlf);
    utl_smtp.write_data(objconnection,
                        'Content-Type: ' || 'text/html; charset=utf-8' ||
                        utl_tcp.crlf);
    utl_smtp.write_data(objconnection,
                        'Content-Transfer-Encoding: ' || '"8Bit"' ||
                        utl_tcp.crlf);
    utl_smtp.write_data(objconnection, utl_tcp.crlf);
    utl_smtp.write_data(objconnection, utl_tcp.crlf || '<HTML>');
    utl_smtp.write_data(objconnection, utl_tcp.crlf || '<BODY>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT COLOR="red" FACE="Courier New">This | is | text | Mail</FONT> <BR>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT COLOR="red" FACE="Courier New">-----------------------</FONT> <BR>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT COLOR="blue" FACE="Courier New">This | is | text | Mail</FONT> <BR>');
    utl_smtp.write_raw_data(objconnection,
                            utl_raw.cast_to_raw(utl_tcp.crlf ||
                                                '<FONT COLOR="red"FACE="Courier New">' || BODY ||
                                                '</FONT>'));
    utl_smtp.write_data(objconnection, utl_tcp.crlf || '<BR>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT size=2 COLOR="blue" FACE="times">This is text Mail</FONT> <BR>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT COLOR="black" FACE="Arial">This is text Mail</FONT> <BR>');
    utl_smtp.write_data(objconnection,
                        utl_tcp.crlf ||
                        '<FONT COLOR="green" FACE="Courier">This is text Mail</FONT><BR>');
    utl_smtp.write_data(objconnection, utl_tcp.crlf || '</BODY>');
    utl_smtp.write_data(objconnection, utl_tcp.crlf || '</HTML>');
    utl_smtp.close_data(objconnection);
    utl_smtp.quit(objconnection);
  EXCEPTION
    WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
      utl_smtp.quit(objconnection);
      dbms_output.put_line(SQLERRM);
    WHEN OTHERS THEN
      utl_smtp.quit(objconnection);
      dbms_output.put_line(SQLERRM);
  END testmail;
  ---------------------
  PROCEDURE conc_send_mail(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_sender_name IN VARCHAR2,
                           p_recipient   IN VARCHAR2,
                           p_subject     IN VARCHAR2,
                           p_body        IN VARCHAR2) IS
  BEGIN
    errbuf  := '';
    retcode := '0';
    send_mail(NULL, p_recipient, p_subject, p_body, p_sender_name);
  END conc_send_mail;

END xxfnd_smtp_utilities;
/
