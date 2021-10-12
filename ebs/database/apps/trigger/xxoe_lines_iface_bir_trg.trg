CREATE OR REPLACE TRIGGER xxoe_lines_iface_bir_trg
   ---------------------------------------------------------------------------
   -- $Header: xxoe_lines_iface_bir_trg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxoe_lines_iface_bir_trg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: update order price from internal requisition
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   --      1.1 16.3.11  yuval tal        change logic
   ---------------------------------------------------------------------------
  BEFORE INSERT ON oe_lines_iface_all  
  FOR EACH ROW  
when (NEW.order_source_id = 10)
DECLARE
  --  l_requisition_price NUMBER := NULL;

  CURSOR c IS
    SELECT 1
    -- INTO l_requisition_price
      FROM hz_cust_site_uses_all        hzca,
           org_organization_definitions odest,
           org_organization_definitions osource,
           gl_ledgers                   l,
           mtl_intercompany_parameters  mtrel,
           qp_list_headers_b            ql,
           po_requisition_lines_all     req
     WHERE req.requisition_line_id = :NEW.orig_sys_line_ref
       AND odest.organization_id = req.destination_organization_id
       AND osource.organization_id = req.source_organization_id
       AND odest.organization_id = odest.organization_id
       AND mtrel.sell_organization_id = odest.operating_unit
       AND mtrel.ship_organization_id = osource.operating_unit
       AND hzca.cust_acct_site_id = mtrel.address_id
       AND osource.set_of_books_id = l.ledger_id
       AND hzca.price_list_id = ql.list_header_id
       AND --hzca.primary_flag = 'Y' AND
           hzca.site_use_code = 'BILL_TO'; --AND

  CURSOR c2 IS
    SELECT
    -- osource.organization_id SOURCE,
    -- odest.organization_id dest,
    -- hzca.price_list_id,
     ql.currency_code price_list_currency, l.currency_code ledger_currency
    --  INTO l_list_header_id, x_list_price_curr_code, x_source_curr_code
      FROM hz_cust_site_uses_all        hzca,
           org_organization_definitions odest,
           org_organization_definitions osource,
           gl_ledgers                   l,
           mtl_intercompany_parameters  mtrel,
           qp_list_headers_b            ql,
           qp_list_headers_tl           xx,
           po_requisition_lines_all     req
     WHERE req.requisition_line_id = :NEW.orig_sys_line_ref
       AND odest.organization_id = req.destination_organization_id
       AND osource.organization_id = req.source_organization_id
       AND mtrel.sell_organization_id = odest.operating_unit
          
       AND mtrel.ship_organization_id = osource.operating_unit
       AND hzca.cust_acct_site_id = mtrel.address_id
       AND osource.set_of_books_id = l.ledger_id
       AND hzca.price_list_id = ql.list_header_id
          --hzca.primary_flag = 'Y' AND
       AND hzca.site_use_code = 'SHIP_TO' --AND
       AND xx.list_header_id = ql.list_header_id
       AND xx.LANGUAGE = 'US';

  l_tmp NUMBER;

  l_price_list_currency VARCHAR2(10);
  l_ledger_currency     VARCHAR2(10);

BEGIN

  IF nvl(fnd_profile.VALUE('XXPO_ENABLE_INTER_REQ_PRICE'), 'N') = 'Y' THEN
    -- by yuval 16.3.11
    --Quering price from requisition is as follows:
    /* SELECT prla.unit_price
     INTO l_requisition_price
     FROM po_requisition_lines_all     prla,
          org_organization_definitions odest,
          org_organization_definitions osource
    WHERE prla.requisition_line_id = :NEW.orig_sys_line_ref AND
          odest.organization_id = prla.destination_organization_id AND
          osource.organization_id = prla.source_organization_id AND
          osource.operating_unit <> odest.operating_unit; */
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    IF l_tmp = 1 THEN
      :NEW.unit_selling_price   := NULL;
      :NEW.unit_list_price      := NULL;
      :NEW.calculate_price_flag := NULL;
    ELSE
    
      OPEN c2;
      FETCH c2
        INTO l_price_list_currency, l_ledger_currency;
      CLOSE c2;
    
      IF l_price_list_currency != l_ledger_currency THEN
        :NEW.unit_list_price := :NEW.unit_list_price *
                                gl_currency_api.get_closest_rate(l_ledger_currency,
                                                                 l_price_list_currency, -- to_curr
                                                                 SYSDATE,
                                                                 'Corporate',
                                                                 99);
      
        :NEW.unit_selling_price := :NEW.unit_selling_price *
                                   gl_currency_api.get_closest_rate(l_ledger_currency,
                                                                    l_price_list_currency, -- to_curr
                                                                    SYSDATE,
                                                                    'Corporate',
                                                                    99);
      
      END IF;
    END IF;
  END IF;

END xxoe_lines_iface_bir_trg;
/

