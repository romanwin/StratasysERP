CREATE OR REPLACE PACKAGE xxinv_resin_rep_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXINV_RESIN_REP
  --  create by:          YUVAL TAL
  --  $Revision:          1.0 $
  --  creation date:      9.8.10
  --  Purpose :           support xmlp XXINVRESINREP  data source
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    9.8.10    YUVAL TAL            initial build
  ----------------------------------------------------------------------- 

  -- global var for xfter report params

  p_operating_unit  NUMBER;
  p_mail_recipients VARCHAR2(240);
  PROCEDURE distribute_resin_report(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_mail_recipients VARCHAR2);

  FUNCTION after_report(p_mail_recipients VARCHAR2) RETURN BOOLEAN;

END xxinv_resin_rep_pkg;
/
