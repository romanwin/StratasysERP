CREATE OR REPLACE PACKAGE BODY PO_CUSTOM_XMLGEN_PKG AS
/* $Header: PO_CUSTOM_XMLGEN_PKG.plb 120.0.12010000.2 2012/09/28 07:26:36 yuandli noship $ */

--========================================================================
-- PROCEDURE : generate_xml_fragment       PUBLIC
-- PARAMETERS: p_document_id         document id
--           : p_revision_num        revision num of the document
--           : p_document_type       document type of the document
--           : p_document_subtype    document subtype of the document
--           : x_custom_xml          output of xml
-- COMMENT   : Custom hook to generate XML fragment for document,
--             called by PO Output for Communication
-- PRE-COND  : NONE
-- EXCEPTIONS: NONE
-- EXAMPLE CODES: Here is an example of how to program custom code.
/**
PROCEDURE generate_xml_fragment
(p_document_id IN NUMBER
, p_revision_num IN NUMBER
, p_document_type IN VARCHAR2
, p_document_subtype IN VARCHAR2
, x_custom_xml OUT NOCOPY CLOB)
IS
  --1). Declare context
  context DBMS_XMLGEN.ctxHandle;
BEGIN

  --2). Init context with custom query sql statement
  context := dbms_xmlgen.newContext('select 1,2,3 from dual');

  --3). Set XML tag of the XML fragment for the result set
  dbms_xmlgen.setRowsetTag(context,'CUSTOM_RESULT');

  --4). Set XML tag for each row of the result set
  dbms_xmlgen.setRowTag(context,NULL);

  dbms_xmlgen.setConvertSpecialChars (context, TRUE);

  --5). Call dbms_xmlgen to get XML and assign it to output CLOB
  x_custom_xml := dbms_xmlgen.getXML(context,DBMS_XMLGEN.NONE);

  dbms_xmlgen.closeContext(context);
EXCEPTION
  WHEN OTHERS THEN
  --6). Capture any exceptions and handle them properly
    NULL;
END;
*/
--========================================================================
-----------------------------------------------------------------------
  --  name:               generate_xml_fragment
  --  create by:          Oracle
  --  Revision:           1.0
  --  creation date:      xx.xx.xxxx
  --  Purpose :           Custom Hook For Enhancing Purchase Order PDF XML Generation Logic (Doc ID 1505737.1)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx.xx.xxxx    Oracle          initial Version
  --  1.1   05.06.2017    Lingaraj(TCS)   CHG0040423 – Add Shipping Notes to PO Pdf for Standard PO(Only for USA)
  -----------------------------------------------------------------------
  PROCEDURE generate_xml_fragment
  (p_document_id IN NUMBER
  , p_revision_num IN NUMBER
  , p_document_type IN VARCHAR2
  , p_document_subtype IN VARCHAR2
  , x_custom_xml OUT NOCOPY CLOB)
  IS

  context DBMS_XMLGEN.ctxHandle;
  v_shipping_notes_US VARCHAR2(4000) := q'[Select message_name message , message_text text
                                            from fnd_new_messages where language_code = userenv('LANG')
                                            and message_name in 
                                               ('XXPO_SHIPPING_NOTE_US_01',
                                                'XXPO_SHIPPING_NOTE_US_BOLD_02',
                                                'XXPO_SHIPPING_NOTE_US_03')
                                           ]';
  BEGIN
    fnd_file.put_line(fnd_file.log,'PO_CUSTOM_XMLGEN_PKG.generate_xml_fragment Called for :' || CHR(13)
                                   ||'Document ID :'|| p_document_id     || CHR(13)                                                
                                   ||'Revision Num :'|| p_revision_num   || CHR(13)
                                   ||'Document Type :'|| p_document_type || CHR(13)
                                   ||'Document Sub Type :'|| p_document_subtype || CHR(13)
                                   );
    If p_document_subtype = 'STANDARD' and FND_GLOBAL.ORG_ID = 737 Then
        fnd_file.put_line(fnd_file.log,'Query :'||v_shipping_notes_US);
        
        --2). Init context with custom query sql statement
        context  := dbms_xmlgen.newContext (  v_shipping_notes_US );
        
        --3). Set XML tag of the XML fragment for the result set
        dbms_xmlgen.setRowsetTag(context,'PO_CUSTOM_DATA');
        
        --4). Set XML tag for each row of the result set
        dbms_xmlgen.setRowTag(context, 'US_SHIPPING_NOTE');
        dbms_xmlgen.setConvertSpecialChars (context, TRUE);
        
        --5). Call dbms_xmlgen to get XML and assign it to output CLOB
        x_custom_xml := dbms_xmlgen.getXML(context,DBMS_XMLGEN.NONE);
        dbms_xmlgen.closeContext(context);
        
        fnd_file.put_line(fnd_file.log,'US Shipping Notes XML OutPut :'||x_custom_xml);
    End If;    
    
  Exception
  When Others Then
     fnd_file.put_line(fnd_file.log,'Exception in PO_CUSTOM_XMLGEN_PKG.generate_xml_fragment :'||sqlerrm); 
  END generate_xml_fragment;

END PO_CUSTOM_XMLGEN_PKG;
/
