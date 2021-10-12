CREATE OR REPLACE PACKAGE APPS.xxinv_kanban_card_pkg AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------------------
  --  Name:            xxinv_kanban_card_pkg
  --  Created By:      Hubert, Eric
  --  Revision:        1.0
  --  Creation Date:   01-MAY-2018
  --  Object Type :    Package Specification
  ---------------------------------------------------------------------------------------
  --  Purpose: Print Kanban Cards with emphasis on flexible parameters and sorting.
  ---------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  01-MAY-2018   Eric Hubert          CHG00_____ - Initial build
  ---------------------------------------------------------------------------------------
    p_conc_request_id              NUMBER;
    p_org_id                       NUMBER; --Organization in which kanban card is defined
    p_kanban_card_number_low       VARCHAR2(30); --
    p_kanban_card_number_high      VARCHAR2(30); --
    p_pull_sequence_id             NUMBER; --
    p_card_created_by              NUMBER; --
    p_card_created_date_low        DATE; --
    p_card_created_date_high       DATE; --
    p_include_reprints             VARCHAR2(1); --
    p_print_event                  VARCHAR2(150); --
    p_source_subinv                VARCHAR2(10); --
    --p_source_locator_id            NUMBER; --
    p_dest_subinv                  VARCHAR2(10); --
    p_dest_locator_id              NUMBER; --
    p_dest_locator_segment_01      VARCHAR2(20); -- Deliver To Stock Locator Segment 1 (Subinventory - XXINV_SUBINVENTORY_TABLE_VS)
    p_dest_locator_segment_02      VARCHAR2(20); -- Deliver To Stock Locator Segment 2 (Row - XXINV_STOCK_LOCATOR_ROW_VS)
    p_dest_locator_segment_03      VARCHAR2(20); -- Deliver To Stock Locator Segment 3 (Rack - XXINV_STOCK_LOCATOR_RACK_VS)
    p_dest_locator_segment_04      VARCHAR2(20); -- Deliver To Stock Locator Segment 4 (Bin - XXINV_STOCK_LOCATOR_BIN_VS)
    
    p_udt_subinv           VARCHAR2(10); --
    p_udt_locator_id              NUMBER; --
    p_udt_locator_segment_01      VARCHAR2(20); -- Ultimate Deliver-To Stock Locator Segment 1 (Subinventory - XXINV_SUBINVENTORY_TABLE_VS)
    p_udt_locator_segment_02      VARCHAR2(20); -- Ultimate Deliver-To Stock Locator Segment 2 (Row - XXINV_STOCK_LOCATOR_ROW_VS)
    p_udt_locator_segment_03      VARCHAR2(20); -- Ultimate Deliver-To Stock Locator Segment 3 (Rack - XXINV_STOCK_LOCATOR_RACK_VS)
    p_udt_locator_segment_04      VARCHAR2(20); -- Ultimate Deliver-To Stock Locator Segment 4 (Bin - XXINV_STOCK_LOCATOR_BIN_VS)  
      
    p_source_type                  NUMBER; --
    p_card_type                    NUMBER;
    p_supply_status                NUMBER;
    p_item_low                     VARCHAR2(30);
    p_item_high                    VARCHAR2(30);
    p_supplier_id                  NUMBER;
    p_supplier_site_id             NUMBER;
    p_sourcing_org_id              NUMBER;
    p_wip_line_id                  NUMBER;
    p_kanban_card_id               NUMBER;
    p_report_id                    NUMBER;
    p_print_report_header_footer   VARCHAR2(3);
    p_report_layout_name           VARCHAR2(30);
    p_debug_flag                   VARCHAR2(30);
    p_update_print_event_dff       VARCHAR2(3); -- Indicates if the Print Event DFF on the Move Order Line should be updated.
    p_sort_field_01                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_01_direction      VARCHAR2(4); --supports dynamic sorting
    p_sort_field_02                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_02_direction      VARCHAR2(4); --supports dynamic sorting
    p_sort_field_03                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_03_direction      VARCHAR2(4); --supports dynamic sorting
    p_sort_field_04                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_04_direction      VARCHAR2(4); --supports dynamic sorting
    p_sort_field_05                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_05_direction      VARCHAR2(4); --supports dynamic sorting
    p_sort_field_06                VARCHAR2(30); --supports dynamic sorting
    p_sort_field_06_direction      VARCHAR2(4); --supports dynamic sorting
    p_lexical_order_by_clause_main VARCHAR2(1000); --lexical that supports dynamic sorting
    p_lexical_where_clause_main    VARCHAR2(2000) := '1=1'; --lexical for where clause of main query
    FUNCTION beforereport RETURN BOOLEAN;
    FUNCTION afterreport RETURN BOOLEAN;
    FUNCTION afterpform RETURN BOOLEAN;
    FUNCTION order_by_clause RETURN VARCHAR2;
    FUNCTION update_print_event_dff(p_kanban_card_id IN NUMBER) RETURN VARCHAR2;
    
    -----------------------------------------------------------------------
    --  Name:               print_kanban_cards
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-May-2018
    --  Purpose :           This function will create a concurrent request for the 
    --  'XXQA: Kanban Card' (XXINV_KANBAN_CARD).  The function has 
    --  separate arguments for the Kanban Card Number, Kanban Card ID, and Pull Sequence ID.
    --  This allows for the printing of a specific scope of kanban cards, for a
    --  single specific card or for all cards in a pull sequence.  The intent
    --  is to call this function from a forms personalization on the Pull
    --  Sequence and/or Kanban Card forms.
    --  
    --  There is an argument for explicitly indicating which printer should be used,
    --  to bypass any rules within the function for determining which printer should
    --  be used.
    ----------------------------------------------------------------------------------
    --  ver   date          name            desc
    --  1.0   24-Jul-2018   Hubert, Eric    CHG0041284 - XXINV: Kanban Card
    -----------------------------------------------------------------------------------
    FUNCTION print_kanban_cards (
     p_organization_id IN NUMBER
     , p_kanban_card_number IN VARCHAR2  --Eith kanban card number or pull sequence id need to be specified.
     , p_pull_sequence_id IN VARCHAR2
     , p_report_layout IN VARCHAR2  --Optional layout (if null, it is determined with a profile option).
     , p_printer_name IN VARCHAR2 --Optional printer name  (if null, it is determined with a profile option).
    ) RETURN NUMBER --Return Concurrent Request ID
    ;
END xxinv_kanban_card_pkg;
/