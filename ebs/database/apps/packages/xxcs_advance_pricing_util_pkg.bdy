CREATE OR REPLACE PACKAGE BODY xxcs_advance_pricing_util_pkg IS

--------------------------------------------------------------------
--  name:            XXOBJT_ADVANCE_PRICING_UTIL_PKG 
--  create by:       Dalit A. Raviv
--  Revision:        1.5
--  creation date:   02/01/2011 14:40:16
--------------------------------------------------------------------
--  purpose :        Advance Pricing Util
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  02/01/2011  Dalit A. Raviv    initial build
--  1.1  11/01/2011  Roman             added get_header_exist procedue
--  1.2  13/03/2011  Roman             added logic to get_spcoverage_exists and 
--                                     get sp_coverage_discount
--  1.3  23/03/2011  Roman             Fixed validation for indirect contracts  
--  1.4  03/04/2011  Roman             Changed SP items validation, added training items 
--  1.5  19/05/2011  Roman             Added logic of Upgade items discounts 
--  1.6  21/06/2011  Roman V.          add functions: get_service_item_price , get_service_item                                                                             
-------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:            get_spare_part
  --  create by:       Roman
  --  Revision:        1.2
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns Y/N in case of spare part item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --  1.1  03/04/2011  Roman             Changed SP items validation, added training items
  --  1.2  19/05/2011  ROman             Added Upgrade Items    
  --------------------------------------------------------------------
  FUNCTION get_spare_part(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_result VARCHAR2(5) := 'N';
  
  BEGIN
    SELECT 'Y' /*nvl2(msib.inventory_item_id, 'Y', 'N')*/ RESULT
      INTO l_result
      FROM mtl_system_items_b msib, oe_order_lines_all oola
     WHERE oola.inventory_item_id = msib.inventory_item_id
       AND oola.line_id = p_line_id
       AND msib.organization_id = 91
       AND msib.material_billable_flag IN
           ('M', 'XXOBJ_HEADS', 'XXOBJ_TRAINING', 'XXOBJ_UG')
       AND msib.item_type <> 'XXOBJ_SYS_FG';
  
    RETURN l_result;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END get_spare_part;

  --------------------------------------------------------------------
  --  name:            get_service_item
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   21/06/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns Y/N in case of service item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/06/2011  Roman             initial build
  --------------------------------------------------------------------
  FUNCTION get_service_item(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_result VARCHAR2(5) := 'N';
  
  BEGIN
  
    SELECT 'Y' RESULT
      INTO l_result
      FROM mtl_system_items_b msib, oe_order_lines_all oola
     WHERE msib.organization_id = 91
       AND msib.inventory_item_id = oola.inventory_item_id
       AND msib.contract_item_type_code = 'SERVICE'
       AND oola.line_id = p_line_id;
  
    RETURN l_result;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END get_service_item;

  --------------------------------------------------------------------
  --  name:            get_service_item_price
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   21/06/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns service item price
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/06/2011  Roman             initial build
  --  1.1  14/02/2013  Adi               Fix the where caluse for 11G DB -- add to char on number field
  --------------------------------------------------------------------
  FUNCTION get_service_item_price(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_price VARCHAR2(10) := 0;
    --l_tmp   VARCHAR2(50);
  BEGIN

    SELECT qll.operand
      INTO l_price
      FROM qp_list_lines         qll,
           qp_pricing_attributes qpa,
           oe_order_lines_all    oola,
           oe_order_lines_all    oola1,
           oe_order_headers_all  ooha
     WHERE qll.list_line_id = qpa.list_line_id
       AND oola.header_id = ooha.header_id
       AND (qll.end_date_active IS NULL OR qll.end_date_active > SYSDATE)
       AND qpa.product_attr_value = to_char(oola.inventory_item_id) -- 1.1  14/02/2013  Adi
          --AND oola.line_id = oola1.service_reference_line_id --511783 --
       AND oola.header_id = oola1.header_id
       AND oola.line_number = oola1.line_number
       AND oola.service_number IS NULL
       AND oola1.line_id = p_line_id
       AND qll.list_header_id =
           (SELECT b.list_header_id
              FROM qp_list_headers_all_b b,
                   qp_list_lines         l,
                   qp_pricing_attributes qpa
             WHERE b.list_header_id = l.list_header_id
               AND l.list_line_id = qpa.list_line_id
               AND to_char(qpa.product_attr_value) = to_char(oola.attribute7)
               AND (l.end_date_active IS NULL OR l.end_date_active > SYSDATE)
               AND b.orig_org_id = oola1.org_id
               AND b.attribute3 = 'Service'
               AND b.currency_code = ooha.transactional_curr_code);
  
    RETURN l_price;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '0';
    
  END get_service_item_price;

  --------------------------------------------------------------------
  --  name:            get_spcoverage_exist
  --  create by:       Roman
  --  Revision:        1.2
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns Y/N in case of existing contract according to 
  --                   according to order sold to org id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --  1.1  13/03/2011  Roman             additional logic
  --  1.2  23/03/2011  Roman             Fixed validation for indirect contracts    
  --------------------------------------------------------------------
  FUNCTION get_spcoverage_exist(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_result VARCHAR2(5) := 'N';
  
  BEGIN
    SELECT 'Y' /*nvl2(cleb.id, 'Y', 'N')*/ RESULT
      INTO l_result
      FROM okc_k_lines_b       cleb,
           okc_k_lines_b       cleb1,
           oks_k_lines_b       kln,
           oks_bus_processes_v bus,
           oe_order_lines_all  oola,
           okc_k_items         oki
     WHERE cleb.id = kln.cle_id
       AND kln.coverage_id = bus.coverage_cle_id
       AND bus.bus_process_name = 'Spare Part Coverage'
       AND cleb.id = cleb1.cle_id
       AND cleb1.id = oki.cle_id
       AND oki.object1_id1 = oola.sold_to_org_id
       AND oola.line_id = p_line_id
       AND cleb.sts_code = 'ACTIVE'
       AND oki.jtot_object1_code = 'OKX_CUSTACCT';
  
    RETURN l_result;
  EXCEPTION
  
    WHEN no_data_found THEN
    
      BEGIN
        --Roman 13/03/2011
        SELECT 'Y' /*nvl2(cleb.id, 'Y', 'N')*/ RESULT
          INTO l_result
          FROM okc_k_lines_b       cleb,
               oks_k_lines_b       kln,
               okc_k_lines_b       okl,
               oks_bus_processes_v bus,
               oe_order_lines_all  oola,
               okc_k_items         oki
         WHERE cleb.id = kln.cle_id
           AND kln.coverage_id = bus.coverage_cle_id
           AND bus.bus_process_name = 'Spare Part Coverage'
           AND cleb.id = okl.cle_id
           AND okl.id = oki.cle_id
           AND oki.object1_id1 = oola.attribute1
           AND oola.line_id = p_line_id
           AND cleb.sts_code = 'ACTIVE'
           AND oki.jtot_object1_code = 'OKX_CUSTPROD';
      
        RETURN l_result;
      EXCEPTION
        WHEN too_many_rows THEN
          RETURN 'Y';
        WHEN OTHERS THEN
          RETURN 'N';
      END;
    
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END get_spcoverage_exist;

  --------------------------------------------------------------------
  --  name:            get_spcoverage_discount
  --  create by:       Roman
  --  Revision:        1.3
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns discount in SP according to contract 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --  1.1  13/03/2011  Roman             additional logic
  --  1.2  23/03/2011  Roman             Fixed discount for indirect contracts 
  --  1.3  19/05/2011  Roman             Reversed get discount, first to check the 
  --                                     contract per serial number 
  --  1.4  02/12/2012  Adi               Get only active contract lines
  --------------------------------------------------------------------
  FUNCTION get_spcoverage_discount(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_discount VARCHAR2(10) := 0;
  
  BEGIN
    SELECT flv.description discount
      INTO l_discount
      FROM okc_k_lines_b       cleb,
           oks_k_lines_b       kln,
           okc_k_lines_b       okl,
           oks_bus_processes_v bus,
           oe_order_lines_all  oola,
           fnd_lookup_values   flv,
           okc_k_items         oki,
           mtl_system_items_b  msib
     WHERE cleb.id = kln.cle_id
       AND kln.coverage_id = bus.coverage_cle_id
       AND msib.inventory_item_id = oola.inventory_item_id
       AND msib.organization_id = 91
       AND bus.bus_process_name = 'Spare Part Coverage'
       AND cleb.id = okl.cle_id
       AND okl.id = oki.cle_id
       AND oki.object1_id1 = oola.attribute1
       AND oola.line_id = p_line_id
       AND okl.sts_code = 'ACTIVE' -- 1.4 Adi Safin
       AND cleb.sts_code = 'ACTIVE'
       AND bus.attribute2 = flv.lookup_type
       AND flv.LANGUAGE = 'US'
       AND (flv.lookup_code = to_char(oola.inventory_item_id) OR
           (flv.lookup_code = msib.material_billable_flag));
  
    RETURN l_discount;
  EXCEPTION
  
    WHEN no_data_found THEN
    
      BEGIN
        SELECT flv.description discount
          INTO l_discount
          FROM okc_k_lines_b       cleb,
               okc_k_lines_b       cleb1,
               oks_k_lines_b       kln,
               oks_bus_processes_v bus,
               oe_order_lines_all  oola,
               fnd_lookup_values   flv,
               mtl_system_items_b  msib,
               okc_k_items         oki
         WHERE cleb.id = kln.cle_id
           AND kln.coverage_id = bus.coverage_cle_id
           AND msib.inventory_item_id = oola.inventory_item_id
           AND msib.organization_id = 91
           AND bus.bus_process_name = 'Spare Part Coverage'
           AND cleb.id = cleb1.cle_id
           AND cleb1.id = oki.cle_id
           AND oki.object1_id1 = oola.sold_to_org_id
           AND oola.line_id = p_line_id
           AND cleb1.sts_code = 'ACTIVE' -- 1.4 Adi Safin
           AND cleb.sts_code = 'ACTIVE'
           AND bus.attribute2 = flv.lookup_type
           AND flv.LANGUAGE = 'US'
           AND (flv.lookup_code = to_char(oola.inventory_item_id) OR
               (flv.lookup_code = msib.material_billable_flag));
      
        RETURN l_discount;
      EXCEPTION
      
        WHEN OTHERS THEN
          RETURN '0';
      END;
    
    WHEN OTHERS THEN
      RETURN '0';
  END get_spcoverage_discount;

END xxcs_advance_pricing_util_pkg;
/
