create or replace PACKAGE BODY GL_WF_CUSTOMIZATION_PKG AS
  /*  $Header: glwfcusb.pls 120.2 2002/11/13 04:33:18 djogg ship $  */
  /* 12/05/14    Ofer Suad CHG0031459-  Implement Journal Entry Approval Workflow for the Stratasys US Ledger*/
  /* 08/06/14    Ofer Suad CHG0032366+CHG0032471   Implement Actual Journal Entry Approval Workflow for APJ and IL Ledgers */
  /* 17-APR-2015 Sandeep Akula CHG0034714 Changed logic in Procedure does_je_need_approval,can_preparer_approve and verify_authority*/
  --
  -- *****************************************************************************
  -- Procedure Is_JE_Valid
  -- *****************************************************************************
  --
  PROCEDURE is_je_valid(itemtype IN VARCHAR2,
                        itemkey  IN VARCHAR2,
                        actid    IN NUMBER,
                        funcmode IN VARCHAR2,
                        result   OUT NOCOPY VARCHAR2) IS
  BEGIN
    IF (funcmode = 'RUN') THEN
      -- Additional code can be added here.
      -- COMPLETE:Y (Workflow transition branch "Yes") indicates that the journal
      --            batch is valid.
      -- COMPLETE:N (Workflow transition branch "No") indicates that the journal
      --            batch is not valid.
      result := 'COMPLETE:Y';
    ELSIF (funcmode = 'CANCEL') THEN
      NULL;
    END IF;
  END is_je_valid;

  --
  -- *****************************************************************************
  -- Procedure Does_JE_Need_Approval
  -- *****************************************************************************
  --
  --------------------------------------------------------------------------------------------------
  /*
  Procedure Name:    does_je_need_approval
  Author's Name:   Sandeep Akula
  Date Written:    20-APR-2015
  Purpose:         This Procedure determines if Journal needs an Approval 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034714
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE does_je_need_approval(itemtype IN VARCHAR2,
                                  itemkey  IN VARCHAR2,
                                  actid    IN NUMBER,
                                  funcmode IN VARCHAR2,
                                  result   OUT NOCOPY VARCHAR2) IS

  l_ledger_id      gl_je_headers.ledger_id%type;
  l_batch_id  number;
  l_balance_type gl_je_headers.actual_flag%type;
  l_je_creator  gl_je_headers.created_by%type; -- 04/01/2015 SAkula Added variable  CHG0034714
  l_fpa_user_cnt   NUMBER; -- 04/01/2015 SAkula Added variable  CHG0034714
  l_cc  varchar2(100);  -- 04/01/2015 SAkula Added variable  CHG0034714
  l_org       number := fnd_global.ORG_ID;  -- 04/01/2015 SAkula Added variable  CHG0034714

  BEGIN

    IF (funcmode = 'RUN') THEN
     /* 12/05/14    Ofer Suad CHG0031459-  JE_Need_Approval only if it is SSYS leger                          */
     /*                                      or other region ledger and balance type  is not actual (Budget   */
     /*                                      or Encubrance)                                                   */

  --  l_balance_type := wf_engine.getItemAttrNumber(itemtype, itemkey, 'BALANCE_TYPE');
    l_batch_id:= wf_engine.getItemAttrNumber(itemtype, itemkey, 'BATCH_ID');
    --l_ledger_id
    select h.ledger_id,h.actual_flag,created_by  -- 04/01/2015 SAkula Added column "created_by"  CHG0034714
    into l_ledger_id,l_balance_type,l_je_creator  -- 04/01/2015 SAkula Added variable l_je_creator CHG0034714
    from gl_je_headers h
    where h.je_batch_id=l_batch_id
    and rownum=1;

    
    -- 04/01/2015 SAkula Checking if the JE Creator exists in the Value set XXGL_FPA_USERS  CHG0034714
    l_fpa_user_cnt := '';
     begin
      select count(*)
      into l_fpa_user_cnt 
      from fnd_flex_value_sets ffvs,
           fnd_flex_values_vl ffvv,
           fnd_user fu
      where ffvs.flex_value_set_id = ffvv.flex_value_set_id and
            ffvs.flex_value_set_name = 'XXGL_FPA_USERS' and
            upper(ffvv.flex_value) = upper(fu.user_name) and
            TRUNC(SYSDATE) BETWEEN TRUNC(NVL(ffvv.start_date_active,SYSDATE)) AND TRUNC(NVL(ffvv.end_date_active,SYSDATE)) and
            fu.user_id = l_je_creator;
     exception
     when no_data_found then
       l_fpa_user_cnt := '0';
     end;


      -- Additional code can be added here.
      -- COMPLETE:Y (Workflow transition branch "Yes") indicates that the journal
      --            batch needs approval.
      -- COMPLETE:N (Workflow transition branch "No") indicates that the journal
      --            batch does not need approval.
    
     -- Actual Balances should always go through Approval 
     IF l_balance_type = 'A' THEN  -- 04/01/2015 SAkula Added CHG0034714  
         result := 'COMPLETE:Y';   -- 04/01/2015 SAkula Added CHG0034714  
     
     ELSE  -- 04/01/2015 SAkula Added CHG0034714
     
              /* 08/06/14    Ofer Suad CHG0032366+CHG0032471   Implement Actual Journal Entry Approval Workflow for APJ+IL Ledgers */
            if l_ledger_id  in(2021,2022) and l_balance_type in('E','B') then 
                  result := 'COMPLETE:N';
            else
            
                  IF l_fpa_user_cnt > '0' THEN -- 04/01/2015 SAkula Added IF Condition CHG0034714
                     result := 'COMPLETE:N';   -- 04/01/2015 SAkula Added CHG0034714  
                  ELSE
                  
                         -- 04/01/2015 SAkula Added CHG0034714
                       l_cc := fnd_profile.value_specific(NAME => 'XX_BUDGET_APPROVER_CC',
                                                          USER_ID =>  NULL,
                                                          RESPONSIBILITY_ID =>  NULL,
                                                          APPLICATION_ID => NULL,
                                                          ORG_ID =>  l_org);
                 
                         -- 04/01/2015 SAkula Added CHG0034714
                           wf_engine.setitemattrtext(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => '#WFM_CC',
                                                     avalue   => l_cc);  
            
                               result := 'COMPLETE:Y';   -- 04/01/2015 SAkula Added CHG0034714  
            
                  END IF;  -- 04/01/2015 SAkula Added CHG0034714          
                  
            end if;
            
     END IF;   -- 04/01/2015 SAkula Added CHG0034714

    ELSIF (funcmode = 'CANCEL') THEN
      NULL;
    END IF;
   
  END does_je_need_approval;

  --
  -- *****************************************************************************
  -- Procedure Can_Preparer_Approve
  -- *****************************************************************************
  --
  --------------------------------------------------------------------------------------------------
  /*
  Procedure Name:    can_preparer_approve
  Author's Name:   Sandeep Akula
  Date Written:    20-APR-2015
  Purpose:         This Procedure determines if Preparer can approve a Journal 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034714
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE can_preparer_approve(itemtype IN VARCHAR2,
                                 itemkey  IN VARCHAR2,
                                 actid    IN NUMBER,
                                 funcmode IN VARCHAR2,
                                 result   OUT NOCOPY VARCHAR2) IS
                                 
  l_batch_id  number; -- 04/15/2015 SAkula Added CHG0034714          
  l_balance_type gl_je_headers.actual_flag%type;  -- 04/15/2015 SAkula Added CHG0034714           
  
  BEGIN
    IF (funcmode = 'RUN') THEN
      -- Additional code can be added here.
      -- COMPLETE:Y (Workflow transition branch "Yes") indicates that the preparer
      --            can self-approve the journal batch.
      -- COMPLETE:N (Workflow transition branch "No") indicates that the preparer
      --            cannot self-approve the journal batch.
      
      -- 04/15/2015 SAkula CHG0034714   Change START        
      l_batch_id:= wf_engine.getItemAttrNumber(itemtype, itemkey, 'BATCH_ID');
        select h.actual_flag
        into l_balance_type
        from gl_je_headers h
        where h.je_batch_id=l_batch_id
        and rownum=1;

       if l_balance_type = 'A' then
          result := 'COMPLETE:Y';
       else
          result := 'COMPLETE:N';
       end if;
       
       -- 04/15/2015 SAkula CHG0034714   Change END
       
    ELSIF (funcmode = 'CANCEL') THEN
      NULL;
    END IF;
  END can_preparer_approve;

  --
  -- *****************************************************************************
  -- Procedure Verify_Authority
  -- *****************************************************************************
  --
  --------------------------------------------------------------------------------------------------
  /*
  Procedure Name:    verify_authority
  Author's Name:   Sandeep Akula
  Date Written:    20-APR-2015
  Purpose:         This Procedure finds the Approver for the Journal 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034714
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE verify_authority(itemtype IN VARCHAR2,
                             itemkey  IN VARCHAR2,
                             actid    IN NUMBER,
                             funcmode IN VARCHAR2,
                             result   OUT NOCOPY VARCHAR2) IS
    l_batch_id  number;
    l_need_appr number;
    l_net_amt   number;
    l_approver  varchar2(100);
    l_org       number := fnd_global.ORG_ID;
    l_flag gl_je_headers.actual_flag%type;
    l_ledger_id      gl_je_headers.ledger_id%type;
  BEGIN
  l_ledger_id    := wf_engine.getItemAttrNumber(itemtype, itemkey, 'SET_OF_BOOKS_ID');
    IF (funcmode = 'RUN') THEN
  /* 12/05/14    Ofer Suad CHG0031459-  if it is SSUS leger - Use Oracle functionality */
  /*                                      otherwise use customization                  */

   l_batch_id := wf_engine.getItemAttrNumber(itemtype, itemkey, 'BATCH_ID');
  select h.actual_flag
          into l_flag
          from gl_je_headers h
         where h.je_batch_id = l_batch_id
           and rownum=1;


      if l_flag='A' then
      result := 'COMPLETE:PASS';
       else
     
       -- 04/01/2015 SAkula Commented below code. Approver will be set for each OU on profile XX_JOURNAL_APPROVER  CHG0034714
       /* select p.profile_value
          into l_approver
          from xxobjt_profiles_v p
         where p.profile_name = 'XX_JOURNAL_APPROVER'
           and p.level_type = 'Site';
        -- :=fnd_profile.VALUE('XX_JOURNAL_APPROVER');
        -- 20-nov-2012 - Ofer suad
        l_batch_id := wf_engine.getItemAttrNumber(itemtype, itemkey, 'BATCH_ID');

        l_need_appr := 0;
        select count(1)
          into l_need_appr
          from gl_je_headers h
         where h.je_batch_id = l_batch_id
           and h.actual_flag = 'E';
           if l_need_appr != 0
       then
        null; --l_approver:=fnd_profile.VALUE('XX_JOURNAL_APPROVER');
      else
        -- BudgetJE than it need additional condition check
        --  if je is not balanced - add fund or move between period - need aproval
        select sum(nvl(h.running_total_dr, 0)) -
               sum(nvl(h.running_total_cr, 0))
          into l_net_amt
          from gl_je_headers h
         where h.je_batch_id = l_batch_id;
        if nvl(l_net_amt, 1) != 0 then
          null; -- l_approver:=fnd_profile.VALUE('XX_JOURNAL_APPROVER');
        else
          --  if not same dept need approval
          l_net_amt := 0;
          select count(*)
            into l_net_amt
            from (select gcc.segment2,
                         sum(nvl(l.entered_dr, 0)) -
                         sum(nvl(l.entered_cr, 0))
                    from gl_je_headers        h,
                         gl_je_lines          l,
                         gl_code_combinations gcc
                   where h.je_batch_id = l_batch_id
                     and l.je_header_id = h.je_header_id
                     and gcc.code_combination_id = l.code_combination_id
                   group by gcc.segment2
                  having sum(nvl(l.entered_dr, 0)) - sum(nvl(l.entered_cr, 0)) != 0);
          if nvl(l_net_amt, 1) != 0 then
            null; -- l_approver:=fnd_profile.VALUE('XX_JOURNAL_APPROVER');
          else
            --if budget control is advisory need approval
            l_need_appr := 0;
            select count(1)
              into l_need_appr
              from gl_bc_packets p
             where p.packet_id in
                   (select pp.packet_id
                      from gl_bc_packets pp
                     where pp.je_batch_id = l_batch_id)

               and p.funds_check_level_code = 'D';
            if nvl(l_need_appr, 0) > 0 then
              null; -- l_approver:=fnd_profile.VALUE('XX_JOURNAL_APPROVER');
            else
              -- approval by local Manager
              l_approver := fnd_profile.value_specific('XX_JOURNAL_APPROVER',
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       l_org);
            end if;
          end if;
        end if;
      end if; */
      -----------------------
      
      -- 04/01/2015 SAkula Deriving the approver from the profile at Org Level  CHG0034714
        l_approver := fnd_profile.value_specific(NAME => 'XX_JOURNAL_APPROVER',
                                                 USER_ID =>  NULL,
                                                 RESPONSIBILITY_ID =>  NULL,
                                                 APPLICATION_ID => NULL,
                                                 ORG_ID =>  l_org);

      -- added by Ofer Suad 17.5.2011 get Budger and Encumrance Approver name
      wf_engine.SetItemAttrText(itemtype,
                                itemkey,
                                'APPROVER_NAME',
                                l_approver);
      -- Additional code can be added here.
      -- COMPLETE:PASS (Workflow transition branch "Pass") indicates that the
      --               approver passed the journal batch approval authorization
      --               check.
      -- COMPLETE:FAIL (Workflow transition branch "Fail") indicates that the
      --               approver failed the journal batch approval authorization
      --               check.
      result := 'COMPLETE:PASS';
    end if;
  ELSIF
  (funcmode = 'CANCEL') THEN NULL;
END IF;
END verify_authority;

END GL_WF_CUSTOMIZATION_PKG;
/
