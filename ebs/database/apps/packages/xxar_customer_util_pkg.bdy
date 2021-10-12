CREATE OR REPLACE PACKAGE BODY xxar_customer_util_pkg AS
--------------------------------------------------------------------
--  name:            xxar_customer_util_pkg
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   03/23/2015
--------------------------------------------------------------------
--  purpose : Package to hold utility functions for manipulating 
--            customers and associated customer entities.
--------------------------------------------------------------------
--  ver  date        name              desc
-- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
--------------------------------------------------------------------
  g_log           VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
  g_log_module    VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_program_unit  VARCHAR2(30);
  g_request_id    NUMBER   := TO_NUMBER(fnd_global.conc_request_id);
  g_user_id       NUMBER   := TO_NUMBER(fnd_profile.value('USER_ID')); 
  g_login_id      NUMBER   := TO_NUMBER(fnd_profile.value('LOGIN_ID')); 
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg  VARCHAR2)
  IS 
  BEGIN
     IF g_log = 'Y' AND 'xxar.customer_util.xxar_customer_util_pkg.'||g_program_unit LIKE LOWER(g_log_module) THEN
        fnd_file.put_line(fnd_file.log,TO_CHAR(SYSDATE,'HH:MI:SS')||' - '||p_msg); 
     END IF;
  END write_log; 

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_output(
    p_msg       VARCHAR2,
    p_col1      VARCHAR2,
    p_col2      VARCHAR2  DEFAULT NULL,
    p_col3      VARCHAR2  DEFAULT NULL    
  )
  IS 
    l_report_row VARCHAR2(2000) := NULL;
  BEGIN
    l_report_row := LPAD(NVL(p_col1,'-'),30,' ')||'  ';
    
    IF p_col2 IS NOT NULL THEN
      l_report_row := l_report_row||LPAD(p_col2,30,' ')||'  ';
    END IF;
    
    IF p_col3 IS NOT NULL THEN
      l_report_row := l_report_row||LPAD(p_col3,30,' ')||'  ';
    END IF;
    
    l_report_row := l_report_row||p_msg;
    
    fnd_file.put_line(fnd_file.output,l_report_row);
  END write_output; 
  
  -- ------------------------------------------------------------------------------------
  -- Purpose: Procedure calling Oracle standard API for updating customers.
  -- ------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
  -- ------------------------------------------------------------------------------------
  PROCEDURE update_customer_account(
    p_cust_account_rec      IN  HZ_CUST_ACCOUNT_V2PUB.CUST_ACCOUNT_REC_TYPE,
    p_object_version_number IN  hz_cust_accounts_all.object_version_number%TYPE,
    x_return_status         OUT VARCHAR2,
    x_return_msg            OUT VARCHAR2
  )
  IS
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000); 
    l_object_version_number hz_cust_accounts_all.object_version_number%TYPE := p_object_version_number;
    --l_error_msg             VARCHAR2(2000); 
  BEGIN
    g_program_unit := 'UPDATE_CUSTOMER_ACCOUNT';
    write_log('START '||g_program_unit);
    write_log('cust_account_id: '||p_cust_account_rec.cust_account_id);
    
    hz_cust_account_v2pub.update_cust_account(
      p_init_msg_list         => FND_API.G_TRUE,
      p_cust_account_rec      => p_cust_account_rec,
      p_object_version_number => l_object_version_number,
      x_return_status         => x_return_status,
      x_msg_count             => x_msg_count,
      x_msg_data              => x_msg_data
    );

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      FOR i IN 1 .. x_msg_count
      LOOP
        x_msg_data := fnd_msg_pub.get(p_msg_index => i, p_encoded => 'F');
        IF x_return_msg IS NULL THEN
          x_return_msg := x_msg_data;
        ELSE
          x_return_msg := x_return_msg || ' ' || x_msg_data;
        END IF;
      END LOOP; 
    END IF;
    
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in update_customer_account: '||DBMS_UTILITY.FORMAT_ERROR_STACK;    
  END update_customer_account;
 
  -- ------------------------------------------------------------------------------------
  -- Purpose: Main procedure called to inactivate customers.
  -- ------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
  -- ------------------------------------------------------------------------------------
  PROCEDURE inactivate_customers(
    errbuff         OUT VARCHAR2,
    retcode         OUT NUMBER,
    p_batch_name    IN  VARCHAR2,
    p_file_location IN  VARCHAR2,
    p_file_name     IN  VARCHAR2
  )
  IS
    CURSOR c_cust 
    IS
      SELECT 
        hca.cust_account_id             cust_account_id,
        xcu.trx_identifier              account_number,
        hca.object_version_number       object_version_number,
        hca.status                      account_status,
        hp.party_name                   customer_name,
        open_ar.open_ar                 open_ar,
        xcu.status                      status
      FROM
        xxar_customer_util              xcu,
        hz_cust_accounts                hca,
        hz_parties                      hp,  
      /* open_ar... */
       (SELECT 
          SUM(
            DECODE(invoice_currency_code,  
              'USD',  amount_due_remaining,
              amount_due_remaining *  gl_currency_api.get_closest_rate(
                                        invoice_currency_code,
                                        'USD',
                                        SYSDATE,
                                        'Corporate',
                                        100
                                      )
            )
          )                   open_ar,
          customer_id         customer_id
        FROM 
            ar_payment_schedules_all      apsa
        GROUP BY apsa.customer_id)                   
                                  open_ar
      /* ...open_ar */  
      WHERE xcu.batch_name      = p_batch_name
      AND   xcu.trx_identifier  = hca.account_number (+)
      AND   hca.party_id        = hp.party_id (+)
      AND   hca.cust_account_id = open_ar.customer_id (+)
      FOR UPDATE OF xcu.status NOWAIT;

    l_cust_account_rec      HZ_CUST_ACCOUNT_V2PUB.CUST_ACCOUNT_REC_TYPE;
    l_object_version_number NUMBER;

    x_return_status         VARCHAR2(2000);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);

    l_return_status         VARCHAR2(1);
    l_return_msg            VARCHAR2(2000);
    l_retcode               NUMBER;
    l_error_flag            VARCHAR2(1) := 'N';
    l_success_recs          NUMBER      := 0;
    l_error_recs            NUMBER      := 0;
    
    e_error                 EXCEPTION;
    
  BEGIN
    g_program_unit := 'INACTIVATE_CUSTOMERS';
    write_log('START '||g_program_unit);

    DELETE FROM xxar_customer_util
    WHERE batch_name = p_batch_name;
    
    write_log(SQL%ROWCOUNT||' Records deleted for batch name '||p_batch_name);
    
    xxobjt_table_loader_util_pkg.load_file(
      errbuf                  => l_return_msg,
      retcode                 => l_retcode,
      p_table_name            => 'XXAR_CUSTOMER_UTIL',
      p_template_name         => 'INACTIVATE_ACCOUNTS',
      p_file_name             => p_file_name,
      p_directory             => p_file_location, 
      p_expected_num_of_rows  => TO_NUMBER(NULL)
    );  

    IF l_retcode <> 0 THEN
      RAISE e_error;
    END IF;

    -- Write output headers    
    fnd_file.put_line(fnd_file.output,LPAD('Customer Account',30,' ')||'  '||LPAD('Customer Name',30,' ')||'  '||'Message');
    fnd_file.put_line(fnd_file.output,LPAD('-',30,'-')||'  '||LPAD('-',30,'-')||'  '||LPAD('-',100,'-'));
    
    FOR rec IN c_cust LOOP
      BEGIN
        l_return_status := 'S';
        
        IF rec.cust_account_id IS NULL THEN
          l_return_msg := 'No Customer exists for this account number';
          RAISE e_error;
        END IF;

        IF rec.account_status = 'I' THEN
          l_return_msg := 'Customer is already inactive';
          RAISE e_error;
        END IF;
        
        IF rec.open_ar <> 0 THEN
          l_return_msg := 'Customer has Open AR in the amount of: '||rec.open_ar;
          RAISE e_error;        
        END IF;

        l_cust_account_rec.cust_account_id  := rec.cust_account_id;
        l_cust_account_rec.status           := 'I'; -- Inactive 
        l_object_version_number             := rec.object_version_number;
        
        update_customer_account(
          p_cust_account_rec      => l_cust_account_rec,
          p_object_version_number => l_object_version_number,
          x_return_status         => l_return_status,
          x_return_msg            => l_return_msg
        );        
      
        IF l_return_status <> 'S' THEN
          RAISE e_error;
        ELSE
          l_success_recs := l_success_recs + 1;
          
          UPDATE xxar_customer_util
          SET 
            status            = 'S',
            last_updated_by   = g_user_id,
            last_update_date  = SYSDATE,
            last_update_login = g_login_id,
            request_id        = g_request_id
          WHERE CURRENT OF c_cust;
        
        END IF;
      EXCEPTION 
        WHEN e_error THEN
          l_return_status := 'E';
        WHEN OTHERS THEN 
          l_return_status := 'E';
          l_return_msg    := 'Unexpected error in c_cust CURSOR: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      END; 
      
      -- If error condition occurred, write output
      IF l_return_status <> 'S' THEN
          l_error_flag := 'Y';
          l_error_recs := l_error_recs + 1;
          
          write_output(
            p_msg       => l_return_msg,
            p_col1      => rec.account_number,
            p_col2      => NVL(rec.customer_name,'-')
          );  
          
          UPDATE xxar_customer_util
          SET 
            status            = 'E',
            last_updated_by   = g_user_id,
            last_update_date  = SYSDATE,
            last_update_login = g_login_id,            
            request_id        = g_request_id
          WHERE CURRENT OF c_cust;          
      END IF;
    END LOOP;  
    
    IF l_error_flag = 'Y' THEN
      retcode := 1;
    END IF;
    
    -- Write totals
    fnd_file.put_line(fnd_file.output,'Record Totals');
    fnd_file.put_line(fnd_file.output,'***********************');
    fnd_file.put_line(fnd_file.output,'Success Records: '||l_success_recs);
    fnd_file.put_line(fnd_file.output,'Error Records  : '||l_error_recs);
    
    
    write_log('END '||g_program_unit); 
  END inactivate_customers;

END xxar_customer_util_pkg;
/

SHOW ERRORS