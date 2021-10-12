CREATE OR REPLACE PACKAGE BODY xxobjt_wf_mail_support AS

  -------------------------------------------------------------
  -- sample_attchment_proc
  -------------------------------------------------------------

  PROCEDURE sample_attchment_proc(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT BLOB,
                                  document_type IN OUT VARCHAR2) IS
    lob_id       NUMBER;
    bdoc         BLOB;
    content_type VARCHAR2(100);
    filename     VARCHAR2(300); -- document_type := 'application/pdf;name=filename.pdf';
  BEGIN
    --set_debug_context('xx_notif_attach_procedure');
    lob_id := to_number(document_id);
  
    -- Obtain the BLOB version of the document
    SELECT file_name, file_content_type, file_data
      INTO filename, content_type, bdoc
      FROM fnd_lobs
     WHERE file_id = lob_id;
    document_type := content_type || ';name=' || filename;
    dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
    
      wf_core.CONTEXT('xxobjt_wf_mail',
                      'xx_notif_attach_procedure',
                      document_id,
                      display_type);
      RAISE;
  END;
  ------------------------------------------------------
  -- get_body_html
  ------------------------------------------------------

  PROCEDURE get_body_html(document_id   IN VARCHAR2,
                          display_type  IN VARCHAR2,
                          document      IN OUT NOCOPY CLOB,
                          document_type IN OUT NOCOPY VARCHAR2) IS
  BEGIN
  
    SELECT t.body_html
      INTO document
      FROM xxobjt_wf_mail_param t
     WHERE t.item_key = document_id;
  
  END;

  -----------------------------------------------                       

  PROCEDURE sample_clob_body(document_id   IN VARCHAR2,
                             display_type  IN VARCHAR2,
                             document      IN OUT CLOB,
                             document_type IN OUT VARCHAR2) IS
    lob_id       NUMBER;
    bdoc         CLOB;
    content_type VARCHAR2(100);
    filename     VARCHAR2(300);
  BEGIN
    document := '<HTML>
<BODY><FONT color=blue face="Courier New">
<P>Hello,</P>
<P>The following stock was sent directly from OBJ IL(OU) to Customer : Otec Gulf 
Fzc
<P>Delivery : 354330 </P>
<TABLE style="COLOR: blue" border=1 cellPadding=5>
  <TBODY>
  <TR>
    <TH>Item</TH>
    <TH>Item Description</TH>
    <TH>Quantity</TH>
    <TH>Initial Pick up date</TH>
    <TH>Order no</TH></TR>
  <TR>
    <TD>OBJ-24000</TD>
    <TD>OBJET30 DESKTOP 3D PRINTER</TD>
    <TD>1</TD>
    <TD>26-DEC-10</TD>
    <TD>123754</TD></TR></TBODY></TABLE>
<P>Good day,</P>
<P>Oracle sys</P></FONT>
<HR>
</HR><FONT color=blue size=-2 face=Verdana>Mail generated on <B>Dec 26 2010</B> 
at <B>12:08:56 PM</B></FONT></TEXT> </BODY></HTML>';
    --  document_type := content_type || ';name=' || filename;
    --     dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
    
      wf_core.CONTEXT('xxobjt_wf_mail',
                      'xx_notif_attach_procedure',
                      document_id,
                      display_type);
      RAISE;
  END;
  ------------------------------------------------
  -- get_header_html
  -----------------------------------------------
  FUNCTION get_header_html(p_logo_location VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
  BEGIN
    IF nvl(upper(p_logo_location), '1') = 'INTERNAL' THEN
    
      fnd_message.set_name('XXOBJT', 'XXOBJT_MAIL_HEADER_INTERNAL');
      fnd_message.set_token('HOST', fnd_web_config.web_server);
    ELSE
      fnd_message.set_name('XXOBJT', 'XXOBJT_MAIL_HEADER');
    END IF;
  
    RETURN fnd_message.get;
  
  END;
  ------------------------------------------------
  -- get_footer_html
  -----------------------------------------------

  FUNCTION get_footer_html RETURN VARCHAR2 IS
  BEGIN
    fnd_message.set_name('XXOBJT', 'XXOBJT_MAIL_FOOTER');
    RETURN fnd_message.get;
  
  END;
END;
/
