CREATE OR REPLACE PACKAGE xxcst_cogs_custom_wf_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxcst_cogs_custom_wf_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxcst_cogs_custom_wf_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: calculate cogs account
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  27/12/09  Hod             Intercompany changes
  --     1.2  03/12/13  Ofer Suad       CR 1102 Ssys changes .
  ---------------------------------------------------------------------------
  FUNCTION build_cogs_ccid(p_order_line_id   NUMBER,
                           p_order_type_ccid NUMBER,
                           p_line_type_ccid  NUMBER,
                           p_item_cogs_ccid  NUMBER,
                           p_cust_site_ccid  NUMBER,
                           p_inv_org_id      NUMBER,
                           p_sell_org_id     NUMBER,
                           p_source          VARCHAR2,
                           p_order_type_attr VARCHAR2,
                           p_order_dept_seg  gl_code_combinations.segment2%TYPE,
                           p_cust_location   gl_code_combinations.segment6%TYPE,
                           p_coa_id          org_organization_definitions.chart_of_accounts_id%TYPE,
                           
                           p_return_status OUT VARCHAR2,
                           p_error_msg     OUT VARCHAR2) RETURN NUMBER;
  PROCEDURE get_cogs_ccid(p_itemtype        IN VARCHAR2,
                          p_itemkey         IN VARCHAR2,
                          p_actid           IN NUMBER,
                          p_funcmode        IN VARCHAR2,
                          p_line_id         IN NUMBER,
                          p_inventory_id    IN NUMBER,
                          p_organization_id IN NUMBER,
                          p_org_id          IN NUMBER,
                          p_order_type_cogs IN NUMBER,
                          x_resultout       OUT NOCOPY VARCHAR2);

  /*** Called from `Generate Cost of Goods Sold Account` ***/
  PROCEDURE get_cogs_ccid_for_shpflxwf(itemtype  IN VARCHAR2,
                                       itemkey   IN VARCHAR2,
                                       actid     IN NUMBER,
                                       funcmode  IN VARCHAR2,
                                       resultout OUT NOCOPY VARCHAR2);

  /*** Called from `Inventory Cost of Goods Sold Account` ***/
  PROCEDURE get_cogs_ccid_for_invflxwf(itemtype  IN VARCHAR2,
                                       itemkey   IN VARCHAR2,
                                       actid     IN NUMBER,
                                       funcmode  IN VARCHAR2,
                                       resultout OUT NOCOPY VARCHAR2);

  /*** Called from `OM : Generate Cost of Goods Sold Account` ***/
  PROCEDURE get_cogs_ccid_for_oecogs(itemtype  IN VARCHAR2,
                                     itemkey   IN VARCHAR2,
                                     actid     IN NUMBER,
                                     funcmode  IN VARCHAR2,
                                     resultout OUT NOCOPY VARCHAR2);

END xxcst_cogs_custom_wf_pkg;
/
