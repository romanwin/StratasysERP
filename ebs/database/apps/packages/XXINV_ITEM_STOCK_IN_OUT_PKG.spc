create or replace package XXINV_ITEM_STOCK_IN_OUT_PKG is

--------------------------------------------------------------------
--  name:             XXINV_ITEM_STOCK_IN_OUT_PKG
--  create by:        Dalit A. Raviv
--  Revision:         1.0
--  creation date:    24/AUG/2015 15:29:18
--------------------------------------------------------------------
--  purpose :         CHG0036084 - Filament Stock in Stock out
--------------------------------------------------------------------
--  ver  date         name              desc
--  1.0  24/AUG/2015  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  type t_item_stock_in_out_rec is record (
        item_stock_id       NUMBER,
        organization_id     NUMBER,
        organization_code   VARCHAR2(10),
        inventory_item_id   NUMBER,
        item_number         VARCHAR2(40),
        account_id          NUMBER,
        subinventory_code   VARCHAR2(10),
        locator_id          NUMBER,
        item_revision       VARCHAR2(10),
        original_lot_number VARCHAR2(100),
        new_lot_number      VARCHAR2(100),
        serial_number       VARCHAR2(100),
        qty                 NUMBER,
        uom                 VARCHAR2(100),
        trx_type_id         NUMBER, 
        trx_action_id       NUMBER, 
        trx_source_type_id  NUMBER,
        stage               VARCHAR2(50),
        batch_id            NUMBER,
        log_code            VARCHAR2(20),
        log_msg             VARCHAR2(2500),
        trx_to_intf_flag    VARCHAR2(20),
        trx_to_intf_date    DATE,
        trx_interface_id    NUMBER, 
        last_update_date    DATE,
        last_updated_by     NUMBER,
        last_update_login   NUMBER,
        creation_date       DATE,
        created_by          NUMBER
       );
                                                    
  --------------------------------------------------------------------
  --  name:             main_out
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure is the main prog that 
  --                    handle taking out items from subinventory.
  --                    
  --                    1) Upload excel file with the list of items to work on
  --                    2) Check if there are existing reservations (i.e open Transact Move Orders, open balance in Stage, etc)
  --                    3) Complete item inforamtion
  --                    4) update account id
  --                    5) Check item combination of: org,item,subinv and locator
  --                       do not exists at interface table
  --                    6) update transaction id's for the interface use
  --                    7) if item have one record with E code - all other reacords need to get error
  --                    8) insert record to interface table
  --                    9) Handle run "Process transaction interface" 
  --                    10) handle transaction table errors
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_out (errbuf          out varchar2,
                      retcode         out number,
                      p_table_name    in  varchar2,
                      p_template_name in  varchar2,
                      p_file_name     in  varchar2,
                      p_directory     in  varchar2,
                      p_upload        in  varchar2);
  
  --------------------------------------------------------------------
  --  name:             main_in
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    27/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    This procedure is the main prog that 
  --                    handle return in items to subinventory.
  --                    
  --                    1) reset batch records that where Success to init. values 
  --                    2) update transaction id's for the interface use
  --                    3) insert record back into interface table
  --                    4) Handle run "Process transaction interface"
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  27/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                    
  procedure main_in  (errbuf     OUT VARCHAR2,
                      retcode    OUT NUMBER,
                      p_batch_id in  number); 
                      
  --------------------------------------------------------------------
  --  name:             get_item_lot_serial_control
  --  create by:        Dalit A. Raviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015 15:29:18
  --------------------------------------------------------------------
  --  purpose :         CHG0036084 - Filament Stock in Stock out
  --                    check if item is lot control or serial control
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  24/AUG/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_item_lot_serial_control(p_organization_id   in number, 
                                        p_inventory_item_id in number,
                                        p_lot_controlled    out varchar2,
                                        p_serial_controlled out varchar2);                                                                                                         

end XXINV_ITEM_STOCK_IN_OUT_PKG;
/
