create or replace package XXGL_SEGMENT_COMPARISON_PKG is
  --------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/XXGL_SEGMENT_COMPARISON_PKG.spc 1415 2014-07-16 12:41:44Z Gary.Altman $ 
  --------------------------------------------------------------------
  --  name:               XXGL_SEGMENT_COMPARISON_PKG
  --  create by:          GARY ALTMAN
  --  creation date:      14.07.2014
  --  Purpose :           support xmlp XXARACCTSGMNTCOMPAR  data source
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14.07.2014    GARY ALTMAN     initial revision
  ----------------------------------------------------------------------- 

  FUNCTION after_report
   RETURN BOOLEAN;

end XXGL_SEGMENT_COMPARISON_PKG;
/
