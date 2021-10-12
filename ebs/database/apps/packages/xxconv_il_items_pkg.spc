CREATE OR REPLACE PACKAGE xxconv_il_items_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_items_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_items_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: item conversions , data fix...
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --        xx/xx/xxxx              initial buid  
  --  1.1   15.5.13    vitaly       insert_items_into_all_org changed (CR739)
  --  1.2    1.6.13    vitaly       update_item_org_attributes added  (CR727)
  --  1.3   12.6.13    vitaly       copy_item_revisions added         (CR810)
  --  1.4   14.8.13    vitaly       rename insert_items_into_all_org to item_org_assignment (CR810)
  --                                parameter p_master_organization_id was removed from item_org_assignment
  --                                apps_initialize was removed from item_org_assignment 
  --  1.5   14.8.13    vitaly       copy_organization_planner added (CR810)
  --  1.6   18.8.13    Vitaly       CR 870 std cost - change hard-coded organization
  ------------------------------------------------------------------
  PROCEDURE insert_interface_master(errbuf                   OUT VARCHAR2,
                                    retcode                  OUT VARCHAR2,
                                    p_master_organization_id IN NUMBER);

  PROCEDURE org_items_conv(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  PROCEDURE insert_interface_org(errbuf                   OUT VARCHAR2,
                                 retcode                  OUT VARCHAR2,
                                 p_master_organization_id IN NUMBER);

  PROCEDURE assign_wpi_org;

  PROCEDURE assign_last_revision;

  PROCEDURE update_def_receiving_subinv;

  PROCEDURE item_org_assignment(errbuf          OUT VARCHAR2,
                                retcode         OUT VARCHAR2,
                                p_table_name    IN VARCHAR2, ---hidden parameter----default value ='XXOBJT_CONV_ITEMS' independent value set XXOBJT_LOADER_TABLES
                                p_template_name IN VARCHAR2, ---dependent value set XXOBJT_LOADER_TEMPLATES
                                p_file_name     IN VARCHAR2,
                                p_directory     IN VARCHAR2);

  PROCEDURE update_ssys_item(errbuf      OUT VARCHAR2,
                             retcode     OUT VARCHAR2,
                             p_location  IN VARCHAR2,
                             p_file_name IN VARCHAR2);

  PROCEDURE update_ssys_item_list_price(errbuf      OUT VARCHAR2,
                                        retcode     OUT VARCHAR2,
                                        p_location  IN VARCHAR2,
                                        p_file_name IN VARCHAR2);

  PROCEDURE update_item_org_attributes(errbuf  OUT VARCHAR2,
                                       retcode OUT VARCHAR2);

  PROCEDURE copy_item_revisions(errbuf               OUT VARCHAR2,
                                retcode              OUT VARCHAR2,
                                p_to_organization_id IN NUMBER,
                                p_inventory_item_id  IN NUMBER);

  ---- Open Interface-----
  PROCEDURE copy_organization_planner(errbuf                 OUT VARCHAR2,
                                      retcode                OUT VARCHAR2,
                                      p_from_organization_id IN NUMBER,
                                      p_to_organization_id   IN NUMBER);
  ---- API ---------------
  PROCEDURE copy_organization_planner2(errbuf                 OUT VARCHAR2,
                                       retcode                OUT VARCHAR2,
                                       p_from_organization_id IN NUMBER,
                                       p_to_organization_id   IN NUMBER);

END xxconv_il_items_pkg;
/
