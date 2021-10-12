CREATE OR REPLACE PACKAGE xxagile_proc_item_categ_pkg IS
   ---------------------------------------------------------------------------
   -- $Header: xxagile_proc_item_categ_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_proc_item_categ_pkg
   -- Created: 05-Dec-2007
   -- Author  : Vinay Chappidi
   --------------------------------------------------------------------------
   -- Perpose: Wrapper package containing all customer item category wrapper procedure for item interface from Agile System
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   PROCEDURE process_item_categ(p_inventory_item_id IN NUMBER,
                                p_category_set_name IN VARCHAR2,
                                p_category_name     IN VARCHAR2,
                                p_creation_date     IN DATE,
                                p_created_by        IN NUMBER,
                                p_last_update_date  IN DATE,
                                p_last_update_by    IN NUMBER,
                                x_return_status     OUT NOCOPY VARCHAR2,
                                x_error_code        OUT NOCOPY NUMBER,
                                x_msg_count         OUT NOCOPY NUMBER,
                                x_msg_data          OUT NOCOPY VARCHAR2);
   -- procedure apps_initialize(p_user_id in number);

END xxagile_proc_item_categ_pkg;
/

