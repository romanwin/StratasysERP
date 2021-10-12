create or replace package body xxasn_price_book_pkg is

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
  function get_user_price (p_price          in number,
                           p_item_number    in varchar2,
                           p_list_header_id in number,
                           p_type           in varchar2) return number is
    
    l_end_user_price1 number := null;
    l_edu_list_header_id number;
  
  begin
  
    select /*qlh.list_header_id, ffvd.price_list_type,*/ ffvd.end_user_pl
    into   l_edu_list_header_id
    from   qp_list_headers_all_b    qlh,
           fnd_flex_values          ffv,
           fnd_flex_value_sets      ffvs,
           fnd_flex_values_dfv      ffvd
    where  ffv.flex_value_set_id    = ffvs.flex_value_set_id
     and   ffvs.flex_value_set_name = 'XXPB_PRICE_LISTS'
     and   qlh.list_header_id       = ffv.flex_value
     and   ffv.rowid                = ffvd.row_id
     and   qlh.list_header_id       = p_list_header_id
     and   ffvd.price_list_type     = p_type;
  
    select nvl2(p_price,  ((1 - p_price / 100) * edu_l.operand), edu_l.operand) end_user_price1
    into   l_end_user_price1
    from   qp_list_headers_all_b      edu,
           qp_list_lines              edu_l,
           qp_pricing_attributes      edu_qpa,
           mtl_system_items_b         msib
    where  edu.list_header_id         = edu_l.list_header_id
    and    edu_l.list_line_id         = edu_qpa.list_line_id
    and    (edu_l.end_date_active     is null or edu_l.end_date_active > sysdate) 
    and    edu.list_header_id  				= l_edu_list_header_id /*p_edu_list_header_id*/	--p_list_header_id 
    and    edu_qpa.product_attr_value = to_char(msib.inventory_item_id)
    and    msib.organization_id       = 91
    and    msib.segment1              = p_item_number;		--p_item_id   

    return l_end_user_price1;
  exception
    when others then 
      return null;
  end get_user_price;  
  
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
  function get_currency (p_list_header_id in number) return varchar2  is
  
    l_currency varchar2(150) := null;
    
  begin
    select trf.currency_code
    into   l_currency
    from   qp_list_headers_all_b trf
    where  trf.list_header_id    = p_list_header_id;
    
    return l_currency;
  exception
    when others then 
      return null;
  end get_currency; 
  
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
  function get_price_list_name (p_list_header_id in number) return varchar2  is
  
    l_price_list_name varchar2(240) := null;
    
  begin
    select --trft.name
           replace(replace(replace (trft.name,'€',' - EUR'),'£',' - GBP'),'$',' - USD') 
    into   l_price_list_name
    from   qp_list_headers_tl   trft
    where  trft.list_header_id  = p_list_header_id
    and    trft.language        = 'US';
    
    return l_price_list_name;
  exception
    when others then 
      return null;
  end get_price_list_name;
                     
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
  function get_transfer_price (p_price_list_id   in number,
                               p_price           in number,
                               p_item_number     in varchar2,
                               p_entity          in varchar2 default null) return number is
     l_transfer_price2 number := null;
                               
  begin
    select case when p_entity = 'RESIN' then
                  case when xxhz_party_ga_util.get_constant_discount(to_number(trf.attribute7)) = 0 then
                         trf_l.operand * (1 - nvl(p_price,0)/100)
                       else
                         trf_l.operand * (1 - nvl(p_price,0)/100) * ( 1 - xxhz_party_ga_util.get_constant_discount(to_number(trf.attribute7)) / 100)
                  end
                else
                  trf_l.operand * (1 - nvl(p_price,0)/100)
           end  transfer_price2
    into   l_transfer_price2
    from   qp_list_headers_all_b trf,
           qp_list_lines         trf_l,
           qp_pricing_attributes trf_qpa,
           mtl_system_items_b    msib
    where  trf.list_header_id         = trf_l.list_header_id
    and    trf_l.list_line_id         = trf_qpa.list_line_id
    and    (trf_l.end_date_active     is null or trf_l.end_date_active > sysdate) 
    and    trf.list_header_id  				= p_price_list_id
    and    trf_qpa.product_attr_value = to_char(msib.inventory_item_id)
    and    msib.organization_id       = 91
    and    msib.segment1              = p_item_number;	   

    return l_transfer_price2;
  exception
    when others then 
      return null;
     
  end get_transfer_price;                              
   
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
                        p_territory        in  varchar2) is
                        
    --l_print_option boolean;
    --l_printer_name varchar2(150) := null;
    l_request_id   number        := null;
    l_program      varchar2(100) := null;
    l_template     boolean;
  
  begin
    if p_type = 'Direct' then
      l_program  := 'XXCS_PRICE_BOOK_DIRECT';
      l_template := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                           template_code      => 'XXCS_PRICE_BOOK_DIRECT',
                                           template_language  => 'en',
                                           output_format      => 'PDF', 
                                           template_territory => 'US');
    else
      l_program := 'XXCS_PRICE_BOOK_INDIRECT';
      l_template := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                           template_code      => 'XXCS_PRICE_BOOK_INDIRECT',
                                           template_language  => 'en',
                                           output_format      => 'PDF', 
                                           template_territory => 'US');
    end if;
    
    if l_template = TRUE then
          
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => l_program,
                                                 description => null,
                                                 start_time  => null,
                                                 sub_request => FALSE,
                                                 argument1   => p_type,
                                                 argument2   => p_price_list_id,
                                                 argument3   => p_platform,
                                                 argument4   => p_territory);
      if l_request_id = 0 then

        fnd_file.put_line(fnd_file.log,'-----------------------------------');
        fnd_file.put_line(fnd_file.log,'------ Failed to print report -----');
        fnd_file.put_line(fnd_file.log,'-----------------------------------');
        errbuf  := sqlcode;
        retcode := sqlerrm;
      else
        fnd_file.put_line(fnd_file.log,'-----------------------------------');
        fnd_file.put_line(fnd_file.log,'----- Success to print report -----');
        fnd_file.put_line(fnd_file.log,'-----------------------------------');
        errbuf  := 0;
        retcode := 'Success to print report';
        -- must commit the request
        commit;
      end if; 
    else
      --
      -- Didn't find printer
      --
      fnd_file.put_line(fnd_file.log,'-----------------------------------');
      fnd_file.put_line(fnd_file.log,'------ Can not Find Template ------');
      fnd_file.put_line(fnd_file.log,'-----------------------------------');
      errbuf  := sqlcode;
      retcode := sqlerrm;
    end if; -- l_print_option

  exception
    when others then 
      errbuf  := 'Run Report - EXCEPTION - '||substr(sqlerrm,1,240);
      retcode := 2;
  end run_report; 
  
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
                                p_territory        in  varchar2) is
  
    l_user_id  number := null;
    l_discount number := null;
  
  begin
    errbuf  := null;
    retcode := 0;
    -- get user id
    l_user_id  := fnd_global.USER_ID;
    -- user can update to discount null -> mean no discount for this price book
    if p_discount <> 0 then
      l_discount := p_discount;
    else
      l_discount := null;
    end if;
  
    -- Mass update of the lookup with the new discount 
    if p_discount_type = 'End_User_Price' then
      update fnd_lookup_values    flv 
      set    attribute4           = l_discount,
             flv.last_update_date = sysdate,
             flv.last_updated_by  = l_user_id
      where  flv.lookup_type      = p_lookup_name
      and    flv.tag              = p_territory;  -- 1.1 23/01/2011 Dalit A. Raviv
    elsif p_discount_type = 'Transfer_Price' then
      update fnd_lookup_values    flv 
      set    attribute3           = l_discount,
             flv.last_update_date = sysdate,
             flv.last_updated_by  = l_user_id
      where  flv.lookup_type      = p_lookup_name
      and    flv.tag              = p_territory;  -- 1.1 23/01/2011 Dalit A. Raviv
    end if;
    
    commit;
  exception
    when others then
      rollback;
      errbuf  := 'pb_apply_discounts failed - '||substr(sqlerrm,1,500);
      retcode := 1;
      fnd_file.put_line(fnd_file.log,errbuf);
  end pb_apply_discounts; 
  
  --------------------------------------------------------------------
  --  name:            get_footer_msg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   09/02/2011 
  --------------------------------------------------------------------
  --  purpose :        Function that by territory, type (Direct/Indirect)
  --                   and platform (Desktop/Eden connex) will return the 
  --                   correct message.
  --  in param:        p_type      - Direct, Indirect
  --                   p_territory - CN, DE, HK, IL, US
  --                   p_platform  - Desktop, Eden/Connex
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                               
  function get_footer_msg      (p_territory        in  varchar2, -- region
                                p_type             in  varchar2,
                                p_platform         in  varchar2) return varchar2 is
  
    l_message_name varchar2(30)   := null;
    l_message      varchar2(2000) := null;
  begin
   
    l_message_name := 'XXCS_PB_SYSTEM_'||p_territory;
    if p_type = 'Direct' then
      l_message_name := l_message_name||'_DIR';
    else
      l_message_name := l_message_name||'_INDIR';
    end if;
    
    if p_platform = 'Desktop' then
      l_message_name := l_message_name||'_DESK';
    else
      l_message_name := l_message_name||'_EDEN';
    end if;
    
    fnd_message.SET_NAME('XXOBJT',l_message_name);
    l_message := fnd_message.GET;
    
    return l_message;
  exception
    when others then 
      return null;
  end get_footer_msg; 
  
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
                                p_item_number      in varchar2) return varchar2 is
  
    l_demo_unit_price varchaR2(150) := null;
  begin
    select trf_l.attribute2
    into   l_demo_unit_price
    from   qp_list_headers_all_b trf,
           qp_list_lines         trf_l,
           qp_pricing_attributes trf_qpa,
           mtl_system_items_b    msib
    where  trf.list_header_id         = trf_l.list_header_id
    and    trf_l.list_line_id         = trf_qpa.list_line_id
    and    (trf_l.end_date_active     is null or trf_l.end_date_active > sysdate) 
    and    trf.list_header_id          = p_list_header_id --9013
    and    trf_qpa.product_attr_value = to_char(msib.inventory_item_id)
    and    msib.organization_id       = 91
    and    msib.segment1              = p_item_number ; --'OBJ-13000';	 
  
    return l_demo_unit_price;
  exception
    when others then
      return null;
  end get_demo_unit_price;                                
                                                      
-- XXASN_PRICE_BOOK_PKG.get_footer_msg                       
end XXASN_PRICE_BOOK_PKG;
/
