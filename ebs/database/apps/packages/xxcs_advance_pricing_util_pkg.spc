CREATE OR REPLACE PACKAGE xxcs_advance_pricing_util_pkg IS

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
--  1.1  11/01/2011  Roman V.          added get_header_exist procedue
--  1.2  13/03/2011  Roman V.          added logic to get_spcoverage_exists and 
--                                     get sp_coverage_discount
--  1.3  23/03/2011  Roman V.          Fixed validation for indirect contracts  
--  1.4  03/04/2011  Roman V.          Changed SP items validation, added training items 
--  1.5  19/05/2011  Roman V.          Added logic of Upgade items discounts 
--  1.6  21/06/2011  Roman V.          add functions: get_service_item_price , get_service_item                                                                             
-------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:            get_spare_part
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --------------------------------------------------------------------
  FUNCTION get_spare_part(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_service_item
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   21/06/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        Returns Y/N in case of spare part item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/06/2011  Roman             initial build
  --------------------------------------------------------------------
  FUNCTION get_service_item(p_line_id IN NUMBER) RETURN VARCHAR2;

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
  --------------------------------------------------------------------
  FUNCTION get_service_item_price(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_spcoverage_exist
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --------------------------------------------------------------------
  FUNCTION get_spcoverage_exist(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_spcoverage_discount
  --  create by:       Roman
  --  Revision:        1.0
  --  creation date:   11/01/2011
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/01/2011  Roman             initial build
  --------------------------------------------------------------------
  FUNCTION get_spcoverage_discount(p_line_id IN NUMBER) RETURN VARCHAR2;

END xxcs_advance_pricing_util_pkg;
/

