CREATE OR REPLACE PACKAGE xxs3_ptm_kanban_pull_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Subinventories Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE kanban_pull_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER);

  PROCEDURE quality_check_kanban(p_err_code OUT VARCHAR2
                                ,p_err_msg  OUT VARCHAR2);

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  PROCEDURE kanban_report_data(p_entity_name IN VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_ptm_kanban_pull_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxs3_ptm_kanban_pull_pkg AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,p_msg);
    /*dbms_output.put_line(i_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Error in writting Log File. ' || SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output
                     ,p_msg);
    /*dbms_output.put_line(p_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Error in writting Output File. ' || SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE kanban_report_data(p_entity_name IN VARCHAR2) AS
  
    CURSOR c_kanban_dq_report IS
      SELECT nvl(xpd.rule_name
                ,' ') rule_name
            ,nvl(xpd.notes
                ,' ') notes
            ,xps.xx_kb_pull_sq_id
            ,xps.pull_sequence_id
            ,xps.inventory_item_name
            ,xps.subinventory_name
            ,xps.locator_id
            ,xps.locator_name
            ,xps.kanban_size
            ,xps.number_of_cards
            ,decode(xps.process_flag
                   ,'R'
                   ,'Y'
                   ,'Q'
                   ,'N') reject_record
      FROM xxs3_ptm_kanban_pullseq    xps
          ,xxs3_ptm_kanban_pullseq_dq xpd
      WHERE xps.xx_kb_pull_sq_id = xpd.xx_kb_pull_sq_id
      AND xps.process_flag IN ('Q', 'R')
      ORDER BY 1;
  
    p_delimiter    VARCHAR2(5) := '~';
    l_count_dq     NUMBER := 0;
    l_count_reject NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_ptm_kanban_pullseq xpkp
    WHERE xpkp.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_ptm_kanban_pullseq xpkp
    WHERE xpkp.process_flag = 'R';
  
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('========================================' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity_name ||
               p_delimiter
              ,100
              ,' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE
                      ,'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_count_dq ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_count_reject ||
               p_delimiter
              ,100
              ,' '));
  
    out_p('');
  
    out_p(rpad('Track Name'
              ,15
              ,' ') || p_delimiter ||
          rpad('Entity Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('XX KANBAN PULL SEQ ID  '
              ,30
              ,' ') || p_delimiter ||
          rpad('Kanban Pull Sequence Id'
              ,30
              ,' ') || p_delimiter ||
          rpad('Inventory Item Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Subinventory Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('LOCATOR ID'
              ,25
              ,' ') || p_delimiter ||
          rpad('LOCATOR NAME'
              ,25
              ,' ') || p_delimiter ||
          rpad('KANBAN SIZE'
              ,25
              ,' ') || p_delimiter ||
          rpad('NUMBER OF CARDS'
              ,25
              ,' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)'
              ,25
              ,' ') || p_delimiter ||
          rpad('Rule Name'
              ,50
              ,' ') || p_delimiter ||
          rpad('Reason Code'
              ,50
              ,' '));
  
    FOR i IN c_kanban_dq_report
    LOOP
      out_p(rpad('PTM'
                ,15
                ,' ') || p_delimiter ||
            rpad('KANBAN PULL SEQUENCE'
                ,30
                ,' ') || p_delimiter ||
            rpad(i.xx_kb_pull_sq_id
                ,15
                ,' ') || p_delimiter ||
            rpad(i.pull_sequence_id
                ,30
                ,' ') || p_delimiter ||
            rpad(i.inventory_item_name
                ,30
                ,' ') || p_delimiter ||
            rpad(i.subinventory_name
                ,30
                ,' ') || p_delimiter ||
            rpad(i.locator_id
                ,25
                ,' ') || p_delimiter ||
            rpad(i.locator_name
                ,25
                ,' ') || p_delimiter ||
            rpad(i.kanban_size
                ,25
                ,' ') || p_delimiter ||
            rpad(i.number_of_cards
                ,25
                ,' ') || p_delimiter ||
            rpad(i.reject_record
                ,20
                ,' ') || p_delimiter ||
            rpad(i.rule_name
                ,200
                ,' ') || p_delimiter ||
            rpad(i.notes
                ,2000
                ,' '));
    
    END LOOP;
    -- p_err_code := '0';
    --  p_err_msg := '';
  EXCEPTION
    WHEN OTHERS THEN
      -- p_err_code := '2';
      --  p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END kanban_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to Cleansing data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_data_kanban_pull(p_errbuf  OUT VARCHAR2
                                    ,p_retcode OUT NUMBER) AS
  
    l_status      VARCHAR2(10) := 'SUCCESS';
    l_check_rule  VARCHAR2(10) := 'TRUE';
    l_err_message VARCHAR2(2000);
  
    CURSOR cur_kanban IS
      SELECT * FROM xxobjt.xxs3_ptm_kanban_pullseq;
  
  BEGIN
    l_check_rule := 'TRUE';
  
    FOR i IN cur_kanban
    LOOP
    
      ---------------------------- Cleanse Source Subinventory-----------------------------------
      IF i.source_type <> 2
      THEN
      
        BEGIN
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_source_subinventory = 'STORES'
             ,cleanse_status         = decode(cleanse_status
                                             ,'FAIL'
                                             ,'FAIL'
                                             ,'PASS')
          --cleanse_status ||
          --                       'SOURCE SUBINVENTORY :PASS, '
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_err_message := SQLERRM;
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET cleanse_status = 'FAIL'
               , --cleanse_status ||
                --' SOURCE SUBINVENTORY :FAIL, ',
                cleanse_error = cleanse_error || ' SOURCE SUBINVENTORY :' ||
                                l_err_message || ' ,'
            WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
          
        END;
      
      ELSE
      
        BEGIN
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_source_subinventory = NULL
             ,cleanse_status         = decode(cleanse_status
                                             ,'FAIL'
                                             ,'FAIL'
                                             ,'PASS') --cleanse_status ||
          -- 'SOURCE SUBINVENTORY :PASS, '
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_err_message := SQLERRM;
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET cleanse_status = 'FAIL'
               , --cleanse_status ||
                --' SOURCE SUBINVENTORY :FAIL, ',
                cleanse_error = cleanse_error || ' SOURCE SUBINVENTORY :' ||
                                l_err_message || ' ,'
            WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
          
        END;
      
      END IF;
      ---------------------------- Cleanse Source Locator id---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_source_locator_id = NULL
           ,cleanse_status       = decode(cleanse_status
                                         ,'FAIL'
                                         ,'FAIL'
                                         ,'PASS') --cleanse_status ||
        --' SOURCE LOCATOR ID :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' SOURCE LOCATOR ID :FAIL, ',
              cleanse_error = cleanse_error || ' SOURCE LOCATOR ID :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source WIP Line id---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_wip_line_code = NULL
           ,cleanse_status   = decode(cleanse_status
                                     ,'FAIL'
                                     ,'FAIL'
                                     ,'PASS') --cleanse_status || ' WIP LINE CODE :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' WIP LINE CODE  :FAIL, ',
              cleanse_error = cleanse_error || ' WIP LINE CODE  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source REPLENISHMENT LEAD TIME---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_replenishment_lead_time = NULL
           ,cleanse_status             = decode(cleanse_status
                                               ,'FAIL'
                                               ,'FAIL'
                                               ,'PASS') --cleanse_status ||
        --' REPLENISHMENT LEAD TIME :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' REPLENISHMENT LEAD TIME  :FAIL, ',
              cleanse_error = cleanse_error || ' REPLENISHMENT LEAD TIME  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source Calculate Kanban Flag---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_calculate_kanban_flag = 3
           ,cleanse_status           = decode(cleanse_status
                                             ,'FAIL'
                                             ,'FAIL'
                                             ,'PASS') --cleanse_status ||
        --' CALCULATE KANBAN FLAG :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' CALCULATE KANBAN FLAG  :FAIL, ',
              cleanse_error = cleanse_error || ' CALCULATE KANBAN FLAG  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source FIXED_LOT_MULTIPLIER---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_fixed_lot_multiplier = NULL
           ,cleanse_status          = decode(cleanse_status
                                            ,'FAIL'
                                            ,'FAIL'
                                            ,'PASS') --cleanse_status ||
        --' FIXED_LOT_MULTIPLIER :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' FIXED_LOT_MULTIPLIER  :FAIL, ',
              cleanse_error = cleanse_error || ' FIXED_LOT_MULTIPLIER  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source SAFETY STOCK DAYS---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_safety_stock_days = NULL
           ,cleanse_status       = decode(cleanse_status
                                         ,'FAIL'
                                         ,'FAIL'
                                         ,'PASS') --cleanse_status ||
        --' SAFETY STOCK DAYS :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' SAFETY STOCK DAYS  :FAIL, ',
              cleanse_error = cleanse_error || ' SAFETY STOCK DAYS  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source MINIMUM_ORDER_QUANTITY---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_minimum_order_quantity = NULL
           ,cleanse_status            = decode(cleanse_status
                                              ,'FAIL'
                                              ,'FAIL'
                                              ,'PASS') --cleanse_status ||
        --' MINIMUM ORDER QUANTITY :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' MINIMUM ORDER QUANTITY  :FAIL, ',
              cleanse_error = cleanse_error || ' MINIMUM ORDER QUANTITY  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source ALLOCATION PERCENT---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_allocation_percent = NULL
           ,cleanse_status        = decode(cleanse_status
                                          ,'FAIL'
                                          ,'FAIL'
                                          ,'PASS') --cleanse_status ||
        --' ALLOCATION PERCENT :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' ALLOCATION PERCENT  :FAIL, ',
              cleanse_error = cleanse_error || ' ALLOCATION PERCENT  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source RELEASE_KANBAN_FLAG---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_release_kanban_flag = NULL
           ,cleanse_status         = decode(cleanse_status
                                           ,'FAIL'
                                           ,'FAIL'
                                           ,'PASS') --cleanse_status ||
        --' RELEASE KANBAN FLAG :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status ||
              --' RELEASE KANBAN FLAG  :FAIL, ',
              cleanse_error = cleanse_error || ' RELEASE KANBAN FLAG  :' ||
                              l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------- Cleanse Source AUTO REQUEST---------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_auto_request = NULL
           ,cleanse_status  = decode(cleanse_status
                                    ,'FAIL'
                                    ,'FAIL'
                                    ,'PASS') --cleanse_status || ' AUTO REQUEST :PASS, '
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             , --cleanse_status || ' AUTO REQUEST  :FAIL, ',
              cleanse_error  = cleanse_error || ' AUTO REQUEST  :' ||
                               l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
    
    
      ---------------------------- Cleanse Source AUTO ALLOCATE FLAG---------------------------------
      -- commented on 12-DEC-2016 as per updated FDD
      /* IF i.source_type = 3
       THEN
       
         BEGIN
         
           UPDATE xxobjt.xxs3_ptm_kanban_pullseq
           SET s3_auto_allocate_flag = 1
              ,cleanse_status        = 'PASS' --cleanse_status ||
           --' AUTO ALLOCATE FLAG :PASS, '
           WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
         
         EXCEPTION
           WHEN OTHERS THEN
             l_err_message := SQLERRM;
           
             UPDATE xxobjt.xxs3_ptm_kanban_pullseq
             SET cleanse_status = 'FAIL'
                , --cleanse_status ||
                 --' AUTO ALLOCATE FLAG  :FAIL, ',
                 cleanse_error = cleanse_error || ' AUTO ALLOCATE FLAG  :' ||
                                 l_err_message || ' ,'
             WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
           
         END;
       
       ELSE
       
         BEGIN
         
           UPDATE xxobjt.xxs3_ptm_kanban_pullseq
           SET s3_auto_allocate_flag = 2
              ,cleanse_status        = 'PASS' --cleanse_status ||
           --' AUTO ALLOCATE FLAG :PASS, '
           WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
         
         EXCEPTION
           WHEN OTHERS THEN
             l_err_message := SQLERRM;
           
             UPDATE xxobjt.xxs3_ptm_kanban_pullseq
             SET cleanse_status = 'FAIL'
                , --cleanse_status ||
                 --' AUTO ALLOCATE FLAG  :FAIL, ',
                 cleanse_error = cleanse_error || ' AUTO ALLOCATE FLAG  :' ||
                                 l_err_message || ' ,'
             WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
         END;
       
       END IF; 
      
      
      */
      -- commented on 12-DEC-2016 as per updated FDD 
    
      -- Added on 12-DEC-2016 as per updated FDD 
    
      ---------------------------- Cleanse Source AUTO ALLOCATE FLAG---------------------------------
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_auto_allocate_flag = 2
           ,cleanse_status        = decode(cleanse_status
                                          ,'FAIL'
                                          ,'FAIL'
                                          ,'PASS')
        WHERE 1 = 1
        AND xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = cleanse_error || ' AUTO ALLOCATE FLAG  :' ||
                               l_err_message || ' ,'
          WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
        
      END;
    
    
    -- Added on 12-DEC-2016 as per updated FDD 
    
    END LOOP;
    COMMIT;
  
  END cleanse_data_kanban_pull;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_kanban_pull_dq(xx_kb_pull_sq_id NUMBER
                                        ,p_rule_name      IN VARCHAR2
                                        ,p_reject_code    IN VARCHAR2
                                        ,p_err_code       OUT VARCHAR2
                                        ,p_err_msg        OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxs3_ptm_kanban_pullseq
    SET process_flag = 'Q'
    WHERE xx_kb_pull_sq_id = xx_kb_pull_sq_id;
  
    INSERT INTO xxs3_ptm_kanban_pullseq_dq
      (xx_kb_pull_dq_id
      ,xx_kb_pull_sq_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_ptm_kanban_pullseq_dq_seq.NEXTVAL
      ,xx_kb_pull_sq_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
    
  END insert_update_kanban_pull_dq;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_upd_kb_pull_reject_dq(p_xx_kb_pull_sq_id NUMBER
                                        ,p_rule_name        IN VARCHAR2
                                        ,p_reject_code      IN VARCHAR2
                                        ,p_err_code         OUT VARCHAR2
                                        ,p_err_msg          OUT VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxs3_ptm_kanban_pullseq xpkp
    SET process_flag = 'R'
    WHERE xpkp.xx_kb_pull_sq_id = p_xx_kb_pull_sq_id;
  
    INSERT INTO xxs3_ptm_kanban_pullseq_dq
      (xx_kb_pull_dq_id
      ,xx_kb_pull_sq_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_ptm_kanban_pullseq_dq_seq.NEXTVAL
      ,p_xx_kb_pull_sq_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
    
  END insert_upd_kb_pull_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
  
    CURSOR c_kanban_trans_report IS
      SELECT *
      FROM xxs3_ptm_kanban_pullseq xps
      WHERE xps.transform_status IN ('PASS', 'FAIL');
  
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxs3_ptm_kanban_pullseq xpkp
    WHERE xpkp.transform_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxs3_ptm_kanban_pullseq xpkp
    WHERE xpkp.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('========================================' || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter
              ,100
              ,' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE
                      ,'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter
              ,100
              ,' '));
  
    out_p('');
  
    out_p(rpad('Track Name'
              ,10
              ,' ') || p_delimiter ||
          rpad('Entity Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('XX KB PULL SEQ ID  '
              ,20
              ,' ') || p_delimiter ||
          rpad('Kanban Pull Sequence Id'
              ,30
              ,' ') || p_delimiter ||
          rpad('Inventory Item Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Organization Code'
              ,25
              ,' ') || p_delimiter ||
          rpad('S3 Organization Code'
              ,30
              ,' ') || p_delimiter ||
          rpad('Subinventory Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('S3 Subinventory Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('Locator Name'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Locator Name'
              ,20
              ,' ') || p_delimiter ||
          rpad('S3 Supplier Number'
              ,20
              ,' ') || p_delimiter ||
          rpad('S3 Supplier Site Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Source Org Code'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Source Org Code'
              ,20
              ,' ') || p_delimiter ||
          rpad('Source Locator Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Source Locator Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Kanban Size'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Kanban Size'
              ,20
              ,' ') || p_delimiter ||
          rpad('Number Of Cards'
              ,15
              ,' ') || p_delimiter ||
          rpad('S3 Number Of Cards'
              ,20
              ,' ') || p_delimiter ||
          rpad('Status'
              ,10
              ,' ') || p_delimiter ||
          rpad('Error Message'
              ,2000
              ,' '));
  
    FOR r_data IN c_kanban_trans_report
    LOOP
      out_p(rpad('PTM'
                ,10
                ,' ') || p_delimiter ||
            rpad('KANBAN PULL SEQUENCE'
                ,11
                ,' ') || p_delimiter ||
            rpad(r_data.xx_kb_pull_sq_id
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.pull_sequence_id
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.inventory_item_name
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.organization_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_organization_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.subinventory_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_subinventory_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.locator_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_locator_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_supplier_number
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_supplier_site_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.source_org_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_source_org_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.source_locator_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_source_locator_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.kanban_size
                ,20
                ,' ') || p_delimiter ||
            rpad(r_data.s3_kanban_size
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.number_of_cards
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_number_of_cards
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.transform_status
                ,10
                ,' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error
                    ,'NULL')
                ,2000
                ,' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data cleansing for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) AS
  
    l_status        VARCHAR2(10) := 'SUCCESS';
    l_check_rule    VARCHAR2(10) := 'TRUE';
    l_error_message VARCHAR2(2000);
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    p_delimiter VARCHAR2(5) := '~';
  
    CURSOR c_kanban_cleanse_report IS
      SELECT *
      FROM xxobjt.xxs3_ptm_kanban_pullseq xkps
      WHERE xkps.cleanse_status IN ('PASS', 'FAIL');
  
  BEGIN
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxobjt.xxs3_ptm_kanban_pullseq xkps
    WHERE xkps.cleanse_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxobjt.xxs3_ptm_kanban_pullseq xkps
    WHERE xkps.cleanse_status = 'FAIL';
  
    out_p(rpad('Report name = Automated Cleanse & Standardize Report' ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('====================================================' ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter
              ,100
              ,' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE
                      ,'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter
              ,100
              ,' '));
  
    out_p('');
  
    out_p(rpad('Track Name'
              ,10
              ,' ') || p_delimiter ||
          rpad('Entity Name'
              ,11
              ,' ') || p_delimiter ||
          rpad('XX KB PULL SQ ID'
              ,14
              ,' ') || p_delimiter ||
          rpad('Kanban Pull Sequence Id'
              ,40
              ,' ') || p_delimiter ||
          rpad('Inventory Item Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Subinventory Name'
              ,30
              ,' ') || p_delimiter ||
          rpad('Source Type'
              ,20
              ,' ') || p_delimiter ||
          rpad('Source Subinventory'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Source Subinventory'
              ,30
              ,' ') || p_delimiter ||
          rpad('Source Locator Id'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Source Locator Id'
              ,30
              ,' ') || p_delimiter ||
          rpad('WIP Line Code'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 WIP Line Code'
              ,30
              ,' ') || p_delimiter ||
          rpad('Replenishment Lead Time'
              ,35
              ,' ') || p_delimiter ||
          rpad('S3 Replenishment Lead Time'
              ,40
              ,' ') || p_delimiter ||
          rpad('Calculate Kanban Flag'
              ,40
              ,' ') || p_delimiter ||
          rpad('S3 Calculate Kanban Flag'
              ,40
              ,' ') || p_delimiter ||
          rpad('Fixed Lot Multiplier'
              ,40
              ,' ') || p_delimiter ||
          rpad('S3 Fixed Lot Multiplier'
              ,40
              ,' ') || p_delimiter ||
          rpad('Safety Stock Days'
              ,40
              ,' ') || p_delimiter ||
          rpad('S3 Safety Stock Days'
              ,40
              ,' ') || p_delimiter ||
          rpad('Minimum Order Quantity'
              ,40
              ,' ') || p_delimiter ||
          rpad('S3 Minimum Order Quantity'
              ,40
              ,' ') || p_delimiter ||
          rpad('Allocation Percent'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Allocation Percent'
              ,30
              ,' ') || p_delimiter ||
          rpad('Release kanban Flag'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Release kanban Flag'
              ,30
              ,' ') || p_delimiter ||
          rpad('Auto Request'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Auto Request'
              ,30
              ,' ') || p_delimiter ||
          rpad('Auto Allocate Flag'
              ,30
              ,' ') || p_delimiter ||
          rpad('S3 Auto Allocate Flag'
              ,30
              ,' ') || p_delimiter ||
          rpad('Status'
              ,10
              ,' ') || p_delimiter ||
          rpad('cleanse_error'
              ,2000
              ,' '));
  
    FOR r_data IN c_kanban_cleanse_report
    LOOP
      out_p(rpad('PTM'
                ,10
                ,' ') || p_delimiter ||
            rpad('KANBAN PULL SEQ'
                ,11
                ,' ') || p_delimiter ||
            rpad(r_data.xx_kb_pull_sq_id
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.pull_sequence_id
                ,14
                ,' ') || p_delimiter ||
            rpad(r_data.inventory_item_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.subinventory_name
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.source_type
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.source_subinventory
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.s3_source_subinventory
                ,10
                ,' ') || p_delimiter ||
            rpad(r_data.source_locator_id
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_source_locator_id
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.wip_line_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_wip_line_code
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.replenishment_lead_time
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_replenishment_lead_time
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.calculate_kanban_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_calculate_kanban_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.fixed_lot_multiplier
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_fixed_lot_multiplier
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.safety_stock_days
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_safety_stock_days
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.minimum_order_quantity
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_minimum_order_quantity
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.allocation_percent
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_allocation_percent
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.release_kanban_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_release_kanban_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.auto_request
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_auto_request
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.auto_allocate_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.s3_auto_allocate_flag
                ,30
                ,' ') || p_delimiter ||
            rpad(r_data.cleanse_status
                ,10
                ,' ') || p_delimiter ||
            rpad(nvl(r_data.cleanse_error
                    ,'NULL')
                ,2000
                ,' '));
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,'Stratasys Confidential' || p_delimiter);
  
  EXCEPTION
  
    WHEN OTHERS THEN
      l_error_message := 'Error in creating Data Cleansing Report ' ||
                         SQLERRM;
      dbms_output.put_line(l_error_message);
    
  END data_cleanse_report;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_kanban(p_err_code OUT VARCHAR2
                                ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
  
    CURSOR cur_kbp IS
      SELECT * FROM xxs3_ptm_kanban_pullseq WHERE process_flag = 'N';
  
  BEGIN
    FOR i IN cur_kbp
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
    
      IF i.locator_id IS NULL
      THEN
      
        insert_upd_kb_pull_reject_dq(i.xx_kb_pull_sq_id
                                    ,'EQT_028:LOCATOR ID IS NOT NULL'
                                    ,'LOCATOR ID IS NULL'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF i.kanban_size IS NULL
      THEN
      
        insert_upd_kb_pull_reject_dq(i.xx_kb_pull_sq_id
                                    ,'EQT_028:KANBAN_SIZE IS NULL'
                                    ,'KANBAN_SIZE IS NULL'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF i.number_of_cards IS NULL
      THEN
      
        insert_upd_kb_pull_reject_dq(i.xx_kb_pull_sq_id
                                    ,'EQT_028:NUMBER_OF_CARDS IS NULL'
                                    ,'NUMBER_OF_CARDS IS NULL'
                                    ,p_err_code
                                    ,p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF i.locator_name IS NOT NULL
      THEN
      
        l_check_rule := xxs3_dq_util_pkg.eqt_166(i.locator_name
                                                ,i.locator_id);
      
        IF l_check_rule = 'FALSE'
        THEN
        
          insert_upd_kb_pull_reject_dq(i.xx_kb_pull_sq_id
                                      ,'EQT_166: VALID KANBAN LOCATOR_ID'
                                      ,'AN EQUIVALENT S3 LOCATOR DOES NOT EXIST'
                                      ,p_err_code
                                      ,p_err_msg);
          l_status := 'ERR';
        
        END IF;
      
      ELSE
      
        insert_upd_kb_pull_reject_dq(i.xx_kb_pull_sq_id
                                    ,'EQT_166: VALID KANBAN LOCATOR_ID'
                                    ,'AN EQUIVALENT S3 LOCATOR DOES NOT EXIST'
                                    ,p_err_code
                                    ,p_err_msg);
      
        l_status := 'ERR';
      
      END IF;
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_ptm_kanban_pullseq
        SET process_flag = 'Y'
        WHERE xx_kb_pull_sq_id = i.xx_kb_pull_sq_id;
      END IF;
    END LOOP;
    COMMIT;
  
  END quality_check_kanban;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE kanban_pull_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER) AS
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(100);
    l_error_message       VARCHAR2(2000); -- mock
    l_get_org             VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
    p_locator_type        VARCHAR2(50);
    non_loc_attr2         VARCHAR2(100);
    l_step                VARCHAR2(200);
    l_supplier_number     NUMBER;
    l_supllier_site_code  VARCHAR2(100);
    l_supplier_name       VARCHAR2(200);
  
  
    CURSOR cur_ptm_kanban IS
      SELECT mkp.pull_sequence_id -- Added on 13-OCT-2016
            ,mkp.organization_id organization_id
            ,ood.organization_code organization_code
            ,mkp.inventory_item_id inventory_item_id
            , -- added 16th aug
             (SELECT segment1
              FROM mtl_system_items_b
              WHERE inventory_item_id = mkp.inventory_item_id
              AND organization_id = mkp.organization_id) inventory_item_name
            , -- added 16th aug
             mkp.subinventory_name subinventory_name
            ,mkp.locator_id locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.locator_id) locator_name
            ,mkp.source_type source_type
            ,mkp.auto_allocate_flag auto_allocate_flag
            ,mkp.supplier_id
            ,mkp.supplier_site_id
            ,mkp.source_organization_id
            ,(SELECT organization_code
              FROM org_organization_definitions
              WHERE organization_id = mkp.source_organization_id) source_org_code
            ,mkp.source_subinventory source_subinventory
            ,mkp.source_locator_id source_locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.source_locator_id) source_locator_name
            ,mkp.wip_line_id wip_line_code
            ,mkp.release_kanban_flag release_kanban_flag
            ,mkp.auto_request auto_request
            ,mkp.calculate_kanban_flag calculate_kanban_flag
            ,mkp.kanban_size kanban_size
            ,mkp.number_of_cards number_of_cards
            ,mkp.minimum_order_quantity minimum_order_quantity
            ,mkp.replenishment_lead_time replenishment_lead_time
            ,mkp.allocation_percent allocation_percent
            ,mkp.fixed_lot_multiplier fixed_lot_multiplier
            ,mkp.safety_stock_days safety_stock_days
      FROM mtl_kanban_pull_sequences_v  mkp
          ,org_organization_definitions ood
          ,mtl_kanban_cards_v           mkc
      WHERE mkp.organization_id = ood.organization_id
      AND mkc.pull_sequence_id = mkp.pull_sequence_id
      AND ood.organization_code = 'UME'
      AND mkp.source_type_meaning = 'Supplier'
      AND EXISTS
       (SELECT *
             FROM xxs3_ptm_master_items_ext_stg xpmies
             WHERE mkp.inventory_item_id = xpmies.l_inventory_item_id
             AND xpmies.extract_rule_name IS NOT NULL -- added on 12-DEC-2016
             AND xpmies.legacy_organization_code IN ('UME') -- added on 12-DEC-2016
             )
      
      UNION --ALL
      
      SELECT mkp.pull_sequence_id
            ,mkp.organization_id organization_id
            ,ood.organization_code organization_code
            ,mkp.inventory_item_id inventory_item_id
            , -- added 16th aug
             (SELECT segment1
              FROM mtl_system_items_b
              WHERE inventory_item_id = mkp.inventory_item_id
              AND organization_id = mkp.organization_id) inventory_item_name
            , -- added 16th aug
             mkp.subinventory_name subinventory_name
            ,mkp.locator_id locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.locator_id) locator_name
            ,mkp.source_type source_type
            ,mkp.auto_allocate_flag auto_allocate_flag
            ,mkp.supplier_id
            ,mkp.supplier_site_id
            ,mkp.source_organization_id
            ,(SELECT organization_code
              FROM org_organization_definitions
              WHERE organization_id = mkp.source_organization_id) source_org_code
            ,mkp.source_subinventory source_subinventory
            ,mkp.source_locator_id source_locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.source_locator_id) source_locator_name
            ,mkp.wip_line_id wip_line_code
            ,mkp.release_kanban_flag release_kanban_flag
            ,mkp.auto_request auto_request
            ,mkp.calculate_kanban_flag calculate_kanban_flag
            ,mkp.kanban_size kanban_size
            ,mkp.number_of_cards number_of_cards
            ,mkp.minimum_order_quantity minimum_order_quantity
            ,mkp.replenishment_lead_time replenishment_lead_time
            ,mkp.allocation_percent allocation_percent
            ,mkp.fixed_lot_multiplier fixed_lot_multiplier
            ,mkp.safety_stock_days safety_stock_days
      FROM mtl_kanban_pull_sequences_v  mkp
          ,org_organization_definitions ood
          ,mtl_kanban_cards_v           mkc
      WHERE mkp.organization_id = ood.organization_id
      AND mkc.pull_sequence_id = mkp.pull_sequence_id
      AND ood.organization_code = 'UME'
      AND mkp.source_type_meaning = 'Intra Org'
      AND mkp.source_subinventory IN ('RAW-MVP', 'RAW-SMAC', 'RAW-OPS')
      AND EXISTS
       (SELECT *
             FROM xxs3_ptm_master_items_ext_stg xpmies
             WHERE mkp.inventory_item_id = xpmies.l_inventory_item_id
             AND xpmies.extract_rule_name IS NOT NULL -- added on 12-DEC-2016
             AND xpmies.legacy_organization_code IN ('UME')); -- added on 12-DEC-2016);
  
    --Commented on 14-OCT-3016      
    /*SELECT mkp.pull_sequence_id
            ,mkp.organization_id organization_id
            ,ood.organization_code organization_code
            ,mkp.inventory_item_id inventory_item_id
            , -- added 16th aug
             (SELECT segment1
              FROM mtl_system_items_b
              WHERE inventory_item_id = mkp.inventory_item_id
              AND organization_id = mkp.organization_id) inventory_item_name
            , -- added 16th aug
             mkp.subinventory_name subinventory_name
            ,mkp.locator_id locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.locator_id) locator_name
            ,mkp.source_type source_type
            ,mkp.auto_allocate_flag auto_allocate_flag
            ,mkp.supplier_id supplier_name
            ,mkp.supplier_site_id supplier_site_name
            ,mkp.source_organization_id
            ,(SELECT organization_code
              FROM org_organization_definitions
              WHERE organization_id = mkp.source_organization_id) source_org_code
            ,mkp.source_subinventory source_subinventory
            ,mkp.source_locator_id source_locator_id
            ,(SELECT attribute2
              FROM mtl_item_locations
              WHERE inventory_location_id = mkp.source_locator_id) source_locator_name
            ,mkp.wip_line_id wip_line_code
            ,mkp.release_kanban_flag release_kanban_flag
            ,mkp.auto_request auto_request
            ,mkp.calculate_kanban_flag calculate_kanban_flag
            ,mkp.kanban_size kanban_size
            ,mkp.number_of_cards number_of_cards
            ,mkp.minimum_order_quantity minimum_order_quantity
            ,mkp.replenishment_lead_time replenishment_lead_time
            ,mkp.allocation_percent allocation_percent
            ,mkp.fixed_lot_multiplier fixed_lot_multiplier
            ,mkp.safety_stock_days safety_stock_days
      FROM mtl_kanban_pull_sequences_v  mkp
          ,org_organization_definitions ood
          ,mtl_kanban_cards_v           mkc
      WHERE mkp.organization_id = ood.organization_id
      AND mkc.pull_sequence_id = mkp.pull_sequence_id
      AND ood.organization_code = 'UME'
      AND mkp.source_type_meaning IN ('Supplier', 'Intra Org')
      AND EXISTS
       (SELECT *
             FROM xxs3_ptm_mtl_master_items xptmi --Added on 14-OCT-2016
             WHERE xptmi.l_inventory_item_id = mkp.inventory_item_id); --Added on 14-OCT-2016
     --Commented on 14-OCT-3016   
    
    
     /*   AND mkp.source_subinventory in ('RAW-MVP', 'RAW-SMAC', 'RAW-OPS')
    AND mkc.CARD_STATUS_NAME = 'Active'
    AND not exists (select *
           from MTL_KANBAN_PULL_SEQUENCES_V
          where source_type = '2'
            and organization_id = 739
            and subinventory_name = 'RAW-MVP');*/
  
  
  
    CURSOR cur_transform IS
      SELECT * FROM xxs3_ptm_kanban_pullseq;
    -- WHERE process_flag IN ('Y', 'Q');
  
  
  BEGIN
    --------------------------------- Remove existing data in staging --------------------------------
  
    log_p('Truncating staging table...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_PTM_KANBAN_PULLSEQ';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_PTM_KANBAN_PULLSEQ_DQ';
  
    -------------------------------- Insert Legacy Data in Staging-----------------------------------
  
    log_p('Inserting in staging table...');
  
    FOR i IN cur_ptm_kanban
    LOOP
      BEGIN
        INSERT INTO xxobjt.xxs3_ptm_kanban_pullseq
          (xx_kb_pull_sq_id
          ,date_of_extract
          ,process_flag
          ,pull_sequence_id
          ,organization_id
          ,organization_code
          ,inventory_item_id
          , -- added 16 aug
           inventory_item_name
          , -- added 16 aug
           subinventory_name
          ,locator_id
          ,locator_name
          ,source_type
          ,auto_allocate_flag
          ,supplier_id
          ,supplier_site_id
          ,source_organization_id
          ,source_org_code
          ,source_subinventory
          ,source_locator_id
          ,source_locator_name
          ,wip_line_code
          ,release_kanban_flag
          ,auto_request
          ,calculate_kanban_flag
          ,kanban_size
          ,number_of_cards
          ,minimum_order_quantity
          ,replenishment_lead_time
          ,allocation_percent
          ,fixed_lot_multiplier
          ,safety_stock_days)
        VALUES
          (xxs3_ptm_kanban_pullseq_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,i.pull_sequence_id
          ,i.organization_id
          ,i.organization_code
          ,i.inventory_item_id
          ,i.inventory_item_name
          ,i.subinventory_name
          ,i.locator_id
          ,i.locator_name
          ,i.source_type
          ,i.auto_allocate_flag
          ,i.supplier_id
          ,i.supplier_site_id
          ,i.source_organization_id
          ,i.source_org_code
          ,i.source_subinventory
          ,i.source_locator_id
          ,i.source_locator_name
          ,i.wip_line_code
          ,i.release_kanban_flag
          ,i.auto_request
          ,i.calculate_kanban_flag
          ,i.kanban_size
          ,i.number_of_cards
          ,i.minimum_order_quantity
          ,i.replenishment_lead_time
          ,i.allocation_percent
          ,i.fixed_lot_multiplier
          ,i.safety_stock_days);
      
      
      EXCEPTION
        WHEN OTHERS THEN
          log_p('Error while inserting data for kanban for id : ' ||
                i.pull_sequence_id || ' : ERROR : ' || SQLERRM);
        
      
      
      END;
    
    END LOOP;
  
    log_p('Data insertion in staging table completed...');
  
    -------------------------------- Cleanse Data-----------------------------------
  
    log_p('Data cleanse strating...');
    cleanse_data_kanban_pull(l_err_code
                            ,l_err_msg);
    log_p('Data cleanse completed...');
  
    -------------------------------- Quality check Data------------------------------
  
    log_p('Data Quality check strating...');
    quality_check_kanban(l_err_code
                        ,l_err_msg);
    log_p('Data Quality check completed...');
  
    -------------------------------- Transform Data------------------------------
  
    log_p('Starting Transformation...');
  
    FOR j IN cur_transform
    LOOP
    
      ------------------ Get Subinventory_name and Locator Id---------------------------------------
    
      BEGIN
      
        IF j.locator_name IS NOT NULL
        THEN
          --log_p();
          xxs3_data_transform_util_pkg.ptm_locator_attr2_parse(j.locator_name
                                                              ,l_get_org
                                                              ,l_get_sub_inv_name
                                                              ,l_get_concat_segments
                                                              ,l_get_row
                                                              ,l_get_rack
                                                              ,l_get_bin
                                                              ,l_error_message);
        
        
        
          IF l_error_message IS NULL
          THEN
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET s3_locator_name      = l_get_concat_segments
               ,s3_subinventory_name = l_get_sub_inv_name
               ,transform_status     = decode(transform_status
                                             ,'FAIL'
                                             ,'FAIL'
                                             ,'PASS')
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
          ELSE
          
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET transform_status = 'FAIL'
               ,transform_error  = transform_error || ' , ' ||
                                   l_error_message
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
          END IF;
        
          -- Added on 05-OCT-2016 as per updated FDD 
          -- To populate the dummy locator_name in S3 for non locator controlled subinventories  
        
        ELSE
          log_p('pull_sequence_id : ' || j.pull_sequence_id);
        
          SELECT locator_type
          INTO p_locator_type
          FROM mtl_secondary_inventories
          WHERE secondary_inventory_name = j.subinventory_name
          AND organization_id =
                (SELECT organization_id
                 FROM mtl_parameters_view
                 WHERE organization_code = 'UME');
        
          IF p_locator_type = 1
          THEN
          
            BEGIN
            
              SELECT attribute2
              INTO non_loc_attr2
              FROM mtl_item_locations
              WHERE subinventory_code = j.subinventory_name;
            
            
              xxs3_data_transform_util_pkg.ptm_locator_attr2_parse(non_loc_attr2
                                                                  ,l_get_org
                                                                  ,l_get_sub_inv_name
                                                                  ,l_get_concat_segments
                                                                  ,l_get_row
                                                                  ,l_get_rack
                                                                  ,l_get_bin
                                                                  ,l_error_message);
            
              IF l_error_message IS NULL
              THEN
              
                UPDATE xxobjt.xxs3_ptm_kanban_pullseq
                SET s3_locator_name      = l_get_concat_segments
                   ,s3_subinventory_name = l_get_sub_inv_name
                   ,transform_status     = decode(transform_status
                                                 ,'FAIL'
                                                 ,'FAIL'
                                                 ,'PASS')
                WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
              
              ELSE
              
                UPDATE xxobjt.xxs3_ptm_kanban_pullseq
                SET transform_status = 'FAIL'
                   ,transform_error  = transform_error || ' , ' ||
                                       l_error_message
                WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
              
              END IF;
            
            EXCEPTION
              WHEN no_data_found THEN
              
                UPDATE xxobjt.xxs3_ptm_kanban_pullseq
                SET transform_status = 'FAIL'
                   ,transform_error  = (transform_error || ' , ' ||
                                       'No Dummy Locator is defined for the non-locator controlled sub inventory : ' ||
                                       j.subinventory_name)
                WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
              
              WHEN too_many_rows THEN
              
                UPDATE xxobjt.xxs3_ptm_kanban_pullseq
                SET transform_status = 'FAIL'
                   ,transform_error  = (transform_error || ' , ' ||
                                       'More than one Dummy Locator is defined for the non-locator controlled sub inventory : ' ||
                                       j.subinventory_name)
                WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
              
            
              WHEN OTHERS THEN
              
                l_error_message := 'Error transformation of Subinventory_name and Locator ' ||
                                   SQLERRM;
              
                UPDATE xxobjt.xxs3_ptm_kanban_pullseq
                SET transform_status = 'FAIL'
                   ,transform_error  = (transform_error || ' , ' ||
                                       l_error_message)
                WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
              
            
            END;
          
          ELSE
          
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET transform_status = 'FAIL'
               ,transform_error  = (transform_error || ' , ' ||
                                   'Unable to find the equivalent s3 locator for the Kanban Pull Sequence; though sub inventory : ' ||
                                   j.subinventory_name ||
                                   ' is not non-locator controlled.')
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
          
          
          END IF;
        
        
        END IF;
      
        -- To populate the dummy locator_name in S3 for non locator controlled subinventories
        -- Added on 05-OCT-2016 as per updated FDD  
      
      EXCEPTION
        WHEN OTHERS THEN
        
          l_error_message := 'Error in transformation of Subinvemtory and Locator Name : ' ||
                             SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error || ' , ' ||
                                 l_error_message
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
      END;
    
      ---------------------------Update Sourge org code an dsource type-------------------------------------
    
      IF j.source_subinventory = 'RAW-MVP'
         AND j.source_type = 3
      THEN
      
        BEGIN
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_source_org_code = 'T03'
             ,s3_source_type     = 1
             ,transform_status   = decode(transform_status
                                         ,'FAIL'
                                         ,'FAIL'
                                         ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        EXCEPTION
        
          WHEN OTHERS THEN
          
            l_error_message := 'Error in updating source subinventory / source type' ||
                               SQLERRM;
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET transform_status = 'FAIL'
               ,transform_error  = transform_error || ' , ' ||
                                   l_error_message
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
        END;
      
      ELSE
      
        IF j.source_org_code IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org'
                                                ,p_stage_tab => 'XXOBJT.XXS3_PTM_KANBAN_PULLSEQ'
                                                , --Staging Table Name
                                                 p_stage_primary_col => 'XX_KB_PULL_SQ_ID'
                                                , --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => j.xx_kb_pull_sq_id
                                                , --Staging Table Primary Column Value
                                                 p_legacy_val => j.source_org_code
                                                , --Legacy Value
                                                 p_stage_col => 'S3_SOURCE_ORG_CODE'
                                                , --Staging Table Name
                                                 p_err_code => l_err_code
                                                , -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
      END IF;
    
    
    
      -- Added on 13-OCT-2016 as Suggested by Eric    
      ------------------ Get Source Locator Name ---------------------------------------
    
      IF j.source_locator_name IS NOT NULL
      THEN
      
        BEGIN
        
          xxs3_data_transform_util_pkg.ptm_locator_attr2_parse(j.source_locator_name
                                                              ,l_get_org
                                                              ,l_get_sub_inv_name
                                                              ,l_get_concat_segments
                                                              ,l_get_row
                                                              ,l_get_rack
                                                              ,l_get_bin
                                                              ,l_error_message);
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_source_locator_name = l_get_concat_segments
             ,transform_status       = decode(transform_status
                                             ,'FAIL'
                                             ,'FAIL'
                                             ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        
        EXCEPTION
          WHEN OTHERS THEN
          
            l_error_message := 'Error transformation of Source Locator Name' ||
                               SQLERRM;
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET transform_status = 'FAIL'
               ,transform_error  = transform_error || ' , ' ||
                                   l_error_message
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
        
        END;
      
      END IF;
    
      -- Added on 13-OCT-2016 as Suggested by Eric
    
    
    
      -- Added on 15-OCT-2016 as per updated FDD 
    
      ------------------ Transformation of NUMBER_OF_CARDS ---------------------------------------
    
      BEGIN
      
        IF j.number_of_cards = 1
        THEN
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_number_of_cards = 2
             ,transform_status   = decode(transform_status
                                         ,'FAIL'
                                         ,'FAIL'
                                         ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        ELSE
          IF j.number_of_cards >= 2
          THEN
          
            UPDATE xxobjt.xxs3_ptm_kanban_pullseq
            SET s3_number_of_cards = j.number_of_cards
               ,transform_status   = decode(transform_status
                                           ,'FAIL'
                                           ,'FAIL'
                                           ,'PASS')
            WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
          
          END IF;
        
        
        END IF;
      
      
      EXCEPTION
        WHEN OTHERS THEN
        
          l_error_message := 'Error while transformaing of NUMBER_OF_CARDS' ||
                             SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error || ' , ' ||
                                 l_error_message
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
      
      END;
    
    
      ------------------ Update Kanban_Size  ---------------------------------------
    
      BEGIN
      
        UPDATE xxobjt.xxs3_ptm_kanban_pullseq
        SET s3_kanban_size   = kanban_size
           ,transform_status = decode(transform_status
                                     ,'FAIL'
                                     ,'FAIL'
                                     ,'PASS')
        WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
      
      EXCEPTION
        WHEN OTHERS THEN
        
          l_error_message := 'Error while transformaing of kanban_size' ||
                             SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error || ' , ' ||
                                 l_error_message
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
      
      END;
    
    
      -- Added on 15-OCT-2016 as per updated FDD 
    
    
      -- Added on 25-OCT-2016 as per updated FDD 
      ------------------ Transformation of SUPPLIER_ID and SUPPLIER_SITE_ID ---------------------------------------
    
    
      BEGIN
      
        IF j.supplier_id IS NOT NULL
        THEN
        
          l_step := 'Fetching supplier number';
          SELECT segment1
          INTO l_supplier_number
          FROM ap_suppliers asa
          WHERE asa.vendor_id = j.supplier_id;
        
        
          l_step := 'Updating supplier number';
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_supplier_number = l_supplier_number
             ,transform_status   = decode(transform_status
                                         ,'FAIL'
                                         ,'FAIL'
                                         ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        
          l_step := 'Fetching supplier Name';
          SELECT vendor_name
          INTO l_supplier_name
          FROM ap_suppliers asa
          WHERE asa.vendor_id = j.supplier_id;
        
        
          l_step := 'Updating supplier Name';
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET supplier_name    = l_supplier_name
             ,transform_status = decode(transform_status
                                       ,'FAIL'
                                       ,'FAIL'
                                       ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        
        END IF;
      
      
      
        IF j.supplier_site_id IS NOT NULL
        THEN
        
          l_step := 'Fetching supplier Site number';
          SELECT vendor_site_code
          INTO l_supllier_site_code
          FROM ap_supplier_sites_all assa
          WHERE assa.vendor_id = j.supplier_id
          AND assa.vendor_site_id = j.supplier_site_id
          AND assa.org_id = 737;
        
          l_step := 'Updating supplier Site number';
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET s3_supplier_site_name = l_supllier_site_code
             ,transform_status      = decode(transform_status
                                            ,'FAIL'
                                            ,'FAIL'
                                            ,'PASS')
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
        
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
        
          l_error_message := 'Error while transformation of supplier in step : ' ||
                             l_step || ' - ' || SQLERRM;
        
          UPDATE xxobjt.xxs3_ptm_kanban_pullseq
          SET transform_status = 'FAIL'
             ,transform_error  = transform_error || ' , ' ||
                                 l_error_message
          WHERE xx_kb_pull_sq_id = j.xx_kb_pull_sq_id;
        
      
      END;
    
    
    
      -- Added on 25-OCT-2016 as per updated FDD 
    
    
      IF j.organization_code IS NOT NULL
      THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org'
                                              ,p_stage_tab => 'XXOBJT.XXS3_PTM_KANBAN_PULLSEQ'
                                              , --Staging Table Name
                                               p_stage_primary_col => 'XX_KB_PULL_SQ_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_kb_pull_sq_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val => j.organization_code
                                              , --Legacy Value
                                               p_stage_col => 'S3_ORGANIZATION_CODE'
                                              , --Staging Table Name
                                               p_err_code => l_err_code
                                              , -- Output error code
                                               p_err_msg => l_err_msg);
      END IF;
    
    
    
    END LOOP;
  
    log_p('Transformation completed...');
  
    kanban_report_data('KANBAN PULL SQUENCE');
  
  END kanban_pull_extract_data;

END xxs3_ptm_kanban_pull_pkg;
/
