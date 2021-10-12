CREATE OR REPLACE PACKAGE xxwip_material_req_plan_pkg IS

  -----------------------------------------------------
  --  name:            xxwip_material_req_plan_pkg
  --  create by:
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  yuval tal         initial build
  --  1.1  05.12.10    yuval tal          change build : add field scheduled_completion_date
  --- 1.2  1.3.2011    yuval tal         change logic
  --------------------------------------------------------------------

  PROCEDURE build(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
  PROCEDURE init_g_po_array;
  FUNCTION get_quantity_allocated(p_item_id         NUMBER,
                                  p_organization_id NUMBER,
                                  p_schedule_group  VARCHAR2,
                                  p_quantity        NUMBER) RETURN NUMBER;

  FUNCTION get_po_quantity(p_item_id NUMBER) RETURN NUMBER;
  PROCEDURE init_qty_sub_array;

  FUNCTION get_postprocessing_lead_time(p_item_id NUMBER, p_org_id NUMBER)
    RETURN NUMBER;

END xxwip_material_req_plan_pkg;
/
