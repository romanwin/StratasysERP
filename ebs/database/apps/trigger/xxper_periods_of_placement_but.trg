create or replace trigger xxper_periods_of_placement_but
before /*insert or*/ update on PER_PERIODS_OF_PLACEMENT
for each row
when (NEW.actual_termination_date is not null)
declare
  l_request_id  number        := null;
  --l_template    boolean;
begin
--------------------------------------------------------------------
--  name:            XXPER_PERIODS_OF_PLACEMENT_BUT
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   11/05/2011 Happy 19 Birthday My Li-Or
--------------------------------------------------------------------
--  purpose :        Trigger that will fire each update of actual termination date
--                   for each contractor that finish to work at Objet.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  11/05/2011  Dalit A. Raviv    initial build
--  1.1  30/11/2011  Dalit A. Raviv    the trigger submit request for the program
--                                     and in the program i handle the add layout.
--------------------------------------------------------------------
  if :NEW.actual_termination_date <> nvl(:OLD.actual_termination_date, :NEW.actual_termination_date-1) then
    -- Set mode
    if  FND_REQUEST.set_mode(TRUE) then
      -- run concurrent that is the main program:
      -- 1) run report
      -- 2) weit for completion
      -- 3) send mail
      -- XXHR_OUTGOING_FORM_PROG -> XXHR: OutGoing Form - Program
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXHR_OUTGOING_FORM_PROG',
                                                 description => null,
                                                 start_time  => null,
                                                 sub_request => FALSE,
                                                 argument1   => :new.person_id );

      dbms_output.put_line('Request Id - '||l_request_id);     
    end if; -- set mode
  end if;
exception
  when others then
    null;
end XXPER_PERIODS_OF_PLACEMENT_BUT;
/
