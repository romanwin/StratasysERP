CREATE OR REPLACE PACKAGE BODY xxom_ssys_rma_pkg IS

--------------------------------------------------------------------
--  name:              XXOM_SSYS_RMA_PKG
--  create by:         Dalit A. Raviv
--  Revision:          1.0 
--  creation date:     02/09/2012 13:21:57
--------------------------------------------------------------------
--  purpose :          Merge project - REP536 - Stratasys Return Material Authorization report
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  02/09/2012    Dalit A. Raviv    initial build
--  1.1  11/02/2013    Dalit A. Raviv    add parameter to the report - P_ORDER_NUM
--  1.2  27/01/2015    Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
--------------------------------------------------------------------  

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
  --  1.1  12/02/2013  Dalit A. Raviv    add parameter P_ORDER_NUM and change main select
  --  1.2  23/09/2013  Adi Safin         CR1028 Add SSUS operating unit get order types according to attribute instead of hard code.
  --  1.3  27/01/2015  Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
  --------------------------------------------------------------------  
  FUNCTION beforereport(P_DELIVERY_ID IN NUMBER, P_ORDER_NUM IN NUMBER, P_MOVE_ORDER_LOW in varchar2)
    RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
  
    if P_DELIVERY_ID is null and P_ORDER_NUM is null and P_MOVE_ORDER_LOW is null then
      fnd_file.put_line(fnd_file.log,'All Parameters are null. Please enter order number, delivery number or move order number.');
      return FALSE;
    end if;
  
    SELECT COUNT(1)
      INTO l_count
      FROM ont.oe_order_headers_all oh
     WHERE ((oh.order_number = p_order_num) OR (p_order_num IS NULL))
       AND ((EXISTS (SELECT 1
                       FROM wsh.wsh_new_deliveries       wnd,
                            wsh.wsh_delivery_assignments wda,
                            wsh.wsh_delivery_details     wdd
                      WHERE wnd.delivery_id = wda.delivery_id
                        AND wda.delivery_detail_id = wdd.delivery_detail_id
                        AND wdd.source_header_id = oh.header_id
                        AND wnd.delivery_id = p_delivery_id)) OR
           p_delivery_id IS NULL)
       AND EXISTS
     (SELECT ooha.header_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE ooha.header_id = oola.header_id
               AND oh.header_id = ooha.header_id
               AND oola.line_type_id IN
                   (SELECT ottl.transaction_type_id
                      FROM oe_transaction_types_tl  ottl,
                           oe_transaction_types_all ott
                     WHERE ott.transaction_type_id = ottl.transaction_type_id
                       AND ottl.language = 'US'
                       AND ott.order_category_code = 'RETURN')
               AND ooha.order_type_id IN
                   ((SELECT ota.transaction_type_id
                      FROM oe_transaction_types_all ota
                     WHERE ota.attribute12 = 'Y'
                       AND ota.transaction_type_code = 'ORDER')))
     -- Dalit A. Raviv 
     AND ((EXISTS (SELECT 1
                     FROM wsh_delivery_details    d,
                          mtl_txn_request_headers rh,
                          mtl_txn_request_lines   rl
                    WHERE d.source_header_id = oh.header_id
                      AND rl.line_id = d.move_order_line_id
                      AND rh.header_id = rl.header_id
                      AND rh.request_number = P_MOVE_ORDER_LOW))
          OR P_MOVE_ORDER_LOW IS NULL)  
                       ;
  
    IF l_count <> 0 THEN
      RETURN TRUE;
    ELSE
      fnd_file.put_line(fnd_file.log,
                        '----------------------------------------');
      IF p_delivery_id IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
                          'Delivery - ' || p_delivery_id ||
                          ' is not related to a return Order');
      END IF;
      IF p_order_num IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
                          'SO Order - ' || p_order_num ||
                          ' is not a return Order');
      END IF;
      fnd_file.put_line(fnd_file.log,
                        '----------------------------------------');
    
      RETURN FALSE;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'----------------------------------------');
      fnd_file.put_line(fnd_file.log,'General error - ' || substr(SQLERRM, 1, 240));
      fnd_file.put_line(fnd_file.log,'Delivery   - ' || p_delivery_id);
      fnd_file.put_line(fnd_file.log,'SO Order   - ' || p_order_num);
      fnd_file.put_line(fnd_file.log,'Move Order - ' || p_move_order_low);
      fnd_file.put_line(fnd_file.log,'----------------------------------------');
      RETURN FALSE;
  END beforereport;

END xxom_ssys_rma_pkg;
/
