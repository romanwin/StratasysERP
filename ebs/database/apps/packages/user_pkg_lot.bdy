CREATE OR REPLACE PACKAGE BODY user_pkg_lot AS
  /* $Header: INVUDLGB.pls 120.0.12010000.5 2011/09/19 12:38:47 kbavadek ship $ */

  -- OPM Convergence - added parent lot number
  -- Bug#4145437 - Increased length of uesr lot number.

  -- Fix for Bug#12925054. Added p_transaction_source_id and p_transaction_source_line_id
  -- so that batch or wip job information can be included

  -- INC0074245  yuval tal add custom code which was override by patch 

  FUNCTION generate_lot_number(p_org_id                     IN NUMBER,
		       p_inventory_item_id          IN NUMBER,
		       p_transaction_date           IN DATE,
		       p_revision                   IN VARCHAR2,
		       p_subinventory_code          IN VARCHAR2,
		       p_locator_id                 IN NUMBER,
		       p_transaction_type_id        IN NUMBER,
		       p_transaction_action_id      IN NUMBER,
		       p_transaction_source_type_id IN NUMBER,
		       p_transaction_source_id      IN NUMBER,
		       p_transaction_source_line_id IN NUMBER,
		       p_lot_number                 IN VARCHAR2,
		       p_parent_lot_number          IN VARCHAR2,
		       x_return_status              OUT NOCOPY VARCHAR2)
    RETURN VARCHAR2 IS
    --  l_user_lot_number    VARCHAR2(300);
    --BEGIN
    -- x_return_status := FND_API.G_RET_STS_SUCCESS;
    -- RETURN  (l_user_lot_number);
  
    l_user_lot_number VARCHAR2(300) := NULL;
    l_lot_prefix      mtl_system_items_b.auto_lot_alpha_prefix%TYPE;
    l_lot_number      NUMBER;
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
  
    -- get prefix 
    BEGIN
      SELECT msib.auto_lot_alpha_prefix
      INTO   l_lot_prefix
      FROM   mtl_system_items_b msib
      WHERE  msib.inventory_item_id = p_inventory_item_id
      AND    msib.organization_id = p_org_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_lot_prefix := NULL;
    END;
  
    -- get next number in sequence
    IF l_lot_prefix = 'MTL' THEN
    
      SELECT xxinv_generate_mtl_lot_s.nextval
      INTO   l_lot_number
      FROM   dual;
      l_user_lot_number := l_lot_prefix || l_lot_number;
    
    ELSIF l_lot_prefix = 'RES' THEN
    
      SELECT xxinv_generate_res_lot_s.nextval
      INTO   l_lot_number
      FROM   dual;
      l_user_lot_number := l_lot_prefix || l_lot_number;
    
    END IF;
  
    RETURN(l_user_lot_number);
  END;

  -- Bug6836808 to allow New Lots Based on custom code

  FUNCTION allow_new_lots(p_transaction_type_id IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    /* Custom code starts for user */
  
    /* Custom code Ends */
    RETURN(TRUE);
  END allow_new_lots;

  --Expired lots custom hook
  FUNCTION use_expired_lots(p_organization_id       IN NUMBER,
		    p_inventory_item_id     IN NUMBER,
		    p_demand_source_type_id IN NUMBER,
		    p_demand_source_line_id IN NUMBER) RETURN BOOLEAN IS
  
    l_debug NUMBER;
  BEGIN
  
    l_debug := nvl(fnd_profile.value('INV_DEBUG_TRACE'), 0);
    IF (l_debug = 1) THEN
      inv_trx_util_pub.trace('Entered use_expired_lots',
		     'use_expired_lots',
		     9);
    END IF;
  
    /* Space for custom logic. Please ensure return values are correct */
    ------------------------------------
    ------------------------------------
  
    IF (l_debug = 1) THEN
      inv_trx_util_pub.trace('returning FALSE', 'use_expired_lots', 9);
    END IF;
    RETURN FALSE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF (l_debug = 1) THEN
        inv_trx_util_pub.trace('Exception:' || SQLERRM,
		       'use_expired_lots',
		       9);
      END IF;
      RETURN FALSE;
  END use_expired_lots;

END user_pkg_lot;
/
