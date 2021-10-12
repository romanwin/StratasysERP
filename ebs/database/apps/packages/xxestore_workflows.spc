create or replace package xxestore_workflows is

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
  --  name:            init_XXattributes
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/07/2012
  --------------------------------------------------------------------
  --  purpose :        
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE xxinitialize( itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2);
                          
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
                               document_type in out varchar2);                          
                            
end XXESTORE_WORKFLOWS;
/
