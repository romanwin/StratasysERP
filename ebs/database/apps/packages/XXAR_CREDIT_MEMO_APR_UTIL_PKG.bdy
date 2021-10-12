CREATE OR REPLACE PACKAGE BODY xxar_credit_memo_apr_util_pkg IS
  --------------------------------------------------------------------
  --  name:            XXAR_CREDIT_MEMO_APR_UTIL_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032802 - SOD-Credit Memo Approval Workflow
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08.2014     Michal Tzvik      initial build
  --  1.1  10/03/2015  Dalit A. Raviv    CHG0034685 - Add LATAM APPROVER 
  --                                     procedures - get_approver
  --------------------------------------------------------------------

  g_enable_cm_approval_wf varchar2(1);
  g_message               varchar2(2500);

  c_debug_module CONSTANT VARCHAR2(100) := 'xxar.cm_approval.xxar_credit_memo_apr_util_pkg.';

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_approval_wf_itemkey
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      16/09/2014
  --  Purpose :           Get item key of XXWFDOC for given cistomer_trx_id
  --                      and doc_status.
  --                     It is been called by XXARCUSTOM.pll
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_approval_wf_itemkey(p_customer_trx_id NUMBER,
                                   p_doc_status      VARCHAR2)
    RETURN VARCHAR2 IS
    l_itemkey VARCHAR2(20);
  BEGIN
    SELECT xwdi.wf_item_key
    INTO   l_itemkey
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd
    WHERE  xwd.doc_id = xwdi.doc_id
    AND    xwd.doc_code = 'AR_CM_TRX'
    AND    xwdi.n_attribute1 = p_customer_trx_id
    AND    xwdi.doc_status = p_doc_status
    AND    rownum = 1;

    RETURN l_itemkey;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_approval_wf_itemkey;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               is_approval_required
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :          Check if approval is needed for current cm
  --                     It is been called by XXARCUSTOM.pll
  --                     Use for hide Complete button, and in order to avoid
  --                     Submit WF if no approval is required.
  --                     Parameters:
  --                     p_customer_trx_id
  --                     p_previous_customer_trx_id - Default value is null.
  --                                          In case of Trancsaction -> Credit,
  --                                          customer_trx_id  of the credit memo
  --                                          still not exist in DB, so function will use
  --                                          p_previous_customer_trx_id instead
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION is_approval_required(p_customer_trx_id          NUMBER,
                                p_previous_customer_trx_id NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_is_approval_required VARCHAR2(1);
    l_customer_trx_rec     ra_customer_trx%ROWTYPE;
    l_item_key             VARCHAR2(15);
    l_check_prev_trx       VARCHAR2(1) := 'N';
  BEGIN
    l_is_approval_required := 'Y';
    g_message              := '';

    BEGIN
      SELECT *
      INTO   l_customer_trx_rec
      FROM   ra_customer_trx_all rct
      WHERE  rct.customer_trx_id = p_customer_trx_id;
    EXCEPTION
      WHEN no_data_found THEN
        SELECT *
        INTO   l_customer_trx_rec
        FROM   ra_customer_trx_all rct
        WHERE  rct.customer_trx_id = p_previous_customer_trx_id;

        l_check_prev_trx := 'Y';
    END;

    -- non - intercompany Customers only
    BEGIN
      SELECT 'N'
      INTO   l_is_approval_required
      FROM   hz_cust_accounts hca
      WHERE  hca.cust_account_id = l_customer_trx_rec.bill_to_customer_id
      AND    hca.customer_type = 'I';

      g_message := 'Customer is internal. Please use the ''Complete'' button.';
      RETURN 'N';

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    -- Transaction class ‘Credit Memo’ only
    IF l_check_prev_trx = 'N' THEN
      BEGIN
        SELECT 'N'
        INTO   l_is_approval_required
        FROM   ra_cust_trx_types rctt
        WHERE  rctt.cust_trx_type_id = l_customer_trx_rec.cust_trx_type_id
        AND    rctt.type != 'CM';

        g_message := 'Transaction type is not Credit Memo. Please use the ''Complete'' button.';
        RETURN 'N';

      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;

      -- CM with Zero amount don’t require approval
      BEGIN
        SELECT 'N'
        INTO   l_is_approval_required
        FROM   ra_customer_trx_lines_all rctl
        WHERE  rctl.customer_trx_id = l_customer_trx_rec.customer_trx_id
         HAVING SUM(rctl.extended_amount) = 0;

        g_message := 'CM amount is zero. Please use the ''Complete'' button.';
        RETURN 'N';

      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;

      -- CM that are APPROVED but not yet complete should not submit WF
      l_item_key := get_approval_wf_itemkey(p_customer_trx_id, 'APPROVED');

      IF l_item_key IS NOT NULL AND
         l_customer_trx_rec.attribute5 = 'APPROVED' THEN
        g_message := 'Current CM is allready approved. Use the Complete button.';
        RETURN 'N';
      END IF;
    END IF;

    RETURN 'Y';

  END is_approval_required;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               call_apps_initialize
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Update DFF CM Approval Status in transaction header
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE set_cm_approval_status(p_customer_trx_id NUMBER,
                                   p_status          VARCHAR2) IS

  BEGIN
    UPDATE ra_customer_trx_all rct
    SET    rct.attribute5 = p_status
    WHERE  rct.customer_trx_id = p_customer_trx_id;

    COMMIT;

  END set_cm_approval_status;
  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               call_apps_initialize
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           call fnd_global.apps_initialize. use to run api with requestor values
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE call_apps_initialize(p_doc_instance_id IN NUMBER) IS
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    l_org_id       NUMBER;
  BEGIN

    xxobjt_wf_doc_util.get_apps_initialize_params(p_doc_instance_id, l_user_id, l_resp_id, l_resp_appl_id);

    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);

    SELECT xwdi.attribute6
    INTO   l_org_id
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;

    mo_global.set_policy_context('S', l_org_id);
    mo_global.init('AR');
    dbms_output.put_line('org_id=' || l_org_id);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END call_apps_initialize;
  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               is_completion_enabled
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18/08/2014
  --  Purpose :           Run validations on transaction, and check if
  --                      completion can be done

  --                      Called by personalization on Transaction form (AR)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION is_completion_enabled(p_customer_trx_id IN NUMBER) RETURN VARCHAR2 IS
    l_so_source_code VARCHAR2(255);
    l_error_count    NUMBER;
    l_msg_data       VARCHAR2(3000) := '';
    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN

    mo_global.init('AR');
    l_so_source_code := oe_profile.value('SO_SOURCE_CODE');

    arp_trx_complete_chk.do_completion_checking(p_customer_trx_id   => p_customer_trx_id, 
                                                p_so_source_code    => l_so_source_code, 
                                                p_so_installed_flag => arp_global.sysparam.ta_installed_flag, 
                                                p_error_count       => l_error_count);

    IF (l_error_count = 0) THEN
      l_msg_data := 'Y';
    ELSE
      l_msg_data := 'N';
    END IF;

    ROLLBACK;

    RETURN l_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      g_message := SQLERRM;
      RETURN 'N';
  END is_completion_enabled;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_customer_trx_id
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           get customer_trx_id of specific doc_instance_id
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_customer_trx_id(p_doc_instance_id NUMBER) RETURN NUMBER IS
    l_customer_trx_id NUMBER;
  BEGIN
    SELECT xwdi.n_attribute1
    INTO   l_customer_trx_id
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  xwdi.doc_instance_id = p_doc_instance_id;

    RETURN l_customer_trx_id;

  END get_customer_trx_id;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               do_completion
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           1. Set CM approval DFF value to APPROVED
  --                      2. Complete the transaction

  --       *******  NOT FOR USE - THIS IS NOT A PUBLIC CODE OF ORACLE !!! ******
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE do_completion(p_doc_instance_id IN NUMBER,
                          x_err_code        OUT NUMBER,
                          x_err_msg         OUT VARCHAR2) IS
                          
    l_customer_trx_id NUMBER;
    ra_cust_trx_rec ra_customer_trx_partial_v%ROWTYPE;
    l_prog_name VARCHAR2(30) := 'do_completion';
    
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';

    call_apps_initialize(p_doc_instance_id);
    mo_global.init('AR');
    l_customer_trx_id := get_customer_trx_id(p_doc_instance_id);
    set_cm_approval_status(l_customer_trx_id, 'APPROVED');

    SELECT *
    INTO   ra_cust_trx_rec
    FROM   ra_customer_trx_partial_v rct
    WHERE  rct.customer_trx_id = l_customer_trx_id;

    --       *******  NOT FOR USE - THIS IS NOT A PUBLIC CODE OF ORACLE !!! ******

    /*update ra_customer_trx_all rct
    set    old_trx_number = trx_number,
           trx_number = rct.doc_sequence_value
    where  rct.customer_trx_id = l_customer_trx_id;

    xx_AR_TRANSACTION_GRP.COMPLETE_TRANSACTION(p_api_version     => 1.0,
                                               p_init_msg_list   => FND_API.G_TRUE,
                                               p_commit          => FND_API.G_FALSE,
                                               p_customer_trx_id => l_customer_trx_id,
                                               x_return_status   => x_return_status,
                                               x_msg_count       => x_msg_count,
                                               x_msg_data        => x_msg_data);


     IF x_return_status = FND_API.G_RET_STS_SUCCESS THEN
       commit;
     ELSE
       rollback;
       x_err_code := '1';
       x_err_msg  := 'API Failed to complete transaction: ';
       IF x_msg_count > 0 THEN
         x_err_msg := 'Error in Complete Transaction API:';
         FOR i IN 1 .. x_msg_count LOOP
           fnd_msg_pub.get(i, 'F', l_err_msg, l_tmp);
           x_err_msg := x_err_msg || ' ' || l_err_msg;
         END LOOP;
       ELSE
         x_err_msg := 'Undocumented error from Complete Transaction API is: ' ||
                      x_return_status || ' ,msg count: ' || x_msg_count ||
                      ' ,message: ' || x_msg_data;
       END IF;
     END IF;
     dbms_output.put_line(x_err_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := SQLERRM; --'Failed to complete transaction: ' || sqlerrm;
      dbms_output.put_line(x_err_msg);
      fnd_log.string(log_level => fnd_log.level_event, module => c_debug_module ||
                                l_prog_name, message => x_err_msg);
  END do_completion;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               generate_need_approval_msg_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Build message body for "Need Aproval" notification
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE generate_need_approval_msg_wf(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB,
                                          document_type IN OUT NOCOPY VARCHAR2) IS
    l_history_clob CLOB;
    l_link_to_form VARCHAR2(1500);

    l_requestor      VARCHAR2(150);
    l_account_number hz_cust_accounts.account_number%TYPE;
    l_account_name   hz_cust_accounts.account_name%TYPE;
    l_field_code     xxobjt_wf_docs.doc_code%TYPE;
    l_field_name     xxobjt_wf_docs.doc_name%TYPE;

    l_cm_number       ra_customer_trx.doc_sequence_value%TYPE;
    l_cm_date         VARCHAR2(15);
    l_prev_trx_number ra_customer_trx.trx_number%TYPE;
    l_tax             NUMBER;
    l_total_amount    NUMBER;
    l_org_name        hr_operating_units.name%TYPE;
    l_itemkey         VARCHAR2(25);
    --l_country         fnd_territories_vl.territory_short_name%TYPE;
    l_wf_error        VARCHAR2(2500);
    l_customer_trx_id NUMBER;
    l_currency        VARCHAR2(15);

    CURSOR c_lines(p_customer_trx_id NUMBER) IS
      SELECT rctl.line_number,
             msib.segment1 item_number,
             rctl.description,
             nvl(rctl.extended_amount, rctl.quantity_credited *
                  rctl.unit_selling_price) amount
      FROM   ra_customer_trx_lines_all rctl,
             mtl_system_items_b        msib
      WHERE  rctl.customer_trx_id = p_customer_trx_id
      AND    rctl.line_type = 'LINE'
      AND    msib.inventory_item_id(+) = rctl.inventory_item_id
      AND    msib.organization_id(+) = 91
      ORDER  BY rctl.line_number;

  BEGIN
    document_type := 'text/html';

    SELECT hr_general.decode_person_name(xwdi.requestor_person_id) requestor,
           hca.account_number,
           hca.account_name,
           rct.doc_sequence_value cm_number,
           to_char(rct.trx_date, 'DD-MON-YYYY') cm_date,
           rct_prev.trx_number prev_trx_number,
           (SELECT SUM(rctl.extended_amount)
            FROM   ra_customer_trx_lines_all rctl
            WHERE  rctl.customer_trx_id = rct.customer_trx_id
            AND    rctl.line_type = 'TAX') tax,
           (SELECT SUM(rctl.extended_amount)
            FROM   ra_customer_trx_lines_all rctl
            WHERE  rctl.customer_trx_id = rct.customer_trx_id
            AND    rctl.line_type = 'LINE') total_amount,
           xwd.doc_code,
           xwd.doc_name field_name,
           xwdi.wf_item_key,
           hou.name org,
           rct.customer_trx_id,
           rct.invoice_currency_code
    INTO   l_requestor,
           l_account_number,
           l_account_name,
           l_cm_number,
           l_cm_date,
           l_prev_trx_number,
           l_tax,
           l_total_amount,
           l_field_code,
           l_field_name,
           l_itemkey,
           l_org_name,
           l_customer_trx_id,
           l_currency
    FROM   xxobjt_wf_doc_instance xwdi,
           xxobjt_wf_docs         xwd,
           ra_customer_trx_all    rct,
           ra_customer_trx_all    rct_prev,
           hz_cust_accounts       hca,
           hr_operating_units     hou
    WHERE  1 = 1
    AND    xwdi.doc_instance_id = document_id
    AND    xwd.doc_id = xwdi.doc_id
    AND    rct.customer_trx_id = xwdi.n_attribute1
    AND    hca.cust_account_id = rct.bill_to_customer_id
    AND    rct_prev.customer_trx_id(+) = rct.previous_customer_trx_id
    AND    hou.organization_id = rct.org_id;

    document := ' ';
    dbms_lob.append(document, '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Change Request Details</strong> </font> </p>');

    ------- Body
    l_wf_error := wf_engine.getitemattrtext(itemtype => 'XXWFDOC', itemkey => l_itemkey, aname => 'ERR_MESSAGE');
    IF l_wf_error IS NOT NULL THEN
      dbms_lob.append(document, '<b><font style="color:red" size="2">' ||
                       l_wf_error || '</font></b><br><br>');
    END IF;

    dbms_lob.append(document, l_requestor ||
                     ' asked to complete credit memo number <b>' ||
                     l_cm_number || ' </b>: <br><br>');

    dbms_lob.append(document, 'Organization:     ' || l_org_name || '<br>');
    dbms_lob.append(document, 'Customer Name:    ' || l_account_name ||
                     '<br>');
    dbms_lob.append(document, 'Customer Number:  ' || l_account_number ||
                     '<br>');
    dbms_lob.append(document, 'Credit Memo Document Number:  ' ||
                     l_cm_number || '<br>');
    dbms_lob.append(document, 'Credit Memo Date:             ' || l_cm_date ||
                     '<br>');
    dbms_lob.append(document, 'Original Invoice: ' || l_prev_trx_number ||
                     '<br>');
    dbms_lob.append(document, 'Currency:         ' || l_currency || '<br>');
    dbms_lob.append(document, 'Amount:           ' || l_total_amount ||
                     '<br>');
    dbms_lob.append(document, 'TAX:              ' || l_tax || '<br><br>');

    dbms_lob.append(document, '<B> Credit Memo lines </B><BR>' ||
                     '<div align="left"><TABLE BORDER=1 cellPadding=2>' ||
                     '<tr> <th><B>  Line </B></th>' ||
                     ' <th><B>  Item  </B></th>' ||
                     ' <th><B>  Description  </B></th>' ||
                     ' <th><B>  Amount       </B></th> </tr>');

    FOR r_line IN c_lines(l_customer_trx_id) LOOP
      dbms_lob.append(document, '<tr>  <td> ' || r_line.line_number ||
                       ' </td>' || ' <td> ' ||
                       nvl(r_line.item_number, chr(38) || 'nbsp') ||
                       ' </td>' || ' <td> ' || r_line.description ||
                       ' </td>' || ' <td align="right"> ' ||
                       r_line.amount || ' </td> </tr>');
    END LOOP;
    dbms_lob.append(document, '</TABLE>');

    dbms_lob.append(document, '<BR><BR>Document Instance Id: ' ||
                     document_id);

    xxar_credit_memo_apr_util_pkg.get_trx_form_link(document_id => document_id, display_type => display_type, document => l_link_to_form, document_type => document_type);

    dbms_lob.append(document, '<BR><BR>' || l_link_to_form);

    ------- History
    l_history_clob := NULL;
    dbms_lob.append(document, '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id => document_id, display_type => '', document => l_history_clob, document_type => document_type);

    dbms_lob.append(document, l_history_clob);

  END generate_need_approval_msg_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               submit_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Submit WF XXWFDOC for credit memo approval
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE submit_wf(p_customer_trx_id IN NUMBER,
                      p_attribute1      IN VARCHAR2 DEFAULT NULL,
                      p_attribute2      IN VARCHAR2 DEFAULT NULL,
                      p_attribute3      IN VARCHAR2 DEFAULT NULL,
                      x_err_code        OUT NUMBER,
                      x_err_msg         OUT VARCHAR2,
                      x_itemkey         OUT VARCHAR2) IS
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(1000);
    l_doc_instance_header xxobjt_wf_doc_instance%ROWTYPE;
    l_person_id           NUMBER := fnd_global.employee_id;
    l_prog_name           VARCHAR2(30) := 'submit_wf';
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
    x_itemkey  := '';

    --- debug
    fnd_log.string(log_level => fnd_log.level_event, module => c_debug_module ||
                              l_prog_name, message => 'p_customer_trx_id = ' ||
                               p_customer_trx_id);

    l_doc_instance_header.user_id             := fnd_global.user_id;
    l_doc_instance_header.resp_id             := fnd_global.resp_id;
    l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
    l_doc_instance_header.requestor_person_id := l_person_id;
    l_doc_instance_header.creator_person_id   := l_person_id;

    l_doc_instance_header.n_attribute1 := p_customer_trx_id;
    l_doc_instance_header.attribute1   := p_attribute1;
    l_doc_instance_header.attribute2   := p_attribute2;
    l_doc_instance_header.attribute3   := p_attribute3;

    BEGIN
      SELECT org_id
      INTO   l_doc_instance_header.attribute6
      FROM   ra_customer_trx_all rctl
      WHERE  rctl.customer_trx_id = p_customer_trx_id;
    EXCEPTION
      WHEN no_data_found THEN
        x_err_code := 1;
        x_err_msg  := 'Transaction must be saved before sending it to approval.';
        g_message  := x_err_msg;
        fnd_log.string(log_level => fnd_log.level_unexpected, module => c_debug_module ||
                                  l_prog_name, message => x_err_msg);

        RETURN;
    END;

    xxobjt_wf_doc_util.create_instance(p_err_code => l_err_code, p_err_msg => l_err_msg, p_doc_instance_header => l_doc_instance_header, p_doc_code => 'AR_CM_TRX');

    IF l_err_code = 1 THEN
      x_err_code := 1;
      x_err_msg  := ('Error in create_instance: ' || l_err_msg);
    ELSE
      xxobjt_wf_doc_util.initiate_approval_process(p_err_code => l_err_code, p_err_msg => l_err_msg, p_doc_instance_id => l_doc_instance_header.doc_instance_id, p_wf_item_key => x_itemkey);

      IF l_err_code = 1 THEN
        x_err_code := 1;
        x_err_msg  := ('Error in initiate_approval_process: ' || l_err_msg);
      ELSE
        set_cm_approval_status(p_customer_trx_id, 'SUBMITTED');
        x_err_msg := 'Approval was successfully submited for ' ||
                     xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id) ||
                     '. doc_instance_id=' ||
                     l_doc_instance_header.doc_instance_id;
      END IF;
    END IF;

    fnd_log.string(log_level => fnd_log.level_unexpected, module => c_debug_module ||
                              l_prog_name, message => x_err_msg);

    g_message := x_err_msg;

  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := ('XXAR_CREDIT_MEMO_APR_UTIL_PKG.submit_wf: Unexpected error: ' ||
                    SQLERRM);
      g_message  := x_err_msg;
      fnd_log.string(log_level => fnd_log.level_unexpected, module => c_debug_module ||
                                l_prog_name, message => x_err_msg);

  END submit_wf;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_message
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Get value of G_MESSAGE. Called by Form personalization.
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_message RETURN VARCHAR2 IS
  BEGIN
    RETURN g_message;
  END get_message;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_approver
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      27/08/2014
  --  Purpose :           get approver name

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/08/2014    Michal Tzvik    initial build
  --  1.1   10/03/2015    Dalit A. Raviv  CHG0034685 - Add LATAM Approver 
  -----------------------------------------------------------------------
  PROCEDURE get_approver(p_doc_instance_id IN NUMBER,
                         x_approver        OUT VARCHAR2,
                         x_err_code        OUT NUMBER,
                         x_err_msg         OUT VARCHAR2) IS
    l_prog_name   varchar2(30) := 'get_approver';
    l_customer_id number;
    l_is_latam    varchar2(10) := 'N';
    l_site_use_id number;
  begin
    x_err_code := '0';
    x_err_msg  := '';
    --  1.1   10/03/2015    Dalit A. Raviv  CHG0034685 - Add LATAM Approver 
    begin
      -- get customer 
      select rcta.bill_to_customer_id, rcta.bill_to_site_use_id
      into   l_customer_id, l_site_use_id
      from   xxobjt_wf_doc_instance xwdi,
             ra_customer_trx_all    rcta
      where  xwdi.n_attribute1      = rcta.customer_trx_id
      and    xwdi.doc_instance_id   = p_doc_instance_id;
      
      -- check if LATAM customer  
      l_is_latam := xxhz_util.is_LATAM_customer (p_site_use_id => l_site_use_id,p_site_id => null,p_customer_id => l_customer_id );
    exception
      when others then
        l_is_latam := 'N';
    end;
    -- If LATAM customer get the approver from setup
    -- else old logic.
    if l_is_latam = 'Y' then
      --get approver name
      begin
        select fu.user_name
        into   x_approver
        from   fnd_lookup_values v,
               fnd_user          fu
        where  v.lookup_type     = 'XXAR_CREDIT_MEMO_APPR_HIR'
        and    v.language        = 'US'
        and    v.enabled_flag    = 'Y'
        and    trunc(sysdate)    between nvl(v.start_date_active,sysdate -1) and nvl(v.end_date_active, sysdate +1)
        and    fu.employee_id (+) = v.attribute1
        and    v.meaning         = 'LATAM';
      exception
        when others then
          l_is_latam := 'N'; 
      end; 
    end if;         
    -- use old logic if did not find LATAM approver 
    -- or this is not a LATAM customer
    if l_is_latam = 'N' then
      select fu_aprv.user_name
      into   x_approver
      from   xxobjt_wf_doc_instance  xwdi,
             per_all_people_f        pap,
             per_all_assignments_f   paa,
             gl_code_combinations    gcc,
             fnd_lookup_values       flv,
             fnd_lookup_values_dfv   flv_dfv,
             fnd_user                fu_aprv
      where  xwdi.doc_instance_id    = p_doc_instance_id
      and    pap.person_id           = xwdi.requestor_person_id
      and    paa.person_id           = pap.person_id
      and    sysdate                 between paa.effective_start_date and paa.effective_end_date
      and    sysdate                 BETWEEN pap.effective_start_date AND pap.effective_end_date
      and    gcc.code_combination_id = paa.default_code_comb_id
      and    flv.lookup_type         = 'XXAR_CREDIT_MEMO_APPR_HIR'
      and    flv.language            = 'US'
      and    flv.lookup_code         = gcc.segment1
      and    flv_dfv.row_id          = flv.rowid
      and    fu_aprv.employee_id     = flv_dfv.approver_name
      and    sysdate                 between nvl(flv.start_date_active, sysdate - 1) and nvl(flv.end_date_active, sysdate + 1)
      and    flv.enabled_flag        = 'Y';
    end if;
  exception
    when others then
      x_err_code := '1';
      x_err_msg  := 'Failed to get approver name: ' || SQLERRM;
      fnd_log.string(log_level => fnd_log.level_event, 
                     module    => c_debug_module ||l_prog_name, 
                     message   => x_err_msg);
  end get_approver;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_trx_form_link
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      27/08/2014
  --  Purpose :           get link to Transaction form, to be used in notification body

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_trx_form_link(document_id   IN VARCHAR2,
                              display_type  IN VARCHAR2,
                              document      IN OUT VARCHAR2,
                              document_type IN OUT VARCHAR2) IS
    l_document VARCHAR2(3200) := '';
    l_htmlref  VARCHAR2(4000);

    l_customer_trx_id NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_approval_status VARCHAR2(15);
    l_link_str        VARCHAR2(150);
  BEGIN

    SELECT xwdi.n_attribute1,
           xwdi.resp_id,
           xwdi.resp_appl_id,
           xwdi.doc_status
    INTO   l_customer_trx_id,
           l_resp_id,
           l_resp_appl_id,
           l_approval_status
    FROM   xxobjt_wf_doc_instance xwdi
    WHERE  1 = 1
    AND    xwdi.doc_instance_id = document_id;

    IF l_approval_status = 'APPROVED' THEN
      l_link_str := 'Please press in order to complete Credit Memo';
    ELSE
      l_link_str := 'Open Transaction Form';
    END IF;

    l_htmlref := '<B><A HREF="' ||
                 fnd_run_function.get_run_function_url(p_function_id => 1691 -- AR_ARXTWMAI_HEADER
                                                      , p_resp_appl_id => l_resp_appl_id, p_resp_id => l_resp_id, p_security_group_id => NULL, p_parameters => 'FP_CUSTOMER_TRX_ID=' ||
                                                                        to_char(l_customer_trx_id)) ||
                 '"> ' || l_link_str || ' </A></B>';

    l_document := l_document || '<BR> ' || l_htmlref;
    document   := l_document;
  END get_trx_form_link;

BEGIN
  g_enable_cm_approval_wf := fnd_profile.value('XXAR_ENABLE_CM_APPROVAL_WF');
END xxar_credit_memo_apr_util_pkg;
/
