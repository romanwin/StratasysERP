CREATE OR REPLACE TRIGGER xxpo_pohdistr_il_index
---------------------------------------------------------------------------
-- Trigger   :        xxpo_pohdistr_il_index
-- Created by:        Nili
-- creation date:     31/08/09
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:           
---------------------------------------------------------------------------
--  ver   date        name            desc
--  1.0   31/08/09    Nili            Initial Build
--  1.1   16/05/2010  Dalit A. Raviv  CUST314 - PO transfer REQ DFF to PO DFF
--                                    Find requisition lines that connect to specific po_line_id
--                                    get the max need_by_date from the requisition_line 
--                                    and from this line get attribute2 value.
--                                    copy req line attribute2 to po line attribute2.
---------------------------------------------------------------------------
  AFTER INSERT
  ON po_distributions_all
  FOR EACH ROW

DECLARE
   l_curr              po_headers_all.currency_code%TYPE;
   l_date              DATE;
   l_type              po_headers_all.type_lookup_code%TYPE;
   l_po_curr           po_headers_all.currency_code%TYPE;
   l_num               po_headers_all.segment1%TYPE;
   --l_encumbered_amount po_distributions_all.encumbered_amount%TYPE;
   l_po_date           po_headers_all.rate_date%TYPE;

   l_mfg_part_number   VARCHAR2(240) := NULL;
   l_att2              varchar2(150) := null;

BEGIN

   BEGIN

      IF :NEW.req_distribution_id IS NOT NULL THEN

         SELECT rl.manufacturer_part_number || '|' || rl.manufacturer_name
           INTO l_mfg_part_number
           FROM po_requisition_lines_all rl, po_req_distributions_all rd
          WHERE rl.requisition_line_id = rd.requisition_line_id AND
                rd.distribution_id = :NEW.req_distribution_id AND
                rl.manufacturer_part_number IS NOT NULL;

      END IF;

      IF l_mfg_part_number IS NULL THEN

         SELECT mfg.mfg_part_num || '|' || mm.manufacturer_name
           INTO l_mfg_part_number
           FROM po_lines_all         pl,
                mtl_manufacturers    mm,
                mtl_mfg_part_numbers mfg
          WHERE nvl(mfg.end_date, SYSDATE + 1) > SYSDATE AND
                mfg.inventory_item_id = pl.item_id AND
                mfg.manufacturer_id = mm.manufacturer_id AND
                pl.po_line_id = :NEW.po_line_id AND
                pl.attribute1 IS NULL;

      END IF;

   EXCEPTION
      WHEN too_many_rows THEN
         BEGIN

            SELECT mfg.mfg_part_num || '|' || trim(substr(s.vendor_name, 1, 30))
              INTO l_mfg_part_number
              FROM ap_suppliers         s,
                   po_headers_all       ph,
                   po_lines_all         pl,
                   mtl_manufacturers    mm,
                   mtl_mfg_part_numbers mfg
             WHERE nvl(mfg.end_date, SYSDATE + 1) > SYSDATE AND
                   mfg.inventory_item_id = pl.item_id AND
                   mfg.manufacturer_id = mm.manufacturer_id AND
                   pl.po_header_id = ph.po_header_id AND
                   ph.vendor_id = s.vendor_id AND
                   trim(substr(s.vendor_name, 1, 30)) = mm.manufacturer_name AND
                   pl.po_line_id = :NEW.po_line_id AND
                   pl.attribute1 IS NULL;

         EXCEPTION
            WHEN OTHERS THEN
               l_mfg_part_number := NULL;
         END;
      WHEN OTHERS THEN
         l_mfg_part_number := NULL;
   END;

   IF REPLACE(l_mfg_part_number, '|', NULL) IS NOT NULL THEN

      UPDATE po_lines_all pl
         SET attribute1 = l_mfg_part_number
       WHERE pl.po_line_id = :NEW.po_line_id AND
             attribute1 IS NULL;

   END IF;

   IF nvl(fnd_profile.VALUE('XXPO_ENABLE_AUTO_LINKAGE'), 'N') = 'Y' THEN
      --
      -- Get PO Data
      --
      xxpo_utils_pkg.get_po_type_num_curr(:NEW.po_header_id,
                                          l_type,
                                          l_po_curr,
                                          l_num,
                                          l_po_date);

      IF nvl(l_type, 'XXX') = 'STANDARD' THEN

         IF :NEW.req_distribution_id IS NOT NULL THEN

            xxpo_utils_pkg.should_do_linkage(p_req_distribution_id => :NEW.req_distribution_id,
                                             p_curr_return         => l_curr,
                                             p_date_return         => l_date);

            --
            -- check if the currency is different
            --
            IF nvl(l_curr, 'USD') != nvl(l_po_curr, 'USD') THEN

               --
               -- Do the linakge
               --
               xxpo_utils_pkg.do_linkage(p_po_num        => l_num,
                                         p_po_line_id    => :NEW.po_line_id,
                                         p_from_currency => nvl(l_curr,
                                                                'USD'),
                                         p_to_currency   => l_po_curr,
                                         p_base_date     => nvl(l_date,
                                                                l_po_date));
            END IF;
         END IF;
      END IF;
   END IF;
   
  -- 1.1 Dalit A. Raviv 16/05/2010 
  if nvl(fnd_profile.VALUE('XXPO_REQ_LINE_ENABLE_TRG'), 'N') = 'Y' THEN  
    -- Get all requisition lines that connect to this po distribution
    begin
      select prl.attribute2 prl_att2
      into   l_att2
      from   po_req_distributions_all   prd,
             po_requisition_lines_all   prl,
             po_requisition_headers_all prh
      where  prd.requisition_line_id    = prl.requisition_line_id
      and    prl.requisition_header_id  = prh.requisition_header_id
      and    prd.distribution_id        = :new.req_distribution_id;
    exception
      when others then
        l_att2 := null;
    end;
       
    if l_att2 is not null then  
      begin
        update po_lines_all  pl
        set    attribute2    = l_att2
        where  pl.po_line_id = :new.po_line_id 
        and    attribute2    is null;
      exception
        when others then
          null;
      end; 
    end if;   
  end if;
  -- end 1.1 16/05/2010 
    
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/

