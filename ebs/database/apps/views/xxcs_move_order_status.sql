CREATE OR REPLACE VIEW XXCS_MOVE_ORDER_STATUS AS
SELECT mh.header_id ,
       mh.request_number AS move_order_number,
       mh.attribute2 incident_id,
       'Open' AS status
  FROM mtl_txn_request_headers mh
 WHERE mh.header_id IN
       (SELECT ml.header_id
          FROM mtl_txn_request_lines ml, fnd_lookup_values flv
         WHERE flv.lookup_type = 'MTL_TXN_REQUEST_STATUS' AND
               flv.lookup_code = ml.line_status AND
               flv.LANGUAGE = 'US' AND
               flv.meaning NOT IN ('Canceled', 'Closed')) AND
       mh.attribute2 IS NOT NULL
UNION
-- This SQL Returns Closed Move Orders
SELECT mh.header_id,
       mh.request_number,
       mh.attribute2,
       'Closed'
  FROM mtl_txn_request_headers mh
 WHERE mh.header_id NOT IN
       (SELECT ml.header_id
          FROM mtl_txn_request_lines ml, fnd_lookup_values flv
         WHERE flv.lookup_type = 'MTL_TXN_REQUEST_STATUS' AND
               flv.lookup_code = ml.line_status AND
               flv.LANGUAGE = 'US' AND
               flv.meaning NOT IN ('Canceled', 'Closed')) AND
       mh.attribute2 IS NOT NULL;

