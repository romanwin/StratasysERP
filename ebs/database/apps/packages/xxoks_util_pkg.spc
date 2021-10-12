create or replace package XXOKS_UTIL_PKG is
 
--------------------------------------------------------------------
-- name:            XXOKS_UTIL_PKG
-- create by:       Dalit A. Raviv
-- Revision:        1.0 
-- creation date:   30/01/2011 11:27:52
--------------------------------------------------------------------
-- purpose :        Util package for all OKS Module
--------------------------------------------------------------------
-- ver  date        name             desc
-- 1.0  30/01/2011  Dalit A. Raviv   initial build
-- 1.1  03/05/2011  Dalit A. Raviv   add function get_discount
--------------------------------------------------------------------

  --------------------------------------------------------------------
  -- name:            get_price_list_name
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   30/01/2011 11:27:52
  --------------------------------------------------------------------
  -- purpose :        Function that by party id currency org_id line_number
  --                  and coverage_name return the relavant price_list.
  -- In Param:        p_party_id
  --                  p_line_name
  --                  p_currency
  --                  p_org_id
  --                  p_std_coverage_name
  -- Return:          Price list name
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  30/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_price_list_name (p_party_id          in number,
                                p_line_name         in varchar2,
                                p_currency          in varchar2,
                                p_org_id            in number,
                                p_std_coverage_name in varchar2) return varchar2;
  
  --------------------------------------------------------------------
  -- name:            get_discount
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   03/05/2011 11:27:52
  --------------------------------------------------------------------
  -- purpose :        Function that calculate contact discount
  --                  Use at XX: Service Contract Quote Form report
  -- In Param:        p_start_date       contract line start date
  --                  p_end_date         contract line ends  date
  --                  p_list_price       contract line price
  --                  p_price_negotiated contract line price negotiated
  -- Return:          contract line discount
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  30/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_discount(p_start_date				in date,
												p_end_date   				in date,
												p_list_price				in number,
												p_price_negotiated 	in number	) return number;
 
end XXOKS_UTIL_PKG;
/

