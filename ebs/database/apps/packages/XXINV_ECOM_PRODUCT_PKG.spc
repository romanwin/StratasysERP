create or replace PACKAGE xxinv_ecom_product_pkg IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXINV_ECOM_PRODUCT_PKG.spc
  Author's Name:   Sandeep Akula
  Date Written:    06-MARCH-2015
  Purpose:         Send Item Attribute updates to e-Commerce 
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  06-MARCH-2015        1.0                  Sandeep Akula    Initial Version (CHG00)
  ---------------------------------------------------------------------------------------------------*/
  TYPE item_rec_type IS RECORD(inventory_item_id           mtl_system_items.inventory_item_id%type,
                               segment1                    mtl_system_items.segment1%type,
                               organization_id             mtl_system_items.organization_id%type,
                               description                 mtl_system_items.description%type,
                               primary_unit_of_measure     mtl_system_items.primary_unit_of_measure%type,
                               hazardous_material_flag     mtl_system_items.hazardous_material_flag%type,
                               dimension_uom_code          mtl_system_items.dimension_uom_code%type,
                               unit_length                 mtl_system_items.unit_length%type,         
                               unit_width                  mtl_system_items.unit_width%type,
                               unit_height                 mtl_system_items.unit_height%type,
                               weight_uom_code             mtl_system_items.weight_uom_code%type,
                               unit_weight                 mtl_system_items.unit_weight%type,
                               created_by                  mtl_system_items.created_by%type,
                               last_updated_by             mtl_system_items.last_updated_by%type,  
                               orderable_on_web_flag       mtl_system_items.orderable_on_web_flag%type,
                               customer_order_enabled_flag mtl_system_items.customer_order_enabled_flag%type,
                               source                      VARCHAR2(150)
                               );
                               
  FUNCTION PRODUCT_EXISTS(p_inventory_item_id IN NUMBER,
                          p_organization_id IN NUMBER)
  RETURN BOOLEAN;
  
  FUNCTION IS_ECOM_ITEM(p_inventory_item_id IN NUMBER,
                        p_organization_id IN NUMBER)
  RETURN VARCHAR2;
  
  FUNCTION get_item_info(p_inventory_item_id IN NUMBER,
                         p_organization_id IN NUMBER,
                         p_source IN VARCHAR2)
  RETURN  item_rec_type;  
  
  FUNCTION get_dimensions_uom_conv_code(p_unit_code IN VARCHAR2,
                                        p_inventory_item_id IN NUMBER)
  RETURN VARCHAR2;                                   
  
  FUNCTION get_weight_uom_conv_code(p_unit_code IN VARCHAR2,
                                    p_inventory_item_id IN NUMBER)
  RETURN VARCHAR2;
  
  FUNCTION get_dimensions_conv_value(p_unit_value IN NUMBER,
                                     p_inventory_item_id IN NUMBER,
                                     p_uom_code IN VARCHAR2)
  RETURN NUMBER;                                   
  
  FUNCTION get_weight_conv_value(p_unit_value IN NUMBER,
                                 p_inventory_item_id IN NUMBER,
                                 p_uom_code IN VARCHAR2)
  RETURN NUMBER;
                               
  PROCEDURE UPDATE_PRODUCT_DATA(p_old_item_rec IN item_rec_type DEFAULT NULL,
                                p_new_item_rec IN item_rec_type,
                                p_err_code OUT NUMBER,
                                p_err_message OUT VARCHAR2);
                               
  PROCEDURE INSERT_PRODUCT_DATA(p_new_item_rec IN item_rec_type,
                                p_err_code OUT NUMBER,
                                p_err_message OUT VARCHAR2);
                                
  PROCEDURE MTL_UPDATE(p_old_item_rec IN item_rec_type,
                       p_new_item_rec IN item_rec_type,
                       p_err_code OUT NUMBER,
                       p_err_message OUT VARCHAR2);
                       
  PROCEDURE MTL_INSERT(p_new_item_rec IN item_rec_type,
                       p_err_code OUT NUMBER,
                       p_err_message OUT VARCHAR2);                       
                                
  PROCEDURE MAIN(errbuf OUT VARCHAR2,
                 retcode OUT NUMBER,
                 p_file_name IN VARCHAR2,
                 p_data_dir IN VARCHAR2);
 
END xxinv_ecom_product_pkg;
/
