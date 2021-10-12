CREATE OR REPLACE PACKAGE xxqp_upd_price_alert_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST527
  --  name:               xxqp_upd_price_alert_pkg
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  ----------------------------------------------------------------------- 

  
  

  --------------------------------------------------------------------
  --  customization code: CUST527
  --  name:               prepare_notification_body
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  -----------------------------------------------------------------------
  PROCEDURE prepare_notification_body(p_document_id   in varchar2,
                                      p_display_type  in varchar2,
                                      p_document      in out clob,
                                      p_document_type in out varchar2);

  
END xxqp_upd_price_alert_pkg;
/
