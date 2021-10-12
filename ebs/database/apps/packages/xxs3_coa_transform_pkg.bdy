CREATE OR REPLACE PACKAGE BODY xxs3_coa_transform_pkg

----------------------------------------------------------------------------
--  name:            xxs3_coa_transform_pkg
--  create by:       TCS
--  Revision:        1.0
--  creation date:   16/11/2015
----------------------------------------------------------------------------
--  purpose :        Generic package body for CoA transformation.
--                   Calling programs will call procedure 
--                   coa_transform and will pass the legacy CoA GL string 
--                   segments.This procedure will return back the S3
--                   CoA GL string
----------------------------------------------------------------------------
--  ver  date        name                         desc
--  1.0  16/11/2015  TCS                          Initial Build
----------------------------------------------------------------------------

 AS
  g_status         VARCHAR2(1) := 'S';
  g_status_message VARCHAR2(4000) := NULL;
  g_module         VARCHAR2(4000) := NULL;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the transform_id for entity type 'ALL' and account type 'ALL'
  --          from table xxcoa_transform_key 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- -------------------------------------------------------------------------------------------- 
  PROCEDURE get_all_transform_id(p_trx_type         IN VARCHAR2
                                ,p_all_transform_id OUT NUMBER
                                ,g_status           OUT VARCHAR2
                                ,g_status_message   OUT VARCHAR2) IS
  
  
  
  BEGIN
    g_status           := 'S';
    p_all_transform_id := 0;
  
    fnd_file.put_line(fnd_file.log
                     ,'TRX :' || p_trx_type);
    BEGIN
      SELECT transform_id
      INTO p_all_transform_id
      FROM xxobjt.xxcoa_transform_key
      WHERE entity_type = p_trx_type
      AND account_type = 'ALL';
    
      fnd_file.put_line(fnd_file.log
                       ,'p_all_transform_id :' || p_all_transform_id);
    
    EXCEPTION
      WHEN no_data_found THEN
        p_all_transform_id := NULL;
        g_status           := 'E';
        g_status_message   := g_status_message || chr(13) ||
                              'No data exists for transaction type and ALL combo';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      WHEN OTHERS THEN
        p_all_transform_id := NULL;
        g_status           := 'E';
        g_status_message   := g_status_message || chr(13) ||
                              'Unexpected error during execution of get_all_transform_id process' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
    END;
    --RETURN p_all_transform_id;
  
  END get_all_transform_id;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: Get the account type like 'COGS','SALES' etc.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION get_account_type(p_account        IN VARCHAR2
                           ,g_status         OUT VARCHAR2
                           ,g_status_message OUT VARCHAR2) RETURN VARCHAR2 IS
  
    l_acct_type VARCHAR2(50) := NULL;
  
  BEGIN
    BEGIN
      g_status := 'S';
    
      g_module := 'GET_ACCOUNT_TYPE';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Inside GET_ACCOUNT_TYPE');
    
      fnd_file.put_line(fnd_file.log
                       ,'Inside get_account_type : Params : p_account : ' ||
                        p_account || ' ,g_status : ' || g_status ||
                        ' ,g_status_message : ' || g_status_message);
    
    
      SELECT description
      INTO l_acct_type
      FROM fnd_lookup_values_vl
      WHERE lookup_type = 'XXS3_COA_ACCOUNT_TYPE'
      AND lookup_code = substr(p_account
                             ,1
                             ,1)
      AND enabled_flag = 'Y'
           --AND LANGUAGE = userenv('LANG')
      AND trunc(SYSDATE) BETWEEN nvl(start_date_active
                                   ,trunc(SYSDATE)) AND
            nvl(end_date_active
               ,trunc(SYSDATE));
    
    EXCEPTION
      WHEN no_data_found THEN
        l_acct_type      := NULL;
        g_status         := 'E';
        g_status_message := g_status_message || chr(13) ||
                            'Account does not exist in XXS3_COA_ACCOUNT_TYPE lookup : ' ||
                            p_account;
      
        fnd_file.put_line(fnd_file.output
                         ,g_status_message);
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      WHEN OTHERS THEN
        l_acct_type      := NULL;
        g_status         := 'E';
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of get_account_type process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
  
    fnd_file.put_line(fnd_file.log
                     ,'After get_account_type : Params : p_account : ' ||
                      p_account || ' ,g_status : ' || g_status ||
                      ' ,g_status_message : ' || g_status_message ||
                      ' ,l_acct_type : ' || l_acct_type);
  
  
    RETURN l_acct_type;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of GET_ACCOUNT_TYPE');
  
  END get_account_type;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: Fetch transform id based on transaction type and account type
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE fetch_coa_transform_id(p_trx_type       IN VARCHAR2 --e.g PO,ITEM,ALL,GL
                                  ,p_acct_type      IN VARCHAR2 --e.g SALES,COGS,EXPENSE etc.
                                  ,p_transform_id   OUT VARCHAR2
                                  ,g_status         OUT VARCHAR2
                                  ,g_status_message OUT VARCHAR2) AS
  
    --l_transform_id NUMBER;
  
  BEGIN
    g_status := 'S';
    g_module := 'FETCH_COA_TRANSFORM_ID';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside FETCH_COA_TRANSFORM_ID');
  
    BEGIN
    
      SELECT transform_id
      INTO p_transform_id
      FROM xxobjt.xxcoa_transform_key
      WHERE entity_type = p_trx_type
           --AND region = p_region
      AND account_type = p_acct_type;
    
    EXCEPTION
      WHEN no_data_found THEN
        p_transform_id   := NULL;
        g_status         := 'E';
        g_status_message := g_status_message || chr(13) ||
                            'Invalid transaction type and account type combination';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      WHEN OTHERS THEN
        p_transform_id   := NULL;
        g_status         := 'E';
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of fetch_coa_transform_id process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of FETCH_COA_TRANSFORM_ID');
  
  END fetch_coa_transform_id;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Comapny segment value from the Company
  --          master table xxcoa_company for a valid combination of transform id and legacy
  --          company segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_company_master(p_legacy_company_val IN VARCHAR2
                             ,p_transform_id       IN NUMBER
                             ,p_company_id         OUT NUMBER
                             ,p_all_transform_id   IN NUMBER)
  
   RETURN VARCHAR2 IS
  
    l_s3_company     VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,'coa_company_master : p_transform_id :' ||
                      p_transform_id);
  
    g_module := 'COA_COMPANY_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_COMPANY_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_legacy_company_val :' ||
                              p_legacy_company_val || ' ,p_transform_id : ' ||
                              p_transform_id);
  
    BEGIN
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_company
      WHERE transform_id = p_transform_id;
    
      fnd_file.put_line(fnd_file.log
                       ,'coa_company_master : p_transform_id :' ||
                        p_transform_id);
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_COMPANY_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_company
                ,company_id
                ,error_message
          INTO l_s3_company
              ,p_company_id
              ,l_error
          FROM xxobjt.xxcoa_company
          WHERE transform_id = p_transform_id
          AND legacy_company = p_legacy_company_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Company segment error: ' || l_error;
          END IF;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) || 'Params : l_s3_company : ' ||
                                    l_s3_company || ' ,p_company_id : ' ||
                                    p_company_id);
        
        
        EXCEPTION
        
          WHEN no_data_found THEN
            BEGIN
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Exact combination of transform_id and legacy_value does not exist');
            
            
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_company
                    ,company_id
                    ,error_message
              INTO l_s3_company
                  ,p_company_id
                  ,l_error
              FROM xxobjt.xxcoa_company
              WHERE transform_id = p_transform_id
              AND legacy_company = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message || chr(13) ||
                                    'Company segment error: ' || l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message || chr(13) ||
                                        'Params : l_s3_company : ' ||
                                        l_s3_company || ' ,p_company_id : ' ||
                                        p_company_id);
            
            
            EXCEPTION
              WHEN no_data_found THEN
                l_s3_company := NULL;
                p_company_id := NULL;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_company     := NULL;
                p_company_id     := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'More than one mapping found for company :' ||
                                    p_legacy_company_val || chr(10) ||
                                    SQLCODE || chr(10) || SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            
              WHEN OTHERS THEN
                l_s3_company     := NULL;
                p_company_id     := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'Unexpected error during execution of coa_company_master process' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            END;
          
          WHEN OTHERS THEN
            l_s3_company     := NULL;
            p_company_id     := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_company_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
          
        END;
      
        -- If no data exists for the transform_id
      ELSE
        IF l_count_trans_id = 0
        THEN
          BEGIN
          
            g_module := 'COA_COMPANY_MASTER : CHECK ALL-LEGACY COMBINATION';
          
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_company
                  ,company_id
                  ,error_message
            INTO l_s3_company
                ,p_company_id
                ,l_error
            FROM xxobjt.xxcoa_company
            WHERE transform_id = p_all_transform_id
            AND legacy_company = p_legacy_company_val;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Company segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message || chr(13) ||
                                      'Params : l_s3_company : ' ||
                                      l_s3_company || ' ,p_company_id : ' ||
                                      p_company_id);
          
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_company := NULL;
              p_company_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
          
            WHEN too_many_rows THEN
              l_s3_company     := NULL;
              p_company_id     := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one mapping found for company :' ||
                                  p_legacy_company_val || chr(10) ||
                                  SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_company     := NULL;
              p_company_id     := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_company_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
            
          END;
        END IF;
      END IF;
    END;
    RETURN l_s3_company;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_COMPANY_MASTER' || chr(13) ||
                              'Output : l_s3_company : ' || l_s3_company ||
                              ' ,p_company_id : ' || p_company_id);
  
  END coa_company_master;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Company segment value from the company
  --          exception table xxcoa_company_exception1 for a valid combination of transform id 
  --          and legacy cimpany segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_company_exception1(p_legacy_company_val IN VARCHAR2
                                 ,p_division           IN VARCHAR2
                                 ,p_s3_company         IN VARCHAR2
                                 ,p_transform_id       IN NUMBER
                                 ,p_company_id         IN NUMBER
                                 ,p_all_transform_id   IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_company_exp VARCHAR2(25);
    l_error          VARCHAR2(100);
    l_rank           NUMBER := 0;
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,'coa_company_master : exception1 : p_transform_id :' ||
                      p_transform_id);
  
    g_module := 'COA_COMPANY_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_COMPANY_EXCEPTION1');
  
    BEGIN
    
      g_module := 'COA_COMPANY_EXCEPTION1 : DIVISION DEPENDENT';
    
      -- Check for exception of transform_id and leagcy_value combination 
      SELECT s3_company
            ,rank
      INTO l_s3_company_exp
          ,l_rank
      FROM xxobjt.xxcoa_company_exception1
      WHERE transform_id = p_transform_id
      AND legacy_company = p_legacy_company_val
      AND division = p_division
      AND company_id = p_company_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for transform_id and legacy_value exists');
    
    
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
        
          ---- Check for exception of Trx_Type-ALL and leagcy_value combination 
          SELECT s3_company
                ,rank
          INTO l_s3_company_exp
              ,l_rank
          FROM xxobjt.xxcoa_company_exception1
          WHERE transform_id = p_all_transform_id
          AND legacy_company = p_legacy_company_val
          AND division = p_division
          AND company_id = p_company_id;
        
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exception for Trx_Type-ALL transform_id and legacy_value exists');
        
        
        EXCEPTION
          WHEN no_data_found THEN
            l_s3_company_exp := p_s3_company;
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exception for Trx_Type-ALL transform_id and legacy_value does not exist');
          
          WHEN OTHERS THEN
            l_s3_company_exp := NULL;
          
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_company_exception1 process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'In NO_DATA_FOUND : ' ||
                                      g_status_message);
          
        
        END;
      
    
      WHEN OTHERS THEN
        l_s3_company_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_company_exception1 process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'In BEGIN WHEN OTHERS: ' ||
                                  g_status_message);
      
    
    END;
    RETURN l_s3_company_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_COMPANY_EXCEPTION1');
  
  END coa_company_exception1;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Company segment value from the company
  --          exception table xxcoa_company_exception2 for a valid combination of transform id 
  --          and legacy cimpany segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_company_exception2(p_legacy_company_val IN VARCHAR2
                                 ,p_s3_org             IN VARCHAR2
                                 ,p_s3_company         IN VARCHAR2
                                 ,p_transform_id       IN NUMBER
                                 ,p_company_id         IN NUMBER
                                 ,p_all_transform_id   IN NUMBER)
    RETURN VARCHAR2 IS
  
  
    l_s3_company_exp     VARCHAR2(25);
    l_error              VARCHAR2(100);
    l_excep_trasnform_id NUMBER;
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,'coa_company_master : exception2 : p_transform_id :' ||
                      p_transform_id);
  
    g_module := 'COA_COMPANY_EXCEPTION2';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_COMPANY_EXCEPTION2');
  
    BEGIN
      -- Check for exception of legacy_id, transform_id and S3_org combination  
      SELECT s3_company
      INTO l_s3_company_exp
      FROM xxobjt.xxcoa_company_exception2
      WHERE transform_id = p_transform_id
      AND inventory_org = p_s3_org
      AND company_id = p_company_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
    
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_company_exp := p_s3_company;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination does not');
      
    
      WHEN OTHERS THEN
        l_s3_company_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_company_exception2 process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
    RETURN l_s3_company_exp;
  END coa_company_exception2;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 InterCompany segment value from the InterCompany
  --          master table xxcoa_intercompany for a valid combination of transform id and legacy
  --          company segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_intercompany_master(p_legacy_intercompany_val IN VARCHAR2
                                  ,p_transform_id            IN NUMBER
                                  ,p_intercompany_id         OUT NUMBER
                                  ,p_all_transform_id        IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_intercomp   VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  
  BEGIN
  
    g_module := 'COA_INTERCOMPANY_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_INTERCOMPANY_MASTER');
  
    fnd_file.put_line(fnd_file.log
                     ,'coa_intercompany_master : p_transform_id : ' ||
                      p_transform_id);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_legacy_intercompany_val :' ||
                              p_legacy_intercompany_val ||
                              ' ,p_transform_id : ' || p_transform_id);
  
    BEGIN
    
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_intercompany
      WHERE transform_id = p_transform_id;
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_INTERCOMPANY_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_intercompany
                ,intercompany_id
                ,error_message
          INTO l_s3_intercomp
              ,p_intercompany_id
              ,l_error
          FROM xxobjt.xxcoa_intercompany
          WHERE transform_id = p_transform_id
          AND legacy_intercompany_value = p_legacy_intercompany_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Intercompany segment error: ' || l_error;
          END IF;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) || 'Params : l_s3_intercomp : ' ||
                                    l_s3_intercomp ||
                                    ' ,p_intercompany_id : ' ||
                                    p_intercompany_id);
        
        EXCEPTION
        
          WHEN no_data_found THEN
            BEGIN
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Exact combination of transform_id and legacy_value does not exist');
            
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_intercompany
                    ,intercompany_id
                    ,error_message
              INTO l_s3_intercomp
                  ,p_intercompany_id
                  ,l_error
              FROM xxobjt.xxcoa_intercompany
              WHERE transform_id = p_transform_id
              AND legacy_intercompany_value = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message || chr(13) ||
                                    'Intercompany segment error: ' ||
                                    l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message || chr(13) ||
                                        'Params : l_s3_intercompany : ' ||
                                        l_s3_intercomp ||
                                        ' ,p_intercompany_id : ' ||
                                        p_intercompany_id);
            
            EXCEPTION
            
              WHEN no_data_found THEN
                l_s3_intercomp    := NULL;
                p_intercompany_id := NULL;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_intercomp    := NULL;
                p_intercompany_id := NULL;
                g_status_message  := g_status_message || chr(13) ||
                                     'More than one mapping found for intercompany :' ||
                                     p_legacy_intercompany_val || chr(10) ||
                                     SQLCODE || chr(10) || SQLERRM;
              
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            
              WHEN OTHERS THEN
                l_s3_intercomp    := NULL;
                p_intercompany_id := NULL;
                g_status_message  := g_status_message || chr(13) ||
                                     'Unexpected error during execution of coa_intercompany_master process' ||
                                     chr(10) || SQLCODE || chr(10) ||
                                     SQLERRM;
              
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            END;
          
        
          WHEN OTHERS THEN
            l_s3_intercomp    := NULL;
            p_intercompany_id := NULL;
            g_status_message  := g_status_message || chr(13) ||
                                 'Unexpected error during execution of coa_intercompany_master process' ||
                                 chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
        END;
      
        -- If no data exists for the transform_id
      ELSE
        IF l_count_trans_id = 0
        THEN
          BEGIN
          
            g_module := 'COA_INTERCOMPANY_MASTER : CHECK ALL-LEGACY COMBINATION';
          
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_intercompany
                  ,intercompany_id
                  ,error_message
            INTO l_s3_intercomp
                ,p_intercompany_id
                ,l_error
            FROM xxobjt.xxcoa_intercompany
            WHERE transform_id = p_all_transform_id
            AND legacy_intercompany_value = p_legacy_intercompany_val;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Intercompany segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message);
          
          EXCEPTION
          
            WHEN no_data_found THEN
              l_s3_intercomp    := NULL;
              p_intercompany_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_intercomp    := NULL;
              p_intercompany_id := NULL;
              g_status_message  := g_status_message || chr(13) ||
                                   'More than one mapping found for intercompany :' ||
                                   p_legacy_intercompany_val || chr(10) ||
                                   SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
          
            WHEN OTHERS THEN
              l_s3_intercomp    := NULL;
              p_intercompany_id := NULL;
              g_status_message  := g_status_message || chr(13) ||
                                   'Unexpected error during execution of coa_intercompany_master process' ||
                                   chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
          END;
        END IF;
      END IF;
    END;
  
    RETURN l_s3_intercomp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_INTERCOMPANY_MASTER' || chr(13) ||
                              'Output : l_s3_intercompany : ' ||
                              l_s3_intercomp || ' ,p_intercompany_id : ' ||
                              p_intercompany_id);
  
  END coa_intercompany_master;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 InterCompany segment value from the intercompany
  --          exception table xxcoa_intercompany_exception1 for a valid combination of transform id 
  --          and legacy intercompany segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_intercompany_exception1(p_legacy_intercompany_val IN VARCHAR2
                                      ,p_s3_intercomp            IN VARCHAR2
                                      ,p_division                IN VARCHAR2
                                      ,p_transform_id            IN NUMBER
                                      ,p_intercompany_id         IN NUMBER
                                      ,p_all_transform_id        IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_intercomp_exp VARCHAR2(25);
    l_error            VARCHAR2(100);
    l_rank             NUMBER := 0;
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,'coa_intercompany_master : exception1 : p_transform_id :' ||
                      p_transform_id);
  
    g_module := 'COA_INTERCOMPANY_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_INTERCOMPANY_EXCEPTION1');
  
    BEGIN
    
      g_module := 'COA_COMPANY_EXCEPTION1 : DIVISION DEPENDENT';
    
      -- Check for exception of transform_id and leagcy_value combination 
      SELECT s3_intercompany
            ,rank
      INTO l_s3_intercomp_exp
          ,l_rank
      FROM xxobjt.xxcoa_intercompany_exception1
      WHERE transform_id = p_transform_id
      AND legacy_intercompany = p_legacy_intercompany_val
      AND division = p_division
      AND intercompany_id = p_intercompany_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for transform_id and legacy_value exists');
    
    
    EXCEPTION
      WHEN no_data_found THEN
      
        BEGIN
          ---- Check for exception of Trx_Type-ALL and leagcy_value combination 
          SELECT s3_intercompany
                ,rank
          INTO l_s3_intercomp_exp
              ,l_rank
          FROM xxobjt.xxcoa_intercompany_exception1
          WHERE transform_id = p_all_transform_id
          AND legacy_intercompany = p_legacy_intercompany_val
          AND division = p_division
          AND intercompany_id = p_intercompany_id;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exception for Trx_Type-ALL transform_id and legacy_value exists');
        
        EXCEPTION
          WHEN no_data_found THEN
            l_s3_intercomp_exp := p_s3_intercomp;
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exception for Trx_Type-ALL transform_id and legacy_value does not exist');
          
          WHEN OTHERS THEN
            l_s3_intercomp_exp := NULL;
          
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_Intercompany_all_exp_div_transform process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'In NO_DATA_FOUND : ' ||
                                      g_status_message);
          
        END;
      
    
      WHEN OTHERS THEN
        l_s3_intercomp_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_Intercompany_all_exp_div_transform process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'In BEGIN WHEN OTHERS: ' ||
                                  g_status_message);
    END;
    RETURN l_s3_intercomp_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_INTERCOMPANY_EXCEPTION1');
  
  END coa_intercompany_exception1;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 InterCompany segment value from the intercompany
  --          exception table xxcoa_intercompany_exception2 for a valid combination of transform id 
  --          and legacy intercompany segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_intercompany_exception2(p_legacy_intercompany_val IN VARCHAR2
                                      ,p_s3_intercomp            IN VARCHAR2
                                      ,p_s3_org                  IN VARCHAR2
                                      ,p_transform_id            IN NUMBER
                                      ,p_intercompany_id         IN NUMBER
                                      ,p_all_transform_id        IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_intercomp_exp   VARCHAR2(25);
    l_error              VARCHAR2(100);
    l_excep_trasnform_id NUMBER;
    l_rank               NUMBER;
  
  BEGIN
  
    g_module := 'COA_INTERCOMPANY_EXCEPTION2';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_INTERCOMPANY_EXCEPTION2');
  
    fnd_file.put_line(fnd_file.log
                     ,'p_s3_org =  :' || p_s3_org);
    fnd_file.put_line(fnd_file.log
                     ,'p_transform_id =  :' || p_transform_id);
  
    -- If S3_org = 'GIM' for the transformtion_id
    IF p_s3_org = 'GIM'
       AND p_transform_id = 3
    THEN
      l_s3_intercomp_exp := '000';
    
    
      fnd_file.put_line(fnd_file.log
                       ,'Intercompany FROM exp2 :' || l_s3_intercomp_exp);
    
    ELSE
      BEGIN
        -- Check for exception of legacy_id, transform_id and S3_org combination  
        SELECT s3_intercompany
        INTO l_s3_intercomp_exp
        FROM xxobjt.xxcoa_intercompany_exception2
        WHERE transform_id = p_transform_id
        AND inventory_org = p_s3_org
        AND intercompany_id = p_intercompany_id;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
      
      EXCEPTION
        WHEN no_data_found THEN
          l_s3_intercomp_exp := p_s3_intercomp;
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exception for legacy_id, transform_id and S3_org combination does not');
        
        WHEN OTHERS THEN
          l_s3_intercomp_exp := NULL;
        
          g_status_message := g_status_message || chr(13) ||
                              'Unexpected error during execution of coa_company_exception2 process' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => g_status_message);
        
      
      END;
    END IF;
  
    RETURN l_s3_intercomp_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_INTERCOMPANY_EXCEPTION2');
  
  END coa_intercompany_exception2;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Account segment value from the Account
  --          master table xxcoa_account for a valid combination of transform id and legacy
  --          account segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_account_master(p_legacy_account_val IN VARCHAR2
                             ,p_transform_id       IN NUMBER
                             ,p_account_id         OUT NUMBER
                             ,p_all_transform_id   IN NUMBER) RETURN VARCHAR2 IS
  
    l_s3_account     VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  BEGIN
  
    g_module := 'COA_ACCOUNT_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_ACCOUNT_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_legacy_account_val :' ||
                              p_legacy_account_val || ' ,p_transform_id : ' ||
                              p_transform_id);
  
    BEGIN
    
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_account
      WHERE transform_id = p_transform_id;
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_ACCOUNT_MASTER : CHECK EXACT COMBINATION';
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_account
                ,account_id
                ,error_message
          INTO l_s3_account
              ,p_account_id
              ,l_error
          FROM xxobjt.xxcoa_account
          WHERE transform_id = p_transform_id
          AND legacy_account = p_legacy_account_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Account segment error: ' || l_error;
          END IF;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) || 'Params : l_s3_account : ' ||
                                    l_s3_account || ' ,p_account_id : ' ||
                                    p_account_id);
        
        EXCEPTION
        
          WHEN no_data_found THEN
            BEGIN
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Exact combination of transform_id and legacy_value does not exist');
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_account
                    ,account_id
                    ,error_message
              INTO l_s3_account
                  ,p_account_id
                  ,l_error
              FROM xxobjt.xxcoa_account
              WHERE transform_id = p_transform_id
              AND legacy_account = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message ||
                                    'Account segment error: ' || chr(13) ||
                                    l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message || chr(13) ||
                                        'Params : l_s3_account : ' ||
                                        l_s3_account || ' ,p_account_id : ' ||
                                        p_account_id);
            
            EXCEPTION
              WHEN no_data_found THEN
                l_s3_account := NULL;
                p_account_id := NULL;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_account     := NULL;
                p_account_id     := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'More than one mapping found for company :' ||
                                    p_legacy_account_val || chr(10) ||
                                    SQLCODE || chr(10) || SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
              WHEN OTHERS THEN
                l_s3_account     := NULL;
                p_account_id     := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'Unexpected error during execution of coa_company_master process' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
            END;
          WHEN OTHERS THEN
            l_s3_account     := NULL;
            p_account_id     := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_company_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
        END;
        -- If no data exists for the transform_id
      ELSE
        IF l_count_trans_id = 0
        THEN
          BEGIN
          
            g_module := 'COA_ACCOUNT_MASTER : CHECK ALL-LEGACY COMBINATION';
          
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_account
                  ,account_id
                  ,error_message
            INTO l_s3_account
                ,p_account_id
                ,l_error
            FROM xxobjt.xxcoa_account
            WHERE transform_id = p_all_transform_id
            AND legacy_account = p_legacy_account_val;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Account segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message || chr(13) ||
                                      'Params : l_s3_account : ' ||
                                      l_s3_account || ' ,p_account_id : ' ||
                                      p_account_id);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_account := NULL;
              p_account_id := NULL;
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_account     := NULL;
              p_account_id     := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one mapping found for company :' ||
                                  p_legacy_account_val || chr(10) ||
                                  SQLCODE || chr(10) || SQLERRM;
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_account     := NULL;
              p_account_id     := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_company_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
            
          END;
        END IF;
      END IF;
    END;
  
    RETURN l_s3_account;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_ACCOUNT_MASTER' || chr(13) ||
                              'Output : l_s3_account : ' || l_s3_account ||
                              ' ,g_account_id : ' || p_account_id);
  
  END coa_account_master;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Account segment value from the Account
  --          exception table xxcoa_account_exception1 for a valid combination of transform id 
  --          and legacy Account segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_account_exception1(p_legacy_account_val IN VARCHAR2
                                 ,p_s3_account         IN VARCHAR2
                                 ,p_s3_org             IN VARCHAR2
                                 ,p_transform_id       IN NUMBER
                                 ,p_account_id         IN NUMBER
                                 ,p_all_transform_id   IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_account_exp     VARCHAR2(25);
    l_error              VARCHAR2(100);
    l_excep_trasnform_id NUMBER;
    l_rank               NUMBER;
  
  BEGIN
  
    g_module := 'COA_ACCOUNT_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_ACCOUNT_EXCEPTION1');
  
    BEGIN
      -- Check for exception of legacy_id, transform_id and S3_org combination  
      SELECT s3_account
      INTO l_s3_account_exp
      FROM xxobjt.xxcoa_account_exception1
      WHERE transform_id = p_transform_id
      AND inventory_org = p_s3_org
      AND account_id = p_account_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_account_exp := p_s3_account;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination does not');
      
      WHEN OTHERS THEN
        l_s3_account_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_company_exception2 process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
  
    RETURN l_s3_account_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_ACCOUNT_EXCEPTION1');
  
  END coa_account_exception1;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 department segment value from the department
  --          master table xxcoa_department for a valid combination of transform id and legacy
  --          department segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION coa_department_master(p_legacy_dept_val  IN VARCHAR2
                                ,p_transform_id     IN NUMBER
                                ,p_department_id    OUT NUMBER
                                ,p_all_transform_id IN VARCHAR2)
  
   RETURN VARCHAR2 IS
  
    l_s3_department  VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  BEGIN
  
    g_module := 'COA_DEPARTMENT_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_DEPARTMENT_MASTER');
  
    fnd_file.put_line(fnd_file.log
                     ,'Inside Deparment master : p_legacy_dept_val : ' ||
                      p_legacy_dept_val);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_legacy_dept_val :' ||
                              p_legacy_dept_val || ' ,p_transform_id : ' ||
                              p_transform_id);
  
    BEGIN
    
    
    
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_department
      WHERE transform_id = p_transform_id;
      -- If data exists for the transform_id
    
      IF l_count_trans_id > 0
      THEN
        BEGIN
          g_module := 'COA_DEPARTMENT_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_department
                ,department_id
                ,error_message
          INTO l_s3_department
              ,p_department_id
              ,l_error
          FROM xxobjt.xxcoa_department
          WHERE transform_id = p_transform_id
          AND legacy_department = p_legacy_dept_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Department segment error: ' || l_error;
          END IF;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) ||
                                    'Params : l_s3_department : ' ||
                                    l_s3_department ||
                                    ' ,p_department_id : ' ||
                                    p_department_id);
        
        EXCEPTION
          WHEN no_data_found THEN
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exact combination of transform_id and legacy_value does not exist');
            BEGIN
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_department
                    ,department_id
                    ,error_message
              INTO l_s3_department
                  ,p_department_id
                  ,l_error
              FROM xxobjt.xxcoa_department
              WHERE transform_id = p_transform_id
              AND legacy_department = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message || chr(13) ||
                                    'Department segment error: ' || l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message);
            
            EXCEPTION
              WHEN no_data_found THEN
                l_s3_department := NULL;
                p_department_id := NULL;
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_department  := NULL;
                p_department_id  := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'More than one mapping found for department :' ||
                                    p_legacy_dept_val || chr(10) || SQLCODE ||
                                    chr(10) || SQLERRM;
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              WHEN OTHERS THEN
                l_s3_department  := NULL;
                p_department_id  := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'Unexpected error during execution of coa_department_master process' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            END;
          WHEN OTHERS THEN
            l_s3_department  := NULL;
            p_department_id  := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_department_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
          
        END;
      
        fnd_file.put_line(fnd_file.log
                         ,'After If : l_s3_department : ' ||
                          l_s3_department);
      
        -- If no data exists for the transform_id
      ELSE
        IF l_count_trans_id = 0
        THEN
          BEGIN
            g_module := 'COA_DEPARTMENT_MASTER : CHECK ALL-LEGACY COMBINATION';
          
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_department
                  ,department_id
                  ,error_message
            INTO l_s3_department
                ,p_department_id
                ,l_error
            FROM xxobjt.xxcoa_department
            WHERE transform_id = p_all_transform_id
            AND legacy_department = p_legacy_dept_val;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Department segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_department := NULL;
              p_department_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_department  := NULL;
              p_department_id  := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one mapping found for department :' ||
                                  p_legacy_dept_val || chr(10) || SQLCODE ||
                                  chr(10) || SQLERRM;
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_department  := NULL;
              p_department_id  := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_department_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
          END;
        END IF;
      END IF;
    END;
    RETURN l_s3_department;
  
    fnd_file.put_line(fnd_file.log
                     ,'After End : l_s3_department : ' || l_s3_department);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_DEPARTMENT_MASTER');
  
  END coa_department_master;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Department segment value from the Department
  --          exception table xxcoa_department_exception1 for a valid combination of transform id 
  --          and legacy Department segment value
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION coa_department_exception1(p_legacy_dept_val  IN VARCHAR2
                                    ,p_s3_org           IN VARCHAR2
                                    ,p_s3_department    IN VARCHAR2
                                    ,p_transform_id     IN NUMBER
                                    ,p_department_id    IN NUMBER
                                    ,p_all_transform_id IN NUMBER)
    RETURN VARCHAR2 IS
  
  
    l_s3_department_exp VARCHAR2(25);
    l_error             VARCHAR2(100);
  
  BEGIN
  
    g_module := 'COA_DEPARTMENT_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_DEPARTMENT_EXCEPTION1');
  
    BEGIN
    
      -- Check for exception of legacy_id, transform_id and S3_org combination  
      SELECT s3_department
      INTO l_s3_department_exp
      FROM xxobjt.xxcoa_department_exception1
      WHERE transform_id = p_transform_id
      AND inventory_org = p_s3_org
      AND department_id = p_department_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
    
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_department_exp := p_s3_department;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination does not');
      
      WHEN OTHERS THEN
        l_s3_department_exp := NULL;
        g_status_message    := g_status_message || chr(13) ||
                               'Unexpected error during execution of coa_department_exception1 process' ||
                               chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
    RETURN l_s3_department_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_DEPARTMENT_EXCEPTION1');
  
  END coa_department_exception1;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Location segment value from the Location
  --          master table xxcoa_location for a valid combination of transform id and legacy
  --          Location segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_location_master(p_legacy_location_val IN VARCHAR2
                              ,p_transform_id        IN NUMBER
                              ,p_location_id         OUT NUMBER
                              ,p_all_transform_id    IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_location    VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  BEGIN
  
    g_module := 'COA_LOCATION_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_LOCATION_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_legacy_location_val :' ||
                              p_legacy_location_val ||
                              ' ,p_transform_id : ' || p_transform_id);
  
    BEGIN
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_location
      WHERE transform_id = p_transform_id;
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_COMPANY_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_location
                ,location_id
                ,error_message
          INTO l_s3_location
              ,p_location_id
              ,l_error
          FROM xxobjt.xxcoa_location
          WHERE transform_id = p_transform_id
          AND legacy_location = p_legacy_location_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Location segment error: ' || l_error;
          END IF;
        
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) || 'Params : l_s3_location : ' ||
                                    l_s3_location || ' ,p_location_id : ' ||
                                    p_location_id);
        
        EXCEPTION
        
          WHEN no_data_found THEN
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exact combination of transform_id and legacy_value does not exist');
          
            BEGIN
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_location
                    ,location_id
                    ,error_message
              INTO l_s3_location
                  ,p_location_id
                  ,l_error
              FROM xxobjt.xxcoa_location
              WHERE transform_id = p_transform_id
              AND legacy_location = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message || chr(13) ||
                                    'Location segment error: ' || l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message);
            
            EXCEPTION
              WHEN no_data_found THEN
                l_s3_location := NULL;
                p_location_id := NULL;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_location    := NULL;
                p_location_id    := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'More than one mapping found for company :' ||
                                    p_legacy_location_val || chr(10) ||
                                    SQLCODE || chr(10) || SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
              WHEN OTHERS THEN
                l_s3_location    := NULL;
                p_location_id    := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'Unexpected error during execution of coa_company_master process' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            END;
          
          WHEN OTHERS THEN
            l_s3_location    := NULL;
            p_location_id    := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_company_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
          
        END;
      
        -- If no data exists for the transform_id 
      ELSE
        IF l_count_trans_id = 0
        THEN
          g_module := 'COA_COMPANY_MASTER : CHECK ALL-LEGACY COMBINATION';
        
          BEGIN
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_location
                  ,location_id
                  ,error_message
            INTO l_s3_location
                ,p_location_id
                ,l_error
            FROM xxobjt.xxcoa_location
            WHERE transform_id = p_all_transform_id
            AND legacy_location = p_legacy_location_val;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Location segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_location := NULL;
              p_location_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_location    := NULL;
              p_location_id    := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one mapping found for company :' ||
                                  p_legacy_location_val || chr(10) ||
                                  SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_location    := NULL;
              p_location_id    := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_company_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
          END;
        END IF;
      END IF;
    END;
  
    RETURN l_s3_location;
  
  END coa_location_master;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Location segment value from the Location
  --          exception table xxcoa_location_exception1 for a valid combination of transform id 
  --          and legacy Location segment value.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_location_exception1(p_legacy_location_val IN VARCHAR2
                                  ,p_s3_location         IN VARCHAR2
                                  ,p_s3_org              IN VARCHAR2
                                  ,p_transform_id        IN NUMBER
                                  ,p_location_id         IN NUMBER
                                  ,p_all_transform_id    IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_location_exp    VARCHAR2(25);
    l_error              VARCHAR2(100);
    l_excep_trasnform_id NUMBER;
    l_rank               NUMBER;
  
  BEGIN
  
    g_module := 'COA_LOCATION_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_LOCATION_EXCEPTION1');
  
    -- If S3_org = 'GIM' for the transformtion_id
    IF p_s3_org = 'GIM'
       AND p_transform_id = 3
    THEN
      l_s3_location_exp := '000';
    
    
      fnd_file.put_line(fnd_file.log
                       ,'Location FROM exp2 :' || l_s3_location_exp);
    
    ELSE
    
    
      BEGIN
        -- Check for exception of legacy_id, transform_id and S3_org combination  
        SELECT s3_location
        INTO l_s3_location_exp
        FROM xxobjt.xxcoa_location_exception1
        WHERE transform_id = p_transform_id
        AND inventory_org = p_s3_org
        AND location_id = p_location_id;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
      
      EXCEPTION
        WHEN no_data_found THEN
          l_s3_location_exp := p_s3_location;
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exception for legacy_id, transform_id and S3_org combination does not');
        
        WHEN OTHERS THEN
          l_s3_location_exp := NULL;
        
          g_status_message := g_status_message || chr(13) ||
                              'Unexpected error during execution of coa_company_exception2 process' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => g_status_message);
        
      END;
    
    END IF;
    RETURN l_s3_location_exp;
  
  END coa_location_exception1;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 BU segment value from the BU
  --          master table xxcoa_business_unit for a valid combination of transform id and legacy
  --          company,department segment value combination. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION coa_bu_company_dept_mapping(p_legacy_company_val IN VARCHAR2
                                      ,p_legacy_dept_val    IN VARCHAR2
                                      ,p_transform_id       IN NUMBER)
  
  
   RETURN VARCHAR2 IS
  
    l_s3_bu VARCHAR2(50);
    l_error VARCHAR2(100);
    p_bu_id NUMBER;
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log
                     ,'p_transform_id : ' || p_transform_id);
    fnd_file.put_line(fnd_file.log
                     ,'p_legacy_company_val : ' || p_legacy_company_val);
    fnd_file.put_line(fnd_file.log
                     ,'p_legacy_dept_val : ' || p_legacy_dept_val);
    BEGIN
      SELECT s3_bu
            ,bu_id
            ,error_message
      INTO l_s3_bu
          ,p_bu_id
          ,l_error
      FROM xxobjt.xxcoa_business_unit
      WHERE transform_id = p_transform_id
      AND legacy_company = p_legacy_company_val
      AND legacy_department = p_legacy_dept_val
      AND nvl(legacy_location
            ,'LOC') = 'LOC';
    
      IF l_error IS NOT NULL
      THEN
        g_status_message := g_status_message || chr(13) ||
                            'BU segment error: ' || l_error;
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_bu := 'NO_BU_FOUND';
        fnd_file.put_line(fnd_file.log
                         ,'BU based on comp and dept : ' || l_s3_bu);
      WHEN too_many_rows THEN
        l_s3_bu          := NULL;
        g_status_message := g_status_message || chr(13) ||
                            'During BU mapping more than one mapping found for Company  :' ||
                            p_legacy_company_val || ' ' ||
                            'and Department :' || p_legacy_dept_val ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
      WHEN OTHERS THEN
        l_s3_bu          := NULL;
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_bu_company_dept_mapping' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
    END;
    RETURN l_s3_bu;
  END coa_bu_company_dept_mapping;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 BU segment value from the BU
  --          master table xxcoa_business_unit for a valid combination of transform id and legacy
  --          company,department,location segment value combination. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION coa_bu_location_mapping(p_legacy_location_val IN VARCHAR2
                                  ,p_transform_id        IN NUMBER)
  --  ,p_transform_id        IN NUMBER)
  
   RETURN VARCHAR2 IS
  
    l_s3_bu VARCHAR2(50);
    l_error VARCHAR2(100);
    p_bu_id NUMBER;
  
  BEGIN
    BEGIN
      SELECT s3_bu
            ,bu_id
            ,error_message
      INTO l_s3_bu
          ,p_bu_id
          ,l_error
      FROM xxobjt.xxcoa_business_unit
      WHERE transform_id = p_transform_id
      AND legacy_location = p_legacy_location_val
      AND nvl(legacy_company
            ,'LOC') = 'LOC'
      AND nvl(legacy_department
            ,'DEPT') = 'DEPT';
    
      IF l_error IS NOT NULL
      THEN
        g_status_message := g_status_message || chr(13) ||
                            'BU segment error: ' || l_error;
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_bu := 'NO_BU_FOUND';
      WHEN too_many_rows THEN
        l_s3_bu          := NULL;
        g_status_message := g_status_message || chr(13) ||
                            'During BU mapping more than one mapping found for Location  :' ||
                            p_legacy_location_val || chr(10) || SQLCODE ||
                            chr(10) || SQLERRM;
      WHEN OTHERS THEN
        l_s3_bu          := NULL;
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_bu_location_mapping' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
    END;
    RETURN l_s3_bu;
  END coa_bu_location_mapping;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 BU segment value from the BU
  --          master table xxcoa_business_unit for a valid combination of transform id and legacy
  --          company,department and location combination. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION coa_business_unit_master(p_legacy_company_val  IN VARCHAR2
                                   ,p_legacy_dept_val     IN VARCHAR2
                                   ,p_legacy_location_val IN VARCHAR2
                                   ,p_transform_id        IN NUMBER
                                   ,p_bu_id               OUT NUMBER
                                   ,p_all_transform_id    IN NUMBER)
  
   RETURN VARCHAR2 IS
  
    l_s3_bu          VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_trans_id
    FROM xxobjt.xxcoa_business_unit
    WHERE transform_id = p_transform_id;
  
    fnd_file.put_line(fnd_file.log
                     ,'l_count_trans_id : ' || l_count_trans_id);
  
    IF l_count_trans_id > 0
    THEN
      BEGIN
        SELECT s3_bu
              ,bu_id
              ,error_message
        INTO l_s3_bu
            ,p_bu_id
            ,l_error
        FROM xxobjt.xxcoa_business_unit
        WHERE transform_id = p_transform_id
        AND legacy_company = p_legacy_company_val
        AND nvl(legacy_department
              ,'DEPT') = 'DEPT'
        AND nvl(legacy_location
              ,'LOC') = 'LOC';
      
        IF l_error IS NOT NULL
        THEN
          g_status_message := g_status_message || chr(13) || l_error;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log
                           ,'calling coa_bu_company_dept_mapping : values : ' ||
                            p_legacy_company_val || ',' ||
                            p_legacy_dept_val || ',' || p_transform_id);
          l_s3_bu := coa_bu_company_dept_mapping(p_legacy_company_val
                                                ,p_legacy_dept_val
                                                ,p_transform_id);
          --  ,p_transform_id);
          IF l_s3_bu = 'NO_BU_FOUND'
          THEN
            fnd_file.put_line(fnd_file.log
                             ,'calling coa_bu_location_mapping : values : ' ||
                              p_legacy_location_val || ',' ||
                              p_transform_id);
            l_s3_bu := coa_bu_location_mapping(p_legacy_location_val
                                              ,p_transform_id);
            -- ,p_transform_id);
            IF l_s3_bu = 'NO_BU_FOUND'
            THEN
              BEGIN
                SELECT s3_bu
                      ,bu_id
                      ,error_message
                INTO l_s3_bu
                    ,p_bu_id
                    ,l_error
                FROM xxobjt.xxcoa_business_unit
                WHERE transform_id = p_transform_id
                AND legacy_company = 'ALL'
                AND legacy_department = 'ALL'
                AND legacy_location = 'ALL';
              
                fnd_file.put_line(fnd_file.log
                                 ,'NO NO_BU_FOUND : ' || l_s3_bu);
              
                IF l_error IS NOT NULL
                THEN
                  g_status_message := g_status_message || chr(13) ||
                                      'BU segment error: ' || l_error;
                END IF;
              
              EXCEPTION
                WHEN no_data_found THEN
                  l_s3_bu := NULL;
              END;
            END IF;
          END IF;
        
        WHEN too_many_rows THEN
          --In BU company can have multiple mappings so need to check company,dept combo and then location mapping
          l_s3_bu := coa_bu_company_dept_mapping(p_legacy_company_val
                                                ,p_legacy_dept_val
                                                ,p_transform_id);
          --  ,p_transform_id);
          IF l_s3_bu = 'NO_BU_FOUND'
          THEN
            fnd_file.put_line(fnd_file.log
                             ,'calling coa_bu_location_mapping : values : ' ||
                              p_legacy_location_val || ',' ||
                              p_transform_id);
            l_s3_bu := coa_bu_location_mapping(p_legacy_location_val
                                              ,p_transform_id);
            IF l_s3_bu = 'NO_BU_FOUND'
            THEN
              l_s3_bu := NULL;
            END IF;
          END IF;
        
        WHEN OTHERS THEN
          l_s3_bu          := NULL;
          g_status_message := g_status_message || chr(13) ||
                              'Unexpected error during execution of coa_business_unit_master' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
      END;
    ELSE
      IF l_count_trans_id = 0
      THEN
        BEGIN
          SELECT s3_bu
                ,bu_id
                ,error_message
          INTO l_s3_bu
              ,p_bu_id
              ,l_error
          FROM xxobjt.xxcoa_business_unit
          WHERE transform_id = p_all_transform_id
          AND legacy_company = p_legacy_company_val
          AND nvl(legacy_department
                ,'DEPT') = 'DEPT'
          AND nvl(legacy_location
                ,'LOC') = 'LOC';
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'BU segment error: ' || l_error;
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_s3_bu := coa_bu_company_dept_mapping(p_legacy_company_val
                                                  ,p_legacy_dept_val
                                                  ,p_all_transform_id);
            fnd_file.put_line(fnd_file.log
                             ,'BU based on comp and dept1 : ' || l_s3_bu);
            --  ,p_all_transform_id);
            IF l_s3_bu = 'NO_BU_FOUND'
            THEN
              l_s3_bu := coa_bu_location_mapping(p_legacy_location_val
                                                ,p_all_transform_id);
            
              fnd_file.put_line(fnd_file.log
                               ,'BU based on location: ' || l_s3_bu);
              --    ,p_all_transform_id);
              IF l_s3_bu = 'NO_BU_FOUND'
              THEN
                l_s3_bu := NULL;
              END IF;
            END IF;
          
          WHEN too_many_rows THEN
            --In BU company can have multiple mappings so need to check company,dept combo and then location mapping
            l_s3_bu := coa_bu_company_dept_mapping(p_legacy_company_val
                                                  ,p_legacy_dept_val
                                                  ,p_transform_id);
            --  ,p_transform_id);
            IF l_s3_bu = 'NO_BU_FOUND'
            THEN
              fnd_file.put_line(fnd_file.log
                               ,'calling coa_bu_location_mapping : values : ' ||
                                p_legacy_location_val || ',' ||
                                p_transform_id);
              l_s3_bu := coa_bu_location_mapping(p_legacy_location_val
                                                ,p_transform_id);
              IF l_s3_bu = 'NO_BU_FOUND'
              THEN
                l_s3_bu := NULL;
              END IF;
            END IF;
          WHEN OTHERS THEN
            l_s3_bu          := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_business_unit_master' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
        END;
      END IF;
    END IF;
    RETURN l_s3_bu;
  END coa_business_unit_master;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 BU segment value from the BU
  --          exception table xxcoa_business_unit_exception1 for a valid combination of transform id 
  --          and legacy Location segment value.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_business_unit_exception1(p_s3_bu            IN VARCHAR2
                                       ,p_s3_org           IN VARCHAR2
                                       ,p_transform_id     IN NUMBER
                                       ,p_bu_id            IN NUMBER
                                       ,p_all_transform_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_bu_exp VARCHAR2(25);
    l_error     VARCHAR2(100);
    l_rank      NUMBER;
  
  BEGIN
    BEGIN
      SELECT s3_bu
      INTO l_s3_bu_exp
      FROM xxobjt.xxcoa_business_unit_exception1
      WHERE transform_id = p_transform_id
      AND inventory_org = p_s3_org
      AND bu_id = p_bu_id;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_bu_exp := p_s3_bu;
        fnd_file.put_line(fnd_file.log
                         ,'No exceptions found in company exception2 table');
      
      WHEN OTHERS THEN
        l_s3_bu_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_business_unit_exception1 process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log
                         ,'Unexpected error during execution of coa_business_unit_exception1 process' ||
                          chr(10) || SQLCODE || chr(10) || SQLERRM);
      
    
    END;
  
    RETURN l_s3_bu_exp;
  
  END coa_business_unit_exception1;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 BU segment value from the BU
  --          master table xxcoa_business_unit_gl for open GL Transaction types
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name             Description
  -- 1.0  16/11/2015  TCS              Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION coa_business_unit_gl(p_legacy_company_val      IN VARCHAR2
                               ,p_sob_id                  IN VARCHAR2
                               ,p_legacy_account_val      IN VARCHAR2
                               ,p_legacy_intercompany_val IN VARCHAR2
                               ,p_transform_id            IN NUMBER
                               ,p_all_transform_id        IN NUMBER
                               ,p_bu_id                   OUT NUMBER)
  
   RETURN VARCHAR2 IS
  
    l_s3_bu          VARCHAR2(50);
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_trans_id
    FROM xxobjt.xxcoa_business_unit_gl
    WHERE transform_id = p_transform_id;
  
    IF l_count_trans_id > 0
    THEN
      BEGIN
        SELECT s3_business_unit
              ,bu_id
              ,error_message
        INTO l_s3_bu
            ,p_bu_id
            ,l_error
        FROM xxobjt.xxcoa_business_unit_gl
        WHERE transform_id = p_transform_id
        AND sob_id = p_sob_id
        AND p_legacy_account_val BETWEEN
              nvl(legacy_account_from
              ,p_legacy_account_val) AND
              nvl(legacy_account_to
                 ,p_legacy_account_val)
        AND p_legacy_intercompany_val BETWEEN
              nvl(legacy_inter_company_from
              ,p_legacy_intercompany_val) AND
              nvl(legacy_inter_company_to
                 ,p_legacy_intercompany_val)
        AND legacy_company = p_legacy_company_val;
      
        IF l_error IS NOT NULL
        THEN
          g_status_message := g_status_message || chr(13) ||
                              'BU segment error: ' || l_error;
        END IF;
      
      
      
      EXCEPTION
        WHEN no_data_found THEN
          l_s3_bu := NULL;
          p_bu_id := NULL;
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Combination of transform_id and legacy_value for BU GL transformation does not exist :' ||
                                    g_status_message);
        
        WHEN too_many_rows THEN
          l_s3_bu          := NULL;
          p_bu_id          := NULL;
          g_status_message := g_status_message || chr(13) ||
                              'More than one mapping found for BU GL transformation :' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'WHEN TOO_MANY_ROWS' ||
                                    g_status_message);
        WHEN OTHERS THEN
          l_s3_bu          := NULL;
          p_bu_id          := NULL;
          g_status_message := g_status_message || chr(13) ||
                              'Unexpected error during execution of coa_business_unit_gl' ||
                              chr(10) || SQLCODE || chr(10) || SQLERRM;
        
      END;
    
      -- If no data exists for the transform_id
    ELSE
      IF l_count_trans_id = 0
      THEN
        BEGIN
          g_module := 'COA_BU_GL_MASTER : CHECK ALL-LEGACY COMBINATION';
        
          -- Check for combination of Trx_Type and Account type='ALL'
          SELECT s3_business_unit
                ,bu_id
                ,error_message
          INTO l_s3_bu
              ,p_bu_id
              ,l_error
          FROM xxobjt.xxcoa_business_unit_gl
          WHERE transform_id = p_all_transform_id
          AND sob_id = p_sob_id
          AND p_legacy_account_val BETWEEN
                nvl(legacy_account_from
                ,p_legacy_account_val) AND
                nvl(legacy_account_to
                   ,p_legacy_account_val)
          AND p_legacy_intercompany_val BETWEEN
                nvl(legacy_inter_company_from
                ,p_legacy_intercompany_val) AND
                nvl(legacy_inter_company_to
                   ,p_legacy_intercompany_val)
          AND legacy_company = p_legacy_company_val;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'BU segment error: ' || l_error;
          END IF;
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                    g_status_message);
        
        EXCEPTION
          WHEN no_data_found THEN
            l_s3_bu := NULL;
            p_bu_id := NULL;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                      g_status_message);
          
          WHEN too_many_rows THEN
            l_s3_bu          := NULL;
            p_bu_id          := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'More than one mapping found for BU GL Transformation :' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                      g_status_message);
          
          WHEN OTHERS THEN
            l_s3_bu          := NULL;
            p_bu_id          := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_business_unit_gl process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
        END;
      END IF;
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_BU_GL_MASTER');
    RETURN l_s3_bu;
  END coa_business_unit_gl;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 PL segment value from the Product Line
  --          master table xxcoa_product_line for a valid combination of transform id and legacy
  --          item number value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_product_line_master(p_item_number      IN VARCHAR2
                                  ,p_transform_id     IN NUMBER
                                  ,p_all_transform_id IN NUMBER
                                  ,p_pl_id            OUT NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_pl          VARCHAR2(50);
    l_pl_id          NUMBER;
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  BEGIN
  
    g_module := 'COA_PL_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_PL_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : Item Number :' || p_item_number ||
                              ' ,p_transform_id : ' || p_transform_id);
  
    BEGIN
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_product_line
      WHERE transform_id = p_transform_id;
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_PL_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_value 
          SELECT s3_pl
                ,pl_id
                ,error_message
          INTO l_s3_pl
              ,p_pl_id
              ,l_error
          FROM xxobjt.xxcoa_product_line
          WHERE transform_id = p_transform_id
          AND legacy_item_number = p_item_number;
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) ||
                                'Product Line segment error: ' || l_error;
          END IF;
        
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_value exists' ||
                                    chr(13) || 'Params : p_item_number : ' ||
                                    p_item_number);
        
        EXCEPTION
        
          WHEN no_data_found THEN
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exact combination of transform_id and legacy_value does not exist');
          
            BEGIN
              -- Check for combination of transform_id and legacy_value = 'ALL'
              SELECT s3_pl
                    ,pl_id
                    ,error_message
              INTO l_s3_pl
                  ,p_pl_id
                  ,l_error
              FROM xxobjt.xxcoa_product_line
              WHERE transform_id = p_transform_id
              AND legacy_item_number = 'ALL';
            
              IF l_error IS NOT NULL
              THEN
                g_status_message := g_status_message || chr(13) ||
                                    'Product Line segment error: ' ||
                                    l_error;
              END IF;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                        g_status_message);
            
            EXCEPTION
              WHEN no_data_found THEN
                l_s3_pl := NULL;
                p_pl_id := NULL;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                          g_status_message);
              
              WHEN too_many_rows THEN
                l_s3_pl          := NULL;
                p_pl_id          := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'More than one Product line mapping found for legacy_value = ALL :' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
              WHEN OTHERS THEN
                l_s3_pl          := NULL;
                p_pl_id          := NULL;
                g_status_message := g_status_message || chr(13) ||
                                    'Unexpected error during execution of coa_product_line_master process' ||
                                    chr(10) || SQLCODE || chr(10) ||
                                    SQLERRM;
              
                fnd_log.STRING(log_level => fnd_log.level_statement
                              ,module => g_module
                              ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                          g_status_message);
              
            END;
          
          WHEN OTHERS THEN
            l_s3_pl          := NULL;
            p_pl_id          := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_product_line_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
          
        END;
      
        -- If no data exists for the transform_id 
      ELSE
        IF l_count_trans_id = 0
        THEN
          g_module := 'COA_PL_MASTER : CHECK ALL-LEGACY COMBINATION';
        
          BEGIN
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_pl
                  ,pl_id
                  ,error_message
            INTO l_s3_pl
                ,p_pl_id
                ,l_error
            FROM xxobjt.xxcoa_product_line
            WHERE transform_id = p_all_transform_id
            AND legacy_item_number = p_item_number;
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Product Line segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_pl := NULL;
              p_pl_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_pl          := NULL;
              p_pl_id          := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one Product Line mapping found for Trx_Type-ALL transform_id and legacy_value :' ||
                                  p_item_number || chr(10) || SQLCODE ||
                                  chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_pl          := NULL;
              p_pl_id          := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_product_line_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
          END;
        END IF;
      END IF;
    END;
  
    RETURN l_s3_pl;
  
  END coa_product_line_master;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 GL PL segment value from the Product Line
  --          master table xxcoa_gl_product_line for a valid combination of transform id and legacy
  --          item number value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  22/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_gl_pl_master(p_set_of_books_id         IN NUMBER
                           ,p_legacy_company_val      IN VARCHAR2
                           ,p_legacy_account_val      IN VARCHAR2
                           ,p_legacy_intercompany_val IN VARCHAR2
                           ,p_legacy_pl_val           IN VARCHAR2
                           ,p_transform_id            IN NUMBER
                           ,p_all_transform_id        IN NUMBER
                           ,p_gl_pl_id                OUT NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_gl_pl       VARCHAR2(50);
    l_gl_pl_id       NUMBER;
    l_error          VARCHAR2(100);
    l_count_trans_id NUMBER := 0;
  
  BEGIN
  
    g_module := 'COA_GL_PL_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_GL_PL_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : p_set_of_books_id :' ||
                              p_set_of_books_id ||
                              ' ,p_legacy_company_val : ' ||
                              p_legacy_company_val ||
                              ' ,p_legacy_account_val : ' ||
                              p_legacy_account_val ||
                              ' ,p_legacy_intercompany_val : ' ||
                              p_legacy_intercompany_val ||
                              ' ,p_legacy_pl_val : ' || p_legacy_pl_val ||
                              ' ,p_transform_id : ' || p_transform_id);
  
  
    fnd_file.put_line(fnd_file.log
                     ,'Inside COA_GL_PL_MASTER...');
    fnd_file.put_line(fnd_file.log
                     ,'Params : p_set_of_books_id :' || p_set_of_books_id ||
                      ' ,p_legacy_company_val : ' || p_legacy_company_val ||
                      ' ,p_legacy_account_val : ' || p_legacy_account_val ||
                      ' ,p_legacy_intercompany_val : ' ||
                      p_legacy_intercompany_val || ' ,p_legacy_pl_val : ' ||
                      p_legacy_pl_val || ' ,p_transform_id : ' ||
                      p_transform_id);
  
    BEGIN
      -- Fetching count of transform_id from master table
      SELECT COUNT(1)
      INTO l_count_trans_id
      FROM xxobjt.xxcoa_gl_product_line
      WHERE transform_id = p_transform_id;
    
      fnd_file.put_line(fnd_file.log
                       ,'Inside COA_GL_PL_MASTER...: l_count_trans_id : ' ||
                        l_count_trans_id);
    
      -- If data exists for the transform_id
      IF l_count_trans_id > 0
      THEN
        BEGIN
        
          g_module := 'COA_GL_PL_MASTER : CHECK EXACT COMBINATION';
        
          -- Check for exact combination of transform_id and legacy_values 
          SELECT s3_product_line
                ,pl_id
                ,error_message
          INTO l_s3_gl_pl
              ,l_gl_pl_id
              ,l_error
          FROM xxobjt.xxcoa_gl_product_line
          WHERE transform_id = p_transform_id
          AND sob_id = p_set_of_books_id
          AND legacy_company = p_legacy_company_val
          AND p_legacy_account_val BETWEEN
                nvl(legacy_account_from
                ,p_legacy_account_val) AND
                nvl(legacy_account_to
                   ,p_legacy_account_val)
          AND p_legacy_intercompany_val BETWEEN
                nvl(legacy_inter_company_from
                ,p_legacy_intercompany_val) AND
                nvl(legacy_inter_company_to
                   ,p_legacy_intercompany_val)
          AND p_legacy_pl_val BETWEEN
                nvl(product_line_from
                ,p_legacy_pl_val) AND
                nvl(product_line_to
                   ,p_legacy_pl_val);
        
          IF l_error IS NOT NULL
          THEN
            g_status_message := g_status_message || chr(13) || l_error;
          END IF;
        
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Exact combination of transform_id and legacy_values exists' ||
                                    chr(13) ||
                                    'Params : p_set_of_books_id :' ||
                                    p_set_of_books_id ||
                                    ' ,p_legacy_company_val : ' ||
                                    p_legacy_company_val ||
                                    ' ,p_legacy_account_val : ' ||
                                    p_legacy_account_val ||
                                    ' ,p_legacy_intercompany_val : ' ||
                                    p_legacy_intercompany_val ||
                                    ' ,p_legacy_pl_val : ' ||
                                    p_legacy_pl_val ||
                                    ' ,p_transform_id : ' || p_transform_id);
        
        EXCEPTION
        
          WHEN no_data_found THEN
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Exact combination of transform_id and legacy_values does not exist');
          
          /* BEGIN
            -- Check for combination of transform_id and legacy_value = 'ALL'
            SELECT s3_product_line
                  ,pl_id
                  ,error_message
            INTO l_s3_gl_pl
                ,l_gl_pl_id
                ,l_error
            FROM xxobjt.xxcoa_gl_product_line
            WHERE transform_id = p_transform_id
            AND sob_id = p_set_of_books_id
            AND legacy_company = p_legacy_company_val
            AND p_legacy_account_val BETWEEN
                  nvl(legacy_account_from
                  ,p_legacy_account_val) AND
                  nvl(legacy_account_to
                     ,p_legacy_account_val)
            AND p_legacy_intercompany_val BETWEEN
                  nvl(legacy_inter_company_from
                  ,p_legacy_intercompany_val) AND
                  nvl(legacy_inter_company_to
                     ,p_legacy_intercompany_val)
            AND p_legacy_pl_val BETWEEN
                  nvl(product_line_from
                  ,p_legacy_pl_val) AND
                  nvl(product_line_to
                     ,p_legacy_pl_val);
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of transform_id and legacy_value = ALL exists :' ||
                                      g_status_message);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_gl_pl := NULL;
              l_gl_pl_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of transform_id and legacy_value = ALL does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_gl_pl       := NULL;
              l_gl_pl_id       := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one Product line mapping found for legacy_value = ALL :' ||
                                  chr(10) || SQLCODE || chr(10) ||
                                  SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside NO_DATA_FOUND: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_gl_pl       := NULL;
              l_gl_pl_id       := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_product_line_master process' ||
                                  chr(10) || SQLCODE || chr(10) ||
                                  SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside NO_DATA_FOUND: ' ||
                                        g_status_message);
            
          END;*/
        
          WHEN OTHERS THEN
            l_s3_gl_pl       := NULL;
            l_gl_pl_id       := NULL;
            g_status_message := g_status_message || chr(13) ||
                                'Unexpected error during execution of coa_product_line_master process' ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                      g_status_message);
          
        END;
      
        -- If no data exists for the transform_id 
      ELSE
        IF l_count_trans_id = 0
        THEN
          g_module := 'COA_GL_PL_MASTER : CHECK ALL-LEGACY COMBINATION';
        
          fnd_file.put_line(fnd_file.log
                           ,'Insie Else : Params : p_set_of_books_id :' ||
                            p_set_of_books_id ||
                            ' ,p_legacy_company_val : ' ||
                            p_legacy_company_val ||
                            ' ,p_legacy_account_val : ' ||
                            p_legacy_account_val ||
                            ' ,p_legacy_intercompany_val : ' ||
                            p_legacy_intercompany_val ||
                            ' ,p_legacy_pl_val : ' || p_legacy_pl_val ||
                            ' ,p_all_transform_id : ' ||
                            p_all_transform_id);
        
          BEGIN
            -- Check for combination of Trx_Type-ALL transform_id and legacy_value
            SELECT s3_product_line
                  ,pl_id
                  ,error_message
            INTO l_s3_gl_pl
                ,l_gl_pl_id
                ,l_error
            FROM xxobjt.xxcoa_gl_product_line
            WHERE transform_id = p_all_transform_id
            AND sob_id = p_set_of_books_id
            AND legacy_company = p_legacy_company_val
            AND p_legacy_account_val BETWEEN
                  nvl(legacy_account_from
                  ,p_legacy_account_val) AND
                  nvl(legacy_account_to
                     ,p_legacy_account_val)
            AND p_legacy_intercompany_val BETWEEN
                  nvl(legacy_inter_company_from
                  ,p_legacy_intercompany_val) AND
                  nvl(legacy_inter_company_to
                     ,p_legacy_intercompany_val)
            AND p_legacy_pl_val BETWEEN
                  nvl(product_line_from
                  ,p_legacy_pl_val) AND
                  nvl(product_line_to
                     ,p_legacy_pl_val);
          
          
          
            fnd_file.put_line(fnd_file.log
                             ,'After query Inside Else : Params : l_s3_gl_pl :' ||
                              l_s3_gl_pl || ' ,l_gl_pl_id : ' ||
                              l_gl_pl_id);
          
            IF l_error IS NOT NULL
            THEN
              g_status_message := g_status_message || chr(13) ||
                                  'Product Line segment error: ' || l_error;
            END IF;
          
            fnd_log.STRING(log_level => fnd_log.level_statement
                          ,module => g_module
                          ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value exists :' ||
                                      g_status_message);
          
          EXCEPTION
            WHEN no_data_found THEN
              l_s3_gl_pl := NULL;
              l_gl_pl_id := NULL;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'Combination of Trx_Type-ALL transform_id and legacy_value does not exist :' ||
                                        g_status_message);
            
            WHEN too_many_rows THEN
              l_s3_gl_pl       := NULL;
              l_gl_pl_id       := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'More than one Product Line mapping found for Trx_Type-ALL transform_id and legacy_value :' ||
                                  'p_set_of_books_id :' ||
                                  p_set_of_books_id ||
                                  ' ,p_legacy_company_val : ' ||
                                  p_legacy_company_val ||
                                  ' ,p_legacy_account_val : ' ||
                                  p_legacy_account_val ||
                                  ' ,p_legacy_intercompany_val : ' ||
                                  p_legacy_intercompany_val ||
                                  ' ,p_legacy_pl_val : ' || p_legacy_pl_val ||
                                  ' ,p_transform_id : ' || p_transform_id ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN TOO_MANY_ROWS inside BEGIN: ' ||
                                        g_status_message);
            
            WHEN OTHERS THEN
              l_s3_gl_pl       := NULL;
              l_gl_pl_id       := NULL;
              g_status_message := g_status_message || chr(13) ||
                                  'Unexpected error during execution of coa_product_line_master process' ||
                                  chr(10) || SQLCODE || chr(10) || SQLERRM;
            
              fnd_log.STRING(log_level => fnd_log.level_statement
                            ,module => g_module
                            ,message => 'WHEN OTHERS inside BEGIN: ' ||
                                        g_status_message);
          END;
        END IF;
      END IF;
    END;
  
    RETURN l_s3_gl_pl;
  
  END coa_gl_pl_master;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Location segment value from the Location
  --          exception table xxcoa_location_exception1 for a valid combination of transform id 
  --          and legacy Location segment value.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_product_line_exception1(p_legacy_pl_val    IN VARCHAR2
                                      ,p_s3_pl            IN VARCHAR2
                                      ,p_s3_org           IN VARCHAR2
                                      ,p_transform_id     IN NUMBER
                                      ,p_pl_id            IN NUMBER
                                      ,p_all_transform_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_s3_pl_exp          VARCHAR2(25);
    l_error              VARCHAR2(100);
    l_excep_trasnform_id NUMBER;
    l_rank               NUMBER;
  
  BEGIN
  
    g_module := 'COA_PL_EXCEPTION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_PL_EXCEPTION1');
  
    BEGIN
      -- Check for exception of legacy_id, transform_id and S3_org combination  
      SELECT s3_pl
      INTO l_s3_pl_exp
      FROM xxobjt.xxcoa_productline_exception1
      WHERE transform_id = p_transform_id
      AND inventory_org = p_s3_org
      AND pl_id = p_pl_id;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Exception for legacy_id, transform_id and S3_org combination exists');
    
    EXCEPTION
      WHEN no_data_found THEN
        l_s3_pl_exp := p_s3_pl;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Exception for legacy_id, transform_id and S3_org combination does not exist');
      
      WHEN OTHERS THEN
        l_s3_pl_exp := NULL;
      
        g_status_message := g_status_message || chr(13) ||
                            'Unexpected error during execution of coa_product_line_exception1 process' ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM;
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
    END;
    RETURN l_s3_pl_exp;
  
  END coa_product_line_exception1;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Company segment value from the Company
  --          master table xxcoa_company for a valid combination of transform id and legacy
  --          company segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  15/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_company_transform(p_legacy_company_val  IN VARCHAR2
                                ,p_legacy_division_val IN VARCHAR2
                                ,p_s3_org              IN VARCHAR2
                                ,p_transform_id        IN NUMBER
                                ,p_trx_type            IN VARCHAR2
                                ,p_all_transform_id    IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_company     VARCHAR2(25) := -999;
    l_s3_company_exp VARCHAR2(25) := -999;
    l_company_id     NUMBER;
  
  
  BEGIN
  
    g_module := 'COA_COMPANY_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_COMPANY_TRANSFORM');
  
  
    -- If legacy_value is NOT NULL
    IF p_legacy_company_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_COMPANY_MASTER');
    
    
      fnd_file.put_line(fnd_file.log
                       ,'coa_company_master calling with : ' ||
                        p_legacy_company_val || ',' || p_transform_id || ',' ||
                        p_all_transform_id);
      -- Calling  coa_company_master        
      l_s3_company := coa_company_master(p_legacy_company_val => p_legacy_company_val
                                        ,p_transform_id => p_transform_id
                                        ,p_company_id => l_company_id
                                        ,p_all_transform_id => p_all_transform_id);
    
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_COMPANY_MASTER');
    
      -- If legacy_value is NULL
    ELSE
    
      g_status_message := g_status_message || chr(13) ||
                          'Company field cannot be null ,';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
    
      l_s3_company := NULL;
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_COMPANY_MASTER');
  
    --Start Company exceptions
    g_module := 'COA_COMPANY_TRANSFORM : EXCPETION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_COMPANY_EXCPETION1');
  
    l_s3_company_exp := coa_company_exception1(p_legacy_company_val => p_legacy_company_val
                                              ,p_division => p_legacy_division_val
                                              ,p_s3_company => l_s3_company
                                              ,p_transform_id => p_transform_id
                                              ,p_company_id => l_company_id
                                              ,p_all_transform_id => p_all_transform_id);
  
    l_s3_company := l_s3_company_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_COMPANY_EXCPETION1');
  
  
  
    g_module := 'COA_COMPANY_TRANSFORM : EXCPETION2';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_COMPANY_EXCPETION2');
  
    l_s3_company_exp := coa_company_exception2(p_legacy_company_val => p_legacy_company_val
                                              ,p_s3_org => p_s3_org
                                              ,p_s3_company => l_s3_company
                                              ,p_transform_id => p_transform_id
                                              ,p_company_id => l_company_id
                                              ,p_all_transform_id => p_all_transform_id);
  
    l_s3_company := l_s3_company_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_COMPANY_EXCPETION2');
    --End Company exceptions  
  
    RETURN l_s3_company;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_COMPANY_TRANSFORM');
  
  END coa_company_transform;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 InterCompany segment value from the InterCompany
  --          master table xxcoa_intercompany for a valid combination of transform id and legacy
  --          company segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_intercompany_transform(p_legacy_company_val      IN VARCHAR2
                                     ,p_legacy_intercompany_val IN VARCHAR2
                                     ,p_legacy_division_val     IN VARCHAR2
                                     ,p_s3_org                  IN VARCHAR2
                                     ,p_transform_id            IN NUMBER
                                     ,p_trx_type                IN VARCHAR2
                                     ,p_all_transform_id        IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_intercomp     VARCHAR2(25) := -999;
    l_s3_intercomp_exp VARCHAR2(25) := -999;
    l_intercompany_id  NUMBER;
  
  BEGIN
  
    g_module := 'COA_INTERCOMPANY_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_INTERCOMPANY_TRANSFORM');
  
  
    -- If legacy_value is NOT NULL
    IF p_legacy_intercompany_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_INTERCOMPANY_MASTER');
    
    
      -- Calling coa_intercompany_master        
      l_s3_intercomp := coa_intercompany_master(p_legacy_intercompany_val => p_legacy_intercompany_val
                                               ,p_transform_id => p_transform_id
                                               ,p_intercompany_id => l_intercompany_id
                                               ,p_all_transform_id => p_all_transform_id);
    
      fnd_file.put_line(fnd_file.log
                       ,'Intercompany FROM master :' || l_s3_intercomp_exp);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_INTERCOMPANY_MASTER');
    
    
      -- If legacy_value is NULL
    ELSE
    
      g_status_message := g_status_message || chr(13) ||
                          'InterCompany field cannot be null ,';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
    
      l_s3_intercomp := NULL;
    
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_INTERCOMPANY_MASTER');
  
    --Start InterCompany exceptions
    g_module := 'COA_COMPANY_TRANSFORM : EXCPETION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_INTERCOMPANY_EXCPETION1');
  
    l_s3_intercomp_exp := coa_intercompany_exception1(p_legacy_intercompany_val => p_legacy_intercompany_val
                                                     ,p_s3_intercomp => l_s3_intercomp
                                                     ,p_division => p_legacy_division_val
                                                     ,p_transform_id => p_transform_id
                                                     ,p_intercompany_id => l_intercompany_id
                                                     ,p_all_transform_id => p_all_transform_id);
  
    l_s3_intercomp := l_s3_intercomp_exp;
  
    fnd_file.put_line(fnd_file.log
                     ,'Intercompany FROM exp1 :' || l_s3_intercomp_exp);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_INTERCOMPANY_EXCPETION1');
  
  
    g_module := 'COA_INTERCOMPANY_TRANSFORM : EXCPETION2';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_INTERCOMPANY_EXCPETION2');
  
    l_s3_intercomp_exp := coa_intercompany_exception2(p_legacy_intercompany_val => p_legacy_intercompany_val
                                                     ,p_s3_intercomp => l_s3_intercomp
                                                     ,p_s3_org => p_s3_org
                                                     ,p_transform_id => p_transform_id
                                                     ,p_intercompany_id => l_intercompany_id
                                                     ,p_all_transform_id => p_all_transform_id);
  
    l_s3_intercomp := l_s3_intercomp_exp;
    fnd_file.put_line(fnd_file.log
                     ,'Intercompany FROM exp2 main :' || l_s3_intercomp);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_INTERCOMPANY_EXCPETION2');
    --End Company exceptions  
  
    --End Company exceptions  
    RETURN l_s3_intercomp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_INTERCOMPANY_TRANSFORM');
  
  END coa_intercompany_transform;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Account segment value from the Account
  --          master table xxcoa_account for a valid combination of transform id and legacy
  --          account segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_account_transform(p_legacy_account_val IN VARCHAR2
                                ,p_s3_org             IN VARCHAR2
                                ,p_transform_id       IN NUMBER
                                ,p_trx_type           IN VARCHAR2
                                ,p_all_transform_id   IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_account     VARCHAR2(25) := -999;
    l_account_id     NUMBER;
    l_s3_account_exp VARCHAR2(25) := -999;
  
  BEGIN
  
    g_module := 'COA_ACCOUNT_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_ACCOUNT_TRANSFORM');
  
  
    -- If legacy_value is NOT NULL
    IF p_legacy_account_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_ACCOUNT_MASTER');
    
      -- Calling  coa_account_master        
      l_s3_account := coa_account_master(p_legacy_account_val => p_legacy_account_val
                                        ,p_transform_id => p_transform_id
                                        ,p_account_id => l_account_id
                                        ,p_all_transform_id => p_all_transform_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_ACCOUNT_MASTER');
    
      -- If legacy_value is NULL
    ELSE
      g_status_message := g_status_message || chr(13) ||
                          'Account field cannot be null ,';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
    
      l_s3_account := NULL;
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_ACCOUNT_MASTER');
  
    --Start Account exceptions
    g_module := 'COA_ACCOUNT_TRANSFORM : EXCPETION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_ACCOUNT_EXCPETION1');
  
    l_s3_account_exp := coa_account_exception1(p_legacy_account_val => p_legacy_account_val
                                              ,p_s3_org => p_s3_org
                                              ,p_s3_account => l_s3_account
                                              ,p_transform_id => p_transform_id
                                              ,p_account_id => l_account_id
                                              ,p_all_transform_id => p_all_transform_id);
  
    l_s3_account := l_s3_account_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_ACCOUNT_EXCPETION1');
  
    RETURN l_s3_account;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_ACCOUNT_TRANSFORM');
  
  END coa_account_transform;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will be used to derive the S3 Department segment value corresponding 
  --         to the legacy department segment value
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_department_transform(p_legacy_dept_val  IN VARCHAR2
                                   ,p_s3_org           IN VARCHAR2
                                   ,p_transform_id     IN NUMBER
                                   ,p_trx_type         IN VARCHAR2
                                   ,p_all_transform_id IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_department     VARCHAR2(25) := -999;
    l_s3_department_exp VARCHAR2(25) := -999;
    l_department_id     NUMBER;
  
  BEGIN
    g_module := 'COA_DEPARTMENT_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_DEPARTMENT_TRANSFORM');
  
  
  
    -- If legacy_value is NOT NULL
    IF p_legacy_dept_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_DEPARTMENT_MASTER');
    
      -- Calling  coa_department_master
      l_s3_department := coa_department_master(p_legacy_dept_val => p_legacy_dept_val
                                              ,p_transform_id => p_transform_id
                                              ,p_department_id => l_department_id
                                              ,p_all_transform_id => p_all_transform_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_DEPARTMENT_MASTER');
    
      -- If legacy_value is NULL
    ELSE
    
      g_status_message := g_status_message || chr(13) ||
                          'Department field cannot be null ,';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
    
      l_s3_department := NULL;
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_DEPARTMENT_MASTER');
  
    --Start Department exceptions
    g_module := 'COA_DEPARTMENT_MASTER : EXCPETION1';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before Calling COA_DEPARTMENT_EXCPETION1');
  
    l_s3_department_exp := coa_department_exception1(p_legacy_dept_val => p_legacy_dept_val
                                                    ,p_s3_org => p_s3_org
                                                    ,p_s3_department => l_s3_department
                                                    ,p_transform_id => p_transform_id
                                                    ,p_department_id => l_department_id
                                                    ,p_all_transform_id => p_all_transform_id);
  
    l_s3_department := l_s3_department_exp;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_DEPARTMENT_EXCPETION1');
  
    --End Department exceptions  
    RETURN l_s3_department;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End Of COA_DEPARTMENT_TRANSFORM');
  
  END coa_department_transform;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Location segment value from the Location
  --          master table xxcoa_location for a valid combination of transform id and legacy
  --          location segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_location_transform(p_legacy_location_val IN VARCHAR2
                                 ,p_s3_org              IN VARCHAR2
                                 ,p_transform_id        IN NUMBER
                                 ,p_trx_type            IN VARCHAR2
                                 ,p_all_transform_id    IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_location     VARCHAR2(25) := -999;
    l_s3_location_exp VARCHAR2(25) := -999;
    l_location_id     NUMBER := 0;
  
  
  BEGIN
    g_module := 'COA_LOCATION_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_LOCATION_TRANSFORM');
  
    -- If legacy_value is NOT NULL
    IF p_legacy_location_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_LOCATION_TRANSFORM');
    
      -- Calling  coa_location_master  
      l_s3_location := coa_location_master(p_legacy_location_val => p_legacy_location_val
                                          ,p_transform_id => p_transform_id
                                          ,p_location_id => l_location_id
                                          ,p_all_transform_id => p_all_transform_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_COMPANY_MASTER');
    
      -- If legacy_value is NULL
    ELSE
      g_status_message := g_status_message || chr(13) ||
                          'Account field cannot be null ,';
      fnd_file.put_line(fnd_file.log
                       ,'Account field cannot be null');
      l_s3_location := NULL;
    END IF;
  
    fnd_file.put_line(fnd_file.log
                     ,'End Account mapping');
  
    --Start Account exceptions
    fnd_file.put_line(fnd_file.log
                     ,'Start Account exceptions : Exception - 1');
  
    l_s3_location_exp := coa_location_exception1(p_legacy_location_val => p_legacy_location_val
                                                ,p_s3_org => p_s3_org
                                                ,p_s3_location => l_s3_location
                                                ,p_transform_id => p_transform_id
                                                ,p_location_id => l_location_id
                                                ,p_all_transform_id => p_all_transform_id);
  
    l_s3_location := l_s3_location_exp;
    fnd_file.put_line(fnd_file.log
                     ,'End Account exceptions : Exception - 1');
  
    RETURN l_s3_location;
  END coa_location_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Location segment value from the Location
  --          master table xxcoa_location for a valid combination of transform id and legacy
  --          location segment value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_transform(p_legacy_company_val  IN VARCHAR2
                           ,p_legacy_dept_val     IN VARCHAR2
                           ,p_legacy_location_val IN VARCHAR2
                           ,p_s3_org              IN VARCHAR2
                           ,p_transform_id        IN NUMBER
                           ,p_trx_type            IN VARCHAR2
                           ,p_all_transform_id    IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_bu     VARCHAR2(25) := -999;
    l_s3_bu_exp VARCHAR2(25) := -999;
    l_bu_id     NUMBER := 0;
  
  BEGIN
    g_module := 'COA_BU_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_BU_TRANSFORM');
  
  
    -- If legacy_value is NULL
    IF p_legacy_company_val IS NULL
       AND p_legacy_location_val IS NULL
    THEN
      g_status_message := g_status_message || chr(13) ||
                          'Both Company and Location field cannot be null ,';
      fnd_file.put_line(fnd_file.log
                       ,'Both Company and Location field cannot be null');
      l_s3_bu := NULL;
      -- If legacy_value is NOT NULL
    ELSE
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_BU_TRANSFORM');
    
    
    
    
      -- Calling  coa_business_unit_master  
      l_s3_bu := coa_business_unit_master(p_legacy_company_val
                                         ,p_legacy_dept_val
                                         ,p_legacy_location_val
                                         ,p_transform_id
                                         ,l_bu_id
                                         ,p_all_transform_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_BU_TRANSFORM');
    
    END IF;
  
    fnd_file.put_line(fnd_file.log
                     ,'End BU mapping');
  
    --Start BU exceptions
    fnd_file.put_line(fnd_file.log
                     ,'Start BU exceptions : Exception - 1');
  
    l_s3_bu_exp := coa_business_unit_exception1(p_s3_org => p_s3_org
                                               ,p_s3_bu => l_s3_bu
                                               ,p_transform_id => p_transform_id
                                               ,p_bu_id => l_bu_id
                                               ,p_all_transform_id => p_all_transform_id);
  
    l_s3_bu := l_s3_bu_exp;
    fnd_file.put_line(fnd_file.log
                     ,'End BU exceptions : Exception - 1');
    RETURN l_s3_bu;
  END coa_bu_transform;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 Product Line segment value from the Product Line
  --          master table xxcoa_product_line for a valid combination of transform id,legacy
  --          Product Line and legacy item number . 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_product_line_transform(p_legacy_product_line IN VARCHAR2
                                     ,p_item_number         IN VARCHAR2
                                     ,p_all_transform_id    IN NUMBER
                                     ,p_transform_id        IN NUMBER
                                     ,p_account_type        IN VARCHAR2
                                     ,p_s3_org              IN VARCHAR2)
  
   RETURN VARCHAR2 IS
    l_s3_pl     VARCHAR2(25) := -999;
    l_s3_pl_exp VARCHAR2(25) := -999;
    l_pl_id     NUMBER := 0;
  
  BEGIN
    g_module := 'COA_LOCATION_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_LOCATION_TRANSFORM');
  
    -- If legacy_value is NOT NULL
    IF p_legacy_product_line IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_PL_TRANSFORM');
    
      IF p_account_type IN ('SALES', 'COGS')
      THEN
        -- Commented 19-dec-2016 SAKula
        --IF p_legacy_product_line = '000'
        --THEN
        --l_s3_pl := '0000';
        --ELSE
        IF p_item_number IS NULL
        THEN
          l_s3_pl := '9999';
        ELSE
          -- Calling  coa_pl_master  
          l_s3_pl := coa_product_line_master(p_item_number
                                            ,p_transform_id
                                            ,p_all_transform_id
                                            ,l_pl_id);
          -- END IF;
        END IF;
      ELSE
        l_s3_pl := coa_product_line_master(p_item_number
                                          ,p_transform_id
                                          ,p_all_transform_id
                                          ,l_pl_id);
      END IF;
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_COMPANY_MASTER');
    
      -- If legacy_value is NULL
    ELSE
      g_status_message := g_status_message || chr(13) ||
                          'Product Line field cannot be null ,';
      fnd_file.put_line(fnd_file.log
                       ,'Product Line field cannot be null');
      l_s3_pl := NULL;
    END IF;
  
    --Start PL exceptions
    fnd_file.put_line(fnd_file.log
                     ,'Start Product Line exceptions : Exception - 1');
  
    l_s3_pl_exp := coa_product_line_exception1(p_legacy_pl_val => p_legacy_product_line
                                              ,p_s3_pl => l_s3_pl
                                              ,p_s3_org => p_s3_org
                                              ,p_transform_id => p_transform_id
                                              ,p_pl_id => l_pl_id
                                              ,p_all_transform_id => p_all_transform_id);
  
    l_s3_pl := l_s3_pl_exp;
    fnd_file.put_line(fnd_file.log
                     ,'End Product Line exceptions : Exception - 1 : l_s3_pl : ' ||
                      l_s3_pl);
  
    RETURN l_s3_pl;
  END coa_product_line_transform;





  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 GL Product Line segment value from the GL Product Line
  --          master table xxcoa_gl_product_line for a valid combination of transform id and legacy
  --          Product Line value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  22/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_gl_pl_transform(p_set_of_books_id         IN NUMBER
                              ,p_legacy_company_val      IN VARCHAR2
                              ,p_legacy_account_val      IN VARCHAR2
                              ,p_legacy_intercompany_val IN VARCHAR2
                              ,p_legacy_pl_val           IN VARCHAR2
                              ,p_s3_org                  IN VARCHAR2
                              ,p_transform_id            IN NUMBER
                              ,p_trx_type                IN VARCHAR2
                              ,p_all_transform_id        IN NUMBER)
  
   RETURN VARCHAR2 IS
    l_s3_gl_pl     VARCHAR2(25) := -999;
    l_s3_gl_pl_exp VARCHAR2(25) := -999;
    l_gl_pl_id     NUMBER := 0;
  
  
  BEGIN
    g_module := 'COA_GL_PL_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_GL_PL_TRANSFORM');
  
    -- If legacy_value is NOT NULL
    IF p_legacy_pl_val IS NOT NULL
    THEN
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before Calling COA_GL_PL_MASTER');
    
    
      fnd_file.put_line(fnd_file.log
                       ,'Calling coa_gl_pl_master...');
    
      -- Calling  coa_gl_pl_master  
      l_s3_gl_pl := coa_gl_pl_master(p_set_of_books_id => p_set_of_books_id
                                    ,p_legacy_company_val => p_legacy_company_val
                                    ,p_legacy_account_val => p_legacy_account_val
                                    ,p_legacy_intercompany_val => p_legacy_intercompany_val
                                    ,p_legacy_pl_val => p_legacy_pl_val
                                    ,p_transform_id => p_transform_id
                                    ,p_all_transform_id => p_all_transform_id
                                    ,p_gl_pl_id => l_gl_pl_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After Calling COA_GL_PL_MASTER');
    
      -- If legacy_value is NULL
    ELSE
      g_status_message := g_status_message || chr(13) ||
                          'GL Product line field cannot be null ,';
      fnd_file.put_line(fnd_file.log
                       ,'GL Product line field cannot be null');
      l_s3_gl_pl := NULL;
    END IF;
  
    fnd_file.put_line(fnd_file.log
                     ,'End GL Product line mapping');
  
  
    RETURN l_s3_gl_pl;
  END coa_gl_pl_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will fetch the S3 PL segment value from the Product Line
  --          master table xxcoa_product_line for Item Master transaction type and for a valid 
  --          combination of transform id and legacy item number value. 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  14/11/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_item_pl_master(p_legacy_product_line IN VARCHAR2
                             ,p_item_number         IN VARCHAR2
                             ,p_all_transform_id    IN NUMBER
                             ,p_transform_id        IN NUMBER
                             ,p_account_type        IN VARCHAR2
                             ,p_s3_org              IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_s3_item_pl        VARCHAR2(50);
    l_s3_item_pl_exp    VARCHAR2(50);
    l_pl_id             NUMBER;
    l_error             VARCHAR2(100);
    l_count_trans_id    NUMBER := 0;
    l_count_item_exists NUMBER := NULL;
    l_all_transform_id  NUMBER;
    l_item_number       VARCHAR2(100);
  
  BEGIN
  
    g_module := 'COA_ITEM_PL_MASTER';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_ITEM_PL_MASTER');
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Params : Item Number :' || p_item_number ||
                              ' ,p_transform_id : ' || p_transform_id);
    fnd_file.put_line(fnd_file.log
                     ,'Params : Item Number :' || p_item_number ||
                      ' ,p_all_transform_id : ' || p_all_transform_id);
  
    l_all_transform_id := p_all_transform_id;
    l_item_number      := p_item_number;
  
    fnd_file.put_line(fnd_file.log
                     ,'l_all_transform_id' || l_all_transform_id);
    fnd_file.put_line(fnd_file.log
                     ,'l_item_number' || l_item_number);
  
    SELECT COUNT(1)
    INTO l_count_item_exists
    FROM xxobjt.xxcoa_product_line
    WHERE transform_id = l_all_transform_id
    AND legacy_item_number = l_item_number;
  
  
    fnd_file.put_line(fnd_file.log
                     ,'Post l_count_item_exists' || l_count_item_exists);
  
    IF p_account_type IN ('SALES', 'COGS')
    THEN
      IF l_count_item_exists = 0
      THEN
        fnd_file.put_line(fnd_file.log
                         ,'No mapping found');
        l_s3_item_pl := '9999';
      ELSE
        -- Commented 19 dec 2016 SAkula 
        --IF p_legacy_product_line = '000'THEN
        -- l_s3_item_pl := '0000';
        -- ELSE
        -- Calling  coa_pl_master  
        l_s3_item_pl := coa_product_line_master(p_item_number
                                               ,p_transform_id
                                               ,p_all_transform_id
                                               ,l_pl_id);
        -- END IF;   
      END IF;
    ELSE
      l_s3_item_pl := coa_product_line_master(p_item_number
                                             ,p_transform_id
                                             ,p_all_transform_id
                                             ,l_pl_id);
    END IF;
  
    --Start PL exceptions
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Start Product Line exceptions : Exception - 1');
  
    l_s3_item_pl_exp := coa_product_line_exception1(p_legacy_pl_val => p_legacy_product_line
                                                   ,p_s3_pl => l_s3_item_pl
                                                   ,p_s3_org => p_s3_org
                                                   ,p_transform_id => p_transform_id
                                                   ,p_pl_id => l_pl_id
                                                   ,p_all_transform_id => p_all_transform_id);
  
    l_s3_item_pl := l_s3_item_pl_exp;
    fnd_file.put_line(fnd_file.log
                     ,'End Product Line exceptions : Exception - 1 : l_s3_item_pl : ' ||
                      l_s3_item_pl);
  
  
  
    RETURN l_s3_item_pl;
  
  END coa_item_pl_master;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure. This returns the concatenated GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_transform(p_field_name              IN VARCHAR2
                         ,p_legacy_company_val      IN VARCHAR2
                         , --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2
                         , --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2
                         , --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2
                         , --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2
                         , --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2
                         , --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2
                         ,p_item_number             IN VARCHAR2 DEFAULT NULL
                         ,p_s3_org                  IN VARCHAR2 DEFAULT NULL
                         ,p_trx_type                IN VARCHAR2
                         ,p_set_of_books_id         IN VARCHAR2 DEFAULT NULL
                         ,p_debug_flag              IN VARCHAR2 DEFAULT 'N'
                         ,p_s3_gl_string            OUT VARCHAR2
                         ,p_err_code                OUT VARCHAR2
                         , -- Output error code
                          p_err_msg                 OUT VARCHAR2) --Output Message VARCHAR2(4000)
   AS
  
    l_company_val        VARCHAR2(250) := -999;
    l_business_unit_val  VARCHAR2(250);
    l_department_val     VARCHAR2(250);
    l_account_val        VARCHAR2(250);
    l_product_line_val   VARCHAR2(250);
    l_location_val       VARCHAR2(250);
    l_future_val         VARCHAR2(250);
    l_intercompany_val   VARCHAR2(250);
    l_acc_first_digit    VARCHAR2(1);
    l_account_type       VARCHAR2(100);
    l_region_name        VARCHAR2(100);
    l_acct_type          VARCHAR2(50);
    l_status             VARCHAR2(1) := 'S';
    p_transform_id       NUMBER := 0;
    p_all_transform_id   NUMBER := 0;
    l_transform_id       NUMBER := 0;
    l_s3_company         VARCHAR2(25) := -999;
    l_s3_company_exp     VARCHAR2(25) := -999;
    l_department_val_exp VARCHAR2(250);
    l_s3_bu              VARCHAR2(25) := -999;
    l_s3_bu_exp          VARCHAR2(25) := -999;
    l_s3_department      VARCHAR2(25) := -999;
    l_s3_department_exp  VARCHAR2(25) := -999;
    l_s3_account         VARCHAR2(25) := -999;
    l_s3_account_exp     VARCHAR2(25) := -999;
    l_s3_location        VARCHAR2(25) := -999;
    l_s3_intercompany    VARCHAR2(25) := -999;
    l_s3_pl              VARCHAR2(25) := -999;
    l_s3_gl_pl           VARCHAR2(25) := -999;
    l_s3_item_pl         VARCHAR2(25) := -999;
    l_bu_id              NUMBER := 0;
  
  
  
  BEGIN
  
    -----------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------------------------------------------------
  
    p_err_msg  := NULL;
    p_err_code := NULL;
  
    g_status         := 'S';
    g_status_message := NULL;
  
    --   IF g_status = 'S'
    --THEN
  
    g_module := 'COA_TRANSFORM';
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Legacy Segments :: Segment1 : ' ||
                              p_legacy_company_val || ' ,Segment2 : ' ||
                              p_legacy_department_val || ' ,Segment3 : ' ||
                              p_legacy_account_val || ' ,Segment5 : ' ||
                              p_legacy_product_val || ' ,Segment6 : ' ||
                              p_legacy_location_val || ' ,Segment7 : ' ||
                              p_legacy_intercompany_val || ' ,Segment10 : ' ||
                              p_legacy_division_val || ' ,Item Number : ' ||
                              p_item_number || ' ,S3 Inventory Org : ' ||
                              p_s3_org || ' ,Transaction Type : ' ||
                              p_trx_type || ' ,Set of Books ID : ' ||
                              p_set_of_books_id);
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Inside COA_TRANSFORM');
  
    ---------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------
    -- Start of Get account_type
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'Before calling GET_ACCOUNT_TYPE');
  
  
    IF p_legacy_account_val IS NOT NULL
    THEN
      l_acct_type := get_account_type(p_account => p_legacy_account_val
                                      --legacy coa account segment value
                                     ,g_status => g_status
                                     ,g_status_message => g_status_message);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Account Type is :' || l_acct_type);
    
      fnd_file.put_line(fnd_file.log
                       ,'Account type is : ' || l_acct_type);
    ELSE
      g_status         := 'E';
      g_status_message := g_status_message || chr(13) ||
                          'Account field cannot be null';
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
    
    END IF;
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'After completion of GET_ACCOUNT_TYPE');
    -- End of Get account_type                
    --   END IF;
    ---------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------
    IF g_status = 'S'
    THEN
      -- Start of Fetch coa transform id
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling FETCH_COA_TRANSFORM_ID');
    
      fnd_file.put_line(fnd_file.log
                       ,'Account type is : ' || l_acct_type);
      fnd_file.put_line(fnd_file.log
                       ,'Trx type is : ' || p_trx_type);
    
      fetch_coa_transform_id(p_trx_type => p_trx_type --transaction type like 'PO','Item Master'
                            ,p_acct_type => l_acct_type
                            ,p_transform_id => p_transform_id
                            ,g_status => g_status
                            ,g_status_message => g_status_message);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => g_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'Transform ID is : ' || p_transform_id);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of FETCH_COA_TRANSFORM_ID');
    
      -- End of Fetch coa transform id
      fnd_file.put_line(fnd_file.log
                       ,'p_transform_id is : ' || p_transform_id);
    END IF;
    -------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------
    IF g_status = 'S'
    THEN
      -- Start of Fetch coa ALL transform id
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling FETCH_COA_ALL_TRANSFORM_ID');
    
      get_all_transform_id(p_trx_type => p_trx_type
                          ,p_all_transform_id => p_all_transform_id
                          ,g_status => g_status
                          ,g_status_message => g_status_message);
    
    END IF;
  
    ------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------
  
    IF g_status = 'S'
    THEN
      --Start company mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_COMPANY_TRANSFORM');
    
      l_s3_company := coa_company_transform(p_legacy_company_val => p_legacy_company_val
                                           ,p_legacy_division_val => p_legacy_division_val
                                           ,p_s3_org => p_s3_org
                                           ,p_transform_id => p_transform_id
                                           ,p_trx_type => p_trx_type
                                           ,p_all_transform_id => p_all_transform_id);
    
      IF l_s3_company IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA Company';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_company : ' || l_s3_company);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_COMPANY_TRANSFORM');
    
      --End company mapping
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER company :' ||
                        g_status_message);
      -------------------------------------------------------------------------------------------------------------------
      -------------------------------------------------------------------------------------------------------------------     
    
      --Start BU mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_BU_TRANSFORM');
      --check BU for transaction type - open GL
      IF p_trx_type = 'GL'
      THEN
        -- refer BU-PO mapping for this particular case
        IF p_legacy_account_val BETWEEN '600000' AND '699999'
           AND p_set_of_books_id = 2282
           AND p_legacy_company_val = '26'
        THEN
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Before Calling COA_BU_GL_TRANSFORM - Same as BU_PO_Transform');
        
          -- Calling  coa_business_unit_master  
          l_s3_bu := coa_business_unit_master(p_legacy_company_val
                                             ,p_legacy_department_val
                                             ,p_legacy_location_val
                                             ,p_transform_id
                                             ,l_bu_id
                                             ,p_all_transform_id);
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'After Calling COA_BU_GL_TRANSFORM - Same as BU_PO_Transform');
        ELSE
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'Before Calling COA_BU_GL_TRANSFORM');
        
          l_s3_bu := coa_business_unit_gl(p_legacy_company_val
                                         ,p_set_of_books_id
                                         ,p_legacy_account_val
                                         ,p_legacy_intercompany_val
                                         ,p_transform_id
                                         ,p_all_transform_id
                                         ,l_bu_id);
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => 'After Calling COA_BU_GL_TRANSFORM');
        END IF;
      ELSE
      
        l_s3_bu := coa_bu_transform(p_legacy_company_val
                                   ,p_legacy_department_val
                                   ,p_legacy_location_val
                                   ,p_s3_org
                                   ,p_transform_id
                                   ,p_trx_type => p_trx_type
                                   ,p_all_transform_id => p_all_transform_id);
      END IF;
      IF l_s3_bu IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA Business Unit';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_bu : ' || l_s3_bu);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_BU_TRANSFORM');
    
      --End of BU Mapping 
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER bu :' || g_status_message);
      ------------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------------
    
      --Start Department mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_DEPARTMENT_TRANSFORM');
    
      l_s3_department := coa_department_transform(p_legacy_dept_val => p_legacy_department_val
                                                 ,p_s3_org => p_s3_org
                                                 ,p_transform_id => p_transform_id
                                                 ,p_trx_type => p_trx_type
                                                 ,p_all_transform_id => p_all_transform_id);
    
      IF l_s3_department IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA Department';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_department : ' || l_s3_department);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_DEPARTMENT_TRANSFORM');
    
      --End of Department Mapping   
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER department :' ||
                        g_status_message);
      ------------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------------
    
    
    
      --Start Account mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_ACCOUNT_TRANSFORM');
    
      l_s3_account := coa_account_transform(p_legacy_account_val => p_legacy_account_val
                                           ,p_s3_org => p_s3_org
                                           ,p_transform_id => p_transform_id
                                           ,p_trx_type => p_trx_type
                                           ,p_all_transform_id => p_all_transform_id);
    
      IF l_s3_account IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA Account';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_account : ' || l_s3_account);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_ACCOUNT_TRANSFORM');
    
      --End of Account Mapping      
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER account :' ||
                        g_status_message);
      ------------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------------
    
      --Start Location mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_LOCATION_TRANSFORM');
    
      l_s3_location := coa_location_transform(p_legacy_location_val => p_legacy_location_val
                                             ,p_s3_org => p_s3_org
                                             ,p_transform_id => p_transform_id
                                             ,p_trx_type => p_trx_type
                                             ,p_all_transform_id => p_all_transform_id);
    
      IF l_s3_location IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA Location';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_location : ' || l_s3_location);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_LOCATION_TRANSFORM');
    
      --End of Location Mapping 
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER location :' ||
                        g_status_message);
      ------------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------------
    
      --Start Intercompany mapping
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Before calling COA_INTERCOMPANY_TRANSFORM');
    
      l_s3_intercompany := coa_intercompany_transform(p_legacy_company_val => p_legacy_company_val
                                                     ,p_legacy_intercompany_val => p_legacy_intercompany_val
                                                     ,p_legacy_division_val => p_legacy_division_val
                                                     ,p_s3_org => p_s3_org
                                                     ,p_transform_id => p_transform_id
                                                     ,p_trx_type => p_trx_type
                                                     ,p_all_transform_id => p_all_transform_id);
    
      IF l_s3_intercompany IS NULL
      THEN
        g_status_message := g_status_message || ' , ' ||
                            'Invalid CoA InterCompany';
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => g_status_message);
      
      END IF;
    
      fnd_file.put_line(fnd_file.log
                       ,'Final l_s3_intercompany : ' || l_s3_intercompany);
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'After completion of COA_INTERCOMPANY_TRANSFORM');
      --End Intercompany mapping   
      fnd_file.put_line(fnd_file.log
                       ,'g_status_message AFTER intercompany :' ||
                        g_status_message);
      ------------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------------
      --Start Product Line mapping
      IF p_trx_type = 'ITEM'
      THEN
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Before calling COA_ITEM_PL_TRANSFORM');
      
        fnd_file.put_line(fnd_file.log
                         ,'Calling coa_item_pl_transform..');
      
        l_s3_item_pl := coa_item_pl_master(p_legacy_product_val
                                          ,p_item_number
                                          ,p_all_transform_id
                                          ,p_transform_id
                                          ,l_acct_type
                                          ,p_s3_org);
      
        IF l_s3_item_pl IS NULL
        THEN
          g_status_message := g_status_message || ' ,' ||
                              'Invalid CoA Product Line';
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => g_status_message);
        
        END IF;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'After completion of COA_ITEM_PL_TRANSFORM');
      
        l_s3_pl := l_s3_item_pl;
      ELSIF p_trx_type = 'GL'
      THEN
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Before calling COA_GL_PL_TRANSFORM');
      
        fnd_file.put_line(fnd_file.log
                         ,'Calling coa_gl_pl_transform..');
      
        l_s3_gl_pl := coa_gl_pl_transform(p_set_of_books_id
                                         ,p_legacy_company_val
                                         ,p_legacy_account_val
                                         ,p_legacy_intercompany_val
                                         ,p_legacy_product_val
                                         ,p_s3_org
                                         ,p_transform_id
                                         ,p_trx_type
                                         ,p_all_transform_id);
      
        IF l_s3_gl_pl IS NULL
        THEN
          g_status_message := g_status_message || ' ,' ||
                              'Invalid CoA GL Product Line';
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => g_status_message);
        
        END IF;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'After completion of COA_GL_PL_TRANSFORM');
      
        l_s3_pl := l_s3_gl_pl;
      
      ELSE
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'Before calling COA_PL_TRANSFORM');
      
        l_s3_pl := coa_product_line_transform(p_legacy_product_val
                                             ,p_item_number
                                             ,p_all_transform_id
                                             ,p_transform_id
                                             ,l_acct_type
                                             ,p_s3_org);
      
        IF l_s3_pl IS NULL
        THEN
          g_status_message := g_status_message || ' , ' ||
                              'Invalid CoA Product Line';
        
          fnd_log.STRING(log_level => fnd_log.level_statement
                        ,module => g_module
                        ,message => g_status_message);
        
        END IF;
      
        fnd_log.STRING(log_level => fnd_log.level_statement
                      ,module => g_module
                      ,message => 'After completion of COA_PL_TRANSFORM');
      
        --End of Product Line mapping
      END IF;
    
    END IF; --end g_status ='S'
    fnd_file.put_line(fnd_file.log
                     ,'g_status_message AFTER pl :' || g_status_message);
    --For CoA errors
    IF g_status_message IS NOT NULL
    THEN
      p_err_code     := '2';
      p_err_msg      := substr(' ,For ' || p_field_name || ': ' ||
                               g_status_message
                              ,1
                              ,4000);
      p_s3_gl_string := NULL;
    
      fnd_log.STRING(log_level => fnd_log.level_statement
                    ,module => g_module
                    ,message => 'Error in COA Transform : ' || p_err_msg);
    
      RETURN;
    END IF;
  
    p_err_code := '0';
    p_err_msg  := 'SUCCESS';
  
    --For CoA errors
  
    --Return concatenated string if there are no errors
    p_s3_gl_string := l_s3_company || '.' || l_s3_bu || '.' ||
                      l_s3_department || '.' || l_s3_account || '.' ||
                      l_s3_pl || '.' || l_s3_location || '.' ||
                      l_s3_intercompany || '.' || '000';
  
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'S3 Segments :: Segment1 : ' || l_s3_company ||
                              ' ,Segment2 : ' || l_s3_bu || ' ,Segment3 : ' ||
                              l_s3_department || ' ,Segment4 : ' ||
                              l_s3_account || ' ,Segment5 : ' || l_s3_pl ||
                              ' ,Segment6 : ' || l_s3_location ||
                              ' ,Segment7 : ' || l_s3_intercompany ||
                              ' ,Segment8 : ' || '000');
  
    fnd_file.put_line(fnd_file.log
                     ,'S3 Segments :: Segment1 : ' || l_s3_company ||
                      ' ,Segment2 : ' || l_s3_bu || ' ,Segment3 : ' ||
                      l_s3_department || ' ,Segment4 : ' || l_s3_account ||
                      ' ,Segment5 : ' || l_s3_pl || ' ,Segment6 : ' ||
                      l_s3_location || ' ,Segment7 : ' ||
                      l_s3_intercompany || ' ,Segment8 : ' || '000');
  
    fnd_log.STRING(log_level => fnd_log.level_statement
                  ,module => g_module
                  ,message => 'End of COA_TRANSFORM');
  
  END coa_transform;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: .This procedure takes the S3 GL string as input and updates the S3 CoA segments in 
  --           extract table 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_update(p_gl_string               IN VARCHAR2
                      , --concatenated GL string
                       p_stage_tab               IN VARCHAR2
                      , -- staging table name
                       p_stage_primary_col       IN VARCHAR2
                      , -- staging table primary column name
                       p_stage_primary_col_val   IN VARCHAR2
                      , -- staging table primary column value
                       p_stage_company_col       IN VARCHAR2
                      , -- s3_segment1
                       p_stage_business_unit_col IN VARCHAR2
                      , --s3_segment2
                       p_stage_department_col    IN VARCHAR2
                      , --s3_segment3
                       p_stage_account_col       IN VARCHAR2
                      , --s3_segment4
                       p_stage_product_line_col  IN VARCHAR2
                      , --s3_segment5
                       p_stage_location_col      IN VARCHAR2
                      , --s3_segment6
                       p_stage_intercompany_col  IN VARCHAR2
                      , --s3_segment7
                       p_stage_future_col        IN VARCHAR2
                      , --s3_segment8
                       p_coa_err_msg             IN VARCHAR2
                      , --error message during CoA transform
                       p_err_code                OUT VARCHAR2
                      ,p_err_msg                 OUT VARCHAR2) AS
  
    l_company_val       VARCHAR2(25);
    l_business_unit_val VARCHAR2(25);
    l_department_val    VARCHAR2(25);
    l_account_val       VARCHAR2(25);
    l_product_line_val  VARCHAR2(25);
    l_location_val      VARCHAR2(25);
    l_intercompany_val  VARCHAR2(25);
    l_future_val        VARCHAR2(25);
    l_dyn_statement     VARCHAR2(3000);
    l_stage_status_col  VARCHAR2(30) := 'TRANSFORM_STATUS';
    l_stage_error_col   VARCHAR2(30) := 'TRANSFORM_ERROR';
    l_fail_status       VARCHAR2(10) := 'FAIL';
    l_pass_status       VARCHAR2(10) := 'PASS';
  BEGIN
    IF p_coa_err_msg NOT LIKE '%SUCCESS%'
    THEN
      --'%Invalid%' OR p_coa_err_msg LIKE '%Removed in S3%' THEN
      l_dyn_statement := '';
      l_dyn_statement := 'update ' || p_stage_tab || ' set ' ||
                         l_stage_status_col || ' = ''' || l_fail_status ||
                         ''', ' || l_stage_error_col || ' = ' ||
                         l_stage_error_col || '|| ''' || p_coa_err_msg ||
                         ''' where ' || p_stage_primary_col || ' = ' ||
                         p_stage_primary_col_val;
      BEGIN
        EXECUTE IMMEDIATE l_dyn_statement;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          p_err_code := '2';
          p_err_msg  := substr('Error in dynamic statement ' ||
                               l_dyn_statement || 'sqlerrm: ' || SQLERRM
                              ,1
                              ,4000);
      END;
      RETURN;
    ELSIF p_gl_string IS NOT NULL
    THEN
      SELECT substr(p_gl_string
                   ,1
                   ,3)
      INTO l_company_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,5
                   ,3)
      INTO l_business_unit_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,9
                   ,4)
      INTO l_department_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,14
                   ,6)
      INTO l_account_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,21
                   ,4)
      INTO l_product_line_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,26
                   ,3)
      INTO l_location_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,30
                   ,3)
      INTO l_intercompany_val
      FROM dual;
      SELECT substr(p_gl_string
                   ,34
                   ,3)
      INTO l_future_val
      FROM dual;
    
      l_dyn_statement := 'update ' || p_stage_tab || ' set ' ||
                         p_stage_company_col || ' = ''' || l_company_val ||
                         ''',' || p_stage_business_unit_col || ' = ''' ||
                         l_business_unit_val || ''',' ||
                         p_stage_department_col || ' = ''' ||
                         l_department_val || ''',' || p_stage_account_col ||
                         ' = ''' || l_account_val || ''',' ||
                         p_stage_product_line_col || ' = ''' ||
                         l_product_line_val || ''',' ||
                         p_stage_location_col || ' = ''' || l_location_val ||
                         ''',' || p_stage_intercompany_col || ' = ''' ||
                         l_intercompany_val || ''',' || p_stage_future_col ||
                         ' = ''' || l_future_val || ''',' ||
                         l_stage_status_col || ' = CASE WHEN ' ||
                         l_stage_error_col || ' IS NOT NULL THEN ''' ||
                         l_fail_status || ''' ELSE ''' || l_pass_status ||
                         ''' END  where ' || p_stage_primary_col || ' = ' ||
                         p_stage_primary_col_val;
    
      --fnd_file.put_line(fnd_file.log,l_dyn_statement);
      BEGIN
        EXECUTE IMMEDIATE l_dyn_statement;
        COMMIT;
        p_err_code := '0';
        p_err_msg  := 'SUCCESS';
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          p_err_code := '2';
          p_err_msg  := substr('Error in dynamic statement ' ||
                               l_dyn_statement || 'sqlerrm: ' || SQLERRM
                              ,1
                              ,4000);
      END;
    END IF;
  END coa_update;

END xxs3_coa_transform_pkg;
/
