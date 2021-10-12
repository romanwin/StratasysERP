CREATE OR REPLACE PACKAGE xxfnd_event_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  --  name:               xxfnd_event_pkg
  --  create by:          DCHATTERJEE
  --  $Revision:          1.0
  --  creation date:      05-NOV-2019
  --  Purpose :           FND Business event handler package
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05-NOV-2019   Diptasurjya     CHG0045880 - Initial Build
  -----------------------------------------------------------------------   


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          This function will be used as Rule function for activated business events
  --          for concurrent request
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  04-NOV-2019  Diptasurjya Chatterjee        CHG0045880 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION conc_request_event_process(p_subscription_guid IN RAW,
              p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;
END xxfnd_event_pkg;
/
