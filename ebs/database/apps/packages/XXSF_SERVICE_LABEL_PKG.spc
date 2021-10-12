CREATE OR REPLACE PACKAGE xxsf_service_label_pkg IS

  --------------------------------------------------------------------
  --  name:            XXSF_SERVICE_LABEL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/11/2014 16:21:42
  --------------------------------------------------------------------
  --  purpose :        CHG0033507 XXSF - Service Label form report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/11/2014  Dalit A. Raviv    initial build
  --  1.1  27/01/2015  Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
  --------------------------------------------------------------------
  -- global var for xmlp report params
  p_delivery_id    NUMBER := NULL;
  p_order_num      NUMBER := NULL;
  p_move_order_low VARCHAR2(30) := NULL;
  p_query          VARCHAR2(5000) := NULL;
  TYPE t_tab IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033507 XXSF - Service Label form report
  --                   Check if report need to be print.
  --                   when no data found or both parameters are null return false.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/11/2014  Dalit A. Raviv    initial build
  --  1.1  27/01/2015  Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
  --------------------------------------------------------------------
  FUNCTION beforereport(p_delivery_id    IN NUMBER,
		p_order_num      IN NUMBER,
		p_move_order_low IN VARCHAR2) RETURN BOOLEAN;

END xxsf_service_label_pkg;
/
