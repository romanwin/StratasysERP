create or replace PACKAGE BODY xx_inv_kanban_status_chng_pkg
AS

/******************************************************************************************************
  Procedure  : P_CHNG_KANBAN_STATUS
  Author     : Rajeeb Das
  Date       : 04-DEC-2013

  Description: This Procedure changes the Kanban supply status
               to Empty or Wait.
  Parameters : Standard Concurrent Program Parameters and
               1. Inventory Organization
               2. Status (The status which the supply status needs to be changed to)

  MODIFICATION HISTORY
  --------------------
  DATE        NAME         DESCRIPTION
  ----------  -----------  --------------------------------------------------------------
  04-DEC-2013 RDAS         Initial Version.
  24-FEB-2015 Gubendran K  Added the condition to ignore kanban cards with sourc type as 'supplier' CHG0034559

*******************************************************************************************************/
  PROCEDURE  p_chng_kanban_status(errbuf             OUT  varchar2
                                 ,retcode            OUT  number
                                 ,p_mfg_org_id       IN   number
                                 ,p_kanban_status    IN   varchar2)
  AS
    lv_return_status                  varchar2(50);
    ln_msg_count                      number;
    lv_msg_data                       varchar2(200);
    ln_message_idx                    number;
    lv_st_ret_status                  varchar2(50);
    ln_st_msg_count                   number;
    lv_st_msg_data                    varchar2(200);
    ln_st_message_idx                 number;
    ln_qty_onhand                     number;
    ln_res_qty_onhand                 number;
    ln_qty_reserved                   number;
    ln_qty_suggested                  number;
    ln_qty_to_transact                number;
    ln_qty_to_reserve                 number;
    ln_supply_status                  number;

    CURSOR  kanban_cur  IS
    select  kc.kanban_card_number,
            kc.kanban_card_id,
            kc.organization_id,
            kps.inventory_item_id,
            itm.segment1 item_number,
            kps.subinventory_name,
            kps.locator_id,
            kps.minimum_order_quantity
      from  MTL_KANBAN_CARDS kc,
            MTL_KANBAN_PULL_SEQUENCES kps,
            mtl_system_items itm
     where  kc.organization_id          = p_mfg_org_id
       and  kc.card_status              = 1
       and  kc.supply_status not in (5,6,7) -- Not 'In process', 'In Transit' or 'Exception'
       and  kc.pull_sequence_id         = kps.pull_sequence_id
       and  kps.inventory_item_id       = itm.inventory_item_id
       and  itm.organization_id         = p_mfg_org_id
       and  kps.source_type <> 2 -- Supplier -- Added CHG0034559 Change --
       and  kps.minimum_order_quantity is not null;

  BEGIN

    IF p_kanban_status = 'WAIT' THEN
      ln_supply_status  := INV_KANBAN_PVT.G_Supply_Status_Wait;

    ELSE
      ln_supply_status  := INV_KANBAN_PVT.G_Supply_Status_Empty;

    END IF;

    FOR  kanban_rec IN kanban_cur
    LOOP

      -- Getting Onhand quantity
      --
      inv_quantity_tree_pub.query_quantities
         (p_api_version_number   	          => 1.0
         , x_return_status        	          => lv_return_status
         , x_msg_count            	          => ln_msg_count
         , x_msg_data             	          => lv_msg_data
         , p_organization_id                      => p_mfg_org_id
         , p_inventory_item_id                    => kanban_rec.inventory_item_id
         , p_tree_mode                            => inv_quantity_tree_pub.g_transaction_mode
         , p_is_revision_control                  => FALSE
         , p_is_lot_control                       => FALSE
         , p_is_serial_control                    => FALSE
         , p_revision             	          => null
         , p_lot_number           	          => null
         , p_subinventory_code    	          => kanban_rec.subinventory_name
         , p_locator_id           	          => kanban_rec.locator_id
         , x_qoh                  	          => ln_qty_onhand
         , x_rqoh                 	          => ln_res_qty_onhand
         , x_qr                   	          => ln_qty_reserved
         , x_qs                   	          => ln_qty_suggested
         , x_att                                  => ln_qty_to_transact
         , x_atr                  	          => ln_qty_to_reserve
         );

       FND_FILE.PUT_LINE(FND_FILE.log,'lv_return_sataus: ' || lv_return_status);
       FND_FILE.PUT_LINE(FND_FILE.log,'ln_qty_onhand: ' || ln_qty_onhand);

       IF lv_return_status  =  FND_API.G_RET_STS_SUCCESS THEN

         FND_FILE.PUT_LINE(FND_FILE.log,'Kanban Card Number: ' || kanban_rec.kanban_card_number);
         FND_FILE.PUT_LINE(FND_FILE.log,'Minumum Order Quantity: ' || kanban_rec.minimum_order_quantity);
     
         -- If onhand quantity is less than the minimum order quantity
         -- change the Supply status.
         IF ln_qty_onhand < kanban_rec.minimum_order_quantity THEN
            inv_Kanban_pub. Update_Card_Supply_Status
                            (p_api_version_number            => 1.0,
                             p_init_msg_list                 => FND_API.G_TRUE,
                             p_commit                        => FND_API.G_TRUE,
                             x_msg_count                     => ln_st_msg_count,
                             x_msg_data                      => lv_st_msg_data,
                             X_Return_Status                 => lv_st_ret_status,
                             p_Kanban_Card_Id                => kanban_rec.kanban_card_id,
                             p_Supply_Status                 => ln_supply_status);

             FND_FILE.PUT_LINE(FND_FILE.log,'lv_st_ret_status: ' || lv_st_ret_status);
      
         END IF;

        ELSE
          FND_FILE.PUT_LINE(FND_FILE.log,'Did not Update Statsu for Kanban Card: ''' || kanban_rec.kanban_card_number || '''');
          FND_FILE.PUT_LINE(FND_FILE.log,'Error Getting Onhand quantity for item: ''' || kanban_rec.item_number || '''');

        END IF;

   END LOOP;
  END p_chng_kanban_status;
END xx_inv_kanban_status_chng_pkg;
/