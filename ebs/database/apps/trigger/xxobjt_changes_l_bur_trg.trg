create or replace trigger xxobjt_changes_l_bur_trg
  before UPDATE OF REQUEST_STATUS on XXOBJT_CHANGES_L
  for each row
declare
  -- local variables here
  l_err_msg  varchar2(500) := null;
  l_err_code number        := 0;
begin
--------------------------------------------------------------------
--  name:            XXOBJT_CHANGES_L_AUR_TRG
--  create by:       Dalit A. Raviv
--  Revision:        1.1
--  creation date:   07/01/2013
--------------------------------------------------------------------
--  purpose :        CUST534 - New screen to connect customization number to DB objects
--                   CR650   - Add history to request statuses
--
--                   2 triggers - after insert to enter the start status
--                              - after update to enter each update of status.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/01/2013  Dalit A. Raviv    initial build
--  1.1  20/01/2013  Dalit A. Raviv    change status changed by to be the OLD update by
--  1.2  24/10/2013  Dalit A. Raviv    Handle History to reflect only updates of Status feild
--  1.3  07/11/2013  Dalit A. Raviv    Correct trigger to supposrt only update case.
--------------------------------------------------------------------
  --  1.2  24/10/2013  Dalit A. Raviv
  if :NEW.REQUEST_STATUS <> nvl(:OLD.REQUEST_STATUS,'DR') then
    :new.STATUS_CHANGE_BY := :NEW.LAST_UPDATED_BY;
  end if;
  if (:NEW.REQUEST_STATUS <> :OLD.REQUEST_STATUS or :NEW.REQUEST_STATUS_DATE <> :OLD.REQUEST_STATUS_DATE) then
    xxobjt_changes_pkg.insert_history(p_request_id          => :NEW.REQUEST_ID,          -- i n
                                      p_change_id           => :NEW.CHANGE_ID,           -- i n
                                      p_request_status      => :OLD.REQUEST_STATUS,      -- i v
                                      p_request_status_date => :OLD.REQUEST_STATUS_DATE, -- i d -- 1.1  20/01/2013  Dalit A. Raviv
                                      p_status_changed_by   => :OLD.STATUS_CHANGE_BY,    -- i n :OLD.LAST_UPDATED_BY --  1.2  24/10/2013  Dalit A. Raviv
                                      p_last_updated_by     => :NEW.LAST_UPDATED_BY,     -- i n
                                      p_errbuf              => l_err_msg,                -- o v
                                      p_retcode             => l_err_code);              -- o n
  end if;

--exception
 -- when others then
  --  null;
end xxobjt_changes_l_Bur_trg;
/
