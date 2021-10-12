create or replace package xxasn_price_book_pkg is
--------------------------------------------------------------------
--  name:            XXASN_PRICE_BOOK_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   26/09/2010 1:30:11 PM
--------------------------------------------------------------------
--  purpose :        Handle price book package
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  26/09/2010  Dalit A. Raviv    initial build
--  1.1  26/12/2010  Dalit A. Raviv    add run_report  
--  1.2  16/01/2011  Dalit A. Raviv    add procedure pb_apply_discounts
--  1.3  23/01/2011  Dalit A. Raviv    procedure pb_apply_discounts add parameter
--                                     procedure run_report add parameter
--  1.4  09/02/2011  Dalit A. Raviv    add function get_footer_msg
--  1.5  23/11/2011  Dalit A. Raviv    function get_transfer_price - 
--                                     add parameter and constant discount for resin
--  1.6  30/11/2011  Dalit A. Raviv    add function get_demo_unit_price
-------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:            get_user_price
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   26/09/2010 
  --------------------------------------------------------------------
  --  purpose :        get user price
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_user_price (p_price              in number,
                           p_item_number        in varchar2,
                           p_list_header_id     in number,
                           p_type               in varchar2) return number;
  
  --------------------------------------------------------------------
  --  name:            get_currency
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   26/09/2010 
  --------------------------------------------------------------------
  --  purpose :        get price list currency 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_currency   (p_list_header_id     in number) return varchar2;
  
  --------------------------------------------------------------------
  --  name:            get_transfer_price
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   26/09/2010 
  --------------------------------------------------------------------
  --  purpose :        get transfer price
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  --  1.1  23/11/2011  Dalit A. Raviv    add parameter and constant discount for resin
  -------------------------------------------------------------------- 
  function get_transfer_price (p_price_list_id  in number,
                               p_price          in number,
                               p_item_number    in varchar2,
                               p_entity         in varchar2 default null) return number;
                                                      
  --------------------------------------------------------------------
  --  name:            get_price_list_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   26/09/2010 
  --------------------------------------------------------------------
  --  purpose :        get price list name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_price_list_name (p_list_header_id in number) return varchar2;                               

  --------------------------------------------------------------------
  --  name:            run_report
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   26/12/2010 
  --------------------------------------------------------------------
  --  purpose :        get price list name
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/12/2010  Dalit A. Raviv    initial build
  --  1.1  23/01/2011  Dalit A. Raviv    add territory parameter
  -------------------------------------------------------------------- 
  Procedure run_report (errbuf             out varchar2,
                        retcode            out varchar2,
                        p_type             in  varchar2,
                        p_price_list_id    in  number,
                        p_platform         in  varchar2,
                        p_territory        in  varchar2);
                        
  --------------------------------------------------------------------
  --  name:            pb_apply_discounts
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/01/2011 
  --------------------------------------------------------------------
  --  purpose :        Program that _apply_discounts
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/01/2011  Dalit A. Raviv    initial build
  --  1.1  23/01/2011  Dalit A. Raviv    add parameter p_territory.
  --                                     Roman add Tag to all lookups that will differ between territories.
  --                                     so when update i need to update the wanted territory values only
  -------------------------------------------------------------------- 
  procedure pb_apply_discounts (errbuf             out varchar2,
                                retcode            out varchar2,
                                p_lookup_name      in  varchar2,
                                p_discount_type    in  varchar2,
                                p_discount         in  number,
                                p_territory        in  varchar2); 
  
  --------------------------------------------------------------------
  --  name:            get_footer_msg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   09/02/2011 
  --------------------------------------------------------------------
  --  purpose :        Function that by territory, type (Direct/Indirect)
  --                   and platform (Desktop/Eden connex) will return the 
  --                   correct message.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                               
  function get_footer_msg      (p_territory        in  varchar2, -- region
                                p_type             in  varchar2,
                                p_platform         in  varchar2) return varchar2;  
                                
  --------------------------------------------------------------------
  --  name:            get_demo_unit_price
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   30/11/2011 
  --------------------------------------------------------------------
  --  purpose :        Function that return demo unit price
  --                   for price list and item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/11/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------          
  function get_demo_unit_price (p_list_header_id   in number,
                                p_item_number      in varchar2) return varchar2;                                                                                      
  
end XXASN_PRICE_BOOK_PKG;
/
