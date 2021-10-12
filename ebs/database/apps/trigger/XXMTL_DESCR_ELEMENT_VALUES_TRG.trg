CREATE OR REPLACE TRIGGER xxmtl_descr_element_values_trg
  before insert or update or delete on "INV"."MTL_DESCR_ELEMENT_VALUES" --added insert/delete condition(CTASK0042788.1)
  for each row
--------------------------------------------------------------------
  --  name:     XXMTL_DESCR_ELEMENT_VALUES_TRG
  --  Description:     trigger created on MTL_DESCR_ELEMENT_VALUES
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/07/2019    Bellona B.      CHG0045254 - strataforce  project PRODUCT Interface
  --									  addition of 2 fields volume_factor_ci and weight_factor_kg
  --  1.1   18/07/2019    Bellona B.      CHG0045254(CTASK0042788) - 1)change trigger condition
  --					(as suggested	  2) Separate definition of l_trigger_action and initialization  
  --					   by Roman)	  3)Added 'DELETE' condition in trigger action.
  --------------------------------------------------------------------
when(NEW.element_name = 'Volume Factor (CI)'
	or NEW.element_name = 'Weight Factor (Kg)')
DECLARE

  l_trigger_name   VARCHAR2(30);-- := 'XXMTL_DESCR_ELEMENT_VALUES_TRG'; --(CTASK0042788.2) Removed initialization
  l_trigger_action VARCHAR2(10);/* := (CASE WHEN INSERTING THEN 'INSERT'--(CTASK0042788.2) Removed initialization
                                         WHEN UPDATING THEN  'UPDATE'
                                         ELSE ''
                                    END
                                    );*/
BEGIN
  --CHG0045254 On 17Jul19
  l_trigger_name := 'XXMTL_DESCR_ELEMENT_VALUES_TRG'; --(CTASK0042788.2) Shifted initialization to BEGIN section.
  l_trigger_action := (CASE WHEN INSERTING THEN 'INSERT' --(CTASK0042788.2) Shifted initialization to BEGIN section.
						 WHEN UPDATING THEN  'UPDATE'
						 WHEN DELETING THEN  'DELETE' --(CTASK0042788.3) Added DELETE condition
						 ELSE ''
						END
					  );  
  -- Strataforce PRODUCT Event Generation on change in 2 fields volume_factor_ci and weight_factor_kg
  xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id =>:new.inventory_item_id,
                                                     p_last_updated_by   =>:new.last_updated_by,
                                                     p_created_by        =>:new.created_by,
                                                     p_trigger_name      =>l_trigger_name,
                                                     p_trigger_action    =>l_trigger_action
                                                     );
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_descr_element_values_trg;
/
