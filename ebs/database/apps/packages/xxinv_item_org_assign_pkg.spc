CREATE OR REPLACE PACKAGE xxinv_item_org_assign_pkg AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxinv_item_org_assign_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxinv_item_org_assign_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Item organization assignment from agile and conversion
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  ---------------------------------------------------------------------------
  PROCEDURE process_org_assignments(p_item_org_assign_tab IN OUT NOCOPY system.ego_item_org_assign_table,
                                    p_commit              IN VARCHAR2,
                                    p_context             IN VARCHAR2 DEFAULT NULL,
                                    x_return_status       OUT NOCOPY VARCHAR,
                                    x_msg_count           OUT NOCOPY NUMBER);
END xxinv_item_org_assign_pkg;
/
