CREATE OR REPLACE TRIGGER xxap_suppliers_bir_trg
   ---------------------------------------------------------------------------
   -- $Header: XXAP_SUPPLIERS_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxap_suppliers_bir_trg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: define holds for new suppliers
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   --          17/09/2013   Ofer Suad    CR1016 NEW.hold_all_payments_flag :='Y';
   ---------------------------------------------------------------------------
BEFORE INSERT ON AP_SUPPLIERS
  FOR EACH ROW
 
BEGIN

   IF nvl(fnd_profile.VALUE('XXAP_ENABLE_SUPPLIERS_UPDATES'), 'N') = 'Y' THEN
   
      :NEW.hold_flag          := 'Y';
      :NEW.hold_all_payments_flag :='Y';
      :NEW.attribute_category := fnd_global.org_id;
      fnd_message.set_name('XXOBJT', 'XXAP_SUPP_INIT_HOLD_REASON');
      :NEW.purchasing_hold_reason := fnd_message.get;
   
   END IF;

END xxpo_requisition_int_bir_trg;
/
