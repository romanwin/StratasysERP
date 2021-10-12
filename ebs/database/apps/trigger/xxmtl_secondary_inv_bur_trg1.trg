create or replace trigger xxmtl_secondary_inv_bur_trg1
  before update on MTL_SECONDARY_INVENTORIES
  for each row

when (((NEW.secondary_inventory_name <> OLD.secondary_inventory_name) or (nvl(NEW.disable_date,sysdate - 1000) <> nvl(OLD.disable_date,sysdate -1000)) )
     and (NEW.last_updated_by <> 4290))
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_sf_id     VARCHAR2(240) := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_SECONDARY_INV_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of suninventory
  --                   CUST776 - Customer support SF-OA interfaces CR 1215
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  -- check this subinv relate to SF
  l_sf_id := xxobjt_oa2sf_interface_pkg.get_entity_sf_id('ORG', :new.organization_id);

  IF l_sf_id IS NOT NULL THEN
    l_oa2sf_rec.source_id   := :new.organization_id || '|' ||
                               :new.secondary_inventory_name;
    l_oa2sf_rec.source_name := 'SUBINV';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_secondary_inv_air_trg1;
/
