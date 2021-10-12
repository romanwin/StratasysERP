CREATE OR REPLACE VIEW PO_WF_NOTIFICATIONS_V
  (notification_id, group_id, message_type, message_name, recipient_role, 
   notification_status, access_key, mail_status, priority, creation_date, 
   end_date, due_date, note, callback, context, 
   subject, message, recipient_role_name, employee_id, from_id, 
   employee_name, from_employee_name, doc_type_name, doc_type, doc_creation_date, 
   object_id, doc_number, amount, currency, doc_owner, 
   owner_id, description, doc_status_dsp, object_type_code, object_sub_type_code, 
   sequence_num, object_revision_num, approval_path_id, request_id, program_application_id, 
   program_date, program_id, last_update_date, item_key, item_type, 
   row_id, org_id, security_level_code, access_level_code)
AS
SELECT
--------------------------------------------------------------------
--  name:            PO_WF_NOTIFICATIONS_V
--  create by:       Oracle View
--  Revision:        1.0
--  creation date:   XX/XX/XXXX
--------------------------------------------------------------------
--  purpose :        CHG0033961 - PO issue - Forward Documents
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  30/11/2014  Dalit A. Raviv    initial build
--------------------------------------------------------------------
       wf.notification_id,
       wf.group_id,
       wf.message_type,
       wf.message_name,
       wf.recipient_role,
       wf.status,
       wf.access_key,
       wf.mail_status,
       wf.priority,
       wf.begin_date,
       wf.end_date,
       wf.due_date,
       wf.user_comment,
       wf.callback,
       wf.context,
       wf_notification.getsubject(wf.notification_id) subject,
       wf_notification.getshortbody(wf.notification_id) message,
       wf_directory.getroledisplayname(wf.recipient_role) recipient_role_name,
       wu.orig_system_id,
       po_notifications_sv3.get_wf_role_id(wf.original_recipient),
       wf_directory.getroledisplayname(wf.recipient_role),
       wf_directory.getroledisplayname(wf.original_recipient),
       podtl.type_name,
       poh.type_lookup_code,
       poh.creation_date,
       poh.po_header_id,
       poh.segment1,
       decode(poh.type_lookup_code, 'RFQ', NULL, 'QUOTATION', NULL, po_notifications_sv3.get_doc_total(poh.type_lookup_code, poh.po_header_id)) amount,
       poh.currency_code,
       po_notifications_sv3.get_emp_name(poh.agent_id),
       poh.agent_id,
       poh.comments,
       nvl(poh.authorization_status, 'INCOMPLETE'),
       ph.object_type_code,
       ph.object_sub_type_code,
       ph.sequence_num,
       ph.object_revision_num,
       nvl(ph.approval_path_id, 0),
       ph.request_id,
       ph.program_application_id,
       ph.program_date,
       ph.program_id,
       ph.last_update_date,
       poh.wf_item_key,
       poh.wf_item_type,
       ph.rowid,
       poh.org_id,
       podb.security_level_code,
       podb.access_level_code
  FROM wf_notifications          wf,
       wf_item_activity_statuses wias,
       po_document_types_all_tl  podtl,
       po_document_types_all_b   podb,
       po_headers                poh,
       po_action_history         ph,
       wf_users                  wu
 WHERE poh.po_header_id = ph.object_id
   AND ph.object_type_code = podtl.document_type_code
   AND podtl.document_type_code IN ('PO', 'PA')
   AND ph.action_code IS NULL
   AND wias.item_type = poh.wf_item_type
   AND wias.item_key = poh.wf_item_key
   AND wias.notification_id = wf.notification_id
   AND wias.activity_status = 'NOTIFIED'
   AND wf.message_type = poh.wf_item_type
   -- 30/11/2014 add XX messages to the list
   AND wf.message_name IN
       ('PO_PO_APPROVE_PDF', 'PO_PO_APPROVE', 'PO_PO_REMINDER_1', 'PO_PO_REMINDER_2', 'UNABLE_TO_RESERVE', 'UNABLE_TO_RESERVE_CO', 
        'XXPO_PO_APPROVE', 'XXPO_PO_APPROVE_PDF', 'XXPO_PO_REMINDER_1', 'XXPO_PO_REMINDER_2', 'XXPO_PO_APPROVE_JRAD', 
        'XXPO_PO_APPROVE_PDF_JRAD', 'XXPO_PO_REMINDER_1_JRAD', 'XXPO_PO_REMINDER_2_JRAD')
   AND podtl.document_subtype = poh.type_lookup_code
   AND podtl.language = userenv('LANG')
   AND poh.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
   AND wf.status = 'OPEN'
   AND ph.sequence_num =
       (SELECT MAX(pah1.sequence_num)
          FROM po_action_history pah1
         WHERE pah1.object_id = ph.object_id
           AND pah1.object_type_code = ph.object_type_code
           AND pah1.object_sub_type_code = ph.object_sub_type_code)
   AND podtl.org_id(+) = poh.org_id
   AND podtl.org_id = podb.org_id
   AND podb.document_type_code = podtl.document_type_code
   AND podb.document_subtype = podtl.document_subtype
   AND wu.name = wf.recipient_role
   AND wu.orig_system IN ('FND', 'PER')
UNION ALL
SELECT wf.notification_id,
       wf.group_id,
       wf.message_type,
       wf.message_name,
       wf.recipient_role,
       wf.status,
       wf.access_key,
       wf.mail_status,
       wf.priority,
       wf.begin_date,
       wf.end_date,
       wf.due_date,
       wf.user_comment,
       wf.callback,
       wf.context,
       wf_notification.getsubject(wf.notification_id) subject,
       wf_notification.getshortbody(wf.notification_id) message,
       wf_directory.getroledisplayname(wf.recipient_role),
       wu.orig_system_id,
       po_notifications_sv3.get_wf_role_id(wf.original_recipient),
       wf_directory.getroledisplayname(wf.recipient_role),
       wf_directory.getroledisplayname(wf.original_recipient),
       podtl.type_name,
       podtl.document_subtype,
       por.creation_date,
       por.po_release_id,
       poh.segment1 || '-' || por.release_num,
       to_char(po_notifications_sv3.get_doc_total('RELEASE', por.po_release_id)) amount,
       poh.currency_code,
       po_notifications_sv3.get_emp_name(por.agent_id),
       poh.agent_id,
       poh.comments,
       nvl(por.authorization_status, 'INCOMPLETE'),
       ph.object_type_code,
       ph.object_sub_type_code,
       ph.sequence_num,
       ph.object_revision_num,
       nvl(ph.approval_path_id, 0),
       ph.request_id,
       ph.program_application_id,
       ph.program_date,
       ph.program_id,
       ph.last_update_date,
       por.wf_item_key,
       por.wf_item_type,
       ph.rowid,
       por.org_id,
       podb.security_level_code,
       podb.access_level_code
  FROM wf_notifications          wf,
       wf_item_activity_statuses wias,
       po_document_types_all_tl  podtl,
       po_document_types_all_b   podb,
       po_action_history         ph,
       po_headers_all            poh,
       po_releases               por,
       wf_users                  wu
 WHERE por.po_release_id = ph.object_id
   AND ph.object_type_code = podtl.document_type_code
   AND podtl.document_type_code = 'RELEASE'
   AND podtl.document_subtype = por.release_type
   AND podtl.language = userenv('LANG')
   AND por.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
   AND wf.status = 'OPEN'
   AND ph.action_code IS NULL
   AND wias.item_type = por.wf_item_type
   AND wias.item_key = por.wf_item_key
   AND wias.notification_id = wf.notification_id
   AND wias.activity_status = 'NOTIFIED'
   AND por.po_header_id = poh.po_header_id
   AND wf.message_type = por.wf_item_type
   -- 30/11/2014 add XX messages to the list
   AND wf.message_name IN
       ('PO_PO_APPROVE_PDF', 'PO_PO_APPROVE', 'PO_PO_REMINDER_1', 'PO_PO_REMINDER_2', 'UNABLE_TO_RESERVE', 'UNABLE_TO_RESERVE_CO', 
        'XXPO_PO_APPROVE', 'XXPO_PO_APPROVE_PDF', 'XXPO_PO_REMINDER_1', 'XXPO_PO_REMINDER_2', 'XXPO_PO_APPROVE_JRAD', 
        'XXPO_PO_APPROVE_PDF_JRAD', 'XXPO_PO_REMINDER_1_JRAD', 'XXPO_PO_REMINDER_2_JRAD') 
   AND ph.sequence_num =
       (SELECT MAX(pah1.sequence_num)
          FROM po_action_history pah1
         WHERE pah1.object_id = ph.object_id
           AND pah1.object_type_code = ph.object_type_code
           AND pah1.object_sub_type_code = ph.object_sub_type_code)
   AND podtl.org_id(+) = por.org_id
   AND podtl.org_id = podb.org_id
   AND podb.document_type_code = podtl.document_type_code
   AND podb.document_subtype = podtl.document_subtype
   AND wu.name = wf.recipient_role
   AND wu.orig_system IN ('FND', 'PER')
UNION ALL
SELECT wf.notification_id,
       wf.group_id,
       wf.message_type,
       wf.message_name,
       wf.recipient_role,
       wf.status,
       wf.access_key,
       wf.mail_status,
       wf.priority,
       wf.begin_date,
       wf.end_date,
       wf.due_date,
       wf.user_comment,
       wf.callback,
       wf.context,
       wf_notification.getsubject(wf.notification_id) subject,
       wf_notification.getshortbody(wf.notification_id) message,
       wf_directory.getroledisplayname(wf.recipient_role),
       wu.orig_system_id,
       po_notifications_sv3.get_wf_role_id(wf.original_recipient),
       wf_directory.getroledisplayname(wf.recipient_role),
       wf_directory.getroledisplayname(wf.original_recipient),
       podtl.type_name,
       prh.type_lookup_code,
       prh.creation_date,
       prh.requisition_header_id,
       prh.segment1,
       decode(prh.type_lookup_code, 'RFQ', NULL, 'QUOTATION', NULL, po_notifications_sv3.get_doc_total(prh.type_lookup_code, prh.requisition_header_id)) amount,
       po_core_s2.get_base_currency(prh.org_id),
       po_notifications_sv3.get_emp_name(prh.preparer_id),
       prh.preparer_id,
       prh.description,
       nvl(prh.authorization_status, 'INCOMPLETE'),
       ph.object_type_code,
       ph.object_sub_type_code,
       ph.sequence_num,
       ph.object_revision_num,
       nvl(ph.approval_path_id, 0),
       ph.request_id,
       ph.program_application_id,
       ph.program_date,
       ph.program_id,
       ph.last_update_date,
       prh.wf_item_key,
       prh.wf_item_type,
       ph.rowid,
       prh.org_id,
       podb.security_level_code,
       podb.access_level_code
  FROM wf_notifications          wf,
       wf_item_activity_statuses wias,
       po_document_types_all_tl  podtl,
       po_document_types_all_b   podb,
       po_requisition_headers    prh,
       po_action_history         ph,
       wf_users                  wu
 WHERE prh.requisition_header_id = ph.object_id
   AND ph.object_type_code = podtl.document_type_code
   AND podtl.document_type_code = 'REQUISITION'
   AND podtl.document_subtype = prh.type_lookup_code
   AND podtl.language = userenv('LANG')
   AND wf.status = 'OPEN'
   AND prh.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
   AND ph.action_code IS NULL
   AND wias.item_type = prh.wf_item_type
   AND wias.item_key = prh.wf_item_key
   AND wias.notification_id = wf.notification_id
   AND wias.activity_status = 'NOTIFIED'
   AND wf.message_type = prh.wf_item_type
   -- 30/11/2014 add XX messages to the list
   AND wf.message_name IN
       ('PO_REQ_APPROVE', 'PO_REQ_REMINDER1', 'PO_REQ_REMINDER2', 'PO_REQ_APPROVE_JRAD', 'PO_REQ_REMINDER1_JRAD', 
        'PO_REQ_REMINDER2_JRAD', 'PO_REQ_INVALID_FORWARD', 'PO_REQ_INVALID_FORWARD_R1', 'PO_REQ_INVALID_FORWARD_R2', 
        'UNABLE_TO_RESERVE', 'PO_REQ_APPROVE_SIMPLE_JRAD', 'XXPO_REQ_APPROVE_JRAD', 'XXPO_REQ_REMINDER1_JRAD', 
        'XXPO_REQ_REMINDER2_JRAD', 'XXPO_REQ_APPROVE_SIMPLE_JRAD')
   AND ph.sequence_num =
       (SELECT MAX(pah1.sequence_num)
          FROM po_action_history pah1
         WHERE pah1.object_id = ph.object_id
           AND pah1.object_type_code = ph.object_type_code
           AND pah1.object_sub_type_code = ph.object_sub_type_code)
   AND podtl.org_id(+) = prh.org_id
   AND podtl.org_id = podb.org_id
   AND podb.document_type_code = podtl.document_type_code
   AND podb.document_subtype = podtl.document_subtype
   AND wu.name = wf.recipient_role
   AND wu.orig_system IN ('FND', 'PER');
