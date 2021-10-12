CREATE OR REPLACE PACKAGE xxagile_process_mfg_item_pkg IS

   ---------------------------------------------------------------------------
   -- $Header: xxagile_process_mfg_item_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_process_mfg_item_pkg
   -- Created: 05-Dec-2007
   -- Author  : Vinay Chappidi
   --------------------------------------------------------------------------
   -- Perpose: Wrapper package containing all customer item manufacturing wrapper procedure for item interface from Agile System
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   PROCEDURE process_mfg_item(p_mfg_name          IN VARCHAR2,
                              p_mfg_part_num      IN VARCHAR2,
                              p_inventory_item_id IN NUMBER,
                              p_transaction_type  IN VARCHAR2,
                              p_organization_id   IN NUMBER DEFAULT 23,
                              p_creation_date     IN DATE,
                              p_created_by        IN NUMBER,
                              p_last_update_date  IN DATE,
                              p_last_update_by    IN NUMBER,
                              p_attribute1        IN VARCHAR2, -- package quantity
                              p_attribute2        IN VARCHAR2, -- device marking, varchar2(15)
                              p_attribute3        IN DATE, -- obsolete date
                              p_attribute4        IN VARCHAR2, -- RoSH Compliant, varchar2(10)
                              p_attribute6        IN VARCHAR2, -- preferred, varchar2(15)
                              x_return_status     OUT NOCOPY VARCHAR2,
                              x_error_code        OUT NOCOPY NUMBER,
                              x_msg_count         OUT NOCOPY NUMBER,
                              x_msg_data          OUT NOCOPY VARCHAR2);

END xxagile_process_mfg_item_pkg;
/

