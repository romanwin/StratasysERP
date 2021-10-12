CREATE OR REPLACE PACKAGE xxcst_upload_cost_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxcst_upload_cost_pkg.spc 4003 2018-06-26 06:40:05Z DAN.MELAMED $
  ---------------------------------------------------------------------------
  -- Package: xxcst_upload_cost_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Load Std Costing to the new organizations
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.6.13     Vitaly       initial build
  --     1.1  09.06.2014  Gary Altman  CHG0032185  add fg_rollup procedure to run Cost Rollup for the Finish Good
  --     1.2  24.06.2014 Gary Altman    CHG0032215  add procedure buy_items_auto_update updating Material Standard Costs for Buy Items
  --     1.3  06-Jun-2018 Dan Melamed    CHG0042784  Add Cost type parameter (instead of hard coded 'Pending'
  ------------------------------------------------------------------
  PROCEDURE upload_overhead(errbuf                OUT VARCHAR2,
                            retcode               OUT VARCHAR2,
                            p_mfg_organization_id IN VARCHAR2);


  -----------------------------------------------------------------------------
  -- upload_cost
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  --     1.0  11.6.13     Vitaly           initial build
  --     1.1  05-Jun-2018 Dan Melamed      CHG0042784 - Add Cost type parameter (instead of hard coded 'Pending'
  -----------------------------------------------------------------------------
  PROCEDURE upload_cost(errbuf          OUT VARCHAR2,
                        retcode         OUT VARCHAR2,
                        p_table_name    IN VARCHAR2,
                        p_template_name IN VARCHAR2,
                        p_file_name     IN VARCHAR2,
                        p_directory     IN VARCHAR2,
                         p_cost_type     IN VARCHAR2);  --CHG0042784 DAN.Melamed 05-Jun-2018 : Add Cost type parameter (instead of hard coded 'Pending');

  PROCEDURE fg_rollup(errbuf                 OUT VARCHAR2,
                      retcode                OUT VARCHAR2,
                      p_table_name           IN VARCHAR2,
                      p_template_name        IN VARCHAR2,
                      p_file_name            IN VARCHAR2,
                      p_directory            IN VARCHAR2);

  PROCEDURE buy_items_auto_update(errbuf                 OUT VARCHAR2,
                                  retcode                OUT VARCHAR2,
                                  p_org_id              IN VARCHAR2);

END xxcst_upload_cost_pkg;
/
