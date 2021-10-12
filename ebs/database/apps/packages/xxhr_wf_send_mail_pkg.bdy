CREATE OR REPLACE PACKAGE BODY xxhr_wf_send_mail_pkg IS

--------------------------------------------------------------------
--  name:            XXHR_WF_SEND_MAIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.12
--  creation date:   27/01/2011 09:14:43
--------------------------------------------------------------------
--  purpose :        HR project - Handle all WF send mail, HTML body
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  27/01/2011  Dalit A. Raviv    initial build
--  1.1  23/10/2011  Dalit A. Raviv    add procedure prepare_salary_clob_body
--  1.2  27/10/2011  Dalit A. Raviv    add procedure prepare_mng_emps_birthday_body
--  1.3  22/12/2011  Dalit A. Raviv    correct select of prepare_AD_clob_body
--                                     substr of positions
--  1.4  19/01/2012  Dalit A. Raviv    HR department requested not to show employee
--                                     position(Title) at AD.
--                                     therfor i need to take position from the program
--                                     procedures - prepare_AD_clob_body
--  1.5  16/02/2012  Dalit A. Raviv    add procedure - prepare_position_changed_body
--                                     CUST482 Employee Position Changed - notify Oracle_Operations
--  1.6  05/03/2012  Dalit A. Raviv    procedure - prepare_mng_emps_birthday_body
--                                     Gift message will be add only for managers
--                                     from territory Objet IL (l_msg2)
--  1.7  19/11/2012  yuval tal         modify prepare_position_changed_body
--                                     add proc  prepare_position_chg_opr_body
--  1.8  30/12/2012  Dalit A. Raviv    Procedure prepare_ad_clob_body
--                                               Organization heirarchy changes - changes in names -> Objet to Stratasys
--                                               change location_code 'Objet Israel - Rehovot%' to 'Stratasys Israel - Rehovot%'
--                                     procedure prepare_mng_emps_birthday_body - send mail to direct manager only
--  1.9  20/02/2013  Dalit A. Raviv    procedure prepare_mng_emps_birthday_body -
--                                     Correct select for Territory - handle relocation and rehire
--                                     Correct instead of sysdate send the date to the body as part of the parameter
--  1.10 03/03/2013  Dalit A. Raviv    Add DBMS_LOB.createtemporary(p_document,TRUE); to all procedures
--                                     it help to run mail body from DB.
--  1.11 26/06/2013  Dalit A. Raviv    procedure prepare_ad_clob_body handle JP position.
--  1.12 09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
--  1.13 20/08/2014  Dalit A. Raviv    add procedure prepare_Interface_body CHG0032233
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            prepare_Interface_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/08/2014
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --                   CHG0032233 - Upload HR data into Oracle 
  --  In  Params:      p_document_id   - l_count_e||'|'||l_count_s||'|'||l_total
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/08/2014  Dalit A. Raviv    initial build 
  --                                     CHG0032233 - Upload HR data into Oracle  
  --------------------------------------------------------------------     
  procedure prepare_Interface_body (p_document_id   in varchar2,
                                    p_display_type  in varchar2,
                                    p_document      in out clob,
                                    p_document_type in out varchar2) is
    l_count_e  varchar2(100);
    l_count_s  varchar2(100);
    l_total    varchar2(100);
    l_temp_str varchar2(500);
  begin
    
    l_temp_str := p_document_id; -- l_count_e||'|'||l_count_s||'|'||l_total
    
    l_count_e  := substr(l_temp_str,1,instr(l_temp_str,'|') -1);
    l_temp_str := substr(l_temp_str,instr(l_temp_str,'|') +1); 
    l_count_s  := substr(l_temp_str,1,instr(l_temp_str,'|') -1);
    l_total    := substr(l_temp_str,instr(l_temp_str,'|') +1); 
    
    dbms_lob.createtemporary(p_document,true);

    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P>Summary Results of, HR Interface process </P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' || 
                    '<TH> Total Records   </TH>' ||
                    '<TH> Success Records </TH>' ||
                    '<TH> Error Records   </TH>' ||
                    '</TR>');
    -- concatenate table values by loop
    -- Put value to HTML table
    dbms_lob.append(p_document,
                    '<TR>' ||
                      '<TD>' || l_total   ||'</TD>' ||
                      '<TD>' || l_count_s ||'</TD>' ||
                      '<TD>' || l_count_e ||'</TD>' ||
                    '</TD>' || '</TR>');

    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    dbms_lob.append(p_document, '<P>Regards,</P>' || '<P>Oracle HR Sysadmin</P></FONT>' || '</BODY></HTML>');

    --set_debug_context('xx_notif_attach_procedure');
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_Interface_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_Interface_body;

  --------------------------------------------------------------------
  --  name:            prepare_salary_clob_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   27/01/2011
  --------------------------------------------------------------------
  --  purpose:         procedure taht prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - batch_id of log_interface table
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/01/2011  Dalit A. Raviv    initial build
  --  1.1  03/03/2013  Dalit A. Raviv    add DBMS_LOB.createtemporary(p_document,TRUE);
  --------------------------------------------------------------------
  procedure prepare_salary_clob_body(p_document_id   in varchar2,
                                     p_display_type  in varchar2,
                                     p_document      in out clob,
                                     p_document_type in out varchar2) is

    cursor log_pop_c is
      select *
      from   xxhr_element_log_interface log_int
      where  log_int.batch_id = p_document_id
      order by log_int.status, log_int.log_code;

    l_full_name varchar2(360) := null;
    l_person_id number        := null;
  begin
    dbms_lob.createtemporary(p_document,true);

    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P>Summary Results of, Import process of Salary and Benefits from Har-gal to Oracle </P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' || '<TH> Emp Num    </TH>' ||
                    '<TH> Emp Name   </TH>' || '<TH> Status     </TH>' ||
                    '<TH> Code       </TH>' || '<TH> Message    </TH>' ||
                    '<TH> Ele code   </TH>' || '<TH> Ele name   </TH>' ||
                    '</TR>');
    -- concatenate table values by loop
    for log_pop_r in log_pop_c loop
      -- get person_id by employee number
      l_person_id := xxhr_util_pkg.get_person_id_by_en(p_emp_number     => log_pop_r.employee_number,
                                                       p_effective_date => trunc(SYSDATE),
                                                       p_bg_id          => 0);
      -- Get employee full name
      l_full_name := xxhr_util_pkg.get_person_full_name(p_person_id      => l_person_id,
                                                        p_effective_date => trunc(SYSDATE),
                                                        p_bg_id          => 0);
      -- Put value to HTML table
      dbms_lob.append(p_document,
                      '<TR>' ||
                        '<TD>' || log_pop_r.employee_number ||'</TD>' ||
                        '<TD>' || nvl(l_full_name, '&nbsp') ||'</TD>' ||
                        '<TD>' || log_pop_r.status || '</TD>' ||
                        '<TD>' || log_pop_r.log_code || '</TD>' ||
                        '<TD>' || log_pop_r.log_message || chr(10) || '</TD>' ||
                        '<TD>' || nvl(log_pop_r.element_code, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(log_pop_r.element_name, '&nbsp') ||
                      '</TD>' || '</TR>');

    END LOOP;
    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    dbms_lob.append(p_document, '<P>Regards,</P>' || '<P>Oracle HR Sysadmin</P></FONT>' || '</BODY></HTML>');

    --set_debug_context('xx_notif_attach_procedure');
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_salary_clob_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_salary_clob_body;

  --------------------------------------------------------------------
  --  name:            prepare_AD_clob_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.5
  --  creation date:   23/10/2011
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - process_mode = 'PREMAIL'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  --  1.1  19/01/2012  Dalit A. Raviv    HR department requested not to show employee
  --                                     position(Title) at AD.
  --                                     therfor i need to take position from the program
  --  1.2  30/12/2012  Dalit A. Raviv    Organization heirarchy changes - changes in names -> Objet to Stratasys
  --                                     change location_code 'Objet Israel - Rehovot%' to 'Stratasys Israel - Rehovot%'
  --  1.3  03/03/2013  Dalit A. Raviv    add DBMS_LOB.createtemporary(p_document,TRUE);
  --  1.4  26/06/2013  Dalit A. Raviv    Handle JP position.
  --  1.5  09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
  --------------------------------------------------------------------
  procedure prepare_ad_clob_body(p_document_id   in varchar2,
                                 p_display_type  in varchar2,
                                 p_document      in out clob,
                                 p_document_type in out varchar2) is

    cursor diff_pop_c is
      select diff.log_msg message,
             papf.full_name full_name,
             nvl(papf.employee_number, papf.npw_number) emp_num,
             diff.user_person_type person_type,
             diff.mobile_number mobile,
             decode(diff.location_id, null, null, xxhr_util_pkg.get_company_name(diff.location_id)) company,
             decode(diff.location_id, null, null, loc.address_line_1 || decode(loc.address_line_2, null, null, ' , ' || loc.address_line_2)) address,
             decode(diff.location_id, null, null, loc.town_or_city) city,
             decode(diff.location_id, null, null, loc.postal_code) zip_code,
             decode(diff.location_id, null, null,
                    trim(decode(loc.region_2, null, null, xxhr_person_extra_info_pkg.get_lookup_code_meaning('US_STATE', loc.region_2)) ||
                         decode(loc.country,null, null, ' ' || territory_short_name))) country_region,
             case
               when diff.location_id is null then
                 null
               when loc.location_code like 'Stratasys Israel - Rehovot%' then
                 'Stratasys Israel - Rehovot'
               when loc.location_code like 'Stratasys Asia Pacific - %JP' then
                 'Stratasys Asia Pacific - JP'
               else
                 loc.location_code
             end office,
             case
               when diff.organization_id is null then
                 null
               else
                 xxhr_util_pkg.get_org_name(diff.organization_id, 0)
             end department,
             diff.organization_name, -- Dalit A. Raviv 09/02/2014
             case
               when diff.organization_id is null then
                 null
               when hr_general.decode_organization(diff.organization_id) = 'Stratasys'
                 and xxhr_util_pkg.get_organization_by_hierarchy(diff.organization_id, 'DIV', 'NAME') = 'Lower type' then
                 'Stratasys HQ'
               when xxhr_util_pkg.get_organization_by_hierarchy(diff.organization_id,  'DIV', 'NAME') =  'Lower type' then
                 null
               else
                 xxhr_util_pkg.get_organization_by_hierarchy(diff.organization_id, 'DIV',  'NAME')
             end division,
             decode(papf1.full_name, NULL, NULL, papf1.full_name) supervisor,
             diff.office_phone_extension,
             diff.office_phone_full,
             diff.office_fax
      from   xxhr_diff_persons_interface diff,
             hr_locations_v              loc,
             fnd_territories_vl          ter,
             per_all_people_f            papf,
             per_all_people_f            papf1 -- for supervisor
      where  diff.process_mode           = p_document_id --'inprocess','premail'
      and    loc.location_id(+)          = diff.location_id
      and    loc.country                 = ter.territory_code(+)
      and    ter.obsolete_flag(+)        <> 'Y'
      and    papf1.person_id(+)          = diff.supervisor_id
      and    trunc(sysdate)              between papf1.effective_start_date(+) and papf1.effective_end_date(+)
      and    papf.person_id              = diff.person_id
      and    trunc(sysdate)              between papf.effective_start_date and papf.effective_end_date
      --and    diff.position_id          = pos.position_id(+)
      order by diff.status;

    l_msg3 varchar2(2000) := null;
    l_department varchar2(150) := null;
  begin

    DBMS_LOB.createtemporary(p_document,TRUE);

    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P> Following is a list of Persons to update at Active directory</P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' || '<TH> Message           </TH>' ||
                     '<TH> Full Name         </TH>' ||
                     '<TH> Emp num           </TH>' ||
                    --'<TH> Person type       </TH>'||
                     '<TH> Mobile            </TH>' ||
                     '<TH> Company           </TH>' ||
                     '<TH> Address           </TH>' ||
                     '<TH> City              </TH>' ||
                     '<TH> Zip Code          </TH>' ||
                     '<TH> Country Region    </TH>' ||
                     '<TH> Office            </TH>' ||
                     '<TH> Department        </TH>' ||
                     '<TH> Division          </TH>' ||
                    --'<TH> Title             </TH>'|| -- 1.1  19/01/2012  Dalit A. Raviv
                     '<TH> Supervisor        </TH>' ||
                     '<TH> Office Phone ext  </TH>' ||
                     '<TH> Office phone full </TH>' ||
                     '<TH> Office fax        </TH>' || '</TR>');

    -- concatenate table values by loop
    for diff_pop_r in diff_pop_c loop

      -- Put value to HTML table
      if nvl(diff_pop_r.organization_name,'DAR') <> nvl(diff_pop_r.department,'DAR') then

        l_department := diff_pop_r.organization_name;
      else
        l_department := diff_pop_r.department;
      end if;
      dbms_lob.append(p_document,
                      '<TR>' ||
                        '<TD>' || diff_pop_r.message || '</TD>' ||
                        '<TD>' || diff_pop_r.full_name || '</TD>' ||
                        '<TD>' || diff_pop_r.emp_num || '</TD>' ||
                        --'<TD>'||nvl(diff_pop_r.person_type,'&nbsp')||'</TD>'||
                        '<TD>' || nvl(diff_pop_r.mobile, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.company, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.address, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.city, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.zip_code, '&nbsp') ||'</TD>' ||
                        '<TD>' || nvl(diff_pop_r.country_region, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.office, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(l_department, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.division, '&nbsp') || '</TD>' ||
                        --'<TD>'||nvl(diff_pop_r.title,'&nbsp')||'</TD>'|| -- 1.1  19/01/2012  Dalit A. Raviv
                        '<TD>' || nvl(diff_pop_r.supervisor, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.office_phone_extension, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.office_phone_full, '&nbsp') || '</TD>' ||
                        '<TD>' || nvl(diff_pop_r.office_fax, '&nbsp') || '</TD>' ||
                      '</TR>');
    end loop;
    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    /*dbms_lob.append(p_document,'<P>Regards,</P>'||
    '<P>Objet Human Resource </P></FONT>'||
    '</BODY></HTML>');*/

    fnd_message.set_name('XXOBJT', 'XXHR_MNG_MAIL_FOOTER');
    l_msg3 := fnd_message.get;
    dbms_lob.append(p_document, l_msg3);

    --set_debug_context('xx_notif_attach_procedure');
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_AD_clob_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_ad_clob_body;

  --------------------------------------------------------------------
  --  name:            prepare_mng_emps_birthday_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.4
  --  creation date:   27/10/2011
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - manager id
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  --  1.1  05/03/2012  Dalit A. Raviv    Gift message will be add only for managers
  --                                     from territory Objet IL (l_msg2).
  --  1.2  30/12/2012  Dalit A. Raviv    send mail to direct manager only
  --  1.3  20/02/2013  Dalit A. Raviv    Correct select for Territory - handle relocation
  --                                     Correct instead of sysdate send the date to the body as part of the parameter
  --  1.4  03/03/2013  Dalit A. Raviv    add DBMS_LOB.createtemporary(p_document,TRUE);
  --------------------------------------------------------------------
  procedure prepare_mng_emps_birthday_body(p_document_id   in varchar2,
                                           p_display_type  in varchar2,
                                           p_document      in out clob,
                                           p_document_type in out varchar2) is

    -- get manager all employess
    -- 1.3  20/02/2013  dalit a. raviv
    cursor get_employees_c(p_supervisor_id in number, p_date in varchar2) is
      select distinct papf.full_name mng,
                      paa1.supervisor_id,
                      paa1.person_id,
                      papf1.full_name emp,
                      to_char(papf1.date_of_birth, 'MON-DD') birthday,
                      level
      from   (select *
              from   per_all_people_f papf2
              where  trunc(sysdate) between papf2.effective_start_date and
                     papf2.effective_end_date) papf,
             (select *
              from   per_all_assignments_f paa2
              where  trunc(sysdate) between paa2.effective_start_date and paa2.effective_end_date) paa1,
             (select *
              from   per_all_people_f papf3
              where  trunc(sysdate) between papf3.effective_start_date and papf3.effective_end_date) papf1
      where  paa1.supervisor_id                    = papf.person_id
      and    paa1.person_id                        = papf1.person_id
      and    paa1.primary_flag                     = 'Y'
      and    paa1.assignment_type                  in ('E', 'C')
      and    level                                 = 1
      and    to_char(papf1.date_of_birth, 'MM-DD') = p_date --to_char(trunc(SYSDATE + 1), 'MM-DD')  -- 1.3 21/02/2013 Dalit A. Raviv
      and    hr_person_type_usage_info.get_user_person_type(trunc(sysdate), paa1.person_id) not like   'Ex%'
      start  with paa1.supervisor_id               = p_supervisor_id
      connect by prior paa1.person_id              = paa1.supervisor_id
             and paa1.primary_flag                 = 'Y'
             and paa1.assignment_type              in ('E', 'C')
             and papf.business_group_id            = 0
             and paa1.business_group_id            = 0
             and papf1.business_group_id           = 0
             and hr_person_type_usage_info.get_user_person_type(trunc(sysdate),  paa1.person_id) not like  'Ex%';

    l_msg1      varchar2(2000) := null;
    l_msg2      varchar2(2000) := null;
    l_msg3      varchar2(2000) := null;
    l_territory varchar2(200)  := null;
    l_mng_id    number         := null;
    l_date      varchar2(50)   := null;

  begin
    DBMS_LOB.createtemporary(p_document,TRUE);

    -- 1.3 21/02/2013 Dalit A. Raviv
    l_mng_id := substr(p_document_id, 1,instr(p_document_id,'|')-1);
    l_date   := substr(p_document_id, instr(p_document_id,'|')+1);
    -- end 1.3
    -- Following is a list of your employees, tomorrow BIRTHDAY
    fnd_message.set_name('XXOBJT', 'XXHR_MNG_SEND_MAIL_MSG1');
    l_msg1 := fnd_message.get;
    -- Please contact HR Admin to collect the gifts
    fnd_message.set_name('XXOBJT', 'XXHR_MNG_SEND_MAIL_MSG2');
    l_msg2 := fnd_message.get;

    -- 1.1  05/03/2012  Dalit A. Raviv
    select xxhr_util_pkg.get_organization_by_hierarchy(paa.organization_id, 'TER',  'NAME')
    into   l_territory
    from   per_all_assignments_f paa
    where  person_id             = l_mng_id --p_document_id 1.3  20/02/2013  dalit a. raviv
    and    trunc(sysdate)        between paa.effective_start_date and paa.effective_end_date
    --  1.3  20/02/2013  Dalit A. Raviv   handle person with more then 1 service employment (like relocation, rehire)
    and    paa.primary_flag      = 'Y'
    and    paa.assignment_type   in ('E', 'C');

    IF l_territory = 'Corp IL' THEN
      -- concatenate start message
      dbms_lob.append(p_document,
                      '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                      '<P> </P>' || '<P> ' || l_msg1 || '</P>' ||
                      '<P> </P>' || '<P> ' || l_msg2 || ' </P>' ||
                      '<P> </P>');
    else
      dbms_lob.append(p_document,
                      '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                      '<P> </P>' || '<P> ' || l_msg1 || '</P>' ||
                      '<P> </P>');
    end if;
    -- end 1.1  05/03/2012

    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue; font size=14" border=1 cellpadding=8>');

    --style="color:blue;text-align:center;font size=20"
    dbms_lob.append(p_document,
                    '<TR align="left">' ||
                      '<TH>Full Name      </TH>' ||
                      '<TH>Date Of Birth  </TH>' ||
                      '<TH>Level          </TH>' ||
                    '</TR>');

    -- concatenate table values by loop
    for get_employees_r in get_employees_c(/*p_document_id*/l_mng_id, l_date) loop

      -- Put value to HTML table
      dbms_lob.append(p_document,
                      '<TR>' || '<TD>' || get_employees_r.emp || '</TD>' ||
                      '<TD>' || get_employees_r.birthday || '</TD>' ||
                      '<TD>' || get_employees_r.level || '</TD>' || '</TR>');
    end loop;
    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    dbms_lob.append(p_document, '<P> </P>' || '&nbsp' || '<P> </P>');

    -- concatenate close tags
    fnd_message.set_name('XXOBJT', 'XXHR_MNG_MAIL_FOOTER');
    l_msg3 := fnd_message.get;
    dbms_lob.append(p_document, l_msg3);
    /*
    dbms_lob.append(p_document,'<P> Regards,</P>'||
                               '<P> Objet Human Resource </P></FONT>'||
                               '</BODY></HTML>');
    */
    --set_debug_context('xx_notif_attach_procedure');
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_mng_emps_birthday_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_mng_emps_birthday_body;

  --------------------------------------------------------------------
  --  name:            prepare_position_changed_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.2
  --  creation date:   16/02/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - send mail code 'P'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --  1.1  19.11.2012  yuval tal         remove condition in  prepare_position_changed_body :
  --                                     and xxhr_util_pkg.get_organization_by_hierarchy (paaf.organization_id,'DIV','NAME') = 'Operation Division IL';
  --  1.2  03/03/2013  Dalit A. Raviv    add DBMS_LOB.createtemporary(p_document,TRUE);
  --------------------------------------------------------------------
  procedure prepare_position_changed_body(p_document_id   in varchar2,
                                          p_display_type  in varchar2,
                                          p_document      in out clob,
                                          p_document_type in out varchar2) is

    cursor get_pos_pop_c is
      select papf.person_id,
             papf.full_name,
             nvl(papf.employee_number, papf.npw_number) emp_num,
             xxhr_util_pkg.get_position_name(papf.person_id,
                                             trunc(sysdate),
                                             0) new_position,
             xxhr_util_pkg.get_organization_by_hierarchy(paaf.organization_id,
                                                         'DIV',
                                                         'NAME') division,
             pos_int.log_msg
      from   xxhr_emp_change_position_int pos_int,
             per_all_people_f             papf,
             per_all_assignments_f        paaf
      where  1 = 1
      and    pos_int.person_id            = papf.person_id
      and    trunc(sysdate)               between papf.effective_start_date and papf.effective_end_date
      and    paaf.person_id               = papf.person_id
      and    trunc(sysdate)               between paaf.effective_start_date and paaf.effective_end_date
      and    pos_int.send_mail            = 'P';
    -- and    xxhr_util_pkg.get_organization_by_hierarchy (paaf.organization_id,'DIV','NAME') = 'Operation Division IL';
  begin
    DBMS_LOB.createtemporary(p_document,TRUE);
    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P> Following is a list of Persons that changed position</P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' ||
                    '<TH> Full Name         </TH>' ||
                    '<TH> Emp num           </TH>' ||
                    '<TH> New Position      </TH>' ||
                    '<TH> Division          </TH>' ||
                    '<TH> Log Message       </TH>' || '</TR>');

    -- concatenate table values by loop
    for get_pos_pop_r in get_pos_pop_c loop

      -- Put value to HTML table
      dbms_lob.append(p_document,
                      '<TR>'  || '<TD>' || get_pos_pop_r.full_name ||
                      '</TD>' || '<TD>' || get_pos_pop_r.emp_num || '</TD>' ||
                      '<TD>'  || nvl(get_pos_pop_r.new_position, '&nbsp') ||
                      '</TD>' || '<TD>' || get_pos_pop_r.division ||
                      '</TD>' || '<TD>' ||
                      nvl(REPLACE(get_pos_pop_r.log_msg, chr(10), '<BR>'), '&nbsp') || '</TD>' || '</TR>');
    end loop;
    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    dbms_lob.append(p_document, '<P>Regards,</P>' || '<P>Oracle HR Sysadmin</P></FONT>' || '</BODY></HTML>');

    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_AD_clob_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_position_changed_body;

  --
  --------------------------------------------------------------------
  --  name:            prepare_position_chg_opr_body
  --  create by:       yuval tal
  --  Revision:        1.1
  --  creation date:   20.11.2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --                   CUST482 CR-518 Employee Position Changed -Add old position/ supervisor position  Hierarchy  locations
  --  In  Params:      p_document_id   - send mail code 'P'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19.11.2012  yuval tal         initial build
  --                                     CUST482 CR-518 Employee Position Changed -Add old position/ supervisor position  Hierarchy  locations
  --  1.1  03/03/2013  Dalit A. Raviv    add DBMS_LOB.createtemporary(p_document,TRUE);
  --------------------------------------------------------------------
  procedure prepare_position_chg_opr_body(p_document_id   in varchar2,
                                          p_display_type  in varchar2,
                                          p_document      in out clob,
                                          p_document_type in out varchar2) is

    cursor get_pos_pop_c is
      select papf.person_id,
             papf.full_name,
             nvl(papf.employee_number, papf.npw_number) emp_num,
             xxhr_util_pkg.get_position_name(papf.person_id, trunc(sysdate), 0) new_position,
             xxhr_util_pkg.get_organization_by_hierarchy(paaf.organization_id, 'DIV', 'NAME') division,
             -- pos_int.log_msg,
             pos_int.position_info
      from   xxhr_emp_change_position_int pos_int,
             per_all_people_f             papf,
             per_all_assignments_f        paaf
      where  1 = 1
      and    pos_int.person_id            = papf.person_id
      and    trunc(sysdate)               between papf.effective_start_date and papf.effective_end_date
      and    paaf.person_id               = papf.person_id
      and    trunc(sysdate)               between paaf.effective_start_date and paaf.effective_end_date
      and    pos_int.send_mail            = 'P'
      and    pos_int.position_info        is not null;
    -- and    xxhr_util_pkg.get_organization_by_hierarchy (paaf.organization_id,'DIV','NAME') = 'Operation Division IL';
  begin
    DBMS_LOB.createtemporary(p_document,TRUE);

    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P>Hello,</P>' || '<P> </P>' ||
                    '<P> Following is a list of Persons that changed position</P>');
    -- concatenate table prompts
    dbms_lob.append(p_document,
                    '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
    dbms_lob.append(p_document,
                    '<TR align="left">' || '<TH> Full Name         </TH>' ||
                    '<TH> Emp num           </TH>' ||
                    '<TH> New Position      </TH>' ||
                    '<TH> Division          </TH>' ||
                    '<TH> Log Message       </TH>' || '</TR>');

    -- concatenate table values by loop
    for get_pos_pop_r in get_pos_pop_c loop

      -- Put value to HTML table
      dbms_lob.append(p_document,
                      '<TR>'  || '<TD>' || get_pos_pop_r.full_name ||
                      '</TD>' || '<TD>' || get_pos_pop_r.emp_num   || '</TD>' ||
                      '<TD>'  || nvl(get_pos_pop_r.new_position, '&nbsp') ||
                      '</TD>' || '<TD>' || get_pos_pop_r.division  ||
                      '</TD>' || '<TD>' ||
                      nvl(REPLACE(get_pos_pop_r.position_info, chr(10), '<BR>'), '&nbsp') || '</TD>' || '</TR>');
    end loop;
    -- concatenate close table
    dbms_lob.append(p_document, '</TABLE> </div>');
    -- concatenate close tags
    dbms_lob.append(p_document, '<P>Regards,</P>' || '<P>Oracle HR Sysadmin</P></FONT>' || '</BODY></HTML>');

    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.context('XXHR_WF_SEND_MAIL_PKG',
                      'XXHR_WF_SEND_MAIL_PKG.prepare_AD_clob_body',
                      p_document_id,
                      p_display_type);
      raise;
  end prepare_position_chg_opr_body;

end xxhr_wf_send_mail_pkg;
/
