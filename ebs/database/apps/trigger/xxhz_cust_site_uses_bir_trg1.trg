create or replace trigger xxhz_cust_site_uses_bir_trg1
  before Insert on HZ_CUST_SITE_USES_ALL
  for each row

 
when ((NEW.site_use_code  in ('BILL_TO','SHIP_TO') ) and (NEW.last_updated_by <> 4290))
DECLARE
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_user_id   NUMBER := NULL;
  l_entity_id NUMBER := NULL;

BEGIN
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_SITE_USES_BIR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.2 
  --  creation date:   07/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of new site use
  --                   will check: 1)that the cust_acct_site_id is relate to SF (att4 keep SF_ID or att5 = Y)
  --                   2) if there is a row at interface tbl XXOBJT_OA2SF_INTERFACE
  --                   if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2010  Dalit A. Raviv    initial build
  --  1.1  25/11/2010  Dalit A. Raviv    when SF send new site this trigger raise.
  --                                     this is a problem because we do not want to 
  --                                     create the same site again at sf.
  --  1.2  05/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     check that this account site relate to party 
  --                                     from type ORGANIZATION
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------  

  -- get user SALESFORCE id
  BEGIN
    SELECT user_id
      INTO l_user_id
      FROM fnd_user fu
     WHERE fu.user_name = 'SALESFORCE';
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
  -- check if user create this site is SALESFORCE and the creation is now 
  -- this site come from SF itself , so we do not need to create it in SF
  IF :new.created_by = l_user_id /*and :NEW.creation_date between sysdate - (15/ (24 * 60)) and sysdate*/
   THEN
    NULL;
  ELSE
    -- Check_party_type (p_entity varchar2,p_entity_id varchar2)   
    l_entity_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('SITE_USE',
                                                             :new.cust_acct_site_id);
    IF l_entity_id IS NOT NULL THEN
      l_oa2sf_rec.source_id   := :new.cust_acct_site_id;
      l_oa2sf_rec.source_name := 'SITE';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    END IF; -- l_flag
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_cust_site_uses_bir_trg1;
/
