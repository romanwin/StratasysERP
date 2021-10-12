create or replace package XXPO_UploadDocs_Pkg is

  -- Author  : AVIH
  -- Created : 16/07/2009 14:23:12
  -- Purpose : Handles Purchasing Documents Uploads

Function GetConversoinMLS return varchar2;

Procedure do_linkage(p_po_num        In po_headers_all.segment1%TYPE,
                     p_from_currency In po_headers_all.currency_code%TYPE,
                     p_to_currency   In po_headers_all.currency_code%TYPE,
                     p_base_date     In DATE,
                     p_LineUnitPrice In po_lines_all.unit_price%type,
                     p_POHdrAttr3    Out po_headers_all.attribute3%type
                    )
;
Procedure Ascii_StandrardPOInt (errbuf                   out varchar2, 
                                retcode                  out varchar2,
                                p_location               in varchar2,
                                p_filename               in varchar2,
                                p_master_organiz_id      in number,
                                p_processLines           in char)
;

end XXPO_UploadDocs_Pkg;
/

