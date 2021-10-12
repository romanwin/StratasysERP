CREATE OR REPLACE PACKAGE BODY xxobjt_wf_doc_rg IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_WF_DOC_RG
  --  create by:       Yuval tal
  --  Revision:        1.1 
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        CUST611 : document approval engine 
  --                   support workflow XXWFDOC
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --------------------------------------------------------------------

  -- Private constant declarations
  g_pkg_name VARCHAR2(50) := 'XXOBJT_WF_DOC_RG';

  --------------------------------------------------------------------
  --  name:            get_history_wf
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        draw history table in notification
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --  1.1  21/07/2013  Dalit A. RAviv    handle null values -> '&nbsp'
  --------------------------------------------------------------------

  PROCEDURE get_history_wf(document_id   IN VARCHAR2,
                           display_type  IN VARCHAR2,
                           document      IN OUT NOCOPY CLOB,
                           document_type IN OUT NOCOPY VARCHAR2) IS
  
    CURSOR c_his IS
      SELECT *
        FROM xxobjt_wf_doc_history_v
       WHERE doc_instance_id = to_number(document_id);
  
  BEGIN
  
    --  document_type := 'text/html';
    document := '<TABLE border=1 cellPadding=3>
   <TR>
    <TH>Seq</TH>
    <TH>Creation Date</TH>
    <TH>Executed By</TH>
    <TH>Title</TH>
    <TH>Action Desc</TH>
    <TH>Action Date</TH>
    <TH>Note</TH>
   </TR>';
  
    FOR i IN c_his LOOP
    
      dbms_lob.append(document,
                      '<TR>
                        <TD>' || i.seq ||
                      '</TD>
                        <TD>' ||
                      to_char(i.creation_date, 'dd-mm-yy hh24:mi') ||
                      '</TD>
                        <TD>' ||
                      nvl(i.role_description, '&nbsp') ||
                      '</TD>
                        <TD>' ||
                      nvl(i.dynamic_role_description, '&nbsp') ||
                      '</TD>
                        <TD>' ||
                      nvl(i.action_desc, '&nbsp') ||
                      '</TD> 
                        <TD>' ||
                      nvl(to_char(nvl(i.action_date, SYSDATE),
                                  'dd-mm-yy hh24:mi'),
                          '&nbsp') || '</TD>
                        <TD>' ||
                      nvl(TRIM(i.note), '&nbsp') ||
                      '</TD>
                      </TR>');
    END LOOP;
    dbms_lob.append(document, '</TABLE>');
  
  EXCEPTION
    WHEN OTHERS THEN
    
      wf_core.context(g_pkg_name,
                      'get_history_wf',
                      document_id,
                      display_type);
      RAISE;
  END;
  ---------------------

END;
/
