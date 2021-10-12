CREATE OR REPLACE PACKAGE BODY xxpo_communication_report_pkg IS
  ---------------------------------------------------------------------------
  -- Package: xxpo_communication_report_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Wrapper for po doscuments
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------

  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  21/05/2013     Vitaly             initial revision (CR763)
  --    1.0  21.5.13   Vitaly         CR763 -- get_uom_tl added
  --    1.0   3.6.13   YUVAL TAL      CR-805 :Purchase PDF documents does not show linkage
  --                                                 modify get_rate_baserate_for_xml,
  --                                                 get_rate_baserate_for_xml,
  --                                                 get_rate_cur_for_xml
  --    1.1  10.6.13  yuval tal       Cust004- bugfix 821 add parameter  p_release_num and call to XXPO_utils_pkg.get_last_linkage_creation to 
  --                                     get_rate_cur_for_xml
  --                                     get_rate_baserate_for_xml
  --                                     get_rate_basedate_for_xml,
  --                                     get_converted_amount
  --                                     add get_release_num 

  ---------------------------------------------------------------------------
  FUNCTION get_total(x_object_type IN VARCHAR2, x_object_id IN NUMBER)
    RETURN NUMBER IS
    x_progress        VARCHAR2(3) := NULL;
    x_base_currency   VARCHAR2(16);
    x_po_currency     VARCHAR2(16);
    x_min_unit        NUMBER;
    x_base_min_unit   NUMBER;
    x_precision       INTEGER;
    x_base_precision  INTEGER;
    x_result_fld      NUMBER;
    l_org_id          hr_all_organization_units.organization_id%TYPE;
    x_base_cur_result BOOLEAN := NULL;
  BEGIN
    IF (x_object_type IN ('H', 'B')) THEN
    
      /*      if x_base_cur_result then
        \* Result should be returned in base currency. Get the currency code
           of the PO and the base currency code
        *\
        x_progress := 10;
        po_core_s2.get_po_currency(x_object_id,
                                   x_base_currency,
                                   x_po_currency);
      
        \* Chk if base_currency = po_currency *\
        if x_base_currency <> x_po_currency then
          \* Get precision and minimum accountable unit of the PO CURRENCY *\
          x_progress := 20;
          po_core_s2.get_currency_info(x_po_currency,
                                       x_precision,
                                       x_min_unit);
        
          \* Get precision and minimum accountable unit of the base CURRENCY *\
          x_progress := 30;
          po_core_s2.get_currency_info(x_base_currency,
                                       x_base_precision,
                                       x_base_min_unit);
        
          if X_base_min_unit is null then
          
            if X_min_unit is null then
            
              x_progress := 40;
            
              \* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
                 849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                                    we pass to GL is the round of individual dist. amounts
                                    and the sum of these rounded values is what should be
                                    displayed as the header total.
              *\
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(sum(round(round((decode(POD.quantity_ordered,
                                                 null,
                                                 (nvl(POD.amount_ordered, 0) -
                                                 nvl(POD.amount_cancelled,
                                                      0)),
                                                 ((nvl(POD.quantity_ordered,
                                                       0) -
                                                 nvl(POD.quantity_cancelled,
                                                       0)) *
                                                 nvl(PLL.price_override, 0))) *
                                         POD.rate),
                                         X_precision),
                                   X_base_precision)),
                         0)
                INTO X_result_fld
                FROM PO_DISTRIBUTIONS_ALL POD, PO_LINE_LOCATIONS_ALL PLL
               WHERE PLL.po_header_id = X_object_id
                 AND PLL.shipment_type in
                     ('STANDARD', 'PLANNED', 'BLANKET')
                 AND PLL.line_location_id = POD.line_location_id;
            
            else
              x_progress := 42;
            
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(sum(round(round(decode(POD.quantity_ordered,
                                                null,
                                                (nvl(POD.amount_ordered, 0) -
                                                nvl(POD.amount_cancelled, 0)),
                                                ((nvl(POD.quantity_ordered,
                                                      0) -
                                                nvl(POD.quantity_cancelled,
                                                      0)) *
                                                nvl(PLL.price_override, 0))) *
                                         POD.rate / X_min_unit) *
                                   X_min_unit,
                                   X_base_precision)),
                         0)
                INTO X_result_fld
                FROM PO_DISTRIBUTIONS_ALL POD, PO_LINE_LOCATIONS_ALL PLL
               WHERE PLL.po_header_id = X_object_id
                 AND PLL.shipment_type in
                     ('STANDARD', 'PLANNED', 'BLANKET')
                 AND PLL.line_location_id = POD.line_location_id;
            
            end if;
          
          else
            \* base_min_unit is NOT null *\
          
            if X_min_unit is null then
              x_progress := 44;
            
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(sum(round(round(decode(POD.quantity_ordered,
                                                null,
                                                (nvl(POD.amount_ordered, 0) -
                                                nvl(POD.amount_cancelled, 0)),
                                                (nvl(POD.quantity_ordered, 0) -
                                                nvl(POD.quantity_cancelled,
                                                     0)) *
                                                nvl(PLL.price_override, 0)) *
                                         POD.rate,
                                         X_precision) / X_base_min_unit) *
                             X_base_min_unit),
                         0)
                INTO X_result_fld
                FROM PO_DISTRIBUTIONS_ALL POD, PO_LINE_LOCATIONS_ALL PLL
               WHERE PLL.po_header_id = X_object_id
                 AND PLL.shipment_type in
                     ('STANDARD', 'PLANNED', 'BLANKET')
                 AND PLL.line_location_id = POD.line_location_id;
            
            else
              x_progress := 46;
            
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(sum(round(round(decode(POD.quantity_ordered,
                                                null,
                                                (nvl(POD.amount_ordered, 0) -
                                                nvl(POD.amount_cancelled, 0)),
                                                (nvl(POD.quantity_ordered, 0) -
                                                nvl(POD.quantity_cancelled,
                                                     0)) *
                                                nvl(PLL.price_override, 0)) *
                                         POD.rate / X_min_unit) *
                                   X_min_unit / X_base_min_unit) *
                             X_base_min_unit),
                         0)
                INTO X_result_fld
                FROM PO_DISTRIBUTIONS_ALL POD, PO_LINE_LOCATIONS_ALL PLL
               WHERE PLL.po_header_id = X_object_id
                 AND PLL.shipment_type in
                     ('STANDARD', 'PLANNED', 'BLANKET')
                 AND PLL.line_location_id = POD.line_location_id;
            
            end if;
          
          end if;
        
        end if; \* x_base_currency <> x_po_currency *\
      
      else*/
    
      /* if we donot want result converted to base currency or if
      the currencies are the same then do the check without
      rate conversion */
    
      /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
         849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                            we pass to GL is the round of individual dist. amounts
                            and the sum of these rounded values is what should be
                            displayed as the header total.
      */
    
      x_progress := 50;
    
      --< Bug 3549096 > Use _ALL tables instead of org-striped views.
      SELECT c.minimum_accountable_unit, c.precision
        INTO x_min_unit, x_precision
        FROM fnd_currencies c, po_headers_all ph
       WHERE ph.po_header_id = x_object_id
         AND c.currency_code = ph.currency_code;
    
      IF x_min_unit IS NULL THEN
        x_progress := 53;
      
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT SUM(decode(pll.quantity,
                          NULL,
                          (pll.amount - nvl(pll.amount_cancelled, 0)),
                          (pll.quantity - nvl(pll.quantity_cancelled, 0)) *
                          nvl(pll.price_override, 0)))
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.po_header_id = x_object_id
           AND pll.shipment_type IN ('STANDARD', 'PLANNED', 'BLANKET');
      
      ELSE
        /* Bug 1111926: GMudgal 2/18/2000
        ** Incorrect placement of brackets caused incorrect rounding
        ** and consequently incorrect PO header totals
        */
        x_progress := 56;
      
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT SUM(round(decode(pll.quantity,
                                NULL,
                                (pll.amount - nvl(pll.amount_cancelled, 0)),
                                (pll.quantity -
                                nvl(pll.quantity_cancelled, 0)) *
                                nvl(pll.price_override, 0)) / x_min_unit) *
                   x_min_unit)
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.po_header_id = x_object_id
           AND pll.shipment_type IN ('STANDARD', 'PLANNED', 'BLANKET');
      
      END IF;
    
      --  end if;
    
      -- <GA FPI START>
      --
    
      -- <GC FPJ>
      -- Change x_object_type for GA from 'G' to 'GA'
    
    ELSIF (x_object_type = 'GA') THEN
      -- Global Agreement
    
      x_result_fld := 1; --get_ga_amount_released(x_object_id, x_base_cur_result);
      --
      -- <GA FPI END>
    
      -- <GC FPJ START>
    ELSIF (x_object_type = 'GC') THEN
      -- Global Contract
      x_result_fld := 1; --get_gc_amount_released(p_po_header_id    => x_object_id,
      --           p_convert_to_base => x_base_cur_result);
    
      -- <GC FPJ END>
    
    ELSIF (x_object_type = 'P') THEN
      /* For PO Planned */
    
      IF x_base_cur_result THEN
      
        /* Result should be returned in base currency. Get the currency code
        of the PO and the base currency code */
      
        x_progress := 60;
        po_core_s2.get_po_currency(x_object_id,
                                   x_base_currency,
                                   x_po_currency);
      
        /* Chk if base_currency = po_currency */
        IF x_base_currency <> x_po_currency THEN
          /* Get precision and minimum accountable unit of the PO CURRENCY */
          x_progress := 70;
          po_core_s2.get_currency_info(x_po_currency,
                                       x_precision,
                                       x_min_unit);
        
          /* Get precision and minimum accountable unit of the base CURRENCY */
          x_progress := 80;
          po_core_s2.get_currency_info(x_base_currency,
                                       x_base_precision,
                                       x_base_min_unit);
        
          /* iali - Bug 482497 - 05/09/97
             For Planned PO the PLL.shipment_type should be 'PLANNED' and not
             'SCHEDULED' as it was before. Adding both in the where clause by replacing
             eqality check with in clause.
          */
          -- Bugs 482497 and 602664, lpo, 12/22/97
          -- Actually, for planned PO, the shipment_type should remain to be 'SCHEDULED'.
          -- This will calculate the total released amount. (a shipment type of 'PLANNED'
          -- indicates the lines in the planned PO, therefore using IN ('PLANNED',
          -- 'SCHEDULED') will calculate the total released amount plus the amount
          -- agreed, which is not what we want.
          -- Refer to POXBWN3B.pls for fix to bug 482497.
        
          IF x_base_min_unit IS NULL THEN
          
            IF x_min_unit IS NULL THEN
            
              x_progress := 90;
            
              /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
                 849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                                    we pass to GL is the round of individual dist. amounts
                                    and the sum of these rounded values is what should be
                                    displayed as the header total.
              */
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round((nvl(pod.quantity_ordered, 0) -
                                         nvl(pod.quantity_cancelled, 0)) *
                                         nvl(pll.price_override, 0) *
                                         pod.rate,
                                         x_precision),
                                   x_base_precision)),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_header_id = x_object_id
                    -- Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.shipment_type = 'SCHEDULED'
                    -- End of fix. Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.line_location_id = pod.line_location_id;
            
            ELSE
              x_progress := 92;
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round((nvl(pod.quantity_ordered, 0) -
                                         nvl(pod.quantity_cancelled, 0)) *
                                         nvl(pll.price_override, 0) *
                                         pod.rate / x_min_unit) *
                                   x_min_unit,
                                   x_base_precision)),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_header_id = x_object_id
                    -- Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.shipment_type = 'SCHEDULED'
                    -- End of fix. Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.line_location_id = pod.line_location_id;
            END IF;
          
          ELSE
            /* base_min_unit is NOT null */
          
            IF x_min_unit IS NULL THEN
              x_progress := 94;
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round((nvl(pod.quantity_ordered, 0) -
                                         nvl(pod.quantity_cancelled, 0)) *
                                         nvl(pll.price_override, 0) *
                                         pod.rate,
                                         x_precision) / x_base_min_unit) *
                             x_base_min_unit),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_header_id = x_object_id
                    -- Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.shipment_type = 'SCHEDULED'
                    -- End of fix. Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.line_location_id = pod.line_location_id;
            
            ELSE
              x_progress := 96;
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round((nvl(pod.quantity_ordered, 0) -
                                         nvl(pod.quantity_cancelled, 0)) *
                                         nvl(pll.price_override, 0) *
                                         pod.rate / x_min_unit) *
                                   x_min_unit / x_base_min_unit) *
                             x_base_min_unit),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_header_id = x_object_id
                    -- Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.shipment_type = 'SCHEDULED'
                    -- End of fix. Bugs 482497 and 602664, lpo, 12/22/97
                 AND pll.line_location_id = pod.line_location_id;
            END IF;
          
          END IF;
        
        END IF; /* x_base_currency <> x_po_currency */
      
      ELSE
      
        /* if we donot want result converted to base currency or if
        the currencies are the same then do the check without
        rate conversion */
        x_progress := 100;
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT c.minimum_accountable_unit, c.precision
          INTO x_min_unit, x_precision
          FROM fnd_currencies c, po_headers_all ph
         WHERE ph.po_header_id = x_object_id
           AND c.currency_code = ph.currency_code;
      
        /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
           849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                              we pass to GL is the round of individual dist. amounts
                              and the sum of these rounded values is what should be
                              displayed as the header total.
        */
        IF x_min_unit IS NULL THEN
          x_progress := 103;
          --< Bug 3549096 > Use _ALL tables instead of org-striped views.
          SELECT SUM(round((pll.quantity - nvl(pll.quantity_cancelled, 0)) *
                           nvl(pll.price_override, 0),
                           x_precision))
            INTO x_result_fld
            FROM po_line_locations_all pll
           WHERE pll.po_header_id = x_object_id
                -- Bugs 482497 and 602664, lpo, 12/22/97
             AND pll.shipment_type = 'SCHEDULED';
          -- Bugs 482497 and 602664, lpo, 12/22/97
        ELSE
          /* Bug 1111926: GMudgal 2/18/2000
          ** Incorrect placement of brackets caused incorrect rounding
          ** and consequently incorrect PO header totals
          */
          x_progress := 106;
          --< Bug 3549096 > Use _ALL tables instead of org-striped views.
          SELECT SUM(round((pll.quantity - nvl(pll.quantity_cancelled, 0)) *
                           nvl(pll.price_override, 0) / x_min_unit) *
                     x_min_unit)
            INTO x_result_fld
            FROM po_line_locations_all pll
           WHERE pll.po_header_id = x_object_id
                -- Bugs 482497 and 602664, lpo, 12/22/97
             AND pll.shipment_type = 'SCHEDULED';
          -- End of fix. Bugs 482497 and 602664, lpo, 12/22/97
        END IF;
      
      END IF;
    
    ELSIF (x_object_type = 'E') THEN
      /* Requisition Header */
      x_progress := 110;
      --bug#5092574 Retrieve the doc org id and pass this to retrieve
      --the document currency. Bug 5124868: refactored this call
      l_org_id := po_moac_utils_pvt.get_entity_org_id(po_moac_utils_pvt.g_doc_type_requisition,
                                                      po_moac_utils_pvt.g_doc_level_header,
                                                      x_object_id); --bug#5092574
    
      po_core_s2.get_req_currency(x_object_id, x_base_currency, l_org_id); --bug#5092574
    
      x_progress := 120;
      po_core_s2.get_currency_info(x_base_currency,
                                   x_base_precision,
                                   x_base_min_unit);
    
      IF x_base_min_unit IS NULL THEN
        x_progress := 130;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
        
              round(sum((nvl(quantity,0) * nvl(unit_price,0))), x_base_precision)
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        -- <Bug 4036549, include cancelled lines with with delivered quantity>
      
        SELECT SUM(round(decode(quantity,
                                NULL,
                                nvl(amount, 0),
                                ((nvl(quantity, 0) -
                                nvl(quantity_cancelled, 0)) *
                                nvl(unit_price, 0))),
                         x_base_precision))
          INTO x_result_fld
          FROM po_requisition_lines_all
         WHERE requisition_header_id = x_object_id
           AND nvl(modified_by_agent_flag, 'N') = 'N';
      
      ELSE
        x_progress := 135;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
              select
              round(sum((nvl(quantity,0) * nvl(unit_price,0)/x_base_min_unit)*
                         x_base_min_unit))
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        -- <Bug 4036549, include cancelled lines with with delivered quantity>
        SELECT SUM(round(decode(quantity,
                                NULL,
                                nvl(amount, 0),
                                ((nvl(quantity, 0) -
                                nvl(quantity_cancelled, 0)) *
                                nvl(unit_price, 0))) / x_base_min_unit) *
                   x_base_min_unit)
          INTO x_result_fld
          FROM po_requisition_lines_all
         WHERE requisition_header_id = x_object_id
           AND nvl(modified_by_agent_flag, 'N') = 'N';
      
      END IF;
    
    ELSIF (x_object_type = 'I') THEN
      /* Requisition Line */
    
      x_progress := 140;
      --bug#5092574 Retrieve the doc org id and pass this to retrieve
      --the document currency. Bug 5124868: refactored this call
      l_org_id := po_moac_utils_pvt.get_entity_org_id(po_moac_utils_pvt.g_doc_type_requisition,
                                                      po_moac_utils_pvt.g_doc_level_line,
                                                      x_object_id); --bug#5092574
    
      po_core_s2.get_req_currency(x_object_id, x_base_currency, l_org_id); --bug#5092574
    
      x_progress := 150;
      po_core_s2.get_currency_info(x_base_currency,
                                   x_base_precision,
                                   x_base_min_unit);
    
      IF x_base_min_unit IS NULL THEN
        x_progress := 160;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
        
              select
              round(sum((nvl(quantity,0) * nvl(unit_price,0))), x_base_precision)
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        -- <Bug 4036549, include cancelled lines with with delivered quantity>
        SELECT SUM(round(decode(quantity,
                                NULL,
                                nvl(amount, 0),
                                ((nvl(quantity, 0) -
                                nvl(quantity_cancelled, 0)) *
                                nvl(unit_price, 0))),
                         x_base_precision))
          INTO x_result_fld
          FROM po_requisition_lines_all
         WHERE requisition_line_id = x_object_id
           AND nvl(modified_by_agent_flag, 'N') = 'N';
      
      ELSE
        x_progress := 165;
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        -- <Bug 4036549, include cancelled lines with with delivered quantity>
        SELECT round(SUM((decode(quantity,
                                 NULL,
                                 nvl(amount, 0),
                                 ((nvl(quantity, 0) -
                                 nvl(quantity_cancelled, 0)) *
                                 nvl(unit_price, 0))) / x_base_min_unit) *
                         x_base_min_unit))
          INTO x_result_fld
          FROM po_requisition_lines_all
         WHERE requisition_line_id = x_object_id
           AND nvl(modified_by_agent_flag, 'N') = 'N';
      
      END IF;
      x_progress := 160;
    
    ELSIF (x_object_type = 'J') THEN
      /* Requisition Distribution */
    
      x_progress := 162;
      --bug#5092574 Retrieve the doc org id and pass this to retrieve
      --the document currency. Bug 5124868: refactored this call
      l_org_id := po_moac_utils_pvt.get_entity_org_id(po_moac_utils_pvt.g_doc_type_requisition,
                                                      po_moac_utils_pvt.g_doc_level_distribution,
                                                      x_object_id); --bug#5092574
    
      po_core_s2.get_req_currency(x_object_id, x_base_currency, l_org_id); --bug#5092574
      x_progress := 164;
      po_core_s2.get_currency_info(x_base_currency,
                                   x_base_precision,
                                   x_base_min_unit);
    
      x_progress := 166;
    
      -- <SERVICES FPJ>
      -- Modified the SELECT statement to take account into Services
      -- lines. For the new Services lines, quantity will be null.
      -- Hence, added decode statements to use amount directly
      -- in the total amount calculation when quantity is null.
      --< Bug 3549096 > Use _ALL tables instead of org-striped views.
      SELECT SUM(decode(x_base_min_unit,
                        NULL,
                        decode(quantity,
                               NULL,
                               round(nvl(pord.req_line_amount, 0),
                                     x_base_precision),
                               round(nvl(pord.req_line_quantity, 0) *
                                     nvl(porl.unit_price, 0),
                                     x_base_precision)),
                        decode(quantity,
                               NULL,
                               round((nvl(pord.req_line_amount, 0) /
                                     x_base_min_unit) * x_base_min_unit),
                               round((nvl(pord.req_line_quantity, 0) *
                                     nvl(porl.unit_price, 0) /
                                     x_base_min_unit) * x_base_min_unit))))
        INTO x_result_fld
        FROM po_req_distributions_all pord, po_requisition_lines_all porl
       WHERE pord.distribution_id = x_object_id
         AND pord.requisition_line_id = porl.requisition_line_id;
    
    ELSIF (x_object_type = 'C') THEN
      /* Contract */
    
      x_progress := 170;
      --< Bug 3549096 > Use _ALL tables instead of org-striped views.
      SELECT c.minimum_accountable_unit, c.precision
        INTO x_min_unit, x_precision
        FROM fnd_currencies c, po_headers_all ph
       WHERE ph.po_header_id = x_object_id
         AND c.currency_code = ph.currency_code;
    
      /* 716188 - SVAIDYAN : Changed the sql stmt to select only Standard and Planned
      POs that reference this contract and also to convert the amount into the
      Contract's currency. This is achieved by converting the PO amt first to the
      functional currency and then changing this to the Contract currency */
    
      /* 716188 - Added an outer join on PO_DISTRIBUTIONS */
      /* 866358 - BPESCHAN: Changed the sql stmt to select quantity_ordered and
      quantity_cancelled from PO_DISTRIBUTIONS instead of PO_LINE_LOCATIONS.
      This fix prevents incorrect calculation for amount release when more then
      one distribution exists. */
    
      /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
         849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                            we pass to GL is the round of individual dist. amounts
                            and the sum of these rounded values is what should be
                            displayed as the header total.
      */
      /*Bug3760487:Purchase Order form was displaying incorrect released
        amount for foreign currency contract when the PO currency is same
        as the contract currency and the rates were different.Added the decode
        to perform the currency conversion only when the currency code of
        PO and contract are different.
        Also removed the join to FND_CURRENCIES
      */
      IF x_min_unit IS NULL THEN
        x_progress := 172;
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT nvl(SUM(decode(ph.currency_code,
                              ph1.currency_code,
                              round((nvl(pod.quantity_ordered, 0) -
                                    nvl(pod.quantity_cancelled, 0)) *
                                    nvl(pll.price_override, 0),
                                    x_precision),
                              round((nvl(pod.quantity_ordered, 0) -
                                    nvl(pod.quantity_cancelled, 0)) *
                                    nvl(pll.price_override, 0) *
                                    nvl(pod.rate, nvl(ph1.rate, 1)) /
                                    nvl(ph.rate, 1),
                                    x_precision))),
                   0)
          INTO x_result_fld
          FROM po_distributions_all  pod,
               po_line_locations_all pll,
               po_lines_all          pl,
               po_headers_all        ph,
               po_headers_all        ph1
        --,FND_CURRENCIES C
         WHERE ph.po_header_id = x_object_id
           AND ph.po_header_id = pl.contract_id -- <GC FPJ>
              --AND    PH.currency_code     = C.currency_code
           AND pl.po_line_id = pll.po_line_id
           AND pll.shipment_type IN ('STANDARD', 'PLANNED')
           AND pod.line_location_id(+) = pll.line_location_id
           AND ph1.po_header_id = pl.po_header_id;
      ELSE
      
        /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
           849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                              we pass to GL is the round of individual dist. amounts
                              and the sum of these rounded values is what should be
                              displayed as the header total.
        */
        x_progress := 174;
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT nvl(SUM(decode(ph.currency_code,
                              ph1.currency_code,
                              round((nvl(pod.quantity_ordered, 0) -
                                    nvl(pod.quantity_cancelled, 0)) *
                                    nvl(pll.price_override, 0) / x_min_unit),
                              round((nvl(pod.quantity_ordered, 0) -
                                    nvl(pod.quantity_cancelled, 0)) *
                                    nvl(pll.price_override, 0) *
                                    nvl(pod.rate, nvl(ph1.rate, 1)) /
                                    nvl(ph.rate, 1) / x_min_unit)) *
                       x_min_unit),
                   0)
          INTO x_result_fld
          FROM po_distributions_all  pod,
               po_line_locations_all pll,
               po_lines_all          pl,
               po_headers_all        ph,
               po_headers_all        ph1
        --,FND_CURRENCIES C
         WHERE ph.po_header_id = x_object_id
           AND ph.po_header_id = pl.contract_id -- <GC FPJ>
              --AND    PH.currency_code     = C.currency_code
           AND pl.po_line_id = pll.po_line_id
           AND pll.shipment_type IN ('STANDARD', 'PLANNED')
           AND pod.line_location_id(+) = pll.line_location_id
           AND ph1.po_header_id = pl.po_header_id;
      END IF;
    
    ELSIF (x_object_type = 'R') THEN
      /* Release */
    
      IF x_base_cur_result THEN
        x_progress := 180;
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT gsb.currency_code, poh.currency_code
          INTO x_base_currency, x_po_currency
          FROM po_headers_all               poh,
               financials_system_params_all fsp,
               gl_sets_of_books             gsb,
               po_releases_all              por
         WHERE por.po_release_id = x_object_id
           AND poh.po_header_id = por.po_header_id
           AND nvl(por.org_id, -99) = nvl(fsp.org_id, -99) --< Bug 3549096 >
           AND fsp.set_of_books_id = gsb.set_of_books_id;
      
        IF (x_base_currency <> x_po_currency) THEN
          /* Get precision and minimum accountable unit of the PO CURRENCY */
          x_progress := 190;
          po_core_s2.get_currency_info(x_po_currency,
                                       x_precision,
                                       x_min_unit);
        
          /* Get precision and minimum accountable unit of the base CURRENCY */
          x_progress := 200;
          po_core_s2.get_currency_info(x_base_currency,
                                       x_base_precision,
                                       x_base_min_unit);
        
          IF x_base_min_unit IS NULL THEN
            IF x_min_unit IS NULL THEN
              x_progress := 210;
            
              /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
                 849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                                    we pass to GL is the round of individual dist. amounts
                                    and the sum of these rounded values is what should be
                                    displayed as the header total.
              */
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round(decode(pod.quantity_ordered,
                                                NULL,
                                                nvl(pod.amount_ordered, 0),
                                                (nvl(pod.quantity_ordered, 0) *
                                                nvl(pll.price_override, 0))) *
                                         pod.rate,
                                         x_precision),
                                   x_base_precision)),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_release_id = x_object_id
                 AND pll.line_location_id = pod.line_location_id
                 AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
            
            ELSE
              x_progress := 212;
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round(decode(pod.quantity_ordered,
                                                NULL,
                                                nvl(pod.amount_ordered, 0),
                                                (nvl(pod.quantity_ordered, 0) *
                                                nvl(pll.price_override, 0))) *
                                         pod.rate / x_min_unit) *
                                   x_min_unit,
                                   x_base_precision)),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_release_id = x_object_id
                 AND pll.line_location_id = pod.line_location_id
                 AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
            
            END IF;
          ELSE
            IF x_min_unit IS NULL THEN
              x_progress := 214;
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round(decode(pod.quantity_ordered,
                                                NULL,
                                                nvl(pod.amount_ordered, 0),
                                                (nvl(pod.quantity_ordered, 0) *
                                                nvl(pll.price_override, 0))) *
                                         pod.rate,
                                         x_precision) / x_base_min_unit) *
                             x_base_min_unit),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_release_id = x_object_id
                 AND pll.line_location_id = pod.line_location_id
                 AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
            
            ELSE
              x_progress := 216;
              -- <SERVICES FPJ>
              -- For the new Services lines, quantity will be null.
              -- Hence, added a decode statement to use amount directly
              -- in the total amount calculation when quantity is null.
              --< Bug 3549096 > Use _ALL tables instead of org-striped views.
              SELECT nvl(SUM(round(round(decode(pod.quantity_ordered,
                                                NULL,
                                                nvl(pod.amount_ordered, 0),
                                                (nvl(pod.quantity_ordered, 0) *
                                                nvl(pll.price_override, 0))) *
                                         pod.rate / x_min_unit) *
                                   x_min_unit / x_base_min_unit) *
                             x_base_min_unit),
                         0)
                INTO x_result_fld
                FROM po_distributions_all pod, po_line_locations_all pll
               WHERE pll.po_release_id = x_object_id
                 AND pll.line_location_id = pod.line_location_id
                 AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
            
            END IF;
          END IF;
        
        END IF;
      ELSE
        x_progress := 220;
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT c.minimum_accountable_unit, c.precision
          INTO x_min_unit, x_precision
          FROM fnd_currencies c, po_releases_all por, po_headers_all ph
         WHERE por.po_release_id = x_object_id
           AND ph.po_header_id = por.po_header_id
           AND c.currency_code = ph.currency_code;
      
        IF x_min_unit IS NULL THEN
        
          /* 958792 kbenjami 8/25/99.  Proprogated fix from R11.
             849493 - SVAIDYAN: Do a sum(round()) instead of round(sum()) since what
                                we pass to GL is the round of individual dist. amounts
                                and the sum of these rounded values is what should be
                                displayed as the header total.
          */
          x_progress := 222;
          -- <SERVICES FPJ>
          -- For the new Services lines, quantity will be null.
          -- Hence, added a decode statement to use amount directly
          -- in the total amount calculation when quantity is null.
          --< Bug 3549096 > Use _ALL tables instead of org-striped views.
          SELECT SUM(round(decode(pll.quantity,
                                  NULL,
                                  (pll.amount - nvl(pll.amount_cancelled, 0)),
                                  ((pll.quantity -
                                  nvl(pll.quantity_cancelled, 0)) *
                                  nvl(pll.price_override, 0))),
                           x_precision))
            INTO x_result_fld
            FROM po_line_locations_all pll
           WHERE pll.po_release_id = x_object_id
             AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
        
        ELSE
          /* Bug 1111926: GMudgal 2/18/2000
          ** Incorrect placement of brackets caused incorrect rounding
          ** and consequently incorrect PO header totals
          */
          x_progress := 224;
        
          -- <SERVICES FPJ>
          -- For the new Services lines, quantity will be null.
          -- Hence, added a decode statement to use amount directly
          -- in the total amount calculation when quantity is null.
          --< Bug 3549096 > Use _ALL tables instead of org-striped views.
          SELECT SUM(round(decode(pll.quantity,
                                  NULL,
                                  (pll.amount - nvl(pll.amount_cancelled, 0)),
                                  ((pll.quantity -
                                  nvl(pll.quantity_cancelled, 0)) *
                                  nvl(pll.price_override, 0))) / x_min_unit) *
                     x_min_unit)
            INTO x_result_fld
            FROM po_line_locations_all pll
           WHERE pll.po_release_id = x_object_id
             AND pll.shipment_type IN ('SCHEDULED', 'BLANKET');
        
        END IF;
      
      END IF;
    
    ELSIF (x_object_type = 'L') THEN
      /* Po Line */
      x_progress := 230;
      --< Bug 3549096 > Use _ALL tables instead of org-striped views.
      SELECT SUM(c.minimum_accountable_unit), 4 --sum(c.precision)
        INTO x_min_unit, x_precision
        FROM fnd_currencies c, po_headers_all ph, po_lines_all pol
       WHERE pol.po_line_id = x_object_id
         AND ph.po_header_id = pol.po_header_id
         AND c.currency_code = ph.currency_code;
    
      IF x_min_unit IS NULL THEN
        x_progress := 232;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
              select round(sum((pll.quantity - nvl(pll.quantity_cancelled,0))*
                               nvl(pll.price_override,0)),x_precision)
        */
        /*    Bug No. 1849112 In the previous fix of 143811 by mistake x_precision
              was not used.
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT SUM(round((decode(pll.quantity,
                                 NULL,
                                 (pll.amount - nvl(pll.amount_cancelled, 0)),
                                 (pll.quantity -
                                 nvl(pll.quantity_cancelled, 0)) *
                                 nvl(pll.price_override, 0))),
                         x_precision))
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.po_line_id = x_object_id
           AND pll.shipment_type IN ('STANDARD', 'BLANKET', 'PLANNED');
      
      ELSE
        x_progress := 234;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT SUM(round((decode(pll.quantity,
                                 NULL,
                                 (pll.amount - nvl(pll.amount_cancelled, 0)),
                                 (pll.quantity -
                                 nvl(pll.quantity_cancelled, 0)) *
                                 nvl(pll.price_override, 0)) / x_min_unit) *
                         x_min_unit))
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.po_line_id = x_object_id
           AND pll.shipment_type IN ('STANDARD', 'BLANKET', 'PLANNED');
      
      END IF;
    
    ELSIF (x_object_type = 'S') THEN
      /* PO Shipment */
      x_progress := 240;
      --< Bug 3549096 > Use _ALL tables instead of org-striped views.
      SELECT c.minimum_accountable_unit, c.precision
        INTO x_min_unit, x_precision
        FROM fnd_currencies c, po_headers_all ph, po_line_locations_all pll
       WHERE pll.line_location_id = x_object_id
         AND ph.po_header_id = pll.po_header_id
         AND c.currency_code = ph.currency_code;
    
      IF x_min_unit IS NULL THEN
        x_progress := 242;
      
        /*    Bug No. 1431811 Changing the round of sum to sum of rounded totals
              select round(sum((pll.quantity - nvl(pll.quantity_cancelled,0))*
                               nvl(pll.price_override,0)),x_precision)
        */
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT SUM(round((decode(pll.quantity,
                                 NULL,
                                 (pll.amount - nvl(pll.amount_cancelled, 0)),
                                 (pll.quantity -
                                 nvl(pll.quantity_cancelled, 0)) *
                                 nvl(pll.price_override, 0))),
                         x_precision))
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.line_location_id = x_object_id;
      
      ELSE
        x_progress := 244;
        -- <SERVICES FPJ>
        -- For the new Services lines, quantity will be null.
        -- Hence, added a decode statement to use amount directly
        -- in the total amount calculation when quantity is null.
        --< Bug 3549096 > Use _ALL tables instead of org-striped views.
        SELECT round(SUM((decode(pll.quantity,
                                 NULL,
                                 (pll.amount - nvl(pll.amount_cancelled, 0)),
                                 (pll.quantity -
                                 nvl(pll.quantity_cancelled, 0)) *
                                 nvl(pll.price_override, 0)) / x_min_unit) *
                         x_min_unit))
          INTO x_result_fld
          FROM po_line_locations_all pll
         WHERE pll.line_location_id = x_object_id;
      
      END IF;
    
    END IF; /* x_object_type */
  
    /* If x_result_fld has a null value, return 0 as the total. */
    IF x_result_fld IS NULL THEN
      x_result_fld := 0;
    END IF;
  
    RETURN(x_result_fld);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(0);
      RAISE;
    
  END get_total;

  --------------------------------------------------------
  -- get_rate_cur_for_xml
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  3.6.13   YUVAL TAL       CR-805 :Purchase PDF documents does not show linkage : add nvl(c.release_num, 0) = 0;
  --     1.1  10.6.13  yuval tal       Cust004- bugfix 821 add parameter  p_release_num and call to XXPO_utils_pkg.get_last_linkage_creation to 
  --------------------------------------------------------

  FUNCTION get_rate_cur_for_xml(po_number     IN VARCHAR2,
                                p_relsase_num NUMBER) RETURN VARCHAR2 IS
  
    v_currency_code VARCHAR2(10);
  BEGIN
    BEGIN
      SELECT c.currency_code
        INTO v_currency_code
        FROM clef062_po_index_esc_set c
       WHERE document_id = po_number
         AND nvl(c.release_num, 0) = p_relsase_num
         AND c.creation_date =
             xxpo_utils_pkg.get_last_linkage_creation(document_id,
                                                      nvl(c.release_num, 0));
    EXCEPTION
      WHEN OTHERS THEN
        v_currency_code := NULL;
    END;
    RETURN v_currency_code;
  END get_rate_cur_for_xml;

  --------------------------------------------------------
  -- get_rate_basedate_for_xml
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  3.6.13   YUVAL TAL       CR-805 :Purchase PDF documents does not show linkage : add nvl(c.release_num, 0) = 0;
  --     1.1  10.6.13  yuval tal       Cust004- bugfix 821 add parameter  p_release_num and call to XXPO_utils_pkg.get_last_linkage_creation to 
  --------------------------------------------------------

  FUNCTION get_rate_baserate_for_xml(po_number     IN VARCHAR2,
                                     p_relsase_num NUMBER) RETURN NUMBER IS
  
    v_base_rate NUMBER;
  BEGIN
    BEGIN
      SELECT c.base_rate
        INTO v_base_rate
        FROM clef062_po_index_esc_set c
       WHERE document_id = po_number
         AND nvl(c.release_num, 0) = p_relsase_num
         AND c.creation_date =
             xxpo_utils_pkg.get_last_linkage_creation(document_id,
                                                      nvl(c.release_num, 0));
    EXCEPTION
      WHEN OTHERS THEN
        v_base_rate := NULL;
    END;
    RETURN v_base_rate;
  END get_rate_baserate_for_xml;

  --------------------------------------------------------
  -- get_rate_basedate_for_xml
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  3.6.13   YUVAL TAL       CR-805 :Purchase PDF documents does not show linkage : add nvl(c.release_num, 0) = 0;
  --     1.1  10.6.13  yuval tal       Cust004- bugfix 821 add parameter  p_release_num and call to XXPO_utils_pkg.get_last_linkage_creation to 
  --------------------------------------------------------

  FUNCTION get_rate_basedate_for_xml(po_number     IN VARCHAR2,
                                     p_relsase_num NUMBER) RETURN DATE IS
  
    v_base_date DATE;
  BEGIN
    BEGIN
      SELECT c.base_date
        INTO v_base_date
        FROM clef062_po_index_esc_set c
       WHERE document_id = po_number
         AND nvl(c.release_num, 0) = p_relsase_num
         AND c.creation_date =
             xxpo_utils_pkg.get_last_linkage_creation(document_id,
                                                      nvl(c.release_num, 0));
    EXCEPTION
      WHEN OTHERS THEN
        v_base_date := NULL;
    END;
    RETURN v_base_date;
  END get_rate_basedate_for_xml;

  FUNCTION get_approved_details_for_xml(po_number IN VARCHAR2,
                                        p_field   IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR IS
  
    v_employee_id NUMBER;
    --v_seq_number        NUMBER;
    v_full_name         VARCHAR2(100);
    v_attribute1        VARCHAR2(30);
    v_attribute2        VARCHAR2(30);
    v_attribute13       VARCHAR2(200);
    v_approve_details   VARCHAR2(2000);
    v_object_name       VARCHAR2(100);
    v_url               VARCHAR2(200);
    v_ou                NUMBER;
    v_logo_path         VARCHAR2(200);
    v_amount_limit      NUMBER;
    v_encumbered_amount NUMBER;
  
    CURSOR cr_approve IS
      SELECT p.sequence_num,
             p.employee_id,
             ph.type_lookup_code,
             ph.po_header_id
        FROM po_action_history p, po_headers_all ph
       WHERE p.object_id = ph.po_header_id
         AND p.object_type_code = 'PO'
         AND ph.segment1 = po_number
         AND ph.org_id = v_ou
      --And p.action_code = 'APPROVE'
       ORDER BY p.sequence_num DESC;
  BEGIN
    --fnd_global.APPS_INITIALIZE(1091,50562,724);
  
    v_url := fnd_profile.value('HELP_WEB_BASE_URL');
    v_ou  := fnd_profile.value('ORG_ID');
  
    BEGIN
      SELECT ha.attribute3
        INTO v_logo_path
        FROM hr_all_organization_units ha
       WHERE ha.organization_id = v_ou;
    EXCEPTION
      WHEN OTHERS THEN
        v_logo_path := NULL;
    END;
  
    FOR i IN cr_approve LOOP
    
      BEGIN
        SELECT SUM(pd.encumbered_amount * nvl(pd.rate, 1))
          INTO v_encumbered_amount
          FROM po_distributions_all pd
         WHERE pd.po_header_id = i.po_header_id;
      EXCEPTION
        WHEN OTHERS THEN
          v_encumbered_amount := 0;
      END;
    
      BEGIN
        SELECT DISTINCT b.amount_limit
          INTO v_amount_limit
          FROM po_control_groups_all    a,
               po_control_rules         b,
               po_position_controls_all c,
               po_control_functions     d,
               per_all_assignments_f    pa
         WHERE pa.person_id = i.employee_id
           AND b.control_group_id = a.control_group_id
              --and b.control_rule_id = 7
           AND c.position_id = pa.position_id
           AND a.control_group_id = c.control_group_id
           AND c.control_function_id = d.control_function_id
           AND a.org_id = v_ou
           AND d.document_subtype = i.type_lookup_code;
      EXCEPTION
        WHEN OTHERS THEN
          v_amount_limit := 0;
      END;
    
      IF v_amount_limit > v_encumbered_amount THEN
        v_employee_id := i.employee_id;
        EXIT;
      END IF;
    
    END LOOP;
  
    BEGIN
      SELECT p.full_name, p.attribute1, p.attribute2, p.attribute13
        INTO v_full_name, v_attribute1, v_attribute2, v_attribute13
        FROM per_all_people_f p
       WHERE p.person_id = v_employee_id;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    BEGIN
      SELECT tt.object_name
        INTO v_object_name
        FROM gl.gl_ledger_config_details tt
       WHERE tt.configuration_id =
             (SELECT DISTINCT t.configuration_id
                FROM gl.gl_ledger_config_details t, per_all_assignments_f f
               WHERE object_id = f.set_of_books_id
                 AND f.person_id = v_employee_id)
         AND tt.object_type_code = 'LEGAL_ENTITY';
    EXCEPTION
      WHEN OTHERS THEN
        v_object_name := NULL;
    END;
  
    /* v_approve_details := 'Approved By: '||v_full_name||chr(13)||
    '000000       '||v_attribute1||chr(13)||
    '             '||v_attribute2||chr(13)||
    '             '||v_object_name;*/
  
    IF p_field = 'FULL_NAME' THEN
      RETURN v_full_name;
    ELSIF p_field = 'JOB_DESC_1' THEN
      RETURN v_attribute1;
    ELSIF p_field = 'JOB_DESC_2' THEN
      RETURN v_attribute2;
    ELSIF p_field = 'COMPANY' THEN
      RETURN v_object_name;
    ELSIF p_field = 'SIG_URL' THEN
      RETURN REPLACE(v_url, 'OA_HTML/') || v_attribute13;
    ELSIF p_field = 'LOGO_URL' THEN
      RETURN REPLACE(v_url, 'OA_HTML/') || v_logo_path;
    END IF;
    RETURN v_approve_details;
  
  END get_approved_details_for_xml;

  FUNCTION get_logo(po_number IN VARCHAR2) RETURN VARCHAR2 IS
  
    v_url VARCHAR2(200);
  
  BEGIN
    v_url := fnd_profile.value('HELP_WEB_BASE_URL');
    ----RETURN REPLACE(v_url, 'OA_HTML/', 'OA_MEDIA/') || 'xxobjet/ObjetLogo.gif';  --Vitali 12-July-2012
    RETURN REPLACE(v_url, 'OA_HTML/', 'OA_MEDIA/') || 'XXLOGO.gif';
  END get_logo;

  --------------------------------------------------------------------
  --  name:            get_balance_quantity
  --  create by:       xxx
  --  Revision:        1.0 
  --  creation date:   xx/xx/2009 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Get line balance quantity
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  xx/xx/2009  XXX              initial build
  --  1.1  11/03/2010  Dalit A. Raviv   Correct balance to take in considaration 
  --                                    canceled and rejected qty
  -------------------------------------------------------------------- 
  FUNCTION get_balance_quantity(p_po_line_id NUMBER) RETURN NUMBER IS
    l_balance_qty NUMBER;
  BEGIN
    SELECT SUM(pll.quantity - nvl(pll.quantity_received, 0) -
               nvl(pll.quantity_rejected, 0) -
               nvl(pll.quantity_cancelled, 0))
    --SUM(pll.quantity - pll.quantity_received)
      INTO l_balance_qty
      FROM po_line_locations_all pll
     WHERE pll.po_line_id = p_po_line_id
       AND pll.po_release_id IS NULL;
  
    RETURN l_balance_qty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_balance_quantity;

  FUNCTION get_rel_balance_quantity(p_po_line_loc_id NUMBER) RETURN NUMBER IS
    l_balance_qty NUMBER;
  BEGIN
    SELECT SUM(pll.quantity - pll.quantity_received)
      INTO l_balance_qty
      FROM po_line_locations_all pll
     WHERE pll.line_location_id = p_po_line_loc_id
       AND pll.po_release_id IS NOT NULL;
  
    RETURN l_balance_qty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_rel_balance_quantity;

  FUNCTION get_released_quantity(p_po_line_id NUMBER) RETURN NUMBER IS
    l_released_qty NUMBER;
  BEGIN
    SELECT SUM(pll.quantity)
      INTO l_released_qty
      FROM po_line_locations_all pll
     WHERE pll.po_line_id = p_po_line_id
       AND pll.po_release_id IS NOT NULL;
  
    RETURN l_released_qty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_released_quantity;

  --------------------------------------------
  -- get_released_remain_quantity
  ---------------------------------------------

  FUNCTION get_release_remain_quantity(p_line_id NUMBER) RETURN NUMBER IS
    l_qty NUMBER;
    /* l_po_line_id NUMBER;
    l_release_id NUMBER;*/
  BEGIN
  
    SELECT MIN(l.quantity_committed) - SUM(pll.quantity)
      INTO l_qty
      FROM po_line_locations_all pll, po_lines_all l, po_releases_all rl
     WHERE rl.po_release_id = pll.po_release_id
       AND l.po_line_id = pll.po_line_id
       AND l.po_line_id = p_line_id
       AND nvl(pll.cancel_flag, 'N') = 'N';
  
    RETURN l_qty;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------
  -- get_converted_amount
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  3.6.13   YUVAL TAL       CR-805 :Purchase PDF documents does not show linkage : add nvl(c.release_num, 0) = 0;
  --     1.1  10.6.13  yuval tal       Cust004- bugfix 821 add parameter  p_release_num 
  --------------------------------------------------------
  FUNCTION get_converted_amount(p_amount      IN NUMBER,
                                po_number     IN VARCHAR2,
                                p_release_num NUMBER) RETURN NUMBER IS
  
    --l_converted_amount NUMBER := 0;
    l_cle_rate NUMBER := 0;
  
  BEGIN
  
    l_cle_rate := get_rate_baserate_for_xml(po_number, p_release_num);
    IF l_cle_rate IS NULL THEN
      RETURN p_amount;
    ELSIF l_cle_rate = 0 THEN
      RETURN p_amount;
    ELSE
      RETURN p_amount / l_cle_rate;
    END IF;
  
  END get_converted_amount;

  FUNCTION get_last_release_num(po_number IN VARCHAR2) RETURN VARCHAR2 IS
  
    v_last_release VARCHAR2(1) := 'N';
    v_release_num  NUMBER(30);
  
  BEGIN
    BEGIN
      SELECT por.release_num
        INTO v_release_num
        FROM po_release_xml por
       WHERE por.segment1 = po_number;
    EXCEPTION
      WHEN OTHERS THEN
        v_last_release := 'Y';
    END;
    RETURN v_last_release;
  END get_last_release_num;

  FUNCTION is_promised_date_changed(p_line_location_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_return_value VARCHAR2(1);
  BEGIN
    BEGIN
      SELECT 'Y'
        INTO v_return_value
        FROM po_line_locations_all         pll,
             po_headers_all                poh,
             po_line_locations_archive_all plla
       WHERE pll.po_header_id = poh.po_header_id
         AND pll.line_location_id = p_line_location_id ----parameter
         AND pll.line_location_id = plla.line_location_id
         AND plla.revision_num =
             (SELECT MAX(plla1.revision_num)
                FROM po_line_locations_archive_all plla1
               WHERE plla1.line_location_id = pll.line_location_id
                 AND plla1.revision_num < poh.revision_num)
         AND nvl(pll.promised_date, SYSDATE) !=
             nvl(plla.promised_date, SYSDATE);
    EXCEPTION
      WHEN OTHERS THEN
        v_return_value := 'N';
    END;
    RETURN v_return_value;
  END is_promised_date_changed;

  FUNCTION is_need_by_date_changed(p_line_location_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_return_value VARCHAR2(1);
  BEGIN
    BEGIN
      SELECT 'Y'
        INTO v_return_value
        FROM po_line_locations_all         pll,
             po_headers_all                poh,
             po_line_locations_archive_all plla
       WHERE pll.po_header_id = poh.po_header_id
         AND pll.line_location_id = p_line_location_id ----parameter
         AND pll.line_location_id = plla.line_location_id
         AND plla.revision_num =
             (SELECT MAX(plla1.revision_num)
                FROM po_line_locations_archive_all plla1
               WHERE plla1.line_location_id = pll.line_location_id
                 AND plla1.revision_num < poh.revision_num)
         AND nvl(pll.need_by_date, SYSDATE) !=
             nvl(plla.need_by_date, SYSDATE);
    EXCEPTION
      WHEN OTHERS THEN
        v_return_value := 'N';
    END;
    RETURN v_return_value;
  END is_need_by_date_changed;

  ----------------------------
  -- is_multi_ship_to
  -- for po PDF report needs 
  -----------------------------
  FUNCTION is_multi_ship_to_org(p_po_header_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT COUNT(DISTINCT t.ship_to_organization_id)
      INTO l_tmp
      FROM po_line_locations_all t
     WHERE nvl(t.cancel_flag, 'N') != 'Y'
       AND t.po_header_id = p_po_header_id;
  
    IF l_tmp > 1 THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  END;

  ----------------------------
  -- get_release_num
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.1   10.6.13  yuval tal       Cust004- bugfix 821
  -----------------------------
  FUNCTION get_release_num(p_po_release_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  
  BEGIN
    SELECT release_num
      INTO l_tmp
      FROM po_releases_all t
     WHERE t.po_release_id = p_po_release_id;
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ---------------------------------------------------------------------------
  -- get_uom_tl
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  21/05/2013     Vitaly             initial revision (CR763)
  ---------------------------------------------------------------------------
  FUNCTION get_uom_tl(p_inventory_item_id NUMBER,
                      p_organization_id   NUMBER,
                      p_unit_of_measure   VARCHAR2) RETURN VARCHAR2 IS
    l_language   mtl_system_items_tl.language%TYPE;
    l_result_uom mtl_units_of_measure.uom_code%TYPE;
    l_uom_jpn    VARCHAR2(50);
  
  BEGIN
  
    l_language := xxhz_util.get_ou_lang(xxhz_util.get_inv_org_ou(p_organization_id));
    IF l_language = 'JA' THEN
      ---Get UOM Code for Japan---------
      BEGIN
        SELECT t.description
          INTO l_uom_jpn
          FROM mtl_categories_v      t,
               mtl_item_categories_v ic,
               mtl_category_sets     cset
         WHERE t.structure_id = ic.structure_id
           AND cset.category_set_name = 'Japan Unit of Measure Sign'
           AND ic.category_id = t.category_id
           AND ic.inventory_item_id = p_inventory_item_id ---
           AND ic.category_set_id = cset.category_set_id
           AND ic.organization_id = nvl(p_organization_id, 91); ---
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      -----
    END IF;
  
    IF l_uom_jpn IS NULL THEN
      -----
      BEGIN
        SELECT t.unit_of_measure_tl
          INTO l_result_uom
          FROM mtl_units_of_measure_tl t
         WHERE t.unit_of_measure = p_unit_of_measure ----
           AND t.language = l_language; ----
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      -----
    END IF;
  
    RETURN nvl(nvl(l_uom_jpn, l_result_uom), p_unit_of_measure);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_uom_tl;
  -----------------------------------------------------------

  ----------------------------------------------------------------------------
  -- get_ap_term_name_tl
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  25.4.2013  yuval tal              cr 724 support japan description
  ---------------------------------------------------------------------------
  FUNCTION get_ap_term_name_tl(p_term_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2 IS
  
    l_name VARCHAR2(500);
  BEGIN
  
    SELECT t.name
      INTO l_name
      FROM ap_terms_tl t
    
     WHERE t.term_id = p_term_id
       AND t.language = xxhz_util.get_ou_lang(p_org_id);
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
END xxpo_communication_report_pkg;
/
