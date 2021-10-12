CREATE OR REPLACE PACKAGE BODY xxssus_cogs_expense_reclass AS

FUNCTION before_report_trigger RETURN BOOLEAN
IS
  l_flex_value_set_id NUMBER;
BEGIN
  fnd_file.put_line(fnd_file.log,'Executing before report trigger');

  select flex_value_set_id 
    into l_flex_value_set_id
    from fnd_flex_value_sets
   where flex_value_set_name like 'XXGL_ACCOUNT_SS';
    
  arp_recon_rep.get_detail_accounts
  ( p_value_set_id      => l_flex_value_set_id
  , p_parent_value      => '501015'
  , p_code_combinations => g_accounts
  ) ; 
  
  
  IF P_DRAFT_MODE = 'NO'
  THEN
     g_data_access_set_id := fnd_profile.value('GL_ACCESS_SET_ID');
     g_ledger_id          := gl_access_set_security_pkg.get_default_ledger_id(g_data_access_set_id, 'R');

    SELECT gl_interface_control_s.NEXTVAL
       INTO g_group_id
       FROM DUAL;

     /*gl_journal_import_pkg.populate_interface_control 
     ( user_je_source_name   => g_je_source_name
     , GROUP_ID              => g_group_id
     , set_of_books_id       => g_ledger_id
     , interface_run_id      => g_interface_id
     , table_name            => 'GL_INTERFACE'
     , processed_data_action => 'D'
     ) ; */

     fnd_file.put_line(fnd_file.log, 'Data Access Set Id = ' || g_data_access_set_id );
     fnd_file.put_line(fnd_file.log, 'Ledger ID          = ' || g_ledger_id          );
     fnd_file.put_line(fnd_file.log, 'Group ID           = ' || g_group_id           );
     fnd_file.put_line(fnd_file.log, 'Interface Run ID   = ' || g_interface_id       );
     fnd_file.put_line(fnd_file.log, 'JE Source Name     = ' || g_je_source_name     );
     fnd_file.put_line(fnd_file.log, 'Btch Name          = ' || P_BATCH_NAME         );
     fnd_file.put_line(fnd_file.log, 'Draft Mode         = ' || p_draft_mode         ); 

     
  END IF;
  fnd_file.put_line(fnd_file.log, 'G_ACCOUNTS         = ' || g_accounts            );

  return true;
END;
--
--
--
FUNCTION after_report_trigger RETURN BOOLEAN IS
  l_request_id NUMBER;
BEGIN
     IF p_draft_mode = 'YES'
      THEN
         -- in draft mode, we do not submit import Journals...
         return true;
      END IF;
     l_request_id := apps.fnd_request.submit_request
                     ( application  => 'SQLGL'
                     , program      => 'GLLEZLSRS'
                     , description  => NULL
                     , start_time   => NULL
                     , sub_request  => FALSE
                     , argument1    => g_data_access_set_id
                     , argument2    => g_je_source_name
                     , argument3    => g_ledger_id
                     , argument4    => g_group_id
                     , argument5    => 'N'
                     , argument6    => 'N'
                     , argument7    => 'Y'
                     , argument8    => fnd_global.local_chr(0)
                     ) ;
     commit;
     fnd_file.put_line(fnd_file.log, 'Request Id = ' || l_request_id);
     return true;
END;
--
--
FUNCTION insert_into_gl_intf
( p_ledger_id              NUMBER
, p_currency_code          VARCHAR2
, p_segment1               VARCHAR2
, p_segment2               VARCHAR2
, p_segment3               VARCHAR2
, p_segment5               VARCHAR2
, p_segment5_rev           VARCHAR2
, p_segment6               VARCHAR2
, p_segment7               VARCHAR2
, p_segment10              VARCHAR2
, p_segment9               VARCHAR2
, p_trxn_value             NUMBER
, p_je_ref     /* reference10 */             VARCHAR2
, p_mtl_trxn_id            NUMBER
, p_acct_date              VARCHAR2
) RETURN BOOLEAN IS

BEGIN


     IF p_draft_mode = 'YES'
      THEN
         return true;
      END IF;

      insert into gl_interface
      (  status,
                    ledger_id,
                    user_je_source_name,
                    user_je_category_name,
                    accounting_date,
                    currency_code,
                    date_created,
                    created_by,
                    actual_flag,
                    segment1,
                    segment2,
                    segment3,
                    segment5,
                    segment6,
                    segment7,
                    segment10,
                    segment9,
                    entered_dr,
                    entered_cr,
                    group_id,
                    reference1,
                    reference2,
                    reference6,
                    reference10
      )
      values
      ( 'NEW'
      , p_ledger_id
      , 'Inventory'
      , 'Inventory'
      , to_date(p_acct_date,'YYYY/MM/DD')
      , 'USD'
      , trunc(sysdate)
      ,  fnd_global.user_id
      , 'A'
      , p_segment1
      , p_segment2
      , p_segment3
      , p_segment5
      , p_segment6
      , p_segment7
      , p_segment10
      , p_segment9
      , p_Trxn_Value
      , 0
      , G_group_id
      , P_BATCH_NAME
      , P_BATCH_DESC
      , substr(p_je_ref,1,100)
      , p_je_ref
      );
      insert into gl_interface
      (  status,
                    ledger_id,
                    user_je_source_name,
                    user_je_category_name,
                    accounting_date,
                    currency_code,
                    date_created,
                    created_by,
                    actual_flag,
                    segment1,
                    segment2,
                    segment3,
                    segment5,
                    segment6,
                    segment7,
                    segment10,
                    segment9,
                    entered_dr,
                    entered_cr,
                    group_id,
                    reference1,
                    reference2,
                    reference6,
                    reference10
      )
      values
      ( 'NEW'
      , p_ledger_id
      , 'Inventory'
      , 'Inventory'
      , to_date(p_acct_date,'YYYY/MM/DD')
      , 'USD'
      , trunc(sysdate)
      , fnd_global.user_id
      , 'A'
      , p_segment1
      , p_segment2
      , p_segment3
      , p_segment5_rev
      , p_segment6
      , p_segment7
      , p_segment10
      , p_segment9
      , 0
      , p_Trxn_Value
      , G_group_id
      , P_BATCH_NAME
      , P_BATCH_DESC
      , substr(p_je_ref,1,100)
      , p_je_ref
      );      
      
      update mtl_material_transactions
        set attribute15 = fnd_global.conc_request_id
        where transaction_id = p_mtl_trxn_id
        ;
      return true;
END ;
--
-- End of Package body
--  
END;
/
show errors
quit
