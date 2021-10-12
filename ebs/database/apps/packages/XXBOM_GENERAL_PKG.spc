create or replace package XXBOM_GENERAL_PKG is

----------------------------------------------------------------------------------------
--      customization code: CHG0034558 
--      name:               XXBOM_GENERAL_PKG
--      create by:          Dalit A. Raviv
--      $Revision:          1.0 $
--      creation date:      07/05/2015 12:17:47
--      Purpose :           General package for BOM uses
----------------------------------------------------------------------------------------
--  ver   date         name             desc
--  1.0   20/11/2006   Dalit A. Raviv   initial build
----------------------------------------------------------------------------------------

 
  ----------------------------------------------------------------------------------------
  --      customization code: CHG0034558 - Restore capability lost due to implementation of Agile
  --      name:               XXBOM_GENERAL_PKG
  --      create by:          Dalit A. Raviv
  --      $Revision:          1.0 $
  --      creation date:      07/05/2015 12:17:47
  --      Purpose :           
  ----------------------------------------------------------------------------------------
  --  ver   date         name             desc
  --  1.0   20/11/2006   Dalit A. Raviv   initial build
  ----------------------------------------------------------------------------------------
  procedure bom_upd_Backflush_info(errbuf            out varchar2,
                                   retcode           out varchar2,
                                   p_organization_id in  number,
                                   p_source_assembly in  number,
                                   p_new_assembly    in  number);

end XXBOM_GENERAL_PKG;
/
