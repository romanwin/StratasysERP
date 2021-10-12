create or replace package xxpo_linkage_temp_pkg is

--------------------------------------------------------------------
--  name:            XXPO_LINKAGE_TEMP_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   19/06/2013 09:06:24
--------------------------------------------------------------------
--  purpose :        CUST006 PO Linkage
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  19/06/2013  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            clear_header_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/06/2013 09:06:24
  --------------------------------------------------------------------
  --  purpose :        CUST006 PO Linkage CR837
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure clear_header_id (errbuf       out varchar2,
                             retcode      out varchar2,
                             p_po_number  in  varchar2);

  --------------------------------------------------------------------
  --  name:            set_header_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/06/2013 09:06:24
  --------------------------------------------------------------------
  --  purpose :        CUST006 PO Linkage CR837
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure set_header_id   (errbuf       out varchar2,
                             retcode      out varchar2,
                             p_po_number  in  varchar2,
                             p_rel_number in  number);                                      
  
end xxpo_linkage_temp_pkg;
/
