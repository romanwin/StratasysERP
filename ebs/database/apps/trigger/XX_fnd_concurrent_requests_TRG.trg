create or replace trigger xx_fnd_concurrent_requests_trg
  before insert on FND_CONCURRENT_REQUESTS
  for each row
   
  
when (NEW.CONCURRENT_PROGRAM_ID = 40178)
declare
  --------------------------------------------------------------------
  --  name:            XX_FND_CONCURRENT_REQUESTS_TRG
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   29/03/2012
  --------------------------------------------------------------------
  --  purpose :        CUST517 - Denied Parties solution / CUST671 - OM Auto Holds
  --                   hold seeded program (Pick Selection List Generation) for pre-check of DP
  --                   hold will be release in the end of checking 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/03/2012  yuval tal         initial build - CR507  Denied party Check before pick release
  --  1.1  22/04/2013  Dalit A. Raviv    change logic to support DP and Auto hold
  --                                     the trigger enter the program (40178) to hold and 
  --                                     call to program that handle the check for dp and Auto hold
  --                                     and release the hold on the program.
  --------------------------------------------------------------------

  l_err_msg       varchar2(1000) := null;
  l_err_code      varchar2(100)  := null;
begin

  -- can not use submit request from this trigger spesific because
  -- table APPLSYS.FND_CONCURRENT_REQUESTS is mutating
  -- therefor we call direct to procedure that it call submit request.
  if fnd_profile.value('XXOM_DP_ENABLE_CHECK') = 'Y'  or fnd_profile.value('XXOM_AUTO_HOLD_ENABLE_CHECK') = 'Y' then
    -- put request in hold
    :new.hold_flag := 'Y';
    XXOM_AUTO_HOLD_PKG.main(errbuf       => l_err_msg,                                                         -- o v
                            retcode      => l_err_code,                                                        -- o v
                            p_batch_id   => substr(:new.argument_text, 1, instr(:new.argument_text, ',') - 1), -- batch_id   i n
                            p_request_id => :new.request_id,                                                   -- request id i n
                            p_hold_stage => 'PICK');                                                           -- Hold stage i v
  end if; -- check profiles
end;
/
