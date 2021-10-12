CREATE OR REPLACE TRIGGER xxap_suppliers_bur_trg
   ---------------------------------------------------------------------------
   -- $Header: xxap_suppliers_bur_trg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxap_suppliers_bur_trg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: define attribute2 for NON MRP Suppliers
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
BEFORE UPDATE OF vendor_type_lookup_code ON ap_suppliers
  FOR EACH ROW
 
when (NEW.vendor_type_lookup_code LIKE 'NON-MRP%')
BEGIN

   IF nvl(fnd_profile.VALUE('XXAP_ENABLE_SUPPLIERS_UPDATES'), 'N') = 'Y' THEN
   
      :NEW.attribute2 := 'None';
   
   END IF;

END xxpo_requisition_int_bir_trg;
/

