CREATE OR REPLACE PACKAGE xxconv_bom_pkg IS
  -- Purpose :
  -- Author  : DMN_SARIF
  -- Created : 15.08.2007
  -- Purpose : 
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ------------------------------------
  --   1.0    15.08.2007  DMN_SARIF     initial build
  --   1.1    23.06.2013  Vitaly        copy_bom added for CR812   
  --------------------------------------------------------------------------
  PROCEDURE bom_org_assignment(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
  -------------------------------------------------------------
  PROCEDURE interface_validation(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
  -------------------------------------------------------------
  PROCEDURE insert_interface_bom(errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_organization_id IN NUMBER);
  ----------------------------------------------------------------
  PROCEDURE update_supply_type;
  ----------------------------------------------------------------
  PROCEDURE copy_bom(errbuf                 OUT VARCHAR2,
                     retcode                OUT VARCHAR2,
                     p_from_organization_id IN NUMBER,
                     p_assembly_item_id     IN NUMBER,
                     p_to_organization_id   IN NUMBER);
  ----------------------------------------------------------------
END xxconv_bom_pkg;
/
