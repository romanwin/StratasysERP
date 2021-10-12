create or replace package xxom_ssys_rma_pkg is

--------------------------------------------------------------------
--  name:            XXOM_SSYS_RMA_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1 
--  creation date:   02/09/2012 13:21:57
--------------------------------------------------------------------
--  purpose :        Merge project - REP536 - Stratasys Return Material Authorization report
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  02/09/2012  Dalit A. Raviv    initial build
--  1.1  11/02/2013  Dalit A. Raviv    add parameter to the report - P_ORDER_NUM
--  1.2  27/01/2015  Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
--------------------------------------------------------------------  
  
  -- global var for xmlp report params
  P_DELIVERY_ID number := null;
  P_ORDER_NUM   number := null;
  P_MOVE_ORDER_LOW varchar2(30); --  1.2 27/01/2015 Dalit A. RAviv CHG0034438

  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP536 - Stratasys Return Material Authorization report
  --                   Check if report need to be print.
  --                   report will print for delivery that relate to Order with return line.                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2012  Dalit A. Raviv    initial build
  --  1.1  12/02/2013  Dalit A. Raviv    add parameter P_ORDER_NUM
  --  1.2  27/01/2015  Dalit A. Raviv    CHG0034438 add parameter P_MOVE_ORDER_LOW.
  --------------------------------------------------------------------  
  function beforereport (P_DELIVERY_ID in number, P_ORDER_NUM in number, P_MOVE_ORDER_LOW in varchar2) return boolean;

end XXOM_SSYS_RMA_PKG;

 
/
