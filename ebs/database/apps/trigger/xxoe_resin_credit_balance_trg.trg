CREATE OR REPLACE TRIGGER xxoe_resin_credit_balance_trg
  before insert or UPDATE OF UNIT_SELLING_PRICE,ORDERED_QUANTITY on oe_order_lines_all  
  for each row
DECLARE
   -- local variables here
   l_curr_code     VARCHAR2(15) := NULL;
   l_order_type_id NUMBER := NULL;
   l_cust_num      VARCHAR2(30) := NULL;
   l_order_number  NUMBER := NULL;
   l_order_price   NUMBER := NULL;
   l_calc_balance  NUMBER := NULL;
   l_resin_balance NUMBER := NULL;
   --l_message       VARCHAR2(2000) := NULL;
   general_exception exception;
BEGIN
   --------------------------------------------------------------------
   --  name:            xxoe_resin_credit_balance_trg
   --  create by:       Dalit A. Raviv
   --  Revision:        1.0 
   --  creation date:   07/02/2009
   --------------------------------------------------------------------
   --  purpose :        Calc order resin balance 
   --------------------------------------------------------------------
   --  ver  date        name              desc
   --  1.0  07/02/2009  Dalit A. Raviv    initial build
   --  1.1  15/06/2016  Diptasurjya       CHG0038661 - Consider ordered quantity while 
   --                   Chatterjee        calculating entered resin credit amount
   --------------------------------------------------------------------

   -- profile to open close trigger
   IF nvl(fnd_profile.VALUE('XXOE_ENABLE_RESIN_CREDIT'), 'N') = 'Y' THEN
      -- if line contain resin credit item and not Canceled line
      IF xxoe_utils_pkg.is_item_resin_credit(:NEW.inventory_item_id) = 'Y' AND
         :NEW.flow_status_code <> 'Cancelled' THEN
         -- get header data
         BEGIN
            SELECT h.transactional_curr_code,
                   h.order_type_id,
                   hz.account_number,
                   h.order_number
              INTO l_curr_code, l_order_type_id, l_cust_num, l_order_number
              FROM oe_order_headers_all h, hz_cust_accounts hz
             WHERE h.header_id = :NEW.header_id AND
                   hz.cust_account_id = h.sold_to_org_id;
         EXCEPTION
            WHEN OTHERS THEN
               l_curr_code     := NULL;
               l_order_type_id := NULL;
               l_cust_num      := NULL;
               l_order_number  := NULL;
         END;
         -- get if initial order and line price < 0     
         IF xxoe_utils_pkg.is_initial_order(l_order_type_id) = 'N' THEN
            IF :NEW.unit_selling_price < 0 THEN          
               -- get order balance without currnt line from data base  
               l_order_price := xxoe_utils_pkg.get_order_resin_balance(l_cust_num,
                                                                       l_curr_code,
                                                                       :NEW.line_id,
                                                                       l_order_number);
                                                                       
               -- calc customer balance by order balance + current line                                                          
               l_calc_balance := xxoe_utils_pkg.calc_resin_credit(l_order_price,
                                                                  0,
                                                                  (:NEW.unit_selling_price*:NEW.ORDERED_QUANTITY), -- CHG0038661 - Dipta
                                                                  l_curr_code,
                                                                  l_cust_num,
                                                                  l_order_number);

               -- case balance is not null, raise message error
               IF l_calc_balance IS NOT NULL AND l_calc_balance < 0 THEN

                  -- set message and raise
                  l_resin_balance := xxoe_utils_pkg.get_resin_balance(l_cust_num,
                                                                      l_curr_code,
                                                                      l_order_number);
                  raise general_exception;
                  
                  -- raise_application_error(-20001, l_message);
               
               END IF; -- calc_balance  
            END IF; -- price < 0                                      
         END IF; -- order type
      END IF; -- resin credit
   END IF;
exception
  when general_exception then
    fnd_message.set_name('XXOBJT','XXOE_RESIN_CREDIT_ERR_MSG');
    fnd_message.set_token('RESIN_BALANCE',TRIM(to_char(l_resin_balance,'99,999,999.99')));
    fnd_message.set_token('CURR_CODE', l_curr_code);
    --  l_message := fnd_message.get;       
    app_exception.raise_exception;
  when others then null;   
END xxoe_resin_credit_balance_trg;
/
