CREATE OR REPLACE PACKAGE BODY xxpa_concur_interface_pkg AS
-- ---------------------------------------------------------------------------------------------
-- Name: xxpa_concur_interface_pkg   
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used to take 'Concur' sourced GL lines and create entries for them
--          in pa_transaction_interface_all.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033409.
-- ---------------------------------------------------------------------------------------------
g_log VARCHAR2(10) := fnd_profile.value('AFLOG_ENABLED');

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033409.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE write_log(p_msg  VARCHAR2)
   IS 
   BEGIN
      IF g_log = 'Y' THEN
         fnd_file.put_line(fnd_file.log,p_msg); 
      END IF;
   END write_log; 
   
-- --------------------------------------------------------------------------------------------
-- Purpose: Updates reference_3 with request_id for program run.  This is updated to flag that
--          we have already pulled this record into pa_transaction_interface_all.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033409.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE update_gl_je_lines(
     p_gl_header_id       IN    NUMBER,
     p_gl_line_num        IN    NUMBER,
     p_request_id         IN    NUMBER,
     x_return_message     OUT   VARCHAR2,
     x_return_status      OUT   VARCHAR2
   )
   IS 
      CURSOR c_update
      IS
         SELECT 
            reference_3
         FROM gl_je_lines
         WHERE je_header_id   = p_gl_header_id
         AND   je_line_num    = p_gl_line_num
         FOR UPDATE OF reference_3 NOWAIT;
   BEGIN
      write_log('In update_gl_ge_lines for je_header_id: '||p_gl_header_id||' je_line_num: '||p_gl_line_num);
      
      FOR rec IN c_update LOOP
         UPDATE gl_je_lines
         SET reference_3 = TO_CHAR(p_request_id)
         WHERE CURRENT OF c_update;
      END LOOP;
      
      x_return_status := 'S';
   EXCEPTION 
      WHEN OTHERS THEN 
         write_log('Error in update_gl_ge_lines for je_header_id: '||p_gl_header_id||' je_line_num: '||p_gl_line_num);
         x_return_status   := 'E';                 
         x_return_message  := 'Error in update_gl_ge_lines '||DBMS_UTILITY.FORMAT_ERROR_STACK;
   END update_gl_je_lines;

-- --------------------------------------------------------------------------------------------
-- Purpose: This procedure is used to take 'Concur' sourced GL lines and create entries for them
--          in pa_transaction_interface_all based on the criteria specified in the c_rec
--          CURSOR.  After data has been entered into pa_transaction_interface_all, we 
--          update the record on gl_je_lines to identify it as a record that has already 
--          been pulled.  The program will COMMIT after INSERT and UPDATE have taken place.
--          If either errors, the record will be rolled back and reported in the concurrent 
--          program output.  
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033409.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE process_rows(                          
     x_errbuff                     OUT   VARCHAR2,     
     x_retcode                     OUT   VARCHAR2,     
     p_org_id                      IN    NUMBER,
     p_dep_org_id                  IN    NUMBER,
     p_gl_ledger_id                IN    NUMBER,
     p_cap_acct                    IN    VARCHAR2,     
     p_non_trade_exp_acct          IN    VARCHAR2,     
     p_trade_exp_acct              IN    VARCHAR2
   )
   IS
      CURSOR c_rec
      IS
         SELECT                                                                                     
           gjh.doc_sequence_value                                batch_name,
           gjl.je_header_id ||'-'||gjl.je_line_num               orig_transaction_reference,
           gjl.je_header_id                                      gl_header_id,
           gjl.je_line_num                                       gl_line_num,
           gcc.segment1                                          gl_segment1,
           gjl.reference_1                                       project_number,
           CASE
             -- If reference_2 is not all zeroes or NULL...
             WHEN REGEXP_REPLACE(gjl.reference_2,'[0]+','0') <> '0' 
             THEN  
                gjl.reference_2
             ELSE  NULL
           END                                                   task_number,                            
           NVL(gjl.accounted_dr, 0) - NVL(gjl.accounted_cr,0)    quantity,
           gjl.effective_date                                    gl_effective_date,
           gjl.reference_3                                       gl_line_reference_3,
           hou.organization_id                                   org_id,
           haou.name                                             dept_name,
           CASE
              WHEN project_tasks.billable_flag = 'N' AND project_tasks.project_type <> 'Trade Show' THEN --26.655.699999.000.000.00.000.0000  
                p_non_trade_exp_acct
              WHEN project_tasks.billable_flag = 'N' AND project_tasks.project_type = 'Trade Show' THEN --26.000.699999.000.000.00.000.0000
                p_trade_exp_acct
              ELSE
                p_cap_acct
           END                                                   gl_account
         FROM 
           gl_je_lines                gjl,
           gl_je_headers              gjh,
           gl_je_sources              gjs,     
           gl_code_combinations       gcc,
           hr_all_organization_units  haou,           
           hr_operating_units         hou,
         -- Inline view gets projects and tasks.
         /* project_tasks... */
          (SELECT
              ppa.segment1         project_number,
              pt.task_number       task_number,
              pt.billable_flag     billable_flag,
              ppt.project_type     project_type,
              -- Used to check for more than one task per project
              COUNT(*) OVER (PARTITION BY ppa.project_id) 
                                    ct,
              -- Used in join condition to this inline view to get
              -- only one task per project
              ROW_NUMBER() OVER (PARTITION BY ppa.project_id
                                  ORDER BY pt.task_id)
                                    rn
              FROM
                pa_projects_all        ppa,
                pa_tasks               pt,
                pa_project_types_all   ppt
              WHERE ppa.project_id    = pt.project_id
              AND   ppa.project_type  = ppt.project_type
           )                          project_tasks
         /* ...project_tasks */
         WHERE gjh.ledger_id              = p_gl_ledger_id
         AND   gjh.je_header_id           = gjl.je_header_id
         AND   gjl.code_combination_id    = gcc.code_combination_id
         --And h.status = 'P'
         AND   gjh.je_source              = gjs.je_source_name
         AND   gjs.user_je_source_name    = 'Concur'
         -- Project number exists
         AND   gjl.reference_1            IS NOT NULL 
         -- Project number is not zero (could be multiple zeroes)
         AND   REGEXP_REPLACE(gjl.reference_1,'[0]+','0')
                                          <> '0' 
         -- Not previously processed
         AND   gjl.reference_3            IS NULL
         -- Get org values
         AND   gjh.ledger_id              = hou.set_of_books_id
         AND   hou.organization_id        = p_org_id
         AND   haou.organization_id       = p_dep_org_id
         -- Get project values
         AND   gjl.reference_1            = project_tasks.project_number (+)
         -- Get one project, since project_tasks is at the task level
         AND   1                          = project_tasks.rn(+);
         
      l_transaction_source       pa_transaction_interface_all.transaction_source%TYPE        := 'Concur';
      l_system_linkage           pa_transaction_interface_all.system_linkage%TYPE            := 'PJ';
      l_expenditure_item_date    pa_transaction_interface_all.expenditure_item_date%TYPE     := SYSDATE;
      l_expenditure_ending_date  pa_transaction_interface_all.expenditure_ending_date%TYPE   := NEXT_DAY(SYSDATE,'Sunday');
      l_expenditure_type         pa_transaction_interface_all.expenditure_type%TYPE          := 'Other Expense';
      l_transaction_status_code  pa_transaction_interface_all.transaction_status_code%TYPE   := 'P';
      l_expenditure_comment      pa_transaction_interface_all.expenditure_comment%TYPE       := 'Pcard'; 
      
      l_success_ct               NUMBER         := 0;
      l_error_ct                 NUMBER         := 0;
      l_error_flag               VARCHAR2(1)    := 'N';
      l_msg                      VARCHAR2(200);  
      l_request_id               NUMBER         := fnd_profile.value('CONC_REQUEST_ID');
      l_created_by               pa_transaction_interface_all.created_by%TYPE                   := TO_NUMBER(fnd_profile.value('USER_ID'));
      
      e_error                    EXCEPTION;
   BEGIN 
      write_log('BEGIN process_rows');
      
      FOR rec IN c_rec LOOP
         l_msg          := NULL;
         l_error_flag   := NULL;
         
         BEGIN
            write_log('Inserting orig_transaction_reference '||rec.orig_transaction_reference);
            INSERT INTO pa_transaction_interface_all(
               batch_name
            ,  orig_transaction_reference
            ,  transaction_source
            ,  system_linkage
            ,  expenditure_item_date
            ,  expenditure_ending_date
            ,  project_number
            ,  task_number
            ,  expenditure_type
            ,  quantity
            ,  org_id
            ,  organization_name
            ,  transaction_status_code
            ,  expenditure_comment
            ,  gl_date
            ,  attribute1
            ,  attribute2
            ,  attribute3
            ,  attribute4
            ,  attribute5
            ,  attribute6
            ,  attribute7
            ,  attribute8
            ,  creation_date
            ,  created_by
            ,  last_update_date
            ,  last_updated_by
            )
            VALUES(
               rec.batch_name                                        
            ,  rec.orig_transaction_reference                        
            ,  l_transaction_source                                
            ,  l_system_linkage                                      
            ,  l_expenditure_item_date                               
            ,  l_expenditure_ending_date                             
            ,  rec.project_number                                    
            ,  rec.task_number                                       
            ,  l_expenditure_type                                    
            ,  rec.quantity                                          
            ,  rec.org_id                                            
            ,  rec.dept_name                                         
            ,  l_transaction_status_code                             
            ,  l_expenditure_comment                                 
            ,  rec.gl_effective_date  
            -- Parses apart gl_account.  Last number says to get the nth value after '.'
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,1)                                       
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,2)                  
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,3)                                       
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,4)                                   
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,5)                                         
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,6)                                          
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,7)                                       
            ,  REGEXP_SUBSTR (rec.gl_account, '[^' || '.' || ']+', 1,8)
            ,  SYSDATE
            ,  l_created_by
            ,  SYSDATE
            ,  l_created_by
            );
            
            write_log('Updating orig_transaction_reference '||rec.orig_transaction_reference);

            update_gl_je_lines(
               p_gl_header_id       => rec.gl_header_id
            ,  p_gl_line_num        => rec.gl_line_num
            ,  p_request_id         => l_request_id
            ,  x_return_message     => l_msg
            ,  x_return_status      => l_error_flag
            );

            write_log('update_gl_je_lines return status: '||l_error_flag);

            IF l_error_flag = 'E' THEN
               RAISE e_error;
            END IF;
            l_success_ct := l_success_ct + 1;
         EXCEPTION
            WHEN e_error THEN
               -- Just need to handle.  Message has already been set.
               NULL;  
            WHEN OTHERS THEN               
               l_error_flag   := 'E';               
               l_msg          := DBMS_UTILITY.FORMAT_ERROR_STACK;
         END;
         IF l_error_flag = 'E' THEN
            l_error_ct := l_error_ct + 1;
            IF l_error_ct = 1 THEN
               fnd_file.put_line(fnd_file.output,'Original Transaction Reference  Error Message');
               fnd_file.put_line(fnd_file.output,'------------------------------  '||RPAD('-',100,'-'));
            END IF;
            
            ROLLBACK;
            write_log('Error occurred with orig_transaction_reference '||rec.orig_transaction_reference);
            fnd_file.put_line(fnd_file.output,LPAD(rec.orig_transaction_reference,30,' ')||'  '||l_msg); 
         ELSE
            COMMIT;         
         END IF;

      END LOOP;
      
      IF l_error_ct > 0 THEN
         x_retcode := 1;    
      END IF;
      
      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output,'Record Totals');
      fnd_file.put_line(fnd_file.output,'**********************');
      fnd_file.put_line(fnd_file.output,'Success Total: '||l_success_ct);
      fnd_file.put_line(fnd_file.output,'Error Total  : '||l_error_ct);
   EXCEPTION 
      WHEN e_error THEN
         fnd_file.put_line(fnd_file.output,l_msg);
         x_retcode := 2; 
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.output,'*** Unexpected Error Occurred '||DBMS_UTILITY.FORMAT_ERROR_STACK|| ' ***');
         x_retcode := 2;          
   END process_rows;

END xxpa_concur_interface_pkg;
/

SHOW ERRORS