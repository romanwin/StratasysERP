CREATE OR REPLACE PACKAGE BODY xxcsf_alerts_pub AS
/*$Header: csfAlertb.pls 120.0.12000000.6 2007/11/16 06:48:42 htank noship $*/

--------------------------------------------------------------------
--  customization code: CUST457 - CSF Task Assignment WF modification
--  name:               XXcsf_alerts_pub
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      21/09/2011
--  Purpose :           This package call from WF Field Service Task Assignment Alerts
--                      original WF call csf_alerts_pub package.
--                      to be able to modify WF to our needs there was a need to change
--                      and copy oracle package (csf_alerts_pub).
--
--                      NOTE:
--                      When patch install need to modify this package if there was changes
--                      at csf_alerts_pub package.
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   21/09/2011    Dalit A. Raviv  initial build
--  1.1   03/11/2011    Dalit A. Raviv  correct source of varibale according to
--                                      oracle patch 120.0.12000000.8
--  1.2   07/12/2011    Dalit A. Raviv  procedure getContactDetail add ext to phone number
--  1.3   15/12/2011    Dalit A. Raviv  Procedure GetTaskDetails need to correct cursor c_task_assgn_detail
--                                      1. The address that is presented is the Customer identifying
--                                         address from HZ parties table and not the incident address
--                                         from SR. This is wrong and should be fixed to the
--                                         correct address that is Incident address from SR.
--                                      2. Add State and Country to the address.
--  1.4   13/02/2012    Dalit A. Raviv  1. correct customer name -> today show party_rel name and
--                                         not the party itself .
--                                         correct select at getTaskDetails function
--                                      2. add new function getSubject - handle message subject str
-----------------------------------------------------------------------

  -- This function will do basic filteration as per the bussiness conditions
  -- also based on the event type it will call another function
  -- Main entry point for the CSF wireless alerts
  -- What to check?
  -- 1. Assignment should have task attached to it with Schedule Start/End date
  -- 2. Schedule start date should be greater than sysdate
  -- 3. Task should be a type of 'Dispatch' and schedulable flag = 'Y' (only for FS tasks)
  -- 4. Check for Task priority (check against profile value)
  -- 5. Task assignment status should be of 'CSF: Default Assigned task status' profile value
  --    at the application level
  function getUserId (p_resource_id number,
                      p_resource_type varchar2) return number is
    l_user_id number;
    cursor c_user_id (v_resource_id number, v_category varchar2) is
      select user_id from jtf_rs_resource_extns where resource_id = v_resource_id and category = v_category;
  begin
    l_user_id := 0;

    open c_user_id (p_resource_id, category_type(p_resource_type));
    fetch c_user_id into l_user_id;
    close c_user_id;
    return l_user_id;
  end;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               category_type
  --  create by:          Oracle
  --  $Revision:          1.0
  --  creation date:      xx/xx/xxxx
  --  Purpose :           Copy from Oracle code
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  function category_type ( p_rs_category varchar2 ) return varchar2 is
  begin
    if p_rs_category = 'RS_EMPLOYEE' then
      return 'EMPLOYEE';
    elsif p_rs_category = 'RS_PARTNER' then
      return 'PARTNER';
    elsif p_rs_category = 'RS_SUPPLIER_CONTACT' then
      return 'SUPPLIER_CONTACT';
    elsif p_rs_category = 'RS_PARTY' then
      return 'PARTY';
    elsif p_rs_category = 'RS_OTHER' then
      return 'OTHER';
    else
      return null;
    end if;
  end;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getAssignedMessage
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      21/09/2011
  --  Purpose :           1) need to remove some message fields
  --                      2) need to add some message information
  --                      3) add fields to note part(cursor and at program)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  procedure getAssignedMessage(document_id varchar2,
                              display_type varchar2,
                              document in out nocopy varchar2,
                              document_type in out nocopy varchar2) is
    l_resource_id number;
    l_resource_type varchar2(100);
    l_task_asgn_id number;
    l_message varchar2(32000);
    l_task_detail task_asgn_record;
    l_message_header varchar2(1000);

    l_tmp_user_id number;
    l_tmp_resp_id number;
    l_tmp_resp_apps_id number;
    p_user_id number;

    -- notes
    l_is_notes varchar2(1);
    l_notes varchar2(30000);
    -- 1.0 21/09/2011 Dalit A. Raviv
    l_note_createed_on varchar2(30);
    l_note_created_by  varchar2(150);
    l_attachment       varchar2(32000);
    -- 1.0 21/09/2011 Dalit A. Raviv
    cursor c_notes (v_task_asgn_id in number) is
      select ln.notes,
             to_char(ln.creation_date, 'DD-MON-YYYY HH24:MI:SS') ||'(GMT +2)' creation_date,
             ln.user_name
      from   jtf_task_assignments         jtaa,
             jtf_tasks_b                  jtb,
             cs_incidents_all_b           ciab,
             xxcs_sr_all_related_notes_v  ln
      where  jtaa.resource_type_code      = 'RS_EMPLOYEE'
      and    jtaa.task_id                 = jtb.task_id
      and    jtb.source_object_id         = ciab.incident_id
      and    ciab.incident_id             = ln.incident_id
      and    jtaa.task_assignment_id      = v_task_asgn_id; -- 5985003 -- parameter
    -- Dalit A. Raviv 03/10/2011
    -- get attachments for SR item from IB
    Cursor c_attachments (v_task_asgn_id in number) is
      select fdst.short_text
      from   fnd_documents              fd,
             fnd_attached_documents     fad,
             fnd_documents_tl           fdt,
             fnd_document_categories_tl fdct,
             fnd_documents_short_text   fdst,
             cs_incidents_all_b         ciab,
             jtf_task_assignments       jtaa,
             jtf_tasks_b                jtb
      WHERE  fad.entity_name            like 'XX_ITEM_INSTANCE'
      and    fdct.user_name             = 'Customer Notes for SR'
      and    fdct.language              = fdt.language
      and    fdt.language               = 'US'
      and    fad.document_id            = fd.document_id
      and    fd.document_id             = fdt.document_id
      and    fd.category_id             = fdct.category_id
      and    fd.category_id             in (select fdct.category_id from fnd_document_categories_tl fdct)
      and    fd.media_id                = fdst.media_id
      and    ciab.customer_product_id   = fad.pk1_value
      and    ciab.incident_id           = jtb.source_object_id
      and    jtb.task_id                = jtaa.task_id
      and    jtaa.task_assignment_id    = v_task_asgn_id; --8052003;

    /*
    cursor c_notes (v_task_asgn_id number) is
      select  n.notes
      from    jtf_notes_vl         n,
              jtf_task_assignments a
      where   n.source_object_code = 'TASK'
        and   n.source_object_id   = a.task_id
        and   a.task_assignment_id = v_task_asgn_id
      union
      select  n.notes
      from    jtf_notes_vl         n,
              jtf_task_assignments a,
              jtf_tasks_b          t
      where   n.source_object_code = 'SR'
        and   n.source_object_id   = t.source_object_id
        and   t.task_id            = a.task_id
        and   a.task_assignment_id = v_task_asgn_id;
     */
     -- end 1.0 21/09/2011
  begin

    l_resource_id := to_number(substr(document_id, 1, instr(document_id, '-', 1, 1) - 1));
    l_resource_type := substr(document_id, instr(document_id, '-', 1, 1) + 1, instr(document_id, '-', 1, 2) - instr(document_id, '-', 1, 1) - 1);
    l_task_asgn_id := to_number(substr(document_id, instr(document_id, '-', 1, 2) + 1));

    p_user_id := getUserId(l_resource_id, l_resource_type);

    if p_user_id is null then
      p_user_id := 0;
    end if;

    -- call API
    l_tmp_user_id      := fnd_global.USER_ID;
    l_tmp_resp_id      := fnd_global.RESP_ID;
    l_tmp_resp_apps_id := fnd_global.RESP_APPL_ID;

    fnd_global.APPS_INITIALIZE(user_id => p_user_id, resp_id => 21685, resp_appl_id => 513);

    l_task_detail := getTaskDetails(null, l_task_asgn_id, null);

    -- A new task assignment has been created for you. Please check the details
    -- below and take necessary action before the due date mentioned in the email.
    fnd_message.set_name('CSF', 'CSF_ALERTS_ASSIGNED_HDR');
    l_message_header := fnd_message.get;

    if display_type = 'text/html' then

      -- dalit A. Raviv 03/10/2011
      l_attachment := null;
      for r_attachments in c_attachments (l_task_asgn_id) loop
        if l_attachment is null then
          l_attachment := r_attachments.short_text;
        else
          l_attachment := l_attachment||chr(10)||r_attachments.short_text;
        end if;
      end loop;
      if l_attachment is not null then
        l_attachment := substr(l_attachment,1,6000);
      end if;
      -- end
      l_message := '<P>';
      l_message := l_message || l_message_header || '</P>';
      -- Task Details
      l_message := l_message || '<P><B>' || getPrompt('CSF_ALERTS_TASK_DETAILS') || ':</B></P>';
      l_message := l_message || '<P>';
      l_message := l_message || '<TABLE cellSpacing=0 cellPadding=4 border=1>';
      -- Task
      l_message := l_message || '<TR>';
      l_message := l_message || '<TD><B>'|| getPrompt('CSF_ALERTS_TASK') || '</B></TD>';
      l_message := l_message || '<TD>'   || l_task_detail.task_number || ' ' || l_task_detail.task_name || '</TD>';
      l_message := l_message || '</TR>';
      -- Task Type
      -- 1.0 21/09/2011 Dalit A. Raviv
      l_message := l_message || '<TR>';
      l_message := l_message || '<TD><B>' || getPrompt('XXCSF_ALERTS_TASK_TYPE') || '</B></TD>';
      l_message := l_message || '<TD>' || l_task_detail.task_type || '</TD>';
      l_message := l_message || '</TR>';
      -- Schedule Start
      l_message := l_message || '<TR>';
      l_message := l_message || '<TD><B>'|| getPrompt('CSF_ALERTS_SCHEDULE_START') || '</B></TD>';
      l_message := l_message || '<TD>'   || to_char(getClientTime(l_task_detail.sch_st_date,
                                            getUserId(l_resource_id, l_resource_type)),'DD-MON-YYYY HH24:MI')||'</TD>';
      l_message := l_message || '</TR>';
      -- Schedule End
      l_message := l_message || '<TR>';
      l_message := l_message || '<TD><B>'|| getPrompt('CSF_ALERTS_SCHEDULE_END') || '</B></TD>';
      l_message := l_message || '<TD>'   || to_char(getClientTime(l_task_detail.sch_end_date,
                                            getUserId(l_resource_id, l_resource_type)), 'DD-MON-YYYY HH24:MI')||'</TD>';
      l_message := l_message || '</TR>';
      l_message := l_message || '</TABLE>';
      l_message := l_message || '</P>';
      --Service Request
      l_message := l_message || '<P><B>' || getPrompt('CSF_ALERTS_SERVICE_REQUEST') || ': </B>';
      l_message := l_message || l_task_detail.sr_number || ' ' || l_task_detail.sr_summary;
      l_message := l_message || '</P>';
      -- Item
      if l_task_detail.product_nr is not null then
        l_message := l_message || '<P><B>' || getPrompt('CSF_ALERTS_ITEM') || '</B>: ' || l_task_detail.product_nr || ', ' || l_task_detail.item_description;
        if l_task_detail.item_serial is not null then
          l_message := l_message || '(' || l_task_detail.item_serial || ')';
        end if;
        -- Dalit A. Raviv 03/10/2011
        if l_attachment is not null then
          l_message := l_message || '<P><B>' || getPrompt('XXCSF_ALERTS_PRINTER_NOTES') || '</B>: ' || l_attachment;
        end if;
        --
        l_message := l_message || '</P>';
      end if;
      -- Customer
      l_message := l_message || '<P><B>' || getPrompt('CSF_ALERTS_CUSTOMER') || '</B>:<BR/>';
      l_message := l_message || l_task_detail.cust_name || '<BR/>';
      l_message := l_message || l_task_detail.cust_address || '<BR/>';
      -- Contact
      if l_task_detail.contact_name is not null then
        l_message := l_message || '<B>' || getPrompt('CSF_ALERTS_CONTACT') || '</B>:<BR/>' ;
        l_message := l_message || l_task_detail.contact_name || '<BR/>';
        l_message := l_message || l_task_detail.contact_phone || ' ' || l_task_detail.contact_email;
      end if;

      l_message := l_message || '</P>';
      -- notes
      l_is_notes := 'N';
      -- 1.0 21/09/2011 Dalit A. Raviv
      open c_notes(l_task_asgn_id);
      loop
        fetch c_notes into l_notes, l_note_createed_on, l_note_created_by;
        exit when c_notes%NOTFOUND;
        -- Notes
        if l_is_notes = 'N' then
          l_message := l_message || '<P><B>' || getPrompt('CSF_ALERTS_NOTES') || ':</B></P>';
          l_is_notes := 'Y';
        end if;
        -- Created On
        l_message := l_message || '<B>' || getPrompt('XXCSF_ALERTS_CREATED_DATE') || '</B>: ' || l_note_createed_on || '<BR/>';
        -- Created By
        l_message := l_message || '<B>' || getPrompt('XXCSF_ALERTS_CREATED_BY') || '</B>: ' || l_note_created_by || '<BR/>';
        l_message := l_message || l_notes || '<BR/><BR/>';

      end loop;
      close c_notes;

    else

      l_message := '';
      l_message := l_message || '
      ' || l_message_header;
      l_message := l_message || '
      ' || '
      ' || getPrompt('CSF_ALERTS_TASK_DETAILS') || ':';
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_TASK') || ': ';
      l_message := l_message || l_task_detail.task_number || ' ' || l_task_detail.task_name;
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_DESCRIPTION') || ': ';
      l_message := l_message || l_task_detail.task_desc;
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_SCHEDULE_START') || ': ';
      l_message := l_message || to_char(getClientTime(l_task_detail.sch_st_date,
                                          getUserId(l_resource_id, l_resource_type)), 'DD-MON-YYYY HH24:MI');
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_SCHEDULE_END') || ': ';
      l_message := l_message || to_char(getClientTime(l_task_detail.sch_end_date,
                                          getUserId(l_resource_id, l_resource_type)), 'DD-MON-YYYY HH24:MI');
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_PLANNED_EFFORT') || ': ';
      l_message := l_message || l_task_detail.planned_effort;
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_PRIORITY') || ': ';
      l_message := l_message || l_task_detail.priority;
      l_message := l_message || '
      ' || getPrompt('CSF_ALERTS_STATUS') || ': ';
      l_message := l_message || l_task_detail.asgm_sts_name;
      l_message := l_message || '
      ' || '
      ' || getPrompt('CSF_ALERTS_SERVICE_REQUEST') || ': ';
      l_message := l_message || l_task_detail.sr_number || ' ' || l_task_detail.sr_summary;

      if l_task_detail.product_nr is not null then
        l_message := l_message || '
        ' || '
        ' || getPrompt('CSF_ALERTS_ITEM') || ': ' || l_task_detail.product_nr || ', ' || l_task_detail.item_description;
        if l_task_detail.item_serial is not null then
          l_message := l_message || '(' || l_task_detail.item_serial || ')';
        end if;
      end if;

      l_message := l_message || '
      ' || '
      ' || getPrompt('CSF_ALERTS_CUSTOMER') || ': ';
      l_message := l_message || '
      ' || l_task_detail.cust_name;
      l_message := l_message || '
      ' || l_task_detail.cust_address;

      if l_task_detail.contact_name is not null then
        l_message := l_message || '
        ' || '
        ' || getPrompt('CSF_ALERTS_CONTACT') || ': ' || l_task_detail.contact_name;
        l_message := l_message || l_task_detail.contact_phone || ' ' || l_task_detail.contact_email;
      end if;

      -- notes
      l_is_notes := 'N';

      open c_notes(l_task_asgn_id);
      loop
        fetch c_notes into l_notes , l_note_createed_on , l_note_created_by;
        exit when c_notes%NOTFOUND;

        if l_is_notes = 'N' then
          l_message := l_message || '
          ' || getPrompt('CSF_ALERTS_NOTES') || ':';
          l_is_notes := 'Y';
        end if;

        l_message := l_message || l_notes || '
        ';

      end loop;
      close c_notes;

    end if;

    fnd_global.APPS_INITIALIZE(user_id => l_tmp_user_id, resp_id => l_tmp_resp_id, resp_appl_id => l_tmp_resp_apps_id);

    document := l_message;

  end getAssignedMessage;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getPrompt
  --  create by:          Oracle
  --  $Revision:          1.0
  --  creation date:      xx/xx/xxxx
  --  Purpose :           Copy from Oracle code
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  function getPrompt (p_name varchar2) return varchar2 is
    l_return varchar2(100);
  begin
    --l_return := '';
    fnd_message.set_name('CSF', p_name);
    l_return := fnd_message.get;
    return l_return;
  end;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getContactDetail
  --  create by:          Oracle
  --  $Revision:          1.0
  --  creation date:      xx/xx/xxxx
  --  Purpose :           Copy from Oracle code
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  --  1.1   04/10/2011    Dalit A. Raviv  add contact Email address
  --  1.2   07/12/2011    Dalit A. Raviv  add ext to the phone number
  -----------------------------------------------------------------------
  function getContactDetail(p_incident_id number,
                            p_contact_type varchar2,
                            p_party_id number) return contact_record is

      l_contact       contact_record;

      l_contact_name  varchar2(100);
      l_contact_email varchar2(250);
      l_contact_phone varchar2(100);

      cursor c_EMP_contact(v_id number) is
        select per.full_name contactname,
               per.email_address email,
               ph.phone_number phone_number
        from   per_all_people_f per,
               per_phones ph
        where  per.person_id    = v_id
        and    per.person_id    = ph.parent_id
        and    ph.phone_type    = 'W1'
        and    ph.parent_table  = 'PER_ALL_PEOPLE_F'
        and    sysdate          between nvl(per.effective_start_date, sysdate)
                                and    nvl(per.effective_end_date, sysdate);

      -- bug # 6630754
      -- relaced hz_party_relationships with hz_relationships
      cursor c_REL_contact(v_id number) is
        select hp.person_first_name ||' '|| hp.person_last_name contactname,
               hp.email_address email
        from   hz_relationships rel,
               hz_parties hp
        where  rel.party_id     = v_id
        and    rel.subject_id   = hp.party_id
        and    rel.subject_table_name = 'HZ_PARTIES'
        and    rel.subject_type = 'PERSON';

      cursor c_PERSON_contact(v_id number) is
        Select party_name, email_address
        from   hz_parties
        where  party_id   = v_id;

      -- 1.2 07/12/2011 Dalit A. Raviv add ext to the phone number
      cursor c_rel_person_phone(v_incident_id number) is
        select hcp.phone_country_code ||' '||
               hcp.phone_area_code ||' '||
               hcp.phone_number||' '||
               nvl2(hcp.phone_extension, 'ext: '|| hcp.phone_extension, null) phone_number
        from   cs_incidents_all_b        ci_all_b,
               cs_hz_sr_contact_points_v chscp,
               hz_contact_points         hcp
        where  ci_all_b.incident_id      = chscp.incident_id
        and    chscp.contact_point_id    = hcp.contact_point_id
        and    chscp.primary_flag        = 'Y'
        and    hcp.contact_point_type    = 'PHONE'
        and    ci_all_b.incident_id      = v_incident_id;

      -- 1.1 04/10/2011 Dalit A. Raviv
      cursor c_contact_email (v_incident_id number) is
        select hp.email_address
        from   cs_incidents_all_b      ciab,
               cs_hz_sr_contact_points chs,
               hz_parties              hp
        where  chs.incident_id         = ciab.incident_id
        and    chs.primary_flag        = 'Y'
        and    chs.party_id            = hp.party_id
        and    ciab.incident_id        = ciab.incident_id
        and    ciab.incident_id        = v_incident_id; --39024

      --
      l_email_address varchar2(250);
      --
  begin

    if p_contact_type = 'EMPLOYEE' then

      open c_EMP_contact(p_party_id);
      fetch c_EMP_contact into l_contact_name, l_contact_email, l_contact_phone;
      close c_EMP_contact;

    elsif p_contact_type = 'PARTY_RELATIONSHIP' then

      open c_REL_contact(p_party_id);
      fetch c_REL_contact into l_contact_name, l_contact_email;
      close c_REL_contact;

      open c_rel_person_phone(p_incident_id);
      fetch c_rel_person_phone into l_contact_phone;
      close c_rel_person_phone;

    elsif p_contact_type = 'PERSON' then

      open c_PERSON_contact(p_party_id);
      fetch c_PERSON_contact into l_contact_name, l_contact_email;
      close c_PERSON_contact;

      open c_rel_person_phone(p_incident_id);
      fetch c_rel_person_phone into l_contact_phone;
      close c_rel_person_phone;

    end if;
    -- 1.1 04/10/2011 Dalit A. Raviv add contact Email address
    -- find the primary contact. this contact is a party byitself
    -- therefor we can take the email from the party.
    l_email_address := null;
    open  c_contact_email (p_incident_id) ;
    fetch c_contact_email into l_email_address;
    close c_contact_email;

    if l_email_address is not null then
     l_contact_email := l_email_address;
    end if;
    -- end 1.1 04/10/2011 Dalit A. Raviv

    l_contact.contact_name  := l_contact_name;
    l_contact.contact_email := l_contact_email;
    l_contact.contact_phone := l_contact_phone;

    return l_contact;

  end getContactDetail;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getTaskDetails
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      21/09/2011
  --  Purpose :           1) correct oracle bug at the condition:
  --                         and msi_b.organization_id (+) = c_b.inv_organization_id--c_b.org_id
  --                         oracle compare organization id to org_id (OU)
  --                         the correction is to compare organization_id to inv_organization_id
  --                      2) add field to cursor c_task_assgn_detail
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  --  1.1   03/11/2011    Dalit A. Raviv  correct source of varibale according to
  --                                      oracle patch 120.0.12000000.8
  --  1.2   13/02/2012    Dalit A. Raviv  correct source of customent name
  --                                      sometime user enter contact name before entering customer name
  --                                      this cause that the address at the SR is the address of the contact 
  --                                      and not the address of the customer itself.
  --                                      at the select the customer name retrieve by the address.
  -----------------------------------------------------------------------
  function getTaskDetails(p_task_id number,
                          p_task_asgn_id number,
                           p_task_audit_id number) return task_asgn_record is

    l_task_asgn_record  task_asgn_record;
    l_contact_record    contact_record;

    l_task_number       jtf_tasks_b.task_number%type;
    l_task_name         jtf_tasks_vl.task_name%type;
    l_task_desc         jtf_tasks_vl.description%type;
    l_sch_st_date       jtf_tasks_b.scheduled_start_date%type;
    l_old_sch_st_date   jtf_tasks_b.scheduled_start_date%type;
    l_sch_end_date      jtf_tasks_b.scheduled_end_date%type;
    l_old_sch_end_date  jtf_tasks_b.scheduled_end_date%type;
    l_planned_effort    varchar2(100);
    l_priority          jtf_task_priorities_vl.name%type;
    l_asgm_sts_name     jtf_task_statuses_vl.name%type;
    l_sr_number         cs_incidents_all_b.incident_number%type;
    -- 03/11/2011 Dalit A. Raviv
    --l_sr_summary      cs_incidents_all_b.summary%type;
    l_sr_summary        cs_incidents_all_tl.summary%type; -- Oracle patch 120.0.12000000.8
    --
    l_product_nr        mtl_system_items_vl.concatenated_segments%type;
    l_item_serial       cs_customer_products_all.current_serial_number%type;
    l_item_description  mtl_system_items_vl.description%type;
    l_cust_name         hz_parties.party_name%type;
    l_cust_address      varchar2(1000);
    --l_contact_name      varchar2(100);
    --l_contact_phone     varchar2(100);
    --l_contact_email     varchar2(250);
    l_contact_type      varchar2(200);
    l_contact_party_id  number;
    l_incident_id       number;
    --  1.0 21/09/2011  Dalit A. Raviv
    l_task_type         varchar2(100);

    -- 1.2 15/12/2011 Dalit A. Raviv
    -- 1.  The address that is presented is the Customer identifying address from HZ parties
    -- table and not the incident address from SR. This is wrong and should be fixed to the
    -- correct address that is Incident address from SR.
    -- 2. The address does not include State and Country, please add both.
    cursor c_task_assgn_detail (v_task_assgn_id number) is
      select  c_b.incident_id                 incident_id,
              c_b.incident_number             sr_number,
              c_b.summary                     sr_summary,
              -- 1.2 13/02/2012 Dalit A. Raviv 
              -- if type is ORGANIZATION this is customer name
              -- else this id the contact name-> need to change to the customer name
              case when hp.party_type = 'ORGANIZATION' then
                     hp.party_name
                   else
                     (select hp1.party_name
                      from   hz_relationships rel,             
                             hz_parties       hp1
                      where  rel.party_id     = hp.party_id         
                      and    rel.subject_type = 'ORGANIZATION'      
                      and    hp1.party_id     = rel.subject_id
                      and    rownum           = 1)
              end  cust_name,
              --hp.party_name                   cust_name,
              -- end 1.2 13/02/2012
              --  hp.address1||', '||hp.postal_code||', '|| hp.city   address, -- 1.1 15/12/11 Moshe Lavi
              hl.address1||', '||hl.postal_code||', '|| hl.city||', '||hl.state||', '||hl.country address, -- 1.1 15/12/11 Moshe Lavi
              jtb.task_number                 task_number,
              j_vl.task_name                  task_name,
              js_vl.name                      assignment_name,
              jp_vl.name                      priority,
              j_vl.planned_effort||' '||j_vl.planned_effort_uom   planned_effort,
              jtb.scheduled_start_date        sch_st_date,
              jtb.scheduled_end_date          sch_end_date,
              j_vl.description                task_desc,
              msi_b.concatenated_segments     product_nr,
              ccp_all.current_serial_number   item_serial,
              msi_b.description               item_description,
              chscp.contact_type              contact_type,
              chscp.party_id                  contact_party_id,
              j_ttt.name                      task_type             --  1.0 21/09/2011 Dalit A. Raviv
      from    jtf_tasks_b                     jtb,
              jtf_task_assignments            jta,
              jtf_tasks_vl                    j_vl,
              jtf_task_types_tl               j_ttt,                --  1.0 21/09/2011 Dalit A. Raviv
              jtf_task_priorities_vl          jp_vl,
              jtf_task_statuses_vl            js_vl,
              cs_incidents_all                c_b,
              hz_party_sites                  hps,
              hz_parties                      hp,
              mtl_system_items_vl             msi_b,
              cs_customer_products_all        ccp_all,
              cs_hz_sr_contact_points_v       chscp,
              hz_locations                    hl                    -- 1.1 15/12/11 Moshe Lavi
      where   jta.task_assignment_id          = v_task_assgn_id     --9446023
      and     jta.task_id                     = jtb.task_id
      and     j_vl.task_id                    = jta.task_id
      and     jp_vl.task_priority_id (+)      = j_vl.task_priority_id
      and     js_vl.task_status_id            = jta.assignment_status_id
      and     jtb.source_object_type_code     = 'SR'
      and     jtb.source_object_id            = c_b.incident_id
      and     jtb.address_id                  = hps.party_site_id
      and     hps.location_id                 = hl.location_id      -- 1.1 15/12/11 Moshe Lavi
      and     hps.party_id                    = hp.party_id
      and     c_b.inventory_item_id           = msi_b.inventory_item_id (+)
      and     c_b.customer_product_id         = ccp_all.customer_product_id(+)
      --      c_b.org_id correct bug Dalit A. Raviv
      and     msi_b.organization_id (+)       = c_b.inv_organization_id
      --
      and     chscp.primary_flag (+)          = 'Y'
      and     chscp.incident_id (+)           = c_b.incident_id
      and     j_ttt.task_type_id              = jtb.task_type_id    --  1.0 21/09/2011 Dalit A. Raviv
      and     j_ttt.language                  = 'US';               --  1.0 21/09/2011 Dalit A. Raviv

    cursor c_task_detail (v_task_id number) is
      SELECT
        c_b.incident_id incident_id,
        c_b.incident_number sr_number,
        c_b.summary sr_summary,
        hp.party_name cust_name,
        hp.address1 || ', ' ||  hp.postal_code || ', ' || hp.city address,
        jtb.task_number task_number,
        j_vl.task_name task_name,
        jp_vl.name priority,
        j_vl.PLANNED_EFFORT || ' ' || j_vl.PLANNED_EFFORT_UOM planned_effort,
        jtb.scheduled_start_date sch_st_date,
        jtb.scheduled_end_date sch_end_date,
        j_vl.description task_desc,
        msi_b.concatenated_segments product_nr,
        ccp_all.current_serial_number item_serial,
        msi_b.description item_description,
        chscp.contact_type  contact_type,
        chscp.party_id contact_party_id
      FROM
        jtf_tasks_b jtb,
        jtf_tasks_vl j_vl,
        jtf_task_priorities_vl jp_vl,
        cs_incidents_all c_b,
        hz_party_sites hps,
        hz_parties hp,
        mtl_system_items_vl msi_b,
        cs_customer_products_all ccp_all,
        cs_hz_sr_contact_points_v chscp
      WHERE
        jtb.task_id = v_task_id
        and j_vl.task_id = jtb.task_id
        and jp_vl.task_priority_id (+) = j_vl.task_priority_id
        and jtb.source_object_type_code = 'SR'
        and jtb.source_object_id = c_b.incident_id
        and jtb.address_id = hps.party_site_id
        and hps.party_id = hp.party_id
        and c_b.inventory_item_id = msi_b.inventory_item_id (+)
        and c_b.customer_product_id = ccp_all.customer_product_id(+)
        and msi_b.organization_id (+) = c_b.org_id
        and chscp.primary_flag (+) = 'Y'
        and chscp.incident_id (+) = c_b.incident_id;

    cursor c_task_audit_detail (v_task_id number, v_task_audit_id number) is
      SELECT
        c_b.incident_id incident_id,
        c_b.incident_number sr_number,
        c_b.summary sr_summary,
        hp.party_name cust_name,
        hp.address1 || ', ' ||  hp.postal_code || ', ' || hp.city address,
        jtb.task_number task_number,
        j_vl.task_name task_name,
        jp_vl.name priority,
        j_vl.PLANNED_EFFORT || ' ' || j_vl.PLANNED_EFFORT_UOM planned_effort,
        jtb.scheduled_start_date sch_st_date,
        jtb.scheduled_end_date sch_end_date,
        j_vl.description task_desc,
        msi_b.concatenated_segments product_nr,
        ccp_all.current_serial_number item_serial,
        msi_b.description item_description,
        chscp.contact_type  contact_type,
        chscp.party_id contact_party_id,
        jtab.old_scheduled_start_date old_sch_st_date,
        jtab.old_scheduled_end_date old_sch_end_date
      FROM
        jtf_tasks_b jtb,
        jtf_task_audits_b jtab,
        jtf_tasks_vl j_vl,
        jtf_task_priorities_vl jp_vl,
        cs_incidents_all c_b,
        hz_party_sites hps,
        hz_parties hp,
        mtl_system_items_vl msi_b,
        cs_customer_products_all ccp_all,
        cs_hz_sr_contact_points_v chscp
      WHERE
        jtb.task_id = v_task_id
        and jtab.task_audit_id = v_task_audit_id
        and jtab.task_id = jtb.task_id
        and j_vl.task_id = jtb.task_id
        and jp_vl.task_priority_id (+) = j_vl.task_priority_id
        and jtb.source_object_type_code = 'SR'
        and jtb.source_object_id = c_b.incident_id
        and jtb.address_id = hps.party_site_id
        and hps.party_id = hp.party_id
        and c_b.inventory_item_id = msi_b.inventory_item_id (+)
        and c_b.customer_product_id = ccp_all.customer_product_id(+)
        and msi_b.organization_id (+) = c_b.org_id
        and chscp.primary_flag (+) = 'Y'
        and chscp.incident_id (+) = c_b.incident_id;
  begin

    if p_task_asgn_id is not null then

      open c_task_assgn_detail(p_task_asgn_id);
      fetch c_task_assgn_detail into
                        l_incident_id,
                        l_sr_number,
                        l_sr_summary,
                        l_cust_name,
                        l_cust_address,
                        l_task_number,
                        l_task_name,
                        l_asgm_sts_name,
                        l_priority,
                        l_planned_effort,
                        l_sch_st_date,
                        l_sch_end_date,
                        l_task_desc,
                        l_product_nr,
                        l_item_serial,
                        l_item_description,
                        l_contact_type,
                        l_contact_party_id,
                        l_task_type;        --  1.0 21/09/2011 Dalit A. Raviv
      close c_task_assgn_detail;

      l_contact_record := getContactDetail(l_incident_id,
                                            l_contact_type,
                                            l_contact_party_id);

      l_task_asgn_record.task_number      := l_task_number;
      l_task_asgn_record.task_name        := l_task_name;
      l_task_asgn_record.task_desc        := l_task_desc;
      l_task_asgn_record.sch_st_date      := l_sch_st_date;
      l_task_asgn_record.sch_end_date     := l_sch_end_date;
      l_task_asgn_record.planned_effort   := l_planned_effort;
      l_task_asgn_record.priority         := l_priority;
      l_task_asgn_record.asgm_sts_name    := l_asgm_sts_name;
      l_task_asgn_record.sr_number        := l_sr_number;
      l_task_asgn_record.sr_summary       := l_sr_summary;
      l_task_asgn_record.product_nr       := l_product_nr;
      l_task_asgn_record.item_serial      := l_item_serial;
      l_task_asgn_record.item_description := l_item_description;
      l_task_asgn_record.cust_name        := l_cust_name;
      l_task_asgn_record.cust_address     := l_cust_address;
      l_task_asgn_record.contact_name     := l_contact_record.contact_name;
      l_task_asgn_record.contact_phone    := l_contact_record.contact_phone;
      l_task_asgn_record.contact_email    := l_contact_record.contact_email;
      --  1.0 21/09/2011 Dalit A. Raviv
      l_task_asgn_record.task_type        := l_task_type;
      --
    elsif p_task_id is not null and p_task_audit_id is null then

      open c_task_detail(p_task_id);
      fetch c_task_detail into
                        l_incident_id,
                        l_sr_number,
                        l_sr_summary,
                        l_cust_name,
                        l_cust_address,
                        l_task_number,
                        l_task_name,
                        l_priority,
                        l_planned_effort,
                        l_sch_st_date,
                        l_sch_end_date,
                        l_task_desc,
                        l_product_nr,
                        l_item_serial,
                        l_item_description,
                        l_contact_type,
                        l_contact_party_id;
      close c_task_detail;

      l_contact_record := getContactDetail(l_incident_id,
                                            l_contact_type,
                                            l_contact_party_id);

      l_task_asgn_record.task_number := l_task_number;
      l_task_asgn_record.task_name := l_task_name;
      l_task_asgn_record.task_desc := l_task_desc;
      l_task_asgn_record.sch_st_date := l_sch_st_date;
      l_task_asgn_record.sch_end_date := l_sch_end_date;
      l_task_asgn_record.planned_effort := l_planned_effort;
      l_task_asgn_record.priority := l_priority;
      l_task_asgn_record.sr_number := l_sr_number;
      l_task_asgn_record.sr_summary := l_sr_summary;
      l_task_asgn_record.product_nr := l_product_nr;
      l_task_asgn_record.item_serial := l_item_serial;
      l_task_asgn_record.item_description := l_item_description;
      l_task_asgn_record.cust_name := l_cust_name;
      l_task_asgn_record.cust_address := l_cust_address;
      l_task_asgn_record.contact_name := l_contact_record.contact_name;
      l_task_asgn_record.contact_phone := l_contact_record.contact_phone;
      l_task_asgn_record.contact_email := l_contact_record.contact_email;

    elsif p_task_id is not null and p_task_audit_id is not null then

      open c_task_audit_detail(p_task_id, p_task_audit_id);
      fetch c_task_audit_detail into
                        l_incident_id,
                        l_sr_number,
                        l_sr_summary,
                        l_cust_name,
                        l_cust_address,
                        l_task_number,
                        l_task_name,
                        l_priority,
                        l_planned_effort,
                        l_sch_st_date,
                        l_sch_end_date,
                        l_task_desc,
                        l_product_nr,
                        l_item_serial,
                        l_item_description,
                        l_contact_type,
                        l_contact_party_id,
                        l_old_sch_st_date,
                        l_old_sch_end_date;
      close c_task_audit_detail;

      l_contact_record := getContactDetail(l_incident_id,
                                            l_contact_type,
                                            l_contact_party_id);

      l_task_asgn_record.task_number := l_task_number;
      l_task_asgn_record.task_name := l_task_name;
      l_task_asgn_record.task_desc := l_task_desc;
      l_task_asgn_record.sch_st_date := l_sch_st_date;
      l_task_asgn_record.sch_end_date := l_sch_end_date;
      l_task_asgn_record.planned_effort := l_planned_effort;
      l_task_asgn_record.priority := l_priority;
      l_task_asgn_record.sr_number := l_sr_number;
      l_task_asgn_record.sr_summary := l_sr_summary;
      l_task_asgn_record.product_nr := l_product_nr;
      l_task_asgn_record.item_serial := l_item_serial;
      l_task_asgn_record.item_description := l_item_description;
      l_task_asgn_record.cust_name := l_cust_name;
      l_task_asgn_record.cust_address := l_cust_address;
      l_task_asgn_record.contact_name := l_contact_record.contact_name;
      l_task_asgn_record.contact_phone := l_contact_record.contact_phone;
      l_task_asgn_record.contact_email := l_contact_record.contact_email;
      l_task_asgn_record.old_sch_st_date := l_old_sch_st_date;
      l_task_asgn_record.old_sch_end_date := l_old_sch_end_date;

    end if;

    return l_task_asgn_record;
  end getTaskDetails;


  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getClientTime
  --  create by:          Oracle
  --  $Revision:          1.0
  --  creation date:      xx/xx/xxxx
  --  Purpose :           Copy from Oracle code
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  function getClientTime (p_server_time date,
                            p_user_id number) return date is
    l_client_tz_id  number;
    l_server_tz_id  number;
    l_msg_count     number;
    l_status        varchar2(1);
    x_client_time   date;
    l_msg_data      varchar2(2000);

  begin

    IF (fnd_timezones.timezones_enabled <> 'Y') THEN
       return p_server_time;
    END IF;

    l_client_tz_id := to_number(fnd_profile.VALUE_SPECIFIC('CLIENT_TIMEZONE_ID',
                                                                      p_user_id,
                                                                      21685,
                                                                      513,
                                                                      null,
                                                                      null));

    l_server_tz_id := to_number(fnd_profile.VALUE_SPECIFIC('SERVER_TIMEZONE_ID',
                                                                      p_user_id,
                                                                      21685,
                                                                      513,
                                                                      null,
                                                                      null));

    HZ_TIMEZONE_PUB.GET_TIME(1.0,
                              'F',
                              l_server_tz_id,
                              l_client_tz_id,
                              p_server_time,
                              x_client_time,
                              l_status,
                              l_msg_count,
                              l_msg_data);

    return x_client_time;

  end getClientTime;
  
  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getSubject
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      13/02/2012
  --  Purpose :           change notification subject
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/02/2012    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  procedure getSubject(document_id   varchar2,
                       display_type  varchar2,
                       document      in out nocopy varchar2,
                       document_type in out nocopy varchar2) is
                       
    l_resource_id          number;
    l_resource_type        varchar2(100);
    l_task_asgn_id         number; 
    l_task_asgn_record     task_asgn_record;
    l_cust_name            hz_parties.party_name%type;
    l_schedule_start_date  varchar2(100);  
    l_msg_subject          varchar(1000);                     
  begin
    l_resource_id          := to_number(substr(document_id, 1, instr(document_id, '-', 1, 1) - 1));
    l_resource_type        := substr(document_id, instr(document_id, '-', 1, 1) + 1, instr(document_id, '-', 1, 2) - instr(document_id, '-', 1, 1) - 1);
    l_task_asgn_id         := to_number(substr(document_id, instr(document_id, '-', 1, 2) + 1));

    l_task_asgn_record     := getTaskDetails(null, l_task_asgn_id, null);

    l_cust_name            := l_task_asgn_record.cust_name;
    l_schedule_start_date  := to_char(getClientTime(l_task_asgn_record.sch_st_date,
                                      getUserId(l_resource_id, l_resource_type)), 'DD-MON-YYYY HH24:MI');

    fnd_message.set_name('CSF', 'CSF_ALERTS_ASSIGNED_SUB');
    fnd_message.set_token('CUST_NAME', l_cust_name);
    fnd_message.set_token('SCH_START_DT', l_schedule_start_date);
    l_msg_subject := fnd_message.get;

    document := l_msg_subject;
  end getSubject;      

END XXcsf_alerts_pub;
/
