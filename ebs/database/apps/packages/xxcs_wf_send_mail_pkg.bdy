create or replace package body xxcs_wf_send_mail_pkg is

--------------------------------------------------------------------
--  name:            XXCS_WF_SEND_MAIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   12/06/2012 15:45:51
--------------------------------------------------------------------
--  purpose :        CRM - Handle all WF send mail, HTML body
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/06/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            prepare_coupon_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012
  --------------------------------------------------------------------
  --  purpose:         REP501 - Training Course Coupons
  --                   procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - manager id
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_coupon_body (p_document_id   in varchar2,
                                 p_display_type  in varchar2,
                                 p_document      in out clob,
                                 p_document_type in out varchar2) is
    
    l_msg1  varchar2(500) := null;
    l_msg2  varchar2(500) := null;
    l_msg3  varchar2(500) := null;
    l_msg4  varchar2(500) := null;
    l_msg5  varchar2(500) := null;
    l_msg6  varchar2(500) := null;
    l_msg7  varchar2(500) := null;
    l_msg8  varchar2(500) := null;
    l_msg9  varchar2(500) := null;
    l_msg10 varchar2(500) := null;
                                    
  begin
    -- Dear Customer,
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG1');
    l_msg1 := fnd_message.GET;
    
    -- As part of Objet’s commitment to your professional development, 
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG2');
    l_msg2 := fnd_message.GET;
    
    -- we invite you to attend an Advanced Operator’s course, free of charge (see the attached coupon).
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG3');
    l_msg3 := fnd_message.GET;
    
    -- At the Advanced Operator’s course you will learn best practices, new ways to maximize your Objet 
    -- printer’s capabilities, and advanced techniques for using Objet’s range of printing materials.
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG4');
    l_msg4 := fnd_message.GET;
  
    -- In our experience, the Advanced Operator’s course is a great way to increase your skills, 
    -- enabling you to optimize the value you get from your Objet printer. 
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG5');
    l_msg5 := fnd_message.GET;
    
    -- The Advanced Operator’s course is also an opportunity to meet other professionals from a variety  
    -- of industries and to learn how their knowledge can be applied to your day-to-day tasks.
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG6');
    l_msg6 := fnd_message.GET;
    
    -- We highly recommend that you take advantage of this opportunity. 
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG7');
    l_msg7 := fnd_message.GET;
    
    -- Space is limited, so call now to reserve your place in the next Advanced Operator’s course. 
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG8');
    l_msg8 := fnd_message.GET;
    -- You may also like to sign up other Objet printer operators in your 
    -- company who would benefit from advanced training.
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG9');
    l_msg9 := fnd_message.GET;
    
    -- Tank you, Customer Support
    fnd_message.SET_NAME('XXOBJT','XXCS_COUPON_MSG10');
    l_msg10 := fnd_message.GET;
    
    
    -- concatenate start message
    dbms_lob.append(p_document,'<HTML>'||
                               '<BODY><FONT color=blue face="Verdana">'||
                               '<P> </P>'||
                               '<P> '||l_msg1 ||' </P>'||
                               '<P> '||l_msg2 || l_msg3 ||' </P>'||
                               '<P> </P>'||
                               '<P> '||l_msg4 ||' </P>'||
                               '<P> '||l_msg5 ||' </P>'||
                               '<P> '||l_msg6 ||' </P>'||
                               '<P> </P>'||
                               '<P> '||l_msg7 ||' </P>'||
                               '<P> '||l_msg8 ||' </P>'||
                               '<P> '||l_msg9 ||' </P>'||
                               '<P> </P>'||
                               '<P> '||l_msg10 ||' </P>'||
                               '<P> </P>'||
                               '</BODY></HTML>'
                               );
    
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.CONTEXT('XXCS_WF_SEND_MAIL_PKG',
                      'XXCS_WF_SEND_MAIL_PKG.prepare_coupon_body',
                      p_document_id,
                      p_display_type);
      raise;
  
  end prepare_coupon_body;   
  
  --------------------------------------------------------------------
  --  name:            prepare_coupon_attachment
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the BLOB to attach to
  --                   the mail as attachment 
  --  In  Params:      p_document_id   - 
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML / application/pdf
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure prepare_coupon_attachment(document_id   IN VARCHAR2,
                                      display_type  IN VARCHAR2,
                                      document      IN OUT BLOB,
                                      document_type IN OUT VARCHAR2) is
                                      
    filename     varchar2(300); 
    l_directory  varchar2(150);
    --l_env        varchar2(20);
    --l_dir_path   varchar2(150);

  BEGIN
    -- document_id is the request id of the report i want 
    -- the output to add as attachment.
    -- 'XXCS_COUPONS_9903925_1.PDF'
    filename    := 'XXCS_COUPONS_'||document_id||'_1.PDF';
    
    l_directory := 'XXCS_COUPONS_FILES';--'XXCS_COUPONS_FILES'
    xxobjt_fnd_attachments.set_shared_directory (l_directory, 'CS/coupon');
    
        
    xxobjt_fnd_attachments.load_file_to_blob(p_file_name => filename,    -- i v
                                             p_directory => l_directory, -- i v
                                             p_blob      => document);   -- o Blob
  
    document_type := 'application/pdf'|| ';name=' || filename;
    --dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      null;
      wf_core.CONTEXT('xxcs_wf_send_mail_pkg',
                      'prepare_coupon_attachment',
                      document_id,
                      display_type);
      raise;
    
  end prepare_coupon_attachment;                                                                    
    
end xxcs_wf_send_mail_pkg;
/
