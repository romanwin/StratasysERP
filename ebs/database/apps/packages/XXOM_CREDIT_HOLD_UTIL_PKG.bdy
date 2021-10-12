create or replace package body XXOM_CREDIT_HOLD_UTIL_PKG  is
--------------------------------------------------------------------
--  name:            XXOM_CREDIT_HOLD_UTIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   07/07/2015 15:16:56
--------------------------------------------------------------------
--  purpose :        CHG0035495 - Workflow for credit check Hold on SO
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/07/2015  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  c_debug_module CONSTANT VARCHAR2(100) := 'xxar.cc_approval.xxom_credit_hold_util_pkg_pkg.';
  --g_message               varchar2(2500);

  --------------------------------------------------------------------
  --  name:            print_log
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   09/07/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   Print message to log
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  09/07/2015  Dalit A. RAviv  CHG0035495
  --------------------------------------------------------------------
  procedure print_log(p_print_msg varchar2) is
  begin
    if fnd_global.conc_request_id = -1 then
      dbms_output.put_line(p_print_msg);
    else
      fnd_file.put_line(FND_FILE.LOG,p_print_msg);
    end if;
  end print_log;

  --------------------------------------------------------------------
  --  name:            print_log
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   09/07/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   Print message to output
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  09/07/2015  Dalit A. RAviv  CHG0035495
  --------------------------------------------------------------------
  procedure print_out(p_print_msg varchar2) is
  begin
    if fnd_global.conc_request_id = -1 then
      dbms_output.put_line(p_print_msg);
    else
      fnd_file.put_line(FND_FILE.OUTPUT,p_print_msg);
    end if;
  end print_out;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_approver_by_region
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      07/07/2015
  --  Purpose :           get approver name from lookup by region and limit
  --                      this function look by region and credit limit who is the approver
  --                      this function will be use for the first approver and last approver
  --
  --                      NOTE - in any case that do not find information the default approver
  --                             will retrieve from profile.
  --
  --  In Parameters:      p_limit  - customer credit limit
  --                      p_region - the region of the approver
  --                      p_entity - can get LAST / FIRST
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   07/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_approver_by_region (p_limit  in number,
                                   p_region in varchar2,
                                   p_entity in varchar2,
                                   p_org_id in number) return varchar2 is
                                   
    l_approver  varchar2(150) := null;
    l_approver2 varchar2(150) := null;
    l_approver1 varchar2(150) := null;
  begin
    -- get the approver by region and customer credit limit
    -- if return TOO_MANY_ROWS get the approver by region, customer credit limit and org_id
    --    exception NO_DATA_FOUND get the approver by region, customer credit limit and ALL
    --        exception others -> get the approver by customer credit limit for CORPORATE tag
    --            exception return the default from profile
    -- if exception others -> get the approver by customer credit limit for CORPORATE tag
    --    exception return the default from profile.
    -- 
    -- by the entity FIRST (attribute1)/ LAST (attribute2) return the relevant approver
    -- begin1
    begin
      select flv.attribute2, flv.attribute1
      into   l_approver2 , l_approver1
      from   fnd_lookup_values flv
      where  flv.lookup_type   = 'XXOM_CREDIT_CHECK_HOLD_APP_HIR'
      and    flv.language      = 'US'
      and    flv.enabled_flag  = 'Y'
      and    trunc(sysdate)    between nvl(flv.start_date_active,sysdate -1) and nvl(flv.end_date_active, sysdate +1)
      and    flv.tag           = p_region
      and    p_limit           between to_number(flv.attribute3) and to_number(flv.attribute4);
    exception
      when TOO_MANY_ROWS then
        -- begin2
        begin
          select flv.attribute2, flv.attribute1
          into   l_approver2 , l_approver1
          from   fnd_lookup_values flv
          where  flv.lookup_type   = 'XXOM_CREDIT_CHECK_HOLD_APP_HIR'
          and    flv.language      = 'US'
          and    flv.enabled_flag  = 'Y'
          and    trunc(sysdate)    between nvl(flv.start_date_active,sysdate -1) and nvl(flv.end_date_active, sysdate +1)
          and    flv.tag           = p_region
          and    p_limit           between to_number(flv.attribute3) and to_number(flv.attribute4)
          and    flv.description   = to_char(p_org_id);
        exception
          when NO_DATA_FOUND then
            -- begin3
            begin
              select flv.attribute2, flv.attribute1
              into   l_approver2 , l_approver1
              from   fnd_lookup_values flv
              where  flv.lookup_type   = 'XXOM_CREDIT_CHECK_HOLD_APP_HIR'
              and    flv.language      = 'US'
              and    flv.enabled_flag  = 'Y'
              and    trunc(sysdate)    between nvl(flv.start_date_active,sysdate -1) and nvl(flv.end_date_active, sysdate +1)
              and    flv.tag           = p_region
              and    p_limit           between to_number(flv.attribute3) and to_number(flv.attribute4)
              and    flv.description   = 'ALL';
            exception
              when others then
                -- begin4
                begin
                  -- if did found at region level because of the limit, look at the same lookup
                  -- with the same limit with tag of CORPORATE
                  -- NOTE there can be several CORPORATE records but the limit will be different.
                  select flv.attribute2, flv.attribute1
                  into   l_approver2 , l_approver1
                  from   fnd_lookup_values flv
                  where  flv.lookup_type   = 'XXOM_CREDIT_CHECK_HOLD_APP_HIR'
                  and    flv.language      = 'US'
                  and    flv.enabled_flag  = 'Y'
                  and    trunc(sysdate)    between nvl(flv.start_date_active,sysdate -1) and nvl(flv.end_date_active, sysdate +1)
                  and    flv.tag           = 'CORPORATE'
                  and    p_limit           between to_number(flv.attribute3) and to_number(flv.attribute4);
                exception
                  when others then
                    l_approver := fnd_profile.VALUE_SPECIFIC('XXAR_DEFAULT_CREDIT_CHECK_APPROVER',
                                                             null, null, null, p_org_id, null);
                end; -- begin4
            end;-- begin3
         end; -- begin2
      when others then
        -- begin5
        begin
          -- if did not found at region level because of the limit, look at the same lookup
          -- with the same limit with tag of CORPORATE
          -- NOTE there can be several CORPORATE records but the limit will be different.
          select flv.attribute2, flv.attribute1
          into   l_approver2 , l_approver1
          from   fnd_lookup_values flv
          where  flv.lookup_type   = 'XXOM_CREDIT_CHECK_HOLD_APP_HIR'
          and    flv.language      = 'US'
          and    flv.enabled_flag  = 'Y'
          and    trunc(sysdate)    between nvl(flv.start_date_active,sysdate -1) and nvl(flv.end_date_active, sysdate +1)
          and    flv.tag           = 'CORPORATE'
          and    p_limit           between to_number(flv.attribute3) and to_number(flv.attribute4);
        exception
          when others then
            l_approver := fnd_profile.VALUE_SPECIFIC('XXAR_DEFAULT_CREDIT_CHECK_APPROVER',
                                                     null, null, null, p_org_id, null);
        end;-- begin5
    end;-- begin1

    if p_entity = 'FIRST' then
      if l_approver is not null and l_approver1 is null then
        return l_approver;
      else
        return l_approver1;
      end if;
    else
      if l_approver is not null and l_approver2 is null then
        return l_approver;
      else
        return l_approver2;
      end if;
    end if;
  
  
  end get_approver_by_region;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_customer_credit_limit
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      07/07/2015
  --  Purpose :
  --  In Parameters:
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   07/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_customer_credit_limit (p_invoice_to_org_id in number) return number is
    l_credit_limit number := null;
  begin
    select  min(amt.overall_credit_limit)
    into    l_credit_limit
    from    --apps.oe_order_headers_all   ooh,
            hz_cust_site_uses_all       hcsu,
            hz_cust_acct_sites_all      hcasa,
            hz_cust_accounts            hca,
            hz_cust_profile_amts        amt,
            hz_customer_profiles        hcp
    where   --ooh.invoice_to_org_id       = hcsu.site_use_id
            hcsu.site_use_id            = p_invoice_to_org_id
    and     hcsu.cust_acct_site_id      = hcasa.cust_acct_site_id
    and     hca.cust_account_id         = hcasa.cust_account_id
    and     hcp.cust_account_profile_id = amt.cust_account_profile_id(+)
    and     hcp.cust_account_id         = hca.cust_account_id(+)
    and     hcp.site_use_id             is null
    and     amt.site_use_id             is null
    and     amt.currency_code           = 'USD';
    --and     ooh.order_number            = '284294'

    return l_credit_limit;
  exception
    when others then
      return 0;

  end get_customer_credit_limit;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_org_region
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      08/07/2015
  --  Purpose :           get approver name
  --                      get the OU from the SO -> get from the legal entity
  --                      get the company -> connect to value set 'XXGL_COMPANY_SEG' ->
  --                      get the region
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   08/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_org_region (p_org_id in number) return varchar2 is
    l_region varchar2(240);
  begin
    select  distinct
            --hroutl_ou.name               ou_name,
            --hroutl_ou.organization_id    org_id,
            --glev.flex_segment_value      company,
            fv.attribute1                region
    into    l_region
    from    xle_entity_profiles          lep,
            xle_registrations            reg,
            hr_locations_all             hrl,
            hz_parties                   hzp,
            fnd_territories_vl           ter,
            hr_operating_units           hro,
            hr_all_organization_units_tl hroutl_bg,
            hr_all_organization_units_tl hroutl_ou,
            hr_organization_units        hou,
            gl_legal_entities_bsvs       glev,
            fnd_flex_values_vl           fv,
            fnd_flex_value_sets          fvs
    where
    -- find the company from the ou
            lep.transacting_entity_flag  = 'Y'
    and     lep.party_id                 = hzp.party_id
    and     lep.legal_entity_id          = reg.source_id
    and     reg.source_table             = 'XLE_ENTITY_PROFILES'
    and     hrl.location_id              = reg.location_id
    and     reg.identifying_flag         = 'Y'
    and     ter.territory_code           = hrl.country
    and     lep.legal_entity_id          = hro.default_legal_context_id
    and     hou.organization_id          = hro.organization_id
    and     hroutl_bg.organization_id    = hro.business_group_id
    and     hroutl_ou.organization_id    = hro.organization_id
    and     glev.legal_entity_id         = lep.legal_entity_id
    -- by the company get the region
    and     fv.flex_value_set_id         = fvs.flex_value_set_id
    and     fvs.flex_value_set_name      like 'XXGL_COMPANY_SEG'
    and     fv.flex_value                = glev.flex_segment_value
    and     fv.enabled_flag              = 'Y'
    and     trunc(sysdate)               between nvl(fv.start_date_active,sysdate -1)
                                         and nvl(fv.end_date_active,sysdate +1)
    and     hroutl_bg.language           = 'US'
    and     hroutl_ou.language           = 'US' 
    and     fv.attribute1                is not null
    and     hroutl_ou.organization_id    = p_org_id;

    return l_region;
    /*
    -- Operating unit org_id -> get organization attribute4
    -- compare it to flex_value of Value set XXGL_COMPANY_SEG connect
    -- return Attribute1 (hold the region of the OU).
    select fv.attribute1           region
    into   l_region
    from   hr_organization_units_v org,
           fnd_flex_values_vl      fv,
           fnd_flex_value_sets     fvs
    where  fv.flex_value_set_id    = fvs.flex_value_set_id
    and    fvs.flex_value_set_name like 'XXGL_COMPANY_SEG'
    and    fv.flex_value           = org.attribute4
    and    org.organization_id     = p_org_id
    and    fv.enabled_flag         = 'Y'
    and    trunc(sysdate)          between nvl(fv.start_date_active,sysdate -1)
                                   and nvl(fv.end_date_active,sysdate +1); */
  exception
    when others then
      dbms_output.put_line('ERR '||substr(sqlerrm,1,240)); 
      return null;
  end get_org_region;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_creator_region
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      08/07/2015
  --  Purpose :           get approver name
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   08/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_creator_region (p_user_id in number ) return varchar2 is
    l_region varchar2(240);
  begin
    -- User -> Employee assignment -> default account -> Code combination segment1 ->
    -- compare this segment1 to attribute1 of Value set XXGL_COMPANY_SEG connect
    -- with this segment1 to the flex_value
    -- Attribute1 hold the region of the person.
    select fv.attribute1 region
           /*gcc.segment1 company,
           p.full_name, a.default_code_comb_id,
           fv.description, fv.flex_value, */
    into   l_region
    from   fnd_user                 u,
           per_all_people_f         p,
           per_all_assignments_f    a,
           gl_code_combinations_kfv gcc,
           fnd_flex_values_vl       fv,
           fnd_flex_value_sets      fvs
    where  u.employee_id            = p.person_id
    and    p.person_id              = a.person_id
    and    trunc(sysdate)           between p.effective_start_date and p.effective_end_date
    and    trunc(sysdate)           between a.effective_start_date and a.effective_end_date
    and    gcc.code_combination_id  = a.default_code_comb_id
    and    u.user_id                = p_user_id   -- <SO_Creator>
    and    fv.flex_value_set_id     = fvs.flex_value_set_id
    and    fvs.flex_value_set_name  like 'XXGL_COMPANY_SEG'
    and    fv.flex_value            = gcc.segment1 --to_char(10)
    and    fv.enabled_flag          = 'Y'
    and    trunc(sysdate)           between nvl(fv.start_date_active,sysdate -1)
                                    and nvl(fv.end_date_active,sysdate +1);

    return l_region;
  exception
    when others then
      return null;
  end get_creator_region;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_approver
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      07/07/2015
  --  Purpose :           get approver name
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   07/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_approver(p_doc_instance_id in  number,
                         p_entity          in  varchar2, -- FIRST/LAST
                         x_approver        out varchar2,
                         x_err_code        out number,
                         x_err_msg         out varchar2) is

    l_is_latam          varchar2(5)   := null;
    l_so_header_id      number        := null;
    l_org_id            number        := null;
    l_so_created_by     number        := null;
    l_invoice_to_org_id number        := null;
    l_credit_limit      number        := null;
    l_region            varchar2(240) := null;
    l_approver          varchar2(240) := null;
    l_prog_name         varchar2(30)  := 'get_approver';
  begin
    x_err_code := 0;
    x_err_msg  := null;

    /*l_doc_instance_header.n_attribute1 := p_order_hold_id;
    l_doc_instance_header.n_attribute2 := p_so_header_id;
    l_doc_instance_header.n_attribute3 := p_org_id;
    l_doc_instance_header.n_attribute4 := p_invoice_to_org_id;
    l_doc_instance_header.n_attribute5 := p_hold_id;
    l_doc_instance_header.attribute2   := p_doc_code; -- 'CREDIT_CHECK'
    l_doc_instance_header.attribute1   := p_so_created_by;*/

    -- get So information
    select xwdi.n_attribute2, xwdi.n_attribute3, xwdi.attribute1, xwdi.n_attribute4
    into   l_so_header_id,    l_org_id,          l_so_created_by, l_invoice_to_org_id
    from   xxobjt_wf_doc_instance xwdi
    where  xwdi.doc_instance_id   = p_doc_instance_id;

    fnd_log.string(log_level => fnd_log.level_unexpected,
                   module    => c_debug_module||l_prog_name,
                   message   => 'l_so_header_id - '||l_so_header_id||' l_org_id - '||l_org_id||
                                ' l_so_created_by - '||l_so_created_by||
                                ' l_invoice_to_org_id - '||l_invoice_to_org_id);

    -- check credit limit
    l_credit_limit := get_customer_credit_limit (l_invoice_to_org_id);
    fnd_log.string(log_level => fnd_log.level_unexpected,
                   module    => c_debug_module||l_prog_name,
                   message   => 'l_credit_limit - '||l_credit_limit);

    -- check if LATAM customer
    l_is_latam := xxhz_util.is_LATAM_customer (p_site_use_id => l_invoice_to_org_id,
                                               p_site_id => null,
                                               p_customer_id => null);

    fnd_log.string(log_level => fnd_log.level_unexpected,
                   module    => c_debug_module||l_prog_name,
                   message   => 'l_is_latam - '||l_is_latam);
    if l_is_latam = 'Y' then
      --get approver name
      l_approver := get_approver_by_region (p_limit  => l_credit_limit, -- i n
                                            p_region => 'LATAM',        -- i v
                                            p_entity => p_entity,       -- i v
                                            p_org_id => l_org_id);      -- i n
      x_approver := l_approver;
    else
      -- get approver by SO creator
      -- get region from the so creator employee -> from the default account at the
      -- assignment info of the employee. from this code combination get the segment1
      -- which is the Company ->  with this value go to value set XXGL_COMPANY_SEG
      l_region := get_org_region(l_org_id);
      --get approver name
      l_approver := get_approver_by_region (p_limit  => l_credit_limit, -- i n
                                            p_region => l_region,       -- i v
                                            p_entity => p_entity,       -- i v
                                            p_org_id => l_org_id);      -- i n
      x_approver := l_approver;
    end if; -- is latam

    fnd_log.string(log_level => fnd_log.level_unexpected,
                   module    => c_debug_module||l_prog_name,
                   message   => 'l_approver - '||l_approver);
  exception
    when others then
      x_err_code := 1;
      x_err_msg  := 'ERR - get_approver '||p_entity||' - '||substr(sqlerrm,1,240);
      x_approver := null;
  end get_approver;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_doc_instance_details
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      14/07/2015
  --  Purpose :           will use from FRW SalesOrder if parameter p_doc_instance_id
  --                      sent to the page, need to get the so header id and hold id
  --                      from the doc approval process, else it will work as today.
  --                      this info will help to determine if to show/hide some RN info
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   14/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  procedure get_doc_instance_details (p_doc_instance_id in  number,
                                      p_so_header_id    out varchar2,
                                      --p_hold_id         out number,
                                      p_auto_hold_id    out varchar2,
                                      p_err_code        out varchar2,
                                      p_err_msg         out varchar2) is

    l_so_header_id number;
    l_hold_id      number;
    l_auto_hold_id number;
  begin
    -- get So information
    select xwdi.n_attribute2, xwdi.n_attribute5, xwdi.attribute3
    into   l_so_header_id,    l_hold_id,         l_auto_hold_id
    from   xxobjt_wf_doc_instance xwdi
    where  xwdi.doc_instance_id   = p_doc_instance_id;

    p_so_header_id := l_so_header_id;
    --p_hold_id      := l_hold_id;
    p_auto_hold_id := l_auto_hold_id;
    p_err_code     := 0;
    p_err_msg      := null;

  exception
    when others then
      p_err_code := 1;
      p_err_msg  := 'ERR - XXOM_CREDIT_HOLD_UTIL_PKG_PKG.get_doc_instance_details: '||substr(sqlerrm,1,240);
  end get_doc_instance_details;

end XXOM_CREDIT_HOLD_UTIL_PKG;
/
