CREATE OR REPLACE PACKAGE xxagile_file_export_pkg IS

  ---------------------------------------------------------------------------
  -- $Header: xxagile_file_export_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxagile_call_eco_boms_api_pl
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Agile output interface
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  2.4.11   yuval tal        change logic at get_item_onhand_qty 
  ---------------------------------------------------------------------------

  PROCEDURE call_xxagile_bpel_proc(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  ---------------------------------------------------------------------------

  FUNCTION get_item_onhand_qty(p_item_id NUMBER) RETURN NUMBER;

  FUNCTION get_item_open_po(p_item_id NUMBER) RETURN NUMBER;

  FUNCTION get_item_last_price(p_item_id NUMBER) RETURN NUMBER;

  FUNCTION get_item_last_currency(p_item_id NUMBER) RETURN VARCHAR2;

END xxagile_file_export_pkg;
/

