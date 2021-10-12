CREATE OR REPLACE PACKAGE xxagile_process_cust_item_pkg IS

   ---------------------------------------------------------------------------
   -- $Header: XXAGILE_PROCESS_CUST_ITEM_PKG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: XXAGILE_PROCESS_CUST_ITEM_PKG
   -- Created: Vinay Chappidi
   -- Author  : 05-Dec-2007
   --------------------------------------------------------------------------
   -- Perpose: Wrapper package containing all customer item wrapper procedure for item interface from Agile System
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   PROCEDURE process_customer_item(p_customer_name         IN VARCHAR2,
                                   p_customer_item         IN VARCHAR2,
                                   p_inventory_item_id     IN NUMBER,
                                   p_inactive_flag         IN VARCHAR2,
                                   p_preference_number     IN NUMBER,
                                   p_item_definition_level IN NUMBER DEFAULT 1,
                                   p_organization_id       IN NUMBER DEFAULT 23,
                                   p_customer_item_desc    IN VARCHAR2, -- varchar2(240)
                                   p_creation_date         IN DATE,
                                   p_created_by            IN NUMBER,
                                   p_last_update_date      IN DATE,
                                   p_last_update_by        IN NUMBER,
                                   x_return_status         OUT NOCOPY VARCHAR2,
                                   x_error_code            OUT NOCOPY NUMBER,
                                   x_msg_count             OUT NOCOPY NUMBER,
                                   x_msg_data              OUT NOCOPY VARCHAR2);

END xxagile_process_cust_item_pkg;
/

