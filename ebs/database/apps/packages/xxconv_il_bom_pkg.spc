CREATE OR REPLACE PACKAGE xxconv_il_bom_pkg IS
  -- Purpose :
  -- Author  : DMN_SARIF
  -- Created : 15.08.2007
  -- Purpose :
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------  --------------  ------------------------------------
  --   1.0    15.08.2007  DMN_SARIF       initial build
  --   1.1    23.06.2013  Vitaly          copy_bom added for CR812
  --   2.0    20-02-2018    R.W.           CHG0041937 to procedure copy_bom added parametre
  --                                      p_copy_subinventory 
  --------------------------------------------------------------------------
  PROCEDURE bom_org_assignment(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
  -------------------------------------------------------------
  --PROCEDURE interface_validation(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
  -------------------------------------------------------------
  /* PROCEDURE insert_interface_bom(errbuf            OUT VARCHAR2,
  retcode           OUT VARCHAR2,
  p_organization_id IN NUMBER);*/
  ----------------------------------------------------------------
  PROCEDURE update_supply_type;
  ----------------------------------------------------------------
  --   Ver   When         Who             Description
  -- -----   ----------   --------------  ------------------------
  --   2.0   20-02-2018   R.W.            CHG0041937
  ----------------------------------------------------------------    
  PROCEDURE copy_bom(errbuf                 OUT VARCHAR2,
                     retcode                OUT VARCHAR2,
                     p_from_organization_id IN NUMBER,
                     p_assembly_item_id     IN NUMBER,
                     p_to_organization_id   IN NUMBER,
                     p_copy_subinventory    IN VARCHAR2 -- CHG0041937
                     );
END xxconv_il_bom_pkg;
/
