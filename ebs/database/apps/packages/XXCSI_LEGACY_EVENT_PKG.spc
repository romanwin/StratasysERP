create or replace
PACKAGE XXCSI_LEGACY_EVENT_PKG
-- +===================================================================+
-- |                         Stratesys                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Package Name     : XXCSI_LEGACY_EVENT_PKG                          |
-- |                                                                   |
-- |Description      : This package is used in the Custom Event subscription
-- |                   to catch the entity id and parameters for custom event
-- |                    and insert into xxssys_events
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
AS
FUNCTION ProcessEvent(
    p_subscription_guid IN RAW,
    p_event             IN OUT wf_event_t)
  return varchar2;
  END;
 /