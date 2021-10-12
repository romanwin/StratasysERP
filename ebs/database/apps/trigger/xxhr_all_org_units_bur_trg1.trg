create or replace trigger xxhr_all_org_units_bur_trg1
  before update on HR_ALL_ORGANIZATION_UNITS
  for each row

when ((nvl(NEW.attribute6,'DAR') <> nvl(OLD.attribute6,'DAR')) and (NEW.last_updated_by <> 4290))
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHR_ALL_ORG_UNITS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of : address6 (SF_id)
  --                   will check that the organziation is inventory organization
  --                   insert row to interface for all subinventories
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/01/2014  Dalit A. Raviv    initial build
  --                                     CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec     xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code      VARCHAR2(10) := 0;
  l_err_desc      VARCHAR2(2500) := NULL;
  l_inventory_org VARCHAR2(5) := 'N';

  CURSOR pop_c(p_organization_id IN NUMBER) IS
    SELECT p_organization_id || '|' || t.secondary_inventory_id source_id,
           'SUBINV' source_name
      FROM xxobjt_oa2sf_subinv_v t
     WHERE t.organization_id = p_organization_id;

BEGIN
  -- Check this organization is inventory organization
  BEGIN
    SELECT 'Y'
      INTO l_inventory_org
      FROM mtl_parameters
     WHERE organization_id = :new.organization_id;
  EXCEPTION
    WHEN OTHERS THEN
      l_inventory_org := 'N';
  END;

  -- By loop enter row to interface for alll subinv that are relate to this organization.
  IF l_inventory_org = 'Y' THEN
    FOR pop_r IN pop_c(:new.organization_id) LOOP
      l_oa2sf_rec.source_id   := pop_r.source_id;
      l_oa2sf_rec.source_name := pop_r.source_name;
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code => l_err_code, -- o v
                                                       p_err_msg => l_err_desc); -- o v
    END LOOP;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhr_all_org_units_bur_trg1;
/
