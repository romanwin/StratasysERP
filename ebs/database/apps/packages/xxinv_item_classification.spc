CREATE OR REPLACE PACKAGE xxinv_item_classification IS
  --------------------------------------------------------------------
  --  name:               xxinv_item_classification
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      31.3.11
  --------------------------------------------------------------------
  --  purpose:      general item_classifications methods
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     31.3.11     yuval tal       initial build
  --  1.1     9.11.2011   yuval tal       add functions:
  --                                      get_last_trans_type_active, get_last_org_trans_active
  --                                      get_last_trans_qty_active, get_total_demand_by_item
  --  1.2     15.12.11                    change get_total_demand_by_item logic add
  --                                      AND dem.plan_id=msi.Plan_Id
  --  1.3     08.1.2012   yuval atl       get_last_rcv  : get price from po_line instead of rcv_trans
  --  1.4     06/02/2012  Dalit A. Raviv  new function is_contract_service_item
  --                                      check if item is SERVICE is_contract_service_item
  --  1.5     25.12.2013  Vitaly          cust 410 CR 1196 - add import_categories and upload categories
  --  1.6     27/03/2014  Dalit A. Raviv  add functions - is_item_POLYJET, is_item_FDM, is_item_RESIN, is_item_SP, is_item_FG
  --  1.7     03/12/2015  Gubendran K     Created new procedure upload_categories_pivot for the CR - CHG0033893
  --  1.8     14/06/2015  Michal Tzvik    CHG0035332 -  procedure upload_categories_pivot: remove parameter p_delete_all_flag
  --  1.9     30/04/2017  yuval tal       CHG0040061 add is_system_item modify
  --                                                 is_item_fdm : add new parameter p_organization_id
  --                                                 is_item_polyjet :add new parameter p_organization_id
  --  2.0     05/07/2018  Roman W.        INC0125761 - create procedure calculate MTL_SYSTEM_ITEMS_B.item_type by ...
  --  2.2     15/12/2019 Roman W.         CHG0047007 - Support N Technologies
  --                                         1) get_item_technology
  --                                         2) get_item_speciality_flavor
  --------------------------------------------------------------------

  FUNCTION get_category_by_set(p_organization_id   IN NUMBER,
                               p_inventory_item_id IN NUMBER,
                               p_category_set_id   IN NUMBER) RETURN VARCHAR2;
  FUNCTION get_item_system_family(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_item_system_sub_family1(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_item_system_sub_family2(p_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_preferred_vendor(p_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_id(p_segment1 VARCHAR2) RETURN NUMBER;

  FUNCTION get_product_line(p_code_combination_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_finish_good(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_spec_19(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_chm_weight(p_item_id NUMBER) RETURN NUMBER;
  FUNCTION get_chm_pack_of(p_item_id NUMBER) RETURN NUMBER;
  -- FUNCTION get_chm_mfg_parent_dept(p_item_id NUMBER) RETURN VARCHAR2;
  -- FUNCTION get_chm_mfg_dept(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_item_category_obj(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_concatenate_bom_by_part(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_conc_bom_family_by_part(p_item_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_last_rcv_po_price(p_item_id NUMBER, p_date DATE) RETURN NUMBER;
  PROCEDURE get_last_rcv_po_price(p_item_id         NUMBER,
                                  p_date            DATE,
                                  p_orig_currency   OUT VARCHAR2,
                                  p_orig_unit_price OUT NUMBER,
                                  p_unit_price_usd  OUT NUMBER);

  FUNCTION get_last_trans_type_active(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_last_org_trans_active(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;
  FUNCTION get_last_trans_qty_active(p_inventory_item_id NUMBER)
    RETURN NUMBER;

  FUNCTION get_total_demand_by_item(p_inventory_item_code VARCHAR2)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            is_contract_service_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/02/2012
  --------------------------------------------------------------------
  --  purpose :        check if item is SERVICE is_contract_service_item 06/02/2012
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_contract_service_item(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  -- import_categories
  -- CUST410 - Item Classification\CR1196 - Upload Item Categories
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  22.12.13    Vitaly         initial build
  --------------------------------------------------------------------
  PROCEDURE import_categories(errbuf                         OUT VARCHAR2,
                              retcode                        OUT VARCHAR2,
                              p_request_id                   IN NUMBER,
                              p_create_new_combinations_flag IN VARCHAR2,
                              p_mode                         IN VARCHAR2 DEFAULT 'SINGLE');
  --------------------------------------------------------------------
  -- upload_categories
  -- CUST410 - Item Classification\CR1196 - Upload Item Categories
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  22.12.13    Vitaly         initial build
  --------------------------------------------------------------------
  PROCEDURE upload_categories(errbuf                         OUT VARCHAR2,
                              retcode                        OUT VARCHAR2,
                              p_table_name                   IN VARCHAR2, ---hidden parameter----default value ='XXOBJT_CONV_CATEGORY' independent value set XXOBJT_LOADER_TABLES
                              p_template_name                IN VARCHAR2, ---dependent value set XXOBJT_LOADER_TEMPLATES
                              p_file_name                    IN VARCHAR2,
                              p_directory                    IN VARCHAR2,
                              p_create_new_combinations_flag IN VARCHAR2);

  --------------------------------------------------------------------
  -- upload_categories_pivot
  -- CHG0033893 - Item Classification - Upload Item Categories pivot
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  03.12.15    Gubendran K         initial build
  --     1.1  14.06.2015  Michal Tzvik  CHG0035332 -  remove parameter p_delete_all_flag
  --------------------------------------------------------------------
  PROCEDURE upload_categories_pivot(errbuf                         OUT VARCHAR2,
                                    retcode                        OUT VARCHAR2,
                                    p_category_set_name            IN VARCHAR2,
                                    p_file_name                    IN VARCHAR2,
                                    p_directory                    IN VARCHAR2,
                                    p_create_new_combinations_flag IN VARCHAR2
                                    /*p_delete_all_flag              IN VARCHAR2 DEFAULT 'N'*/);

  --------------------------------------------------------------------
  --  name:            is_item_polyjet
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is FDM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/05/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_item_polyjet(p_inventory_item_id IN NUMBER,
                           p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_item_fdm
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is FDM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/05/2014  Dalit A. Raviv    initial build
  -- 1.1 30.4.17       yuval tal         CHG0040061 add new parameter p_organization_id
  --------------------------------------------------------------------
  FUNCTION is_item_fdm(p_inventory_item_id IN NUMBER,
                       p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_item_resin
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --
  --  in params:       inventory_item_id
  --  out:             if this is a resin item Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_item_resin(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:               is_item_SP
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            general item_classifications methods
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     27/03/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_item_sp(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:               is_item_FG
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            Get if item is Finished good
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     27/03/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_item_fg(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:               is_item_Material
  --  create by:          OFER SUAD
  --  Revision:           1.0
  --  creation date:      27/03/2014
  --------------------------------------------------------------------
  --  purpose:            is_item_Material
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     08.07.14  OFER SUAD       CHANGE CHG0032527 - initial build
  --------------------------------------------------------------------

  FUNCTION is_item_material(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_system_item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30.4.17   yuval tal           CHG0040061 initial build
  --------------------------------------------------------------------
  FUNCTION is_system_item(p_inventory_item_id IN NUMBER,
                          p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  ---------------------------------------------------------------------------------------------------------------
  -- Ver      When         Who       Description
  -- -------  -----------  --------  ----------------------------------------------------------------------------
  --  1.0     05/07/2018   Roman W.  INC0125761 - create procedure calculate MTL_SYSTEM_ITEMS_B.item_type by ...
  ---------------------------------------------------------------------------------------------------------------
  function get_item_type(p_inventory_item_id NUMBER) return VARCHAR2;

  ----------------------------------------------------------------------------------------------------
  --  ver  When        Who               Descr
  -------- ----------- ----------------- -------------------------------------------------------------  
  --  1.0  15/12/2019  Roman W.          CHG0047007 - Support Multiple Technologies       
  ----------------------------------------------------------------------------------------------------
  function get_item_technology(p_inventory_item_id NUMBER) return VARCHAR2;

  ----------------------------------------------------------------------------------------------------
  --  ver  When        Who               Descr
  -------- ----------- ----------------- -------------------------------------------------------------  
  --  1.0  15/12/2019  Roman W.          CHG0047007 - Support Multiple Technologies       
  ----------------------------------------------------------------------------------------------------
  function get_item_speciality_flavor(p_inventory_item_id NUMBER)
    return VARCHAR2;

END xxinv_item_classification;
/
