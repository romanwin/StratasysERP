create or replace trigger xxobjt_fsr_header_bir_trg1
  before insert on xxobjt_fsr_header
  for each row

declare
  l_org_id             number := null;
  l_customer_party_id  number := null;
  l_owner_party_id     number := null;
  l_cs_region          varchar2(150) := null;
begin
--------------------------------------------------------------------
--  name:            XXOBJT_FSR_HEADER_BIR_TRG1
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   30/08/2011 1:30:11 PM
--------------------------------------------------------------------
--  purpose :
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  30/08/2011  Dalit A. Raviv    initial build
--  1.1  14/12/2011  Dalit A. Raviv    change main select - to look only
--                                     on serial that is open
-------------------------------------------------------------------- 
  begin
    select hps.attribute3,       -- org id
           hps.party_id,         -- customer party id
           r.party_id,           -- contact relationship party id
           cii.attribute8        -- cs_region
    into   l_org_id,
           l_customer_party_id,
           l_owner_party_id,
           l_cs_region
    from   hz_parties             hp,
           hz_relationships       r,
           hz_parties             hpo,
           hz_parties             hps,
           csi_item_instances     cii,
           csi_instance_statuses  cis                      -- 1.1  14/12/2011  Dalit A. Raviv
    where  hp.party_number        = :NEW.registration_code  
    and    hp.party_id            = r.party_id
    and    r.object_type          = 'PERSON'
    and    r.object_table_name    = 'HZ_PARTIES'
    and    r.object_id            = hpo.party_id
    and    r.subject_id           = hps.party_id
    and    cii.owner_party_id(+)  = hps.party_id
    and    cii.serial_number(+)   = :NEW.serial_number     
    and    cis.instance_status_id = cii.instance_status_id -- 1.1  14/12/2011  Dalit A. Raviv
    and    cis.terminated_flag    = 'N';                   -- 1.1  14/12/2011  Dalit A. Raviv

    :NEW.org_id             := l_org_id;
    :NEW.customer_party_id  := l_customer_party_id;
    :NEW.owner_party_id     := l_owner_party_id;
    :NEW.cs_region          := l_cs_region;
  exception
    when others then
      :NEW.error_message := 'Trigger - Could not find additional data - '||
                            ' registration_code: '||:NEW.registration_code||'|'||
                            ' serial_number: '||:NEW.serial_number||'|'||
                            ' org_id: '||fnd_global.ORG_ID||
                            ' resp_id: '||fnd_global.RESP_ID||
                            ' resp_appl_id: '||fnd_global.RESP_APPL_ID||
                            ' user_id: '||fnd_global.USER_ID||
                            substr(sqlerrm,1,240);
  end;

exception
  when others then
    null;
end XXOBJT_FSR_HEADER_BIR_TRG1;
/
