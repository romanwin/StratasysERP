CREATE OR REPLACE PACKAGE BODY xxinv_utils_temp_pkg IS

   FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
                                 p_order_line_id NUMBER) RETURN VARCHAR2 IS
   
      CURSOR csr_lot_serials IS
         SELECT wsn.fm_serial_number ||
                decode(wsn.fm_serial_number,
                       wsn.to_serial_number,
                       NULL,
                       wsn.fm_serial_number,
                       NULL,
                       NULL,
                       ', ') ||
                decode(wsn.fm_serial_number,
                       wsn.to_serial_number,
                       NULL,
                       wsn.to_serial_number) ser_lot,
                NULL exp_date,
                wdd.inventory_item_id
           FROM wsh_delivery_details     wdd,
                wsh_delivery_assignments wda,
                wsh_new_deliveries       wnd,
                wsh_serial_numbers       wsn
          WHERE wdd.delivery_detail_id = wda.delivery_detail_id AND
                wdd.delivery_detail_id = wsn.delivery_detail_id AND
                wda.delivery_id = wnd.delivery_id AND
                wnd.NAME = nvl(p_delivery_name, wnd.NAME) AND -- Delivery_id from Invoice
                wdd.source_line_id = p_order_line_id -- Order Line ID from invoice;
         UNION ALL
         SELECT wdd.lot_number ser_lot,
                to_char(mln.expiration_date, 'DD-MON-RR') exp_date,
                wdd.inventory_item_id
           FROM wsh_delivery_details     wdd,
                wsh_delivery_assignments wda,
                wsh_new_deliveries       wnd,
                mtl_lot_numbers          mln
          WHERE wdd.delivery_detail_id = wda.delivery_detail_id AND
                wdd.lot_number IS NOT NULL AND
                wdd.inventory_item_id = mln.inventory_item_id AND
                wdd.organization_id = mln.organization_id AND
                wdd.lot_number = mln.lot_number AND
                wda.delivery_id = wnd.delivery_id AND
                wnd.NAME = nvl(p_delivery_name, wnd.NAME) AND -- Delivery_id from Invoice
                wdd.source_line_id = p_order_line_id; -- Order Line ID from invoice;
   
      v_serial_num VARCHAR2(50);
      v_flag       NUMBER;
   
   BEGIN
      v_flag := 1;
      FOR curec IN csr_lot_serials LOOP
         IF v_flag = 1 THEN
            IF curec.exp_date IS NOT NULL THEN
               v_serial_num := curec.ser_lot || chr(10) || '(' ||
                               curec.exp_date || ')';
            ELSE
               v_serial_num := curec.ser_lot;
            END IF;
         ELSE
            IF curec.exp_date IS NOT NULL THEN
               v_serial_num := v_serial_num || ',' || curec.ser_lot ||
                               chr(10) || '(' || curec.exp_date || ')';
            ELSE
               v_serial_num := v_serial_num || ',' || curec.ser_lot;
            END IF;
         END IF;
      
         v_flag := v_flag + 1;
      END LOOP;
   
      RETURN v_serial_num;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_delivery_serials;

END xxinv_utils_temp_pkg;
/

