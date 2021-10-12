create or replace package xxcsi_ib_auto_upgrade_pkg is

--------------------------------------------------------------------
--  name:            XXCSI_IB_AUTO_UPGRADE_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   13/03/2011 10:42:40 AM
--------------------------------------------------------------------
--  purpose :        program that perform upgrade in Install Base
--                   accourding to upgrade rules.
--                   Currently printers upgrade process in IB performed manualy.
--                   CUST398 - CRM - Automated upgrade in IB
--                   CUST419 - PZ2Oracle interface for UG upgrade in IB will call this package
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/03/2011  Dalit A. Raviv    initial build
--  1.1  23/05/2011  Dalit A. Raviv    add logic changes to support cust419
--  1.2  17/07/2011  Dalit A. Raviv    Roman found that instead of doing create new ii, close old ii,
--                                     create new relationship etc, we can use the update ii API
--                                     with transaction type 205 (Item Number and or Serial Number Change)
--                                     this type give the ability to update item instance with new inventory_item_id.
--                                     create new procedure main (the old one changed to main_old).
--  1.3  20/03/2012  Dalit A. Raviv    change logic of upgrade.
--                                     new procedure get_sales_ug_items_details
--                                     update procedure get_HASP_after_upgrade
--                                                      update_item_instance_new
--                                                      main
--  1.4  17/04/2012  Dalit A. Raviv    CUST419 1.4 - add ability to reverse upgrade
--                                     new procedure reverse_upgrade_item
--  1.5  08-Aug-2016 L. Sarangi        CHG0037320 - Objet studio SW update
--                                     new procedure <get_studio_sw_version> added to Get the studio SW version
--------------------------------------------------------------------

  TYPE t_instance_rec IS RECORD
     (old_instance_id      number,
      upgrade_kit          number, -- old_inventory_item_id
      close_date           date);

  TYPE t_log_rec IS RECORD
     (entity_id            number,
      status               varchar2(20),
      instance_id_old      number,
      serial_number_old    varchar2(100),
      upgrade_type         number, -- inventory_item_id from map tbl
      instance_id_new      number,
      hasp_instance_id_new number,
      msg_code             varchar2(20),
      msg_desc             varchar2(2500));

  TYPE t_log_bz2oa_rec IS RECORD
     (transaction_id   number,
      record_status    varchar2(100),
      error_message    varchar2(2000));

  --------------------------------------------------------------------
  -- name:            get_sales_ug_items_details
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   20/03/2012
  --------------------------------------------------------------------
  -- purpose :        Get upgrade item details from lookup
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  20/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure get_sales_ug_items_details (p_upgrade_item_id     in  number,
                                        p_before_upgrade_item in  number,
                                        p_before_upgrade_hasp in  number,
                                        p_entity              in varchar2 default 'DR',
                                        x_after_upgrade_item  out number,
                                        x_after_upgrade_hasp  out number,
                                        x_from_sw_version     out varchar2,
                                        p_err_code            out varchar2,
                                        p_err_desc            out varchar2);

  --------------------------------------------------------------------
  --  name:            get_upgrade_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/05/2011
  --------------------------------------------------------------------
  --  purpose :        function that find upgrade kit according to
  --                   system_sn of the printer from the interface table.
  --  Return:          varchar2 -> HW (Hard ware) or SW (Soft Ware)
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  23/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure get_upgrade_type (p_serial_number   in varchar2,  -- is_HW_SW_upgrade
                              p_upgrade_type    out varchar2,
                              p_upgrade_kit     out number,
                              p_old_instance_id out number);

  --------------------------------------------------------------------
  -- name:            get_SW_HASP_exist
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   25/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        Get detail of the HASP item that is now connect to
  --                  the printer (before upgrade)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  25/05/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure get_SW_HASP_exist (p_old_instance_id        in  number,
                               p_Hasp_instance_id       out number,
                               p_HASP_inventory_item_id out number,
                               p_error_code             out varchar2,
                               p_error_desc             out varchar2);

  --------------------------------------------------------------------
  -- name:            get_HASP_after_upgrade
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   25/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        Get detail of the new HASP item that is upgrade to
  --                  the printer (after upgrade)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  25/05/2011  Dalit A. Raviv   initial build
  -- 1.1  20/03/2012  Dalit A. Raviv   change logic to support new upgrade system.
  --------------------------------------------------------------------
  procedure get_HASP_after_upgrade (p_upgrade_kit               in  number,
                                    p_old_instance_item_id      in number,
                                    p_old_instance_hasp_item_id in number,
                                    p_entity                    in varchar2 default 'DR',
                                    p_NEW_HASP_item_id          out number,
                                    p_err_code                  out varchar2,
                                    p_err_desc                  out varchar2);

  --------------------------------------------------------------------
  --  name:            check_is_item_hasp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/03/2011
  --------------------------------------------------------------------
  --  purpose :        Check if the item is HASP item
  --
  --  return:          HASP - item is HASP
  --                   ITEM - item is not
  --                   DUP  - if there is more then one HASP relate to the instance
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_is_item_hasp (p_instance_id in number) return varchar2 ;

  --------------------------------------------------------------------
  --  name:            check_is_item_hasp_rel
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/03/2011
  --------------------------------------------------------------------
  --  purpose :        Check if the instance is HASP item
  --                   i will call this function from the handle relationship
  --                   at the select each row will return if this is item or hasp
  --                   then Hasp item the new relationship has diffrent handling.
  --
  --  return:          HASP - item is HASP
  --                   ITEM - item is not
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function check_is_item_hasp_rel (p_instance_id in number) return varchar2;

  --------------------------------------------------------------------
  --  name:            handle_close_old_instance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle close old instance
  --
  --  in param:        p_source    - 'MAIN' / 'REL'
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/03/2011  Dalit A. Raviv  initial build
  --  1.1  24/05/2011  Dalit A. Raviv  Add p_source param and code to support.
  --                                   need to close old relation items with no serial number
  --------------------------------------------------------------------
  procedure handle_close_old_instance (p_old_instance_id in  number,
                                       p_old_close_date  in  date,
                                       p_upgrade_kit     in  number,
                                       p_source          in  varchar2,
                                       p_msg_desc        out varchar2,
                                       p_msg_code        out varchar2);


  procedure close_contract(p_err_code out varchar2,
                           p_err_desc out varchar2);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        Main Process
  --  out params:      errbuf  - null success others failrd
  --                   retcode - 0    success 1 failed
  --  In Params:       p_instance_id
  --                   p_inventory_item_id
  --                   p_entity    - 'AUTO'   Automatic program
  --                               - 'MANUAL' Run Manual
  --                   p_hasp_sn
  --                   p_System_sn
  --                   p_user_name - fnd_user or PZ_INTF
  --                   p_SW_HW     - HW / SW
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  23/05/2011  Dalit A. Raviv    xxcs_sales_ug_items_v view field names changed
  --                                     add parameter user name , p_hasp_sn, p_SW_HW
  --  1.2  17/07/2011  Dalit A. Raviv    Roman found that instead of doing create new ii, close old ii,
  --                                     create new relationship etc, we can use the update ii API
  --                                     with transaction type 205 (Item Number and or Serial Number Change)
  --                                     this type give the ability to update item instance with new inventory_item_id.
  --                                     create new procedure main (the old one changed to main_old).
  --------------------------------------------------------------------
  procedure main (errbuf              out varchar2,
                  retcode             out varchar2,
                  p_entity            in  varchar2,
                  p_instance_id       in  number,
                  p_inventory_item_id in  number,
                  p_hasp_sn           in  varchar2 default null,
                  p_user_name         in  varchar2 default null,
                  p_SW_HW             in  varchar2 default 'HW') ; -- HW / SW_UPG / SW_NEW

  /*procedure create_item_instance (p_instance_rec    in  t_instance_rec,
                                  p_new_instance_id out number,
                                  p_new_item_id     out number,
                                  p_err_code        out varchar2,
                                  p_err_msg         out varchar2);     */

  --------------------------------------------------------------------
  --  name:            reverse_upgrade_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle reverse instance to item before upgrade
  --
  --  in param:        p_instance_id       - the instance to reverse upgrade
  --                   p_serial_number     - not allways exists
  --                   p_inventory_item_id - To Part number
  --
  --  out params:      errbuf              - null success others failed
  --                   retcode             - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/03/2011  Dalit A. Raviv  initial build
  --  1.1  24/05/2011  Dalit A. Raviv  Add p_source param and code to support.
  --                                   need to close old relation items with no serial number
  --------------------------------------------------------------------
  procedure reverse_upgrade_item (errbuf              out varchar2,
                                  retcode             out varchar2,
                                  p_instance_id       in  number,
                                  p_serial_number     in  varchar2,
                                  p_inventory_item_id in  number);  -- To Part number

  --------------------------------------------------------------------
  --  name:            get_embedded_sw_version
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/04/2012
  --------------------------------------------------------------------
  --  purpose :        find the new embedded SW version of the upgrade printer.
  --  In Params:       p_old_inventory_item_id
  --                   p_upgrade_kit_desc
  --                   p_hasp_instance_id
  --                   p_old_embeded_sw_ver
  --  out params:      p_embedded_sw_ver
  --                   p_err_desc  - null success others failrd
  --                   p_err_code  - 0    success 1 failed
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure get_embedded_sw_version (p_old_inventory_item_id in  number,
                                     p_upgrade_kit_desc      in  varchar2,
                                     p_hasp_item_id          in  number,
                                     p_old_embeded_sw_ver    in  varchar2,
                                     p_embedded_sw_ver       out varchar2,
                                     p_err_code              out varchar2,
                                     p_err_desc              out varchar2);
  
  --------------------------------------------------------------------
  --  name:            get_Studio_sw_version
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   04/08/2016
  --------------------------------------------------------------------
  --  purpose :        find the new Studio SW version of the upgrade printer.
  --  In Params:       p_old_inventory_item_id
  --                   p_upgrade_kit_desc
  --                   p_hasp_instance_id
  --                   p_old_studio_sw_ver
  --  out params:      p_studio_sw_ver
  --                   p_err_desc  - null success others failrd
  --                   p_err_code  - 0    success 1 failed
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/08/2016  Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --------------------------------------------------------------------
  procedure get_studio_sw_version (p_old_inventory_item_id in  number,
                                   p_upgrade_kit_desc      in  varchar2,
                                   p_hasp_item_id          in  number,
                                   p_old_studio_sw_ver     in  varchar2,
                                   p_studio_sw_ver         out varchar2,
                                   p_err_code              out varchar2,
                                   p_err_desc              out varchar2);
                                                                          


  procedure test (p_instance_id        in  number,
                  p_inventory_item_id  in  number,
                  p_inventory_revision in  varchar2,
                  p_err_code           out varchar2,
                  p_err_msg            out varchar2);

end XXCSI_IB_AUTO_UPGRADE_PKG;
/