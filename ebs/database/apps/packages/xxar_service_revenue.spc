CREATE OR REPLACE PACKAGE xxar_service_revenue IS
  --------------------------------------------------------------------
  --  name:              XXAR_SERVICE_REVENUE
  --  create by:         Ofer.Suad
  --  Revision:          1.0
  --  creation date:     15/01/2012
  --------------------------------------------------------------------
  --  purpose :          Conratcts from OM Accounting
  --------------------------------------------------------------------
  PROCEDURE move_earned_revenue(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  FUNCTION is_ssys_item(pc_itemid NUMBER) RETURN NUMBER;

END xxar_service_revenue;
/
