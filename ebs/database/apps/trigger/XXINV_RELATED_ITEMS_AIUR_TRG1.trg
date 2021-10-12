CREATE OR REPLACE TRIGGER XXINV_RELATED_ITEMS_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXINV_RELATED_ITEMS_AIUR_TRG1
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     11/11/2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0036886  : Check and insert/update data into event table for Insert, Delete
--                                   and Update triggers on MTL_RELATED_ITEMS
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   11/11/2015    Diptasurjya Chatterjee     CHG0036886 - Initial Build
--  1.1   18.Dec.2017   Lingaraj Sarangi           CHG0041504 - Product Interface [StrataForce Interface]
--  1.2   6.Jun.2018    Lingaraj Sarangi           CHG0041808 - Pricelist Line Interface
--  1.3   17/02/2019    Lingaraj                   INC0146984  - remove pronto call
--------------------------------------------------------------------------------------------------
AFTER INSERT OR DELETE OR UPDATE ON "INV"."MTL_RELATED_ITEMS"
FOR EACH ROW

DECLARE
  l_trigger_name          varchar2(30) := 'XXINV_RELATED_ITEMS_AIUR_TRG1';
  l_trigger_ation         VARCHAR2(10):= ''; -- Added on 18.Dec.2017 for v1.1 CHG0041504 - Product Interface
  --pronto_old_items_rec    xxinv_pronto_event_pkg.item_rec_type; --INC0146984
  --pronto_new_items_rec    xxinv_pronto_event_pkg.item_rec_type; --INC0146984
  l_old_rec               MTL_RELATED_ITEMS%rowtype;  --CHG0041808
  l_new_rec               MTL_RELATED_ITEMS%rowtype;  --CHG0041808
  l_error_message         varchar2(2000);
BEGIN
  l_error_message := '';

  -- Added on 18.Dec.2017 for v1.1 CHG0041504 - Product Interface
  IF INSERTING THEN
     l_trigger_ation := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_ation := 'UPDATE';
  ELSIF DELETING THEN
     l_trigger_ation := 'DELETE';
  END IF;
  /* Commented for INC0146984
  pronto_old_items_rec.inventory_item_id    := :old.inventory_item_id;
  pronto_old_items_rec.organization_id      := :old.organization_id;
  pronto_old_items_rec.related_item_id      := :old.related_item_id;
  pronto_old_items_rec.relationship_type_id := :old.relationship_type_id;
  pronto_old_items_rec.created_by           := :old.created_by;
  pronto_old_items_rec.last_updated_by      := :old.last_updated_by;

  pronto_new_items_rec.inventory_item_id    := :new.inventory_item_id;
  pronto_new_items_rec.organization_id      := :new.organization_id;
  pronto_new_items_rec.related_item_id      := :new.related_item_id;
  pronto_new_items_rec.relationship_type_id := :new.relationship_type_id;
  pronto_new_items_rec.created_by           := :new.created_by;
  pronto_new_items_rec.last_updated_by      := :new.last_updated_by;
  */
  --Begin CHG0041808
    l_old_rec.inventory_item_id    := :old.inventory_item_id;
    l_old_rec.organization_id      := :old.organization_id;
    l_old_rec.related_item_id      := :old.related_item_id;
    l_old_rec.relationship_type_id := :old.relationship_type_id;
    l_old_rec.created_by           := :old.created_by;
    l_old_rec.last_updated_by      := :old.last_updated_by;

    l_new_rec.inventory_item_id    := :new.inventory_item_id;
    l_new_rec.organization_id      := :new.organization_id;
    l_new_rec.related_item_id      := :new.related_item_id;
    l_new_rec.relationship_type_id := :new.relationship_type_id;
    l_new_rec.created_by           := :new.created_by;
    l_new_rec.last_updated_by      := :new.last_updated_by;
  --End CHG0041808
  /* Commented for INC0146984
  IF updating THEN
     xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => pronto_old_items_rec,
                                                   p_new_item_rec   => pronto_new_items_rec,
                                                   p_trigger_name   => l_trigger_name,
                                                   p_trigger_action => 'UPDATE');
  ELSIF inserting THEN
     xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => null,
                                                   p_new_item_rec   => pronto_new_items_rec,
                                                   p_trigger_name   => l_trigger_name,
                                                   p_trigger_action => 'INSERT');
  ELSIF deleting THEN
    xxinv_pronto_event_pkg.item_trigger_processor(p_old_item_rec   => pronto_old_items_rec,
                                                  p_new_item_rec   => null,
                                                  p_trigger_name   => l_trigger_name,
                                                  p_trigger_action => 'DELETE');
  END IF;
  */
  --v1.1 Added on 18.Dec.2017 for Strataforce Interface
  --If the Relation type Added as Substitute or Removed Then Product Event need to be generated.
  If (:NEW.RELATIONSHIP_TYPE_ID = 2 ) or (:OLD.RELATIONSHIP_TYPE_ID = 2) Then
    xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id  => nvl(:NEW.inventory_item_id ,:OLD.inventory_item_id),
                                                       p_last_updated_by    => nvl(:NEW.last_updated_by   ,:OLD.last_updated_by),
                                                       p_created_by         => nvl(:NEW.created_by        ,:OLD.created_by),
                                                       p_trigger_name       => l_trigger_name,
                                                       p_trigger_action     => l_trigger_ation
                                                       );
  End If;

  --If a Item relationship created / Modified / Delted  of Type Service
  --The affected Items and related items price need to sync too SFDC
  If (:NEW.RELATIONSHIP_TYPE_ID = 5 ) or (:OLD.RELATIONSHIP_TYPE_ID = 5) Then
    xxssys_strataforce_events_pkg.related_item_trg_processor(p_old_rec       => l_old_rec,
                                                             p_new_rec       => l_new_rec,
                                                             p_trigger_name  => l_trigger_name,
                                                             p_trigger_action=> l_trigger_ation
                                                             );
  End If;

EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_RELATED_ITEMS_AIUR_TRG1;
/
