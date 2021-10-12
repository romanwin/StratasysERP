CREATE OR REPLACE PACKAGE xxbom_explosion_report_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 23-Nov-09 22:07:51
  -- Purpose : Explode assembly by effective date for Disco

  g_explosion_effective_date DATE;
  g_organization_code        VARCHAR2(3);

  TYPE item_table_type IS TABLE OF VARCHAR2(30) INDEX BY BINARY_INTEGER;
  g_assembly_item item_table_type;

  FUNCTION explode_assembly_by_date(p_item_ind NUMBER DEFAULT 1)
    RETURN xxbom_exploded_items_tbl_type;

  FUNCTION set_effective_date(p_effective_date DATE) RETURN NUMBER;

  FUNCTION set_organization_code(p_org_code VARCHAR2) RETURN VARCHAR2;

  FUNCTION set_assembly_item(p_assembly_item VARCHAR2,
                             p_item_ind      NUMBER DEFAULT 1)
    RETURN VARCHAR2;

  FUNCTION get_effective_date RETURN DATE;

  FUNCTION get_organization_code RETURN VARCHAR2;

  FUNCTION get_assembly_item(p_item_ind NUMBER DEFAULT 1) RETURN VARCHAR2;
  FUNCTION explode_assembly_by_date2 RETURN xxbom_exploded_items_tbl_type;
END xxbom_explosion_report_pkg;
/
