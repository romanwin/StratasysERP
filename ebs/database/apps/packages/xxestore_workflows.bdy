create or replace package body xxestore_workflows is

--------------------------------------------------------------------
--  name:            XXESTORE_WORKFLOWS
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   01/07/2012 14:57:46
--------------------------------------------------------------------
--  purpose :        CUST509 - eStore Change WF for Notifications     
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  01/07/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            XXInitialize
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/07/2012
  --------------------------------------------------------------------
  --  purpose :        This procedure will call from 
  --                   WF iStore Alerts Workflow (IBEALERT)
  --                   and will handle init of XX attributes.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure xxinitialize( itemtype  in varchar2,
                          itemkey   in varchar2,
                          actid     in number,
                          funcmode  in varchar2,
                          resultout out nocopy varchar2) is
  
    l_email_text  varchar2(240) := null;
    --l_msite_name  varchar2(240) := null;
    l_msg_name    varchar2(240) := null;
    l_msg1        varchar2(500) := null;
    l_msg2        varchar2(500) := null;
    l_msg3        varchar2(500) := null;
    l_msg4        varchar2(500) := null;
    l_msg5        varchar2(500) := null;
    l_sendto      varchar2(240) := null;
    l_org_id      varchar2(240) := null;
          
  begin
    
    l_sendto := wf_engine.GetItemAttrText(itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'SENDTO');                                                                               
                                                                                                                                        
    -- get from workflow the value at attribute SEND_TO
    -- this value (HZ_PARTY:1913050) hold hz_party_id parameter 1913050                                        
    select v.profile_option_value 
    into   l_org_id
    from   fnd_profile_option_values v,       
           fnd_profile_options       fpo,
           fnd_user                  fu,      
           fnd_user_resp_groups_all  fur
    where  fu.user_id                = fur.user_id
    and    fur.responsibility_id     = v.level_value
    and    v.profile_option_id       = fpo.profile_option_id
    and    fpo.profile_option_name   = 'ORG_ID' --MO: Operating Unit
    and    fu.customer_id            = substr(l_sendto,10) --'HZ_PARTY:7099052'
    --and    nvl(fur.end_date,sysdate) between fur.start_date and nvl(fur.end_date, sysdate -1);              
    and   ( fur.end_date is null or fur.end_date > trunc(sysdate));

    -- By The party_id found we get the email text from message.
    -- substr(l_send_to,10) this bring the only party_id
    begin      
      if l_org_id = 96 then
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_DE';
      elsif l_org_id = 89 then
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_US';
      elsif l_org_id = 81 then
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_EM';  
      elsif l_org_id = 103 then
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_HK';  
      elsif l_org_id = 161 then
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_CN';  
      else
        l_msg_name := 'XXIBE_SUPPORT_EMAIL_DEFAULT';
      end if;    
        
      select fnm.message_text
      into   l_email_text
      from   fnd_new_messages fnm
      where  fnm.message_name = l_msg_name;
                               
      --if l_msite_name = 'Objet_Europe' then  
      if l_org_id = 96 then   
        begin
          select fnm1.message_text
          into   l_msg1
          from   fnd_new_messages  fnm1
          where  fnm1.message_name = 'XXIBE_EU_MSG1';
        exception
          when others then l_msg1 := null;
        end;
        begin
          select fnm2.message_text
          into   l_msg2
          from   fnd_new_messages  fnm2
          where  fnm2.message_name = 'XXIBE_EU_MSG2';
        exception
          when others then l_msg2 := null;
        end;
        begin
          select fnm3.message_text
          into   l_msg3
          from   fnd_new_messages  fnm3
          where  fnm3.message_name = 'XXIBE_EU_MSG3';
        exception
          when others then l_msg3 := null;
        end;
        begin
          select fnm4.message_text
          into   l_msg4
          from   fnd_new_messages  fnm4
          where  fnm4.message_name = 'XXIBE_EU_MSG4';
        exception
          when others then l_msg4 := null;
        end;
        begin
          select fnm5.message_text
          into   l_msg5
          from   fnd_new_messages  fnm5
          where  fnm5.message_name = 'XXIBE_EU_MSG5';
        exception
          when others then l_msg5 := null;
        end;                                    
      else
        l_msg1 := null;
        l_msg2 := null;
        l_msg3 := null;
        l_msg4 := null;
        l_msg5 := null;
      end if;
                                
      -- set WF attributes with new email body text details
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_SUPPORT_EMAIL',
                                avalue   => l_email_text);                           
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_EU_MSG1',
                                avalue   => l_msg1); 
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_EU_MSG2',
                                avalue   => l_msg2);   
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_EU_MSG3',
                                avalue   => l_msg3);                                                            
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_EU_MSG4',
                                avalue   => l_msg4);   
      wf_engine.SetItemAttrText(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXIBE_EU_MSG5',
                                avalue   => l_msg5);   

      resultout := wf_engine.eng_completed;
      return;
    exception
      when others then
        -- set WF attributes with new email body text details
        wf_engine.SetItemAttrNumber(itemtype => itemtype,
                                    itemkey  => itemkey,
                                    aname    => 'XXIBE_SUPPORT_EMAIL',
                                    avalue   => '');
        
        --resultout := 'COMPLETE:';
        resultout := wf_engine.eng_completed;
        return;
    end;

  exception
    when others then
      wf_core.context('XXESTORE_WORKFLOWS',
                      'XXInitialize',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      resultout := wf_engine.eng_error;
      raise;
      return;
  end XXINITIALIZE;
  
  --------------------------------------------------------------------
  --  name:            prepare_attachment
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/12/2012
  --------------------------------------------------------------------
  --  purpose :        This procedure call from workflow - JTF Approval
  --                   New Attribute XX_Blob_Attachment1 
  --                   default value is plsqlblob:XXESTORE_WORKFLOWS.prepare_attachment
  --                   
  --                   This give the ability to attach the file to the mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/12/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure prepare_attachment(document_id   in varchar2,
                               display_type  in varchar2,
                               document      in out blob,
                               document_type in out varchar2)  is
                         
    filename     varchar2(300); 
    l_directory  varchar2(150);
  begin
    
    filename    := 'ObjeteStoreFAQ.PDF'; -- to keep at profile
    
    l_directory := 'XXIBE_ATTACHMENT_DOC';
    xxobjt_fnd_attachments.set_shared_directory (l_directory, 'ESTORE/attachment');

    xxobjt_fnd_attachments.load_file_to_blob(p_file_name => filename,    -- i v
                                             p_directory => l_directory, -- i v
                                             p_blob      => document);   -- o Blob
  
    document_type := 'application/pdf'|| ';name=' || filename;
    --dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.CONTEXT('XXESTORE_WORKFLOWS',
                      'prepare_attachment',
                      document_id,
                      display_type);
      raise;
  end prepare_attachment;
                                                 
    
end XXESTORE_WORKFLOWS;
/
