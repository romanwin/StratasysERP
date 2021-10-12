CREATE OR REPLACE PACKAGE xxinv_bom_util_pkg IS

  --------------------------------------------------------------------
  --  customization code: XXINV_BOM_PKG
  --  name:               XXINV_BOM_PKG
  --  Revision:           1.1
  --  create by:          YUVAL TAL
  --  creation date:      05.12.10
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   08/03/2006    YUVAL TAL       initial build
  --  1.1   11/06/2014    Dalit A. Raviv  Procedure schedule_bom_explode change population logic
  --                                      add new parameter to run bom explode  per assembly
  --  2.0   08/03/2018   Roman.W         CHG0041937 - addede procedure "xxinv_bomcopy_casing" called from 
  --                                     concurrent "XXINV_BOMCOPY_CASING / XX: INV XXBOM Copy Bom Casing"
  --                                     Read items data from file and submit concurrent "XXBOMCOPY"
  --  2.1   11/03/2018   Roman.W         CHG0041951 - added procedure "xxinv_bompcmbm_casing" calling from
  --                                     concurrent "XXINV_BOMPCMBM_CASING / XX: INV Create Common Bills Casing".
  --                                     Procedure read data from file and submit concurrent "BOMPCMBM"
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom_Phantom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom_phantom(p_assembly_item_id  IN NUMBER,
                                p_id                IN NUMBER,
                                p_revision_date     IN DATE,
                                p_organization_id   IN NUMBER,
                                p_explode_option    IN NUMBER,
                                p_impl_flag         IN NUMBER,
                                p_levels_to_explode IN NUMBER, --1,
                                p_bom_or_eng        IN NUMBER, -- 1, --BOM
                                p_module            IN NUMBER, -- 2, -- BOM
                                p_std_comp_flag     IN NUMBER,
                                p_qty               IN NUMBER);

  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom(p_assembly_item_id  IN NUMBER,
                        p_id                IN NUMBER,
                        p_revision_date     IN DATE,
                        p_organization_id   IN NUMBER,
                        p_explode_option    IN NUMBER, -- 1 - All,  2 - Current, 3 - Current and future
                        p_impl_flag         IN NUMBER, -- 1 - implemented only,  2 - both impl and unimpl
                        p_levels_to_explode IN NUMBER, --1,
                        p_bom_or_eng        IN NUMBER, -- 1, --BOM
                        p_module            IN NUMBER, -- 2, -- BOM
                        p_std_comp_flag     IN NUMBER, -- 2,
                        p_qty               IN NUMBER);

  --------------------------------------------------------------------
  -- customization code:cust
  -- name: Explode_Bom_With_Phantom
  -- create by: Tamara Karavani
  -- creation date:  28/06/2006
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------

  PROCEDURE explode_bom_with_phantom(p_assembly_item_id  IN NUMBER,
                                     p_id                IN NUMBER,
                                     p_revision_date     IN DATE,
                                     p_organization_id   IN NUMBER,
                                     p_explode_option    IN NUMBER, -- 1 - All,  2 - Current, 3 - Current and future
                                     p_impl_flag         IN NUMBER, -- 1 - implemented only,  2 - both impl and unimpl
                                     p_levels_to_explode IN NUMBER, -- 1,
                                     p_bom_or_eng        IN NUMBER, -- 1 - BOM, 2 - ENG
                                     p_module            IN NUMBER, -- 1 - Costing, 2 - Bom, 3 - Order entry
                                     p_std_comp_flag     IN NUMBER, -- 1 - explode only standard components, 2 - all components
                                     p_qty               IN NUMBER);
  --------------------------------------------------------------------
  -- customization code:cust44
  -- name: Explode_Bom_no_Phantom
  -- create by: Ida
  -- creation date:  29/11/2005
  --------------------------------------------------------------------
  -- input :
  --------------------------------------------------------------------
  -- process :
  -- ouput   :
  -- depend on :
  --------------------------------------------------------------------
  PROCEDURE explode_bom_no_phantom(p_assembly_item_id IN NUMBER,
                                   --p_id                IN NUMBER,
                                   p_revision_date     IN DATE,
                                   p_organization_id   IN NUMBER,
                                   p_explode_option    IN NUMBER,
                                   p_impl_flag         IN NUMBER,
                                   p_levels_to_explode IN NUMBER, -- 1,
                                   p_bom_or_eng        IN NUMBER, -- 1, --BOM
                                   p_module            IN NUMBER, -- 2, -- BOM
                                   p_std_comp_flag     IN NUMBER,
                                   p_qty               IN NUMBER);

  PROCEDURE scheduale_bom_explode(errbuf             OUT VARCHAR2,
                                  retcode            OUT NUMBER,
                                  p_assembly_item_id in number);

  --PROCEDURE currency_bom_explode(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  ---------------------------------------------------------------------------------------------------------------
  -- Ver      Who       When           Description 
  -- -------  --------  -------------  --------------------------------------------------------------------------
  -- 2.0      Roman.W   08/03/2018     CHG0041937 - Common BOM at OMA - XXBOM Copy BOM
  ---------------------------------------------------------------------------------------------------------------                            
  procedure xxinv_bomcopy_casing(errbuf                OUT VARCHAR2,
                                 retcode               OUT VARCHAR2,
                                 p_org_id_from         IN VARCHAR2,
                                 p_org_id_to           IN VARCHAR2,
                                 p_file_name           IN VARCHAR2,
                                 p_directory_from_list IN VARCHAR2,
                                 p_directory_name      IN VARCHAR2,
                                 p_directory_path      IN VARCHAR2,
                                 p_concurent_max_count IN NUMBER);

  ---------------------------------------------------------------------------------------------------------------
  -- Ver      Who       When           Description 
  -- -------  --------  -------------  --------------------------------------------------------------------------
  -- 2.1      Roman.W   08/03/2018     CHG0041951 - Development - Common BOM at OMA - XX table load definition 
  ---------------------------------------------------------------------------------------------------------------
  procedure xxinv_bompcmbm_casing(errbuf                   OUT VARCHAR2,
                                  retcode                  OUT VARCHAR2,
                                  p_file_name              IN VARCHAR2,
                                  p_defauld_directory_name IN VARCHAR2,
                                  p_new_directory_name     IN VARCHAR2,
                                  p_new_directory_path     IN VARCHAR2,
                                  p_concurent_max_count    IN NUMBER);

END xxinv_bom_util_pkg;
/
