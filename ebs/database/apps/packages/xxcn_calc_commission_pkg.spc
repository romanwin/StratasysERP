CREATE OR REPLACE PACKAGE xxcn_calc_commission_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: XXOE_RESELLER_ORDER_REL_PKG     
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: Master program for handling the pre-calculation step of commissions for consumable
--          items. This includes managing the relationship of systems to consumables for that 
--          calculation.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------

   FUNCTION get_consumable_id(
      p_business_line      VARCHAR2
   ,  p_product            VARCHAR2
   ,  p_family             VARCHAR2
   ,  p_inventory_item_id  NUMBER
   ,  p_inventory_org_id   NUMBER
   )
   RETURN NUMBER;

   FUNCTION get_system_id(
      p_business_line      VARCHAR2
   ,  p_product            VARCHAR2
   ,  p_family             VARCHAR2
   ,  p_inventory_item_id  NUMBER
   ,  p_inventory_org_id   NUMBER
   )
   RETURN NUMBER;

   PROCEDURE bulk_load_system_consumables(
      errbuff           OUT VARCHAR2
   ,  retcode           OUT NUMBER 
   );

   PROCEDURE update_calc_comm_lines(
      x_return_status   OUT VARCHAR2
   ,  x_return_msg      OUT VARCHAR2
   );

   PROCEDURE link_consumables_to_systems(
      errbuff                          OUT VARCHAR2
   ,  retcode                          OUT NUMBER
   ,  p_start_date                     IN  VARCHAR2
   ,  p_end_date                       IN  VARCHAR2
   ,  p_factor_delivery_confirm_date   IN  VARCHAR2   DEFAULT 'N'
   ,  p_reseller_id                    IN  NUMBER
   ,  p_trx_number                     IN  VARCHAR2
   ,  p_report_only                    IN  VARCHAR2
   ,  p_org_id                         IN  NUMBER
   );
  
   FUNCTION get_count_linked_recs(
      p_record_id    NUMBER
   ,  p_record_type  VARCHAR2
   )
   RETURN NUMBER;
   
 
   PROCEDURE lock_system_consumable (
      p_record_type              IN    VARCHAR2
   ,  p_system_item_rec          IN    xxcn_system_items%ROWTYPE
   ,  p_consumable_item_rec      IN    xxcn_consumable_items%ROWTYPE
   ,  p_system_to_consumable_rec IN    xxcn_system_to_consumable%ROWTYPE
   ,  x_return_status            OUT   VARCHAR2
   ,  x_return_msg               OUT   VARCHAR2
   );

   PROCEDURE update_system_consumable (
      p_record_type              IN       VARCHAR2
   ,  p_update_all_linked_recs   IN       VARCHAR2
   ,  p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  p_system_to_consumable_rec IN       xxcn_system_to_consumable%ROWTYPE      
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2   
   );

   PROCEDURE insert_system_consumable (
      p_record_type              IN       VARCHAR2
   ,  p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  p_system_to_consumable_rec IN       xxcn_system_to_consumable%ROWTYPE
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2
   );

   PROCEDURE delete_pre_commission(
      errbuff                       OUT VARCHAR2
   ,  retcode                       OUT NUMBER
   ,  p_request_id                  IN  NUMBER
   ,  p_clear_exception_table_only  IN  VARCHAR2 DEFAULT 'N'
   ,  p_remove_all_pending          IN  VARCHAR2 DEFAULT 'N'
   );

END xxcn_calc_commission_pkg;
/

SHOW ERRORS
   

