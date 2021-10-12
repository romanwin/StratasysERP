CREATE OR REPLACE PACKAGE xxoe_order_wf_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxoe_order_wf_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxoe_order_wf_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Sales order approval process
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --    1.0  31/08/09                  Initial Build
  --    1.1  5.8.10                    FIX : XXOE_PRICE_ADJ item attribute calc (full discount 100%)
  --    1.2  20.5.11    yuval tal      add logic to  apply_line_hold CR 259
  --    1.3  28.7.11    yuval tal      add logic to  apply_line_hold CR 289
  --    1.4  30.10.11   yuval tal      initiate_approval_wf :change logic for  XXOE_PRICE_ADJ
  --    1.5  3.11.11    yuval tal      change logic in check_hold_condition_flag : move min price check to manual dicount condition
  --    1.6  2.2.2012   yuval tal      cr 368 :OM Order Lines Hold ? Release Freight 
  ---------------------------------------------------------------------------
  TYPE nlist_rec_type IS RECORD(
    NAME          wf_users.name%TYPE := fnd_api.g_miss_char,
    display_name  wf_users.display_name%TYPE := fnd_api.g_miss_char,
    email_address wf_users.email_address%TYPE := fnd_api.g_miss_char);

  TYPE nlist_tbl_type IS TABLE OF nlist_rec_type INDEX BY BINARY_INTEGER;

  notiflist        nlist_tbl_type;
  g_miss_notiflist nlist_tbl_type;
  g_miss_nlist_rec nlist_rec_type;

  PROCEDURE apply_line_hold(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout IN OUT VARCHAR2);

  PROCEDURE check_line_hold(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout IN OUT VARCHAR2);

  PROCEDURE set_notif_params(itemtype  IN VARCHAR2,
                             itemkey   IN VARCHAR2,
                             actid     IN NUMBER,
                             funcmode  IN VARCHAR2,
                             resultout IN OUT VARCHAR2);

  PROCEDURE set_notif_performer(itemtype  IN VARCHAR2,
                                itemkey   IN VARCHAR2,
                                actid     IN NUMBER,
                                funcmode  IN VARCHAR2,
                                resultout OUT NOCOPY VARCHAR2);

  FUNCTION get_devisor(p_devisor NUMBER) RETURN NUMBER;
  PRAGMA RESTRICT_REFERENCES(get_devisor, WNDS, WNPS);

  PROCEDURE set_attributes(itemtype  IN VARCHAR2,
                           itemkey   IN VARCHAR2,
                           actid     IN NUMBER,
                           funcmode  IN VARCHAR2,
                           resultout IN OUT VARCHAR2);

  PROCEDURE release_holds(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout IN OUT VARCHAR2);

  PROCEDURE initiate_approval_wf(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  -- RanS 24/12/09 - Addition
  PROCEDURE check_line_2close(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout IN OUT VARCHAR2);
  -- End RanS
  FUNCTION check_hold_condition_flag(p_line_id         NUMBER,
                                     p_condition_type  VARCHAR2,
                                     p_condition_value VARCHAR2,
                                     p_min_price2hold  NUMBER,
                                     p_unit_list_price NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_total_adj(p_line_id NUMBER, p_adj_type VARCHAR2) RETURN NUMBER;

  PROCEDURE check_approval_needed(itemtype  IN VARCHAR2,
                                  itemkey   IN VARCHAR2,
                                  actid     IN NUMBER,
                                  funcmode  IN VARCHAR2,
                                  resultout IN OUT VARCHAR2);
END xxoe_order_wf_pkg;

 
/
