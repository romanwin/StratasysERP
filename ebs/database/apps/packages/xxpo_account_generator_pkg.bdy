CREATE OR REPLACE PACKAGE BODY xxpo_account_generator_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST251
  --  name:               Account Generator for Projects
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            Account Generator for Projects Related  determine the distribution
  --                      account for Requisition  lines. In current business process the requestor
  --                      enter requisition  into the system by enter the following information:
  --                      Make sure the destination type is Expense  and RandD
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --  1.1   15/09/2020   Roman W.        CHG0048543 - R & D Location in purchase requisition - change logic  
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CUST251
  --  name:               Account Generator for Projects
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            in form personalization-
  --                      check if requisition have lines from type EXPENCE
  --                      plus deliver_to_location_id is R and D
  --                      and have value at attribute1
  --                      if do not have value msg will popup and return to header
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --  1.1   10.10.10     yuval tal       change logic
  --  1.2   20.9.12      yuval.tal       cr 483 change seg7 in accounts
  --                                     called from po form ( form personaliztion) when navigating to po_approve block
  --------------------------------------------------------------------
  FUNCTION get_project_att1_entered(p_requisition_header_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_project_name VARCHAR2(150) := NULL;
  
    CURSOR c_exp IS
      SELECT 1
        FROM po_requisition_lines_all prl
       WHERE nvl(prl.cancel_flag, 'N') = 'N'
         AND prl.destination_type_code = 'EXPENSE'
         AND prl.requisition_header_id = p_requisition_header_id;
  BEGIN
  
    FOR i IN c_exp LOOP
    
      SELECT prh.attribute1
        INTO l_project_name
        FROM po_requisition_headers_all prh
       WHERE prh.requisition_header_id = p_requisition_header_id;
    
      IF l_project_name IS NULL THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    
    END LOOP;
  
    RETURN 'I'; -- not expense
  
    /*
    SELECT prh.attribute1
       INTO l_project_name
       FROM po_requisition_headers_all prh
       , po_requisition_lines_all prl
      WHERE prh.requisition_header_id = p_requisition_header_id
        AND prh.requisition_header_id = prl.requisition_header_id
        AND prl.destination_type_code = 'EXPENSE'
        AND prl.deliver_to_location_id = 262
        AND prh.attribute1 IS NOT NULL;
    
     RETURN 'Y';*/
  
    /* EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN OTHERS THEN
      RETURN 'Y';*/
  END get_project_att1_entered;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               check_req_hdr_have_line
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            in form personalization-
  --                      i do not want user to commit before enter lines to req
  --                      if did not enter any line - msg will popup and raise
  --  return:             EXIST   - if find requisition lines
  --                      NO_LINE - if did not find any lines
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION check_req_hdr_have_line(p_requisition_header_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_exist_lines NUMBER := 0;
  
  BEGIN
    SELECT COUNT(prl.requisition_line_id)
      INTO l_exist_lines
      FROM po_requisition_headers_all prh, po_requisition_lines_all prl
     WHERE prh.requisition_header_id = p_requisition_header_id
       AND prh.requisition_header_id = prl.requisition_header_id;
    --and    prl.destination_type_code  = 'EXPENSE'
    --and    prl.deliver_to_location_id = 262;
  
    IF nvl(l_exist_lines, 0) > 0 THEN
      RETURN 'EXIST';
    ELSE
      RETURN 'NO_LINE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'NO_LINE';
  END check_req_hdr_have_line;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               get_project_requester_acc
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            this procedure call from WF - PO Requisition Account Generator
  --                      Process:  XX: Build Rule-Based Expense Account
  --                      Function: XX: Get Project Requester Acc
  --  return:             COMPLETE:SUCCESS
  --                      COMPLETE:FAILURE
  -----------------------------------------------------------------------------------------------------------
  --  ver   date         name             desc
  --  ----  -----------  ---------------  -------------------------------------------------------------------
  --  1.0   18/01/2010   Dalit A. Raviv   initial build
  --  1.1   15/09/2020   Roman W.         CHG0048543 - R & D Location in purchase requisition - change logic
  -----------------------------------------------------------------------------------------------------------
  PROCEDURE get_project_requester_acc(itemtype IN VARCHAR2,
                                      itemkey  IN VARCHAR2,
                                      actid    IN NUMBER,
                                      funcmode IN VARCHAR2,
                                      RESULT   OUT NOCOPY VARCHAR2) IS
  
    --x_progress          varchar2(150) := null;
    l_project_name      VARCHAR2(150) := NULL;
    l_deliver_to_loc_id NUMBER := NULL;
    l_dest_type_code    VARCHAR2(150) := NULL;
    l_orig_ccid         NUMBER := NULL;
    l_expense_org_id    NUMBER := NULL;
    l_coa_id            NUMBER := NULL;
    l_seg1              VARCHAR2(25) := NULL;
    l_seg2              VARCHAR2(25) := NULL;
    l_seg3              VARCHAR2(25) := NULL;
    l_seg4              VARCHAR2(25) := NULL;
    l_seg5              VARCHAR2(25) := NULL;
    l_seg6              VARCHAR2(25) := NULL;
    l_seg7              VARCHAR2(25) := NULL;
    l_seg8              VARCHAR2(25) := NULL;
    l_seg9              VARCHAR2(25) := NULL;
    l_new_ccid          NUMBER := NULL;
    l_return_code       VARCHAR2(50) := NULL;
    l_err_msg           VARCHAR2(2500) := NULL;
    l_new_cc_segments   VARCHAR2(250) := NULL;
  
  BEGIN
  
    IF (funcmode <> wf_engine.eng_run) THEN
    
      RESULT := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    IF nvl(fnd_profile.value('XXPO_ENABLE_ACCOUNT_GENERATOR_PRJ'), 'N') = 'Y' THEN
      -- get item attributes values
      l_project_name := wf_engine.getitemattrtext(itemtype => itemtype,
                                                  itemkey  => itemkey,
                                                  aname    => 'HEADER_ATT1');
    
      l_deliver_to_loc_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                         itemkey  => itemkey,
                                                         aname    => 'DELIVER_TO_LOCATION_ID');
    
      l_dest_type_code := wf_engine.getitemattrtext(itemtype => itemtype,
                                                    itemkey  => itemkey,
                                                    aname    => 'DESTINATION_TYPE_CODE');
      -- this is the acct_id that i need to change
      l_orig_ccid := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                 itemkey  => itemkey,
                                                 aname    => 'DEFAULT_ACCT_ID');
    
      -- get org_id If it is NULL and the org context's org_id is not null,
      -- then copy org_context's org_id.
      IF l_expense_org_id IS NULL THEN
        l_expense_org_id := po_moac_utils_pvt.get_current_org_id; --<R12 MOAC>
      END IF;
      -- check that this is an expence and RandD requisiotion
      IF /*l_deliver_to_loc_id = 262 AND -- rem By Dovik 15/09/2020 CHG0048543 */
       l_dest_type_code = 'EXPENSE' THEN
        BEGIN
          -- get original account segments
          SELECT gcc.segment1,
                 gcc.segment2,
                 gcc.segment3,
                 gcc.segment4,
                 gcc.segment5,
                 gcc.segment6,
                 gcc.segment7,
                 gcc.segment8,
                 gcc.segment9
            INTO l_seg1,
                 l_seg2,
                 l_seg3,
                 l_seg4,
                 l_seg5,
                 l_seg6,
                 l_seg7,
                 l_seg8,
                 l_seg9
            FROM gl_code_combinations gcc
           WHERE gcc.code_combination_id = l_orig_ccid;
          -- change segment8 at the account to the value at attribute1 from the header
          -- and create new concatenate segments
        
          l_new_cc_segments := l_seg1 || '.' || l_seg2 || '.' || l_seg3 || '.' ||
                               l_seg4 || '.' || l_seg5 || '.' || l_seg6 || '.' ||
                               l_seg7 || '.' || l_project_name || '.' ||
                               l_seg9;
        
          -- get coa_id nned for after call
          l_coa_id := xxgl_utils_pkg.get_coa_id_from_ou(l_expense_org_id);
        
          -- if the new account exists return ccid for the new combination
          -- if do not exists create new account and return new ccid
          xxgl_utils_pkg.get_and_create_account(p_concat_segment => l_new_cc_segments, -- i v
                                                p_coa_id         => l_coa_id, -- i v
                                                --p_app_short_name      IN VARCHAR2 DEFAULT NULL,
                                                x_code_combination_id => l_new_ccid, -- o n
                                                x_return_code         => l_return_code, -- o v
                                                x_err_msg             => l_err_msg); -- o v
        
          IF l_return_code = 'S' THEN
            -- success
            -- set item attribute back with the return value - new ccid
            BEGIN
              wf_engine.setitemattrnumber(itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'DEFAULT_ACCT_ID',
                                          avalue   => l_new_ccid);
              RESULT := 'COMPLETE:SUCCESS';
              RETURN;
            EXCEPTION
              WHEN OTHERS THEN
                RESULT := 'COMPLETE:FAILURE';
            END;
          ELSE
          
            -- set item attribute back with null value
            wf_engine.setitemattrnumber(itemtype => itemtype,
                                        itemkey  => itemkey,
                                        aname    => 'DEFAULT_ACCT_ID',
                                        avalue   => NULL);
          
            RESULT := 'COMPLETE:FAILURE';
            --raise;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            wf_core.context('XXPO_ACCOUNT_GENERATOR_PKG',
                            'get_project_requester_acc',
                            itemtype,
                            itemkey,
                            to_char(actid),
                            funcmode,
                            SQLERRM);
          
            RESULT := 'COMPLETE:FAILURE';
            --raise;
        END;
      ELSE
        RESULT := 'COMPLETE:SUCCESS';
        RETURN;
      END IF;
    ELSE
      RESULT := 'COMPLETE:SUCCESS';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXPO_ACCOUNT_GENERATOR_PKG',
                      'get_project_requester_acc',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      SQLERRM);
      RESULT := 'COMPLETE:FAILURE';
    
      RETURN;
  END get_project_requester_acc;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               update_ditribution_account
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      25/01/2010
  --------------------------------------------------------------------
  --  process:
  --  return:             p_error_code - 0 success,     <> 0 failed
  --                      p_error_desc - null success , <> null failed
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/01/2010    Dalit A. Raviv  initial build
  -- 1.1   10.10.10        yuval tal      init account to null
  --------------------------------------------------------------------
  PROCEDURE update_ditribution_account(p_req_header_id IN NUMBER,
                                       p_proj_account  IN VARCHAR2,
                                       p_error_code    OUT NUMBER,
                                       p_error_desc    OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    CURSOR get_req_dist_lines_c(p_requisition_line_id IN NUMBER) IS
      SELECT rd.*
        FROM po_req_distributions_all rd, po_requisition_lines_all rl
       WHERE rd.requisition_line_id = rl.requisition_line_id
         AND rl.requisition_header_id = p_req_header_id
         AND rd.requisition_line_id = p_requisition_line_id; -- 11581 --
  
    CURSOR get_req_lines_c IS
      SELECT rl.*
        FROM po_requisition_lines_all rl
       WHERE rl.requisition_header_id = p_req_header_id; -- 11581 --
  
    CURSOR get_req_header_c IS
      SELECT rh.*
        FROM po_requisition_headers_all rh
       WHERE rh.requisition_header_id = p_req_header_id; -- 11581 --
  
    l_req_dist_rec   po_req_distributions_all%ROWTYPE;
    l_req_line_rec   po_requisition_lines_all%ROWTYPE;
    l_req_header_rec po_requisition_headers_all%ROWTYPE;
  
    -- in out vars  --
    l_charge_success        BOOLEAN;
    l_budget_success        BOOLEAN;
    l_accrual_success       BOOLEAN;
    l_variance_success      BOOLEAN;
    l_new_combination       BOOLEAN;
    l_code_combination_id   NUMBER(30);
    l_budget_account_id     NUMBER(30);
    l_accrual_account_id    NUMBER(30);
    l_variance_account_id   NUMBER(30);
    l_charge_account_flex   VARCHAR2(2000);
    l_budget_account_flex   VARCHAR2(2000);
    l_accrual_account_flex  VARCHAR2(2000);
    l_variance_account_flex VARCHAR2(2000);
    l_charge_account_desc   VARCHAR2(2000);
    l_budget_account_desc   VARCHAR2(2000);
    l_accrual_account_desc  VARCHAR2(2000);
    l_variance_account_desc VARCHAR2(2000);
    l_wf_itemkey            VARCHAR2(2000);
    l_fb_error_msg          VARCHAR2(2000) := NULL;
    l_expense_org_id        NUMBER := NULL;
    l_coa_id                NUMBER := NULL;
  
    l_return BOOLEAN;
  
    general_exception EXCEPTION;
  BEGIN
    FOR get_req_header_r IN get_req_header_c LOOP
      l_req_header_rec := get_req_header_r;
    END LOOP;
  
    FOR get_req_lines_r IN get_req_lines_c LOOP
      l_req_line_rec := NULL;
      l_req_line_rec := get_req_lines_r;
      FOR get_req_dist_lines_r IN get_req_dist_lines_c(get_req_lines_r.requisition_line_id) LOOP
        -- first delete requisition distribution line
        -- then create the new distribution with the correct project charge acccount.
        l_req_dist_rec := get_req_dist_lines_r;
        /*begin
          DELETE FROM po_req_distributions_all
          WHERE  distribution_id      = get_req_dist_lines_r.distribution_id;
        
        exception
          when others then
            rollback;
            p_error_desc := 'Can not delete req distribution - '||get_req_dist_lines_r.distribution_id;
            p_error_code := 1;
            raise general_exception;
        end;*/
      
        BEGIN
        
          -- get coa_id value by defaul org id
          l_expense_org_id      := po_moac_utils_pvt.get_current_org_id; --<R12 MOAC>
          l_coa_id              := xxgl_utils_pkg.get_coa_id_from_ou(l_expense_org_id);
          l_code_combination_id := NULL; -- yuval  10.10.10
          l_budget_account_id   := NULL;
          l_accrual_account_id  := NULL;
          l_variance_account_id := NULL; -- end yuval 10.10.10
          l_return              := po_req_wf_build_account_init.start_workflow(x_charge_success              => l_charge_success, -- i/o b
                                                                               x_budget_success              => l_budget_success, -- i/o b
                                                                               x_accrual_success             => l_accrual_success, -- i/o b
                                                                               x_variance_success            => l_variance_success, -- i/o b
                                                                               x_code_combination_id         => l_code_combination_id, -- i/o n
                                                                               x_budget_account_id           => l_budget_account_id, -- i/o n
                                                                               x_accrual_account_id          => l_accrual_account_id, -- i/o n
                                                                               x_variance_account_id         => l_variance_account_id, -- i/o n
                                                                               x_charge_account_flex         => l_charge_account_flex, -- i/o v
                                                                               x_budget_account_flex         => l_budget_account_flex, -- i/o v
                                                                               x_accrual_account_flex        => l_accrual_account_flex, -- i/o v
                                                                               x_variance_account_flex       => l_variance_account_flex, -- i/o v
                                                                               x_charge_account_desc         => l_charge_account_desc, -- i/o v
                                                                               x_budget_account_desc         => l_budget_account_desc, -- i/o v
                                                                               x_accrual_account_desc        => l_accrual_account_desc, -- i/o v
                                                                               x_variance_account_desc       => l_variance_account_desc, -- i/o v
                                                                               x_coa_id                      => l_coa_id, -- i   n
                                                                               x_bom_resource_id             => NULL, -- i   n
                                                                               x_bom_cost_element_id         => NULL, -- i   n
                                                                               x_category_id                 => l_req_line_rec.category_id, -- i   n
                                                                               x_destination_type_code       => l_req_line_rec.destination_type_code, -- i   v
                                                                               x_deliver_to_location_id      => l_req_line_rec.deliver_to_location_id, -- i   n
                                                                               x_destination_organization_id => l_req_line_rec.destination_organization_id, -- i   n
                                                                               x_destination_subinventory    => l_req_line_rec.destination_subinventory, -- i   v
                                                                               x_expenditure_type            => NULL, -- i   v
                                                                               x_expenditure_organization_id => NULL, -- i   n
                                                                               x_expenditure_item_date       => NULL, -- i   d
                                                                               x_item_id                     => l_req_line_rec.item_id, -- i   n
                                                                               x_line_type_id                => l_req_line_rec.line_type_id, -- i   n
                                                                               x_result_billable_flag        => NULL, -- i   v
                                                                               x_preparer_id                 => l_req_header_rec.preparer_id, -- i   n
                                                                               x_project_id                  => NULL, -- i   n
                                                                               x_document_type_code          => NULL, -- i   v
                                                                               x_blanket_po_header_id        => NULL, -- i   n
                                                                               x_source_type_code            => l_req_line_rec.source_type_code, -- i   v
                                                                               x_source_organization_id      => l_req_line_rec.source_organization_id, -- i   n  for internal
                                                                               x_source_subinventory         => l_req_line_rec.source_subinventory, -- i   v  for internal
                                                                               x_task_id                     => NULL, -- i   n
                                                                               -- ????????????????????????
                                                                               x_deliver_to_person_id => l_req_line_rec.to_person_id, -- i   n
                                                                               --
                                                                               x_type_lookup_code => l_req_header_rec.type_lookup_code, -- i   v
                                                                               -- ????????????????????????
                                                                               x_suggested_vendor_id => NULL, -- i   n
                                                                               --
                                                                               x_wip_entity_id              => NULL, -- i   n
                                                                               x_wip_entity_type            => NULL, -- i   v
                                                                               x_wip_line_id                => NULL, -- i   n
                                                                               x_wip_repetitive_schedule_id => NULL, -- i   n
                                                                               x_wip_operation_seq_num      => NULL, -- i   n
                                                                               x_wip_resource_seq_num       => NULL, -- i   n
                                                                               x_po_encumberance_flag       => 'Y', -- i   v
                                                                               x_gl_encumbered_date         => trunc(SYSDATE), -- i   d
                                                                               wf_itemkey                   => l_wf_itemkey, -- i/o nocopy v
                                                                               x_new_combination            => l_new_combination, -- i/o nocopy b,
                                                                               header_att1                  => p_proj_account, -- i   v
                                                                               header_att2                  => NULL, -- i   v
                                                                               header_att3                  => NULL, -- i   v
                                                                               header_att4                  => NULL, -- i   v
                                                                               header_att5                  => NULL, -- i   v
                                                                               header_att6                  => NULL, -- i   v
                                                                               header_att7                  => NULL, -- i   v
                                                                               header_att8                  => NULL, -- i   v
                                                                               header_att9                  => NULL, -- i   v
                                                                               header_att10                 => NULL, -- i   v
                                                                               header_att11                 => NULL, -- i   v
                                                                               header_att12                 => NULL, -- i   v
                                                                               header_att13                 => NULL, -- i   v
                                                                               header_att14                 => NULL, -- i   v
                                                                               header_att15                 => NULL, -- i   v
                                                                               line_att1                    => NULL, -- i   v
                                                                               line_att2                    => NULL, -- i   v
                                                                               line_att3                    => NULL, -- i   v
                                                                               line_att4                    => NULL, -- i   v
                                                                               line_att5                    => NULL, -- i   v
                                                                               line_att6                    => NULL, -- i   v
                                                                               line_att7                    => NULL, -- i   v
                                                                               line_att8                    => NULL, -- i   v
                                                                               line_att9                    => NULL, -- i   v
                                                                               line_att10                   => NULL, -- i   v
                                                                               line_att11                   => NULL, -- i   v
                                                                               line_att12                   => NULL, -- i   v
                                                                               line_att13                   => NULL, -- i   v
                                                                               line_att14                   => NULL, -- i   v
                                                                               line_att15                   => NULL, -- i   v
                                                                               distribution_att1            => NULL, -- i   v
                                                                               distribution_att2            => NULL, -- i   v
                                                                               distribution_att3            => NULL, -- i   v
                                                                               distribution_att4            => NULL, -- i   v
                                                                               distribution_att5            => NULL, -- i   v
                                                                               distribution_att6            => NULL, -- i   v
                                                                               distribution_att7            => NULL, -- i   v
                                                                               distribution_att8            => NULL, -- i   v
                                                                               distribution_att9            => NULL, -- i   v
                                                                               distribution_att10           => NULL, -- i   v
                                                                               distribution_att11           => NULL, -- i   v
                                                                               distribution_att12           => NULL, -- i   v
                                                                               distribution_att13           => NULL, -- i   v
                                                                               distribution_att14           => NULL, -- i   v
                                                                               distribution_att15           => NULL, -- i   v
                                                                               fb_error_msg                 => l_fb_error_msg --,                          -- i/o nocopy v
                                                                               --x_award_id          =>  ,       -- i n def null
                                                                               --x_suggested_vendor_site_id => , -- i n def null
                                                                               --p_unit_price                => ,-- i n def null
                                                                               --p_blanket_po_line_num       =>  -- i n def null
                                                                               );
          IF (NOT (l_return)) THEN
            -- failed
            p_error_code := 1;
            p_error_desc := 'Account generator failed - ' || l_fb_error_msg ||
                            ' - ' || SQLERRM;
          ELSE
            -- success
            UPDATE po_req_distributions_all rd
               SET rd.code_combination_id = l_code_combination_id,
                   rd.budget_account_id   = l_budget_account_id,
                   rd.accrual_account_id  = l_accrual_account_id,
                   rd.variance_account_id = l_variance_account_id
             WHERE rd.distribution_id =
                   get_req_dist_lines_r.distribution_id;
          
            COMMIT;
          
            p_error_code := 0;
            p_error_desc := NULL;
          
          END IF;
        END;
      END LOOP; -- dist
    END LOOP; -- lines
  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'General exception - ' || SQLERRM;
  END update_ditribution_account;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               check_req_dist_have_encumb
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      31/01/2010
  --------------------------------------------------------------------
  --  process:
  --  return:             Y find encumbered_flag = Y for this req
  --                      N did not find
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/01/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION check_req_dist_have_encumb(p_req_header_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_count NUMBER := 0;
  
  BEGIN
    IF p_req_header_id IS NOT NULL THEN
      SELECT COUNT(1) --prd.encumbered_flag
        INTO l_count
        FROM po_requisition_headers_all prh,
             po_requisition_lines_all   prl,
             po_req_distributions_all   prd
       WHERE prh.requisition_header_id = prl.requisition_header_id
         AND prh.requisition_header_id = p_req_header_id
         AND prl.requisition_line_id = prd.requisition_line_id
         AND nvl(prd.encumbered_flag, 'N') = 'Y';
    
      IF l_count = 0 THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    ELSE
      RETURN 'N';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END check_req_dist_have_encumb;

  --------------------------------------
  -- get_new_cc_id
  --
  -- in : p_segment7 : new segment
  --       p_ccid    : current ccid for seg7 update
  --
  --  out  : p_new_ccid :  new code combination id (exists or generated)
  --         p_err_code :  -1  no need to generate new code combination
  --                       0   successfuly ended
  --                       1   error accured
  -------------------------------------
  PROCEDURE get_new_cc_id(p_segment7    VARCHAR2,
                          p_ccid        NUMBER,
                          p_new_ccid    OUT NUMBER,
                          p_err_code    OUT NUMBER,
                          p_err_message OUT VARCHAR2) IS
    CURSOR cc(c_ccid NUMBER) IS
      SELECT *
        FROM gl_code_combinations t
       WHERE t.code_combination_id = c_ccid
         AND enabled_flag = 'Y';
  
    CURSOR check_conc_seg_exists(c_conc_seg VARCHAR2) IS
      SELECT code_combination_id
        FROM gl_code_combinations_kfv x
       WHERE concatenated_segments = c_conc_seg
         AND enabled_flag = 'Y';
    l_conc_seg    VARCHAR2(500);
    l_acc_id      NUMBER;
    l_err_code    VARCHAR2(50);
    l_err_message VARCHAR2(2000);
  BEGIN
    p_new_ccid := NULL;
    FOR i IN cc(p_ccid) LOOP
      -- check diff
      IF p_segment7 = i.segment7 THEN
        p_err_code    := -1;
        p_err_message := 'No nedd to update code_combination_id';
        dbms_output.put_line(p_err_message);
        RETURN;
      END IF;
    
      l_conc_seg := i.segment1 || '.' || i.segment2 || '.' || i.segment3 || '.' ||
                    i.segment4 || '.' || i.segment5 || '.' || i.segment6 || '.' ||
                    p_segment7 || '.' || i.segment8 || '.' || i.segment9;
    
      dbms_output.put_line('get new code combination');
    
      OPEN check_conc_seg_exists(l_conc_seg);
    
      FETCH check_conc_seg_exists
        INTO l_acc_id;
    
      IF check_conc_seg_exists%NOTFOUND THEN
      
        -- generate acoount combination
        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => l_conc_seg,
                                              p_coa_id              => i.chart_of_accounts_id,
                                              x_code_combination_id => l_acc_id,
                                              x_return_code         => l_err_code,
                                              x_err_msg             => l_err_message);
      
        IF l_err_code != fnd_api.g_ret_sts_success THEN
          -- dbms_output.put_line('l_err_code=' || l_err_code ||
          --  ' l_err_message=' || l_err_message);
          p_err_code    := 1;
          p_err_message := 'Failed to generate ccid for ' || l_conc_seg || ' ' ||
                           l_err_message;
          RETURN;
        END IF;
      
      END IF;
      p_new_ccid := l_acc_id;
      p_err_code := 0;
    
      CLOSE check_conc_seg_exists;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  -------------------------------------
  -- update_po_accounts
  --
  -- cr 483 change seg7 in accounts
  -- called from po form ( form personaliztion) when navigating to po_approve block
  -------------------------------------
  PROCEDURE update_po_dist_accounts(p_po_header_id NUMBER) IS
  
    l_segment7 VARCHAR2(500);
    --l_conc_seg    VARCHAR2(500);
    l_err_code    VARCHAR2(50);
    l_err_message VARCHAR2(2000);
    l_cc_id       NUMBER;
    l_po_dist_id  NUMBER;
    CURSOR c_dist IS
      SELECT d.po_distribution_id,
             h.vendor_id,
             h.vendor_site_id,
             d.budget_account_id,
             d.accrual_account_id,
             d.variance_account_id,
             d.code_combination_id
        FROM po_distributions_all d, po_headers_all h
      
       WHERE h.po_header_id = d.po_header_id
         AND d.encumbered_flag = 'N'
         AND d.po_header_id = p_po_header_id;
    my_exception EXCEPTION;
  BEGIN
  
    --fnd_global.APPS_INITIALIZE(3850,-1,-1);
  
    FOR i IN c_dist LOOP
      l_po_dist_id := i.po_distribution_id;
      --
      BEGIN
      
        SELECT gcc.segment7
          INTO l_segment7
          FROM po_vendor_sites_all p, gl_code_combinations gcc
         WHERE gcc.code_combination_id = p.accts_pay_code_combination_id
           AND p.vendor_id = i.vendor_id
           AND p.vendor_site_id = i.vendor_site_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          RETURN;
        
      END;
      ---
    
      IF l_segment7 IS NOT NULL THEN
      
        ------- l_charge_account_id -----------------------------
        get_new_cc_id(l_segment7,
                      i.code_combination_id,
                      l_cc_id,
                      l_err_code,
                      l_err_message);
        IF l_err_code = 0 THEN
          UPDATE po_distributions_all t
             SET t.code_combination_id = l_cc_id
           WHERE t.po_distribution_id = i.po_distribution_id;
        ELSIF l_err_code = 1 THEN
          RAISE my_exception;
        END IF;
      
        ------- budget_account_id -----------------------------
        get_new_cc_id(l_segment7,
                      i.budget_account_id,
                      l_cc_id,
                      l_err_code,
                      l_err_message);
        IF l_err_code = 0 THEN
          UPDATE po_distributions_all t
             SET t.budget_account_id = l_cc_id
           WHERE t.po_distribution_id = i.po_distribution_id;
        ELSIF l_err_code = 1 THEN
          RAISE my_exception;
        END IF;
      
        ------- accrual_account_id -----------------------------
        get_new_cc_id(l_segment7,
                      i.accrual_account_id,
                      l_cc_id,
                      l_err_code,
                      l_err_message);
        IF l_err_code = 0 THEN
          UPDATE po_distributions_all t
             SET t.accrual_account_id = l_cc_id
           WHERE t.po_distribution_id = i.po_distribution_id;
        ELSIF l_err_code = 1 THEN
          RAISE my_exception;
        END IF;
      
        ------- variance_account_id -----------------------------
        get_new_cc_id(l_segment7,
                      i.variance_account_id,
                      l_cc_id,
                      l_err_code,
                      l_err_message);
        IF l_err_code = 0 THEN
          UPDATE po_distributions_all t
             SET t.variance_account_id = l_cc_id
           WHERE t.po_distribution_id = i.po_distribution_id;
        ELSIF l_err_code = 1 THEN
          RAISE my_exception;
        END IF;
        -----
      END IF; -- l_segment7 IS NOT NULL
    
    -- dist loop
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,
                              'po_distribution_id=' || l_po_dist_id || ' ' ||
                              l_err_message);
  END;

END xxpo_account_generator_pkg;
-- PO_WF_UTIL_PKG
-- PO_WF_PO_RULE_ACC . get_default_requester_acc
-- xxgl_utils_pkg
/
