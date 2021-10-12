CREATE OR REPLACE PACKAGE apps.xx_wip_job_bom_dump_pkg AS
  PROCEDURE p_extract_job_boms(errbuf         OUT VARCHAR2,
                               retcode        OUT NUMBER,
                               p_mfg_org_id   IN NUMBER,
                               p_defrag_table IN VARCHAR2 DEFAULT 'N');

  FUNCTION f_get_on_hand_qty(p_inventory_item_id IN NUMBER,
                             p_organization_id   IN NUMBER) RETURN NUMBER;

END xx_wip_job_bom_dump_pkg;
/
