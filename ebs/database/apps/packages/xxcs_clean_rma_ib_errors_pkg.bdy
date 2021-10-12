CREATE OR REPLACE PACKAGE BODY XXCS_CLEAN_RMA_IB_ERRORS_PKG IS
  --------------For concurrent XX: Clean RMA Fulfillment IB Errors (short name: XXCS_CLEAN_RMA_IB_ERRORS)
  --------------xxcs_clean_rma_ib_errors_pkg.clean_rma_ib_errors
  /**********************************************************************************************************/
  PROCEDURE CLEAN_RMA_IB_ERRORS(ERRBUF OUT VARCHAR2, ERRCODE OUT VARCHAR2) IS
  
    CURSOR MAIN_CUR IS
      SELECT SOURCE_HEADER_REF_ID,
             SOURCE_HEADER_REF,
             SOURCE_LINE_REF_ID,
             SOURCE_LINE_REF,
             TRANSACTION_ERROR_ID
        FROM CSI_TXN_ERRORS
       WHERE SOURCE_TYPE = 'CSIRMAFL'
         AND PROCESSED_FLAG = 'E'
         AND ERROR_TEXT LIKE '%Transaction Details are Mandatory%';
    --AND rownum=1;  ---FOR DEBUGGING ONLY
  
    L_TRANSACTION_ID NUMBER;
    V_STEP           VARCHAR2(100);
    V_COUNTER        NUMBER := 0;
    V_SUCCESS_CNTR   NUMBER := 0;
    V_FAILURE_CNTR   NUMBER := 0;
  
  BEGIN
  
    FOR I IN MAIN_CUR LOOP
      ---================ LOOP==========================
      BEGIN
        V_COUNTER := V_COUNTER + 1;
        V_STEP    := 'Step 1';
        SELECT CSI_TRANSACTIONS_S.NEXTVAL INTO L_TRANSACTION_ID FROM DUAL;
      
        V_STEP := 'Step 5';
        INSERT INTO CSI_TRANSACTIONS
        VALUES
          (L_TRANSACTION_ID,
           SYSDATE,
           SYSDATE,
           54,
           NULL,           NULL,           NULL,
           I.SOURCE_HEADER_REF_ID,
           I.SOURCE_HEADER_REF,
           I.SOURCE_LINE_REF_ID,
           I.SOURCE_LINE_REF,
           NULL,           NULL,           NULL,           NULL,
           NULL,           NULL,
           'COMPLETE',
           NULL,           NULL,           NULL,           NULL,
           NULL,           NULL,           NULL,           NULL,
           NULL,           NULL,           NULL,           NULL,
           NULL,           NULL,           NULL,           NULL,
           NULL,           NULL,           NULL,
           -1,
           SYSDATE,
           -1,
           SYSDATE,
           -1,
           1,
           NULL,
           NULL,
           1,
           'N');
      
        V_STEP := 'Step 10';
        UPDATE CSI_TXN_ERRORS
           SET PROCESSED_FLAG = 'P', ERROR_TEXT = 'FIXED: ' || ERROR_TEXT
         WHERE TRANSACTION_ERROR_ID = I.TRANSACTION_ERROR_ID;
        V_SUCCESS_CNTR := V_SUCCESS_CNTR + 1;
      EXCEPTION
        WHEN OTHERS THEN
          V_FAILURE_CNTR := V_FAILURE_CNTR + 1;
          FND_FILE.PUT_LINE(FND_FILE.LOG,
                            '======== ERROR : (transaction_error_id=' ||
                            I.TRANSACTION_ERROR_ID || ' (step=' || V_STEP ||
                            ') : ' || SQLERRM);
      END;
      ---================ END LOOP======================
    END LOOP;
  
    COMMIT;
  
    ------------------Display total information ...----------------------------
    FND_FILE.PUT_LINE(FND_FILE.LOG, ''); --empty line
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '***************************************************************************');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '********************TOTAL INFORMATION******************************');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '***************************************************************************');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=========There are ' || V_COUNTER ||
                      ' errors in CSI_TXN_ERRORS table for updating');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=============' || V_SUCCESS_CNTR ||
                      ' errors were updated SUCCESSFULY');
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=============' || V_FAILURE_CNTR ||
                      ' updates  FAILURED');
  
  EXCEPTION
    WHEN OTHERS THEN
      ERRBUF  := 'Procedure xxcs_clean_rma_ib_errors_pkg.clean_rma_ib_errors Failed';
      ERRCODE := 1;
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '========Unexpected ERROR in XXCS_CLEAN_RMA_IB_ERRORS_PKG.clean_rma_ib_errors (step=' ||
                        V_STEP || ') : ' || SQLERRM);
  END CLEAN_RMA_IB_ERRORS;

END XXCS_CLEAN_RMA_IB_ERRORS_PKG;
/

