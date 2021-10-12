create or replace trigger APPS.xxmtl_item_rev_b_bur_trg1
  before update on MTL_ITEM_REVISIONS_B
  for each row

when ( (NEW.organization_id = 91) and (NEW.last_updated_by <> 4290) and
      ((NEW.revision <> OLD.revision) or (NEW.effectivity_date <> OLD.effectivity_date) or (NEW.implementation_date <> OLD.implementation_date))
     )
DECLARE
 
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_ITEM_REV_B_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of item rev
  --                   CUST776 - Customer support SF-OA interfaces CR 1215
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  IF xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PRODUCT', :new.inventory_item_id) = 1 THEN
   
    l_oa2sf_rec.source_id   := :new.revision_id;
    l_oa2sf_rec.source_name := 'ITEMREV';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_system_items_bur_trg1;
/
