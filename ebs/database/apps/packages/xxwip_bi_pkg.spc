CREATE OR REPLACE PACKAGE xxwip_bi_pkg IS

  -- Author  : ERIC JM HOSENPUD
  -- Created : 1/13/2008 1:45:57 PM
  -- Purpose : For use with WIP Discrete Jobs Discoverer report

  -- Public function and procedure declarations
  FUNCTION internal_onhand_nettable(p_inventory_item_id NUMBER,
                                    p_organization_id   NUMBER) RETURN NUMBER;

  FUNCTION external_onhand_nettable(p_inventory_item_id NUMBER,
                                    p_supplier_code     VARCHAR2 /* if null then onhand internal*/)
    RETURN NUMBER;

  FUNCTION internal_released_jobs_qty(p_inventory_item_id NUMBER,
                                      p_status_type       NUMBER /*default 3 - released*/,
                                      p_wip_entity_id     NUMBER)
    RETURN NUMBER;

  FUNCTION external_released_jobs_qty(p_inventory_item_id NUMBER,
                                      p_status_type       NUMBER /*default 3 - released*/,
                                      p_supplier_code     VARCHAR2 /* if null then released internal*/,
                                      p_wip_entity_id     NUMBER)
    RETURN NUMBER;

  FUNCTION open_supply_qty(p_inventory_item_id NUMBER) RETURN NUMBER;

  FUNCTION oldest_po_vendor(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION wip_comp_assbly_descrip(p_wip_job           NUMBER,
                                   p_inventory_item_id NUMBER,
                                   p_info_request      VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION supply_over_all_wip_jobs(p_inventory_item_id NUMBER) RETURN NUMBER;

  FUNCTION wip_req_for_released(p_wip_entity_id NUMBER) RETURN NUMBER;

  FUNCTION il_job_pick_qty(p_entity_id wip_entities.wip_entity_id%TYPE)
    RETURN NUMBER;

  FUNCTION po_open_quantity(p_inventory_item_id NUMBER,
                            p_organization_id   NUMBER) RETURN NUMBER;

  FUNCTION po_vendor_name(p_inventory_item_id NUMBER,
                          p_organization_id   NUMBER) RETURN VARCHAR2;

  FUNCTION po_buyer_name(p_inventory_item_id NUMBER,
                         p_organization_id   NUMBER) RETURN VARCHAR2;

  function xx_job_pick_qty(p_entity_id wip_entities.wip_entity_id%type)
    return number;
END xxwip_bi_pkg;
/

