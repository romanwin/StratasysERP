create or replace trigger xxoe_hold_sources_all_aur_t

  --------------------------------------------------------------------
  --  name:            XXOE_HOLD_SOURCES_ALL_AUR_T
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   release approval notification.
  --                   If user release the hold from the form, i need to continue the WF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  after update of released_flag on OE_HOLD_SOURCES_ALL
  for each row

  when ( new.released_flag = 'Y')
declare

  l_header_id number;
begin

  if fnd_profile.value('XXOM_AUTO_HOLD_ENABLE_CHECK') = 'Y' then

    if XXOM_AUTO_HOLD_PKG.check_hold_exist_at_setup (:NEW.hold_id) = 'Y' then
      select header_id
      into   l_header_id
      from   oe_order_holds_all t
      where  t.hold_source_id   = :NEW.hold_source_id
      and    t.order_hold_id    = :NEW.hold_id;

      -- submit concurrent
      XXOM_AUTO_HOLD_PKG.release_notification(l_header_id,:NEW.hold_id);

    end if; -- hold exists
  end if; -- profile

exception
  when others then
    null;
end;
/
