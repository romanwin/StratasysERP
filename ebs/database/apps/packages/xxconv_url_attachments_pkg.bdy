CREATE OR REPLACE PACKAGE BODY XXCONV_URL_ATTACHMENTS_PKG IS

  ------------------------------------
  PROCEDURE UPLOAD_URL_ATTACHMENT_FOR_ITEM(ERRBUF                      OUT VARCHAR2,
                                           ERRCODE                     OUT VARCHAR2,
                                           P_LOCATION                  IN VARCHAR2,
                                           P_FILENAME                  IN VARCHAR2,
                                           P_IGNORE_FIRST_HEADERS_LINE IN VARCHAR2 DEFAULT 'Y',
                                           P_VALIDATE_ONLY_FLAG        IN VARCHAR2 DEFAULT 'Y',
                                           P_ORGANIZATION_ID           IN NUMBER,
                                           P_INVENTORY_ITEM_ID         IN NUMBER,
                                           P_DATATYPE_ID               IN NUMBER,
                                           P_CATEGORY_ID               IN NUMBER) IS
  
    V_ORGANIZATION_NAME   VARCHAR2(300);
    V_ITEM_PARAMETER_TEXT VARCHAR2(1000);
    V_STEP                VARCHAR2(1000);
    V_LINE_NUMBER         NUMBER := 0;
    V_LINE_IS_VALID_FLAG  VARCHAR2(1);
    V_VALID_ERROR_MESSAGE VARCHAR2(1000);
    V_ERROR_MESSAGE       VARCHAR2(1000);
    V_STATUS              VARCHAR2(100);
    V_NUMERIC_DUMMY       NUMBER;
    ---V_CATEGORY_EXISTS          NUMBER;
    V_CATEGORY_USER_NAME VARCHAR2(300);
    ---V_DATATYPE_EXISTS          NUMBER;
    V_DATATYPE_USER_NAME       VARCHAR2(300);
    V_THERE_ARE_NON_VALID_ROWS VARCHAR2(100) := 'N';
    V_NUM_OF_NON_VALID_LINES   NUMBER := 0;
    V_NUM_OF_VALID_LINES       NUMBER := 0;
    STOP_PROCESSING EXCEPTION; --- missing parameter...or invalid parameter. stop (exit) procedure..
    VALIDATION_ERROR EXCEPTION; ---the one of fields is invalid. stop processing for this line
    V_NUM_OF_UPLOAD_SUCCESS  NUMBER := 0;
    V_NUM_OF_UPLOAD_FAILURED NUMBER := 0;
    V_RESULT                 VARCHAR2(100);
    ---UTL_FILE variables----------------
    V_FILE                 UTL_FILE.FILE_TYPE;
    V_LINE                 VARCHAR2(7000);
    V_READ_CODE            NUMBER;
    V_SEGMENT1             VARCHAR2(300);
    V_ATTACHMENT_FILE_NAME VARCHAR2(300);
    -----Selected values-----------------
    V_INVENTORY_ITEM_ID NUMBER;
    -----API variables-------------------
  
  BEGIN
  
    V_STEP := 'Step 1';
  
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); ---empty row
  
    IF P_LOCATION IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* MISSING PARAMETER p_location ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_FILENAME IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* MISSING PARAMETER p_filename ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_VALIDATE_ONLY_FLAG IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* MISSING PARAMETER p_validate_only_flag *******' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_VALIDATE_ONLY_FLAG NOT IN ('Y', 'N') THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* PARAMETER p_validate_only_flag SHOULD BE ''Y'' or ''N'' ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_IGNORE_FIRST_HEADERS_LINE IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* MISSING PARAMETER p_ignore_first_headers_line ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_IGNORE_FIRST_HEADERS_LINE NOT IN ('Y', 'N') THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR************* PARAMETER p_ignore_first_headers_line SHOULD BE ''Y'' or ''N'' **********' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_ORGANIZATION_ID IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR********** MISSING PARAMETER p_organization_id ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    IF P_CATEGORY_ID IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR********** MISSING PARAMETER p_category_id ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    -------
    BEGIN
      SELECT T.USER_NAME
        INTO V_CATEGORY_USER_NAME
        FROM FND_DOCUMENT_CATEGORIES_TL T
       WHERE T.CATEGORY_ID = P_CATEGORY_ID
         AND T.LANGUAGE = 'US';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          '****ERROR********** CATEGORY p_category_id=' ||
                          P_CATEGORY_ID ||
                          ' DOES NOT EXIST in FND_DOCUMENT_CATEGORIES table ****************' ||
                          CHR(13));
        RAISE STOP_PROCESSING;
    END;
    -------
  
    IF P_DATATYPE_ID IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '****ERROR********** MISSING PARAMETER p_datatype_id ****************' ||
                        CHR(13));
      RAISE STOP_PROCESSING;
    END IF;
  
    -------
    BEGIN
      SELECT T.USER_NAME
        INTO V_DATATYPE_USER_NAME
        FROM FND_DOCUMENT_DATATYPES T
       WHERE T.DATATYPE_ID = P_DATATYPE_ID
         AND T.LANGUAGE = 'US'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        V_DATATYPE_USER_NAME := NULL;
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          '****ERROR********** DATATYPE p_datatype_id=' ||
                          P_DATATYPE_ID ||
                          ' DOES NOT EXIST in FND_DOCUMENT_DATATYPES table ****************' ||
                          CHR(13));
        RAISE STOP_PROCESSING;
    END;
    -------
  
    -------Get organization name------------
    BEGIN
      SELECT OU.NAME
        INTO V_ORGANIZATION_NAME
        FROM HR_ALL_ORGANIZATION_UNITS OU
       WHERE OU.ORGANIZATION_ID = P_ORGANIZATION_ID; --parameter
    EXCEPTION
      WHEN OTHERS THEN
        V_ORGANIZATION_NAME := NULL;
    END;
  
    IF P_INVENTORY_ITEM_ID IS NOT NULL THEN
      --------Get inventory item id-----------
      BEGIN
        SELECT MSI.INVENTORY_ITEM_ID || '      (''' || MSI.SEGMENT1 ||
               ''')'
          INTO V_ITEM_PARAMETER_TEXT
          FROM MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.ORGANIZATION_ID = P_ORGANIZATION_ID ---parameter
           AND MSI.INVENTORY_ITEM_ID = P_INVENTORY_ITEM_ID; ---parameter
      EXCEPTION
        WHEN OTHERS THEN
          V_ORGANIZATION_NAME := NULL;
      END;
      -----------------------------------------
    ELSE
      V_ITEM_PARAMETER_TEXT := '';
    END IF;
  
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '******************************************************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '***************************PARAMETERS*****************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '******************************************************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_location=' || P_LOCATION || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_filename=' || P_FILENAME || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_ignore_first_headers_line=' ||
                      P_IGNORE_FIRST_HEADERS_LINE || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_validate_only_flag=' ||
                      P_VALIDATE_ONLY_FLAG || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_organization_id=   ' || P_ORGANIZATION_ID ||
                      '    (''' || V_ORGANIZATION_NAME || ''')' || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_inventory_item_id= ' ||
                      V_ITEM_PARAMETER_TEXT || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_datatype_id= ' || P_DATATYPE_ID ||
                      '   (''' || V_DATATYPE_USER_NAME || ''')' || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '---------p_category_id= ' || P_CATEGORY_ID ||
                      '   (''' || V_CATEGORY_USER_NAME || ''')' || CHR(13));
  
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); --empty line
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); --empty line
  
    ------------------Open flat file----------------------------
    V_STEP := 'Step 10';
    BEGIN
      V_FILE := UTL_FILE.FOPEN( ---v_dir,v_file_name,'r');
                               P_LOCATION,
                               P_FILENAME,
                               'R');
      -- p_location,p_filename,'r',32767);
    
    EXCEPTION
      WHEN UTL_FILE.INVALID_PATH THEN
        ERRCODE := '2';
        ERRBUF  := ERRBUF || 'Invalid Path for ' ||
                   LTRIM(P_LOCATION || '/' || P_FILENAME) || CHR(0);
        RAISE STOP_PROCESSING;
      WHEN UTL_FILE.INVALID_MODE THEN
        ERRCODE := '2';
        ERRBUF  := ERRBUF || 'Invalid Mode for ' ||
                   LTRIM(P_LOCATION || '/' || P_FILENAME) || CHR(0);
        RAISE STOP_PROCESSING;
      WHEN UTL_FILE.INVALID_OPERATION THEN
        ERRCODE := '2';
        ERRBUF  := ERRBUF || 'Invalid operation for ' ||
                   LTRIM(P_LOCATION || '/' || P_FILENAME) || ' ' || SQLERRM ||
                   CHR(0);
        RAISE STOP_PROCESSING;
      WHEN OTHERS THEN
        ERRCODE := '2';
        ERRBUF  := '==============Cannot open ' || P_LOCATION || '/' ||
                   P_FILENAME || ' file';
        RAISE STOP_PROCESSING;
    END;
    ------------------
  
    ------------------Get lines---------------------------------
    V_STEP := 'Step 20';
    BEGIN
      V_READ_CODE := 1;
      WHILE V_READ_CODE <> 0 --End Of File
       LOOP
        ----
        BEGIN
          UTL_FILE.GET_LINE(V_FILE, V_LINE);
        EXCEPTION
          WHEN UTL_FILE.READ_ERROR THEN
            ERRBUF  := 'Read Error' || CHR(0);
            ERRCODE := '2';
            EXIT;
          WHEN NO_DATA_FOUND THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG, ' '); ---empty row
            FND_FILE.PUT_LINE(FND_FILE.LOG, ' '); ---empty row
            FND_FILE.PUT_LINE(FND_FILE.LOG,
                              '***********************READ COMPLETE******************************' ||
                              CHR(13));
            ERRBUF      := 'Read Complete' || CHR(0);
            V_READ_CODE := 0;
            EXIT;
          WHEN OTHERS THEN
            ERRBUF  := 'Other for Line Read' || CHR(0);
            ERRCODE := '2';
            EXIT;
        END;
        --------
      
        IF V_LINE IS NULL THEN
          ----dbms_output.put_line('Got empty line');
          NULL;
        ELSE
          V_STEP := 'Step 30';
          --------New line was received from file-----------
          V_LINE_NUMBER         := V_LINE_NUMBER + 1;
          V_LINE_IS_VALID_FLAG  := 'Y';
          V_VALID_ERROR_MESSAGE := NULL;
          V_STATUS              := 'SUCCESS';
        
          V_SEGMENT1             := XXCONV_URL_ATTACHMENTS_PKG.GET_FIELD_FROM_UTL_FILE_LINE(V_LINE,
                                                                                            1);
          V_ATTACHMENT_FILE_NAME := XXCONV_URL_ATTACHMENTS_PKG.GET_FIELD_FROM_UTL_FILE_LINE(V_LINE,
                                                                                            2);
        
          ---=================Validations========================
          BEGIN
            IF V_LINE_NUMBER = 1 AND P_IGNORE_FIRST_HEADERS_LINE = 'Y' THEN
              RAISE VALIDATION_ERROR; ---no validations for this headres line
            END IF;
            V_STEP := 'Step 40';
            ----------Check SEGMENT1------------REQUIRED----------------
            IF V_SEGMENT1 IS NULL THEN
              V_LINE_IS_VALID_FLAG  := 'N';
              V_STATUS              := 'ERROR';
              V_VALID_ERROR_MESSAGE := '======Line ' || V_LINE_NUMBER ||
                                       ' Validation Error:   SEGMENT1 IS MISSING';
              FND_FILE.PUT_LINE(FND_FILE.LOG,
                                V_VALID_ERROR_MESSAGE || CHR(13));
              RAISE VALIDATION_ERROR;
            END IF;
            V_STEP := 'Step 40.2';
            --------
            BEGIN
              SELECT MSI.INVENTORY_ITEM_ID
                INTO V_INVENTORY_ITEM_ID
                FROM MTL_SYSTEM_ITEMS_B MSI
               WHERE MSI.SEGMENT1 = V_SEGMENT1 ---from file
                 AND MSI.ORGANIZATION_ID = P_ORGANIZATION_ID; ---parameter
            EXCEPTION
              WHEN OTHERS THEN
                V_INVENTORY_ITEM_ID   := NULL;
                V_LINE_IS_VALID_FLAG  := 'N';
                V_STATUS              := 'ERROR';
                V_VALID_ERROR_MESSAGE := '======Line ' || V_LINE_NUMBER ||
                                         ' Validation Error:   Segment1=''' ||
                                         V_SEGMENT1 ||
                                         ''' in organization ' ||
                                         P_ORGANIZATION_ID ||
                                         ' DOES NOT EXIST in MTL_SYSTEM_ITEMS_B table';
                FND_FILE.PUT_LINE(FND_FILE.LOG,
                                  V_VALID_ERROR_MESSAGE || CHR(13));
                RAISE VALIDATION_ERROR;
            END;
            V_STEP := 'Step 40.3';
            --------
            BEGIN
              SELECT 1
                INTO V_NUMERIC_DUMMY
                FROM FND_ATTACHED_DOCUMENTS T
               WHERE T.ENTITY_NAME = 'MTL_SYSTEM_ITEMS'
                 AND T.CATEGORY_ID = P_CATEGORY_ID ---Item Picture
                 AND T.PK1_VALUE = P_ORGANIZATION_ID ---parameter
                 AND T.PK2_VALUE = V_INVENTORY_ITEM_ID ---selected value
                 AND ROWNUM = 1;
            
              V_LINE_IS_VALID_FLAG  := 'N';
              V_STATUS              := 'ERROR';
              V_VALID_ERROR_MESSAGE := '======Line ' || V_LINE_NUMBER ||
                                       ' This line will be ignored:   Attachment for Segment1=''' ||
                                       V_SEGMENT1 || ''' in organization ' ||
                                       P_ORGANIZATION_ID ||
                                       ' ALREADY EXISTS';
              FND_FILE.PUT_LINE(FND_FILE.LOG,
                                V_VALID_ERROR_MESSAGE || CHR(13));
              RAISE VALIDATION_ERROR;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
            V_STEP := 'Step 40.4';
            --------
            IF V_ATTACHMENT_FILE_NAME IS NULL THEN
              V_LINE_IS_VALID_FLAG  := 'N';
              V_STATUS              := 'ERROR';
              V_VALID_ERROR_MESSAGE := '======Line ' || V_LINE_NUMBER ||
                                       ' Validation Error:   File Name for URL IS MISSING';
              FND_FILE.PUT_LINE(FND_FILE.LOG,
                                V_VALID_ERROR_MESSAGE || CHR(13));
              RAISE VALIDATION_ERROR;
            END IF;
          
          EXCEPTION
            WHEN VALIDATION_ERROR THEN
              IF NOT
                  (V_LINE_NUMBER = 1 AND P_IGNORE_FIRST_HEADERS_LINE = 'Y') THEN
                V_THERE_ARE_NON_VALID_ROWS := 'Y';
              END IF;
              FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); ---empty line 
          END;
          ---=============the end of validations=================  
          IF V_LINE_IS_VALID_FLAG = 'N' THEN
            V_NUM_OF_NON_VALID_LINES := V_NUM_OF_NON_VALID_LINES + 1;
          ELSE
            V_NUM_OF_VALID_LINES := V_NUM_OF_VALID_LINES + 1;
          END IF;
        
          IF NOT (V_LINE_NUMBER = 1 AND P_IGNORE_FIRST_HEADERS_LINE = 'Y') AND
             V_LINE_IS_VALID_FLAG = 'Y' AND P_VALIDATE_ONLY_FLAG = 'N' AND
             (P_INVENTORY_ITEM_ID IS NULL OR
             V_INVENTORY_ITEM_ID = P_INVENTORY_ITEM_ID) THEN
          
            V_RESULT := XXCONV_URL_ATTACHMENTS_PKG.CREATE_URL_ATTACHMENT_FOR_ITEM(P_CATEGORY_ID          => P_CATEGORY_ID,
                                                                                  P_SEGMENT1             => V_SEGMENT1,
                                                                                  P_DATATYPE_ID          => P_DATATYPE_ID, ---5--URL-attachment,
                                                                                  P_URL                  => REPLACE(FND_PROFILE.VALUE('HELP_WEB_BASE_URL'),
                                                                                                                    'OA_HTML/',
                                                                                                                    'OA_MEDIA/') ||
                                                                                                            'Objet_Items/' ||
                                                                                                            V_ATTACHMENT_FILE_NAME ||
                                                                                                            '.pdf',
                                                                                  P_FUNCTION_NAME        => 'INVIDITM',
                                                                                  P_ENTITY_NAME          => 'MTL_SYSTEM_ITEMS',
                                                                                  P_PK1_VALUE            => P_ORGANIZATION_ID, --parameter 
                                                                                  P_PK2_VALUE            => V_INVENTORY_ITEM_ID,
                                                                                  P_PK3_VALUE            => NULL,
                                                                                  P_PK4_VALUE            => NULL,
                                                                                  P_PK5_VALUE            => NULL,
                                                                                  P_USER_ID              => FND_GLOBAL.USER_ID,
                                                                                  P_USAGE_TYPE           => 'O',
                                                                                  P_DOCUMENT_DESCRIPTION => V_SEGMENT1,
                                                                                  P_TITLE                => V_SEGMENT1);
          
            IF V_RESULT = 'SUCCESS' THEN
              V_NUM_OF_UPLOAD_SUCCESS := V_NUM_OF_UPLOAD_SUCCESS + 1;
            ELSE
              V_NUM_OF_UPLOAD_FAILURED := V_NUM_OF_UPLOAD_FAILURED + 1;
            END IF;
          END IF; ------IF NOT(v_line_number=1 AND p_ignore_first_headers_line='Y')...
        
        END IF; ----IF v_line IS NULL THEN...
      END LOOP;
    
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          '##############  No more data to read  #################' ||
                          CHR(13));
    END;
  
    ------------------Close flat file----------------------------
    UTL_FILE.FCLOSE(V_FILE);
  
    ------------------Display total information about this updload...----------------------------
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); --empty line
    FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13)); --empty line
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '***************************************************************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '********************TOTAL INFORMATION******************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '***************************************************************************' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=========There are ' || V_LINE_NUMBER ||
                      ' rows in our file ' || P_LOCATION || '/' ||
                      P_FILENAME || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=============' || V_NUM_OF_NON_VALID_LINES ||
                      ' rows ARE NON-VALID' || CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=============' || V_NUM_OF_UPLOAD_SUCCESS ||
                      ' item url attachments were SUCCESSFULY UPLOADED' ||
                      CHR(13));
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      '=============' || V_NUM_OF_UPLOAD_FAILURED ||
                      ' api uploads FAILURED' || CHR(13));
  
  EXCEPTION
    WHEN STOP_PROCESSING THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        '********STOP PROCESSING*********' || CHR(13));
    WHEN OTHERS THEN
      V_ERROR_MESSAGE := ' =============XXCONV_URL_ATTACHMENTS_PKG.UPLOAD_URL_ATTACHMENT_FOR_ITEM unexpected ERROR (' ||
                         V_STEP || ') : ' || SQLERRM;
      ERRCODE         := '2';
      ERRBUF          := V_ERROR_MESSAGE;
      FND_FILE.PUT_LINE(FND_FILE.LOG, V_ERROR_MESSAGE || CHR(13));
  END UPLOAD_URL_ATTACHMENT_FOR_ITEM;
  ---------------------------------------
  ----------------------------------------------
  FUNCTION GET_FIELD_FROM_UTL_FILE_LINE(P_LINE_STR     IN VARCHAR2,
                                        P_FIELD_NUMBER IN NUMBER)
    RETURN VARCHAR2 IS
    V_LAST_COMMA_POS              NUMBER;
    V_POS                         NUMBER;
    V_NUM_OF_COLUMNS_IN_THIS_LINE NUMBER;
    V_START_POS                   NUMBER;
    V_NEXT_COMMA_POS              NUMBER;
    V_LENGTH                      NUMBER;
  
  BEGIN
  
    IF P_LINE_STR IS NULL OR P_FIELD_NUMBER IS NULL OR P_FIELD_NUMBER <= 0 THEN
      RETURN '';
    END IF;
  
    SELECT INSTR(P_LINE_STR, ',', -1) INTO V_LAST_COMMA_POS FROM DUAL;
  
    IF V_LAST_COMMA_POS >= 1 THEN
      V_NUM_OF_COLUMNS_IN_THIS_LINE := 1;
      LOOP
        V_POS                         := INSTR(P_LINE_STR,
                                               ',',
                                               1,
                                               V_NUM_OF_COLUMNS_IN_THIS_LINE);
        V_NUM_OF_COLUMNS_IN_THIS_LINE := V_NUM_OF_COLUMNS_IN_THIS_LINE + 1;
        IF V_POS >= V_LAST_COMMA_POS OR V_POS = 0 THEN
          EXIT;
        END IF;
      END LOOP;
    END IF;
  
    -----return to_char(v_num_of_columns_in_this_line);
  
    IF P_FIELD_NUMBER = V_NUM_OF_COLUMNS_IN_THIS_LINE THEN
      ----this is last column in this line
      RETURN RTRIM(RTRIM(SUBSTR(P_LINE_STR, V_LAST_COMMA_POS + 1), ' '),
                   CHR(13));
    ELSE
      IF P_FIELD_NUMBER = 1 THEN
        V_START_POS := 1;
      ELSE
        V_START_POS := INSTR(P_LINE_STR, ',', 1, P_FIELD_NUMBER - 1) + 1;
      END IF;
      V_NEXT_COMMA_POS := INSTR(P_LINE_STR, ',', 1, P_FIELD_NUMBER);
      V_LENGTH         := V_NEXT_COMMA_POS - V_START_POS;
      RETURN LTRIM(RTRIM(SUBSTR(P_LINE_STR, V_START_POS, V_LENGTH), ' '),
                   ' ');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '';
  END GET_FIELD_FROM_UTL_FILE_LINE;
  ----------------------------------------------  
  FUNCTION CREATE_URL_ATTACHMENT_FOR_ITEM(P_CATEGORY_ID          IN NUMBER,
                                          P_SEGMENT1             IN VARCHAR2,
                                          P_DATATYPE_ID          IN NUMBER,
                                          P_URL                  IN VARCHAR2,
                                          P_FUNCTION_NAME        IN VARCHAR2,
                                          P_ENTITY_NAME          IN VARCHAR2,
                                          P_PK1_VALUE            IN VARCHAR2, --Organization_id  
                                          P_PK2_VALUE            IN VARCHAR2, --Inventory_item_Id
                                          P_PK3_VALUE            IN VARCHAR2,
                                          P_PK4_VALUE            IN VARCHAR2,
                                          P_PK5_VALUE            IN VARCHAR2,
                                          P_USER_ID              IN NUMBER,
                                          P_USAGE_TYPE           IN VARCHAR2,
                                          P_DOCUMENT_DESCRIPTION IN VARCHAR2,
                                          P_TITLE                IN VARCHAR2)
    RETURN VARCHAR2 IS
    V_STEP VARCHAR2(100);
    STOP_PROCCESSING EXCEPTION;
    V_NUMERIC_DUMMY      NUMBER;
    V_ATTACHMENT_SEQ_NUM NUMBER;
    V_ERROR_MESSAGE      VARCHAR2(1000);
    V_ATTACHMENT_EXISTS  NUMBER;
  BEGIN
    V_STEP := 'Step 1';
    ---------Check 2 parameters: p_pk1_value (Organization_id) and p_pk2_value (Inventory_item_Id)---------------
    BEGIN
      SELECT 1
        INTO V_NUMERIC_DUMMY
        FROM MTL_SYSTEM_ITEMS_B MSI
       WHERE MSI.ORGANIZATION_ID = P_PK1_VALUE --Organization_id 
         AND MSI.INVENTORY_ITEM_ID = P_PK2_VALUE; --Inventory_item_Id      
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          '======ERROR=======inventory_item_id=' ||
                          P_PK2_VALUE ||
                          ' does not exist in organization_id=' ||
                          P_PK1_VALUE || CHR(13));
        RAISE STOP_PROCCESSING;
    END;
    ---------Check existing attachments for this item-organization-----------
    ------------------and calculate SEQ_NUM for new attachment---------------
    BEGIN
      SELECT NVL(MAX(T.SEQ_NUM) + 10, 10)
        INTO V_ATTACHMENT_SEQ_NUM
        FROM FND_ATTACHED_DOCUMENTS T
       WHERE T.ENTITY_NAME = 'MTL_SYSTEM_ITEMS'
         AND T.CATEGORY_ID = P_CATEGORY_ID
         AND T.PK1_VALUE = P_PK1_VALUE --Organization_id 
         AND T.PK2_VALUE = P_PK2_VALUE; --Inventory_item_Id       
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    -----------------------------
    BEGIN
      FND_WEBATTCH.ADD_ATTACHMENT(SEQ_NUM              => V_ATTACHMENT_SEQ_NUM ---10
                                 ,
                                  CATEGORY_ID          => P_CATEGORY_ID,
                                  DOCUMENT_DESCRIPTION => P_DOCUMENT_DESCRIPTION,
                                  DATATYPE_ID          => P_DATATYPE_ID ---5  ---URL-attachment
                                 ,
                                  TEXT                 => NULL,
                                  FILE_NAME            => NULL,
                                  URL                  => P_URL,
                                  FUNCTION_NAME        => P_FUNCTION_NAME ----'INVIDITM'
                                 ,
                                  ENTITY_NAME          => P_ENTITY_NAME ----'MTL_SYSTEM_ITEMS'
                                 ,
                                  PK1_VALUE            => P_PK1_VALUE ----organization_id  
                                 ,
                                  PK2_VALUE            => P_PK2_VALUE ----Inventory_item_Id
                                 ,
                                  PK3_VALUE            => NULL,
                                  PK4_VALUE            => NULL,
                                  PK5_VALUE            => NULL,
                                  MEDIA_ID             => NULL,
                                  USER_ID              => P_USER_ID,
                                  USAGE_TYPE           => P_USAGE_TYPE,
                                  TITLE                => P_TITLE);
      COMMIT;
      -------
      BEGIN
        SELECT 1
          INTO V_ATTACHMENT_EXISTS
          FROM FND_ATTACHED_DOCUMENTS T
         WHERE T.ENTITY_NAME = 'MTL_SYSTEM_ITEMS'
           AND T.CATEGORY_ID = P_CATEGORY_ID ---Category 
           AND T.PK1_VALUE = P_PK1_VALUE ---Organization_id 
           AND T.PK2_VALUE = P_PK2_VALUE ---Inventory_item_Id
           AND ROWNUM = 1;
      
        RETURN 'SUCCESS';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN 'FAILURE';
      END;
      -------
    
    EXCEPTION
      WHEN OTHERS THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          '======ERROR=======We cannot to add attachment for item ''' ||
                          P_SEGMENT1 || ''' : ' || SQLERRM || CHR(13));
        RETURN 'FAILURE';
    END;
    ------------------------
  EXCEPTION
    WHEN STOP_PROCCESSING THEN
      RETURN 'FAILURE';
    WHEN OTHERS THEN
      V_ERROR_MESSAGE := ' =============XXCONV_URL_ATTACHMENTS_PKG.create_url_attachment_for_item unexpected ERROR (' ||
                         V_STEP || ') : ' || SQLERRM;
      FND_FILE.PUT_LINE(FND_FILE.LOG, V_ERROR_MESSAGE || CHR(13));
      RETURN 'FAILURE';
  END CREATE_URL_ATTACHMENT_FOR_ITEM;
  ----------------------------------------------    

END XXCONV_URL_ATTACHMENTS_PKG;
/

