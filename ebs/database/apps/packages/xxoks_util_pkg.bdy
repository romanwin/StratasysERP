create or replace package body xxoks_util_pkg is

--------------------------------------------------------------------
-- name:            XXOKS_UTIL_PKG
-- create by:       Dalit A. Raviv
-- Revision:        1.2 
-- creation date:   30/01/2011 11:27:52
--------------------------------------------------------------------
-- purpose :        Util package for all OKS Module
--------------------------------------------------------------------
-- ver  date        name             desc
-- 1.0  30/01/2011  Dalit A. Raviv   initial build
-- 1.1  03/05/2011  Dalit A. Raviv   add function get_discount
-- 1.2  20/03/2013  Adi Safin        procedure get_price_list_name - Add support for Printer Care PL 
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
  -- 1.1  20/03/2013  Adi Safin        Add support for Printer Care PL  
  --------------------------------------------------------------------
  function get_price_list_name (p_party_id          in number,
                                p_line_name         in varchar2,
                                p_currency          in varchar2,
                                p_org_id            in number,
                                p_std_coverage_name in varchar2) return varchar2 is
                                
    l_count   number        := 0;
    l_pl_name varchar2(240) := null;
  BEGIN
    -- Start 1.1  20/03/2013  Adi Safin 
    BEGIN
      -- check line name is PRINTER CARE for SERVICE CARE
      select count(1)
      into   l_count
      from   okc_k_headers_all_b h,
             okc_k_party_roles_b okp,
             okc_k_lines_b       l,
             okc_k_items         oki,
             mtl_system_items_b  msib
      where  oki.cle_id          = l.id
      and    l.chr_id            = h.id
      and    msib.inventory_item_id = oki.object1_id1
      and    msib.organization_id   = 91
      and    msib.segment1       = 'SERVICE CARE'
      and    okp.chr_id          = h.id
      and    okp.object1_id1     = p_party_id --:oks_header_parties.party_id_old
      and    p_line_name         = 'PRINTER CARE';
    exception
      when others then 
        l_count := 0;
    end ; 
    
    if l_count > 0 then
      begin
        select qlht.name
        into   l_pl_name
        from   qp_list_headers_all_b qlhb, 
               qp_list_headers_tl    qlht
        where  qlhb.list_header_id   = qlht.list_header_id
        and    qlht.language         = 'US'
        and    nvl(qlhb.attribute1,  p_org_id) = p_org_id --:oks_header.org_id
        and    qlhb.currency_code    = p_currency
        and    qlht.name             like ('PRINTER CARE with ServiceCare%');
        
        return l_pl_name;
      exception 
        when others then null;
      end;
    end if;    
    -- End 1.1  20/03/2013  Adi Safin 
    begin
      -- check line name is SPID for SERVICE CARE
      select count(1)
      into   l_count
      from   okc_k_headers_all_b h,
             okc_k_party_roles_b okp,
             okc_k_lines_b       l,
             okc_k_items         oki,
             mtl_system_items_b  msib
      where  oki.cle_id          = l.id
      and    l.chr_id            = h.id
      and    msib.inventory_item_id = oki.object1_id1
      and    msib.organization_id   = 91
      and    msib.segment1       = 'SERVICE CARE'
      and    okp.chr_id          = h.id
      and    okp.object1_id1     = p_party_id --:oks_header_parties.party_id_old
      and    p_line_name         = 'SPID';
    exception
      when others then 
        l_count := 0;
    end ; 
    
    
     if l_count > 0 then
      begin
        select qlht.name
        into   l_pl_name
        from   qp_list_headers_all_b qlhb, 
               qp_list_headers_tl    qlht
        where  qlhb.list_header_id   = qlht.list_header_id
        and    qlht.language         = 'US'
        and    nvl(qlhb.attribute1,  p_org_id) = p_org_id --:oks_header.org_id
        and    qlhb.currency_code    = p_currency
        and    qlht.name             like ('SPID with ServiceCare%');
        
        return l_pl_name;
      exception 
        when others then null;
      end;
    end if;
    -- if yes return price list where the name like SPID with ServiceCare%
    if l_count > 0 then
      begin
        select qlht.name
        into   l_pl_name
        from   qp_list_headers_all_b qlhb, 
               qp_list_headers_tl    qlht
        where  qlhb.list_header_id   = qlht.list_header_id
        and    qlht.language         = 'US'
        and    nvl(qlhb.attribute1,  p_org_id) = p_org_id --:oks_header.org_id
        and    qlhb.currency_code    = p_currency
        and    qlht.name             like ('SPID with ServiceCare%');
        
        return l_pl_name;
      exception 
        when others then null;
      end;
    end if;
    -- check line name is SPID for TOTAL CARE
    begin
      select count(1)
      into   l_count
      from   okc_k_headers_all_b h,
             okc_k_party_roles_b okp,
             okc_k_lines_b       l,
             okc_k_items         oki,
             mtl_system_items_b  msib
      where  oki.cle_id          = l.id
      and    l.chr_id            = h.id
      and    msib.inventory_item_id = oki.object1_id1
      and    msib.organization_id   = 91
      and    msib.segment1       = 'TOTAL CARE'
      and    okp.chr_id          = h.id
      and    okp.object1_id1     = p_party_id --:oks_header_parties.party_id_old
      and    p_line_name = 'SPID';
    exception
      when others then
        l_count := 0;
    end;
    -- if yes return price list where the name like SPID with ServiceCare%
    if l_count > 0 then
      begin
        select qlht.name
        into   l_pl_name
        from   qp_list_headers_all_b qlhb, 
               qp_list_headers_tl    qlht
        where  qlhb.list_header_id   = qlht.list_header_id
        and    qlht.language         = 'US'
        and    nvl(qlhb.attribute1,  p_org_id) = p_org_id --:oks_header.org_id
        and    qlhb.currency_code    = p_currency
        and    qlht.name             like ('SPID with TotalCare%');
        
        return l_pl_name;
      exception
        when others then 
          null;
      end;
    end if;
    -- if yes return price list by org_id and std_coverage_name
    begin
    select qlht.name
    into   l_pl_name
    from   qp_list_headers_all_b qlhb, 
           qp_list_headers_tl    qlht
    where  qlhb.list_header_id   = qlht.list_header_id
    and    qlht.language         = 'US'
    and    qlhb.attribute1       = p_org_id --:oks_header.org_id
    and    qlhb.attribute2       = p_std_coverage_name;
      
    return l_pl_name;
      
    exception
      when others then
        return null;
    end;
  
    return l_pl_name;
  exception  
    when others then 
      return null;
  end get_price_list_name;   
  
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
												p_price_negotiated 	in number	) return number IS

    l_duration 			number       	:= null;
    l_timeunit 			varchar2(50) 	:= null;
    l_return_status varchar2(50) 	:= null;
    l_factor				number				:= null;
    l_discount			number				:= null;

  begin
    -- 1.3 03/05/2011 Dalit A. Raviv 
    -- change logic of calculate discount.
    -- the discount relate to the duration of the contract
    if p_list_price = 0 then
      return 0;
    else
    	  
      OKC_TIME_UTIL_PUB.get_duration( p_start_date, 		--p_start_date 		in  date,
                                      p_end_date,   		--p_end_date   		in  date,
                                      l_duration,				--x_duration   		out nocopy number,
                                      l_timeunit,				--x_timeunit   		out nocopy varchar2,
                                      l_return_status); --x_return_status out nocopy varchar2);
    	
      if l_timeunit = 'YR' then     		-- Year
        l_factor := l_duration * 1;
      elsif l_timeunit = 'QTR' then			-- Quarter
        l_factor := l_duration * 0.25; 
      elsif l_timeunit = 'MTH' then			-- Months
        l_factor := round(l_duration * (1/12),2); 
      elsif l_timeunit = 'WK' then			-- Week
        l_factor := round(l_duration * (1/52),2);  
      elsif l_timeunit = 'DAY' then			-- Day
        l_factor := round(l_duration * (1/365),2); 
      end if;
    --srw.message(100,'l_timeunit - '||l_timeunit); 
    --srw.message(110,'l_duration - '||l_duration); 
    --srw.message(120,'l_factor   - '||l_factor); 	
      l_discount := trunc((((p_list_price * l_factor) - p_price_negotiated) / (p_list_price * l_factor)) * 100 ,2);
    --srw.message(120,'l_discount - '||l_discount);   	
      return l_discount;	
    end if;

  end get_discount;                             
                                
end XXOKS_UTIL_PKG;
/
