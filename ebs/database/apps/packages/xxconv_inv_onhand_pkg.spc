CREATE OR REPLACE PACKAGE xxconv_inv_onhand_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_inv_onhand_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_inv_onhand_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Transfer Qty On Hand from old to new Organizations 
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  7.7.13     Vitaly       initial build
  ------------------------------------------------------------------
  PROCEDURE transfer_oh_qty(errbuf                 OUT VARCHAR2,
                            retcode                OUT VARCHAR2,
                            p_from_organization_id IN NUMBER,
                            p_to_organization_id   IN NUMBER);
  ----------------------------------------------------------------------------
  PROCEDURE transfer_oh_qty_tpl(p_from_organization_id IN NUMBER);

END xxconv_inv_onhand_pkg;
/
