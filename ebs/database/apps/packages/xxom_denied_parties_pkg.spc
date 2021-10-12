CREATE OR REPLACE PACKAGE xxom_denied_parties_pkg AS

  --------------------------------------------------------------------
  --  name:            XXOM_DENIED_PARTIES_PKG
  --  create by:       yuval tal
  --  Revision:        1.3
  --  creation date:   19.07.12
  --------------------------------------------------------------------
  --  purpose :        support OM order process
  --------------------------------------------------------------------
  --  ver  date         name             desc
  --  1.0  19.07.12     yuval tal        Initial Build CR465 cust 517
  --  1.1  09.12.12     yuval tal        CR507:Denied parties - check in pick release process
  --  1.2  06.03.13     yuval tal        CR689:Capture the releaser name when a release is done by Email
  --                                     add proc check_user_action_wf
  --                                     modify proc release_hold_wf : use wf new attribute CONTEXT_USER_MAIL to find user_id
  --  1.3  22/04/2013   Dalit A. Raviv   procedure pick_release_delivery_check take out handle of
  --                                     the release of the request hold(that changed at the trigger xx_fnd_concurrent_requests_trg
  --                                     change p_err_code_and p_err_message order
  --  1.4  23.11.17     Piyali Bhowmick  CHG0041843 - Add two new procedures:
  --                                     1.initiate_dp_hold_conc - Create a new program for applying hold on non-picked orders.
  --                                     2.initiate_dp_hold_wf - To initiate the DP Hold Workflow Process for a particular order line
  --  1.5  24-OCT-2018  Diptasurjya      CHG0044277 - Purge Denied Party audit table if order is closed/cancelled
  --------------------------------------------------------------------

  PROCEDURE check_denied_parties(p_reff_id          VARCHAR2,
                                 p_reff_name        VARCHAR2,
                                 p_company_name     IN VARCHAR2,
                                 p_person_name      VARCHAR2,
                                 p_address          VARCHAR2,
                                 p_country          VARCHAR2,
                                 p_xml_result       OUT VARCHAR2,
                                 p_err_code         OUT NUMBER,
                                 p_err_message      OUT VARCHAR2,
                                 p_denied_code      OUT VARCHAR2,
                                 p_risk_country     OUT VARCHAR2,
                                 p_bpel_instance_id OUT VARCHAR2,
                                 p_hold_flag        OUT VARCHAR2);

  PROCEDURE check_denied_parties(p_order_line_id    NUMBER,
                                 p_xml_result       OUT VARCHAR2,
                                 p_err_code         OUT NUMBER,
                                 p_err_message      OUT VARCHAR2,
                                 p_denied_code      OUT VARCHAR2,
                                 p_risk_country     OUT VARCHAR2,
                                 p_bpel_instance_id OUT VARCHAR2,
                                 p_hold_flag        OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   Roman W.   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  PROCEDURE check_denied_parties_oic(p_reff_id          IN VARCHAR2,
                                     p_reff_name        IN VARCHAR2,
                                     p_company_name     IN VARCHAR2,
                                     p_person_name      IN VARCHAR2,
                                     p_address          IN VARCHAR2,
                                     p_country          IN VARCHAR2,
                                     p_xml_result       OUT VARCHAR2,
                                     p_denied_code      OUT VARCHAR2,
                                     p_risk_country     OUT VARCHAR2,
                                     p_bpel_instance_id OUT VARCHAR2,
                                     p_hold_flag        OUT VARCHAR2,
                                     p_err_code         OUT NUMBER,
                                     p_err_message      OUT VARCHAR2);

  PROCEDURE check_denied_parties_wf(itemtype  IN VARCHAR2,
                                    itemkey   IN VARCHAR2,
                                    actid     IN NUMBER,
                                    funcmode  IN VARCHAR2,
                                    resultout OUT NOCOPY VARCHAR2);

  /* PROCEDURE http_parse(p_result      CLOB,
                         p_err_code    NUMBER,
                         p_err_message VARCHAR2);
  */
  PROCEDURE parse_result(p_result       CLOB,
                         p_err_code     OUT NUMBER,
                         p_err_message  OUT VARCHAR2,
                         p_denied_code  OUT VARCHAR2,
                         p_risk_country OUT VARCHAR2);

  PROCEDURE apply_hold(p_header_id    NUMBER,
                       p_org_id       NUMBER,
                       p_user_id      NUMBER,
                       p_hold_comment VARCHAR2,
                       p_err_code     OUT NUMBER,
                       p_err_message  OUT VARCHAR2);
  PROCEDURE apply_hold_wf(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2);

  PROCEDURE release_hold(p_header_id       NUMBER,
                         p_org_id          NUMBER,
                         p_user_id         NUMBER,
                         p_release_comment VARCHAR2,
                         p_err_code        OUT NUMBER,
                         p_err_message     OUT VARCHAR2);
  PROCEDURE release_hold_wf(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2);

  FUNCTION is_fdm_item(p_item_id NUMBER) RETURN VARCHAR2;

  PROCEDURE initiate_dp_param(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2);
  --------------------------------------------------------------------------
  -- initiate_dp_hold_conc

  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  23.11.17  piyali bhowmick     CHG0041843- Create a new program for applying hold on non-picked orders

  ---------------------------------
  PROCEDURE initiate_dp_hold_conc(p_err_code    OUT NUMBER,
                                  p_err_message OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- initiate_dp_hold_wf

  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  23.11.17  piyali bhowmick     CHG0041843- To initiate the DP Hold Workflow Process for a particular order line

  ---------------------------------
  PROCEDURE initiate_dp_hold_wf(p_err_code    OUT NUMBER,
                                p_err_message OUT VARCHAR2,
                                p_line_id     NUMBER,
                                p_item_key    OUT VARCHAR2,
                                p_user_key    OUT VARCHAR2
                                
                                );
		        
  PROCEDURE is_dp_check_needed(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_attributes_wf(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2);

  PROCEDURE get_next_dist_role(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2);
  PROCEDURE is_approve_notification_exists(itemtype  IN VARCHAR2,
                                           itemkey   IN VARCHAR2,
                                           actid     IN NUMBER,
                                           funcmode  IN VARCHAR2,
                                           resultout OUT NOCOPY VARCHAR2);

  PROCEDURE wait2dp_approval(itemtype  IN VARCHAR2,
                             itemkey   IN VARCHAR2,
                             actid     IN NUMBER,
                             funcmode  IN VARCHAR2,
                             resultout OUT NOCOPY VARCHAR2);

  FUNCTION is_open_dp_hold_exists(p_line_id NUMBER) RETURN VARCHAR2;

  PROCEDURE release_notification(p_order_header_id NUMBER);
  PROCEDURE release_notification_conc(p_err_code        OUT NUMBER,
                                      p_err_message     OUT VARCHAR2,
                                      p_order_header_id NUMBER);

  PROCEDURE pick_release_delivery_check(p_err_message OUT VARCHAR2,
                                        p_err_code    OUT NUMBER,
                                        p_batch_id    NUMBER,
                                        p_request_id  NUMBER);

  PROCEDURE submit_check_pick_conc(p_request_id NUMBER, p_batch_id NUMBER);
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2);

||||||| .r4781
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2);
             
=======
                                 itemkey   IN VARCHAR2,
                                 actid     IN NUMBER,
                                 funcmode  IN VARCHAR2,
                                 resultout OUT NOCOPY VARCHAR2);

>>>>>>> .r4792
  ------------------------------------------
  -- CHG0044277 - purge audit table record
  ------------------------------------------
  -- ver  date        name            desc
  -- 1.0  24-OCT-2018 Diptasurjya     CHG0044277 - Purge Denied Party audit table if order is closed/cancelled
  --------------------------------------------
<<<<<<< .mine
  PROCEDURE purge_dp_audit_table(p_err_code    OUT NUMBER,
		         p_err_message OUT VARCHAR2);
||||||| .r4781
  procedure purge_dp_audit_table(p_err_code    OUT NUMBER,
              p_err_message OUT VARCHAR2);
=======
  PROCEDURE purge_dp_audit_table(p_err_code    OUT NUMBER,
                                 p_err_message OUT VARCHAR2);
>>>>>>> .r4792

END;
/