create or replace TRIGGER XXMTL_SYSTEM_ITEMS_AIUR_TRG1
--------------------------------------------------------------------------------------------------
/*
Revision:        1.0  
Trigger Name:    XXMTL_SYSTEM_ITEMS_AIUR_TRG1.trg
Author's Name:   Sandeep Akula
Date Written:    6-MARCH-2015
Purpose:         Updates data in staging table for the Item being updated 
                 Inserts data into a staging table whenever a new Item is created 
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
6-MARCH-2015        1.0                  Sandeep Akula    Initial Version -- CHG0034783
---------------------------------------------------------------------------------------------------*/
AFTER INSERT OR UPDATE ON MTL_SYSTEM_ITEMS_B
FOR EACH ROW

DECLARE
  Old_Items_Tbl       xxinv_ecom_product_pkg.item_rec_type;
  New_Items_Tbl       xxinv_ecom_product_pkg.item_rec_type;
  l_error_code  NUMBER;
  l_error_message varchar2(2000);
  update_excp EXCEPTION;
  insert_excp     EXCEPTION;
  
BEGIN
l_error_code := '';
l_error_message := '';

-- Old Values before Update 
Old_Items_Tbl.inventory_item_id := :old.inventory_item_id;
Old_Items_Tbl.segment1 := :old.segment1;
Old_Items_Tbl.organization_id := :old.organization_id;
Old_Items_Tbl.description := :old.description;
Old_Items_Tbl.primary_unit_of_measure := :old.primary_unit_of_measure;
Old_Items_Tbl.hazardous_material_flag := :old.hazardous_material_flag;
Old_Items_Tbl.dimension_uom_code := :old.dimension_uom_code;
Old_Items_Tbl.unit_length := :old.unit_length;
Old_Items_Tbl.unit_width := :old.unit_width;
Old_Items_Tbl.unit_height := :old.unit_height;
Old_Items_Tbl.weight_uom_code := :old.weight_uom_code;
Old_Items_Tbl.unit_weight := :old.unit_weight;
Old_Items_Tbl.created_by := :old.created_by;
Old_Items_Tbl.last_updated_by := :old.last_updated_by;
Old_Items_Tbl.orderable_on_web_flag := :old.orderable_on_web_flag;
Old_Items_Tbl.customer_order_enabled_flag := :old.customer_order_enabled_flag;

-- New Values after Update 
New_Items_Tbl.inventory_item_id := :new.inventory_item_id;
New_Items_Tbl.segment1 := :new.segment1;
New_Items_Tbl.organization_id := :new.organization_id;
New_Items_Tbl.description := :new.description;
New_Items_Tbl.primary_unit_of_measure := :new.primary_unit_of_measure;
New_Items_Tbl.hazardous_material_flag := :new.hazardous_material_flag;
New_Items_Tbl.dimension_uom_code := :new.dimension_uom_code;
New_Items_Tbl.unit_length := :new.unit_length;
New_Items_Tbl.unit_width := :new.unit_width;
New_Items_Tbl.unit_height := :new.unit_height;
New_Items_Tbl.weight_uom_code := :new.weight_uom_code;
New_Items_Tbl.unit_weight := :new.unit_weight;
New_Items_Tbl.created_by := :new.created_by;
New_Items_Tbl.last_updated_by := :new.last_updated_by;
New_Items_Tbl.orderable_on_web_flag := :new.orderable_on_web_flag;
New_Items_Tbl.customer_order_enabled_flag := :new.customer_order_enabled_flag;
New_Items_Tbl.source := 'MTL_SYSTEM_ITEMS';

IF updating THEN 

   xxinv_ecom_product_pkg.mtl_update(p_old_item_rec => Old_Items_Tbl,
                                    p_new_item_rec   => New_Items_Tbl,
                                    p_err_code  => l_error_code,
                                   p_err_message => l_error_message);
                                           
            IF  l_error_code = '1' THEN
               RAISE update_excp;
            END IF; 
   
ELSIF inserting THEN
 
   xxinv_ecom_product_pkg.mtl_insert(p_new_item_rec   => New_Items_Tbl,
                                     p_err_code  => l_error_code,
                                     p_err_message => l_error_message); 
                                             
      IF  l_error_code = '1' THEN
        RAISE insert_excp;
      END IF;
   
END IF;
 
     
EXCEPTION
  WHEN update_excp THEN 
    l_error_message := 'Error Occured in Procedure xxinv_ecom_product_pkg.mtl_upate with Error :'||l_error_message;
   RAISE_APPLICATION_ERROR(-20000,l_error_message);
  WHEN INSERT_EXCP THEN
  l_error_message := 'Error Occured in Procedure xxinv_ecom_product_pkg.insert_product_data with Error :'||l_error_message;
   RAISE_APPLICATION_ERROR(-20000,l_error_message);
  WHEN OTHERS THEN
   l_error_message := substrb(sqlerrm,1,150);
   RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXMTL_SYSTEM_ITEMS_AIUR_TRG1;
/
