CREATE OR REPLACE TRIGGER XXMTL_ITEM_CATEG_AIUR_TRG1
--------------------------------------------------------------------------------------------------
/*
Revision:        1.0  
Trigger Name:    XXMTL_ITEM_CATEG_AIUR_TRG1.trg
Author's Name:   Sandeep Akula
Date Written:    26-MARCH-2015
Purpose:         Updates data in staging table for the Item Category being updated 
                 Inserts data into a staging table whenever a new Category is added for an Item Category set "Product Hierarchy "
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
26-MARCH-2015        1.0                  Sandeep Akula    Initial Version -- CHG0034783
---------------------------------------------------------------------------------------------------*/
AFTER INSERT OR UPDATE ON MTL_ITEM_CATEGORIES
FOR EACH ROW

WHEN (NEW.category_set_id = 1100000221) 
                            
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

-- New Values after Update 
  New_Items_Tbl := xxinv_ecom_product_pkg.get_item_info(:NEW.inventory_item_id,:NEW.organization_id,'MTL_ITEM_CATEGORIES');

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
    l_error_message := 'Error Occured in Procedure xxinv_ecom_product_pkg.mtl_update with Error :'||l_error_message;
   RAISE_APPLICATION_ERROR(-20000,l_error_message);
 WHEN INSERT_EXCP THEN
  l_error_message := 'Error Occured in Procedure xxinv_ecom_product_pkg.mtl_insert with Error :'||l_error_message;
   RAISE_APPLICATION_ERROR(-20000,l_error_message);
  WHEN OTHERS THEN
   l_error_message := substrb(sqlerrm,1,150);
   RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXMTL_ITEM_CATEG_AIUR_TRG1;
/
