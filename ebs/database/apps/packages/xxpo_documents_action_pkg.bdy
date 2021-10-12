CREATE OR REPLACE PACKAGE BODY APPS.xxpo_documents_action_pkg IS
  --------------------------------------------------------------------
  --  name:              XXPO_DOCUMENTS_ACTION_PKG
  --  create by:         XXX
  --  Revision:          1.7
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver    date          name              desc
  --  1.0    xx/xx/xxxx    XXXX              initial build
  --  1.x    14.04.2013    yoram zamir       modify close po
  --  1.1    25.04.2013    yuval tal         modify close po - bugfix
  --  1.2    04.12.2014    mmazanet          Added the following procedures for
  --                                         CHG0032431... write_log, close_po_pub, auto_close_po
  --  1.3    26/01/2015    Dalit A. Raviv    CHG0034145 - change close PO to Cancel,
  --                                         close PO do not release the encumbrance, cancel do.
  --                                         change cursor population to only expense lines
  --                                         Add 3 fields to log mail.
  --  1.4    25/02/2015    Dalit A. Raviv    CHG0034191 - add procedure approve_po_for_kanban
  --                                         Automatically PO approval process approve_po_for_kanban
  --  1.5    02-Mar-2016   Lingaraj Sarangi  CHG0037860- Change  for Auto approve Blanket release for MIN-MAX PRs
  --                                         Procedure changed - approve_po_for_kanban

  -- 1.6     17-Jul-2016  Sandeep Sapru      CHG0038856 - XXPO Kanban Approve Blanket Release - limit to Blanket line agreed qty
  -- 1.7     8-Sep-2016   Yuval.Tal          INC0075201 - PO Format
  --                                         Change 1.6 having a Bug in "approve_po_for_kanban" PROCEDURE, So The fix applied for that
  --  1.8    12-Jan-2017  Nishant Kumar      INC0084856 - Only "Approved" Blanket Agreement in consideration for "Incomplete" releases
  --  1.9    1.1.18       yuval tal          INC0110709 - modify resend_notification
  --  2.1    21-May-2018  Bellona(TCS)       CHG0042927 - Replace list_name with full_name for approving incomplete PO release
  --  2.2    03-SEP-2018  Bellona(TCS)       CHG0043481 - PO Action History - removal of Truncated Action Date time stamp for 3 programs
  --												1.	XX: Update PO Status to Incomplete -> procedure - UPDATE_PO_TO_INCOMPLETE
  --												2.	XX: Update PO Release Status to Incomplete -> procedure - abort_po_rel2incomplete
  --												3.  XX: Update Requisition Status to Incomplete -> procedure - UPDATE_REQ_STATUS
  --  2.3    08-Aug-2018  Hubert, Eric       CHG0043721 - Added procedures, auto_finally_close_po and finally_close_po_pub, to Finally Close POs.
  --------------------------------------------------------------------

  g_log        VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0032431.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN
    IF g_log = 'Y' AND 'xxpo.documents_action.xxpo_documents_action_pkg' LIKE
       lower(g_log_module) THEN
      fnd_file.put_line(fnd_file.log,
    to_char(SYSDATE, 'HH:MI:SS') || ' - ' || p_msg);
    END IF;
  END write_log;

  --------------------------------------------------------------------
  --  name:              cancel_po_pub
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     26/01/2015
  --------------------------------------------------------------------
  --  purpose :          Generic cancle procedure for POs and Po line
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  26/01/2015    Dalit A. Raviv    Initial Creation CHG0034145
  --------------------------------------------------------------------
  PROCEDURE cancel_po_pub(p_po_type        IN VARCHAR2,
      p_po_header_id   IN NUMBER,
      p_po_line_id     IN NUMBER,
      p_close_reason   IN VARCHAR2,
      x_return_status  OUT VARCHAR2,
      x_return_message OUT VARCHAR2) IS

    l_doctyp         po_document_types_v.document_type_code%TYPE;
    l_docsubtyp      po_document_types_v.document_subtype%TYPE;
    l_po_number      po_headers_all.segment1%TYPE := NULL;
    l_line_num       po_lines_all.line_num%TYPE := NULL;
    l_return_message VARCHAR2(32000) := NULL;
    l_msg_index      NUMBER := NULL;
    l_msg_data       VARCHAR2(32000) := NULL;

  BEGIN
    /*
    fnd_global.apps_initialize (user_id => 2470,resp_id => 50877,resp_appl_id =>201);
    mo_global.set_org_context  (p_org_id_char     => 81,
                                p_sp_id_char      => NULL,
                                p_appl_short_name => 'PO');
    */
    write_log('cancel_po_pub for p_po_type: ' || p_po_type ||
    ' p_po_header_id: ' || p_po_header_id || ' p_po_line_id: ' ||
    p_po_line_id);

    apps.po_notifications_sv2.get_doc_type_subtype(x_notif_doc_type => p_po_type,
           x_type           => l_doctyp,
           x_subtype        => l_docsubtyp);
    write_log('l_doctyp   : ' || l_doctyp);
    write_log('l_docsubtyp: ' || l_docsubtyp);

    IF p_po_header_id IS NOT NULL THEN
      po_document_control_pub.control_document(p_api_version      => 1.0,
                 p_init_msg_list    => 'T',
                 p_commit           => 'F',
                 x_return_status    => x_return_status,
                 p_doc_type         => l_doctyp, -- 'PO'
                 p_doc_subtype      => l_docsubtyp, -- 'STANDARD'
                 p_doc_id           => p_po_header_id, -- 339556, 340069
                 p_doc_num          => /*l_po_number*/ NULL, -- '100040133', '100040255'
                 p_release_id       => NULL,
                 p_release_num      => NULL,
                 p_doc_line_id      => p_po_line_id, -- 403610
                 p_doc_line_num     => /*l_line_num*/ NULL, -- 3
                 p_doc_line_loc_id  => NULL,
                 p_doc_shipment_num => NULL,
                 p_action           => 'CANCEL',
                 p_action_date      => SYSDATE,
                 p_cancel_reason    => p_close_reason,
                 p_cancel_reqs_flag => 'Y',
                 p_print_flag       => 'N',
                 p_note_to_vendor   => '', -- should be null maybee to put p_close_reason
                 p_use_gldate       => 'Y');

      IF x_return_status <> 'S' THEN
        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
          fnd_msg_pub.get(p_msg_index     => i,
      p_encoded       => 'F',
      p_data          => l_msg_data,
      p_msg_index_out => l_msg_index);

          IF l_return_message IS NOT NULL THEN
  l_return_message := l_return_message || l_msg_data;
          ELSE
  l_return_message := l_msg_data;
          END IF;
        END LOOP;
        fnd_file.put_line(fnd_file.log,
      '--- PO ' || l_po_number || ' , line ' ||
      l_line_num);
        fnd_file.put_line(fnd_file.log, l_return_message);
        x_return_message := l_return_message;
        x_return_status  := 'E';
        ROLLBACK;
      ELSE
        x_return_status := 'S';
        COMMIT;
      END IF;
    ELSE
      x_return_status  := 'E';
      x_return_message := 'Can not Cancel Po when PO_Header_id is null';
    END IF;
    write_log('End cancel_po_pub');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status  := 'E';
      x_return_message := 'Unexpected error occurred in cancel_po_pub: ' ||
      dbms_utility.format_error_stack;
  END cancel_po_pub;

  --------------------------------------------------------------------
  --  name:              close_po_pub
  --  create by:         MMAZANET
  --  Revision:          1.6
  --  creation date:     25.11.14
  --------------------------------------------------------------------
  --  purpose :          Generic close procedure for POs
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  25.11.14      MMAZANET          Initial Creation for CHG0032431.
  --------------------------------------------------------------------
  PROCEDURE close_po_pub(p_po_type        IN VARCHAR2,
     p_po_header_id   IN NUMBER,
     p_po_line_id     IN NUMBER,
     p_close_reason   IN VARCHAR2,
     x_return_status  OUT VARCHAR2,
     x_return_message OUT VARCHAR2) IS
    l_doctyp        po_document_types_v.document_type_code%TYPE;
    l_docsubtyp     po_document_types_v.document_subtype%TYPE;
    l_po_close_flag BOOLEAN := FALSE;
    l_return_code   VARCHAR2(1);
  BEGIN
    write_log('close_po_pub for p_po_type: ' || p_po_type ||
    ' p_po_header_id: ' || p_po_header_id || ' p_po_line_id: ' ||
    p_po_line_id);

    apps.po_notifications_sv2.get_doc_type_subtype(x_notif_doc_type => p_po_type,
           x_type           => l_doctyp,
           x_subtype        => l_docsubtyp);

    write_log('l_doctyp   : ' || l_doctyp);
    write_log('l_docsubtyp: ' || l_docsubtyp);

    l_po_close_flag := apps.po_actions.close_po(p_docid        => p_po_header_id, -- PO_Header_Id
        p_doctyp       => l_doctyp, -- Doc Type (PO, PA etc.)
        p_docsubtyp    => l_docsubtyp, -- Doc Subtype (STANDRD, BLANKET etc.)
        p_lineid       => p_po_line_id, -- PO_Line_ID
        p_shipid       => NULL, -- PO_Line_Location_Id
        p_action       => 'CLOSE',
        p_reason       => p_close_reason,
        p_calling_mode => 'PO',
        p_conc_flag    => 'Y', -- 'N'
        p_return_code  => l_return_code,
        p_auto_close   => 'N', -- manual Close
        p_action_date  => SYSDATE);

    IF l_po_close_flag THEN
      x_return_status := 'S';
    ELSE
      x_return_status  := 'E';
      x_return_message := 'Line could not be closed, or may already be closed';
    END IF;

    write_log('End close_po_pub');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status  := 'E';
      x_return_message := 'Unexpected error occurred in close_po_generic: ' ||
      dbms_utility.format_error_stack;
  END close_po_pub;

  --------------------------------------------------------------------
  --  name:              finally_close_po_pub
  --  created by:        Hubert, Eric
  --  Revision:          1.0
  --  creation date:     08-Aug-2018
  --------------------------------------------------------------------
  --  purpose :          Generic finally close procedure for POs
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  08-Aug-2018   Hubert, Eric      Initial Creation for CHG0043721.
  --------------------------------------------------------------------
  PROCEDURE finally_close_po_pub(p_po_type        IN VARCHAR2,
     p_po_header_id   IN NUMBER,
     p_po_line_id     IN NUMBER,
     p_close_reason   IN VARCHAR2,
     x_return_status  OUT VARCHAR2,
     x_return_message OUT VARCHAR2) IS
    l_doctyp        po_document_types_v.document_type_code%TYPE;
    l_docsubtyp     po_document_types_v.document_subtype%TYPE;
    l_po_close_flag BOOLEAN := FALSE;
    l_return_code   VARCHAR2(1);
  BEGIN
    write_log('finally_close_po_pub for p_po_type: ' || p_po_type ||
    ' p_po_header_id: ' || p_po_header_id || ' p_po_line_id: ' ||
    p_po_line_id);

    apps.po_notifications_sv2.get_doc_type_subtype(x_notif_doc_type => p_po_type,
           x_type           => l_doctyp,
           x_subtype        => l_docsubtyp);

    write_log('l_doctyp   : ' || l_doctyp);
    write_log('l_docsubtyp: ' || l_docsubtyp);

    l_po_close_flag := apps.po_actions.close_po(p_docid        => p_po_header_id, -- PO_Header_Id
        p_doctyp       => l_doctyp, -- Doc Type (PO, PA etc.)
        p_docsubtyp    => l_docsubtyp, -- Doc Subtype (STANDARD, BLANKET etc.)
        p_lineid       => p_po_line_id, -- PO_Line_ID
        p_shipid       => NULL, -- PO_Line_Location_Id
        p_action       => 'FINALLY CLOSE',
        p_reason       => p_close_reason,
        p_calling_mode => 'PO',
        p_conc_flag    => 'Y', -- 'N'
        p_return_code  => l_return_code,
        p_auto_close   => 'N', -- manual Close
        p_action_date  => SYSDATE);

    IF l_po_close_flag THEN
      x_return_status := 'S';
    ELSE
      x_return_status  := 'E';
      x_return_message := 'Line could not be finally closed, or may already be finally closed';
    END IF;

    write_log('End finally_close_po_pub');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status  := 'E';
      x_return_message := 'Unexpected error occurred in finally_close_po_pub: ' ||
      dbms_utility.format_error_stack;
  END finally_close_po_pub;


  --------------------------------------------------------------------------
  -- auto_close_po
  --------------------------------------------------------------------------
  -- Purpose: This procedure is used to close POs automatically.  This can
  --          be done in one of two ways.  First, it can close based on the
  --          first part of the UNION from the c_po CURSOR.  These are records
  --          that are considered open POs.  Second, it can
  --          close based on the custom table xxpo_documents_custom_load,
  --          which is loaded from a csv.  The p_po_source parameter determines
  --          which half of the union is called.
  --
  -- Params:
  --          p_po_source
  --            Set to DB to close open POs (first part of UNION of c_po CURSOR)
  --            Set to CSV to close POs from xxpo_documents_custom_load table
  --            (second part of UNION of c_po CURSOR)
  --          p_org_id
  --            Operating Unit to run program for.  -9 means run for all
  --          p_po_type
  --            Purchase document type for closure.
  --          p_days_tolerance
  --            Used to limit which POs will close
  --          p_burst_flag
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_default_email
  --            The PO requestor or PO buyer (if requestor is NULL) will be
  --            notified if their PO is closed.  However, if the PO can not
  --            be closed, the p_default_email person will be notified, if
  --            one is specified.
  --          p_key_col
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_report_title
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_email_subject
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_email_body
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_file_name
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_purge_table
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_load_file_name
  --            If p_po_source is CSV, we need to specify the csv file name
  --          p_load_file_dir
  --            If p_po_source is CSV, we need to specify the csv location
  --          p_test_report
  --            Allows to run the program without calling the po close API.
  --            This will show what the program will attempt to close.
  --          p_use_default_email
  --            This will send output from xxssys_generic_rpt_pkg.submit_request
  --            to the p_default_email.  This is for testing as everything
  --            goes to oradev in development environments.
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ------------------------------------
  -- 1.1      25.11.14  mmazanet        Initial creation for CHG0032431.
  --------------------------------------------------------------------------
  PROCEDURE auto_close_po(errbuff             OUT VARCHAR2,
      retcode             OUT VARCHAR2,
      p_po_source         IN VARCHAR2,
      p_org_id            IN NUMBER,
      p_po_type           IN VARCHAR2 DEFAULT NULL,
      p_days_tolerance    IN VARCHAR2 DEFAULT 0,
      p_burst_flag        IN VARCHAR2,
      p_default_email     IN VARCHAR2,
      p_key_col           IN VARCHAR2,
      p_report_title      IN VARCHAR2,
      p_report_pre_text1  IN VARCHAR2,
      p_report_pre_text2  IN VARCHAR2,
      p_email_subject     IN VARCHAR2,
      p_email_body        IN VARCHAR2,
      p_file_name         IN VARCHAR2,
      p_purge_table       IN VARCHAR2,
      p_load_file_name    IN VARCHAR2 DEFAULT NULL,
      p_load_file_dir     IN VARCHAR2 DEFAULT NULL,
      p_test_report       IN VARCHAR2,
      p_use_default_email IN VARCHAR2) IS
    CURSOR c_po IS
    -- Open POs eligible for closure
      SELECT poh.po_header_id po_header_id,
   pol.po_line_id po_line_id,
   pol.line_num po_line_num,
   poh.segment1 po_number,
   poh.type_lookup_code po_type,
   poh.org_id po_org_id,
   papf.email_address po_buyer_email,
   papf.first_name || ' ' || papf.last_name po_buyer_name
      FROM   po_headers_all     poh,
   po_lines_all       pol,
   hr_operating_units hou,
   per_all_people_f   papf
      WHERE  poh.org_id = decode(p_org_id, -9, poh.org_id, p_org_id)
      AND    poh.po_header_id = pol.po_header_id
      AND    pol.org_id = decode(p_org_id, -9, pol.org_id, p_org_id)
      AND    poh.closed_code = 'OPEN'
      AND    po_headers_sv3.get_po_status(poh.po_header_id)
  -- 'Approved, Reserved' added for companies that use encumbrance
  IN ('Approved', 'Approved, Reserved')
      AND    poh.type_lookup_code =
   decode(p_po_type, 'ALL', poh.type_lookup_code, p_po_type)
      AND    nvl(poh.attribute4, 'N') <> 'Y'
      AND    trunc(poh.creation_date + p_days_tolerance) <= trunc(SYSDATE)
      AND    NOT EXISTS
       (SELECT 'PO Invoiced with in thershold days'
    FROM   po_distributions_all         pda,
           ap_invoice_distributions_all aida,
           ap_invoices_all              aia
    WHERE  poh.po_header_id = pda.po_header_id
    AND    pda.org_id = decode(p_org_id, -9, pda.org_id, p_org_id)
    AND    pda.po_distribution_id = aida.po_distribution_id
    AND    aida.org_id =
           decode(p_org_id, -9, aida.org_id, p_org_id)
    AND    aida.invoice_id = aia.invoice_id
    AND    aia.org_id = decode(p_org_id, -9, aia.org_id, p_org_id)
    AND    trunc(aia.creation_date + p_days_tolerance) >=
           trunc(SYSDATE)
    AND    trunc(aia.invoice_date + p_days_tolerance) >=
           trunc(SYSDATE))
      AND    poh.org_id = hou.organization_id
      AND    poh.agent_id = papf.person_id(+)
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date(+) AND
   papf.effective_end_date(+)
      AND    p_po_source = 'DB'
      UNION ALL
      -- POs from csv
      SELECT po.po_header_id     po_header_id,
   po.po_line_id       po_line_id,
   xdcl.po_line_number po_line_num,
   xdcl.po_number      po_number,
   xdcl.po_type        po_type,
   po.po_org_id        po_org_id,
   po.po_buyer_email   po_buyer_email,
   po.po_buyer_name    po_buyer_name
      FROM   /* po... */
   (SELECT poh.po_header_id po_header_id,
           pol.po_line_id po_line_id,
           pol.line_num po_line_num,
           poh.segment1 po_number,
           poh.type_lookup_code po_type,
           poh.org_id po_org_id,
           papf.email_address po_buyer_email,
           papf.first_name || ' ' || papf.last_name po_buyer_name
    FROM   po_headers_all     poh,
           po_lines_all       pol,
           hr_operating_units hou,
           per_all_people_f   papf
    WHERE  poh.org_id = decode(p_org_id, -9, poh.org_id, p_org_id)
    AND    poh.po_header_id = pol.po_header_id
    AND    pol.org_id = decode(p_org_id, -9, pol.org_id, p_org_id)
    AND    poh.org_id = hou.organization_id
    AND    poh.agent_id = papf.person_id(+)
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date(+) AND
           papf.effective_end_date(+)
    AND    nvl(poh.attribute4, 'N') <> 'Y') po,
   /* ...po */
   -- custom table
   xxpo_documents_custom_load xdcl
      WHERE  xdcl.po_number = po.po_number(+)
      AND    xdcl.po_type = po.po_type(+)
      AND    xdcl.po_line_number = po.po_line_num(+)
      AND    p_po_source = 'CSV'
      ORDER  BY po_number,
      po_line_num;

    CURSOR c_po_requestor(p_po_line_id NUMBER) IS
    -- Generates a list of email addresses.  DISTINCT ensures we won't get the same address twice.
      SELECT DISTINCT papf.email_address email_address,
            papf.first_name || ' ' || papf.last_name full_name
      FROM   po_distributions_all pda,
   per_all_people_f     papf
      WHERE  pda.org_id = decode(p_org_id, -9, pda.org_id, p_org_id)
      AND    pda.po_line_id = p_po_line_id
      AND    pda.deliver_to_person_id = papf.person_id
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
   papf.effective_end_date;

    l_error_prog_flag VARCHAR2(1) := 'N';
    l_return_status   VARCHAR2(1);
    l_msg             VARCHAR2(500);
    l_email_string    VARCHAR2(1000);
    l_email           VARCHAR2(250);
    l_name_string     VARCHAR2(1000);
    l_name            VARCHAR2(250);
    l_records_exist   VARCHAR2(1) := 'N';

    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_curr_request_id        NUMBER := fnd_profile.value('CONC_REQUEST_ID');
    l_email_is_valid_flag    VARCHAR2(1);
    l_invalid_email_list     VARCHAR2(500);

    l_retcode VARCHAR2(1);

    e_error EXCEPTION;
  BEGIN
    errbuff := NULL;
    write_log('Begin auto_close_invoiced_po');
    fnd_file.put_line(fnd_file.log, to_char(userenv('SESSIONID')));

    -- Load xxpo_documents_custom_load table from csv
    IF p_po_source = 'CSV' THEN
      write_log('Loading ');

      -- Clear out existing records
      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXPO_DOCUMENTS_CUSTOM_LOAD';

      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_msg,
               retcode                => l_retcode,
               p_table_name           => 'XXPO_DOCUMENTS_CUSTOM_LOAD',
               p_template_name        => 'DEFAULT',
               p_file_name            => p_load_file_name,
               p_directory            => p_load_file_dir,
               p_expected_num_of_rows => to_number(NULL));

      IF l_retcode <> 0 THEN
        RAISE e_error;
      END IF;
    END IF;

    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
    l_xxssys_generic_rpt_rec.col1            := 'PO NUMBER';
    l_xxssys_generic_rpt_rec.col2            := 'PO LINE NUMBER';
    l_xxssys_generic_rpt_rec.col3            := 'PO TYPE';
    l_xxssys_generic_rpt_rec.col4            := 'PO_REQUESTER';
    l_xxssys_generic_rpt_rec.col_msg         := 'MESSAGE';

    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
          x_return_status          => l_return_status,
          x_return_message         => l_msg);

    IF l_return_status <> 'S' THEN
      --l_error_prog_flag := 'Y';
      RAISE e_error;
    END IF;

    FOR rec IN c_po LOOP
      BEGIN
        l_msg           := NULL;
        l_records_exist := 'Y';

        write_log('*** Begin loop for po_number ' || rec.po_number ||
        ' po_line_number ' || rec.po_line_num || ' po_type ' ||
        rec.po_type || ' ***');

        write_log('p_po_source      : ' || p_po_source);
        write_log('rec.po_header_id : ' || rec.po_header_id);

        -- CHECK p_po_source = 'CSV' record exists
        IF p_po_source = 'CSV' AND rec.po_header_id IS NULL THEN
          l_msg := 'Error: Record does not exist in Oracle PO tables';
          RAISE e_error;
        END IF;

        -- Determines wether or not to call the close API
        IF p_test_report = 'N' THEN
          -- Calls Oracle's standard close API
          close_po_pub(p_po_type        => rec.po_type,
             p_po_header_id   => rec.po_header_id,
             p_po_line_id     => rec.po_line_id,
             p_close_reason   => 'System Autoclosed ' ||
             to_char(trunc(SYSDATE)),
             x_return_status  => l_return_status,
             x_return_message => l_msg);

          IF l_return_status <> 'S' THEN
  RAISE e_error;
          END IF;
        END IF;

        -- Find email(s) for requestor
        l_email_string := NULL;
        l_name_string  := NULL;
        FOR rec_email IN c_po_requestor(rec.po_line_id) LOOP
          l_email        := rec_email.email_address;
          l_name         := rec_email.full_name;
          l_email_string := l_email_string || l_email || ',';
          l_name_string  := l_name_string || l_name || ',';
        END LOOP;
        -- remove last comma
        l_email_string := regexp_replace(l_email_string, '\s*,\s*$', '');
        l_name_string  := regexp_replace(l_name_string, '\s*,\s*$', '');

        -- If no requestor email, set to the buyer email
        IF l_email_string IS NULL THEN
          l_email_string := rec.po_buyer_email;
          l_name_string  := rec.po_buyer_name;
        END IF;

        write_log('l_email_string : ' || l_email_string);
        write_log('l_name_string  : ' || l_name_string);

      EXCEPTION
        WHEN e_error THEN
          l_error_prog_flag := 'Y';
        WHEN OTHERS THEN
          l_error_prog_flag := 'Y';
          l_msg             := 'Unexpected error occurred in c_po CURSOR loop: ' ||
           dbms_utility.format_error_stack;
      END;

      -- If there is an error or no email, send to the p_default_email
      IF l_msg IS NOT NULL OR l_email_string IS NULL THEN
        l_email_string := p_default_email;
      END IF;

      write_log('l_email_string: ' || l_email_string);

      xxobjt_general_utils_pkg.validate_mail_list(p_mail_list             => l_email_string,
          p_is_list_valid         => l_email_is_valid_flag,
          p_out_valid_mail_list   => l_email_string,
          p_out_invalid_mail_list => l_invalid_email_list);

      write_log('l_email_string (after validation): ' || l_email_string);
      write_log('l_email_is_valid_flag            : ' ||
      l_email_is_valid_flag);
      write_log('l_invalid_email_list             : ' ||
      l_invalid_email_list);

      IF l_email_is_valid_flag = 'N' THEN
        l_msg := l_msg || ' The following emails are invalid: ' ||
       l_invalid_email_list;
      END IF;

      -- if param set to 'Y', override email string
      IF p_use_default_email = 'Y' THEN
        l_email_string := p_default_email;
      END IF;

      -- Set output report detail rows
      l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.email_to        := l_email_string;
      l_xxssys_generic_rpt_rec.col1            := rec.po_number;
      l_xxssys_generic_rpt_rec.col2            := rec.po_line_num;
      l_xxssys_generic_rpt_rec.col3            := rec.po_type;
      l_xxssys_generic_rpt_rec.col4            := l_name_string;
      l_xxssys_generic_rpt_rec.col_msg         := l_msg;

      write_log('Write to xxsys_generic_rpt');

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
            x_return_status          => l_return_status,
            x_return_message         => l_msg);

      IF l_return_status <> 'S' THEN
        l_error_prog_flag := 'Y';
        fnd_file.put_line(fnd_file.output, l_msg);
      END IF;
      write_log('*** End loop ***');
    END LOOP;

    IF l_records_exist = 'Y' THEN

      write_log('Submit xxssys_generic_rpt_pkg.submit_request');
      -- Submit output report to be emailed out, if records were processed
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => p_burst_flag,
              p_request_id         => l_curr_request_id,
              p_l_report_title     => p_report_title,
              p_l_report_pre_text1 => p_report_pre_text1,
              p_l_report_pre_text2 => p_report_pre_text2,
              p_l_email_subject    => p_email_subject,
              p_l_email_body1      => p_email_body,
              -- Since col2 is a VARCHAR2 field holding a number, we need to modify
              -- the ORDER BY to put a TO_NUMBER around the field.
              p_l_order_by         => ' key_col, col1, TO_NUMBER(col2), col3',
              p_l_file_name        => p_file_name,
              p_l_key_column       => p_key_col,
              p_l_purge_table_flag => p_purge_table,
              x_return_status      => l_return_status,
              x_return_message     => l_msg);

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;
    END IF;

    write_log('End auto_close_invoiced_po');
  EXCEPTION
    WHEN e_error THEN
      retcode := 2;
      errbuff := 'error occurred in auto_close_po';
      fnd_file.put_line(fnd_file.output, l_msg);
    WHEN OTHERS THEN
      retcode := 2;
      errbuff := 'Unexpected error occurred in auto_close_po';
      fnd_file.put_line(fnd_file.output,
    'Unexpected error occurred in auto_close_po: ' ||
    dbms_utility.format_error_stack);
  END auto_close_po;

  --------------------------------------------------------------------------
  -- auto_finally_close_po
  --------------------------------------------------------------------------
  -- Purpose: This procedure is used to finally close POs automatically.  It can
  --          finally close based on the custom table xxpo_documents_custom_load,
  --          which is loaded from a csv.  The p_po_source parameter determines
  --          which half of the union is called.
  --
  --          Unlike the auto_close_po procedure which has the capability to "find"
  --          POs that should be closed, we do not have that functionality with 
  --          this procedure since we want the business users to explicitly
  --          list which PO lines need to be finally closed (using a CSV file).
  --          Therefore, the p_days_tolerance parameter used in auto_close_po
  --          is not utilized for auto_finally_close.
  --
  -- Params:
  --          p_po_source
  --            Set to DB to close open POs (first part of UNION of c_po CURSOR)
  --            Set to CSV to close POs from xxpo_documents_custom_load table
  --            (second part of UNION of c_po CURSOR)
  --          p_org_id
  --            Operating Unit to run program for.  -9 means run for all
  --          p_po_type
  --            Purchase document type for closure.
  --          p_burst_flag
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_default_email
  --            The PO requestor or PO buyer (if requestor is NULL) will be
  --            notified if their PO is closed.  However, if the PO can not
  --            be closed, the p_default_email person will be notified, if
  --            one is specified.
  --          p_key_col
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_report_title
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_email_subject
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_email_body
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_file_name
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_purge_table
  --            Used in call to xxssys_generic_rpt_pkg.submit_request
  --          p_load_file_name
  --            If p_po_source is CSV, we need to specify the csv file name
  --          p_load_file_dir
  --            If p_po_source is CSV, we need to specify the csv location
  --          p_test_report
  --            Allows to run the program without calling the po close API.
  --            This will show what the program will attempt to close.
  --          p_use_default_email
  --            This will send output from xxssys_generic_rpt_pkg.submit_request
  --            to the p_default_email.  This is for testing as everything
  --            goes to oradev in development environments.
  --------------------------------------------------------------------------
  -- Version  Date         Performer       Comments
  ----------  -----------  --------------  ------------------------------------
  -- 1.1      08-Aug-2018  Hubert, Eric    Initial creation for CHG0043721.
  --------------------------------------------------------------------------
  PROCEDURE auto_finally_close_po(errbuff             OUT VARCHAR2,
      retcode             OUT VARCHAR2,
      p_po_source         IN VARCHAR2,
      p_org_id            IN NUMBER,
      p_po_type           IN VARCHAR2 DEFAULT NULL,
      p_burst_flag        IN VARCHAR2,
      p_default_email     IN VARCHAR2,
      p_key_col           IN VARCHAR2,
      p_report_title      IN VARCHAR2,
      p_report_pre_text1  IN VARCHAR2,
      p_report_pre_text2  IN VARCHAR2,
      p_email_subject     IN VARCHAR2,
      p_email_body        IN VARCHAR2,
      p_file_name         IN VARCHAR2,
      p_purge_table       IN VARCHAR2,
      p_load_file_name    IN VARCHAR2 DEFAULT NULL,
      p_load_file_dir     IN VARCHAR2 DEFAULT NULL,
      p_test_report       IN VARCHAR2,
      p_use_default_email IN VARCHAR2) IS
    CURSOR c_po IS
    -- POs from CSV file loaded to xxpo_documents_custom_load, and related header/line attributes
      SELECT po.po_header_id     po_header_id,
   po.po_line_id       po_line_id,
   xdcl.po_line_number po_line_num,
   xdcl.po_number      po_number,
   xdcl.po_type        po_type,
   po.po_org_id        po_org_id,
   po.po_buyer_email   po_buyer_email,
   po.po_buyer_name    po_buyer_name
      FROM   /* po... */
   (SELECT poh.po_header_id po_header_id,
           pol.po_line_id po_line_id,
           pol.line_num po_line_num,
           poh.segment1 po_number,
           poh.type_lookup_code po_type,
           poh.org_id po_org_id,
           papf.email_address po_buyer_email,
           papf.first_name || ' ' || papf.last_name po_buyer_name
    FROM   po_headers_all     poh,
           po_lines_all       pol,
           hr_operating_units hou,
           per_all_people_f   papf
    WHERE  poh.org_id = decode(p_org_id, -9, poh.org_id, p_org_id)
    AND    poh.po_header_id = pol.po_header_id
    AND    pol.org_id = decode(p_org_id, -9, pol.org_id, p_org_id)
    AND    poh.org_id = hou.organization_id
    AND    poh.agent_id = papf.person_id(+)
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date(+) AND
           papf.effective_end_date(+)
    AND    nvl(poh.attribute4, 'N') <> 'Y') po,
   /* ...po */
   -- custom table
   xxpo_documents_custom_load xdcl
      WHERE  xdcl.po_number = po.po_number(+)
      AND    xdcl.po_type = po.po_type(+)
      AND    xdcl.po_line_number = po.po_line_num(+)
      AND    p_po_source = 'CSV'
      ORDER  BY po_number,
      po_line_num;

    CURSOR c_po_requestor(p_po_line_id NUMBER) IS
    -- Generates a list of email addresses.  DISTINCT ensures we won't get the same address twice.
      SELECT DISTINCT papf.email_address email_address,
            papf.first_name || ' ' || papf.last_name full_name
      FROM   po_distributions_all pda,
   per_all_people_f     papf
      WHERE  pda.org_id = decode(p_org_id, -9, pda.org_id, p_org_id)
      AND    pda.po_line_id = p_po_line_id
      AND    pda.deliver_to_person_id = papf.person_id
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
   papf.effective_end_date;

    l_error_prog_flag VARCHAR2(1) := 'N';
    l_return_status   VARCHAR2(1);
    l_msg             VARCHAR2(500);
    l_email_string    VARCHAR2(1000);
    l_email           VARCHAR2(250);
    l_name_string     VARCHAR2(1000);
    l_name            VARCHAR2(250);
    l_records_exist   VARCHAR2(1) := 'N';

    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_curr_request_id        NUMBER := fnd_profile.value('CONC_REQUEST_ID');
    l_email_is_valid_flag    VARCHAR2(1);
    l_invalid_email_list     VARCHAR2(500);

    l_retcode VARCHAR2(1);

    e_error EXCEPTION;
  BEGIN
    errbuff := NULL;
    write_log('Begin auto_finally_close_po');
    fnd_file.put_line(fnd_file.log, to_char(userenv('SESSIONID')));

    -- Load xxpo_documents_custom_load table from csv
    IF p_po_source = 'CSV' THEN
      write_log('Loading ');

      -- Clear out existing records
      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXPO_DOCUMENTS_CUSTOM_LOAD';

      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_msg,
               retcode                => l_retcode,
               p_table_name           => 'XXPO_DOCUMENTS_CUSTOM_LOAD',
               p_template_name        => 'DEFAULT',
               p_file_name            => p_load_file_name,
               p_directory            => p_load_file_dir,
               p_expected_num_of_rows => to_number(NULL));

      IF l_retcode <> 0 THEN
        RAISE e_error;
      END IF;
    END IF;

    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
    l_xxssys_generic_rpt_rec.col1            := 'PO NUMBER';
    l_xxssys_generic_rpt_rec.col2            := 'PO LINE NUMBER';
    l_xxssys_generic_rpt_rec.col3            := 'PO TYPE';
    l_xxssys_generic_rpt_rec.col4            := 'PO_REQUESTER';
    l_xxssys_generic_rpt_rec.col_msg         := 'MESSAGE';

    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
          x_return_status          => l_return_status,
          x_return_message         => l_msg);

    IF l_return_status <> 'S' THEN
      --l_error_prog_flag := 'Y';
      RAISE e_error;
    END IF;

    FOR rec IN c_po LOOP
      BEGIN
        l_msg           := NULL;
        l_records_exist := 'Y';

        write_log('*** Begin loop for po_number ' || rec.po_number ||
        ' po_line_number ' || rec.po_line_num || ' po_type ' ||
        rec.po_type || ' ***');

        write_log('p_po_source      : ' || p_po_source);
        write_log('rec.po_header_id : ' || rec.po_header_id);

        -- CHECK p_po_source = 'CSV' record exists
        IF p_po_source = 'CSV' AND rec.po_header_id IS NULL THEN
          l_msg := 'Error: Record does not exist in Oracle PO tables';
          RAISE e_error;
        END IF;

        -- Determines wether or not to call the close API
        IF p_test_report = 'N' THEN
          -- Calls Oracle's standard close API
          finally_close_po_pub(p_po_type        => rec.po_type,
             p_po_header_id   => rec.po_header_id,
             p_po_line_id     => rec.po_line_id,
             p_close_reason   => 'System Auto Finally Closed ' ||
             to_char(trunc(SYSDATE)),
             x_return_status  => l_return_status,
             x_return_message => l_msg);

          IF l_return_status <> 'S' THEN
  RAISE e_error;
          END IF;
        END IF;

        -- Find email(s) for requestor
        l_email_string := NULL;
        l_name_string  := NULL;
        FOR rec_email IN c_po_requestor(rec.po_line_id) LOOP
          l_email        := rec_email.email_address;
          l_name         := rec_email.full_name;
          l_email_string := l_email_string || l_email || ',';
          l_name_string  := l_name_string || l_name || ',';
        END LOOP;
        -- remove last comma
        l_email_string := regexp_replace(l_email_string, '\s*,\s*$', '');
        l_name_string  := regexp_replace(l_name_string, '\s*,\s*$', '');

        -- If no requestor email, set to the buyer email
        IF l_email_string IS NULL THEN
          l_email_string := rec.po_buyer_email;
          l_name_string  := rec.po_buyer_name;
        END IF;

        write_log('l_email_string : ' || l_email_string);
        write_log('l_name_string  : ' || l_name_string);

      EXCEPTION
        WHEN e_error THEN
          l_error_prog_flag := 'Y';
        WHEN OTHERS THEN
          l_error_prog_flag := 'Y';
          l_msg             := 'Unexpected error occurred in c_po CURSOR loop: ' ||
           dbms_utility.format_error_stack;
      END;

      -- If there is an error or no email, send to the p_default_email
      IF l_msg IS NOT NULL OR l_email_string IS NULL THEN
        l_email_string := p_default_email;
      END IF;

      write_log('l_email_string: ' || l_email_string);

      xxobjt_general_utils_pkg.validate_mail_list(p_mail_list             => l_email_string,
          p_is_list_valid         => l_email_is_valid_flag,
          p_out_valid_mail_list   => l_email_string,
          p_out_invalid_mail_list => l_invalid_email_list);

      write_log('l_email_string (after validation): ' || l_email_string);
      write_log('l_email_is_valid_flag            : ' ||
      l_email_is_valid_flag);
      write_log('l_invalid_email_list             : ' ||
      l_invalid_email_list);

      IF l_email_is_valid_flag = 'N' THEN
        l_msg := l_msg || ' The following emails are invalid: ' ||
       l_invalid_email_list;
      END IF;

      -- if param set to 'Y', override email string
      IF p_use_default_email = 'Y' THEN
        l_email_string := p_default_email;
      END IF;

      -- Set output report detail rows
      l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.email_to        := l_email_string;
      l_xxssys_generic_rpt_rec.col1            := rec.po_number;
      l_xxssys_generic_rpt_rec.col2            := rec.po_line_num;
      l_xxssys_generic_rpt_rec.col3            := rec.po_type;
      l_xxssys_generic_rpt_rec.col4            := l_name_string;
      l_xxssys_generic_rpt_rec.col_msg         := l_msg;

      write_log('Write to xxsys_generic_rpt');

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
            x_return_status          => l_return_status,
            x_return_message         => l_msg);

      IF l_return_status <> 'S' THEN
        l_error_prog_flag := 'Y';
        fnd_file.put_line(fnd_file.output, l_msg);
      END IF;
      write_log('*** End loop ***');
    END LOOP;

    IF l_records_exist = 'Y' THEN

      write_log('Submit xxssys_generic_rpt_pkg.submit_request');
      -- Submit output report to be emailed out, if records were processed
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => p_burst_flag,
              p_request_id         => l_curr_request_id,
              p_l_report_title     => p_report_title,
              p_l_report_pre_text1 => p_report_pre_text1,
              p_l_report_pre_text2 => p_report_pre_text2,
              p_l_email_subject    => p_email_subject,
              p_l_email_body1      => p_email_body,
              -- Since col2 is a VARCHAR2 field holding a number, we need to modify
              -- the ORDER BY to put a TO_NUMBER around the field.
              p_l_order_by         => ' key_col, col1, TO_NUMBER(col2), col3',
              p_l_file_name        => p_file_name,
              p_l_key_column       => p_key_col,
              p_l_purge_table_flag => p_purge_table,
              x_return_status      => l_return_status,
              x_return_message     => l_msg);

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;
    END IF;

    write_log('End auto_finally_close_po');
  EXCEPTION
    WHEN e_error THEN
      retcode := 2;
      errbuff := 'error occurred in auto_finally_close_po';
      fnd_file.put_line(fnd_file.output, l_msg);
    WHEN OTHERS THEN
      retcode := 2;
      errbuff := 'Unexpected error occurred in auto_finally_close_po';
      fnd_file.put_line(fnd_file.output,
    'Unexpected error occurred in auto_finally_close_po: ' ||
    dbms_utility.format_error_stack);
  END auto_finally_close_po;

  --------------------------------------------------------------------
  --  name:              auto_cancel_po
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     26/01/2015
  --------------------------------------------------------------------
  --  purpose :          This procedure is used to cancel PO liness automatically.  This can
  --                     be done in one of two ways. First, it can cancel lines based on the
  --                     first part of the UNION from the c_po CURSOR. These are records
  --                     that are considered open POs and EXPENSE type. Second, it can
  --                     cancel lines based on the custom table xxpo_documents_custom_load,
  --                     which is loaded from a csv. The p_po_source parameter determines
  --                     which half of the union is called.
  --                     NOTE - this program refer only to STANDARD PO
  --------------------------------------------------------------------
  --  Params:          p_po_source
  --                     Set to DB to close open POs (first part of UNION of c_po CURSOR)
  --                     Set to CSV to close POs from xxpo_documents_custom_load table
  --                     (second part of UNION of c_po CURSOR)
  --                   p_org_id
  --                     Operating Unit to run program for.  -9 means run for all
  --                   p_po_type
  --                     Purchase document type for closure.
  --                   p_days_tolerance
  --                     Used to limit which POs will close
  --                   p_burst_flag
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_default_email
  --                     The PO requestor or PO buyer (if requestor is NULL) will be
  --                     notified if their PO is closed.  However, if the PO can not
  --                     be closed, the p_default_email person will be notified, if
  --                     one is specified.
  --                   p_key_col
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_report_title
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_email_subject
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_email_body
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_file_name
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_purge_table
  --                     Used in call to xxssys_generic_rpt_pkg.submit_request
  --                   p_load_file_name
  --                     If p_po_source is CSV, we need to specify the csv file name
  --                   p_load_file_dir
  --                     If p_po_source is CSV, we need to specify the csv location
  --                   p_test_report
  --                     Allows to run the program without calling the po close API.
  --                     This will show what the program will attempt to close.
  --                   p_use_default_email
  --                     This will send output from xxssys_generic_rpt_pkg.submit_request
  --                     to the p_default_email.  This is for testing as everything
  --                     goes to oradev in development environments.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.2  26/01/2015    Dalit A. Raviv    CHG0034145 - add the ability to cancel PO lines.
  --                                       close PO do not release the encumbrance, cancel do.
  --                                       change cursor population to only expense lines.
  --                                       change the notification send to requestor and user run.
  --------------------------------------------------------------------
  PROCEDURE auto_cancel_po(errbuff             OUT VARCHAR2,
       retcode             OUT VARCHAR2,
       p_po_source         IN VARCHAR2,
       p_org_id            IN NUMBER,
       p_po_type           IN VARCHAR2 DEFAULT NULL,
       p_days_tolerance    IN VARCHAR2 DEFAULT 0,
       p_burst_flag        IN VARCHAR2,
       p_default_email     IN VARCHAR2,
       p_key_col           IN VARCHAR2,
       p_report_title      IN VARCHAR2,
       p_report_pre_text1  IN VARCHAR2,
       p_report_pre_text2  IN VARCHAR2,
       p_email_subject     IN VARCHAR2,
       p_email_body        IN VARCHAR2,
       p_file_name         IN VARCHAR2,
       p_purge_table       IN VARCHAR2,
       p_load_file_name    IN VARCHAR2 DEFAULT NULL,
       p_load_file_dir     IN VARCHAR2 DEFAULT NULL,
       p_test_report       IN VARCHAR2,
       p_use_default_email IN VARCHAR2,
       p_send_sum_report   IN VARCHAR2) IS
    CURSOR c_po IS
    -- Open POs eligible for closure
      SELECT poh.po_header_id po_header_id,
   pol.po_line_id po_line_id,
   pol.line_num po_line_num,
   poh.segment1 po_number,
   poh.type_lookup_code po_type,
   poh.org_id po_org_id,
   papf.email_address po_buyer_email,
   papf.first_name || ' ' || papf.last_name po_buyer_name,
   poh.vendor_id vendor_id,
   sup.vendor_name vendor_name
      FROM   po_headers_all     poh,
   po_lines_all       pol,
   hr_operating_units hou,
   per_all_people_f   papf,
   ap_suppliers       sup -- 1.2 26/01/2015 Dalit A. Raviv CHG0034145
      WHERE  poh.org_id = decode(p_org_id, -9, poh.org_id, p_org_id)
      AND    poh.po_header_id = pol.po_header_id
      AND    pol.org_id = decode(p_org_id, -9, pol.org_id, p_org_id)
      AND    nvl(poh.closed_code, 'OPEN') = 'OPEN'
  -- 1.2 26/01/2015 Dalit A. Raviv CHG0034145 - only expense lines we assum that all destinations will be the same for the same line.
      AND    nvl(xxpo_utils_pkg.get_po_destination(poh.po_header_id),
       'INV') = 'EXPENSE'
      AND    sup.vendor_id = poh.vendor_id
  --
      AND    po_headers_sv3.get_po_status(poh.po_header_id)
  -- 'Approved, Reserved' added for companies that use encumbrance
  IN ('Approved', 'Approved, Reserved')
      AND    poh.type_lookup_code =
   decode(p_po_type, 'ALL', poh.type_lookup_code, p_po_type)
      AND    nvl(poh.attribute4, 'N') <> 'Y'
      AND    trunc(poh.creation_date + p_days_tolerance) <= trunc(SYSDATE)
      AND    NOT EXISTS
       (SELECT 'PO Invoiced with in thershold days'
    FROM   po_distributions_all         pda,
           ap_invoice_distributions_all aida,
           ap_invoices_all              aia
    WHERE  poh.po_header_id = pda.po_header_id
    AND    pda.org_id = decode(p_org_id, -9, pda.org_id, p_org_id)
    AND    pda.po_distribution_id = aida.po_distribution_id
    AND    aida.org_id =
           decode(p_org_id, -9, aida.org_id, p_org_id)
    AND    aida.invoice_id = aia.invoice_id
    AND    aia.org_id = decode(p_org_id, -9, aia.org_id, p_org_id)
    AND    trunc(aia.creation_date + p_days_tolerance) >=
           trunc(SYSDATE)
    AND    trunc(aia.invoice_date + p_days_tolerance) >=
           trunc(SYSDATE))
      AND    poh.org_id = hou.organization_id
      AND    poh.agent_id = papf.person_id
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
   papf.effective_end_date
      AND    p_po_source = 'DB'
      UNION ALL
      -- POs from csv
      SELECT po.po_header_id     po_header_id,
   po.po_line_id       po_line_id,
   xdcl.po_line_number po_line_num,
   xdcl.po_number      po_number,
   po.po_type          po_type,
   --xdcl.po_type                 po_type,
   po.po_org_id      po_org_id,
   po.po_buyer_email po_buyer_email,
   po.po_buyer_name  po_buyer_name,
   po.vendor_id      vendor_id,
   po.vendor_name    vendor_name
      FROM   (SELECT poh.po_header_id po_header_id,
           pol.po_line_id po_line_id,
           pol.line_num po_line_num,
           poh.segment1 po_number,
           poh.type_lookup_code po_type,
           poh.org_id po_org_id,
           papf.email_address po_buyer_email,
           papf.first_name || ' ' || papf.last_name po_buyer_name,
           poh.vendor_id vendor_id,
           sup.vendor_name vendor_name
    FROM   po_headers_all     poh,
           po_lines_all       pol,
           hr_operating_units hou,
           per_all_people_f   papf,
           ap_suppliers       sup -- 1.2 26/01/2015 Dalit A. Raviv CHG0034145
    WHERE  poh.org_id = decode(p_org_id, -9, poh.org_id, p_org_id)
    AND    poh.po_header_id = pol.po_header_id
    AND    pol.org_id = decode(p_org_id, -9, pol.org_id, p_org_id)
    AND    poh.org_id = hou.organization_id
    AND    poh.agent_id = papf.person_id
    AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
          -- 1.2 26/01/2015 Dalit A. Raviv CHG0034145
    AND    sup.vendor_id = poh.vendor_id
          --
    AND    nvl(poh.attribute4, 'N') <> 'Y') po,
   -- custom table
   xxpo_documents_custom_load xdcl
      WHERE  xdcl.po_number = po.po_number
      AND    xdcl.po_type = po.po_type
      AND    xdcl.po_line_number = po.po_line_num(+)
      AND    nvl(xxpo_utils_pkg.get_po_destination(po.po_header_id), 'INV') =
   'EXPENSE'
      AND    p_po_source = 'CSV'
      ORDER  BY po_number,
      po_line_num;

    CURSOR c_po_requestor(p_po_line_id NUMBER) IS
    -- generates a list of email addresses.  distinct ensures we won't get the same address twice.
      SELECT DISTINCT papf.email_address email_address,
            papf.first_name || ' ' || papf.last_name full_name
      FROM   po_distributions_all pda,
   per_all_people_f     papf
      WHERE  pda.org_id = decode(p_org_id, -9, pda.org_id, p_org_id)
      AND    pda.po_line_id = p_po_line_id
      AND    pda.deliver_to_person_id = papf.person_id
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
   papf.effective_end_date;

    -- Dalit A. Raviv 18/02/2015
    CURSOR c_line_info(p_line_id IN NUMBER) IS
      SELECT pla.item_description line_description,
   gcc.concatenated_segments charge_account,
   (SELECT MIN(ffv.description) parent_description
    FROM   fnd_flex_value_children_v ffvc,
           fnd_flex_values_vl        ffv,
           fnd_flex_hierarchies      ffh
    WHERE  ffvc.flex_value_set_id IN (1013887, 1020162)
    AND    ffvc.flex_value_set_id = ffh.flex_value_set_id
    AND    ffh.flex_value_set_id = ffv.flex_value_set_id
    AND    ffh.hierarchy_id = ffv.structured_hierarchy_level
    AND    ffvc.parent_flex_value = ffv.flex_value
    AND    ffh.hierarchy_code LIKE 'Budget%'
    AND    ffvc.flex_value = gcc.segment3 --'631350'
    AND    rownum = 1
    GROUP  BY ffvc.flex_value,
    ffvc.flex_value_set_id) parent_value
      FROM   po_lines_all             pla,
   po_distributions_all     pda,
   gl_code_combinations_kfv gcc
      WHERE  pla.po_line_id = p_line_id --408484 --P_LINE_ID
      AND    pla.po_line_id = pda.po_line_id
      AND    gcc.code_combination_id = pda.code_combination_id
      AND    rownum = 1;

    l_error_prog_flag VARCHAR2(1) := 'N';
    l_return_status   VARCHAR2(1);
    l_msg             VARCHAR2(500);
    l_msg1            VARCHAR2(500);
    l_email_string    VARCHAR2(1000);
    l_email           VARCHAR2(250);
    l_name_string     VARCHAR2(1000);
    l_name            VARCHAR2(250);
    l_records_exist   VARCHAR2(1) := 'N';

    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_curr_request_id        NUMBER := fnd_profile.value('CONC_REQUEST_ID');
    l_email_is_valid_flag    VARCHAR2(1);
    l_invalid_email_list     VARCHAR2(500);
    -- 1.2 26/01/2015 Dalit A. Raviv CHG0034145
    l_line_amount     NUMBER;
    l_count_all_lines NUMBER := 0;
    l_count_lines     NUMBER := 0;
    l_line_desc       po_lines_all.item_description%TYPE;
    l_charge_account  gl_code_combinations_kfv.concatenated_segments%TYPE;
    l_parent_value    fnd_flex_values_vl.description%TYPE;
    l_user_mail       per_all_people_f.email_address%TYPE;
    --
    l_retcode VARCHAR2(1);
    e_error EXCEPTION;

  BEGIN
    errbuff := NULL;
    retcode := 0;

    write_log('Begin auto_close_invoiced_po');
    fnd_file.put_line(fnd_file.log, to_char(userenv('SESSIONID')));

    mo_global.set_org_context(p_org_id_char     => p_org_id,
          p_sp_id_char      => NULL,
          p_appl_short_name => 'PO');

    -- Load xxpo_documents_custom_load table from csv
    IF p_po_source = 'CSV' THEN
      write_log('Loading ');

      -- Clear out existing records
      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXPO_DOCUMENTS_CUSTOM_LOAD';

      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_msg,
               retcode                => l_retcode,
               p_table_name           => 'XXPO_DOCUMENTS_CUSTOM_LOAD',
               p_template_name        => 'DEFAULT',
               p_file_name            => p_load_file_name,
               p_directory            => p_load_file_dir,
               p_expected_num_of_rows => to_number(NULL));

      IF l_retcode <> 0 THEN
        RAISE e_error;
      END IF;
    END IF;

    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
    l_xxssys_generic_rpt_rec.col1            := 'PO NUMBER';
    l_xxssys_generic_rpt_rec.col2            := 'PO LINE NUMBER';
    l_xxssys_generic_rpt_rec.col3            := 'LINE DESCRIPTION';
    l_xxssys_generic_rpt_rec.col4            := 'PO REQUESTER';
    -- Dalit A. Raviv 26/01/2015 CHG0034145
    l_xxssys_generic_rpt_rec.col5 := 'LINE AMOUNT USD';
    l_xxssys_generic_rpt_rec.col6 := 'SUPPLIER';
    l_xxssys_generic_rpt_rec.col7 := 'CHARGE ACCOUNT';
    l_xxssys_generic_rpt_rec.col8 := 'PARENT VALUE';
    --
    l_xxssys_generic_rpt_rec.col_msg := 'MESSAGE';

    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
          x_return_status          => l_return_status,
          x_return_message         => l_msg);

    IF l_return_status <> 'S' THEN
      RAISE e_error;
    END IF;
    -- Dalit A. Raviv 18/02/2015
    IF p_send_sum_report = 'Y' THEN
      l_user_mail := xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(fnd_global.user_id));
    END IF;
    --
    FOR rec IN c_po LOOP
      BEGIN
        l_msg             := NULL;
        l_msg1            := NULL;
        l_records_exist   := 'Y';
        l_line_amount     := 0;
        l_count_all_lines := 0;
        l_count_lines     := 0;
        l_return_status   := 'S';

        write_log('*** Begin loop for po_number ' || rec.po_number ||
        ' po_line_number ' || rec.po_line_num || ' po_type ' ||
        rec.po_type || ' ***');
        write_log('p_po_source      : ' || p_po_source);
        write_log('rec.po_header_id : ' || rec.po_header_id);

        -- CHECK p_po_source = 'CSV' record exists
        IF p_po_source = 'CSV' AND rec.po_header_id IS NULL THEN
          l_msg := 'Error: Record does not exist in Oracle PO tables';
          RAISE e_error;
        END IF;

        -- Determines wether or not to call the close API
        IF p_test_report = 'N' THEN
          -- Calls Oracle's standard cancel API
          -- 1.2 26/01/2015 Dalit A. Raviv  CHG0034145
          cancel_po_pub(p_po_type        => rec.po_type, -- i v
    p_po_header_id   => rec.po_header_id, -- i n
    p_po_line_id     => rec.po_line_id, -- i n
    p_close_reason   => 'System Autocancel ' ||
              to_char(trunc(SYSDATE)), -- i v
    x_return_status  => l_return_status, -- o v
    x_return_message => l_msg -- o v
    );

          --IF l_return_status <> 'S' THEN
          --  RAISE e_error;
          --END IF;
        END IF;

        -- 1.2 26/01/2015 Dalit A. Raviv  CHG0034145
        -- Get line amount for the notification (free amount at the encumbrance)
        BEGIN
          l_line_amount := NULL;

          SELECT round(-sum(nvl(xd.unrounded_accounted_dr, 0) -
        nvl(xd.unrounded_accounted_cr, 0)),
             2) free_amount
          INTO   l_line_amount
          FROM   xla_transaction_entities_upg g,
       xla_ae_headers               h,
       gl_ledgers                   gl,
       xla_ae_lines                 l,
       xla_distribution_links       xd,
       po_distributions_all         pda
          WHERE  g.transaction_number = rec.po_number -- '400005215' -- PO Number
          AND    g.application_id = 201
          AND    h.entity_id = g.entity_id
          AND    h.application_id = 201
          AND    gl.ledger_id = h.ledger_id
          AND    gl.currency_code = 'USD'
          AND    l.ae_header_id = h.ae_header_id
          AND    h.event_type_code = 'PO_PA_CANCELLED'
          AND    h.request_id = l_curr_request_id -- 30502538    -- request_id
          AND    l.accounting_class_code != 'RFE'
          AND    xd.ae_header_id = l.ae_header_id
          AND    xd.ae_line_num = l.ae_line_num
          AND    pda.po_distribution_id = xd.source_distribution_id_num_1
          AND    pda.po_line_id = rec.po_line_id; -- 408246      -- Po_line_id
        EXCEPTION
          WHEN OTHERS THEN
  l_line_amount := NULL;
        END;

        -- Find email(s) for requestor
        l_email_string := NULL;
        l_name_string  := NULL;
        l_email        := NULL;
        l_name         := NULL;
        FOR rec_email IN c_po_requestor(rec.po_line_id) LOOP
          l_email        := rec_email.email_address;
          l_name         := rec_email.full_name;
          l_email_string := l_email_string || l_email || ',';
          l_name_string  := l_name_string || l_name || ',';
        END LOOP;

        -- If no requestor email, set to the buyer email
        IF l_email_string IS NULL THEN
          l_email_string := rec.po_buyer_email;
          l_name_string  := rec.po_buyer_name;
        ELSE
          -- remove last comma
          -- 1.2 26/01/2015 Dalit A. Raviv  CHG0034145
          --l_email_string  := REGEXP_REPLACE(l_email_string , '\s*,\s*$', '');
          --l_name_string   := REGEXP_REPLACE(l_name_string , '\s*,\s*$', '');
          l_email_string := rtrim(ltrim(l_email_string, ','), ',');
          l_name_string  := rtrim(ltrim(l_name_string, ','), ',');
        END IF;

        write_log('l_email_string : ' || l_email_string);
        write_log('l_name_string  : ' || l_name_string);

      EXCEPTION
        WHEN e_error THEN
          l_error_prog_flag := 'Y';
        WHEN OTHERS THEN
          l_error_prog_flag := 'Y';
          l_msg             := l_msg || chr(10) ||
           ' Unexpected error occurred in c_po CURSOR loop: ' ||
           dbms_utility.format_error_stack;
      END;

      -- If there is an error or no email, send to the p_default_email
      IF l_msg IS NOT NULL OR l_email_string IS NULL THEN
        l_email_string := p_default_email;
      END IF;

      write_log('l_email_string: ' || l_email_string);

      xxobjt_general_utils_pkg.validate_mail_list(p_mail_list             => l_email_string,
          p_is_list_valid         => l_email_is_valid_flag,
          p_out_valid_mail_list   => l_email_string,
          p_out_invalid_mail_list => l_invalid_email_list);

      write_log('l_email_string (after validation): ' || l_email_string);
      write_log('l_email_is_valid_flag            : ' ||
      l_email_is_valid_flag);
      write_log('l_invalid_email_list             : ' ||
      l_invalid_email_list);

      IF l_email_is_valid_flag = 'N' THEN
        l_msg := l_msg || chr(10) || ' The following emails are invalid: ' ||
       l_invalid_email_list;
      END IF;

      -- if param set to 'Y', override email string
      IF p_use_default_email = 'Y' THEN
        l_email_string := p_default_email;
      END IF;
      -- Dalit A. Raviv 18/02/2015 CHG0034145
      l_line_desc      := NULL;
      l_charge_account := NULL;
      l_parent_value   := NULL;
      FOR r_line_info IN c_line_info(rec.po_line_id) LOOP
        l_line_desc      := r_line_info.line_description;
        l_charge_account := r_line_info.charge_account;
        l_parent_value   := r_line_info.parent_value;
      END LOOP;
      --
      -- Set output report detail rows
      l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.email_to        := l_email_string;
      l_xxssys_generic_rpt_rec.col1            := rec.po_number;
      l_xxssys_generic_rpt_rec.col2            := rec.po_line_num;
      l_xxssys_generic_rpt_rec.col3            := l_line_desc;
      l_xxssys_generic_rpt_rec.col4            := l_name_string; --
      l_xxssys_generic_rpt_rec.col5            := l_line_amount;
      l_xxssys_generic_rpt_rec.col6            := rec.vendor_name;
      l_xxssys_generic_rpt_rec.col7            := l_charge_account;
      l_xxssys_generic_rpt_rec.col8            := l_parent_value;
      --
      l_xxssys_generic_rpt_rec.col_msg := l_msg;

      write_log('Write to xxsys_generic_rpt'); -- XX: SSYS Generic Report

      l_msg1 := substr(l_msg, 400);
      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
            x_return_status          => l_return_status,
            x_return_message         => l_msg);

      IF l_return_status <> 'S' THEN
        l_error_prog_flag := 'Y';
        fnd_file.put_line(fnd_file.output, l_msg);
      END IF;
      -- Dalit A. Raviv 18/02/2015 CHG0034145
      IF p_send_sum_report = 'Y' THEN
        -- Set output report detail rows
        l_xxssys_generic_rpt_rec.request_id      := l_curr_request_id;
        l_xxssys_generic_rpt_rec.header_row_flag := 'N';
        l_xxssys_generic_rpt_rec.email_to        := l_user_mail /*l_email_string*/
         ;
        l_xxssys_generic_rpt_rec.col1            := rec.po_number;
        l_xxssys_generic_rpt_rec.col2            := rec.po_line_num;
        l_xxssys_generic_rpt_rec.col3            := l_line_desc;
        l_xxssys_generic_rpt_rec.col4            := l_name_string;
        l_xxssys_generic_rpt_rec.col5            := l_line_amount;
        l_xxssys_generic_rpt_rec.col6            := rec.vendor_name;
        l_xxssys_generic_rpt_rec.col7            := l_charge_account;
        l_xxssys_generic_rpt_rec.col8            := l_parent_value;
        --
        l_xxssys_generic_rpt_rec.col_msg := l_msg1;

        write_log('Write to xxsys_generic_rpt'); -- XX: SSYS Generic Report
        l_msg := NULL;
        xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
              x_return_status          => l_return_status,
              x_return_message         => l_msg);

        IF l_return_status <> 'S' THEN
          l_error_prog_flag := 'Y';
          fnd_file.put_line(fnd_file.output, l_msg);
        END IF;
      END IF;

      write_log('*** End loop ***');
    END LOOP;

    IF l_records_exist = 'Y' THEN
      l_msg := NULL;
      write_log('Submit xxssys_generic_rpt_pkg.submit_request');
      -- Submit output report to be emailed out, if records were processed
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => p_burst_flag,
              p_request_id         => l_curr_request_id,
              p_l_report_title     => p_report_title,
              p_l_report_pre_text1 => p_report_pre_text1,
              p_l_report_pre_text2 => p_report_pre_text2,
              p_l_email_subject    => p_email_subject, -- 'PO Lines Cancelled'
              p_l_email_body1      => p_email_body,
              -- Since col2 is a VARCHAR2 field holding a number, we need to modify
              -- the ORDER BY to put a TO_NUMBER around the field.
              p_l_order_by         => ' key_col, col1, TO_NUMBER(col2), col3',
              p_l_file_name        => p_file_name,
              p_l_key_column       => p_key_col, -- 'EMAIL_TO'
              p_l_purge_table_flag => p_purge_table,
              x_return_status      => l_return_status,
              x_return_message     => l_msg);

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;
    END IF;

    write_log('End auto_ccancel_invoiced_po');
  EXCEPTION
    WHEN e_error THEN
      errbuff := l_msg;
      retcode := 2;
      fnd_file.put_line(fnd_file.output, l_msg);
    WHEN OTHERS THEN
      retcode := 2;
      errbuff := 'Unexpected error occurred in auto_cancel_po: ' ||
       dbms_utility.format_error_stack;
      fnd_file.put_line(fnd_file.output,
    'Unexpected error occurred in auto_cancel_po: ' ||
    dbms_utility.format_error_stack);
  END auto_cancel_po;

  --------------------------------------------------------------------
  --  name:              cancel_requisition
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --------------------------------------------------------------------
  PROCEDURE cancel_requisition(p_req_header_id NUMBER,
           p_req_sub_type  VARCHAR2 DEFAULT 'PURCHASE',
           p_reject_reason VARCHAR2,
           x_return_status OUT VARCHAR2,
           x_err_msg       OUT VARCHAR2) IS

    l_document_org_id NUMBER;
    l_msg_data        VARCHAR(500);
    l_msg_index_out   NUMBER;

    t_req_header_id po_tbl_number;
    t_req_line_id   po_tbl_number;

    l_po_return_code   VARCHAR2(240);
    l_online_report_id NUMBER;

  BEGIN

    SELECT org_id
    INTO   l_document_org_id
    FROM   po_requisition_headers_all
    WHERE  requisition_header_id = p_req_header_id;

    po_moac_utils_pvt.set_org_context(l_document_org_id); -- <R12 MOAC>

    SELECT rl.requisition_header_id,
           rl.requisition_line_id
    BULK   COLLECT
    INTO   t_req_header_id,
           t_req_line_id
    FROM   po_requisition_lines_all rl
    WHERE  rl.line_location_id IS NULL
    AND    nvl(rl.cancel_flag, 'N') != 'Y'
    AND    nvl(rl.closed_code, 'OPEN') = 'OPEN'
    AND    rl.line_location_id IS NULL
    AND    requisition_header_id = p_req_header_id;

    po_document_control_pvt.val_action_date(p_api_version              => 1.0,
              p_init_msg_list            => 'T',
              x_return_status            => x_return_status,
              p_doc_type                 => 'REQUISITION',
              p_doc_subtype              => p_req_sub_type,
              p_doc_id                   => p_req_header_id,
              p_action                   => 'CANCEL',
              p_action_date              => SYSDATE,
              p_cbc_enabled              => 'N',
              p_po_encumbrance_flag      => 'Y',
              p_req_encumbrance_flag     => 'Y',
              p_skip_valid_cbc_acct_date => NULL);

    IF x_return_status != fnd_api.g_ret_sts_success THEN

      fnd_msg_pub.get(p_msg_index     => -1,
            p_encoded       => 'F',
            p_data          => l_msg_data,
            p_msg_index_out => l_msg_index_out);

      x_err_msg := l_msg_data;
      fnd_file.put_line(fnd_file.log, x_return_status || ': ' || x_err_msg);

    ELSE

      FOR i IN 1 .. t_req_line_id.count LOOP

        IF po_reqs_control_sv.val_reqs_action(x_req_header_id      => p_req_header_id,
                x_req_line_id        => t_req_line_id(i),
                x_agent_id           => 61, --fnd_global.EMPLOYEE_ID,
                x_req_doc_type       => 'REQUISITION',
                x_req_doc_subtype    => p_req_sub_type,
                x_req_control_action => 'CANCEL REQ LINE',
                x_req_control_reason => p_reject_reason,
                x_req_action_date    => SYSDATE,
                x_encumbrance_flag   => 'Y',
                x_oe_installed_flag  => 'Y') THEN

          po_document_funds_pvt.do_cancel(x_return_status    => x_return_status,
            p_doc_type         => 'REQUISITION',
            p_doc_subtype      => p_req_sub_type,
            p_doc_level        => 'LINE',
            p_doc_level_id     => t_req_line_id(i),
            p_use_enc_gt_flag  => 'N',
            p_override_funds   => 'U',
            p_use_gl_date      => 'N',
            p_override_date    => SYSDATE,
            x_po_return_code   => l_po_return_code,
            x_online_report_id => l_online_report_id);
          COMMIT;
        ELSE

          x_err_msg := 'po_reqs_control_sv.val_reqs_action return false - ' ||
             t_req_line_id(i);
          fnd_file.put_line(fnd_file.log,
        x_return_status || ': ' ||
        'po_reqs_control_sv.val_reqs_action return false - ' ||
        t_req_line_id(i));

        END IF;

      END LOOP;
    END IF;
    -- fnd_file.put_line(fnd_file.log,x_return_status || ': ' || t_req_line_id(i) ||
    --                     ' - ' || x_err_msg);

  END cancel_requisition;

  --------------------------------------------------------------------
  --  name:              update_req_status
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --  1.2  03-SEP-2018  Bellona(TCS)       CHG0043481 - PO Action History
  --                                       removal of Truncated Action Date 
  --       time stamp for program "XX: Update Requisition Status to Incomplete"   
  --------------------------------------------------------------------
  PROCEDURE update_req_status(errbuf       OUT VARCHAR2,
          errcode      OUT VARCHAR2,
          v_req_number IN VARCHAR2,
          v_org_id     IN NUMBER) IS

    CURSOR reqtoreset(x_req_number VARCHAR2,
            x_org_id     NUMBER) IS
      SELECT wf_item_type,
   wf_item_key,
   requisition_header_id,
   segment1,
   type_lookup_code
      FROM   po_requisition_headers_all h
      WHERE  h.segment1 = x_req_number
      AND    h.org_id = x_org_id
      AND    h.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
      AND    nvl(h.closed_code, 'OPEN') <> 'FINALLY_CLOSED'
      AND    nvl(h.cancel_flag, 'N') = 'N';

    CURSOR wfstoabort(st_item_type VARCHAR2,
            st_item_key  VARCHAR2) IS
      SELECT LEVEL,
   item_type,
   item_key,
   end_date
      FROM   wf_items
      START  WITH item_type = st_item_type
           AND    item_key = st_item_key
      CONNECT BY PRIOR item_type = parent_item_type
          AND    PRIOR item_key = parent_item_key
      ORDER  BY LEVEL DESC;

    wf_rec wfstoabort%ROWTYPE;

    x_org_id           NUMBER;
    x_req_number       VARCHAR2(15);
    x_open_notif_exist VARCHAR2(1);
    ros                reqtoreset%ROWTYPE;

    x_progress         VARCHAR2(500);
    x_count_po_assoc   NUMBER;
    x_active_wf_exists VARCHAR2(1);
    nullseq            NUMBER;

    g_po_debug        VARCHAR2(1) := 'Y';
    l_disallow_script VARCHAR2(1);
    l_req_encumbrance VARCHAR2(1);

  BEGIN
    errbuf       := NULL;
    errcode      := 0;
    x_org_id     := v_org_id;
    x_req_number := v_req_number;

    fnd_file.put_line(fnd_file.log,
            'Req ' || x_req_number || ' in org ' || x_org_id);

    BEGIN
      SELECT 'Y'
      INTO   x_open_notif_exist
      FROM   dual
      WHERE  EXISTS (SELECT 'open notifications'
    FROM   wf_item_activity_statuses  wias,
           wf_notifications           wfn,
           po_requisition_headers_all porh
    WHERE  wias.notification_id IS NOT NULL
    AND    wias.notification_id = wfn.group_id
    AND    wfn.status = 'OPEN'
    AND    wias.item_type = 'REQAPPRV'
    AND    wias.item_key = porh.wf_item_key
    AND    porh.org_id = x_org_id
    AND    porh.segment1 = x_req_number
    AND    porh.authorization_status IN
           ('IN PROCESS', 'PRE-APPROVED'));
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF (x_open_notif_exist = 'Y') THEN
      fnd_file.put_line(fnd_file.log, '      ');
      fnd_file.put_line(fnd_file.log,
    'An Open notification exists for this document, you may want to use the notification to process this document. Do not commit if you wish to use the notification');
    END IF;

    SELECT COUNT(*)
    INTO   x_count_po_assoc
    FROM   po_requisition_lines_all   prl,
           po_requisition_headers_all prh
    WHERE  prh.segment1 = x_req_number
    AND    prh.org_id = x_org_id
    AND    prh.requisition_header_id = prl.requisition_header_id
    AND    (prl.line_location_id IS NOT NULL OR
          nvl(prh.transferred_to_oe_flag, 'N') = 'Y');

    IF (x_count_po_assoc > 0) THEN
      fnd_file.put_line(fnd_file.log,
    'This requisition is associated with a PO or sales order and hence cannot be reset. Please contact Oracle support');
      RETURN;
    END IF;

    OPEN reqtoreset(x_req_number, x_org_id);

    FETCH reqtoreset
      INTO ros;

    IF reqtoreset%NOTFOUND THEN
      fnd_file.put_line(fnd_file.log,
    'No such requisition with req number ' ||
    x_req_number ||
    ' exists which requires to be reset');
      fnd_file.put_line(fnd_file.log,
    'No such requisition with req number ' ||
    x_req_number ||
    ' exists which requires to be reset');
      RETURN;
    END IF;

    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log,
    'Processing ' || ros.type_lookup_code ||
    ' Req Number: ' || ros.segment1);
      fnd_file.put_line(fnd_file.log,
    '......................................'); --116
    END IF;

    BEGIN
      SELECT 'Y'
      INTO   l_disallow_script
      FROM   dual
      WHERE  EXISTS
       (SELECT 'dist with USSGL code'
    FROM   po_req_distributions_all prd,
           po_requisition_lines_all prl
    WHERE  prd.requisition_line_id = prl.requisition_line_id
    AND    prl.requisition_header_id = ros.requisition_header_id
    AND    prd.ussgl_transaction_code IS NOT NULL);

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF l_disallow_script = 'Y' THEN
      fnd_file.put_line(fnd_file.log,
    'You have a public sector installation and USSGL transaction codes are used');
      fnd_file.put_line(fnd_file.log,
    'The reset script is not allowed in such a scenario, please contact Oracle Support');
      CLOSE reqtoreset;
      RETURN;
    END IF;

    /* abort workflow processes if they exists */
    -- first check whether the wf process exists or not
    BEGIN
      SELECT 'Y'
      INTO   x_active_wf_exists
      FROM   wf_items wfi
      WHERE  wfi.item_type = ros.wf_item_type
      AND    wfi.item_key = ros.wf_item_key
      AND    wfi.end_date IS NULL;

    EXCEPTION
      WHEN no_data_found THEN
        x_active_wf_exists := 'N';
    END;

    -- if the wf process is not already aborted then abort it.
    IF (x_active_wf_exists = 'Y') THEN

      IF (g_po_debug = 'Y') THEN
        fnd_file.put_line(fnd_file.log, 'Aborting Workflow...');
      END IF;

      OPEN wfstoabort(ros.wf_item_type, ros.wf_item_key);

      LOOP
        FETCH wfstoabort
          INTO wf_rec;
        IF (g_po_debug = 'Y') THEN
          fnd_file.put_line(fnd_file.log,
        wf_rec.item_type || wf_rec.item_key);
        END IF;
        IF wfstoabort%NOTFOUND THEN
          CLOSE wfstoabort;
          EXIT;
        END IF;

        IF (wf_rec.end_date IS NULL) THEN
          BEGIN
  wf_engine.abortprocess(wf_rec.item_type, wf_rec.item_key);
          EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,
            'Could not abort the workflow for PO :' ||
            ros.segment1 ||
            ' Please contact Oracle Support ');
    ROLLBACK;
    RETURN;
          END;
        END IF;
      END LOOP;
    END IF;

    /* Update the authorization status of the requisition to incomplete */
    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log, 'Updating Requisition Status...');
    END IF;

    UPDATE po_requisition_headers_all
    SET    authorization_status = 'INCOMPLETE',
           wf_item_type         = NULL,
           wf_item_key          = NULL
    WHERE  requisition_header_id = ros.requisition_header_id;

    /* Update Action history setting the last null action code to NO ACTION */
    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log, 'Updating PO Action History...');
    END IF;

    SELECT nvl(MAX(sequence_num), 0)
    INTO   nullseq
    FROM   po_action_history
    WHERE  object_type_code = 'REQUISITION'
    AND    object_sub_type_code = ros.type_lookup_code
    AND    object_id = ros.requisition_header_id
    AND    action_code IS NULL;

    UPDATE po_action_history
    SET    action_code = 'NO ACTION',
           action_date = SYSDATE, --trunc(SYSDATE),				-- CHG0043481
           note        = 'updated by reset script on ' ||
     to_char(SYSDATE)--to_char(trunc(SYSDATE))					-- CHG0043481
    WHERE  object_id = ros.requisition_header_id
    AND    object_type_code = 'REQUISITION'
    AND    object_sub_type_code = ros.type_lookup_code
    AND    sequence_num = nullseq
    AND    action_code IS NULL;

    SELECT nvl(req_encumbrance_flag, 'N')
    INTO   l_req_encumbrance
    FROM   financials_system_params_all
    WHERE  org_id = x_org_id;

    IF l_req_encumbrance = 'N' THEN
      fnd_file.put_line(fnd_file.log, 'Done Processing.');
      fnd_file.put_line(fnd_file.log, '................');
      fnd_file.put_line(fnd_file.log,
    'Please issue commit, if no errors found.');
      fnd_file.put_line(fnd_file.log, 'Done Processing.');
      fnd_file.put_line(fnd_file.log, '................');
      fnd_file.put_line(fnd_file.log,
    'Please issue commit, if no errors found.');
      RETURN;
    END IF;

    --    close reqtoreset;

    fnd_file.put_line(fnd_file.log, 'Done Processing.');
    fnd_file.put_line(fnd_file.log, '................');
    fnd_file.put_line(fnd_file.log,
            'Please issue commit, if no errors found.');
    fnd_file.put_line(fnd_file.log, 'Done Processing.');
    fnd_file.put_line(fnd_file.log, '................');
    fnd_file.put_line(fnd_file.log,
            'Please issue commit, if no errors found.');

  EXCEPTION
    WHEN OTHERS THEN
      errcode := 2;
      errbuf  := 'some exception occured ' || SQLERRM || ' rolling back ' ||
       x_progress;
      fnd_file.put_line(fnd_file.log,
    'some exception occured ' || SQLERRM ||
    ' rolling back' || x_progress);
      ROLLBACK;
      --      close reqtoreset;
      RETURN;
  END update_req_status;

  --------------------------------------------------------------------
  --  name:              updated_by_reset_script
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --------------------------------------------------------------------
  PROCEDURE updated_by_reset_script(errbuf         OUT VARCHAR2,
      errcode        OUT VARCHAR2,
      v_req_number   IN VARCHAR2,
      v_org_id       IN NUMBER,
      v_line_output1 OUT VARCHAR2,
      v_line_output2 OUT VARCHAR2,
      v_line_output3 OUT VARCHAR2) IS

    CURSOR reqtoreset(x_req_number VARCHAR2,
            x_org_id     NUMBER) IS
      SELECT wf_item_type,
   wf_item_key,
   requisition_header_id,
   segment1,
   type_lookup_code
      FROM   po_requisition_headers_all h
      WHERE  h.segment1 = x_req_number
      AND    h.org_id = x_org_id
      AND    h.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
      AND    nvl(h.closed_code, 'OPEN') <> 'FINALLY_CLOSED'
      AND    nvl(h.cancel_flag, 'N') = 'N';

    CURSOR wfstoabort(st_item_type VARCHAR2,
            st_item_key  VARCHAR2) IS
      SELECT LEVEL,
   item_type,
   item_key,
   end_date
      FROM   wf_items
      START  WITH item_type = st_item_type
           AND    item_key = st_item_key
      CONNECT BY PRIOR item_type = parent_item_type
          AND    PRIOR item_key = parent_item_key
      ORDER  BY LEVEL DESC;

    wf_rec wfstoabort%ROWTYPE;

    x_org_id           NUMBER;
    x_req_number       VARCHAR2(15);
    x_open_notif_exist VARCHAR2(1);
    ros                reqtoreset%ROWTYPE;

    x_progress         VARCHAR2(500);
    x_count_po_assoc   NUMBER;
    x_active_wf_exists VARCHAR2(1);
    nullseq            NUMBER;

    g_po_debug        VARCHAR2(1) := 'Y';
    l_disallow_script VARCHAR2(1);
    l_req_encumbrance VARCHAR2(1);

  BEGIN
    errbuf       := NULL;
    errcode      := 0;
    x_org_id     := v_org_id;
    x_req_number := v_req_number;

    fnd_file.put_line(fnd_file.log,
            'Req ' || x_req_number || ' in org ' || x_org_id);

    BEGIN
      SELECT 'Y'
      INTO   x_open_notif_exist
      FROM   dual
      WHERE  EXISTS (SELECT 'open notifications'
    FROM   wf_item_activity_statuses  wias,
           wf_notifications           wfn,
           po_requisition_headers_all porh
    WHERE  wias.notification_id IS NOT NULL
    AND    wias.notification_id = wfn.group_id
    AND    wfn.status = 'OPEN'
    AND    wias.item_type = 'REQAPPRV'
    AND    wias.item_key = porh.wf_item_key
    AND    porh.org_id = x_org_id
    AND    porh.segment1 = x_req_number
    AND    porh.authorization_status IN
           ('IN PROCESS', 'PRE-APPROVED'));
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF (x_open_notif_exist = 'Y') THEN
      fnd_file.put_line(fnd_file.log, '      ');
      fnd_file.put_line(fnd_file.log,
    'An Open notification exists for this document, you may want to use the notification to process this document. Do not commit if you wish to use the notification');
    END IF;

    SELECT COUNT(*)
    INTO   x_count_po_assoc
    FROM   po_requisition_lines_all   prl,
           po_requisition_headers_all prh
    WHERE  prh.segment1 = x_req_number
    AND    prh.org_id = x_org_id
    AND    prh.requisition_header_id = prl.requisition_header_id
    AND    (prl.line_location_id IS NOT NULL OR
          nvl(prh.transferred_to_oe_flag, 'N') = 'Y');

    IF (x_count_po_assoc > 0) THEN
      fnd_file.put_line(fnd_file.log,
    'This requisition is associated with a PO or sales order and hence cannot be reset. Please contact Oracle support');
      RETURN;
    END IF;

    OPEN reqtoreset(x_req_number, x_org_id);

    FETCH reqtoreset
      INTO ros;

    IF reqtoreset%NOTFOUND THEN
      fnd_file.put_line(fnd_file.log,
    'No such requisition with req number ' ||
    x_req_number ||
    ' exists which requires to be reset');
      RETURN;
    END IF;

    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log,
    'Processing ' || ros.type_lookup_code ||
    ' Req Number: ' || ros.segment1);
      fnd_file.put_line(fnd_file.log,
    '......................................'); --116
    END IF;

    BEGIN
      SELECT 'Y'
      INTO   l_disallow_script
      FROM   dual
      WHERE  EXISTS
       (SELECT 'dist with USSGL code'
    FROM   po_req_distributions_all prd,
           po_requisition_lines_all prl
    WHERE  prd.requisition_line_id = prl.requisition_line_id
    AND    prl.requisition_header_id = ros.requisition_header_id
    AND    prd.ussgl_transaction_code IS NOT NULL);

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF l_disallow_script = 'Y' THEN
      fnd_file.put_line(fnd_file.log,
    'You have a public sector installation and USSGL transaction codes are used');
      fnd_file.put_line(fnd_file.log,
    'The reset script is not allowed in such a scenario, please contact Oracle Support');
      CLOSE reqtoreset;
      RETURN;
    END IF;

    l_disallow_script := 'N';
    BEGIN
      SELECT 'Y'
      INTO   l_disallow_script
      FROM   dual
      WHERE  EXISTS (SELECT 'encumbrance data'
    FROM   po_bc_distributions
    WHERE  je_source_name = 'Purchasing'
    AND    je_category_name = 'Requisitions'
    AND    header_id = ros.requisition_header_id);
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF l_disallow_script = 'Y' THEN
      fnd_file.put_line(fnd_file.log,
    'This Requisition has been reserved atleast once previously.');
      fnd_file.put_line(fnd_file.log,
    'Hence this Requisition can not be reset');
      CLOSE reqtoreset;
      RETURN;
    END IF;

    /* abort workflow processes if they exists */
    -- first check whether the wf process exists or not
    BEGIN
      SELECT 'Y'
      INTO   x_active_wf_exists
      FROM   wf_items wfi
      WHERE  wfi.item_type = ros.wf_item_type
      AND    wfi.item_key = ros.wf_item_key
      AND    wfi.end_date IS NULL;

    EXCEPTION
      WHEN no_data_found THEN
        x_active_wf_exists := 'N';
    END;

    -- if the wf process is not already aborted then abort it.
    IF (x_active_wf_exists = 'Y') THEN

      IF (g_po_debug = 'Y') THEN
        fnd_file.put_line(fnd_file.log, 'Aborting Workflow...');
      END IF;

      OPEN wfstoabort(ros.wf_item_type, ros.wf_item_key);

      LOOP
        FETCH wfstoabort
          INTO wf_rec;
        IF (g_po_debug = 'Y') THEN
          fnd_file.put_line(fnd_file.log,
        wf_rec.item_type || wf_rec.item_key);
        END IF;
        IF wfstoabort%NOTFOUND THEN
          CLOSE wfstoabort;
          EXIT;
        END IF;

        IF (wf_rec.end_date IS NULL) THEN
          BEGIN
  wf_engine.abortprocess(wf_rec.item_type, wf_rec.item_key);
          EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,
            'Could not abort the workflow for PO :' ||
            ros.segment1 ||
            ' Please contact Oracle Support ');
    ROLLBACK;
    RETURN;
          END;

        END IF;
      END LOOP;
    END IF;

    /* Update the authorization status of the requisition to incomplete */
    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log, 'Updating Requisition Status...');
    END IF;

    UPDATE po_requisition_headers_all
    SET    authorization_status = 'INCOMPLETE',
           wf_item_type         = NULL,
           wf_item_key          = NULL
    WHERE  requisition_header_id = ros.requisition_header_id;

    /* Update Action history setting the last null action code to NO ACTION */
    IF (g_po_debug = 'Y') THEN
      fnd_file.put_line(fnd_file.log, 'Updating PO Action History...');
    END IF;

    SELECT nvl(MAX(sequence_num), 0)
    INTO   nullseq
    FROM   po_action_history
    WHERE  object_type_code = 'REQUISITION'
    AND    object_sub_type_code = ros.type_lookup_code
    AND    object_id = ros.requisition_header_id
    AND    action_code IS NULL;

    UPDATE po_action_history
    SET    action_code = 'NO ACTION',
           action_date = trunc(SYSDATE),
           note        = 'updated by reset script on ' ||
     to_char(trunc(SYSDATE))
    WHERE  object_id = ros.requisition_header_id
    AND    object_type_code = 'REQUISITION'
    AND    object_sub_type_code = ros.type_lookup_code
    AND    sequence_num = nullseq
    AND    action_code IS NULL;

    SELECT nvl(req_encumbrance_flag, 'N')
    INTO   l_req_encumbrance
    FROM   financials_system_params_all
    WHERE  org_id = x_org_id;

    IF l_req_encumbrance = 'N' THEN
      v_line_output1 := 'Done Processing.';
      v_line_output2 := '................';
      v_line_output3 := 'Please issue commit, if no errors found.';
      fnd_file.put_line(fnd_file.log, 'Done Processing.');
      fnd_file.put_line(fnd_file.log, '................');
      fnd_file.put_line(fnd_file.log,
    'Please issue commit, if no errors found.');
      RETURN;
    END IF;

    --    close reqtoreset;

    v_line_output1 := 'Done Processing.';
    v_line_output2 := '................';
    v_line_output3 := 'Please issue commit, if no errors found.';
    fnd_file.put_line(fnd_file.log, 'Done Processing.');
    fnd_file.put_line(fnd_file.log, '................');
    fnd_file.put_line(fnd_file.log,
            'Please issue commit, if no errors found.');

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'some exception occured ' || SQLERRM || ' rolling back ' ||
       x_progress;
      errcode := 1;
      fnd_file.put_line(fnd_file.log,
    'some exception occured ' || SQLERRM ||
    ' rolling back' || x_progress);
      ROLLBACK;
      --      close reqtoreset;
      RETURN;
  END updated_by_reset_script;

  --------------------------------------------------------------------
  --  name:              abort_po_rel2incomplete
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  /*=======================================================================+
  |  Copyright (c) 2009 Oracle Corporation Redwood Shores, California, USA|
  |                            All rights reserved.                       |
  +=======================================================================*/
  /* $Header: poxrespo.sql 120.0.12000000.2 2009/08/13 13:05:25 vrecharl noship $ */
  /* PLEASE READ NOTE 390023.1 CAREFULLY BEFORE EXECUTING THIS SCRIPT.
   * This script will:
   * reset the document to incomplete/requires reapproval status.
   * delete/update action history as desired (refere note 390023.1 for more details).
   * abort all the related workflows If there is encumbrance entries related to the PO, it will:
   * skip the reset action on the document.
  */
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --  1.2  03-SEP-2018  Bellona(TCS)       CHG0043481 - PO Action History
  --                                       removal of Truncated Action Date 
  --       time stamp for program "XX: Update PO Release Status to Incomplete"   
  --------------------------------------------------------------------
  PROCEDURE abort_po_rel2incomplete(errbuf            OUT VARCHAR2,
      retcode           OUT VARCHAR2,
      p_po_release_id   NUMBER,
      p_organization_id NUMBER,
      p_del_action_hist VARCHAR2 DEFAULT 'N') IS

    CURSOR c_po IS
      SELECT h.segment1,
   t.wf_item_type,
   t.wf_item_key,
   t.release_num,
   t.approved_date
      FROM   po_releases_all t,
   po_headers_all  h
      WHERE  h.org_id = p_organization_id
      AND    t.po_header_id = h.po_header_id
      AND    t.po_release_id = p_po_release_id
      AND    t.authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
      AND    nvl(t.cancel_flag, 'N') = 'N'
      AND    nvl(t.closed_code, 'OPEN') <> 'FINALLY_CLOSED';
  BEGIN
    errbuf  := 'No Po Found !!';
    retcode := 0;

    FOR i IN c_po LOOP
      fnd_file.put_line(fnd_file.log,
    'Processing PO Number: ' || i.segment1 ||
    ' release :' || i.release_num);
      fnd_file.put_line(fnd_file.log,
    '......................................');

      -- ABORT WF

      wf_engine.abortprocess(i.wf_item_type, i.wf_item_key);
      fnd_file.put_line(fnd_file.log,
    'workflow  aborted :' || i.wf_item_type || ' ' ||
    i.wf_item_key);

      -- UPDATE STATUS

      UPDATE po_releases_all t
      SET    authorization_status = decode(approved_date,
             NULL,
             'INCOMPLETE',
             'REQUIRES REAPPROVAL'),
   wf_item_type         = NULL,
   wf_item_key          = NULL,
   approved_flag        = decode(approved_date, NULL, 'N', 'R')
      WHERE  t.po_release_id = p_po_release_id;

      fnd_file.put_line(fnd_file.log, 'Status Updated to INCOMPLETE');

      -- UPDATE ACTION HISTORY

      IF nvl(p_del_action_hist, 'N') = 'N' THEN
        UPDATE po_action_history
        SET    action_code = 'NO ACTION',
     action_date = SYSDATE,     --trunc(SYSDATE),	-- CHG0043481
     note        = 'Updated by reset script on ' ||
         to_char(SYSDATE) --to_char(trunc(SYSDATE))					-- CHG0043481
        WHERE  object_id = p_po_release_id
        AND    object_type_code = 'RELEASE'
        AND    object_sub_type_code = 'BLANKET'
        AND    action_code IS NULL;
      ELSE

        DELETE po_action_history h
        WHERE  object_id = p_po_release_id
        AND    object_type_code = 'RELEASE'
        AND    object_sub_type_code = 'BLANKET'
        AND    h.sequence_num >=
     (SELECT nvl(MAX(sequence_num), 0)
       FROM   po_action_history
       WHERE  object_id = p_po_release_id
       AND    object_type_code = 'RELEASE'
       AND    object_sub_type_code = 'BLANKET'
       AND    action_code = 'SUBMIT');

      END IF;

      ---
      COMMIT;
      errbuf := 'PO Number: ' || i.segment1 || ' release :' ||
      i.release_num || ' Aborted';
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error in abort_po_rel2incomplete :' || SQLERRM;
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:              update_po_to_incomplete
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --  1.2  03-SEP-2018  Bellona(TCS)       CHG0043481 - PO Action History
  --                                       removal of Truncated Action Date 
  --             time stamp for program "XX: Update PO Status to Incomplete"  
  --------------------------------------------------------------------
  PROCEDURE update_po_to_incomplete(errbuf            OUT VARCHAR2,
      retcode           OUT VARCHAR2,
      p_po_number       VARCHAR2,
      p_organization_id NUMBER,
      p_del_action_hist VARCHAR2 DEFAULT 'N') IS

    CURSOR potoreset(po_number VARCHAR2,
           x_org_id  NUMBER) IS
      SELECT wf_item_type,
   wf_item_key,
   po_header_id,
   segment1,
   revision_num,
   type_lookup_code,
   approved_date
      FROM   po_headers_all
      WHERE  segment1 = po_number
      AND    nvl(org_id, -99) = nvl(x_org_id, -99)
  -- bug 5015493: Need to allow reset of blankets and PPOs also.
  -- and type_lookup_code = 'STANDARD'
      AND    authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
      AND    nvl(cancel_flag, 'N') = 'N'
      AND    nvl(closed_code, 'OPEN') <> 'FINALLY_CLOSED';

    /* select the max sequence number with NULL action code */

    CURSOR maxseq(id       NUMBER,
        sub_type po_action_history.object_sub_type_code%TYPE) IS
      SELECT nvl(MAX(sequence_num), 0)
      FROM   po_action_history
      WHERE  object_type_code IN ('PO', 'PA')
      AND    object_sub_type_code = sub_type
      AND    object_id = id
      AND    action_code IS NULL;

    /* select the max sequence number with submit action */

    CURSOR poaction(id        NUMBER,
          c_subtype po_action_history.object_sub_type_code%TYPE) IS
      SELECT nvl(MAX(sequence_num), 0)
      FROM   po_action_history
      WHERE  object_type_code IN ('PO', 'PA')
      AND    object_sub_type_code = c_subtype
      AND    object_id = id
      AND    action_code = 'SUBMIT';

    CURSOR wfstoabort(st_item_type VARCHAR2,
            st_item_key  VARCHAR2) IS
      SELECT LEVEL,
   item_type,
   item_key,
   end_date
      FROM   wf_items
      START  WITH item_type = st_item_type
           AND    item_key = st_item_key
      CONNECT BY PRIOR item_type = parent_item_type
          AND    PRIOR item_key = parent_item_key
      ORDER  BY LEVEL DESC;

    wf_rec wfstoabort%ROWTYPE;

    submitseq po_action_history.sequence_num%TYPE;
    nullseq   po_action_history.sequence_num%TYPE;

    x_organization_id  NUMBER;
    x_po_number        VARCHAR2(15);
    x_open_notif_exist VARCHAR2(1);
    pos                potoreset%ROWTYPE;

    x_progress          VARCHAR2(500);
    x_active_wf_exists  VARCHAR2(1);
    l_delete_act_hist   VARCHAR2(1);
    l_change_req_exists VARCHAR2(1);
    l_res_seq           po_action_history.sequence_num%TYPE;
    l_sub_res_seq       po_action_history.sequence_num%TYPE;
    l_res_act           po_action_history.action_code%TYPE;
    l_del_res_hist      VARCHAR2(1);

    /* For encumbrance actions */

    name_already_used EXCEPTION;
    PRAGMA EXCEPTION_INIT(name_already_used, -955);
    disallow_script VARCHAR2(1);

    l_purch_encumbrance_flag VARCHAR2(1);

  BEGIN
    errbuf            := NULL;
    retcode           := 0;
    l_delete_act_hist := p_del_action_hist;

    x_organization_id := p_organization_id;

    x_po_number := p_po_number;

    x_progress := '010: start';

    BEGIN
      SELECT 'Y'
      INTO   x_open_notif_exist
      FROM   dual
      WHERE  EXISTS
       (SELECT 'open notifications'
    FROM   wf_item_activity_statuses wias,
           wf_notifications          wfn,
           po_headers_all            poh
    WHERE  wias.notification_id IS NOT NULL
    AND    wias.notification_id = wfn.group_id
    AND    wfn.status = 'OPEN'
    AND    wias.item_type = 'POAPPRV'
    AND    wias.item_key = poh.wf_item_key
    AND    nvl(poh.org_id, -99) = nvl(x_organization_id, -99)
    AND    poh.segment1 = x_po_number
    AND    poh.authorization_status IN
           ('IN PROCESS', 'PRE-APPROVED'));
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    x_progress := '020: selected open notif';

    IF (x_open_notif_exist = 'Y') THEN
      fnd_file.put_line(fnd_file.log, '  ');
      fnd_file.put_line(fnd_file.log,
    'An Open notification exists for this document, you may want to use the notification to process this document. Do not commit if you wish to use the notification');
    END IF;

    BEGIN
      SELECT 'Y'
      INTO   l_change_req_exists
      FROM   dual
      WHERE  EXISTS
       (SELECT 'po with change request'
    FROM   po_headers_all h
    WHERE  h.segment1 = x_po_number
    AND    nvl(h.org_id, -99) = nvl(x_organization_id, -99)
    AND    h.change_requested_by IN ('REQUESTER', 'SUPPLIER'));
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF (l_change_req_exists = 'Y') THEN
      fnd_file.put_line(fnd_file.log, '  ');
      fnd_file.put_line(fnd_file.log,
    'ATTENTION !!! There is an open change request against this PO. You should respond to the notification for the same.');
      RETURN;
      --   fnd_file.put_line(fnd_file.log,'If you are running this script unaware of the change request, Please ROLLBACK');
    END IF;

    OPEN potoreset(x_po_number, x_organization_id);

    FETCH potoreset
      INTO pos;
    IF potoreset%NOTFOUND THEN
      fnd_file.put_line(fnd_file.log,
    'No PO with PO Number ' || x_po_number ||
    ' exists in org ' || to_char(x_organization_id) ||
    ' which requires to be reset');
      RETURN;
    END IF;
    CLOSE potoreset;

    /* check if any distribution with USSGL code exists - if it does then exit */

    disallow_script := 'N';
    BEGIN
      SELECT 'Y'
      INTO   disallow_script
      FROM   dual
      WHERE  EXISTS (SELECT 'dist with USSGL code'
    FROM   po_distributions_all
    WHERE  po_header_id = pos.po_header_id
    AND    ussgl_transaction_code IS NOT NULL);

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    IF disallow_script = 'Y' THEN
      fnd_file.put_line(fnd_file.log,
    'You have a public sector installation and USSGL transaction codes are used');
      fnd_file.put_line(fnd_file.log,
    'The reset script is not allowed in such a scenario, please contact Oracle Support');
      RETURN;
    END IF;

    x_progress := '030 checking enc action ';

    fnd_file.put_line(fnd_file.log,
            'Processing ' || pos.type_lookup_code ||
            ' PO Number: ' || pos.segment1);
    fnd_file.put_line(fnd_file.log,
            '......................................');

    BEGIN
      SELECT 'Y'
      INTO   x_active_wf_exists
      FROM   wf_items wfi
      WHERE  wfi.item_type = pos.wf_item_type
      AND    wfi.item_key = pos.wf_item_key
      AND    wfi.end_date IS NULL;

    EXCEPTION
      WHEN no_data_found THEN
        x_active_wf_exists := 'N';
    END;

    IF (x_active_wf_exists = 'Y') THEN
      fnd_file.put_line(fnd_file.log, 'Aborting Workflow...');
      OPEN wfstoabort(pos.wf_item_type, pos.wf_item_key);
      LOOP
        FETCH wfstoabort
          INTO wf_rec;
        IF wfstoabort%NOTFOUND THEN
          CLOSE wfstoabort;
          EXIT;
        END IF;

        IF (wf_rec.end_date IS NULL) THEN
          BEGIN
  wf_engine.abortprocess(wf_rec.item_type, wf_rec.item_key);
          EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,
            ' workflow not aborted :' ||
            wf_rec.item_type || '-' || wf_rec.item_key);

          END;

        END IF;
      END LOOP;
    END IF;

    fnd_file.put_line(fnd_file.log, 'Updating PO Status..');
    UPDATE po_headers_all
    SET    authorization_status = decode(pos.approved_date,
           NULL,
           'INCOMPLETE',
           'REQUIRES REAPPROVAL'),
           wf_item_type         = NULL,
           wf_item_key          = NULL,
           approved_flag        = decode(pos.approved_date, NULL, 'N', 'R')
    WHERE  po_header_id = pos.po_header_id;

    OPEN maxseq(pos.po_header_id, pos.type_lookup_code);
    FETCH maxseq
      INTO nullseq;
    CLOSE maxseq;

    OPEN poaction(pos.po_header_id, pos.type_lookup_code);
    FETCH poaction
      INTO submitseq;
    CLOSE poaction;
    IF nullseq > submitseq THEN

      IF nvl(l_delete_act_hist, 'N') = 'N' THEN
        UPDATE po_action_history
        SET    action_code = 'NO ACTION',
     action_date = SYSDATE,	 --trunc(SYSDATE), 					-- CHG0043481
     note        = 'updated by reset script on ' ||
         to_char(SYSDATE) --to_char(trunc(SYSDATE))				-- CHG0043481
        WHERE  object_id = pos.po_header_id
        AND    object_type_code = decode(pos.type_lookup_code,
           'STANDARD',
           'PO',
           'PLANNED',
           'PO', --future plan to enhance for planned PO
           'PA')
        AND    object_sub_type_code = pos.type_lookup_code
        AND    sequence_num = nullseq
        AND    action_code IS NULL;
      ELSE

        DELETE po_action_history
        WHERE  object_id = pos.po_header_id
        AND    object_type_code = decode(pos.type_lookup_code,
           'STANDARD',
           'PO',
           'PLANNED',
           'PO', --future plan to enhance for planned PO
           'PA')
        AND    object_sub_type_code = pos.type_lookup_code
        AND    sequence_num >= submitseq
        AND    sequence_num <= nullseq;

      END IF;

    END IF;

    fnd_file.put_line(fnd_file.log, 'Done Approval Processing.');

    SELECT nvl(purch_encumbrance_flag, 'N')
    INTO   l_purch_encumbrance_flag
    FROM   financials_system_params_all fspa
    WHERE  nvl(fspa.org_id, -99) = nvl(x_organization_id, -99);

    IF (l_purch_encumbrance_flag = 'N')
      -- bug 5015493 : Need to allow reset for blankets also
       OR (pos.type_lookup_code = 'BLANKET') THEN

      IF (pos.type_lookup_code = 'BLANKET') THEN
        fnd_file.put_line(fnd_file.log, 'document reset successfully');
        fnd_file.put_line(fnd_file.log,
      'If you are using Blanket encumbrance, Please ROLLBACK, else COMMIT');
      ELSE
        fnd_file.put_line(fnd_file.log, 'document reset successfully');
        fnd_file.put_line(fnd_file.log, 'please COMMIT data');
      END IF;
      RETURN;
    END IF;

    -- reserve action history stuff
    -- check the action history and delete any reserve to submit actions if all the distributions
    -- are now unencumbered, this should happen only if we are deleting the action history
    IF l_delete_act_hist = 'Y' THEN

      -- first get the last sequence and action code from action history
      BEGIN
        SELECT sequence_num,
     action_code
        INTO   l_res_seq,
     l_res_act
        FROM   po_action_history pah
        WHERE  pah.object_id = pos.po_header_id
        AND    pah.object_type_code = decode(pos.type_lookup_code,
               'STANDARD',
               'PO',
               'PLANNED',
               'PO', --future plan to enhance for planned PO
               'PA')
        AND    pah.object_sub_type_code = pos.type_lookup_code
        AND    sequence_num IN
     (SELECT MAX(sequence_num)
       FROM   po_action_history pah1
       WHERE  pah1.object_id = pah.object_id
       AND    pah1.object_type_code = pah.object_type_code
       AND    pah1.object_sub_type_code = pah.object_sub_type_code);
      EXCEPTION
        WHEN too_many_rows THEN
          fnd_file.put_line(fnd_file.log,
        'action history needs to be corrected separately ');
        WHEN no_data_found THEN
          NULL;
      END;

      -- now if the last action is reserve get the last submit action sequence

      IF (l_res_act = 'RESERVE') THEN
        BEGIN
          SELECT MAX(sequence_num)
          INTO   l_sub_res_seq
          FROM   po_action_history pah
          WHERE  action_code = 'SUBMIT'
          AND    pah.object_id = pos.po_header_id
          AND    pah.object_type_code = decode(pos.type_lookup_code,
                 'STANDARD',
                 'PO',
                 'PLANNED',
                 'PO', --future plan to enhance for planned PO
                 'PA')
          AND    pah.object_sub_type_code = pos.type_lookup_code;
        EXCEPTION
          WHEN no_data_found THEN
  NULL;
        END;

        -- check if we need to delete the action history, ie. if all the distbributions
        -- are unreserved

        IF ((l_sub_res_seq IS NOT NULL) AND (l_res_seq > l_sub_res_seq)) THEN

          BEGIN
  SELECT 'Y'
  INTO   l_del_res_hist
  FROM   dual
  WHERE  NOT EXISTS
   (SELECT 'encumbered dist'
          FROM   po_distributions_all pod
          WHERE  pod.po_header_id = pos.po_header_id
          AND    nvl(pod.encumbered_flag, 'N') = 'Y'
          AND    nvl(pod.prevent_encumbrance_flag, 'N') = 'N');
          EXCEPTION
  WHEN no_data_found THEN
    l_del_res_hist := 'N';
          END;

          IF l_del_res_hist = 'Y' THEN

  fnd_file.put_line(fnd_file.log,
          'deleting reservation action history ... ');

  DELETE po_action_history pah
  WHERE  pah.object_id = pos.po_header_id
  AND    pah.object_type_code =
         decode(pos.type_lookup_code,
       'STANDARD',
       'PO',
       'PLANNED',
       'PO', --future plan to enhance for planned PO
       'PA')
  AND    pah.object_sub_type_code = pos.type_lookup_code
  AND    sequence_num >= l_sub_res_seq
  AND    sequence_num <= l_res_seq;
          END IF;

        END IF; -- l_res_seq > l_sub_res_seq

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'some exception occured ' || SQLERRM || ' rolling back ' ||
       x_progress;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
    'some exception occured ' || SQLERRM ||
    ' rolling back' || x_progress);
      ROLLBACK;
  END update_po_to_incomplete;

  --------------------------------------------------------------------
  --  name:              workflow_aq_reenqueue
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --------------------------------------------------------------------
  PROCEDURE workflow_aq_reenqueue(p_agent_name VARCHAR2) IS

  BEGIN

    -- dbdrv :none -- $header :wfaqrenq.SQL 120.0.12000000.6 2008 / 04 / 04 08 :37 :51 sstomar ship $
    -- + == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == = +
    -- | copyright(c) 2005, oracle. ALL rights reserved. |
    -- + == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == = +
    --
    -- NAME
    -- wfaqrenq.SQL - workflow aq re - enqueue script
    --
    -- description
    -- this script re - enqueues messages that are backed up BY wfaqback.SQL script.
    -- wfaqback.SQL creates a temp TABLE AND backs up THE specified event messages.
    -- this script takes THE messages FROM THE temp TABLE AND re - enqueues them TO
    -- THE AGENT. it supports messages OF wf_event_t AND sys.aq$_jms_text_message TYPE.
    --
    -- usage -- sqlplus apps / < apps pwd > @wfaqrenq.SQL < AGENT NAME >
    --
    -- modification log :
    -- 04 / 04 / 2008 sstomar modified TO take THE back - up OF alerts also
    -- + == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == = +

    fnd_file.put_line(fnd_file.log, ' ** * re - enqueing messages');

    DECLARE
      l_agent      wf_agent_t;
      l_rows       INTEGER;
      l_agent_name VARCHAR2(30) := upper(p_agent_name);
      l_schema     VARCHAR2(128);
      l_data_type  VARCHAR2(106);
      l_queue_name VARCHAR2(80);
      l_qname      VARCHAR2(80);
      l_pos        NUMBER := 0;

      l_q_correlation_id VARCHAR2(240);

      l_evt_user_data wf_event_t;

      TYPE t_user_data_evt_tbl IS TABLE OF wf_event_t INDEX BY BINARY_INTEGER;
      TYPE t_user_data_jms_tbl IS TABLE OF sys.aq$_jms_text_message INDEX BY BINARY_INTEGER;
      TYPE t_corr_id_tbl IS TABLE OF VARCHAR2(128) INDEX BY BINARY_INTEGER;

      l_user_data_evt_tbl t_user_data_evt_tbl;
      l_user_data_jms_tbl t_user_data_jms_tbl;
      l_corr_id_tbl       t_corr_id_tbl;

      CURSOR c_evt_bkup_msg(p_queue_name IN VARCHAR2) IS
        SELECT user_data
        FROM   wf_queue_temp_evt_table
        WHERE  queue = p_queue_name
        ORDER  BY enq_time;

      CURSOR c_jms_bkup_msg(p_queue_name IN VARCHAR2) IS
        SELECT user_data,
     corr_id
        FROM   wf_queue_temp_jms_table
        WHERE  queue = p_queue_name
        ORDER  BY enq_time;
    BEGIN
      SELECT queue_name
      INTO   l_queue_name
      FROM   wf_agents
      WHERE  NAME = l_agent_name
      AND    system_guid = wf_event.local_system_guid;

      l_pos    := instr(l_queue_name, '.', 1, 1);
      l_schema := substr(l_queue_name, 1, l_pos - 1);
      l_qname  := substr(l_queue_name, l_pos + 1);

      SELECT TRIM(object_type)
      INTO   l_data_type
      FROM   all_queue_tables
      WHERE  queue_table IN (SELECT queue_table
         FROM   all_queues
         WHERE  NAME = l_qname
         AND    owner = l_schema)
      AND    owner = l_schema;

      l_pos       := instr(l_data_type, '.', 1, 1);
      l_data_type := substr(l_data_type, l_pos + 1);

      l_agent := wf_agent_t(l_agent_name, wf_event.local_system_name);
      l_rows  := 5000;

      IF (l_data_type LIKE '%WF_EVENT_T') THEN
        OPEN c_evt_bkup_msg(l_agent_name);
        IF (upper(l_agent_name) = 'WF_ERROR') THEN
          LOOP
  FETCH c_evt_bkup_msg BULK COLLECT
    INTO l_user_data_evt_tbl LIMIT l_rows;
  EXIT WHEN l_user_data_evt_tbl.count = 0;

  FOR i IN 1 .. l_user_data_evt_tbl.last LOOP
    wf_error_qh.enqueue(l_user_data_evt_tbl(i), l_agent);
  END LOOP;

  COMMIT;
  l_user_data_evt_tbl.delete;
          END LOOP;
        ELSE
          LOOP
  FETCH c_evt_bkup_msg BULK COLLECT
    INTO l_user_data_evt_tbl LIMIT l_rows;
  EXIT WHEN l_user_data_evt_tbl.count = 0;

  FOR i IN 1 .. l_user_data_evt_tbl.last LOOP
    wf_event.enqueue(l_user_data_evt_tbl(i), l_agent);
  END LOOP;
  COMMIT;
  l_user_data_evt_tbl.delete;
          END LOOP;
        END IF;
        CLOSE c_evt_bkup_msg;

      ELSE
        IF l_data_type LIKE '%AQ$_JMS_TEXT_MESSAGE' THEN
          OPEN c_jms_bkup_msg(l_agent_name);
          LOOP

  FETCH c_jms_bkup_msg BULK COLLECT
    INTO l_user_data_jms_tbl,
         l_corr_id_tbl LIMIT l_rows;

  EXIT WHEN l_user_data_jms_tbl.count = 0;

  -- Re-enqueue each message
  FOR i IN 1 .. l_user_data_jms_tbl.last LOOP

    wf_event_ojmstext_qh.deserialize(l_user_data_jms_tbl(i),
                 l_evt_user_data);

    -- Below code is to re-enqueue Alerts with proper corrId.
    --
    l_q_correlation_id := l_corr_id_tbl(i);

    -- l_q_correlation_id := l_evt_user_data.getValueForParameter('Q_CORRELATION_ID');

    IF ((l_q_correlation_id IS NOT NULL) AND
       (l_q_correlation_id = 'APPS:ALR')) THEN

      -- Note: we should NOT use schema name here like 'APPS:ALR:
      --       otherwise message will be enqueued with corrid LIKE APPS:APPS:ALR:
      l_q_correlation_id := 'ALR:';

      l_evt_user_data.setcorrelationid(l_q_correlation_id);

      -- Update in param list TOO, incase
      l_evt_user_data.addparametertolist('Q_CORRELATION_ID',
           l_q_correlation_id);
    END IF;

    wf_event.enqueue(l_evt_user_data, l_agent);

  END LOOP;
  COMMIT;

  l_user_data_jms_tbl.delete;

          END LOOP;
          CLOSE c_jms_bkup_msg;
        END IF;
      END IF;
    END;

    COMMIT;

    fnd_file.put_line(fnd_file.log,
            ' ** ** * re - enqueue OF alerts completed ** ** *');

  END workflow_aq_reenqueue;

  --------------------------------------------------------------------
  --  name:              workflow_aq_backup
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    XXX               Initial
  --------------------------------------------------------------------
  PROCEDURE workflow_aq_backup(p_agent_name VARCHAR2) IS

  BEGIN

    --dbdrv: none
    -- $Header: wfaqback.sql 120.0.12000000.8 2008/04/04 08:35:47 sstomar ship $
    -- +=========================================================================+
    -- |            Copyright (c) 2005, Oracle. All rights reserved.             |
    -- +=========================================================================+
    --
    -- NAME
    --   wfaqback.sql - WorkFlow AQ BACK up script
    --
    -- DESCRIPTION
    --   This script helps to back up a given Workflow Advanced Queue(of WF_EVENT_T
    --   or SYS.AQ$_JMS_TEXT_MESSAGE payload) for a list of given correlation ids.
    --   The AQ messages are stored in an intermediate table. Once the queue in
    --   question is recreated, the messages can be re-enqueued on to the queue using
    --   wfaqrenq.sql which will take the messages from the intermediate table and
    --   re-equeue them.
    --
    --   Typical steps in this process...
    --   1. Back up all required events using $FND_TOP/sql/wfaqback.sql. You may
    --      specify all the corrids that you *DO NOT WANT* in "l_unwanted_events"
    --      PLSQL table below. All messages other than this list would be backed up.
    --   2. If % is specified in the list, it means that all the messages are to be
    --      --oved from the queue and none is required to be backed up. This is
    --      same as recreating the queue without backing up messages.
    --   3. If wfaqback.sql completes successfully, verify in the intermediate
    --      table(s) wf_queue_temp_[evt|jms]_table if the required messages are
    --      backed up.
    --   4. After confirming that the messages are backed up, drop and recreate the
    --      queue in question.
    --      a) Find and note tablespace used by index on CORRID column to be used
    --         later when recreating the index on CORRID.
    --           SELECT index_name, tablespace_name
    --           FROM   all_indexes
    --           WHERE  index_name = '<Queue Table Name>_N1';
    --      b) Drop the queue
    --         wfevqued.sql - All WF queues
    --      c) Create the queue
    --         wfbesqc.sql  - All BES JMS queues like Java Deferred, Java Error etc.
    --         wfevquc2.sql - All BES WF_EVENT_T queues like Deferred, Error etc.
    --         wfjmsqc2.sql - All Ntf queues like Notification Out and Notification In
    --      d) Create subscribers
    --         wfbesqsubc.sql - All BES JMS/WF_EVENT_T queues like Java Deferred,
    --                          Java Error, Deferred, Error etc.
    --         wfmqsubc2.sql  - All Ntf queues like Notification Out and Notification In
    --      e) Create index on corrid
    --         wfbesqidxc.sql - All BES JMS/WF_EVENT_T queues like Java Deferred,
    --                          Java Error, Deferred, Error etc.
    --         wfqidxc2.sql   - All Ntf queues like Notification Out and Notification In
    --      f) Gather table statistics
    --         wfhistc.sql - All WF objects
    --   5. Re-enqueue backed up messages to the queue using $FND_TOP/sql/wfaqrenq.sql.
    --
    --   More infomation in bug 4111510 update *** SACSHARM  01/19/05 06:32 pm ***
    --
    -- USAGE
    --   sqlplus apps/<apps pwd> @wfaqback.sql <Agent Name>/[corrid]
    --
    --   You may optionally specify a corrid that you *DO WANT* to back up as commandline
    --   parameter. This overrides the values mentioned in the PLSQL table i
    --   *l_unwanted_events*. By passing a corrid after a / following the agent name would
    --   back up ONLY that corrid from the queue.
    --
    -- +===================================================================================+

    --whenever sqlerror exit failure rollback;
    --whenever oserror exit failure rollback;

    -- Create a table to backup the messages. CREATE GLOBAL TEMPORARY TABLE
    -- does not work since we have wf_event_t datatype in the table

    DECLARE
      l_agent_name  VARCHAR2(128) := upper(p_agent_name);
      l_sql_evt_str VARCHAR2(4000);
      l_sql_jms_str VARCHAR2(4000);
      l_sql_del_str VARCHAR2(4000);
      l_schema      VARCHAR2(80);
      l_qname       VARCHAR2(80);
      l_queue_name  VARCHAR2(80);
      l_data_type   VARCHAR2(106);
      l_pos         NUMBER := 0;

      object_exists EXCEPTION;
      PRAGMA EXCEPTION_INIT(object_exists, -955);
    BEGIN

      l_pos := instr(l_agent_name, '/', 1, 1);
      IF l_pos > 0 THEN
        l_agent_name := substr(l_agent_name, 1, l_pos - 1);
      END IF;
      l_pos := 0;

      SELECT queue_name
      INTO   l_queue_name
      FROM   wf_agents
      WHERE  NAME = l_agent_name
      AND    system_guid = wf_event.local_system_guid;

      l_pos    := instr(l_queue_name, '.', 1, 1);
      l_schema := substr(l_queue_name, 1, l_pos - 1);
      l_qname  := substr(l_queue_name, l_pos + 1);

      SELECT TRIM(object_type)
      INTO   l_data_type
      FROM   all_queue_tables
      WHERE  queue_table IN (SELECT queue_table
         FROM   all_queues
         WHERE  NAME = l_qname
         AND    owner = l_schema)
      AND    owner = l_schema;

      l_pos       := instr(l_data_type, '.', 1, 1);
      l_data_type := substr(l_data_type, l_pos + 1);

      -- Create a temporary tables to backup messages from different queues
      l_sql_evt_str := 'CREATE TABLE wf_queue_temp_evt_table ' ||
             '  (enq_time  date, ' ||
             '   queue     varchar2(30), ' ||
             '   corr_id   varchar2(128), ' ||
             '   delay     date, ' || '   user_data WF_EVENT_T)';
      l_sql_jms_str := 'CREATE TABLE wf_queue_temp_jms_table ' ||
             '  (enq_time  date, ' ||
             '   queue     varchar2(30), ' ||
             '   corr_id   varchar2(128), ' ||
             '   delay     date, ' ||
             '   user_data SYS.AQ$_JMS_TEXT_MESSAGE)';
      BEGIN
        EXECUTE IMMEDIATE l_sql_evt_str;
        EXECUTE IMMEDIATE l_sql_jms_str;
      EXCEPTION
        WHEN object_exists THEN
          IF (l_data_type LIKE '%WF_EVENT_T') THEN
  l_sql_del_str := ' DELETE FROM wf_queue_temp_evt_table ' ||
         ' WHERE queue = ''' || l_agent_name || '''';
  EXECUTE IMMEDIATE l_sql_del_str;
  EXECUTE IMMEDIATE l_sql_jms_str;
          ELSE
  IF l_data_type LIKE '%AQ$_JMS_TEXT_MESSAGE' THEN
    EXECUTE IMMEDIATE l_sql_jms_str;
    l_sql_del_str := ' DELETE FROM wf_queue_temp_jms_table ' ||
           ' WHERE queue = ''' || l_agent_name || '''';
    EXECUTE IMMEDIATE l_sql_del_str;
  END IF;
          END IF;
      END;

    EXCEPTION
      WHEN object_exists THEN
        IF l_data_type LIKE '%AQ$_JMS_TEXT_MESSAGE' THEN
          l_sql_del_str := ' DELETE FROM wf_queue_temp_jms_table ' ||
       ' WHERE queue = ''' || l_agent_name || '''';
          EXECUTE IMMEDIATE l_sql_del_str;
        END IF;
      WHEN OTHERS THEN
        raise_application_error(-20000,
            'Oracle Error = ' || to_char(SQLCODE) ||
            ' - ' || SQLERRM);
    END;

    COMMIT;

    fnd_file.put_line(fnd_file.log,
            '**** TEMPORARY TABLES / AQs created ****');

    -- Back up the events as per the users exclusion list given above

    DECLARE
      l_schema       VARCHAR2(128);
      l_agent_name   VARCHAR2(128) := p_agent_name;
      l_queue        VARCHAR2(128);
      l_corr_id      VARCHAR2(128);
      l_account_name VARCHAR2(128);
      l_where        VARCHAR2(32000);
      l_sql_str      VARCHAR2(32000);
      l_ntf_corr_str VARCHAR2(106);
      l_data_type    VARCHAR2(106);
      l_queue_name   VARCHAR2(80);
      l_qname        VARCHAR2(80);
      l_pos          NUMBER := 0;

      l_rows NUMBER;

      TYPE t_strings_tbl IS TABLE OF VARCHAR2(80);

      TYPE t_bkup_msg IS REF CURSOR;
      c_bkup_msg t_bkup_msg;

      TYPE t_enq_time_tbl IS TABLE OF DATE INDEX BY BINARY_INTEGER;
      TYPE t_queue_tbl IS TABLE OF VARCHAR2(30) INDEX BY BINARY_INTEGER;
      TYPE t_corr_id_tbl IS TABLE OF VARCHAR2(128) INDEX BY BINARY_INTEGER;
      TYPE t_user_data_evt_tbl IS TABLE OF wf_event_t INDEX BY BINARY_INTEGER;
      TYPE t_user_data_jms_tbl IS TABLE OF sys.aq$_jms_text_message INDEX BY BINARY_INTEGER;
      TYPE t_delay_tbl IS TABLE OF DATE INDEX BY BINARY_INTEGER;

      l_enq_time_tbl      t_enq_time_tbl;
      l_queue_tbl         t_queue_tbl;
      l_corr_id_tbl       t_corr_id_tbl;
      l_delay_tbl         t_delay_tbl;
      l_user_data_evt_tbl t_user_data_evt_tbl;
      l_user_data_jms_tbl t_user_data_jms_tbl;

      -- #### UPDATE THIS TABLE WITH EVENT NAMES THAT YOU WANT TO --OVED  #### --
      -- #### If you specify % here, all events will be --oved #### --
      l_unwanted_events t_strings_tbl := t_strings_tbl( -- 'APPS:APPS:ALR:'
           -- ,'oracle.apps.cs.sr.ServiceRequest%'
           -- Add more event names here that you want to be --OVED
           );

    BEGIN
      -- Retrieving corr_id of the events that are to be backed up
      l_pos := instr(l_agent_name, '/', 1, 1);
      IF l_pos > 0 THEN
        l_ntf_corr_str := substr(l_agent_name, l_pos + 1);
        l_agent_name   := upper(substr(l_agent_name, 1, l_pos - 1));
      END IF;

      SELECT queue_name
      INTO   l_queue_name
      FROM   wf_agents
      WHERE  NAME = upper(l_agent_name)
      AND    system_guid = wf_event.local_system_guid;

      l_pos    := instr(l_queue_name, '.', 1, 1);
      l_schema := substr(l_queue_name, 1, l_pos - 1);
      l_qname  := substr(l_queue_name, l_pos + 1);

      SELECT TRIM(object_type)
      INTO   l_data_type
      FROM   all_queue_tables
      WHERE  queue_table IN (SELECT queue_table
         FROM   all_queues
         WHERE  NAME = l_qname
         AND    owner = l_schema)
      AND    owner = l_schema;

      -- Query from the AQ view table
      l_queue := l_schema || '.AQ$' || l_qname;

      l_pos       := instr(l_data_type, '.', 1, 1);
      l_data_type := substr(l_data_type, l_pos + 1);

      -- Can be adjusted accordingly
      l_rows := 5000;

      -- Set the correlation id
      IF (l_ntf_corr_str IS NOT NULL) THEN
        l_where := ' corr_id LIKE ''' || l_ntf_corr_str || '''';
      ELSE
        IF (l_unwanted_events IS NULL OR l_unwanted_events.count = 0) THEN
          l_where := ' corr_id LIKE ''%''';
        ELSE
          l_account_name := NULL;
          -- Set the account name for WF_% agents
          IF (upper(l_agent_name) LIKE 'WF_%') THEN
  IF (wf_event.account_name IS NULL) THEN
    wf_event.setaccountname;
  END IF;
  l_account_name := wf_event.account_name;
          END IF;
          l_corr_id := l_account_name || ':' || l_unwanted_events(1);
          l_where   := ' corr_id NOT LIKE ''' || l_corr_id || '''';

          FOR i IN 2 .. l_unwanted_events.last LOOP
  l_corr_id := l_account_name || ':' || l_unwanted_events(i);
  l_where   := l_where || ' AND corr_id NOT LIKE ''' || l_corr_id || '''';
          END LOOP;
        END IF;
      END IF;

      l_sql_str := 'SELECT enq_time, ' || ' queue, ' || ' corr_id, ' ||
         ' delay, ' || ' user_data ' || ' FROM ' || l_queue ||
         ' WHERE ' || l_where ||
         ' AND msg_state in (''READY'', ''WAIT'')' ||
         ' ORDER BY ENQ_TIME';
      IF (l_data_type LIKE '%WF_EVENT_T') THEN
        OPEN c_bkup_msg FOR l_sql_str;
        LOOP
          -- Bulk fetch 5000 records each time
          FETCH c_bkup_msg BULK COLLECT
  INTO l_enq_time_tbl,
       l_queue_tbl,
       l_corr_id_tbl,
       l_delay_tbl,
       l_user_data_evt_tbl LIMIT l_rows;
          EXIT WHEN l_enq_time_tbl.count = 0;
          -- Insert into the temporary table
          FORALL j IN l_enq_time_tbl.first .. l_enq_time_tbl.last
  INSERT INTO wf_queue_temp_evt_table
    (enq_time,
     queue,
     corr_id,
     delay,
     user_data)
  VALUES
    (l_enq_time_tbl(j),
     l_queue_tbl(j),
     l_corr_id_tbl(j),
     l_delay_tbl(j),
     l_user_data_evt_tbl(j));
          l_enq_time_tbl.delete;
          COMMIT;
        END LOOP;
        CLOSE c_bkup_msg;
      ELSE
        IF l_data_type LIKE '%AQ$_JMS_TEXT_MESSAGE' THEN
          OPEN c_bkup_msg FOR l_sql_str;
          LOOP
  -- Bulk fetch 5000 records each time
  FETCH c_bkup_msg BULK COLLECT
    INTO l_enq_time_tbl,
         l_queue_tbl,
         l_corr_id_tbl,
         l_delay_tbl,
         l_user_data_jms_tbl LIMIT l_rows;
  EXIT WHEN l_enq_time_tbl.count = 0;
  -- Insert into the temporary table
  FORALL j IN l_enq_time_tbl.first .. l_enq_time_tbl.last
    INSERT INTO wf_queue_temp_jms_table
      (enq_time,
       queue,
       corr_id,
       delay,
       user_data)
    VALUES
      (l_enq_time_tbl(j),
       l_queue_tbl(j),
       l_corr_id_tbl(j),
       l_delay_tbl(j),
       l_user_data_jms_tbl(j));
  l_enq_time_tbl.delete;
  COMMIT;
          END LOOP;
          CLOSE c_bkup_msg;
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        IF (c_bkup_msg%ISOPEN) THEN
          CLOSE c_bkup_msg;
        END IF;
        raise_application_error(-20000,
            'Oracle Error = ' || to_char(SQLCODE) ||
            ' - ' || SQLERRM);
    END;

    fnd_file.put_line(fnd_file.log, '**** Messages backed up ****');

    COMMIT;
    -- exit;

  END workflow_aq_backup;

  --------------------------------------------------------------------
  --  name:              resend_notification
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :          new version for previous resebd_notification
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    yuval tal         Initial
  --  1.2    1.1.18      yuval tal         INC0110709 - start sending mail  after 24 H
  --------------------------------------------------------------------
  PROCEDURE resend_notification(errbuf                    OUT VARCHAR2,
            retcode                   OUT VARCHAR2,
            p_item_type               VARCHAR2,
            p_messages_name_delimited VARCHAR2,
            p_notification_id         NUMBER,
            p_days                    NUMBER) IS

    CURSOR c IS
      SELECT t.notification_id
      FROM   wf_notifications t
      WHERE  t.message_type = p_item_type
      AND    (p_messages_name_delimited IS NULL OR
  instr(p_messages_name_delimited, t.message_name) > 0)
      AND    t.status = 'OPEN'
      AND    nvl(mail_status, 'MAIL') != 'MAIL'
      AND    t.notification_id = nvl(p_notification_id, t.notification_id)
      AND    t.begin_date + p_days > SYSDATE
      AND    SYSDATE >= begin_date + 1; --INC0110709
    l_count     NUMBER := 0;
    l_count_err NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c LOOP
      l_count := l_count + 1;
      BEGIN
        SAVEPOINT a;
        wf_notification.resend(i.notification_id);

      EXCEPTION
        WHEN OTHERS THEN
          l_count_err := l_count_err + 1;
          dbms_output.put_line(i.notification_id || ' ' || SQLERRM);
          fnd_file.put_line(fnd_file.log,
        substr(i.notification_id || ' ' || SQLERRM,
               1,
               249));
          retcode := 1;
          ROLLBACK TO a;
      END;
    END LOOP;
    COMMIT;

    errbuf := l_count || ' Notifications (Mail) Resend  , ' || l_count_err ||
    ' Notification failed';
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:              close_po
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :          CLOSE OPEN PO
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  XX/XX/XXXX    yuval tal         Initial
  --  1.x  14.4.2013     yoram zamir       NVL(pha.closed_code,'OPEN') instead of pha.closed_code   Yoram Zamir 10-APR-2013
  --                                       condition: plla.receipt_required_flag = 'N' was removed
  --                                       New condition (plla.receipt_required_flag != 'Y' OR (plla.receipt_required_flag = 'Y' AND plla.quantity - nvl(plla.quantity_cancelled, 0) = plla.quantity_received))
  --  1.1  25.4.2013     yuval tal         modify close po - bugfix
  --------------------------------------------------------------------
  PROCEDURE close_po(errbuf      OUT VARCHAR2,
           retcode     OUT VARCHAR2,
           p_org_id    NUMBER,
           p_from_date VARCHAR2,
           p_to_date   VARCHAR2,
           p_po_number VARCHAR2) IS
    CURSOR c IS
      SELECT pha.segment1,
   pha.type_lookup_code,
   pha.po_header_id,
   COUNT(*) line_count
      FROM   po_headers_all        pha,
   po_lines_all          pla,
   po_line_locations_all plla
      WHERE  pha.org_id = p_org_id
      AND    pla.po_header_id = pha.po_header_id
      AND    plla.po_line_id = pla.po_line_id
      AND    pha.type_lookup_code = 'STANDARD'
      AND    pha.authorization_status = 'APPROVED'
      AND    nvl(pha.cancel_flag, 'N') = 'N'
  --AND pha.closed_code = 'OPEN'
      AND    nvl(pha.closed_code, 'OPEN') = 'OPEN' -- Yoram Zamir 10-APR-2013
  --AND plla.match_option = 'P' -- Match To PO Yoram Zamir 10-APR-2013
      AND    plla.closed_code = 'CLOSED FOR INVOICE'
  --  AND plla.receipt_required_flag = 'N' -- Yoram Zamir 10-APR-2013
      AND    plla.quantity - nvl(plla.quantity_cancelled, 0) =
   plla.quantity_billed
      AND    -- Yoram Zamir 10-APR-2013
   (plla.receipt_required_flag != 'Y' OR
   (plla.receipt_required_flag = 'Y' AND
   plla.quantity - nvl(plla.quantity_cancelled, 0) =
   plla.quantity_received))

      AND    pha.segment1 = nvl(p_po_number, pha.segment1)
      AND    trunc(pha.creation_date) BETWEEN
   nvl(trunc(fnd_date.canonical_to_date(p_from_date)),
        trunc(pha.creation_date) - 1) AND
   nvl(trunc(fnd_date.canonical_to_date(p_to_date)),
       trunc(pha.creation_date) + 1)
      GROUP  BY pha.segment1,
      pha.type_lookup_code,
      pha.po_header_id;

    CURSOR c_chk_unclose_lines_exists(c_po_header_id NUMBER) IS
      SELECT 1
      FROM   po_headers_all        pha,
   po_lines_all          pla,
   po_line_locations_all plla
      WHERE  pla.po_header_id = pha.po_header_id
      AND    plla.po_line_id = pla.po_line_id
      AND    pha.type_lookup_code = 'STANDARD'
      AND    pha.authorization_status = 'APPROVED'
      AND    nvl(pha.cancel_flag, 'N') = 'N'
      AND    nvl(pha.closed_code, 'OPEN') = 'OPEN'
      AND    plla.closed_code NOT IN ('CLOSED FOR INVOICE', 'CLOSED')
      AND    pha.po_header_id = c_po_header_id;

    -- AND plla.match_option = 'P'
    -- AND plla.closed_code = 'CLOSED FOR INVOICE';
    l_count    NUMBER;
    l_err_flag VARCHAR2(1);
    l_rec      po_document_action_pvt.doc_action_call_rec_type;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR i IN c LOOP
      fnd_file.put_line(fnd_file.log,
    'Start process po_number=' || i.segment1);
      l_rec   := NULL;
      l_count := NULL;

      OPEN c_chk_unclose_lines_exists(i.po_header_id);
      FETCH c_chk_unclose_lines_exists
        INTO l_count;
      CLOSE c_chk_unclose_lines_exists;
      fnd_file.put_line(fnd_file.log, 'l_count=' || l_count);
      IF nvl(l_count, 0) = 0 THEN
        -- all line are close for invoice
        dbms_output.put_line('close po_number=' || i.segment1);
        fnd_file.put_line(fnd_file.log, 'close po_number=' || i.segment1);

        l_rec.action := 'CLOSE';
        l_rec.lock_document := FALSE;
        l_rec.document_type := 'PO';
        l_rec.document_subtype := 'STANDARD';
        l_rec.document_id := i.po_header_id;
        l_rec.employee_id := fnd_global.employee_id;
        l_rec.new_document_status := NULL;
        l_rec. approval_path_id := NULL;
        l_rec.forward_to_id := NULL;
        l_rec.note := 'Automatic Closure';
        l_rec.return_code := NULL;
        l_rec.return_status := NULL;
        l_rec.functional_error := NULL;
        l_rec.line_id := NULL;
        l_rec.shipment_id := NULL;
        l_rec.calling_mode := 'PO';
        l_rec.called_from_conc := TRUE;
        l_rec.origin_doc_id := NULL;
        l_rec.action_date := SYSDATE;
        l_rec.online_report_id := NULL;
        l_rec.use_gl_date := 'N';
        l_rec.offline_code := NULL;
        po_document_action_close.manual_close_po(l_rec);

        fnd_file.put_line(fnd_file.log,
      'return_status ' || l_rec.return_status);
        IF TRIM(l_rec.return_status) = 'S' THEN
          fnd_file.put_line(fnd_file.log,
        'PO ' || i.segment1 || ' Successfuly closed .');

        ELSE
          l_err_flag := 1;
          -- dbms_output.put_line(l_rec.error_msg || ' ' || fnd_message.get);
          fnd_file.put_line(fnd_file.log,
        'PO ' || i.segment1 || ' Unable to Close .' ||
        l_rec.error_msg || ' ' || fnd_message.get);

        END IF;

        -- END IF;
      ELSE
        l_err_flag := 1;
        --  dbms_output.put_line('po_number=' || i.segment1 ||
        --      ' is not ready to close , check closing conditions');
        fnd_file.put_line(fnd_file.log,
      'po_number=' || i.segment1 ||
      ' is not ready to close , check closing conditions');
      END IF;
      COMMIT;
    END LOOP;
    retcode := l_err_flag;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := 2;
  END close_po;

  --------------------------------------------------------------------
  --  name:              approve_po_for_kanban
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     25/02/2015
  --------------------------------------------------------------------
  --  purpose :          CHG0034191 - Automatically PO approval process
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  25/02/2015    Dalit A. Raviv    Initial
  --  1.2  02-Mar-2016   Lingaraj Sarangi  CHG0037860- Change  for Auto approve Blanket release for MIN-MAX PRs
  --                                         Procedure changed - approve_po_for_kanban
  --  1.3  17-Jul-2016  Sandeep Sapru      CHG0038856 - XXPO Kanban Approve Blanket Release - limit to Blanket line agreed qty
  --  1.4  08-Sep-2016  Yuval.Tal          INC0075201 - PO Format
  --                                       Change 1.6 having a Bug in "approve_po_for_kanban" PROCEDURE, So The fix applied for that
  --  1.5  12-Jan-2017  Nishant.Kumar      INC0084856 - Only "Approved" Blanket Agreement in consideration for "Incomplete" releases
  --  1.6  21-May-2018  Bellona(TCS)       CHG0042927 - Replace list_name with full_name for approving incomplete PO release
  --------------------------------------------------------------------
  PROCEDURE approve_po_for_kanban(errbuff OUT VARCHAR2,
              retcode OUT VARCHAR2) IS

    CURSOR c_pop IS
      SELECT po_header_id,
   po_release_id,
   po_number,
   release_num,
   quantity_ordered,
   org_id,
   type_lookup_code,
   buyer_id,
   buyer_name,
   revision_num,
   line_num,
   shipment_num,
   quantity,
   promised_date,
   need_by_date,
   ord_seq
      FROM   (SELECT ph.po_header_id,
           pra.po_release_id,
           ph.segment1 po_number,
           pra.release_num,
           pd.quantity_ordered,
           ph.org_id,
           ph.type_lookup_code,
           ph.agent_id buyer_id,
           --hr_general.decode_person_name(ph.agent_id) buyer_name,	-- CHG0042927
		   apps.hr_person_name.get_person_name(ph.agent_id,trunc(sysdate) , 'FULL_NAME') buyer_name, 	--CHG0042927
           pra.revision_num,
           pl.line_num,
           pll.shipment_num,
           pll.quantity,
           pll.promised_date,
           pll.need_by_date,
           -- this wil cause that only one record per Release will be handle
           row_number() over(PARTITION BY pra.po_release_id ORDER BY pd.po_distribution_id) ord_seq
    FROM   po_headers_all             ph,
           po_lines_all               pl,
           po_releases_all            pra,
           po_line_locations_all      pll,
           po_distributions_all       pd,
           po_req_distributions_all   prd, -- Added CHG0037860
           po_requisition_lines_all   prl, -- Added CHG0037860
           po_requisition_headers_all prh, -- Added CHG0037860
           po_asl_attributes          paa, -- Added CHG0037860
           po_approved_supplier_list  pas, -- Added CHG0037860
           mtl_system_items_b         msi -- Added CHG0037860
    -- locate all items that are supplier kanban
    WHERE  ph.type_lookup_code = 'BLANKET'
    AND    pl.po_header_id = ph.po_header_id
    AND    pra.po_header_id = pl.po_header_id
    AND    ph.authorization_status = 'APPROVED' -- Added INC0084856
    AND    nvl(pra.authorization_status, 'INCOMPLETE') =
           'INCOMPLETE'
    AND    pd.po_header_id = pl.po_header_id
    AND    pd.po_line_id = pl.po_line_id
    AND    pd.po_release_id = pra.po_release_id
    AND    pll.line_location_id = pd.line_location_id
          -- Start CHG0037860
    AND    pd.req_distribution_id = prd.distribution_id
    AND    prd.requisition_line_id = prl.requisition_line_id
    AND    prl.requisition_header_id = prh.requisition_header_id
    AND    prh.interface_source_code = 'INV'
          --and    pd.kanban_card_id     is not null
          --and    ph.segment1 = '100040767';
          --and    pra.po_release_id = 231017;
    AND    paa.item_id = pl.item_id
    AND    paa.vendor_id = ph.vendor_id
    AND    paa.vendor_site_id = ph.vendor_site_id
    AND    pas.item_id = pl.item_id
    AND    pas.vendor_id = ph.vendor_id
    AND    pas.vendor_site_id = ph.vendor_site_id
    AND    pas.asl_status_id = 2 -- Approved
    AND    paa.release_generation_method = 'CREATE'
    AND    msi.inventory_item_id = pl.item_id
    AND    msi.organization_id = pd.destination_organization_id
    AND    (((msi.inventory_planning_code = 2) AND
          (msi.source_type = 2)) OR
          (pl.item_id IN
          (SELECT mkp.inventory_item_id
    FROM   mtl_kanban_pull_sequences mkp
    WHERE  mkp.source_type = 2 -- Supplier
    AND    mkp.organization_id =
           pd.destination_organization_id
    AND    mkp.inventory_item_id = pl.item_id)))) -- END CHG0037860
      WHERE  ord_seq = 1;

    ----------- Added CHG0038856 Sandeep sapru 17-jul-2016---------
    ----------- Description : To validate those Blanket releases whose total released qty is greater then Agreed Qty

    CURSOR c_rec(p_header_id NUMBER) IS
      SELECT pha.po_header_id,
   SUM(plla.quantity - plla.quantity_cancelled) quantity_released,
   pla.quantity_committed,
   pla.line_num
      FROM   po_headers_all        pha,
   po_lines_all          pla,
   po_releases_all       pra,
   po_line_locations_all plla
      WHERE  pha.po_header_id = pla.po_header_id
      AND    pla.po_line_id = plla.po_line_id
      AND    pra.po_release_id = plla.po_release_id
      AND    pha.authorization_status = 'APPROVED'
      AND    pha.closed_code IS NULL
      AND    pra.po_header_id = p_header_id
      GROUP  BY pha.po_header_id,
      plla.po_line_id,
      pla.quantity_committed,
      pla.line_num;

    l_num        NUMBER := NULL;
    l_api_errors po_api_errors_rec_type;
    p_flag       CHAR(1); ---- Added CHG0038856

  BEGIN

    errbuff := NULL;
    retcode := 0;
    p_flag  := 'Y'; ---- Added CHG0038856

    /*-- for debug
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 50623,resp_appl_id => 660);
    mo_global.set_org_context(p_org_id_char     => 81,
                              p_sp_id_char      => NULL,
                              p_appl_short_name => 'AR');*/

    FOR r_pop IN c_pop LOOP

      -- in order the PO to be approve, the PO need's to change . the parameter
      -- LAUNCH_APPROVALS_FLAG to 'Y' cause the PO touse the approval WF.
      -- the approval WF send mail to buyer and to supplier.

      FOR p_rec IN c_rec(r_pop.po_header_id) LOOP

        -- ---- start CHG0038856 Added Sandeep
        -- ----  If the total released qty is less then the total committed qty (or Agreed qty) then only call the API
        ----- Else keep the release into "Incomplete" status
        IF r_pop.line_num = p_rec.line_num THEN

          IF (p_rec.quantity_released <= p_rec.quantity_committed) THEN

  p_flag := 'Y';

  --8 Sep 2016 - Yuval Tal - INC0075201 - Supplier Notification with PDF
  mo_global.set_org_context(p_org_id_char     => r_pop.org_id,
        p_sp_id_char      => NULL,
        p_appl_short_name => 'PO');
  fnd_file.put_line(fnd_file.log, 'ORG ID :' || r_pop.org_id);
  fnd_file.put_line(fnd_file.log,
          'po_number :' || r_pop.po_number);
  --INC0075201

  l_num := po_change_api1_s.update_po(x_po_number           => r_pop.po_number,
        x_release_number      => r_pop.release_num,
        x_revision_number     => r_pop.revision_num,
        x_line_number         => r_pop.line_num,
        x_shipment_number     => r_pop.shipment_num,
        new_quantity          => to_number(NULL),
        new_price             => to_number(NULL),
        new_promised_date     => CASE
               WHEN r_pop.promised_date IS NOT NULL THEN
                r_pop.promised_date - (1 / 24 / 60 / 60)
               ELSE
                NULL
             END,
        new_need_by_date      => CASE
               WHEN r_pop.need_by_date IS NOT NULL THEN
                r_pop.need_by_date - (1 / 24 / 60 / 60)
               ELSE
                NULL
             END,
        launch_approvals_flag => 'Y', -- launch approval through workflow
        update_source         => NULL, -- Reserved for future use
        version               => '1.0', -- Version of the API
        x_override_date       => SYSDATE, -- for the reserved po
        x_api_errors          => l_api_errors, -- PO_API_ERRORS_REC_TYPE for debug
        p_buyer_name          => r_pop.buyer_name, -- buyer name can get other then the one who mad the po
        p_secondary_quantity  => NULL,
        p_preferred_grade     => NULL,
        p_org_id              => r_pop.org_id);

          ELSE
  ---- Added CHG0038856
  ---- put into the log file the PO details whose released qty is gretaer then comitted qty
  p_flag := 'N';
  fnd_file.put_line(fnd_file.log,
          'Order Number ' || r_pop.po_number || '-' ||
          'Release Number ' || r_pop.release_num || '-' ||
          ' Released quantity ' ||
          p_rec.quantity_released || ' :' ||
          ' greater then Comitted quantity ' || ' :' ||
          p_rec.quantity_committed);
  -- fnd_file.put_line(fnd_file.log,errbuff||' '||retcode);
          END IF; ---- end CHG0038856
        END IF; ---- end CHG0038856
        IF l_num = 1 THEN
          -- success to update
          COMMIT;
          EXIT; --8 Sep 2016 - Yuval Tal - INC0075201 - Supplier Notification with PDF
        ELSIF l_num = 0 THEN
          -- faile to update
          ROLLBACK;
          FOR i IN 1 .. l_api_errors.message_text.count LOOP
  retcode := 1;
  errbuff := 'could not update some of the PO''s please look at the log';
  fnd_file.put_line(fnd_file.log,
          'could not update po_num - ' ||
          r_pop.po_number || ' release_num - ' ||
          r_pop.release_num || chr(10) ||
          ' message_name - ' ||
          l_api_errors.message_name(i) || chr(10) ||
          ' message_text - ' ||
          l_api_errors.message_text(i));
  /*dbms_output.put_line('could not update po_num - '||r_pop.po_number||
            ' release_num - '||r_pop.release_num||chr(10)||
            ' message_name - '||l_api_errors.message_name(i)||chr(10)||
            ' message_text - '||l_api_errors.message_text(i));*/

          END LOOP; -- msg_text
        END IF; --l_num

      ---2nd cursor End Loop
      END LOOP;
    END LOOP;
  END approve_po_for_kanban;

END xxpo_documents_action_pkg;
/