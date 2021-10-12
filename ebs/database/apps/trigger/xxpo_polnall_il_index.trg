CREATE OR REPLACE TRIGGER xxpo_polnall_il_index
   ---------------------------------------------------------------------------
   -- $Header: xxpo_polnall_il_index 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxpo_polnall_il_index
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Auto Linkage 
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09  Nili            Initial Build
   ---------------------------------------------------------------------------
BEFORE INSERT OR UPDATE OF UNIT_PRICE ON po_lines_all
FOR EACH ROW
DECLARE
   l_curr po_headers_all.currency_code%TYPE;
   --l_date date;
   l_type    po_headers_all.type_lookup_code%TYPE;
   l_po_curr po_headers_all.currency_code%TYPE;
   l_num     po_headers_all.segment1%TYPE;
   l_po_date po_headers_all.rate_date%TYPE;
   l_rate    clef062_po_index_esc_set.base_rate%TYPE;
   --l_conv_type clef062_po_index_esc_set.conversion_type%type;
   l_att3 po_lines_all.attribute3%TYPE := substr(:NEW.attribute3,
                                                 1,
                                                 length(:NEW.attribute3) - 4);
BEGIN

   IF nvl(fnd_profile.VALUE('XXPO_ENABLE_AUTO_LINKAGE'), 'N') = 'Y' THEN
   
      --
      -- Get PO Data
      --  
      xxpo_utils_pkg.get_po_type_num_curr(:NEW.po_header_id,
                                          l_type,
                                          l_po_curr,
                                          l_num,
                                          l_po_date);
   
      xxpo_utils_pkg.get_linkage(p_po_num => l_num,
                                 p_rate   => l_rate,
                                 p_curr   => l_curr);
   
      IF nvl(l_rate, 0) = 0 THEN
         RETURN;
      END IF;
   
      l_att3 := ltrim(rtrim(REPLACE(:NEW.attribute3, l_curr)));
   
      --
      -- Update linkage
      --
      /*if updating('ATTRIBUTE3') and nvl(l_rate,0) != 0  then
      
         if trunc(:new.UNIT_PRICE , 5) != trunc((l_att3 / :new.QUANTITY) * l_rate ,5) then
          :new.UNIT_PRICE := (l_att3 / :new.QUANTITY) * l_rate; 
         end if;
      els*/
      IF /*updating('UNIT_PRICE') AND*/
       nvl(l_rate, 0) != 0 THEN
         IF nvl(trunc(l_att3, 5), -1) !=
            trunc(round(:NEW.unit_price) / l_rate, 5) THEN
            :NEW.attribute3 := to_char(round(:NEW.unit_price / l_rate, 4)) || ' ' ||
                               l_curr;
         END IF;
      
      END IF;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/

