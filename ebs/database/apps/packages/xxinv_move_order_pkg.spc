CREATE OR REPLACE PACKAGE xxinv_move_order_pkg IS

  --------------------------------------------------------------------
  --  name:            XXINV_MOVE_ORDER_PKG
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose :  change CHG0032311 Auto Populate Destination Locator in Mass Move Orders     
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05.6.14    Yuval Tal        initial build
  --  1.1  07.07.14   yuval tal       CHG0032699 : upload_mo_setup_file add parameter p_inventory_item_id 
  --------------------------------------------------------------------   

  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  PROCEDURE get_mo_dest_info(p_inventory_item_id  NUMBER,
                             p_from_sub_inventory VARCHAR2,
                             p_from_locator_id    NUMBER,
                             p_to_sub_inventory   OUT VARCHAR2,
                             p_to_locator_seg     OUT VARCHAR2,
                             p_to_locator_id      OUT NUMBER);

  PROCEDURE upload_mo_setup_file(p_err_buff       OUT VARCHAR2,
                                 p_err_code       OUT NUMBER,
                                 p_table_name     VARCHAR2,
                                 p_template_name  VARCHAR2,
                                 p_directory      VARCHAR2,
                                 p_file_name      VARCHAR2,
                                 p_delete_records VARCHAR2);
END;
/
