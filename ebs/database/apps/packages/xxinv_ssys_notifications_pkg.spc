CREATE OR REPLACE PACKAGE xxinv_ssys_notifications_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST540
  --  name:               xxinv_ssys_notifications_pkg
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  ----------------------------------------------------------------------- 

  PROCEDURE create_items_notification(p_document_id   IN VARCHAR2,
                                      p_display_type  IN VARCHAR2,
                                      p_document      IN OUT CLOB,
                                      p_document_type IN OUT VARCHAR2);

  PROCEDURE upd_items_min_max_notification(p_document_id   IN VARCHAR2,
                                           p_display_type  IN VARCHAR2,
                                           p_document      IN OUT CLOB,
                                           p_document_type IN OUT VARCHAR2);

  PROCEDURE add_lines_to_bpa_notification(p_document_id   IN VARCHAR2,
                                          p_display_type  IN VARCHAR2,
                                          p_document      IN OUT CLOB,
                                          p_document_type IN OUT VARCHAR2);

  PROCEDURE add_ssys_item_cost_notificat(p_document_id   IN VARCHAR2,
                                         p_display_type  IN VARCHAR2,
                                         p_document      IN OUT CLOB,
                                         p_document_type IN OUT VARCHAR2);

END xxinv_ssys_notifications_pkg;
/
