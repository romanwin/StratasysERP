create or replace trigger xxmtl_system_items_bur_trg1
  before update on MTL_SYSTEM_ITEMS_B
  for each row

when (NEW.organization_id = 91 and   (new.customer_order_enabled_flag = 'Y' or (old.customer_order_enabled_flag = 'Y' and new.customer_order_enabled_flag = 'N')) )
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_SYSTEM_ITEMS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   06/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of item
  --                   when status changed at master organization
  --                   transfer only items that are related to SF ( check status relate to SF)
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    initial build
  --  1.1  06/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --------------------------------------------------------------------

  l_oa2sf_rec.source_id   := :new.inventory_item_id;
  l_oa2sf_rec.source_name := 'PRODUCT';
  xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				   p_err_code  => l_err_code, -- o v
				   p_err_msg   => l_err_desc); -- o v
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_system_items_bur_trg1;
/
