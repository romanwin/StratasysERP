create or replace package body XXGL_SEGMENT_COMPARISON_PKG is

 --------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/XXGL_SEGMENT_COMPARISON_PKG.bdy 1415 2014-07-16 12:41:44Z Gary.Altman $ 
  --------------------------------------------------------------------
  --  name:               XXGL_SEGMENT_COMPARISON_PKG
  --  create by:          GARY ALTMAN
  --  creation date:      14.07.2014
  --  Purpose :           support xmlp XXARACCTSGMNTCOMPAR  data source
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14.07.2014    GARY ALTMAN     initial revision
  -----------------------------------------------------------------------

  FUNCTION after_report RETURN BOOLEAN IS
  
    l_request_id NUMBER;
    l_count      NUMBER;
    l_conc_date  DATE;
  BEGIN      
    
      l_request_id := fnd_request.submit_request(application => 'XDO',
                                                 program     => 'XDOBURSTREP',
                                                 argument1   => 'Y',
                                                 argument2   => fnd_global.conc_request_id);
      IF l_request_id IS NOT NULL THEN                    
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
    
  END;
  
end XXGL_SEGMENT_COMPARISON_PKG;
/
