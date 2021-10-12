CREATE OR REPLACE PACKAGE BODY XXINV_NON_ASSET_TO_ASSET_PKG IS

   FUNCTION non_asset_to_asset_prevention(p_organization_id   IN NUMBER,
                                          p_from_subinventory IN VARCHAR2,
                                          p_to_subinventory   IN VARCHAR2) RETURN VARCHAR2 IS
       v_step                         VARCHAR2(100);
       v_from_subinv_asset_inventory  NUMBER; 
       v_to_subinv_asset_inventory    NUMBER; 
       v_message                      VARCHAR2(1000);
       
       CURSOR get_asset_inventory (p_inv_organization_id NUMBER,
                                   p_subinventory        VARCHAR2) IS
       SELECT msinv.asset_inventory
       FROM   mtl_secondary_inventories  msinv
       WHERE  msinv.secondary_inventory_name=p_subinventory      ---cursor param
       AND    msinv.organization_id=p_inv_organization_id; ---current inventory organization      
       
   BEGIN   
                                                     
       v_step:='Step 1';
       IF p_organization_id   IS NULL OR
          p_from_subinventory IS NULL OR
          p_to_subinventory   IS NULL THEN
            RETURN 'MISSING PARAMETER';   ----NULL; --missing parameter
       END IF;       
       v_step:='Step 10';
       OPEN get_asset_inventory(p_organization_id,p_from_subinventory);
       FETCH get_asset_inventory INTO v_from_subinv_asset_inventory;
       IF get_asset_inventory%NOTFOUND THEN
           CLOSE get_asset_inventory;
           RETURN 'Subinventory '||p_from_subinventory||' (from subinv) does not exist in MTL_SECONDARY_INVENTORIES table for organization_id='||p_organization_id;
       END IF;
       CLOSE get_asset_inventory;
       v_step:='Step 20';
       OPEN get_asset_inventory(p_organization_id,p_to_subinventory);
       FETCH get_asset_inventory INTO v_to_subinv_asset_inventory;
       IF get_asset_inventory%NOTFOUND THEN
           CLOSE get_asset_inventory;
           RETURN 'Subinventory '||p_to_subinventory||' (to subinv) does not exist in MTL_SECONDARY_INVENTORIES table for organization_id='||p_organization_id;
       END IF;
       CLOSE get_asset_inventory;
       v_step:='Step 30';
       IF v_from_subinv_asset_inventory!=v_to_subinv_asset_inventory THEN
           IF v_from_subinv_asset_inventory=2 THEN
               fnd_message.set_name('XXOBJT','XXINV_NON_ASSET_TO_ASSET_PREV');
               v_message := fnd_message.get;
               RETURN v_message;
               ----RETURN 'Subinventory Transfer from Non Asset to Asset was prohibited';
           ELSE
               fnd_message.set_name('XXOBJT','XXINV_ASSET_TO_NON_ASSET_PREV');
               v_message := fnd_message.get;
               RETURN v_message;
               ----RETURN 'Subinventory Transfer from Asset to Non Asset was prohibited';
           END IF;
       END IF;       
       
       RETURN 'VALID';   ----NULL; --No prevention...Its OK
   EXCEPTION
      WHEN OTHERS THEN
        RETURN 'Unexpected Error in XXINV_NON_ASSET_TO_ASSET_PKG.non_asset_to_asset_prevention ,'||v_step||'  '||substr(SQLERRM,1,200);
   END non_asset_to_asset_prevention;
   
END XXINV_NON_ASSET_TO_ASSET_PKG;
/

