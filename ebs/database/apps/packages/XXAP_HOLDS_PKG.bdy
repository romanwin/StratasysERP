CREATE OR REPLACE PACKAGE BODY XXAP_HOLDS_PKG IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXAP_HOLDS_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         AP Invoice Holds Package
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula    Initial Version (CHG0036487)
  25-JAN-2016        1.1                  Diptasurjya      INC0056690 - Check PO matching for ITEM type lines only
  26-JAN-2016        1.2                  Diptasurjya      INC0056915 - Truncate PO creation date before matching for
                                                           PO and Invoice date so that PO and Invoice created on same
                                                           date at different time are not put on hold. Function get_hold_action changed
  27-JAN-2016        1.3                  Diptasurjya      INC0056916 - Check if XX_PO_DATE_HOLD hold has already been
                                                           released, if yes do not put hold again. Procedure validate_invoice is changed
  6-APR-2016         1.4                  Lingaraj         CHG0037986 -Change PO Date hold process to ignore prepayments and adj lines
                                                           Invoice Source and Invoice Type controlled from Lookup for Exempt Hold                                
  ---------------------------------------------------------------------------------------------------*/
 c_debug_module CONSTANT VARCHAR2(100) := 'XXAP.XXAP_HOLDS_PKG.';

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:  invoke_hold_res_workflow
  Author's Name:   Diptasurjya Chatterjee
  Date Written:    01-DEC-2015
  Purpose:         This Procedure invokes the AP Hold resolution workflow
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version             Name                       Remarks
  -----------    ----------------    -------------              ------------------
  13-OCT-2015        1.0             Diptasurjya Chatterjee     Initial Version -- CHG0036487
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE invoke_hold_res_workflow(p_hold_id IN number) IS
  BEGIN
    AP_WORKFLOW_PKG.create_hold_wf_process(p_hold_id);
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'invoke_hold_res_workflow',
                   message   => 'API ERROR while invoking Hold resolution workflow for Hold ID: '||p_hold_id);
    ROLLBACK;
    RAISE;
  END invoke_hold_res_workflow;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:  abort_hold_res_workflow
  Author's Name:   Diptasurjya Chatterjee
  Date Written:    01-DEC-2015
  Purpose:         This Procedure aborts the AP Hold resolution workflow
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version             Name                       Remarks
  -----------    ----------------    -------------              ------------------
  13-OCT-2015        1.0             Diptasurjya Chatterjee     Initial Version -- CHG0036487
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE abort_hold_res_workflow(p_hold_id IN number) IS
  BEGIN
    AP_WORKFLOW_PKG.abort_holds_workflow(p_hold_id);
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'invoke_hold_res_workflow',
                   message   => 'API ERROR while aborting Hold resolution workflow for Hold ID: '||p_hold_id);
    ROLLBACK;
    RAISE;
  END abort_hold_res_workflow;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    create_single_hold
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         This Procedure creates a Hold on the AP Invoice
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036487
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE create_single_hold(p_invoice_id         IN number,
                             p_hold_lookup_code   IN varchar2,
                             p_hold_type IN varchar2 DEFAULT NULL,
                             p_hold_reason IN varchar2 DEFAULT NULL,
                             p_held_by IN number DEFAULT NULL,
                             p_calling_sequence IN varchar2 DEFAULT NULL)  IS

l_hold_exists_cnt NUMBER;
l_mail_list VARCHAR2(500);
--l_role_name   VARCHAR2(100) := FND_PROFILE.VALUE('XXAP_HOLD_NOTF_ROLE');
l_err_code  NUMBER;
l_err_msg   VARCHAR2(500);
l_invoice_number AP_INVOICES_ALL.invoice_num%type;
l_invoice_creator fnd_user.user_name%type;

l_hold_id   number;

BEGIN

 -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => 'Inside the Procedure create_single_hold'||
                                ' p_invoice_id:' || p_invoice_id||
                                ' p_hold_lookup_code:'||p_hold_lookup_code);

    select a.invoice_num,b.user_name
    into l_invoice_number,l_invoice_creator
    from ap_invoices_all a,
         fnd_user b
    where a.invoice_id = p_invoice_id and
          a.created_by = b.user_id;

 fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => 'l_invoice_number :'||l_invoice_number||
                                ' l_invoice_creator :'||l_invoice_creator);

-- Calling the Private Holds API to Create Hold
AP_HOLDS_PKG.INSERT_SINGLE_HOLD
            (x_invoice_id            => p_invoice_id,
             x_hold_lookup_code      => p_hold_lookup_code,
             x_hold_type             => p_hold_type,
             x_hold_reason           => p_hold_reason,
             x_held_by               => p_held_by,
             x_calling_sequence      => p_calling_sequence
            );

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => 'After the API');


   BEGIN
      SELECT count(*)
        INTO l_hold_exists_cnt
        FROM ap_holds_all
       WHERE invoice_id = p_invoice_id AND
             hold_lookup_code = p_hold_lookup_code;

      select hold_id
        into l_hold_id
        from ap_holds_all
       where invoice_id = p_invoice_id
         AND hold_lookup_code = p_hold_lookup_code
         and wf_status is null;
      --IF (l_user_releaseable_flag = 'Y' AND l_initiate_workflow_flag = 'Y') THEN
      -- Invoke AP Hold Resolution workflow
      -------------------------------------------
      fnd_log.string(log_level => fnd_log.level_event,
                     module    => c_debug_module || 'create_single_hold',
                     message   => 'Before calling Workflow for Hold ID: '||l_hold_id);

      invoke_hold_res_workflow(l_hold_id);

      --------------------------------------------

      --END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_hold_exists_cnt := 0;
   END;

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => 'l_hold_exists_cnt :'||l_hold_exists_cnt);

--IF l_hold_exists_cnt = 0 THEN
/* Sending Failure Email */
/*l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Could not Create '||p_hold_lookup_code||' Hold on Invoice ID '||p_invoice_id,
                              p_body_text   => 'Could not Create '||p_hold_lookup_code||' Hold on Invoice ID '||p_invoice_id||chr(10)||
                                               'Hold was Initiated from AP_CUSTOM_INV_VALIDATION_PKG'||chr(10)||
                                               'Please contact IT for an action plan',
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

ELSIF l_hold_exists_cnt > 0 THEN*/
/* Sending Failure Email */
/*l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Hold '||p_hold_lookup_code||' created on Invoice '||l_invoice_number,
                              p_body_text   => 'Hold '||p_hold_lookup_code||' created on Invoice ID '||p_invoice_id||chr(10)||
                                               'Please check the Hold Reason in Invoice workbench, correct the error and revalidate the Invoice'||chr(10)||
                                               'Hold was Initiated from AP_CUSTOM_INV_VALIDATION_PKG',
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

END IF; */


fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => 'END of the Procedure');

EXCEPTION
WHEN OTHERS THEN
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_invoice_creator,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Exception Occured in xxap_holds_pkg.create_single_hold for Invoice ID '||p_invoice_id,
                              p_body_text   => 'Exception Occured in xxap_holds_pkg.create_single_hold for Invoice ID '||p_invoice_id||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                               'SQL Error :'||SQLERRM,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END create_single_hold;

 --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    release_single_hold
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         This Procedure releases a Hold on the AP Invoice
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036487
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE release_single_hold(p_invoice_id         IN number,
                             p_hold_lookup_code   IN varchar2,
                             p_release_lookup_code   IN varchar2,
                             p_held_by IN number DEFAULT NULL,
                             p_calling_sequence IN varchar2 DEFAULT NULL) IS

l_release_exists_cnt NUMBER;
l_mail_list VARCHAR2(500);
l_role_name   VARCHAR2(100) := FND_PROFILE.VALUE('XXAP_HOLD_NOTF_ROLE');
l_err_code  NUMBER;
l_err_msg   VARCHAR2(500);
l_invoice_number AP_INVOICES_ALL.invoice_num%type;
l_invoice_creator fnd_user.user_name%type;

l_hold_id number;
BEGIN

 -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'Inside the Procedure release_single_hold'||
                                ' p_invoice_id:' || p_invoice_id||
                                ' p_hold_lookup_code:'||p_hold_lookup_code||
                                ' p_release_lookup_code:'||p_release_lookup_code);

    select a.invoice_num,b.user_name
    into l_invoice_number,l_invoice_creator
    from ap_invoices_all a,
         fnd_user b
    where a.invoice_id = p_invoice_id and
          a.created_by = b.user_id;

 fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'l_invoice_number :'||l_invoice_number||
                                ' l_invoice_creator :'||l_invoice_creator);


-- Calling the Private Holds API to Release Hold
AP_HOLDS_PKG.RELEASE_SINGLE_HOLD
            (x_invoice_id            => p_invoice_id,
             x_hold_lookup_code      => p_hold_lookup_code,
             x_release_lookup_code   => p_release_lookup_code,
             x_held_by               => p_held_by,
             x_calling_sequence      => p_calling_sequence
            );

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'After the API');

   /* Abort the AME hold resolution workflow */
    BEGIN
      select hold_id
        into l_hold_id
        from ap_holds_all
       where invoice_id = p_invoice_id
         AND hold_lookup_code = p_hold_lookup_code
         and wf_status = 'STARTED';

      abort_hold_res_workflow(l_hold_id);

      fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'AME workflow for hold release aborted. Hold ID: '||l_hold_id);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'Hold ID not found during aborting workflow');
    END;

   BEGIN
      SELECT count(*)
        INTO l_release_exists_cnt
        FROM ap_holds_all
       WHERE invoice_id = p_invoice_id AND
             hold_lookup_code = p_hold_lookup_code AND
             release_lookup_code IS NOT NULL;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_release_exists_cnt := 0;
   END;

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'l_hold_exists_cnt :'||l_release_exists_cnt);

/*IF l_release_exists_cnt = 0 THEN
/* Sending Failure Email */
/*l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Could not release '||p_hold_lookup_code||' Hold on Invoice ID '||p_invoice_id,
                              p_body_text   => 'Could not release '||p_hold_lookup_code||' Hold on Invoice ID '||p_invoice_id||chr(10)||
                                               'Hold was Initiated from AP_CUSTOM_INV_VALIDATION_PKG'||chr(10)||
                                               'Please contact IT for an action plan',
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

ELSIF l_release_exists_cnt > 0 THEN
/* Sending Failure Email */
/*l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Hold '||p_hold_lookup_code||' released Sucessfully on Invoice '||l_invoice_number,
                              p_body_text   => 'Hold '||p_hold_lookup_code||' released Sucessfully on Invoice ID '||p_invoice_id||chr(10)||
                                               'Invoice is Validated. Please proceed to the next step'||chr(10)||
                                               'Hold was Initiated from AP_CUSTOM_INV_VALIDATION_PKG',
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);

END IF;     */


fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'release_single_hold',
                   message   => 'END of the Procedure');

EXCEPTION
WHEN OTHERS THEN
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_invoice_creator,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Exception Occured in xxap_holds_pkg.release_single_hold for Invoice ID '||p_invoice_id,
                              p_body_text   => 'Exception Occured in xxap_holds_pkg.release_single_hold for Invoice ID '||p_invoice_id||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                               'SQL Error :'||SQLERRM,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END release_single_hold;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_hold_action
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         This Functions Validate the Invoice and determines if a Hold can be applied on the Invoice
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036487
  25-JAN-2016        1.1                  Diptasurjya       INC0056690 - Check PO matching for ITEM type lines only
  26-JAN-2016        1.2                  Diptasurjya       INC0056915 - Truncate PO creation date before matching for
                                                            PO and Invoice date so that PO and Invoice created on same
                                                            date at different time are not put on hold
  6-APR-2016         1.3                  Lingaraj         CHG0037986 -Change PO Date hold process to ignore prepayments and adj lines
                                                           Invoice Source and Invoice Type controlled from Lookup for Exempt Hold                                                                                            
  ---------------------------------------------------------------------------------------------------*/
FUNCTION get_hold_action(p_invoice_id IN NUMBER)
RETURN VARCHAR2 IS

--l_po_number po_headers_all.segment1%type;
--l_po_date DATE;
--l_invoice_Date DATE;
--l_hold_action VARCHAR2(1000);
l_po_count NUMBER;

l_ap_dist_count NUMBER;
l_unmatched_inv_amount NUMBER;--Added for CHG0037986
BEGIN

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'get_hold_action',
                   message   => 'Inside Procedure get_hold_action'||
                                ' p_invoice_id :'||p_invoice_id);

SELECT COUNT(*)
into l_po_count
from ap_invoices_all ai,
     ap_invoice_distributions_all aid,
     po_distributions_all pd,
     po_headers_all ph
where ai.invoice_id = aid.invoice_id and
      aid.po_distribution_id = pd.po_distribution_id and
      pd.po_header_id = ph.po_header_id and
      ai.invoice_id = p_invoice_id and
      NVL(aid.reversal_flag,'N') <> 'Y' and
      aid.line_type_lookup_code = 'ITEM';--NOT IN ('FREIGHT','MISCELLANEOUS','TAX','NONREC_TAX','REC_TAX','TERV','TIPV','TRV');  INC0056690 -- Dipta

/* Start - Added by Dipta to handle multiple PO matched to single Invoice */
SELECT COUNT(*)
into   l_ap_dist_count
from   ap_invoice_distributions_all aid
where  aid.invoice_id = p_invoice_id and
       NVL(aid.reversal_flag,'N') <> 'Y' and
       aid.line_type_lookup_code = 'ITEM';--NOT IN ('FREIGHT','MISCELLANEOUS','TAX','NONREC_TAX','REC_TAX','TERV','TIPV','TRV');  INC0056690 -- Dipta
/* End - Added by Dipta to handle multiple PO matched to single Invoice */

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'get_hold_action',
                   message   => 'l_po_count :'||l_po_count||' l_ap_dist_count: '||l_ap_dist_count);

-- Commented by Dipta to handle multiple PO matched to single Invoice
/*IF l_po_count = 0 then
 RETURN('CREATE_HOLD_PO_NOT_EXISTS');
ELSE*/

/*Start - CHG0037986 - If All the Manually added Invoice lines total to Zero, 
                       and Total no of PO lines and invoice Lines not matched
                       then hold will not be applyed in the invoice But other conditions
                       will be checked where invoice hold can be applied    */
  l_unmatched_inv_amount := 0;
  SELECT SUM(amount)
    into l_unmatched_inv_amount
    FROM ap_invoice_distributions_all aid
   WHERE aid.invoice_id = p_invoice_id
     AND NVL(aid.reversal_flag, 'N') <> 'Y'
     AND aid.line_type_lookup_code = 'ITEM'
     AND dist_match_type = 'NOT_MATCHED'
     AND po_distribution_id IS NULL;
/* End - CHG0037986 */

IF l_po_count <> l_ap_dist_count AND l_unmatched_inv_amount <> 0 THEN
 RETURN('CREATE_HOLD_PO_NOT_EXISTS');
ELSE

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'get_hold_action',
                   message   => 'Inside ELSE');

--l_po_number := '';
--l_po_date := '';
--l_invoice_date := '';
--l_hold_action := '';
begin

/*select ph.segment1,ph.creation_date,ai.invoice_date,
(CASE WHEN ph.creation_date > ai.invoice_date THEN 'CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE'
      ELSE 'DONT_CREATE_HOLD' END)
into l_po_number,l_po_date,l_invoice_date,l_hold_action
from ap_invoices_all ai,
     ap_invoice_distributions_all aid,
     po_distributions_all pd,
     po_headers_all ph
where ai.invoice_id = aid.invoice_id and
      aid.po_distribution_id = pd.po_distribution_id and
      pd.po_header_id = ph.po_header_id and
      ai.invoice_id = p_invoice_id and
      NVL(aid.reversal_flag,'N') <> 'Y' and
      aid.line_type_lookup_code NOT IN ('FREIGHT','MISCELLANEOUS')
group by ph.segment1,ph.creation_date,ai.invoice_date;*/

for act_rec in (select ph.segment1,ph.creation_date,ai.invoice_date,
                  (CASE WHEN trunc(ph.creation_date) > ai.invoice_date THEN 'CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE'
                      ELSE 'DONT_CREATE_HOLD' END) hold_action
              --into l_po_number,l_po_date,l_invoice_date,l_hold_action
              from ap_invoices_all ai,
                   ap_invoice_distributions_all aid,
                   po_distributions_all pd,
                   po_headers_all ph
             where ai.invoice_id = aid.invoice_id and
                   aid.po_distribution_id = pd.po_distribution_id and
                   pd.po_header_id = ph.po_header_id and
                   ai.invoice_id = p_invoice_id and
                   NVL(aid.reversal_flag,'N') <> 'Y' and
                   aid.line_type_lookup_code NOT IN ('FREIGHT','MISCELLANEOUS')
          group by ph.segment1,ph.creation_date,ai.invoice_date)
loop
  if act_rec.hold_action = 'CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE' then
    RETURN(act_rec.hold_action);
  end if;

  fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'l_po_number :'||act_rec.segment1||
                                ' l_po_date:' || act_rec.creation_date||
                                ' l_invoice_date:'||act_rec.invoice_date||
                                ' l_hold_action:'||act_rec.hold_action);
end loop;

exception
when others then
--l_po_number := NULL;
--l_po_date := null;
--l_invoice_date := null;
--l_hold_action := NULL;
NULL;
end;

RETURN('DONT_CREATE_HOLD');

END IF;

EXCEPTION
WHEN OTHERS THEN
RETURN('SQL ERROR:'||SQLERRM);
END get_hold_action;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    HOLD_ELIGIBLE
  Author's Name:   Sandeep Akula
  Date Written:    18-NOV-2015
  Purpose:         This Function determines if the Invoice is eligible for applying a Hold
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-NOV-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036487
  4-JAN-2016         1.1                  Diptasurjya       Conversion rate applied for checking invoice amount criteria
                                                            Supplier exempt types handled based on new lookup XXAP_HOLD_EXEMPT_VENDOR_TYPES
  6-APR-2016         1.2                  Lingaraj          CHG0037986 -Change PO Date hold process to ignore prepayments and adj lines                                                                                                            
  ---------------------------------------------------------------------------------------------------*/
FUNCTION HOLD_ELIGIBLE(p_invoice_id IN number)
RETURN VARCHAR2 IS

l_amt NUMBER;
l_inv_source ap_invoices_all.source%type;
l_inv_type ap_invoices_all.invoice_type_lookup_code%type;
l_conversion_rate number;
l_invoice_currency varchar2(20);
l_invoice_gl_date date;

l_supplier_type_exempt  varchar2(1);--Added for CHG0037986
l_inv_src_type_exempt   varchar2(1);--Added for CHG0037986
l_inv_type_exempt varchar2(1);
e_no_conversion_rate exception;
PRAGMA EXCEPTION_INIT( e_no_conversion_rate, -20799 );
BEGIN

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'HOLD_ELIGIBLE',
                   message   => 'Inside Function HOLD_ELIGIBLE');

begin
  select invoice_amount,upper(source),upper(invoice_type_lookup_code), invoice_currency_code, gl_date
    into l_amt,l_inv_source,l_inv_type, l_invoice_currency, l_invoice_gl_date
    from ap_invoices_all
   where invoice_id = p_invoice_id;
exception
when no_data_found then
  l_amt := 0;
  l_inv_source := null;
  l_inv_type := null;
end;

if l_invoice_currency <> 'USD' then
  begin
    select gdr.conversion_rate
      into l_conversion_rate
      from gl_daily_rates gdr
     where gdr.from_currency = l_invoice_currency
       and gdr.to_currency = 'USD'
       and gdr.conversion_type = 'Corporate'
       and trunc(gdr.conversion_date) = trunc(l_invoice_gl_date);
  exception when no_data_found then
    RAISE_APPLICATION_ERROR(-20799,'No Conversion rate found from '||l_invoice_currency||' to USD for '||to_char(l_invoice_gl_date,'dd-MON-rrrr'));
  end;
else
  l_conversion_rate := 1;
end if;

begin
  select 'Y'
    into l_supplier_type_exempt
    from fnd_lookup_values_vl flv,
         ap_invoices_all ai,
         ap_suppliers sup
   where flv.lookup_type='XXAP_HOLD_EXEMPT_VENDOR_TYPES'
     and flv.enabled_flag = 'Y'
     and ai.invoice_id = p_invoice_id
     and sup.vendor_id = ai.vendor_id
     and flv.LOOKUP_CODE = sup.vendor_type_lookup_code;
exception
when no_data_found then
  l_supplier_type_exempt := 'N';
end;

/*Strat CHG0037986  
        New Lookup Created 'XXAP_HOLD_EXEMPT_INVOICE_SRCS' for Configurable Invoice Sources
*/
begin
  select 'Y'
    into l_inv_src_type_exempt
    from fnd_lookup_values_vl flv
   where flv.lookup_type='XXAP_HOLD_EXEMPT_INVOICE_SRCS'
     and flv.enabled_flag = 'Y'
     and flv.LOOKUP_CODE  = l_inv_source;
exception
when no_data_found then
  l_inv_src_type_exempt := 'N';
end;

--New Lookup Created 'XXAP_HOLD_EXEMPT_INVOICE_TYPES' for Configurable Invoice Types
begin
  select 'Y'
    into l_inv_type_exempt
    from fnd_lookup_values_vl flv
   where flv.lookup_type='XXAP_HOLD_EXEMPT_INVOICE_TYPES'
     and flv.enabled_flag = 'Y'
     and flv.LOOKUP_CODE  = l_inv_type;
exception
when no_data_found then
  l_inv_type_exempt := 'N';
end;
/*End CHG0037986 */

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'HOLD_ELIGIBLE',
                   message   => 'l_amt:'||l_amt||
                                ' l_inv_source:'||l_inv_source||
                                ' l_inv_type:'||l_inv_type);

IF (l_amt*l_conversion_rate) < 1000
  -- OR l_inv_source IN ('RECEIVABLES','INTERCOMPANY') /* Commented on CHG0037986 */
  -- OR l_inv_type = 'EXPENSE REPORT'                  /* Commented on CHG0037986 */
   OR l_inv_src_type_exempt  = 'Y'  /* Added on CHG0037986 */
   OR l_inv_type_exempt      = 'Y'  /* Added on CHG0037986 */
   OR l_supplier_type_exempt = 'Y' THEN
  RETURN('N');
ELSE
  RETURN('Y');
END IF;

END HOLD_ELIGIBLE;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    validate_invoice
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         This Procedure checks if Invoice is eligible for hold. If the Invoice is eligible then a hold is applied
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036487
  27-JAN-2016        1.1                  Diptasurjya       INC0056916 - Check if XX_PO_DATE_HOLD hold has already been
                                                            released, if yes do not put hold again
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE validate_invoice(p_invoice_id IN number,
                           p_user_id    IN number DEFAULT NULL) IS

l_hold_code ap_hold_codes.hold_lookup_code%type;
l_hold_type ap_hold_codes.hold_type%type;
l_hold_reason varchar2(2000);
l_mail_list VARCHAR2(500);
--l_role_name   VARCHAR2(100) := FND_PROFILE.VALUE('XXAP_HOLD_NOTF_ROLE');
l_err_code  NUMBER;
l_err_msg   VARCHAR2(500);
l_release_cnt NUMBER;
l_unrelease_cnt NUMBER; -- INC0056916 - Dipta added
l_invoice_creator fnd_user.user_name%type;

BEGIN

 -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'Inside the Procedure validate_invoice'||
                                ' p_invoice_id:' || p_invoice_id);

   select b.user_name
    into l_invoice_creator
    from ap_invoices_all a,
         fnd_user b
    where a.invoice_id = p_invoice_id and
          a.created_by = b.user_id;

 fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'create_single_hold',
                   message   => ' l_invoice_creator :'||l_invoice_creator);


IF hold_eligible(p_invoice_id) = 'N' THEN

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'Inside IF Condition while calling function hold_eligible'||
                                ' . Cannot Create Hold as Invoice failed the eligibility criteria');

ELSE

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'Inside ELSE Condition while calling function hold_eligible'||
                                ' . Continue with Invoice Hold Validations');

SELECT count(*)
INTO l_unrelease_cnt -- INC0056916 - Dipta changed from l_release_cnt to l_unrelease_cnt
FROM ap_holds_all
WHERE invoice_id = p_invoice_id AND
      hold_lookup_code = 'XX_PO_DATE_HOLD' and --FND_PROFILE.VALUE('XXAP_HOLD_CODE') and
      release_lookup_code IS NULL;

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'l_unrelease_cnt :'||l_unrelease_cnt); -- INC0056916 - Dipta changed from l_release_cnt to l_unrelease_cnt
                               -- 'Profile XXAP_HOLD_CODE Value:'||FND_PROFILE.VALUE('XXAP_HOLD_CODE'));

IF  l_unrelease_cnt > 0 THEN  -- INC0056916 - Dipta changed from l_release_cnt to l_unrelease_cnt

  if get_hold_action(p_invoice_id) IN ('CREATE_HOLD_PO_NOT_EXISTS','CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE') then

     fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'l_unrelease_cnt > 0; No Action Taken as Issue Still Exists');

      NULL; -- Do Not release hold as Issue still exists

  elsif get_hold_action(p_invoice_id) = 'DONT_CREATE_HOLD' then

     fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'l_release_cnt > 0; Before Release API');

     release_single_hold(p_invoice_id            => p_invoice_id,
                   p_hold_lookup_code      => 'XX_PO_DATE_HOLD',--'XX_INVOICE_HOLD', --FND_PROFILE.VALUE('XXAP_HOLD_CODE'),
                   p_release_lookup_code      => 'XXAP_PO_HOLD_RELEASE',
                   p_held_by               => p_user_id,
                   p_calling_sequence      => NULL
                   );
  end if;

ELSE
  /* INC0056916 - Dipta - Start Evaluate released holds for this invoice */
  SELECT count(*)
  INTO l_release_cnt
  FROM ap_holds_all
  WHERE invoice_id = p_invoice_id AND
        hold_lookup_code = 'XX_PO_DATE_HOLD' and --FND_PROFILE.VALUE('XXAP_HOLD_CODE') and
        release_lookup_code IS NOT NULL;

  if l_release_cnt = 0 then
  /* INC0056916 - Dipta - End Evaluate released holds for this invoice */
    fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module || 'validate_invoice',
                       message   => 'unreleased count not greater than zero and release count is 0');

    IF get_hold_action(p_invoice_id) IN ('CREATE_HOLD_PO_NOT_EXISTS','CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE') THEN

    fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module || 'validate_invoice',
                       message   => 'Before Deriving Hold');

    l_hold_code := '';
    l_hold_type := '';
    l_hold_reason := '';
    select hold_lookup_code,hold_type
    into l_hold_code,l_hold_type
    from ap_hold_codes
    where hold_lookup_code = 'XX_PO_DATE_HOLD'; --FND_PROFILE.VALUE('XXAP_HOLD_CODE');


    fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module || 'validate_invoice',
                       message   => 'Before Holds IF Condition');

    IF l_hold_code IS NOT NULL AND l_hold_type IS NOT NULL THEN

    fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module || 'validate_invoice',
                       message   => 'Before Calling API');

    l_hold_reason := (CASE WHEN  get_hold_action(p_invoice_id) = 'CREATE_HOLD_PO_NOT_EXISTS' THEN 'PONOTEXISTS:PO Does not Exists for the Invoice'
                           WHEN  get_hold_action(p_invoice_id) = 'CREATE_HOLD_PO_DATE_MORE_THAN_INV_DATE' THEN 'PODATEGINVDATE:PO Date is greater than Invoice Date'
                           ELSE NULL END);

    fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module || 'validate_invoice',
                       message   => 'l_hold_reason :'||l_hold_reason);

    create_single_hold(p_invoice_id            => p_invoice_id,
                       p_hold_lookup_code      => l_hold_code,
                       p_hold_type             => l_hold_type,
                       p_hold_reason           => l_hold_reason,
                       p_held_by               => p_user_id,
                       p_calling_sequence      => NULL
                       );

    END IF;

    END IF;
  end if;/* INC0056916 - Dipta - Evaluate released holds for this invoice */
END IF;

END IF;  -- MAIN END IF

fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'validate_invoice',
                   message   => 'END of the Procedure');

EXCEPTION
WHEN OTHERS THEN
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXAPHOLDMAILLIST');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_invoice_creator,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'Exception Occured in xxap_holds_pkg.validate_invoice for Invoice ID '||p_invoice_id,
                              p_body_text   => 'Exception Occured in xxap_holds_pkg.validate_invoice for Invoice ID '||p_invoice_id||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                               'SQL Error :'||SQLERRM,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END validate_invoice;
END XXAP_HOLDS_PKG;
/