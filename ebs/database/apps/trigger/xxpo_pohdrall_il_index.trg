CREATE OR REPLACE TRIGGER xxpo_pohdrall_il_index
   ---------------------------------------------------------------------------
   -- $Header: xxpo_pohdrall_il_index 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxpo_pohdrall_il_index
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Auto Linkage 
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09  Nili            Initial Build
   ---------------------------------------------------------------------------
AFTER UPDATE OF segment1 ON po_headers_all
FOR EACH ROW
BEGIN
   IF nvl(fnd_profile.VALUE('XXPO_ENABLE_AUTO_LINKAGE'), 'N') = 'Y' THEN
   
      --
      -- Update linkage
      --
      UPDATE clef062_po_index_esc_set ll
         SET ll.document_id = :NEW.segment1
       WHERE ll.document_id = :OLD.segment1 AND
             ll.module = 'PO';
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/

