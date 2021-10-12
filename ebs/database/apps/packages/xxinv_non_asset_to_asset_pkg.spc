CREATE OR REPLACE PACKAGE XXINV_NON_ASSET_TO_ASSET_PKG IS
   ---------------------------------------------------------------------------
   -- $Header: XXINV_NON_ASSET_TO_ASSET_PKG 120.0 2010/05/09  $
   ---------------------------------------------------------------------------
   -- Package: XXINV_NON_ASSET_TO_ASSET_PKG
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Non Asset To Asset Prevention (Subinventory Transfers: 
   --                          From Asset Subinv1 to Asset Subinv2 OR From Non Asset Subinv1 to Non Asset Subinv2
   --
   --------------------------------------------------------------------------
   -- Version  Date        Performer       Comments
   ----------  --------    --------------  ----------------------------------
   --     1.0  09/05/2010  Vitaly K.       Initial Build
   ---------------------------------------------------------------------------
   FUNCTION non_asset_to_asset_prevention(p_organization_id   IN NUMBER,
                                          p_from_subinventory IN VARCHAR2,
                                          p_to_subinventory   IN VARCHAR2) RETURN VARCHAR2;

END XXINV_NON_ASSET_TO_ASSET_PKG;
/

