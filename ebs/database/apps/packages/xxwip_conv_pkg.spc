CREATE OR REPLACE PACKAGE xxwip_conv_pkg AUTHID CURRENT_USER IS
  ------------------------------------------------------------------
  -- $Header: xxwip_conv_pkg   $
  ------------------------------------------------------------------
  -- Package: XXWIP_CONV_PKG
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose: 
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  07.10.13   Vitaly         initial build
  ------------------------------------------------------------------
  PROCEDURE copy_unreleased_jobs(errbuf                 OUT VARCHAR2,
                                 retcode                OUT VARCHAR2,
                                 p_from_organization_id IN NUMBER,
                                 p_to_organization_id   IN NUMBER,
                                 p_group_id             IN NUMBER,
                                 p_creation_date        IN VARCHAR2);

END xxwip_conv_pkg;
/
