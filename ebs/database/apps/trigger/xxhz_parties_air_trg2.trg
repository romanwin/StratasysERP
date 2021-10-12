create or replace trigger XXHZ_PARTIES_AIR_TRG2

  after insert on hz_parties
  for each row

when (NEW.party_type = 'PERSON' AND NEW.created_by_module in ('CSCCCCRC', 'SR'))
declare
  result BOOLEAN;
  req_id number;
begin
--------------------------------------------------------------------
--  name:            XXHZ_PARTIES_BIUR_TRG2
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   13/10/2010 1:30:11 PM
--------------------------------------------------------------------
--  purpose :        Trigger that will fire each party_type = 'PERSON'
--                   and created_by_module in ('CSCCCCRC', 'SR')
--                   The trigger will run concurent request XXHZ: Create Cust Account Role
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/10/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------
  /* Submit a request from a database trigger */
  result := FND_REQUEST.SET_MODE(TRUE);
  req_id := fnd_request.submit_request(application => 'XXOBJT',
                                       program     => 'XXHZ_CREATE_CUST_ACC_ROLE', -- XXHZ: Create Cust Account Role
                                       description => null,
                                       start_time  => null,
                                       sub_request => FALSE);

exception
  when others then
    null;
end XXHZ_PARTIES_AIR_TRG2;
/

