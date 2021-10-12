CREATE OR REPLACE PACKAGE BODY xxap_mpa_accounting_pkg IS

  FUNCTION get_default_prepaid_acct(p_org_id                       IN NUMBER,
                                    p_invoice_distribution_id      IN NUMBER,
                                    p_invoice_distribution_account IN NUMBER)
    RETURN NUMBER
  -- this is the invoice distribution account id
    -- last updated 20/07/2009 by SHAIE
    -- 03/12/13 Ofer Suad        CR 1123 Cahnge logic of defualt acount to support new COA
   IS
  
    l_default_ccid                NUMBER;
    l_deferred_expense_account_vs VARCHAR2(50) := 'XXAP_MPA_PREPAID_EXP_ACCOUNT_VS';
    l_inv_dist_expense_account    VARCHAR2(20);
    l_coa_id                      NUMBER;
    l_default_conc_seg            gl_code_combinations_kfv.concatenated_segments%TYPE;
    l_new_prepaid_acct_number     VARCHAR2(20);
    l_flex_seg                    fnd_flex_ext.segmentarray;
    l_default_prepaid_acct        VARCHAR2(20);
    l_inv_company_segment         VARCHAR2(20);
    l_num_seg                     NUMBER;
    l_return_ccid                 NUMBER;
    l_ok                          BOOLEAN;
  
  BEGIN
    -- == log
    fnd_file.put_line(fnd_file.log, 'Objet XXAP_MPA_ACCOUNTING_PKG called');
    dbms_output.put_line('Objet XXAP_MPA_ACCOUNTING_PKG called');
  
    -- == DEFAULT PREPAID CCID ==
    -- 1. initialize default expense account CCID and number from the value set
  
    -- init coa_id
    -- get COA ID
    BEGIN
      SELECT gll.chart_of_accounts_id
        INTO l_coa_id
        FROM gl_ledgers gll, hr_operating_units hou
       WHERE gll.ledger_id = hou.set_of_books_id
         AND hou.organization_id = p_org_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('others exception in getting COA ID ' ||
                             SQLERRM);
    END;
    BEGIN
      SELECT ffv.description -- prepaid exp conc seg
        INTO l_default_conc_seg
        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
       WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
         AND ffvs.flex_value_set_name = l_deferred_expense_account_vs
         AND ffv.flex_value = 'O' || l_coa_id; --    03/12/13 Ofer Suad        Cahnge logic of defualt acount to support new COA
    
    EXCEPTION
      WHEN no_data_found THEN
        -- no default exist --> error
        dbms_output.put_line('could not find default prepaid acct in value set: ' ||
                             l_deferred_expense_account_vs);
      WHEN OTHERS THEN
        dbms_output.put_line('others exception in initialize default expense: ' ||
                             SQLERRM);
    END;
  
    -- get number of segments
    BEGIN
    
      SELECT COUNT(*)
        INTO l_num_seg
        FROM fnd_id_flex_segments
       WHERE application_id = 101 --GL
         AND id_flex_code = 'GL#' --v_id_flex_code
         AND id_flex_num = l_coa_id --v_id_flex_num
      ;
    
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('others exception in getting number of segments ' ||
                             SQLERRM);
      
    END;
  
    -- 2. get the ccid for this default combination
    BEGIN
    
      -- call function to break the segments an array
      l_num_seg := fnd_flex_ext.breakup_segments(concatenated_segs => l_default_conc_seg,
                                                 delimiter         => '.',
                                                 segments          => l_flex_seg);
    
      IF l_num_seg < 1 THEN
        -- error
        dbms_output.put_line('exception in getting breakup seg ' ||
                             SQLERRM);
        RETURN NULL;
      END IF;
    
      -- get the default combination id
      l_ok := fnd_flex_ext.get_combination_id(application_short_name => 'SQLGL',
                                              key_flex_code          => 'GL#',
                                              structure_number       => l_coa_id, -- COA ID
                                              validation_date        => SYSDATE,
                                              n_segments             => l_num_seg, --10,
                                              segments               => l_flex_seg,
                                              combination_id         => l_default_ccid);
    
      -- return default if error
      IF l_ok = FALSE THEN
        l_return_ccid := l_default_ccid;
        dbms_output.put_line('step 2 some error in get_combination_id - use default account');
      ELSE
        dbms_output.put_line('step 2 got default prepaid expense ccid: ' ||
                             l_return_ccid);
      END IF;
    
    END;
  
    /*
          SELECT GLCC.code_combination_id
            INTO l_default_CCID
            FROM gl_code_combinations_kfv GLCC
           WHERE GLCC.concatenated_segments = l_default_CONC_SEG
           ;
    
           EXCEPTION
            WHEN NO_DATA_FOUND THEN
               -- no ccid exists --> error
               dbms_output.put_line ('could not find ccid for conc seg: ' ||l_default_CONC_SEG );
             WHEN OTHERS THEN
              dbms_output.put_line ('others exception in get ccid for def combination: ' || SQLERRM);
       END;
    */
    -- 3. populate the segments for this ccid
    l_default_prepaid_acct := l_flex_seg(3);
    /*
    BEGIN
      SELECT GLCC.segment2,
             GLCC.segment1,
             GLCC.segment2,
             GLCC.segment3,
             GLCC.segment4,
             GLCC.segment5,
             GLCC.segment6,
             GLCC.segment7,
             GLCC.segment8,
             GLCC.segment9,
             GLCC.segment10
        INTO l_default_prepaid_acct,
             l_flex_seg(1),
             l_flex_seg(2),
             l_flex_seg(3),
             l_flex_seg(4),
             l_flex_seg(5),
             l_flex_seg(6),
             l_flex_seg(7),
             l_flex_seg(8),
             l_flex_seg(9),
             l_flex_seg(10)
        FROM GL_CODE_COMBINATIONS_KFV GLCC
       WHERE GLCC.code_combination_id = l_default_CCID
       ;
    
       EXCEPTION
         WHEN OTHERS THEN
           dbms_output.put_line ('general error in default comb: ' || sqlerrm);
     END;
     */
    dbms_output.put_line('defatlt account: ' || l_default_prepaid_acct ||
                         ' default ccid: ' || l_default_ccid);
  
    -- == 2. determine prepaid expense account  ==
    -----------------------------
    -- 1. get expense account from ap invoice distribution line
    BEGIN
      SELECT glcc.segment3, glcc.segment1
        INTO l_inv_dist_expense_account, l_inv_company_segment
        FROM gl_code_combinations glcc
       WHERE glcc.code_combination_id = p_invoice_distribution_account;
    
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('general error in account: ' || SQLERRM);
    END;
  
    dbms_output.put_line('l_inv_dist_expense_account: ' ||
                         l_inv_dist_expense_account);
    dbms_output.put_line('l_inv_company_segment: ' ||
                         l_inv_company_segment);
  
    -- 2. get appropriate Prepaid Expenses account from VS
    BEGIN
      SELECT ffv.description -- prepaid exp account
        INTO l_new_prepaid_acct_number
        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
       WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
         AND ffvs.flex_value_set_name = l_deferred_expense_account_vs
         AND ffv.flex_value = l_inv_dist_expense_account;
    
    EXCEPTION
      WHEN no_data_found THEN
        -- no specific assignment --> use default
        dbms_output.put_line('found explicit prepaid acct: ' ||
                             l_new_prepaid_acct_number);
        l_new_prepaid_acct_number := l_default_prepaid_acct;
      WHEN OTHERS THEN
        dbms_output.put_line('others exception om get equivalent account: ' ||
                             SQLERRM);
    END;
  
    ------------------------
    -- == 3. generate return CCID
    -- finalize return CCID
  
    -- replace account in default combination to get new default KFV + company segment
    l_flex_seg(3) := l_new_prepaid_acct_number;
    l_flex_seg(1) := l_inv_company_segment;
    /*
     -- get COA ID
     BEGIN
        SELECT GLL.chart_of_accounts_id
          INTO l_coa_id
          FROM gl_ledgers GLL,
               hr_operating_units HOU
         WHERE GLL.ledger_id = HOU.set_of_books_id
           and HOU.organization_id = P_ORG_ID
               ;
    
        EXCEPTION
          WHEN OTHERS THEN
              dbms_output.put_line ('others exception in getting COA ID ' || SQLERRM);
     END;
    
     -- get number of segments
     BEGIN
    
        SELECT count(*)
          INTO l_num_seg
          FROM FND_ID_FLEX_SEGMENTS
         WHERE application_id = 101 --GL
           AND id_flex_code = 'GL#' --v_id_flex_code
           AND id_flex_num = l_coa_id   --v_id_flex_num
           ;
    
        EXCEPTION
           WHEN OTHERS THEN
              dbms_output.put_line ('others exception in getting number of segments ' || SQLERRM);
    
     END;
    
    */
    /*  dbms_output.put_line('going to create comb: ' || l_flex_seg(1) || '.' ||
                            l_flex_seg(2) || '.' || l_flex_seg(3) || '.' ||
                            l_flex_seg(4) || '.' || l_flex_seg(5) || '.' ||
                            l_flex_seg(6) || '.' || l_flex_seg(7) || '.' ||
                            l_flex_seg(8));
    */
    -- call API to get new combination
    l_ok := fnd_flex_ext.get_combination_id(application_short_name => 'SQLGL',
                                            key_flex_code          => 'GL#',
                                            structure_number       => l_coa_id, -- COA ID
                                            validation_date        => SYSDATE,
                                            n_segments             => l_num_seg, --10,
                                            segments               => l_flex_seg,
                                            combination_id         => l_return_ccid);
  
    -- return default if error
    IF l_ok = FALSE THEN
      l_return_ccid := l_default_ccid;
      dbms_output.put_line('some error in get_combination_id - use default account');
    ELSE
      dbms_output.put_line('got new default prepaid expense ccid: ' ||
                           l_return_ccid);
    END IF;
  
    ------------------
    -- RETURN
  
    dbms_output.put_line('successfully return value: ' || l_return_ccid);
    RETURN l_return_ccid;
  
  EXCEPTION
    WHEN OTHERS THEN
      -- general exception =- return the default ccid anyway
      dbms_output.put_line('general exception: ' || SQLERRM);
      RETURN l_default_ccid;
    
  END get_default_prepaid_acct;

END xxap_mpa_accounting_pkg;
/
