CREATE OR REPLACE PACKAGE xxom_s3_event_pkg AS

  FUNCTION process_event(p_subscription_guid IN RAW,
                         p_event             IN OUT wf_event_t)

   RETURN VARCHAR2;

END xxom_s3_event_pkg;
/

