create or replace package body XXCS_DISCO_PKG is

--------------------------------------------------------------------
--  name:            XXCS_DISCO_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   14/02/2011 09:19:34
--------------------------------------------------------------------
--  purpose :        Package that will handle all CS Disco functions
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  14/02/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------      
 
  --------------------------------------------------------------------
  --  name:            get_early_contract_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/02/2011 09:19:34
  --------------------------------------------------------------------
  --  purpose :        function that for time and material instances
  --                   will check early period of 60 days and see if there was 
  --                   a warranty or contract.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------    
  function get_early_contract_status (p_instance_id in number,
                                      p_from_date   in date,
                                      p_to_date     in date) return varchar2 is
                                      
    l_contract_or_warranty varchar2(150) := null;
  begin
    select gg.contract_or_warranty
    into   l_contract_or_warranty
    from   (select zz.contract_service_id,
                   zz.contract_number,
                   zz.contract_id,
                   zz.line_id,
                   zz.party_id,
                   zz.instance_id,
                   zz.contract_or_warranty,
                   zz.line_start_date,
                   zz.line_end_date,
                   zz.line_date_terminated,
                   zz.service,
                   zz.type,
                   zz.coverage,
                   zz.version_number,
                   zz.line_subtotal_converted_usd,
                   zz.modifier,
                   zz.org_id,
                   zz.operating_unit,
                   zz.cs_region,
                   zz.item_type,
                   zz.account_name,
                   zz.account_number,
                   zz.invoiced,
                   DENSE_RANK() OVER(PARTITION BY zz.party_id, zz.instance_id ORDER BY nvl(zz.line_date_terminated, zz.line_end_date) DESC) rank
            from   xxcs_inst_contr_and_warr_all_v zz
            where  zz.line_status not in ('CANCELLED', 'ENTERED', 'SIGNED')
            and    nvl(zz.line_date_terminated, zz.line_end_date) between p_from_date and p_to_date
           ) gg
    where gg.rank        = 1
    and   gg.instance_id = p_instance_id; -- 368017;
    
    return l_contract_or_warranty;
  exception
    when others then
      return 'T&M';
  end get_early_contract_status; 
                                     
end XXCS_DISCO_PKG;
/

