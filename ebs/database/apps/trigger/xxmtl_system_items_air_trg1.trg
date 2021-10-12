create or replace trigger xxmtl_system_items_air_trg1
  after insert on MTL_SYSTEM_ITEMS_B
  for each row

when ( NEW.organization_id = 91 and  new.customer_order_enabled_flag = 'Y' /*and  new.inventory_item_status_code NOT IN
             ('XX_DISCONT', 'Obsolete', 'Inactive')*/ )
DECLARE
  l_oa2sf_rec     xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code      VARCHAR2(10)   := 0;
  l_err_desc      VARCHAR2(2500) := NULL;
  l_status_exists varchar2(10)   := 'N';
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_SYSTEM_ITEMS_AIR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of item
  --                   CUST776 - Customer support SF-OA interfaces CR 1215
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --  1.1  15/02/2015  Dalit A. Raviv    CHG0034398 - SFDC modifications
  --                                     SF decided to transfer Inactive items too.
  --------------------------------------------------------------------
  -- 1.1 15/02/2015 Dalit A. Raviv CHG0034398
  begin
    select 'Y'
    into   l_status_exists
    from   fnd_flex_values_vl       fv,
           fnd_flex_value_sets      fvs
    where  fv.flex_value_set_id     = fvs.flex_value_set_id
    and    fvs.flex_value_set_name  like 'XXSSYS_SF_EXCLUDE_ITEM_STATUS'
    and    fv.flex_value            =  :new.inventory_item_status_code
    and    nvl(fv.enabled_flag,'N') = 'Y'
    and    trunc(sysdate)           between nvl(fv.start_date_active,sysdate -1) and nvl(fv.end_date_active, sysdate +1);
  exception
    when others then
      l_status_exists := 'N';
  end;
  -- add if 1.1 15/02/2015 Dalit A. Raviv CHG0034398
  if l_status_exists = 'Y' then
    l_oa2sf_rec.source_id   := :new.inventory_item_id;
    l_oa2sf_rec.source_name := 'PRODUCT';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code => l_err_code, -- o v
                                                     p_err_msg => l_err_desc); -- o v
  end if;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_system_items_bur_trg1;
/
