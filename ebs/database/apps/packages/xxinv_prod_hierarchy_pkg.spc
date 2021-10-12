create or replace package xxinv_prod_hierarchy_pkg is
--------------------------------------------------------------------
--  name:            XXINV_PROD_HIERARCHY_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   12/06/2014 13:05:45
--------------------------------------------------------------------
--  purpose :        CHG0032236 - Item Category Auto assign - Product Hierarchy
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/06/2014  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2014 13:05:45
  --------------------------------------------------------------------
  --  purpose :        Handle main program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure  main (errbuf                    out varchar2,
                   retcode                   out varchar2,
                   p_organization_id         in  number,
                   p_forecast_name           in  varchar2,
                   p_simulation_mode         in  varchar2,
                   p_Constrain_lob           in  varchar2, 
                   p_Constrain_lob_threshold in  number,       
                   p_Common_threshold        in  number,
                   p_days_to_keep_assign     in  number,
                   p_day_to_keep_import      in  number ); 
                   
                   
  --------------------------------------------------------------------
  --  name:            prepare_mail_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/2014
  --------------------------------------------------------------------
  --  purpose:         procedure taht prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - request_id of XXOBJT_CONV_CATEGORY table
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure prepare_mail_body(p_document_id   in varchar2,
                              p_display_type  in varchar2,
                              p_document      in out clob,
                              p_document_type in out varchar2);                   
end XXINV_PROD_HIERARCHY_PKG;
/
