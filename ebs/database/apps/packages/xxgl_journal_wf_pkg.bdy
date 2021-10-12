CREATE OR REPLACE PACKAGE BODY xxgl_journal_wf_pkg IS

  --------------------------------------------------------------------
  --  name:            xxgl_journal_wf_pkg
  --  create by:       Yuval tal
  --  Revision:        1.1 
  --  creation date:   22.8.13
  --------------------------------------------------------------------
  --  purpose :        CUST420 : CR 985 - support changes in Journal wf approval
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --  1.1  03/05/2015  Dalit A. RAviv    CHG0035261 - approval_message_cc_mgr_body
  --                                     an error is always shown when 
  --                                     journal approval sent to higher approver.  
  --------------------------------------------------------------------

  -- Private constant declarations
  g_pkg_name VARCHAR2(50) := 'XXGL_JOURNAL_WF_PKG';

  --------------------------------------------------------------------
  --  name:            approve_message_body
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   22.8.13
  --------------------------------------------------------------------
  --  purpose :        CR 985 - support changes in Journal wf approval
  --                   display cc manager body message
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22.8.13     Yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE approval_message_body(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT NOCOPY CLOB,
                                  document_type IN OUT NOCOPY VARCHAR2) IS
  
    l_batch_id                 NUMBER;
    l_nid                      NUMBER;
    l_batch_name               VARCHAR2(500);
    l_preparer_display_name    VARCHAR2(500);
    l_comment_from             VARCHAR2(2000);
    l_forward_approver_comment VARCHAR2(2000);
    
    CURSOR c IS
      SELECT h.currency_code,
             h.period_name,
             gl.name ledger_name,
             to_char(SUM(nvl(l.accounted_dr, 0)), '999,999,999,990.00') debit_amount,
             to_char(SUM(nvl(l.accounted_cr, 0)), '999,999,999,990.00') credit_amount,
             gcc.concatenated_segments account_combination,
             xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) dept_desc,
             xxgl_utils_pkg.get_dff_value_description(1013887, gcc.segment3) account_desc
        FROM gl_je_headers            h,
             gl_je_lines              l,
             gl_code_combinations_kfv gcc,
             gl_ledgers               gl
       WHERE h.je_batch_id = l_batch_id --(batch id for example 7030386)
         AND l.je_header_id = h.je_header_id
         AND gcc.code_combination_id = l.code_combination_id
         AND gl.ledger_id = h.ledger_id
       GROUP BY h.currency_code,
                h.period_name,
                gl.name,
                gcc.concatenated_segments,
                gcc.segment2,
                gcc.segment3;

  BEGIN
    -- Currency, Quarter, ledger name, department description, account description, account combination, debit, credit
    l_batch_id := substr(document_id, 1, instr(document_id, ':') - 1);
    l_nid      := substr(document_id, instr(document_id, ':') + 1);
  
    l_batch_name            := wf_notification.getattrtext(l_nid,'BATCH_NAME');
    l_preparer_display_name := wf_notification.getattrtext(l_nid,'PREPARER_DISPLAY_NAME');
  
    l_comment_from             := wf_notification.getattrtext(l_nid,'COMMENT_FROM');
    l_forward_approver_comment := wf_notification.getattrtext(l_nid,'FORWARD_APPROVER_COMMENT');
  
    document := '<BR>Journal batch ' || l_batch_name || ' submitted by ' ||
                l_preparer_display_name || ' requires your approval.<br><br>
<br>
 <TABLE border=1 cellPadding=3>
   <TR>
    <TH>Currency</TH>
    <TH>Period</TH>    
    <TH>Ledger Name</TH>
    <th>Department Description</th>
    <th>Account Description</th>
    <TH>Account Combination</TH>    
    <TH>Debit Amount</TH>
    <TH>Credit Amount</TH>
    </TR>';
  
    FOR i IN c LOOP
    
      dbms_lob.append(document,
                      '<TR>' || '<TD>' || i.currency_code || '</TD> <TD>' ||
                      i.period_name || '</TD><TD>' || i.ledger_name ||
                      '</TD><TD>' || i.dept_desc || '</TD><TD>' ||
                      i.account_desc || '</TD><TD>' ||
                      i.account_combination || '</TD><TD align="right">' ||
                      i.debit_amount || '</TD><TD align="right">' ||
                      i.credit_amount || '</TD></TR>');
    END LOOP;
    dbms_lob.append(document,
                    '</TABLE><BR><BR>' || l_comment_from || '<BR>' ||
                    l_forward_approver_comment);
  
  EXCEPTION
    WHEN OTHERS THEN  
      wf_core.context(g_pkg_name,
                      'approve_message_body',
                      document_id,
                      display_type);
      RAISE;
  END approval_message_body;

  --------------------------------------------------------------------
  --  name:            approval_message_cc_mgr_body
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   22.8.13
  --------------------------------------------------------------------
  --  purpose :        CR 985 - support changes in Journal wf approval
  --                   display cc manager body message 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22.8.13     Yuval tal         initial build
  --  1.1  03/05/2015  Dalit A. RAviv    CHG0035261 - an error is always shown when 
  --                                     journal approval sent to higher approver.
  --------------------------------------------------------------------
  PROCEDURE approval_message_cc_mgr_body(document_id   IN VARCHAR2,
                                         display_type  IN VARCHAR2,
                                         document      IN OUT NOCOPY CLOB,
                                         document_type IN OUT NOCOPY VARCHAR2) IS
  
    l_batch_id                 NUMBER;
    l_nid                      NUMBER;
    l_batch_name               VARCHAR2(500);
    l_preparer_display_name    VARCHAR2(500);
    -- l_comment_from             VARCHAR2(2000);
    -- l_forward_approver_comment VARCHAR2(2000);
    l_approver_display_name    VARCHAR2(500);
    
    CURSOR c IS
      SELECT h.currency_code,
             h.period_name,
             gl.name ledger_name,
             to_char(SUM(nvl(l.accounted_dr, 0)), '999,999,999,990.00') debit_amount,
             to_char(SUM(nvl(l.accounted_cr, 0)), '999,999,999,990.00') credit_amount,
             gcc.concatenated_segments account_combination,
             xxgl_utils_pkg.get_dff_value_description(1013889, gcc.segment2) dept_desc,
             xxgl_utils_pkg.get_dff_value_description(1013887, gcc.segment3) account_desc
        FROM gl_je_headers            h,
             gl_je_lines              l,
             gl_code_combinations_kfv gcc,
             gl_ledgers               gl
       WHERE h.je_batch_id = l_batch_id --(batch id for example 7030386)
         AND l.je_header_id = h.je_header_id
         AND gcc.code_combination_id = l.code_combination_id
         AND gl.ledger_id = h.ledger_id
       GROUP BY h.currency_code,
                h.period_name,
                gl.name,
                gcc.concatenated_segments,
                gcc.segment2,
                gcc.segment3;
        
  BEGIN
  
    l_batch_id := substr(document_id, 1, instr(document_id, ':') - 1);
    l_nid      := substr(document_id, instr(document_id, ':') + 1);
    l_batch_name            := wf_notification.getattrtext(l_nid,'BATCH_NAME');
    l_preparer_display_name := wf_notification.getattrtext(l_nid,'PREPARER_DISPLAY_NAME');
    -- CHG0035261 the WF message do not have theses attributes , 
    -- attribute APPROVER_DISPLAY_NAME need to refer to l_approver_display_name instead of l_forward_approver_comment
    /*l_comment_from             := wf_notification.getattrtext(l_nid,
                                                              'COMMENT_FROM');
    l_forward_approver_comment := wf_notification.getattrtext(l_nid,
                                                              'FORWARD_APPROVER_COMMENT');*/
    /*l_forward_approver_comment*/
    l_approver_display_name := wf_notification.getattrtext(l_nid,'APPROVER_DISPLAY_NAME');
    -- end CHG0035261
    document := '<BR>Journal batch ' || l_batch_name || ' submitted by ' ||
                l_preparer_display_name || ' was sent to ' ||
                l_approver_display_name || ' for approval.<br><br>
<br>
 <TABLE border=1 cellPadding=3>
   <TR>
    <TH>Currency</TH>
    <TH>Period</TH>    
    <TH>Ledger Name</TH>
    <th>Department Description</th>
    <th>Account Description</th>
    <TH>Account Combination</TH>    
    <TH>Debit Amount</TH>
    <TH>Credit Amount</TH>
    </TR>';
  
    FOR i IN c LOOP
    
      dbms_lob.append(document,
                      '<TR>' || '<TD>' || i.currency_code || '</TD> <TD>' ||
                      i.period_name || '</TD><TD>' || i.ledger_name ||
                      '</TD><TD>' || i.dept_desc || '</TD><TD>' ||
                      i.account_desc || '</TD><TD>' ||
                      i.account_combination || '</TD><TD align="right">' ||
                      i.debit_amount || '</TD><TD align="right">' ||
                      i.credit_amount || '</TD></TR>');
    END LOOP;
    dbms_lob.append(document, '</TABLE>');
  
  EXCEPTION
    WHEN OTHERS THEN  
      wf_core.context(g_pkg_name,
                      'approve_message_body',
                      document_id,
                      display_type);
      RAISE;
  END approval_message_cc_mgr_body;

END xxgl_journal_wf_pkg;
/
