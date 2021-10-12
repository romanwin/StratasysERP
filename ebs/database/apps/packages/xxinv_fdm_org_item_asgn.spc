create or replace package xxinv_fdm_org_item_asgn as 
--
--
  --------------------------------------------------------------------
  --  name:              xxinv_fdm_org_item_asgn
  --  create by:         Sanjai K Misra
  --  Revision:          1.0
  --  creation date:     01-Jul-14
  --------------------------------------------------------------------
  --  purpose :          Copy UME Items to org under SSUS
  --                     Yhis package was created for change request CHG0032038
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0                Sanjai K Misra    Initial Creation
--
--
PROCEDURE process_items
( errbuf      OUT VARCHAR2
, retcode     OUT VARCHAR2 
, p_file_name     VARCHAR2
, p_directory     VARCHAR2
) ;
end;
/