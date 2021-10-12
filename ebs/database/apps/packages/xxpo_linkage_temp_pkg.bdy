create or replace package body xxpo_linkage_temp_pkg is
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
                             p_po_number  in  varchar2) is
  begin
    errbuf  := null;
    retcode := 0;
    
    update clef062_po_index_esc_set x
    set    x.po_header_id = null
    where  x.module       = 'PO'
    and    x.document_id  = p_po_number;
    commit;
  exception
    when others then
      errbuf  := 'Failed to clear PO header id. PO Number :' || p_po_number;
      retcode := 2;
      rollback;
      fnd_file.put_line(fnd_file.log, 'Failed to clear PO header id. PO Number :' || p_po_number);
  end clear_header_id;                                           

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
                             p_rel_number in  number) is
  begin
    errbuf  := null;
    retcode := 0;
    
    update clef062_po_index_esc_set x
    set    x.po_header_id = (select p.po_header_id
                             from   po_headers_all p
                             where  p.segment1     = p_po_number)
    where  x.module       = 'PO'
    and    x.document_id  = p_po_number 
    and    x.release_num  = p_rel_number;
    commit;
    
  exception
    when others then
      errbuf  := 'Failed to set PO header id. PO Number :' || p_po_number;
      retcode := 2;
      rollback;
      fnd_file.put_line(fnd_file.log, 'Failed to clear PO header id. PO Number :' || p_po_number);
  end set_header_id;                                                                  
  
  
end xxpo_linkage_temp_pkg;
/
