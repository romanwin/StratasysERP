CREATE OR REPLACE TRIGGER XXOE_LOT_SERIAL_NUMBERS_TRG

---------------------------------------------------------------------------
-- Trigger   :        XXOE_LOT_SERIAL_NUMBERS_trg
-- Created by:        YUVAL TAL
-- creation date:     3.8.10
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:
---------------------------------------------------------------------------
--  ver    date        name            desc
--  1.0   3.8.10       yuval tal       check serial number exists at customer
--  1.1   18.08.2013   Vitaly          CR 870 std cost - change hard-coded organization
---------------------------------------------------------------------------
  AFTER INSERT OR UPDATE of FROM_SERIAL_NUMBER ON OE_LOT_SERIAL_NUMBERS
  FOR EACH ROW
 
 
when ( (nvl(old.FROM_SERIAL_NUMBER,'-1') != new.FROM_SERIAL_NUMBER) or
 (nvl(old.to_SERIAL_NUMBER,'-1') != new.to_SERIAL_NUMBER)
   )
DECLARE
  l_tmp NUMBER;

  CURSOR c_check_item IS
    SELECT 1
      FROM mtl_system_items_b msi, oe_order_lines_all ol
     WHERE msi.serial_number_control_code = 5
       AND msi.organization_id = 736 /*ITA*/ ---90 /*WPI*/
       AND ol.line_id = :new.line_id
       AND msi.inventory_item_id = ol.ordered_item_id;

BEGIN
  OPEN c_check_item;
  FETCH c_check_item
    INTO l_tmp;

  CLOSE c_check_item;

  IF l_tmp = 1 THEN
    RETURN; -- no need to check serial
  END IF;
  ----
  SELECT nvl(MAX(1), 0)
    INTO l_tmp
    FROM oe_order_lines_all   ool,
         oe_order_headers_all ooh,
         csi_item_instances   cii,
         hz_cust_accounts     hca,
         hz_parties           hp,
         mtl_system_items_b   msi
   WHERE ool.header_id = ooh.header_id
     AND hca.cust_account_id = ooh.sold_to_org_id
     AND hca.party_id = hp.party_id
     AND cii.owner_party_id = hp.party_id
     AND cii.inventory_item_id = ool.inventory_item_id
     AND msi.inventory_item_id = ool.inventory_item_id
     AND msi.organization_id = ool.ship_from_org_id
     AND cii.serial_number BETWEEN :new.from_serial_number AND
         nvl(:new.to_serial_number, :new.from_serial_number)
     AND ool.line_id = :new.line_id;

  IF l_tmp = 0 THEN
    fnd_message.set_name('XXOBJT', 'XXOM_RMA_INVALID_SERIAL');
    app_exception.raise_exception;
  END IF;
END xxoe_lot_serial_numbers_trg;
/
