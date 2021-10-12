create or replace package body xx_xla_events_util is

  Procedure Clear_Event_Of_Deleted_Dist(x_return_code        OUT VARCHAR2,
                                        x_err_msg            OUT VARCHAR2,
                                        p_transaction_number varchar2,
                                        p_org_id             number) is
    l_Message           VARCHAR2(500) := '';
    l_event_source_info xla_events_pub_pkg.t_event_source_info;
    l_security_context  xla_events_pub_pkg.t_security;

    l_ledger_id       NUMBER;
    l_legal_entity_id NUMBER;

    CURSOR c_draft_event IS
      SELECT DISTINCT xte.entity_code entity_code,
                      xte.source_id_int_1 header_id,
                      xte.transaction_number segment1,
                      xte.security_id_int_1 org_id,
                      xe.event_id
        FROM xla.xla_transaction_entities xte,
             xla.xla_events               xe,
             xla.xla_distribution_links   xdl
       WHERE xte.application_id = 201
         and xte.application_id = xe.application_id --added by daniel katz
         and xte.application_id = xdl.application_id --added by daniel katz
         AND xte.entity_id = xe.entity_id
         AND xdl.event_id = xe.event_id
         AND xe.event_status_code = 'U'
         and xte.security_id_int_1 = p_org_id
         and xte.transaction_number = p_transaction_number
         AND xe.process_status_code IN ('D', 'I')
         AND ((xte.entity_code = 'PURCHASE_ORDER' AND NOT EXISTS
              (SELECT pod.po_distribution_id
                  FROM po_distributions_all pod
                 WHERE pod.po_distribution_id =
                       xdl.source_distribution_id_num_1)) OR
             (xte.entity_code = 'RELEASE' AND NOT EXISTS
              (SELECT pod.po_distribution_id
                  FROM po_distributions_all pod
                 WHERE pod.po_distribution_id =
                       xdl.source_distribution_id_num_1)) OR
             (xte.entity_code = 'REQUISITION' AND NOT EXISTS
              (SELECT prd.distribution_id
                  FROM po_req_distributions_all prd
                 WHERE prd.distribution_id = xdl.source_distribution_id_num_1)));
  begin
    fnd_file.Put_Line(fnd_file.LOG, fnd_global.org_id);
    FOR draft_event IN c_draft_event LOOP

      l_Message := 'Processing  ' || ' Document Type: ' ||
                   draft_event.entity_code || ' Document Number : ' ||
                   draft_event.segment1 || ' header_id : ' ||
                   draft_event.header_id || ' org_id : ' ||
                   draft_event.org_id || ' event_id : ' ||
                   draft_event.event_id;
      fnd_file.Put_Line(fnd_file.LOG, l_Message);

      PO_MOAC_UTILS_PVT.set_org_context(draft_event.org_id);

      SELECT set_of_books_id
        INTO l_ledger_id
        FROM hr_operating_units hou
       WHERE hou.organization_id = draft_event.org_id;

      l_legal_entity_id := xle_utilities_grp.Get_DefaultLegalContext_OU(draft_event.org_id);

      l_event_source_info.source_application_id := NULL;
      l_event_source_info.application_id        := 201;
      l_event_source_info.legal_entity_id       := l_legal_entity_id;
      l_event_source_info.ledger_id             := l_ledger_id;
      l_event_source_info.entity_type_code      := draft_event.entity_code;
      l_event_source_info.transaction_number    := draft_event.segment1; -- Segment1
      l_event_source_info.source_id_int_1       := draft_event.header_id; -- header_id
      l_security_context.security_id_int_1      := draft_event.org_id; -- Org_id

      l_Message := 'Deleting the event and clearing PO BC Distribution Table. ' || '\n';
      fnd_file.Put_Line(fnd_file.LOG, l_Message);

      xla_events_pub_pkg.DELETE_EVENT(l_event_source_info,
                                      draft_event.event_id,
                                      NULL,
                                      l_security_context);

      fnd_file.Put_Line(fnd_file.LOG,
                        ' Event Deleted : ' || draft_event.event_id);

      DELETE FROM PO_BC_DISTRIBUTIONS
       WHERE ae_event_id = draft_event.event_id;

    END LOOP;

    l_Message := 'Deleted all the draft event and cleared PO BC Distribution Table. ';

    fnd_file.Put_Line(fnd_file.LOG, l_Message);

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.Put_Line(fnd_file.LOG, 'Some exception occured ' || SQLERRM);

      ROLLBACK;
  end Clear_Event_Of_Deleted_Dist;
  -----------------------------------------------------------------
  Procedure clear_Invalid_Events_PO(x_return_code        OUT VARCHAR2,
                                    x_err_msg            OUT VARCHAR2,
                                    p_transaction_number varchar2,
                                    p_org_id             number) is
    l_Message           VARCHAR2(500) := '';
    l_event_source_info xla_events_pub_pkg.t_event_source_info;
    l_security_context  xla_events_pub_pkg.t_security;

    l_ledger_id       NUMBER;
    l_legal_entity_id NUMBER;

    CURSOR cur_events IS
      SELECT event_id FROM PSA_BC_XLA_EVENTS_GT;
    CURSOR c_draft_event IS
      select DISTINCT ph.po_header_id, ph.segment1, ph.org_id, xe.event_id
        from xla.xla_transaction_entities xte,
             xla.xla_events               xe,
             po_headers_all               ph
       where xte.source_id_int_1 = ph.po_header_id
         AND ph.segment1 = p_transaction_number
         and ph.org_id = p_org_id
         AND xte.application_id = 201
         AND xte.entity_id = xe.entity_id
         AND xe.EVENT_STATUS_CODE = 'U'
         AND xe.PROCESS_STATUS_CODE IN ('I', 'D');
  begin
    FOR draft_event IN c_draft_event LOOP

      l_Message := 'Processing  ' || ' po_header_id : ' ||
                   draft_event.po_header_id || ' PO Number : ' ||
                   draft_event.segment1 || ' org_id : ' ||
                   draft_event.org_id || ' event_id : ' ||
                   draft_event.event_id;

      fnd_file.Put_Line(fnd_file.LOG, l_Message);

      PO_MOAC_UTILS_PVT.set_org_context(draft_event.org_id);

      SELECT set_of_books_id
        INTO l_ledger_id
        FROM hr_operating_units hou
       WHERE hou.organization_id = draft_event.org_id;

      l_legal_entity_id := xle_utilities_grp.Get_DefaultLegalContext_OU(draft_event.org_id);

      l_event_source_info.source_application_id := NULL;
      l_event_source_info.application_id        := 201;
      l_event_source_info.legal_entity_id       := l_legal_entity_id;
      l_event_source_info.ledger_id             := l_ledger_id;
      l_event_source_info.entity_type_code      := 'PURCHASE_ORDER';
      l_event_source_info.transaction_number    := draft_event.segment1; -- Segment1
      l_event_source_info.source_id_int_1       := draft_event.po_header_id; -- Po_header_id
      l_security_context.security_id_int_1      := draft_event.org_id; -- Org_id

      xla_events_pub_pkg.DELETE_EVENT(l_event_source_info,
                                      draft_event.event_id,
                                      NULL,
                                      l_security_context);

      fnd_file.Put_Line(fnd_file.LOG,
                        ' Event Deleted : ' || draft_event.event_id);

      DELETE FROM PO_BC_DISTRIBUTIONS
       WHERE ae_event_id = draft_event.event_id;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.Put_Line(fnd_file.LOG, 'Some exception occured ' || SQLERRM);

      ROLLBACK;
  end clear_Invalid_Events_PO;

  -----------------------------------------------------------------
  Procedure clear_Invalid_Events_REQ(x_return_code        OUT VARCHAR2,
                                     x_err_msg            OUT VARCHAR2,
                                     p_transaction_number varchar2,
                                     p_org_id             number) is
    l_Message           VARCHAR2(500) := '';
    l_event_source_info xla_events_pub_pkg.t_event_source_info;
    l_security_context  xla_events_pub_pkg.t_security;

    l_ledger_id       NUMBER;
    l_legal_entity_id NUMBER;

    CURSOR cur_events IS
      SELECT event_id FROM PSA_BC_XLA_EVENTS_GT;
    CURSOR c_draft_event IS
      select DISTINCT prh.requisition_header_id,
                      prh.segment1,
                      prh.org_id,
                      xe.event_id
        from xla.xla_transaction_entities xte,
             xla.xla_events               xe,
             po_requisition_headers_all   prh
       where xte.source_id_int_1 = prh.requisition_header_id
         AND prh.segment1 = p_transaction_number
         AND xte.application_id = 201
         and prh.org_id = p_org_id
         AND xte.entity_id = xe.entity_id
         AND xe.EVENT_STATUS_CODE = 'U'
         AND xe.PROCESS_STATUS_CODE in ('D', 'I');
  begin
    FOR draft_event IN c_draft_event LOOP

      l_Message := 'Processing  ' || ' requisition_header_id : ' ||
                   draft_event.requisition_header_id || ' Req Number : ' ||
                   draft_event.segment1 || ' org_id : ' ||
                   draft_event.org_id || ' event_id : ' ||
                   draft_event.event_id;
      fnd_file.Put_Line(fnd_file.LOG, l_Message);

      PO_MOAC_UTILS_PVT.set_org_context(draft_event.org_id);

      SELECT set_of_books_id
        INTO l_ledger_id
        FROM hr_operating_units hou
       WHERE hou.organization_id = draft_event.org_id;

      l_legal_entity_id := xle_utilities_grp.Get_DefaultLegalContext_OU(draft_event.org_id);

      l_event_source_info.source_application_id := NULL;
      l_event_source_info.application_id        := 201;
      l_event_source_info.legal_entity_id       := l_legal_entity_id;
      l_event_source_info.ledger_id             := l_ledger_id;
      l_event_source_info.entity_type_code      := 'REQUISITION';
      l_event_source_info.transaction_number    := draft_event.segment1; -- Segment1
      l_event_source_info.source_id_int_1       := draft_event.requisition_header_id; -- Req_header_id
      l_security_context.security_id_int_1      := draft_event.org_id; -- Org_id

      xla_events_pub_pkg.DELETE_EVENT(l_event_source_info,
                                      draft_event.event_id,
                                      NULL,
                                      l_security_context);

      fnd_file.Put_Line(fnd_file.LOG,
                        ' Event Deleted : ' || draft_event.event_id);

      DELETE FROM PO_BC_DISTRIBUTIONS
       WHERE ae_event_id = draft_event.event_id;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.Put_Line(fnd_file.LOG, 'Some exception occured ' || SQLERRM);

      ROLLBACK;
  end clear_Invalid_Events_REQ;
  -----------------------------------------------------------------
end xx_xla_events_util;
/

