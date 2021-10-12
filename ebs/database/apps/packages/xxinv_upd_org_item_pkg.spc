CREATE OR REPLACE PACKAGE xxinv_upd_org_item_pkg IS

  -----------------------------------------------------------
  -- copy_account_from_master_item
  -----------------------------------------------------------
  -- Version  Date          Performer       Comments
  ----------  ----------    --------------  ---------------------
  --   1.x    19.2.13        yuval tal        CR 676 Syncronize several Item Attributes from
  --                                          Master to Organization , add param  p_sync_entity
  --   1.1    07.07.13       yuval tal        CR 810 - add parameters to copy_account_from_master_item  
  --  1.2     9.9.13         vitaly           cr 967 add copy_account_from_master_item2 (interface version)
  --    
  -----------------------------------------------------------

  PROCEDURE copy_account_from_master_item(p_errbuff     OUT VARCHAR2,
                                          p_errcode     OUT VARCHAR2,
                                          p_sync_entity VARCHAR2,
                                          p_sync_org_id NUMBER,
                                          p_batch_size  NUMBER);

  PROCEDURE copy_account_from_master_item2(p_errbuff              OUT VARCHAR2,
                                           p_errcode              OUT VARCHAR2,
                                           p_sync_organization_id NUMBER,
                                           p_item                 VARCHAR2);

  PROCEDURE load_minmax_quantities(p_location IN VARCHAR2,
                                   p_filename IN VARCHAR2);

  FUNCTION get_org_coa_id(p_organization_id NUMBER) RETURN NUMBER;
  FUNCTION get_coa_name(p_coa_id NUMBER) RETURN VARCHAR2;
END xxinv_upd_org_item_pkg;
/
