create or replace package xxinv_utils_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 24/5/2009 19:57:18
  -- Purpose :
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --
  --   1.1    12.9.2010     yuval tal      add get_revision4date
  --   1.2    3.10.10       yuval tal      add line_id to   get_avail_to_reserve
  --   1.3    10.10.10      yuval tal      add get_item_full_leadtime    + get_mfg_mfg_part
  --   1.4    22.1.10       yuval tal      add logic to org_assignment - support POS to be defines like POH in the Agile
  --   1.5    5.12.10       yuval tal      add function get_oh_qty_string  +get_buyer_id
  --   1.6    26.12.10      yuval  tal     add check_disallowed_hasp_in_req + check_hasp_item_allowed
  --   1.7    28.12.10      yuval tal      add is_sub_inventory_asset+ check_asset_sub_inv_status
  --   1.8    1.2.11        yuval tal      add is_hazard_item
  --   1.9    31.7.11       yuval tal      procedure : get_oh_qty : change logic
  --   2.0    07.12.11      yuval tal      add logic to org_assignment  : UOP as UOC
  --   2.1    23.05.12      yuval tal      add Is_TPL_SUB function
  --   2.2    26.7.12       yuval tal      add get_resin_item_kg_rate
  --   2.3    11.02.13      yuval tal      add is_fdm_item,add get_item_supplier
  --   2.3.5  23.6.13       yuval tal      CR832- Assign Item to JOO,JOT : add logic to org_assignment - support JOO,JOT to be defines like EOT in the Agile
  --   2.4    23.4.13       yuval tal      add get_item_desc_tl
  --   2.5    16.05.13      Vitaly         add get_qty_factor_jpn
  --   2.6    26.05.13      Vitaly         get_serials_and_lots was modifyed for cr724
  --   2.7    02.06.13      Vitaly         get_print_inv_uom_tl added for cr 731
  --          30/06/2013    Dalit A. Raviv new function is_fdm_system_item (for VSOE CR429)
  --   2.8    30.7.13       yuval tal      add update_group_mark_id- CUST439 - INV General\439 Delete Group Mark ID
  --   2.9    05.08.13      Vitaly         CR811- select in cursor csr_org_assign was changed (see sub-select "org")
  --   3.0    18.08.13      Vitaly         CR 870 std cost - change hard-coded organization; change cost_type_id=2 (Average) to fnd_profile.value('XX_COST_TYPE')
  --   3.1    18.08.13      yuval tal      CR936-Change the get_avail_to_reserve quantity to return  quantity by list sub inventory
  --   3.2    22.04.14      sanjai misra   Modified this pkg for CHG31742
  --                                       Added following function
  --                                       1. get_tariff_code
  --                                       2. get_category_value
  --   3.3    28.04.14      sandeep akula  Added Function GET_STD_CST_BSD_ORGS_IN_LOOKUP (CHG0031469)
  --   3.4    08/06/2014    yuval tal      CHG0032388 - add function get_item_catalog_value
  --   3.5    11.6.14       yuval tal      change CHG0032103: add get_category_segment
  --   3.6    7.7.14        yuval tal      CHG0032699 add get_item_id
  --   3.7    09/11/2014    Dalit A. Raviv CHG0034134 add function - get_related_item
  --   3.8    30/03/2015    Michal Tzvik   CHG0034935 Add function get_organization_id
  --   3.9    10/05/2015    Dalit A. Raviv CHG0034558 add function get_org_code
  --   4.0    10/06/2015    Michal Tzvik   CHG0035332 add function get_sp_technical_category
  --   4.1    09/21/2015    Diptasurjya    CHG0036213 add function is_aerospace_item
  --                        Chatterjee
  --   4.2    07/Oct/2015   Dalit A. Raviv CHG0035915 add function get_weight_uom_code
  --   4.3    07/Mar/2016   Lingaraj Sarangi CHG0037886 add function is_item_restricted
  --   4.4    05/MAR/2017   Dovik Pollak     CHG0040117 -  New function Added - get_sourcing_buyer_id
  --   4.5    06/03/2018    bellona banerjee CHG0041294 -  Added P_Delivery_Name to 
  --										check_asset_sub_inv_status for delivery id to name conversion
  ---------------------------------------------------------------------------
  FUNCTION get_item_id(p_item_code VARCHAR2) RETURN NUMBER;

  FUNCTION get_resin_item_kg_rate(p_inventory_item_id NUMBER) RETURN NUMBER;

  FUNCTION is_tpl_sub(p_organization_id    NUMBER,
              p_sub_inventory_code VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_current_revision(p_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE,
                p_organization_id   mtl_system_items_b.organization_id%TYPE)
    RETURN VARCHAR2;
  PRAGMA RESTRICT_REFERENCES(get_current_revision, WNDS, WNPS);

  FUNCTION get_future_revision(p_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE,
               p_organization_id   mtl_system_items_b.organization_id%TYPE,
               x_effectivity_date  OUT DATE) RETURN VARCHAR2;

  FUNCTION get_lookup_meaning(p_lookup_type VARCHAR2,
              p_lookup_code VARCHAR2) RETURN VARCHAR2;
  PRAGMA RESTRICT_REFERENCES(get_lookup_meaning, WNDS, WNPS);

  FUNCTION get_avail_to_reserve(p_inventory_item_id NUMBER,
                p_organization_id   NUMBER,
                -- Dalit A. Raviv 03/12/2009
                p_subinventory      VARCHAR2 DEFAULT NULL,
                p_locator_id        NUMBER DEFAULT NULL,
                p_is_serial_control NUMBER DEFAULT NULL,
                p_revision          VARCHAR2 DEFAULT NULL,
                p_lot_number        VARCHAR2 DEFAULT NULL,
                p_line_id           NUMBER DEFAULT NULL)
    RETURN NUMBER;

  FUNCTION get_avail_to_transact(p_inventory_item_id NUMBER,
                 p_organization_id   NUMBER,
                 p_subinventory      VARCHAR2 DEFAULT NULL,
                 p_locator_id        NUMBER DEFAULT NULL,
                 p_is_serial_control NUMBER DEFAULT NULL,
                 p_revision          VARCHAR2 DEFAULT NULL,
                 p_lot_number        VARCHAR2 DEFAULT NULL)
    RETURN NUMBER;

  PROCEDURE org_assignment(p_inventory_item_id NUMBER,
           p_item_code         VARCHAR2,
           p_group             VARCHAR2,
           p_family            VARCHAR2 DEFAULT NULL,
           x_return_status     OUT VARCHAR2,
           x_err_message       OUT VARCHAR2);

  FUNCTION get_organization_id_to_assign(p_inv_item_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_bom_organization(p_category IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_master_organization_id(p_organization_id NUMBER DEFAULT NULL)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:               get_organization_id
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      30/03/2015
  --  Description:        return organization_id of given organization_code
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/03/2015    Michal Tzvik    CHG0034935 - Initial build
  --------------------------------------------------------------------
  FUNCTION get_organization_id(p_organization_code VARCHAR2) RETURN NUMBER;

  FUNCTION get_default_category_set_id(p_func_area VARCHAR2 DEFAULT 'Inventory')
    RETURN NUMBER;

  FUNCTION item_routing_exists(p_item_id NUMBER,
               p_org_id  NUMBER) RETURN VARCHAR2;

  FUNCTION item_in_price_list(p_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION item_in_asl(p_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_formulation(p_item_id NUMBER,
                p_org_id  NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_ms(p_item_id NUMBER,
               p_org_id  NUMBER) RETURN VARCHAR2;

  FUNCTION item_has_sourcing_rule(p_item   VARCHAR2,
                  p_org_id NUMBER) RETURN VARCHAR2;

  FUNCTION item_req_by_date(p_item_id NUMBER,
            p_org_id  NUMBER,
            p_date    DATE) RETURN NUMBER;

  FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
                p_order_line_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_serials_and_lots
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2009
  --------------------------------------------------------------------
  --  purpose :        concatenate all serials/lots for SO line
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2009  Ella Malchi       initial build
  --  1.1  03/12/2009  Dalit A. Raviv    change the select for the serial_lot
  --                                     function will return serials for RMA, INTERNAL and STD SO
  --                                     and not only for STD SO. add param p_reference_id
  --  1.2  14/02/2010  Dalit A. Raviv    maker the function faster

  --------------------------------------------------------------------
  FUNCTION get_serials_and_lots(p_order_line_id NUMBER,
                p_reference_id  NUMBER DEFAULT NULL,
                p_str_len       NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  FUNCTION get_in_transit_qty(p_inventory_item_id    NUMBER,
              p_from_organization_id NUMBER,
              p_to_organization_id   NUMBER DEFAULT NULL)
    RETURN NUMBER;

  FUNCTION get_item_category(p_inventory_item_id NUMBER,
             p_category_set_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_oh_qty
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        Returns OH quantity for specified item, organization, subinv, locator
  --  in param:
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  XX/XX/XXXX  XXX            initial build
  --  1.1  17/12/2014  Dalit A. Raviv add the ability to get the qty only from nettable subinv
  --------------------------------------------------------------------
  FUNCTION get_oh_qty(p_item_code       VARCHAR2,
              p_organization_id NUMBER,
              p_subinventory    VARCHAR2,
              p_locator_code    VARCHAR2 DEFAULT NULL,
              p_available_type  NUMBER DEFAULT NULL) RETURN NUMBER;

  FUNCTION get_cust_4sup_dem(p_identifier VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_revision_2receive(p_inventory_item_id NUMBER,
                 p_organization_id   NUMBER,
                 p_po_line           NUMBER) RETURN VARCHAR2;

  ----------------------------------------------------------
  -- Returns OH quantity for specified item, organization, subinv, locator
  ----------------------------------------------------------
  FUNCTION get_oh_qty_by_id(p_inventory_item_id NUMBER,
            p_organization_id   NUMBER,
            p_subinventory      VARCHAR2 DEFAULT NULL,
            p_locator_id        NUMBER DEFAULT NULL)
    RETURN NUMBER;

  FUNCTION get_oh_qty_string(p_inventory_item_id NUMBER,
             p_organization_id   NUMBER,
             p_subinventory_list VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_item_cost(p_inventory_item_id NUMBER,
         p_organization_id   NUMBER) RETURN NUMBER;

  FUNCTION get_trx_type_loc_validation(p_trx_type_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_revision4date(p_inventory_item_id NUMBER,
             p_organization_id   NUMBER,
             p_date              DATE) RETURN VARCHAR2;

  FUNCTION get_item_segment(p_item_id NUMBER,
            p_org_id  NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_full_leadtime(p_item_id NUMBER,
                  p_org_id  NUMBER) RETURN NUMBER;

  FUNCTION get_mfg_mfg_part(p_item_id         NUMBER,
            p_organization_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_item_make_buy_code(p_item_id NUMBER,
                  p_org_id  NUMBER) RETURN NUMBER;

  FUNCTION get_item_material_cost(p_inventory_item_id NUMBER,
                  p_organization_id   NUMBER) RETURN NUMBER;

  FUNCTION get_buyer_id(p_item_id NUMBER,
        p_org_id  NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_sourcing_buyer_id
  --  create by:       Dovik
  --  Revision:        1.0
  --  creation date:   05/Mar/2017
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  05/Mar/2017   Dovik.Pollak      CHG0040117 - Cut the PO
  --------------------------------------------------------------------
  FUNCTION get_sourcing_buyer_id(p_item_id NUMBER,
                 p_org_id  NUMBER) RETURN NUMBER;

  FUNCTION check_hasp_item_allowed(p_inventory_item_id NUMBER,
                   p_organization_id   NUMBER,
                   p_user_id           NUMBER)
    RETURN VARCHAR2;

  FUNCTION check_disallowed_hasp_in_req(p_requisition_header_id NUMBER,
                p_user_id               NUMBER)
    RETURN VARCHAR2;

  FUNCTION is_sub_inventory_asset(p_secondary_inventory_name VARCHAR2,
                  p_organization_id          NUMBER)
    RETURN NUMBER;

  FUNCTION check_asset_sub_inv_status--(p_delivery_id NUMBER) 
  (p_delivery_name VARCHAR2) RETURN VARCHAR2; -- CHG0041294- on 06/03/2018 for delivery id to name change
  

  FUNCTION is_hazard_item(p_item_id NUMBER,
          p_org_id  NUMBER) RETURN VARCHAR2;

  FUNCTION is_fdm_item(p_item_id     NUMBER DEFAULT NULL,
               p_item_number VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  FUNCTION get_item_supplier(p_organization_id NUMBER,
             p_item_id         NUMBER) RETURN NUMBER;

  FUNCTION get_item_desc_tl(p_item_id         NUMBER,
            p_organization_id NUMBER,
            p_org_id          NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  FUNCTION get_qty_factor_jpn(p_item_id         NUMBER,
              p_organization_id NUMBER DEFAULT NULL,
              p_org_id          NUMBER DEFAULT NULL)
    RETURN NUMBER;

  FUNCTION get_print_inv_uom_tl(p_uom_code        VARCHAR2,
                p_item_id         NUMBER,
                p_organization_id NUMBER,
                p_org_id          NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_fdm_system_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/06/2013
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_fdm_system_item(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  PROCEDURE update_group_mark_id(p_errbuff       OUT VARCHAR2,
                 p_errcode       OUT VARCHAR2,
                 p_serial_number VARCHAR2);

  FUNCTION get_transform_cost_org_code(p_organization_code VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_category_value(p_category_set_id   NUMBER,
              p_inventory_item_id NUMBER,
              p_org_id            NUMBER) RETURN VARCHAR2;

  FUNCTION get_tariff_code(p_org_id            IN NUMBER,
           p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            GET_STD_CST_BSD_ORGS_IN_LOOKUP
  --  create by:       Sandeep Akula
  --  Revision:        1.0
  --  creation date:   28/04/2014
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/04/2014  Sandeep Akula    initial build
  --------------------------------------------------------------------
  FUNCTION get_std_cst_bsd_orgs_in_lookup(p_cost_type         IN VARCHAR2,
                  p_lookup_type       IN VARCHAR2,
                  p_order             IN VARCHAR2,
                  p_inventory_item_id IN NUMBER)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_category_segment
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   11.6.14
  --------------------------------------------------------------------
  --  purpose :CHG0032103
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11.6.14  yuval tal            initial build - change CHG0032103:Add Item classification categories to modifiers
  --------------------------------------------------------------------
  FUNCTION get_category_segment(p_segment_name      VARCHAR2,
                p_category_set_id   NUMBER,
                p_inventory_item_id NUMBER) RETURN VARCHAR2;

  ------------------------------------------------------------------
  --get_item_catalog_value
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/06/2014  yuval tal         CHG0032388 - initial
  ---------------------------------------------------------------------
  FUNCTION get_item_catalog_value(p_organization_id       NUMBER,
                  p_inventoy_item_id      NUMBER,
                  p_item_catalog_group_id NUMBER,
                  p_element_name          VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:               get_related_item
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      09/11/2014
  --  Description:        return the relate item to specific item (by item id or item number)
  --                      p_is_fdm -> N / Y
  --                      p_entity -> ID / CODE, ID will return the item id, CODE will return segment1
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/11/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_related_item(p_item_number IN VARCHAR2,
            p_item_id     IN NUMBER,
            p_is_fdm      IN VARCHAR2 DEFAULT 'N',
            p_entity      IN VARCHAR2 DEFAULT 'ID')
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_org_code
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034558
  --                   get organization code by id
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0034558
  --------------------------------------------------------------------
  FUNCTION get_org_code(p_organization_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_SP_Technical_category
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   10/06/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332
  --                   get technical category of an item. If p_organization_id
  --                   is null, use master organization.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/06/2015  Michal Tzvik    initial version
  --------------------------------------------------------------------
  FUNCTION get_sp_technical_category(p_inventory_item_id NUMBER,
             p_organization_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_aerospace_item
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   09/21/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0036213
  --                   Check if an item is aerospace related
  --                   Currently this is achieved by matching item segment1
  --                   against a fixed set of values in a custom value set
  --------------------------------------------------------------------
  --  ver  date        name                      desc
  --  1.0  09/21/2015  Diptasurjya Chatterjee    initial version
  --------------------------------------------------------------------
  FUNCTION is_aerospace_item(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_weight_uom_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/21/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   Get item id return item weight_uom
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/21/2015  Dalit A. Raviv    initial version
  --------------------------------------------------------------------
  FUNCTION get_weight_uom_code(p_inventory_item_id NUMBER,
               p_organization_id   NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_item_restricted
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   07-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037863
  --                   Get item id return item is restricted(Y) or not (N)
  --
  --------------------------------------------------------------------
  --  ver  date         name                 desc
  --  1.0  07-Mar-2016  Lingaraj Sarangi     initial version
  --------------------------------------------------------------------
  FUNCTION is_item_restricted(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_item_restricted
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   07-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037863
  --                   Get item id return item is
  --                   If the Item is Hazard and restricted Return Value (Y)
  --                   If the Item is Hazard and Not restricted Return Value (N)
  --                   If the Item is Non Hazard and * Return Value (N)
  --------------------------------------------------------------------
  --  ver  date         name                 desc
  --  1.0  07-Mar-2016  Lingaraj Sarangi     initial version
  --------------------------------------------------------------------
  FUNCTION is_item_hazard_restricted(p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

END xxinv_utils_pkg;
/