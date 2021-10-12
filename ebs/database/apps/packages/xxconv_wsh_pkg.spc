CREATE OR REPLACE PACKAGE xxconv_wsh_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_wsh_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_wsh_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Shipping Methods Assignments to new organizations 
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  8.7.13     Vitaly       initial build
  ------------------------------------------------------------------
  PROCEDURE org_carrier_assignment(errbuf                 OUT VARCHAR2,
                                   retcode                OUT VARCHAR2,
                                   p_from_organization_id IN NUMBER,
                                   p_to_organization_id   IN NUMBER);

END xxconv_wsh_pkg;
/
