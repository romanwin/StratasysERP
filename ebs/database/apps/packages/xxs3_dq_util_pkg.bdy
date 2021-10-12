CREATE OR REPLACE PACKAGE BODY xxs3_dq_util_pkg AS
  ----------------------------------------------------------------------------
  --  name:            XXS3_DQ_UTIL_PKG
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   19/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing all DQ checks

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  --  purpose :        Function to validate against value sets

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------
  FUNCTION check_valueset(p_set_code VARCHAR2
                         ,p_code     VARCHAR2 /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              P_MODE     VARCHAR2 DEFAULT 'ALL'*/)
  
   RETURN NUMBER IS
  
    l_check NUMBER := 0;
  
    CURSOR c IS
      SELECT COUNT(*)
      FROM fnd_flex_values_vl  p
          ,fnd_flex_value_sets vs
      WHERE flex_value = p_code
      AND p.flex_value_set_id = vs.flex_value_set_id
      AND vs.flex_value_set_name = p_set_code
      AND nvl(p.enabled_flag
            ,'N') = 'Y'; /*AND P_MODE = 'ACTIVE') OR
                                                                                                                                                                                                                                                                                                 P_MODE = 'ALL');*/
  
    l_tmp VARCHAR2(200);
  
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_check;
    CLOSE c;
  
    RETURN l_check;
  END check_valueset;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate UOM
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_900(p_uom IN VARCHAR2) RETURN VARCHAR2 IS
  
    --l_uom_check VARCHAR2(10);
  BEGIN
  
    IF p_uom = 'EA'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_900;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate quantity
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_901(p_quantity IN VARCHAR2) RETURN VARCHAR2 IS
  
    --l_uom_check VARCHAR2(10);
  BEGIN
  
    IF p_quantity = 1
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_901;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate valueset
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_902(p_value_set_code IN VARCHAR2
                  ,p_value_code     IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_valueset_check VARCHAR2(1000);
  BEGIN
  
    l_valueset_check := check_valueset(p_set_code => p_value_set_code
                                      ,p_code => p_value_code);
  
    IF l_valueset_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_902;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate valueset XXCS_PRICE_LISTS
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_903(p_list_header_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO l_check
    FROM qp_list_headers_tl
    WHERE list_header_id = p_list_header_id
    AND LANGUAGE = 'US';
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_903;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate BEGIN_BALANCE_CHECK
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  09/09/2016  Paulami Ray / Sateesh V    Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_904 --BEGIN_BALANCE_CH
   RETURN VARCHAR2 IS
    l_begin_balance_dr NUMBER;
    l_begin_balance_cr NUMBER;
  
  BEGIN
    SELECT SUM(begin_balance_dr)
    INTO l_begin_balance_dr
    FROM xxobjt.xxs3_rtr_gl_balances; --87316377516.47
  
    SELECT SUM(begin_balance_cr)
    INTO l_begin_balance_cr
    FROM xxobjt.xxs3_rtr_gl_balances; --87317498917.71
  
    IF l_begin_balance_dr <> l_begin_balance_cr
    THEN
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_904;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate BEGIN_BALANCE_BEQ_CHK
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  09/09/2016  Paulami Ray / Sateesh V    Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_905 --BEGIN_BALANCE_BEQ_CHK
   RETURN VARCHAR2 IS
    l_begin_balance_dr_beq NUMBER;
    l_begin_balance_cr_beq NUMBER;
  
  BEGIN
    SELECT SUM(begin_balance_dr_beq)
    INTO l_begin_balance_dr_beq
    FROM xxobjt.xxs3_rtr_gl_balances; --87316377516.47
  
    SELECT SUM(begin_balance_cr_beq)
    INTO l_begin_balance_cr_beq
    FROM xxobjt.xxs3_rtr_gl_balances; --87317498917.71
  
    IF l_begin_balance_dr_beq <> l_begin_balance_cr_beq
    THEN
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_905;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PERIOD_NET_CHK
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  09/09/2016  Paulami Ray / Sateesh V    Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_906 --PERIOD_NET_CHK
   RETURN VARCHAR2 IS
    l_period_net_dr NUMBER;
    l_period_net_cr NUMBER;
  
  BEGIN
    SELECT SUM(period_net_dr)
    INTO l_period_net_dr
    FROM xxobjt.xxs3_rtr_gl_balances; --87316377516.47
  
    SELECT SUM(period_net_cr)
    INTO l_period_net_cr
    FROM xxobjt.xxs3_rtr_gl_balances; --87317498917.71
  
    IF l_period_net_dr <> l_period_net_cr
    THEN
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_906;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PERIOD_NET_BEQ_CHK
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  09/09/2016  Paulami Ray / Sateesh V    Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_907 --PERIOD_NET_BEQ_CHK
   RETURN VARCHAR2 IS
    l_period_net_dr_beq NUMBER;
    l_period_net_cr_beq NUMBER;
  
  BEGIN
    SELECT SUM(period_net_dr_beq)
    INTO l_period_net_dr_beq
    FROM xxobjt.xxs3_rtr_gl_balances; --87316377516.47
  
    SELECT SUM(period_net_cr_beq)
    INTO l_period_net_cr_beq
    FROM xxobjt.xxs3_rtr_gl_balances; --87317498917.71
  
    IF l_period_net_dr_beq <> l_period_net_cr_beq
    THEN
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_907;

  /* -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PARTY_NAME
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION EQT_001(P_LEGACY_PARTY_ID IN VARCHAR2, P_PARTY_TYPE IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    LN_COUNT_PARTY NUMBER;
    LC_RESULT      BOOLEAN;
    --
  BEGIN
    --
    BEGIN
      \*SELECT count(party_name)
        INTO ln_count_party
        from xxobjt.XXS3_OTC_PARTIES
       WHERE regexp_like(party_name, '^The(\s)')
          OR LENGTH(party_name) = 1
      --OR     REGEXP_LIKE(party_name,  'Inc.|Inc$|Ltd.|Ltd|Corp.|Corp|,|.|(|)')*\
      SELECT 1
        INTO LN_COUNT_PARTY
        FROM XXOBJT.XXS3_OTC_PARTIES
       WHERE PARTY_TYPE = 'ORGANIZATION'
            --AND PARTY_NAME = 'Sony'
         AND LEGACY_PARTY_ID = P_LEGACY_PARTY_ID
         AND (REGEXP_LIKE(PARTY_NAME, '^The(\s)') OR LENGTH(PARTY_NAME) = 1 OR
             REGEXP_LIKE(PARTY_NAME, 'Inc$|Ltd$|Corp$|[.]|[,]|[(]|[)]'));
    EXCEPTION
      WHEN OTHERS THEN
        LN_COUNT_PARTY := 0;
    END;
    --
    IF LN_COUNT_PARTY <> 0 THEN
      LC_RESULT := TRUE;
    ELSE
      LC_RESULT := FALSE;
    END IF;
    --
    RETURN LC_RESULT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      LC_RESULT := FALSE;
      RETURN LC_RESULT;
  END EQT_001;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PARTY_NAME in case of Perons
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION EQT_002(P_LEGACY_PARTY_ID IN VARCHAR2, P_PARTY_TYPE IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    LN_COUNT_PARTY NUMBER;
    LC_RESULT      BOOLEAN;
    --
  BEGIN
    --
    BEGIN
      SELECT 1
        INTO LN_COUNT_PARTY
        FROM XXOBJT.XXS3_OTC_PARTIES
       WHERE PARTY_TYPE = 'PERSON'
         AND LEGACY_PARTY_ID = P_LEGACY_PARTY_ID
         AND (LENGTH(PARTY_NAME) = 1 OR
             PARTY_NAME IN
             ('NA', 'AP', 'A/P', 'Accounting', 'Accounts Payable',
              'Account Payables', 'Account Management', 'Payable Accounts',
              'AP Invoices', 'Invoice', 'Invoices', 'Invoice Mail',
              'Invoicing', 'Invoicing Method', 'Invoicing Office',
              'Order Desk', 'Receiving', 'Receiving Dept',
              'Receiving Department', 'Shipping', 'Shipping Department',
              'Receiving/Shipping') OR
             REGEXP_LIKE(PARTY_NAME, '^[.](*)|^[,](*)|[@]|^\d'));
      --
    EXCEPTION
      WHEN OTHERS THEN
        LN_COUNT_PARTY := 0;
    END;
    --
    IF LN_COUNT_PARTY <> 0 THEN
      LC_RESULT := TRUE;
    ELSE
      LC_RESULT := FALSE;
    END IF;
    --
    RETURN LC_RESULT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      LC_RESULT := FALSE;
      RETURN LC_RESULT;
  END EQT_002;*/
  --


  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate balances for a particular period
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  03/11/2016  Sumana Naha                   Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_908(p_xx_glb_id NUMBER) RETURN VARCHAR2 IS
    l_period_net_dr_beq    NUMBER;
    l_period_net_cr_beq    NUMBER;
    l_begin_balance_dr_beq NUMBER;
    l_begin_balance_cr_beq NUMBER;
    l_period_net_dr        NUMBER;
    l_period_net_cr        NUMBER;
    l_begin_balance_dr     NUMBER;
    l_begin_balance_cr     NUMBER;
  
  BEGIN
    SELECT period_net_dr_beq
          ,period_net_cr_beq
          ,begin_balance_dr_beq
          ,begin_balance_cr_beq
          ,period_net_dr
          ,period_net_cr
          ,begin_balance_dr
          ,begin_balance_cr
    INTO l_period_net_dr_beq
        ,l_period_net_cr_beq
        ,l_begin_balance_dr_beq
        ,l_begin_balance_cr_beq
        ,l_period_net_dr
        ,l_period_net_cr
        ,l_begin_balance_dr
        ,l_begin_balance_cr
    FROM xxobjt.xxs3_rtr_gl_balances
    WHERE xx_glb_id = p_xx_glb_id;
  
  
    IF (l_begin_balance_dr - l_begin_balance_cr = 0)
       AND (l_begin_balance_dr_beq - l_begin_balance_cr_beq = 0)
    -- AND (l_period_net_dr - l_period_net_cr = 0)
    -- AND (l_period_net_dr_beq - l_period_net_cr_beq) = 0
    
    THEN
      RETURN 'FALSE';
    
    ELSE
      RETURN 'TRUE';
    END IF;
  
  END eqt_908;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Accounted DR and CR for unearned revenue
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  02/11/2016  Sumana Naha                   Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_909 RETURN VARCHAR2 IS
    l_sum_accounted_dr NUMBER;
    l_sum_accounted_cr NUMBER;
  
  BEGIN
    SELECT SUM(accounted_dr)
          ,SUM(accounted_cr)
    INTO l_sum_accounted_dr
        ,l_sum_accounted_cr
    FROM xxobjt.xxs3_rtr_unearned_rev;
  
  
    IF l_sum_accounted_dr = l_sum_accounted_cr
    
    THEN
      RETURN 'TRUE';
    
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_909;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Accounted DR and CR for unearned revenue for particular invoice line
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  02/11/2016  Sumana Naha                   Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_910(p_legacy_cust_trx_line_id NUMBER) RETURN VARCHAR2 IS
    l_line_accounted_dr NUMBER;
    l_line_accounted_cr NUMBER;
  
  BEGIN
    SELECT SUM(accounted_dr)
          ,SUM(accounted_cr)
    INTO l_line_accounted_dr
        ,l_line_accounted_cr
    FROM xxobjt.xxs3_rtr_unearned_rev
    WHERE p_legacy_cust_trx_line_id = legacy_customer_trx_line_id;
  
  
    IF l_line_accounted_dr = l_line_accounted_cr
    
    THEN
      RETURN 'TRUE';
    
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_910;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PERSON_FIRST_NAME
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_018(p_person_first_name IN VARCHAR2
                  ,p_party_type        IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    --ln_count_party NUMBER;
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF p_party_type = 'PERSON'
    THEN
      IF p_person_first_name IS NULL
      THEN
        lc_result := TRUE;
      ELSE
        lc_result := FALSE;
      END IF;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_018;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PERSON_FIRST_NAME
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_019(p_person_last_name IN VARCHAR2
                  ,p_party_type       IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    --ln_count_party NUMBER;
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF p_party_type = 'PERSON'
    THEN
      IF p_person_last_name IS NULL
      THEN
        lc_result := TRUE;
      ELSE
        lc_result := FALSE;
      END IF;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_019;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate GROUP_TYPE
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_099(p_party_type IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF p_party_type = 'GROUP'
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_099;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate COUNTRY
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_012(p_country IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF (p_country IS NULL
       --AND p_country IN ()
       )
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_012;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate ADDRESS1 is not missing
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_020(p_address1 IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    --IF p_party_type = 'ORGANIZATION' THEN
    IF p_address1 IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    --ELSE
    --lc_result := FALSE;
    --END IF;
    RETURN lc_result;
  END eqt_020;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate ADDRESS4 does not contain '** AVALARA UNABLE TO VALIDATE ADDRESS **'
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_013(p_address4 IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF p_address4 = '** AVALARA UNABLE TO VALIDATE ADDRESS **'
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_013;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate TIMEZONE is not missing
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_014(p_timezone IN NUMBER)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    --IF p_party_type = 'ORGANIZATION' THEN
    IF p_timezone IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_014;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate CITY
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_015(p_city IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    --IF p_party_type = 'ORGANIZATION' THEN
    IF p_city IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    --ELSE
    --lc_result := FALSE;
    --END IF;
    RETURN lc_result;
  END eqt_015;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate POSTAL CODE
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_016(p_postal_code IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    --IF p_party_type = 'ORGANIZATION' THEN
    IF p_postal_code IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    -- ELSE
    -- lc_result := FALSE;
    --END IF;
    RETURN lc_result;
  END eqt_016;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate PARTY TYPE LOV
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_017(p_value IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    ln_count_party NUMBER;
    lc_result      BOOLEAN;
    --
   BEGIN
      IF p_value NOT IN ('ORGANIZATION', 'GROUP', 'PERSON', 'PARTY_RELATIONSHIP') THEN
       lc_result := TRUE;
      ELSE
       lc_result := FALSE;
      END IF;
    
      RETURN lc_result;
   END eqt_017;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate NULL VALUES
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_028(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_028;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_029
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  10/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_029(p_attribute2 IN VARCHAR2
                  ,p_attribute3 IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF p_attribute2 IS NOT NULL THEN
     IF p_attribute3 IS NULL THEN 
      lc_result := TRUE;
     ELSE 
      lc_result := FALSE;
     END IF;
    END IF;
    RETURN lc_result;
  END eqt_029;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate NOT NULL VALUE
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_030(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value IS NOT NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_030;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Sales Channel LOV
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_031(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    l_count   NUMBER;
    --
  BEGIN
    IF p_value IN ('DIRECT','INDIRECT')
    THEN
      lc_result := FALSE;
    ELSE
      lc_result := TRUE;
    END IF;
    RETURN lc_result;
  END eqt_031;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate valueset FND_DATE_STANDARD
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_904(p_date IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_date   DATE;
    l_format VARCHAR2(10);
  
  BEGIN
    SELECT fnd_date.canonical_to_date(p_date) INTO l_date FROM dual;
  
    IF l_date IS NOT NULL
    THEN
      l_format := 'TRUE';
      RETURN l_format;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_format := 'FALSE';
      RETURN l_format;
  END eqt_904;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_036
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_036(p_hold_all_payments_flag    IN VARCHAR2
                  ,p_hold_future_payments_flag IN VARCHAR2
                  ,p_hold_reason               IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_check VARCHAR2(10);
  BEGIN
  
    IF p_hold_all_payments_flag = 'N'
       AND p_hold_future_payments_flag = 'N'
    THEN
      IF p_hold_reason IS NULL
      THEN
        l_check := 'TRUE';
      ELSE
        l_check := 'FALSE';
      END IF;
    ELSIF p_hold_all_payments_flag = 'Y'
          OR p_hold_future_payments_flag = 'Y'
    THEN
      IF p_hold_reason IS NOT NULL
      THEN
        l_check := 'TRUE';
      ELSE
        l_check := 'FALSE';
      END IF;
    END IF;
  
    RETURN l_check;
  END eqt_036;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_004
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_004(p_address VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE regexp_like(p_address
                     ,'[,.@%()]')
    OR p_address LIKE '% '
    OR p_address LIKE ' %'
    OR length(p_address) <= 4;
  
    IF l_check > 0
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_004;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_005
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  /*FUNCTION EQT_005( p_city VARCHAR2) RETURN VARCHAR2 IS
  
     l_check NUMBER;
    BEGIN
  
     SELECT count(*)
     INTO l_check
     FROM dual
     WHERE regexp_like (p_city,'[,.@%()]')
     OR length(p_city)<=3;
  
    IF l_check > 0 THEN
     RETURN 'FALSE';
    ELSE
     RETURN 'TRUE';
    END IF;
  END EQT_005;
  */
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_040
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_040(p_entity VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE regexp_like(p_entity
                     ,'[%]');
  
    IF l_check > 0
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_040;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Valid Person
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_042(p_id NUMBER) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    l_count   NUMBER;
    --
  BEGIN
    SELECT COUNT(person_id)
    INTO l_count
    FROM per_all_people_f
    WHERE employee_number = nvl(p_id
                               ,-99)
    AND current_employee_flag != 'Y';
    IF (l_count <> 0)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_042;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate credit check value
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_043(p_cust_account_id NUMBER
                  ,p_credit_checking VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result   BOOLEAN;
    l_cust_type VARCHAR2(1);
    --
  BEGIN
    SELECT customer_type
    INTO l_cust_type
    FROM hz_cust_accounts
    WHERE cust_account_id = p_cust_account_id;
    IF (l_cust_type = 'I')
    THEN
      IF (p_credit_checking = 'Y')
      THEN
        lc_result := TRUE;
      ELSE
        lc_result := FALSE;
      END IF;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_043;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate 'Y'  VALUES FOR 'US'
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_044(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value <> 'Y'
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_044;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate 'N'  VALUES FOR 'US'
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Santanu Bhaumik                 Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_035(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value = 'N'
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_035;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate customer profile class
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_045(p_cust_account_id NUMBER
                  ,p_profile_class   NUMBER) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    l_count   NUMBER;
    --
  BEGIN
    SELECT COUNT(organization_id)
    INTO l_count
    FROM hr_organization_units_v
    WHERE organization_id IN
          (SELECT org_id
           FROM hz_cust_accounts
           WHERE cust_account_id = p_cust_account_id)
    AND country = 'US';
    IF (l_count <> 0 AND p_profile_class <> 1040)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_045;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate customer STANDARD TERMS
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_046(p_cust_account_id NUMBER
                  ,p_standard_terms  NUMBER) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    l_count   NUMBER;
    --
  BEGIN
    SELECT COUNT(organization_id)
    INTO l_count
    FROM hr_organization_units_v
    WHERE organization_id IN
          (SELECT org_id
           FROM hz_cust_accounts
           WHERE cust_account_id = p_cust_account_id)
    AND country = 'US';
    IF (l_count <> 0 AND p_standard_terms <> 1120)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_046;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate STATEMENT CYCLE ID
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_048(p_send_statements    VARCHAR2
                  ,p_statement_cycle_id NUMBER) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    l_count   NUMBER;
    --
  BEGIN
    IF (p_send_statements = 'Y' AND p_statement_cycle_id IS NULL)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_048;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate STATEMENT CYCLE ID
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_049(p_send_statements     VARCHAR2
                  ,p_tax_printing_option VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF (p_send_statements = 'Y' AND p_tax_printing_option = 'TOTAL ONLY')
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_049;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate CURRENCY
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_050(p_currency VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF (p_currency != 'USD')
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_050;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate CURRENCY
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_051(p_credit_limit VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF (p_credit_limit < 1000)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_051;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate CUSTOMER PROFILE ATTRIBUTES
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_052(p_att1 VARCHAR2
                  ,p_att  VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF (p_att1 IS NOT NULL AND p_att IS NULL)
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_052;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_021
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_021(p_email VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE regexp_like(p_email
                     ,'[@]');
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_021;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EMAIL FORMAT
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_022(p_email_format  IN VARCHAR2
                  ,p_email_address IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF (p_email_address IS NOT NULL)
    THEN
      IF (p_email_format IS NULL)
      THEN
        lc_result := TRUE;
      ELSE
        lc_result := FALSE;
      END IF;
    END IF;
    RETURN lc_result;
  END eqt_022;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EMAIL FORMAT
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_023(p_email_format  IN VARCHAR2
                  ,p_email_address IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    --
    IF (p_email_format IS NOT NULL)
    THEN
      IF (p_email_address IS NULL)
      THEN
        lc_result := TRUE;
      ELSE
        lc_result := FALSE;
      END IF;
    END IF;
    RETURN lc_result;
  END eqt_023;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_025
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  10/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_025(p_value IN VARCHAR2)
  --
   RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
    IF p_value NOT IN ('SHIP_TO','BILL_TO')
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_025;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_026
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_026(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_026;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_027
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  29/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_027(p_value VARCHAR2) RETURN BOOLEAN IS
    --
    lc_result BOOLEAN;
    --
  BEGIN
  
    IF p_value IS NULL
    THEN
      lc_result := TRUE;
    ELSE
      lc_result := FALSE;
    END IF;
    RETURN lc_result;
  END eqt_027;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_001
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_001(p_entity VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE upper(substr(p_entity
                      ,1
                      ,4)) <> upper('The ')
    AND length(p_entity) > 1
    AND regexp_like(p_entity
                  ,'[A-Za-z]'
                  ,'i')
    AND p_entity NOT LIKE '%@%'
    AND p_entity NOT LIKE '%#%'
    AND p_entity NOT LIKE '%''%''%'
    AND p_entity NOT LIKE '%.%'
    AND p_entity NOT LIKE '%,%'
    AND p_entity NOT LIKE '%(%'
    AND p_entity NOT LIKE '%)%'
    AND p_entity NOT LIKE '% '
    AND p_entity NOT LIKE ' %';
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_001;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_002
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_002(p_entity VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE substr(p_entity
                ,1
                ,1) NOT IN ('0'
                           ,'1'
                           ,'2'
                           ,'3'
                           ,'4'
                           ,'5'
                           ,'6'
                           ,'7'
                           ,'8'
                           ,'9'
                           ,'.'
                           ,',')
    AND length(p_entity) > 1
    AND regexp_like(p_entity
                  ,'[A-Za-z]'
                  ,'i')
    AND p_entity NOT LIKE '%@%'
    AND p_entity NOT LIKE '%#%'
    AND p_entity NOT IN ('NA'
                       ,'AP'
                       ,'A/P'
                       ,'Accounting'
                       ,'Accounts Payable'
                       ,'Account Payables'
                       ,'Account Management'
                       ,'Payable Accounts'
                       ,'Order Desk'
                       ,'Receiving'
                       ,'Receiving Dept'
                       ,'Receiving Department'
                       ,'Shipping'
                       ,'Shipping Department'
                       ,'Receiving/Shipping'
                       ,'AP Invoices'
                       ,'Invoice'
                       ,'Invoices'
                       ,'Invoice Mail'
                       ,'Invoicing'
                       ,'Invoicing Method'
                       ,'Invoicing Office')
    AND p_entity NOT LIKE '% '
    AND p_entity NOT LIKE ' %';
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_002;

  ---------Standardize City-------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_005
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_005(p_entity VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM dual
    WHERE regexp_like(p_entity
                     ,'[A-Za-z]'
                     ,'i') ---exclude asian characters
    AND p_entity NOT LIKE '%@%'
    AND p_entity NOT LIKE '%,%'
    AND p_entity NOT LIKE '%.%'
    AND p_entity NOT LIKE '%(%'
    AND p_entity NOT LIKE '%)%'
    AND p_entity NOT LIKE '%''%''%'
    AND length(p_entity) > 3
    AND p_entity NOT LIKE '% '
    AND p_entity NOT LIKE ' %';
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_005;

  ----------------- Standardize State Code-----------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_006
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_006(p_state   VARCHAR2
                  ,p_country VARCHAR2) RETURN VARCHAR2 IS
  
    l_length NUMBER;
    l_check  NUMBER;
  BEGIN
  
    SELECT length(p_state) INTO l_length FROM dual;
  
    IF l_length = 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_state_lkp
      WHERE
      /*lookup_type like '%Country%'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      and*/
       regexp_like(p_state
                  ,'[A-Za-z]'
                  ,'i')
       AND code = p_state
       AND country_code = p_country;
    
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_006;

  ----------------------Standardize  Province Code-----
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_007
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_007(p_province VARCHAR2
                  ,p_country  VARCHAR2) RETURN VARCHAR2 IS
  
    l_check  NUMBER;
    l_length NUMBER;
  BEGIN
  
    SELECT length(p_province) INTO l_check FROM dual;
  
    IF l_length = 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_province_lkp
      WHERE
      /*lookup_type like '%Country%'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      and*/
       regexp_like(p_province
                  ,'[A-Za-z]'
                  ,'i')
       AND code = p_province
       AND country_code = p_country;
    
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_007;

  ----------------- Standardize Country Code-----------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_008
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_008(p_country VARCHAR2) RETURN VARCHAR2 IS
  
    l_length NUMBER;
    l_check  NUMBER;
  BEGIN
  
    SELECT length(p_country) INTO l_length FROM dual;
  
    IF l_length = 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_country_lkp
      WHERE
      /*lookup_type like '%Country%'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      and*/
       regexp_like(p_country
                  ,'[A-Za-z]'
                  ,'i')
       AND code = p_country;
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_008;

  ------------------ Standardize State Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_009
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_009(p_state   VARCHAR2
                  ,p_country VARCHAR2) RETURN VARCHAR2 IS
  
    l_length NUMBER;
    l_check  NUMBER;
  BEGIN
  
    SELECT length(p_state) INTO l_length FROM dual;
  
    IF l_length > 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_state_lkp
      WHERE
      --lookup_type like '%Country%'
       regexp_like(p_state
                  ,'[A-Za-z]'
                  ,'i')
       AND short_name = p_state
       AND country_code = p_country
       AND p_country NOT LIKE '% '
       AND p_country NOT LIKE ' %'
       AND p_state NOT LIKE '% '
       AND p_state NOT LIKE ' %';
    
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_009;

  ------------------ Standardize Province Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_010
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_010(p_province VARCHAR2
                  ,p_country  VARCHAR2) RETURN VARCHAR2 IS
  
    l_length NUMBER;
    l_check  NUMBER;
  BEGIN
  
    SELECT length(p_province) INTO l_length FROM dual;
  
    IF l_length > 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_province_lkp
      WHERE
      --lookup_type like '%Country%'
       regexp_like(p_province
                  ,'[A-Za-z]'
                  ,'i')
       AND short_name = p_province
       AND country_code = p_country
       AND p_country NOT LIKE '% '
       AND p_country NOT LIKE ' %'
       AND p_province NOT LIKE '% '
       AND p_province NOT LIKE ' %';
    
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_010;

  ----------------- Standardize Country Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_011
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_011(p_country VARCHAR2) RETURN VARCHAR2 IS
  
    l_length NUMBER;
    l_check  NUMBER;
  BEGIN
  
    SELECT length(p_country) INTO l_length FROM dual;
  
    IF l_length > 2
    THEN
    
      SELECT COUNT(*)
      INTO l_check
      FROM xxobjt.xxs3_country_lkp
      WHERE
      --lookup_type like '%Country%'
       regexp_like(p_country
                  ,'[A-Za-z]'
                  ,'i')
       AND p_country NOT LIKE '% '
       AND p_country NOT LIKE ' %'
       AND short_name = p_country;
    
    END IF;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_011;

  ------------------ Standardize  Province Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_010
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_010(p_province VARCHAR2) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM xxobjt.xxs3_province_lkp
    WHERE regexp_like(p_province
                     ,'[A-Za-z]'
                     ,'i')
    AND code = p_province
    AND p_province NOT LIKE '% '
    AND p_province NOT LIKE ' %';
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_010;

  ------------------ Supplier Business Type US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_053
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_053(p_business_type VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF upper(p_business_type) = 'DIRECT'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_053;

  ------------------ FA Locations Segment 1 US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_053
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_057(p_fa_loc_segment1 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_fa_loc_segment1 IN ('USA-MA', 'USA-MN')
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_057;

  ------------------ FA Locations Segment 2 US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_058
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_058(p_fa_loc_segment2 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_fa_loc_segment2 IN ('BILLERICA', 'EDEN PRAIRIE', 'MINNEAPOLIS')
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_058;

  ------------------ FA Locations Segment 3 US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_059
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_059(p_fa_loc_segment3 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_fa_loc_segment3 IN ('CORPORATE', 'NASH', 'OPS', 'SKUNKWORKS',
        'SMACS', 'WALLACE', 'EDENVALE')
       OR p_fa_loc_segment3 IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_059;

  ------------------ Depreciation Start Date US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT-072
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_072(p_deprn_start_date DATE) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_deprn_start_date IS NOT NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_072;

  ------------------ Always equals Yes - US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_061
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_061(p_flag VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_flag = 'YES'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_061;

  ------------------ Missing Basic Rate US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_062
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_062(p_basic_rate         NUMBER
                  ,p_asset_cat_segment1 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_basic_rate = 0
    THEN
      IF p_asset_cat_segment1 LIKE 'INTANGIBLE%'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    ELSIF p_basic_rate != 0
    THEN
      IF p_asset_cat_segment1 LIKE 'INTANGIBLE%'
      THEN
        RETURN 'FALSE';
      ELSE
        RETURN 'TRUE';
      END IF;
    END IF;
  END eqt_062;

  ------------------ Missing Adjusted Rate US------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_063
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_063(p_adjusted_rate      NUMBER
                  ,p_asset_cat_segment1 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_asset_cat_segment1 LIKE 'INTANGIBLE%'
    THEN
      IF p_adjusted_rate != 0
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_063;

  ------------------ EOFY ADJ Cost------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_064
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_064(p_eofy_adj_cost          NUMBER
                  ,p_retirement_id          NUMBER
                  ,p_date_placed_in_service DATE) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_retirement_id IS NOT NULL
       OR p_date_placed_in_service >
       to_date('31-DEC-' || extract(YEAR FROM SYSDATE))
    THEN
      IF p_eofy_adj_cost IS NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_064;

  ------------------ EOY Formula Factor------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_065
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_065(p_eofy_adj_cost       NUMBER
                  ,p_eofy_formula_factor NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
    IF (p_eofy_adj_cost IS NOT NULL AND p_eofy_formula_factor = 1)
       OR (p_eofy_adj_cost IS NULL AND p_eofy_formula_factor IS NULL)
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_065;

  ------------------ Invalid Current Units value------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_066
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_066(p_current_units NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
    IF (p_current_units >= 0 AND p_current_units <= 100)
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_066;

  ------------------ Missing Manufacture Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_067
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_067(p_manufacturer_name       VARCHAR2
                  ,p_attribute_category_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_attribute_category_code IN
       ('MACHINES.AGENT LOANER', 'MACHINES.INVENTORY',
        'MACHINES.RENTAL UNIT', 'MACHINES.SHOW SYSTEMS')
    THEN
      IF p_manufacturer_name IS NOT NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_067;

  ------------------ Missing Serial Number------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_068
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_068(p_serial_number           VARCHAR2
                  ,p_attribute_category_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_attribute_category_code IN
       ('MACHINES.AGENT LOANER', 'MACHINES.INVENTORY',
        'MACHINES.RENTAL UNIT', 'MACHINES.SHOW SYSTEMS')
    THEN
      IF p_serial_number IS NOT NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_068;

  ------------------ Missing Model Number------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_069
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_069(p_model_number            VARCHAR2
                  ,p_attribute_category_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_attribute_category_code IN
       ('MACHINES.AGENT LOANER', 'MACHINES.INVENTORY',
        'MACHINES.RENTAL UNIT', 'MACHINES.SHOW SYSTEMS')
    THEN
      IF p_model_number IS NOT NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_069;

  ------------------ Valid Asset Key-----------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_151
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_151(p_asset_key_segment1 VARCHAR2
                  ,p_asset_key_segment2 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF (p_asset_key_segment1 IN ('FDM', 'POLYJET', 'NONE') AND
       p_asset_key_segment2 IN
       ('NONE', '400MC', '360MC', '900MC', '380MC', '450MC', '250MC',
        'Objet 24', 'Objet 30', 'Objet 30 Pro', 'Objet 30 Prime',
        'Eden 260', 'Objet 260', 'Objet 500', 'Objet J750', 'Objet 1000',
        'Mojo', 'uPrint', 'Dimension'))
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_151;

  ------------------ Valid Attribute Category Code------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_070
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_070(p_asset_cat_segment1 VARCHAR2
                  ,p_asset_cat_segment2 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF (p_asset_cat_segment1 IN
       ('COMPUTERS', 'FURNITURE&FIXTURES', 'INTANGIBLE',
        'LAND AND BUILDINGS', 'LEASEHOLD IMP', 'MACHINERY AND EQUIP',
        'MACHINES', 'VEHICLES') AND
       p_asset_cat_segment2 IN
       ('COMPUTERS', 'ERP SYSTEM', 'HARDWARE', 'SOFTWARE', 'OFFICE EQUIPM',
        'OFFICE FURNITURE', 'CAPSOFTWARE', 'INTANGIBLE', 'CUSTOMER BASE',
        'PATENTS', 'TRADEMARKS', 'NON-COMPETE', 'BUILDING',
        'BUILDING IMPROVE', 'LAND', 'LEASEHOLD IMP', 'ELECTRONIC EQUIP',
        'EQUIPMENT OTHER', 'INDUSTRIAL EQUIP', 'MOLDS AND DYES', 'TOOLS',
        'AGENT LOANER', 'INVENTORY', 'RENTAL UNIT', 'SHOW SYSTEMS',
        'VEHICLES'))
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_070;

  ------------------ Valid Inventorial Flag------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_071
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_071(p_inventorial_flag        VARCHAR2
                  ,p_attribute_category_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_attribute_category_code IN
       ('INTANGIBLE.CAPSOFTWARE', 'INTANGIBLE.CUSTOMER BASE',
        'INTANGIBLE.INTANGIBLE', 'INTANGIBLE.PATENTS',
        'INTANGIBLE.TRADEMARKS', 'LAND AND BUILDINGS.BUILDING',
        'LAND AND BUILDINGS.BUILDING IMPROVE', 'LAND AND BUILDINGS.LAND',
        'LEASEHOLD IMP.LEASEHOLD IMP')
    THEN
      IF p_inventorial_flag = 'NO'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_071;

  ------------------ Standardize Car Stock Subinventory Name------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_075
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Santanu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_075(p_car_stock_subinv_name VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF (length(p_car_stock_subinv_name) = 10)
       AND (substr(p_car_stock_subinv_name
                  ,1
                  ,1) = 'S')
       AND (regexp_like(substr(p_car_stock_subinv_name
                              ,2
                              ,3)
                       ,'^[[:digit:]]+$'))
       AND (substr(p_car_stock_subinv_name
                  ,5
                  ,3) = ' - ')
       AND (substr(p_car_stock_subinv_name
                  ,8
                  ,3) = 'CAR')
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_075;

  ------------------ Check valid account ------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_076
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   3/08/2016  Debarati banerjee                 Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_076(p_segment4 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_segment4 = '201110'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_076;

  ------------------ Check valid account ------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_077
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   3/08/2016  Debarati banerjee                 Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_077(p_segment4         VARCHAR2
                  ,p_pay_grp_lkp_code IN VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_pay_grp_lkp_code = 'RESELLER'
    THEN
      IF p_segment4 = '141054'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    ELSE
      IF p_segment4 = '141050'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
  
  END eqt_077;

  -- ------------------------------- Stock Locator is not null ----------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_155
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   3/08/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_155(p_locator_name VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_locator_name IS NOT NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_155;

  ------------------ Check valid org ------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_076
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_156(p_enabled_flag VARCHAR2
                  ,p_org_code     VARCHAR2) RETURN VARCHAR2 IS
  
    l_chk_dup_flag VARCHAR2(2);
  
  BEGIN
  
    IF p_enabled_flag = 'Y'
       AND p_org_code IN ('M01', 'T01', 'T02', 'T03', 'S01')
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_156;

  ------------------ Check valid subinventories  ------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_076
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_157(p_enabled_flag      VARCHAR2
                  ,p_subinventory_code VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_enabled_flag = 'Y'
       AND
       p_subinventory_code IN ('MRB', 'STORES', 'FG', 'HOLD', 'OSP', 'RD')
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  END eqt_157;

  ------------------ Check length of New Stock Locator Segment ---------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_161
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_161(p_locator_name VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF length(p_locator_name) <= 12 /*AND
                                                                                                                                                               instr((p_locator_name), '.', 1, 1) = 5 AND
                                                                                                                                                               instr((p_locator_name), '.', 1, 2) = 9 */
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_161;

  ------------------ Check valid Stock Locator  ---------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_161
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_166(p_locator_name VARCHAR2
                  ,p_locator_id   NUMBER) RETURN VARCHAR2 IS
  
    l_check_flag VARCHAR2(2);
  
  BEGIN
  
    SELECT 'Y'
    INTO l_check_flag
    FROM mtl_item_locations mil
    WHERE mil.attribute2 = p_locator_name
    AND mil.inventory_location_id = p_locator_id;
  
    IF l_check_flag = 'Y'
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_166;

  -------------- Check for null stock locator for locator controlled subinventory  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_158
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_158(p_enabled_flag      VARCHAR2
                  ,p_subinventory_code VARCHAR2
                  ,p_locator_name      VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF p_enabled_flag = 'Y'
       AND
       p_subinventory_code IN ('MRB', 'STORES', 'FG', 'HOLD', 'OSP', 'RD')
       AND length(p_locator_name) <> 0
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_158;

  -------------- Check for invalid format stock locator for locator controlled subinventory  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_159
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/05/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_159(p_enabled_flag      VARCHAR2
                  ,p_subinventory_code VARCHAR2
                  ,p_locator_name      VARCHAR2
                  ,p_row               VARCHAR2
                  ,p_rack              VARCHAR2
                  ,p_bin               VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_enabled_flag = 'Y'
       AND
       p_subinventory_code IN ('MRB', 'STORES', 'FG', 'HOLD', 'OSP', 'RD')
       AND length(p_locator_name) <= 12
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_159;

  ------------------------------- Check for Stock locator required  ---------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_170
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   10/08/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_170(p_stock_locator              VARCHAR2
                  ,p_serial_number_control_code NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF (p_stock_locator IS NULL AND p_serial_number_control_code <> 1)
    THEN
      --- dummy for item check
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_170;

  -------------- Check for Inventory On-Hand Exists without Item Master  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_171
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   10/08/2016  Paulami Ray                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_171(p_item_segment1 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_item_segment1 = 'Y'
    THEN
      --- dummy for item check
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    RETURN 'TRUE';
  
  END eqt_171;

  -------------- Check for valid agent  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_175
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   01/08/2016  Debarati Banerjee                 Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_175(p_agent_id NUMBER) RETURN VARCHAR2 IS
  
    l_check NUMBER;
  
  BEGIN
  
    SELECT COUNT(*)
    INTO l_check
    FROM po_agents_v      pa
        ,per_all_people_f ppf
    WHERE pa.agent_id = ppf.person_id
    AND ppf.employee_number IS NOT NULL
    AND SYSDATE BETWEEN nvl(ppf.effective_start_date
                          ,SYSDATE) AND
          nvl(ppf.effective_end_date
             ,SYSDATE)
    AND SYSDATE BETWEEN nvl(pa.start_date_active
                          ,SYSDATE) AND
          nvl(pa.end_date_active
             ,SYSDATE)
    AND pa.agent_id = p_agent_id;
  
    IF l_check > 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_175;

  -------------- Check for valid account  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_183
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   01/08/2016  Debarati Banerjee                 Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_183(p_segment5 VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_segment5 = '0000'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_183;

  -------------- 1 Primary Bill To  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_162
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_162(p_cust_acct_id NUMBER) RETURN BOOLEAN IS
    l_count NUMBER;
    l_org NUMBER := 0;
  BEGIN
     
   SELECT COUNT(DISTINCT xocs.org_id)
   INTO l_org
     FROM hz_cust_acct_sites_all xocs
    WHERE cust_account_id = p_cust_acct_id;
    
    SELECT COUNT(1)
    INTO l_count
    FROM hz_cust_site_uses_all
    WHERE cust_acct_site_id IN
          (SELECT cust_acct_site_id
           FROM hz_cust_acct_sites_all
           WHERE cust_account_id = p_cust_acct_id)
    AND site_use_code = 'BILL_TO'
    AND primary_flag = 'Y';
    
    IF l_org <= 1 AND l_count > 1
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  
  END eqt_162;

  -------------- 1 Primary Ship To  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_163
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_163(p_cust_acct_id NUMBER) RETURN BOOLEAN IS
    l_count NUMBER;
    l_org NUMBER := 0;
  BEGIN  
   SELECT COUNT(DISTINCT xocs.org_id)
     INTO l_org
     FROM hz_cust_acct_sites_all xocs
    WHERE cust_account_id = p_cust_acct_id;
    
    SELECT COUNT(1)
    INTO l_count
    FROM hz_cust_site_uses_all
    WHERE cust_acct_site_id IN
          (SELECT cust_acct_site_id
           FROM hz_cust_acct_sites_all
           WHERE cust_account_id = p_cust_acct_id)
    AND site_use_code = 'SHIP_TO'
    AND primary_flag = 'Y';
    
    IF l_org <= 1 AND l_count > 1
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  
  END eqt_163;

  -------------- No Primary Bill To  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_164
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_164(p_cust_acct_id NUMBER) RETURN BOOLEAN IS
    l_count NUMBER;    
  BEGIN
    SELECT COUNT(1)
    INTO l_count
    FROM hz_cust_site_uses_all
    WHERE cust_acct_site_id IN
          (SELECT cust_acct_site_id
           FROM hz_cust_acct_sites_all
           WHERE cust_account_id = p_cust_acct_id)
    AND site_use_code = 'BILL_TO'
    AND primary_flag = 'Y';
    IF l_count = 0
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_164;
  -------------- No Primary Ship To  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_165
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_165(p_cust_acct_id NUMBER) RETURN BOOLEAN IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(1)
    INTO l_count
    FROM hz_cust_site_uses_all
    WHERE cust_acct_site_id IN
          (SELECT cust_acct_site_id
           FROM hz_cust_acct_sites_all
           WHERE cust_account_id = p_cust_acct_id)
    AND site_use_code = 'SHIP_TO'
    AND primary_flag = 'Y';
    IF l_count = 0
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  
  END eqt_165;

  -------------- : Valid Customer GL REC Segment 4  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_188
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_188(p_organization_id NUMBER
                  ,p_gl_id_rec_seg4  VARCHAR2
                  ,p_gl_id_rec       VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER;
    l_name  VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT NAME
      INTO l_name
      FROM hr_organization_units
      WHERE organization_id = p_organization_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_name := NULL;
    END;
    IF l_name = 'Stratasys US OU'
    THEN
      IF p_gl_id_rec IS NULL
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    ELSE
      IF p_gl_id_rec_seg4 LIKE '11%'
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    END IF;
  
    RETURN TRUE;
  END eqt_188;

  -------------- : Valid Customer GL REV Segment 4  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_189
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_189(p_organization_id NUMBER
                  ,p_gl_id_rev_seg4  VARCHAR2
                  ,p_gl_id_rev       VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER;
    l_name  VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT NAME
      INTO l_name
      FROM hr_organization_units
      WHERE organization_id = p_organization_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_name := NULL;
    END;
  
    IF l_name = 'Stratasys US OU'
    THEN
      IF p_gl_id_rev IS NULL
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    ELSE
      IF p_gl_id_rev_seg4 LIKE '4011%'
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    END IF;
  
    RETURN TRUE;
  END eqt_189;

  -------------- : Valid Customer GL UNEARNED Segment 4  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_193
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_193(p_organization_id     NUMBER
                  ,p_gl_id_unearned_seg4 VARCHAR2
                  ,p_gl_id_unearned      VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER;
    l_name  VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT NAME
      INTO l_name
      FROM hr_organization_units
      WHERE organization_id = p_organization_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_name := NULL;
    END;
    IF l_name = 'Stratasys US OU'
    THEN
      IF p_gl_id_unearned IS NULL
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    ELSE
      IF p_gl_id_unearned_seg4 = '251300'
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    END IF;
    RETURN TRUE;
  END eqt_193;

  -------------- : Inco Terms - US Account Level  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_184
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_184(p_organization_id NUMBER
                  ,p_attribute18     VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER;
    l_name  VARCHAR2(250);
  BEGIN
  
    IF p_organization_id = 737
    THEN
      IF p_attribute18 IS NULL
      THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
    END IF;
    RETURN TRUE;
  END eqt_184;

  -------------- : Calculate US Customer Class Code  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_185
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_185(p_customer_type      IN VARCHAR2
                  ,p_sales_channel_code IN VARCHAR2 DEFAULT NULL
                  ,p_site_use_type      IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_customer_class_code VARCHAR2(250);
  
  BEGIN
    IF p_customer_type = 'I'
    THEN
      l_customer_class_code := 'INTERCOMPANY';
    ELSIF (p_customer_type = 'R' AND p_sales_channel_code = 'INDIRECT')
    THEN
      l_customer_class_code := 'INTERNATIONAL/LATAM';
    ELSIF (p_customer_type = 'R' AND p_sales_channel_code = 'DIRECT')
    THEN
      IF p_site_use_type = 'INSTALL AT'
      THEN
        l_customer_class_code := 'LEASE';
      ELSE
        l_customer_class_code := 'TRADE';
      END IF;
    END IF;
    RETURN l_customer_class_code;
  END eqt_185;

  -------------- : 1 Party 1 Account Rule  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_152
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   16/08/2016  Sanatnu Bhaumik               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_152(p_party_id IN NUMBER) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(cust_account_id)
    INTO l_count
    FROM hz_cust_accounts_all
    WHERE status = 'A'
    AND party_id = p_party_id;
    --GROUP BY party_id;
    IF l_count > 1
    THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END eqt_152;

  -------------- : Item type  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_198
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Paulami Ray               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_198(p_item_make_buy IN VARCHAR2
                  ,p_rollup_flag   IN NUMBER) RETURN BOOLEAN IS
  
  BEGIN
  
    IF p_item_make_buy = 'MAKE'
       AND p_rollup_flag = 1
    THEN
    
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END eqt_198;

  -------------- : Item type  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_199
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Paulami Ray               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_199(p_item_make_buy IN VARCHAR2
                  ,p_rollup_flag   IN NUMBER) RETURN BOOLEAN IS
  
  BEGIN
  
    IF p_item_make_buy = 'BUY'
       AND p_rollup_flag = 2
    THEN
    
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END eqt_199;

  -------------- : Item type  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_200
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Paulami Ray               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_200(p_item_make_buy IN VARCHAR2
                  ,p_cic_org_id    IN NUMBER
                  ,p_inv_item_id   IN NUMBER
                  ,p_source_type   IN VARCHAR2
                  ,p_cost_type_id  IN NUMBER) RETURN BOOLEAN IS
    l_check_flag VARCHAR2(10);
  BEGIN
  
    /* SELECT *
     into l_check_flag
     FROM CST_ITEM_COST_DETAILS_V
    WHERE 1 = 1
      AND organization_id = P_cic_org_idp
      AND INVENTORY_ITEM_ID = p_inv_item_id
      AND SOURCE_TYPE = p_source_type
         --AND COST_ELEMENT      = 'Material'
      AND COST_TYPE_ID = p_cost_type_id
    ORDER BY SOURCE_TYPE,
             COST_ELEMENT*/
  
    IF p_item_make_buy = 'MAKE'
       AND l_check_flag IS NULL
    THEN
    
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END eqt_200;

  -------------- : Item type  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_201
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Paulami Ray               Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_201(p_item_make_buy IN VARCHAR2
                  ,p_cic_org_id    IN NUMBER
                  ,p_inv_item_id   IN NUMBER
                  ,p_source_type   IN VARCHAR2
                  ,p_cost_type_id  IN NUMBER) RETURN BOOLEAN IS
    l_check_flag VARCHAR2(10);
  BEGIN
  
    /*  SELECT * into l_check_flag
    FROM CST_ITEM_COST_DETAILS_V
    WHERE 1               =1
    AND organization_id   = P_cic_org_idp
    AND INVENTORY_ITEM_ID = p_inv_item_id
    AND SOURCE_TYPE       = p_source_type
    --AND COST_ELEMENT      = 'Material'
    AND COST_TYPE_ID      = p_cost_type_id
    ORDER BY SOURCE_TYPE,
      COST_ELEMENT */
  
    IF p_item_make_buy = 'BUY'
       AND l_check_flag IS NOT NULL
    THEN
    
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END eqt_201;

  -------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate ACCOUNTING_RULE_ID
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  18/08/2016 V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_081(p_rule_id IN NUMBER) RETURN VARCHAR2 IS
    l_rule_name VARCHAR2(100);
  
  BEGIN
    SELECT NAME
    INTO l_rule_name
    FROM ra_rules rr
    WHERE rr.rule_id = p_rule_id;
  
    IF l_rule_name <> 'SSUS Std 12 Month Maint'
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  
  EXCEPTION
    WHEN no_data_found THEN
      l_rule_name := NULL;
      RETURN 'FALSE';
    WHEN OTHERS THEN
      l_rule_name := NULL;
      RETURN 'FALSE';
  END eqt_081;

  -------------- : Purchasing Item Flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_082
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_082(p_planning_make_buy_code IN NUMBER
                  ,p_purchasing_item_flag   IN VARCHAR2)
  
   RETURN VARCHAR2 IS
  BEGIN
  
    IF p_planning_make_buy_code = 2
    THEN
      IF p_purchasing_item_flag = 'Y'
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_082;

  -------------- : Shippable Item Flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_083
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_083(p_item_type           IN VARCHAR2
                  ,p_shippable_item_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type = 'XXSSYS_INTGBLE'
    THEN
      IF p_shippable_item_flag = 'N'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_083;

  -------------- : INVENTORY_ITEM_FLAG  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_084
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_084(p_item_type           IN VARCHAR2
                  ,p_inventory_item_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type IN ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC',
        'XXOBJ_GEN', 'XXOBJ_PH', 'XXOBJ_PP', 'XXOBJ_PUR_EXP',
        'XXOBJ_SER', 'XXOBJ_SER_EXP', 'XXOBJ_SER_LABOR',
        'XXSSUS_PHANTOM_SUB_ASSY', 'XXSSUS_PURCHASED_EXPENSE',
        'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE')
    THEN
      IF p_inventory_item_flag = 'N'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_084;

  -------------- : INVENTORY_ASSET_FLAG  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_085
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_085(p_inventory_asset_flag IN VARCHAR2
                  ,p_cost_enabled_flag    IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_cost_enabled_flag = 'Y'
       AND p_inventory_asset_flag = 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      IF p_cost_enabled_flag = 'N'
         AND p_inventory_asset_flag = 'N'
      THEN
        RETURN 'TRUE';
      END IF;
      RETURN 'FALSE';
    END IF;
    RETURN 'FALSE';
  END eqt_085;

  -------------- : Purchasing_enabled_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_086
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_086(p_planning_make_buy_code  IN NUMBER
                  ,p_purchasing_enabled_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_planning_make_buy_code = 2
    THEN
      IF p_purchasing_enabled_flag = 'Y'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_086;
  -------------- : Stock_enabled_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_087
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_087(p_item_type          IN VARCHAR2
                  ,p_stock_enabled_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type IN
       ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'POC', 'PTO', 'RC', 'XXOBJ_DOC',
        'XXOBJ_GEN', 'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER',
        'XXOBJ_SER_EXP', 'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
        'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE', 'XXSSYS_PTO_KIT',
        'XXSSYS_PTO_MODEL', 'XXSSYS_PTO_OCLASS')
    THEN
      IF p_stock_enabled_flag = 'N'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_087;
  -------------- : bom_enabled_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_088
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_088(p_item_type       IN VARCHAR2
                  ,p_bom_enabled_fla IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type IN
       ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
        'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
        'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
        'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE')
    THEN
      IF p_bom_enabled_fla = 'N'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_088;

  -------------- : collateral_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_090
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------    
  FUNCTION eqt_090(p_collateral_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF (p_collateral_flag = 'N' OR p_collateral_flag IS NULL)
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_090;

  -------------- : allow_item_desc_update_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_091
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------    
  FUNCTION eqt_091(p_allow_item_desc_update_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_allow_item_desc_update_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_091;

  -------------- : inspection_required_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_092
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------    
  FUNCTION eqt_092(p_inspection_required_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_inspection_required_flag IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_092;

  -------------- : receipt_required_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_093
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------    
  FUNCTION eqt_093(p_planning_make_buy_code IN NUMBER
                  ,p_receipt_required_flag  VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_planning_make_buy_code = 2
    THEN
      IF p_receipt_required_flag IS NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_093;

  -------------- : qty_rcv_tolerance  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_094
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_094(p_qty_rcv_tolerance IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_qty_rcv_tolerance IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_094;

  -------------- : list_price_per_unit  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_095
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_095(p_planning_make_buy_code IN NUMBER
                  ,p_list_price_per_unit    NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_planning_make_buy_code = '2'
    THEN
      IF (p_list_price_per_unit IS NULL OR p_list_price_per_unit = 0)
      THEN
        RETURN 'FALSE';
      ELSE
        RETURN 'TRUE';
      END IF;
    END IF;
  
    RETURN 'TRUE';
  END eqt_095;
  -------------- : assest_category_id  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_096
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_096(p_assest_category_id IN NUMBER
                  ,p_item_type          VARCHAR2) RETURN VARCHAR2 IS
    l_count VARCHAR2(10);
  BEGIN
    SELECT COUNT(*)
    INTO l_count
    FROM fa_categories_b
    WHERE category_id = p_assest_category_id
    AND segment1 = 'MACHINES'
    AND segment2 = 'INVENTORY';
  
    IF p_item_type IN ('XXOBJ_SER_FGS', 'XXOBJ_SYS_FG',
        'XXSSUS_FG_SERIALIZED', 'XXSSUS_RT_SERIAL')
    THEN
      IF l_count <> 0
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  EXCEPTION
    WHEN no_data_found THEN
      l_count := NULL;
      RETURN 'TRUE';
    WHEN OTHERS THEN
      l_count := NULL;
      RETURN 'TRUE';
  END eqt_096;

  -------------- : unit_of_issue   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_097
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_097(p_unit_of_issue IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_unit_of_issue IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_097;

  -------------- : serial_number_control_code   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_098
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_098(p_item_type                  IN VARCHAR2
                  ,p_serial_number_control_code IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type IN ('XXOBJ_SYS_FG', 'XXSSUS_FG_SERIALIZED')
       AND p_serial_number_control_code = '2'
    THEN
      RETURN 'TRUE';
    ELSE
      IF p_item_type IN
         ('XXOBJ_SER_FGS', 'XXOBJ_PUR_SA_SN', 'XXSSUS_RT_SERIAL')
         AND p_serial_number_control_code = '5'
      THEN
        RETURN 'TRUE';
      END IF;
      RETURN 'FALSE';
    END IF;
    RETURN 'FALSE';
  
  END eqt_098;
  -------------- : serial_number_control_code   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_099
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_099_1(p_source_subinventory IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_source_subinventory IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_099_1;

  -------------- : expense_account   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_100
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_100(p_item_type       IN VARCHAR2
                  ,p_expense_account IN VARCHAR2) RETURN VARCHAR2 IS
    l_count VARCHAR2(10);
  BEGIN
    SELECT COUNT(*)
    INTO l_count
    FROM gl_code_combinations_kfv gcck
        ,mtl_system_items_b       msi
    WHERE gcck.code_combination_id = msi.expense_account
    AND gcck.segment4 = '189184';
  
    IF p_item_type IN ('XXOBJ_SER_FGS', 'XXOBJ_SYS_FG',
        'XXSSUS_FG_SERIALIZED', 'XXSSUS_RT_SERIAL')
    THEN
      IF l_count <> 0
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_100;
  -------------- : shrinkage_rate   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_101
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------     
  FUNCTION eqt_101(p_shrinkage_rate IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_shrinkage_rate IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_101;

  -------------- : std_lot_size   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_102
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------     

  FUNCTION eqt_102(p_std_lot_size IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_std_lot_size IS NOT NULL
    THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;
  END eqt_102;

  -------------- : end_assembly_pegging_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_103
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------     

  FUNCTION eqt_103(p_item_type                 IN VARCHAR2
                  ,p_end_assembly_pegging_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_item_type IN
       ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
        'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
        'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
        'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE')
    THEN
      IF p_end_assembly_pegging_flag IS NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_103;

  -------------- : BOM_ITEM_TYPE  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_104
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_104(p_planning_make_buy_code IN NUMBER
                  ,p_bom_item_type          IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_planning_make_buy_code = 1
    THEN
      IF p_bom_item_type = 4
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_104;
  -------------- : pick_components_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_105
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_105(p_pick_components_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_pick_components_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_105;
  -------------- : replenish_to_order_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_106
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------  
  FUNCTION eqt_106(p_replenish_to_order_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_replenish_to_order_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_106;
  -------------- : atp_components_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_107
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_107(p_atp_components_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_atp_components_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_107;
  -------------- : cost_of_sales_account  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_108
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_108(p_cost_of_sales_account IN VARCHAR2) RETURN VARCHAR2 IS
    l_count VARCHAR2(10);
  BEGIN
    SELECT COUNT(*)
    INTO l_count
    FROM gl_code_combinations_kfv gcck
        ,mtl_system_items_b       msi
    WHERE gcck.code_combination_id = msi.cost_of_sales_account
    AND gcck.segment4 = '501050';
  
    IF l_count <> 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_108;

  ------------- :sales_account  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_109
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_109(p_sales_account IN VARCHAR2) RETURN VARCHAR2 IS
    l_count VARCHAR2(10);
  BEGIN
    SELECT COUNT(*)
    INTO l_count
    FROM gl_code_combinations_kfv gcck
        ,mtl_system_items_b       msi
    WHERE gcck.code_combination_id = msi.sales_account
    AND gcck.segment4 = '401100';
  
    IF l_count <> 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_109;
  ------------- :default_rollup_flag  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_110
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_110(p_default_rollup_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_default_rollup_flag IS NOT NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_110;

  ------------- :planning_make_buy_code  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_111
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_111(p_planning_make_buy_code IN NUMBER
                  ,p_item_type              IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_planning_make_buy_code = 2
    THEN
    
      IF p_item_type IN
         ('XXOBJ_ACC_FG', 'XXOBJ_ACC_FGS', 'XXOBJ_CHM_PUR', 'XXOBJ_KIT_BUY',
          'XXOBJ_NON_OBJET', 'XXOBJ_NO_CHM_PUR', 'XXOBJ_PUR_IFK',
          'XXOBJ_PUR_NJRC', 'XXOBJ_PUR_SA', 'XXOBJ_PUR_SA_SN',
          'XXOBJ_PUR_STD', 'XXOBJ_SER_FG_B', 'XXSSUS_BULK_SUPPLY',
          'XXSSUS_RT_SERIAL', 'XXSSUS_STD_PURCHASED_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_111;

  ------------ :reservable_type  --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_112
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_112(p_reservable_type IN VARCHAR2
                  ,p_item_type       IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_reservable_type = 'N'
    THEN
    
      IF p_item_type IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    
    END IF;
    RETURN 'TRUE';
  END eqt_112;

  ------------ :vendor_warranty_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_113
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_113(p_vendor_warranty_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_vendor_warranty_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_113;
  ------------ :serviceable_product_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_114
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_114(p_serviceable_product_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_serviceable_product_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_114;
  ------------ :prorate_service_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_115
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_115(p_prorate_service_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_prorate_service_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_115;
  ------------ :invoiceable_item_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_116
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_116(p_invoiceable_item_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_invoiceable_item_flag = 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_116;
  ------------ :invoice_enabled_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_117
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_117(p_invoice_enabled_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_invoice_enabled_flag = 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_117;
  ----------- :costing_enabled_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_118
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_118(p_costing_enabled_flag IN VARCHAR2
                  ,p_item_type            IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_costing_enabled_flag = 'N'
    THEN
    
      IF p_item_type IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_118;

  ----------- :cycle_count_enabled_flag   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_119
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_119(p_cycle_count_enabled_flag IN VARCHAR2
                  ,p_item_type                IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_cycle_count_enabled_flag = 'N'
    THEN
    
      IF p_item_type IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  
  END eqt_119;
  ----------- :ato_forecast_control   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_120
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_120(p_ato_forecast_control IN NUMBER
                  ,p_item_type            IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_ato_forecast_control IS NULL
    THEN
    
      IF p_item_type IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_120;

  ---------- :effectivity_control   --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_121
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_121(p_effectivity_control IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_effectivity_control = 1
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_121;

  --------- :event_flag    --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_122
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_122(p_event_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_event_flag = 'N'
       OR p_event_flag IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_122;

  --------- :electronic_flag    --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_123
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_123(p_electronic_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_electronic_flag = 'N'
       OR p_electronic_flag IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_123;

  --------- :downloadable_flag    --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_124
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_124(p_downloadable_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_downloadable_flag = 'N'
       OR p_downloadable_flag IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_124;

  --------- :comms_nl_trackable_flag     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_125
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_125(p_comms_nl_trackable_flag IN VARCHAR2
                  ,p_item_type               IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_comms_nl_trackable_flag = 'Y'
    THEN
      IF p_item_type IN ('XXOBJ_PUR_SA_SN', 'XXOBJ_SER_FGS', 'XXOBJ_SYS_FG',
          'XXSSUS_FG_SERIALIZED', 'XXSSUS_RT_NON_SERIAL')
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  
  END eqt_125;

  --------- :web_status     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_126
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_126(p_web_status IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_web_status = 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_126;

  --------- :dimension_uom_code      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_127
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_127(p_dimension_uom_code IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_dimension_uom_code IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_127;

  --------- :unit_length      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_128
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_128(p_unit_length IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_unit_length IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_128;

  --------- :unit_width       --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_129
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_129(p_unit_width IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_unit_width IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_129;

  --------- :unit_height       --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_128
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_130(p_unit_height IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_unit_height IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_130;

  --------- :dual_uom_control       --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_131
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_131(p_dual_uom_control IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_dual_uom_control = 1
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_131;

  -------- :dual_uom_deviation_high       --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_132
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_132(p_dual_uom_deviation_high IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_dual_uom_deviation_high = 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_132;

  -------- :dual_uom_deviation_low       --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_133
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_133(p_dual_uom_deviation_low IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_dual_uom_deviation_low = 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_133;
  ------- :default_so_source_type        --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_134
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_134(p_default_so_source_type IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_default_so_source_type = 'INTERNAL'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_134;

  ------- :hazardous_material_flag        --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_135
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_135(p_hazardous_material_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_hazardous_material_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_135;

  ------- :recipe_enabled_flag        --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_136
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_136(p_recipe_enabled_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_recipe_enabled_flag = 'N'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_136;

  ------- :Calculation of the receiving_routing_id        --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_137
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_137(p_inventory_item_id    IN NUMBER
                  ,p_organization_code    IN VARCHAR2
                  ,p_s3_organization_code IN VARCHAR2) RETURN NUMBER IS
    s3_receiving_routing_id NUMBER;
  
  BEGIN
    IF p_s3_organization_code = 'T03'
    THEN
    
      /* Transformation rule for Item field, receiving_routing_id. It needs to be inferred from the default receiving subinventory in legacy.*/
      SELECT /* Determine S3 value for Receipt Routing (receiving_routing_id) in T03 org. 1: Standard 2: Inspection 3: Direct All other orgs (M01, T01, T02, etc. should be 3 - Direct) */
       (CASE
         WHEN misd.subinventory_code LIKE ('RECINSP%') THEN
          '2' --2 - Inspection
         ELSE
          '3' --3 - Direct
       END) s3_t03_receiving_routing_id
      INTO s3_receiving_routing_id
      FROM mtl_system_items msi
      INNER JOIN mtl_parameters mp ON (mp.organization_id =
                                      msi.organization_id)
      
      LEFT JOIN mtl_item_sub_defaults misd ON (msi.inventory_item_id =
                                              misd.inventory_item_id AND
                                              msi.organization_id =
                                              misd.organization_id)
      WHERE mp.organization_code = p_organization_code
      AND msi.inventory_item_id = p_inventory_item_id;
    
      RETURN s3_receiving_routing_id;
    ELSE
      SELECT /* All other orgs (M01, T01, T02, etc. should be 3 - Direct) */
       3 AS s3_receiving_routing_id
      INTO s3_receiving_routing_id
      FROM mtl_system_items msi
      INNER JOIN mtl_parameters mp ON (mp.organization_id =
                                      msi.organization_id)
      
      LEFT JOIN mtl_item_sub_defaults misd ON (msi.inventory_item_id =
                                              misd.inventory_item_id AND
                                              msi.organization_id =
                                              misd.organization_id)
      WHERE mp.organization_code = p_organization_code
      AND msi.inventory_item_id = p_inventory_item_id;
    
      RETURN s3_receiving_routing_id;
    END IF;
    RETURN s3_receiving_routing_id;
  EXCEPTION
    WHEN no_data_found THEN
      s3_receiving_routing_id := NULL;
      RETURN s3_receiving_routing_id;
    WHEN OTHERS THEN
      s3_receiving_routing_id := NULL;
      RETURN s3_receiving_routing_id;
    
  END eqt_137;

  ------ :ato_forecast_control     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_138
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_138(p_ato_forecast_control IN VARCHAR2
                  ,p_item_type            IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_ato_forecast_control = '2'
    THEN
      IF p_item_type NOT IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  
  END eqt_138;

  ----- :cycle_count_enabled_flag     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_139
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_139(p_cycle_count_enabled_flag IN VARCHAR2
                  ,p_item_type                IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_cycle_count_enabled_flag = 'Y'
    THEN
      IF p_item_type NOT IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_139;

  ----- :reservable_type     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_140
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_140(p_reservable_type IN VARCHAR2
                  ,p_item_type       IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_reservable_type = 'Y'
    THEN
      IF p_item_type NOT IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'RC', 'XXOBJ_DOC', 'XXOBJ_GEN',
          'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER', 'XXOBJ_SER_EXP',
          'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE')
      THEN
      
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_140;

  ----- :mrp_planning_code     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_141
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_141(p_mrp_planning_code IN VARCHAR2
                  ,p_item_type_code    IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_mrp_planning_code = '6'
    THEN
      IF p_item_type_code IN
         ('ARP', 'COUPON', 'DISCOUNT', 'FRT', 'POC', 'PTO', 'RC',
          'XXOBJ_DOC', 'XXOBJ_GEN', 'XXOBJ_PP', 'XXOBJ_PUR_EXP', 'XXOBJ_SER',
          'XXOBJ_SER_EXP', 'XXOBJ_SER_LABOR', 'XXSSUS_PURCHASED_EXPENSE',
          'XXSSUS_REFERENCE_ITEM', 'XXSSYS_INTGBLE', 'XXSSYS_PTO_KIT',
          'XXSSYS_PTO_MODEL', 'XXSSYS_PTO_OCLASS')
      THEN
        --  equal "Not planned", else equal "MRP and MPP planning"        
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'TRUE';
  END eqt_141;

  ----- :receipt_required_flag     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_142
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_142(p_receipt_required_flag  IN VARCHAR2
                  ,p_planning_make_buy_code IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_planning_make_buy_code = 1
    THEN
      IF p_receipt_required_flag = 'Y'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
    RETURN 'FALSE';
  END eqt_142;

  ----- :revision_qty_control_code     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_143
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_143(p_revision_qty_control_code IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF p_revision_qty_control_code = 1
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_143;

  ---- :ship_model_complete_flag     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_144
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION eqt_144(p_ship_model_complete_flag IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_ship_model_complete_flag = 'N'
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_144;

  --- :source_subinventory     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_145
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_145(p_source_subinventory IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_source_subinventory IS NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_145;

  --- :source_type      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_146
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION eqt_146(p_source_type IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_source_type IS NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_146;
  --- :restrict_subinventories_code      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_147
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_147(p_restrict_subinventories_code IN VARCHAR2)
    RETURN VARCHAR2 IS
  BEGIN
    IF p_restrict_subinventories_code IS NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_147;

  --- :contract_item_type_code      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_148
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 

  FUNCTION eqt_148(p_contract_item_type_code IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_contract_item_type_code IS NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_148;
  --- :contract_item_type_code      --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_149
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  V.V.Sateesh               Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_149(p_serv_req_enabled_code IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_serv_req_enabled_code IS NULL
    THEN
    
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END eqt_149;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_190
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Debarati banerjee              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_190(p_entity IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_entity IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_190;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_191
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Debarati banerjee              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_191(p_ou            IN VARCHAR2
                  ,p_entity        IN VARCHAR2
                  ,p_gl_id_freight IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_ou = 'Stratasys US OU'
    THEN
      IF p_gl_id_freight IS NULL
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    ELSE
      IF p_entity = '401910'
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    END IF;
  END eqt_191;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_192
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  Debarati banerjee              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_192(p_entity IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    IF p_entity IS NULL
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_192;

  --- :REC Distribution Missing     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_202
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_202(p_customer_trx_id IN VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
  
    BEGIN
      SELECT COUNT(1)
      INTO l_count
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class = 'REC';
    
    EXCEPTION
      WHEN OTHERS THEN
        l_count := '0';
    END;
  
    IF l_count = 0
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_202;

  --- :More than one REC distribution exists for invoice     --------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_203
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_203(p_customer_trx_id IN VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
  
    BEGIN
      SELECT COUNT(1)
      INTO l_count
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class = 'REC';
    EXCEPTION
      WHEN OTHERS THEN
        l_count := '0';
      
    END;
  
    IF l_count > 1
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_203;

  --- :REV Distribution Missing for Invoice Line--------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_204
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_204(p_customer_trx_line_id IN VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
  
    BEGIN
      SELECT COUNT(1)
      INTO l_count
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_line_id = p_customer_trx_line_id
      AND account_class = 'REV';
    
    EXCEPTION
      WHEN OTHERS THEN
        l_count := '0';
      
    END;
  
    IF l_count = 0
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_204;

  --- More than one REV distribution exists for Invoice Line-------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_205
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_205(p_customer_trx_line_id IN VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  BEGIN
  
    BEGIN
      SELECT COUNT(1)
      INTO l_count
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_line_id = p_customer_trx_line_id
      AND account_class = 'REV';
    
    EXCEPTION
      WHEN OTHERS THEN
        l_count := 0;
      
    END;
  
    IF l_count > 1
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_205;

  --- The sum of the 'REV' distributions should equal the 'REC' distribution-------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_206
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_206(p_customer_trx_id IN VARCHAR2) RETURN BOOLEAN IS
    l_rec_amount NUMBER;
    l_rev_amount NUMBER;
  BEGIN
  
    BEGIN
      SELECT amount
      INTO l_rec_amount
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class = 'REC';
    EXCEPTION
      WHEN OTHERS THEN
        l_rec_amount := NULL;
      
    END;
  
    BEGIN
      SELECT SUM(amount)
      INTO l_rev_amount
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class = 'REV';
    
    EXCEPTION
      WHEN OTHERS THEN
        l_rec_amount := NULL;
      
    END;
  
    IF l_rev_amount != l_rev_amount
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_206;

  --- For each invoice header, the receivable (REC) distribution should equal the remaining amount due on the invoice-------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate EQT_207
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  -- 1.0   18/08/2016  TCS              Initial build
  ----------------------------------------------------------------------------------------------- 
  FUNCTION eqt_207(p_customer_trx_id IN VARCHAR2) RETURN BOOLEAN IS
    l_rec_amount NUMBER;
    l_rev_amount NUMBER;
  BEGIN
  
    BEGIN
      SELECT amount
      INTO l_rec_amount
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class = 'REC';
    
    EXCEPTION
      WHEN OTHERS THEN
        l_rec_amount := NULL;
      
    END;
  
    BEGIN
      SELECT SUM(amount)
      INTO l_rev_amount
      FROM xxobjt.xxs3_rtr_open_trx_distribution
      WHERE legacy_customer_trx_id = p_customer_trx_id
      AND account_class != 'REC';
    EXCEPTION
      WHEN OTHERS THEN
        l_rec_amount := NULL;
      
    END;
  
    IF l_rev_amount != l_rev_amount
    THEN
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END eqt_207;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Destination Organization 
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Sateesh                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_176_1(p_destination_organization VARCHAR2
                    ,p_ship_to_org_code_ship    VARCHAR2
                    ,p_ship_to_location_ship    VARCHAR2) RETURN VARCHAR2 IS
  
    l_destination_code VARCHAR2(100);
    l_count            NUMBER;
    l_check            NUMBER;
  
  BEGIN
  
    SELECT NAME
    INTO l_destination_code
    FROM hr_organization_units_v      hou
        ,org_organization_definitions ood
    WHERE hou.organization_id = ood.organization_id
    AND ood.organization_code = p_destination_organization;
  
    SELECT COUNT(*)
    INTO l_count
    FROM hr_organization_units_v hou
    WHERE NAME = l_destination_code
    AND location_code = p_ship_to_location_ship;
  
    SELECT COUNT(*)
    INTO l_check
    FROM hr_organization_information_v hoi
        ,hr_organization_units_v       hou
    WHERE org_information1_meaning = 'Inventory Organization'
    AND hoi.organization_id = hou.organization_id
    AND hou.location_code = p_ship_to_location_ship;
  
    IF p_destination_organization = p_ship_to_org_code_ship
    THEN
      IF l_count > 0
         OR l_check = 0
      THEN
        RETURN 'TRUE';
      ELSE
        RETURN 'FALSE';
      END IF;
    ELSE
      RETURN 'FALSE';
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
    WHEN OTHERS THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
  END eqt_176_1;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Destination Organization 
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Sateesh                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_218(p_destination_organization VARCHAR2
                  ,p_ship_to_org_code_ship    VARCHAR2
                  ,p_ship_to_location_ship    VARCHAR2) RETURN VARCHAR2 IS
  
    l_destination_code VARCHAR2(100);
    l_count            NUMBER;
    l_check            NUMBER;
  
  BEGIN
  
    SELECT NAME
    INTO l_destination_code
    FROM hr_organization_units_v      hou
        ,org_organization_definitions ood
    WHERE hou.organization_id = ood.organization_id
    AND ood.organization_code = p_destination_organization;
  
  
    IF p_destination_organization = p_ship_to_org_code_ship
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
    WHEN OTHERS THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
  END eqt_218;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate Destination Organization 
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Sateesh                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_219(p_destination_organization VARCHAR2
                  ,p_ship_to_org_code_ship    VARCHAR2
                  ,p_ship_to_location_ship    VARCHAR2) RETURN VARCHAR2 IS
  
    l_destination_code VARCHAR2(100);
    l_count            NUMBER;
    l_check            NUMBER;
  
  BEGIN
  
    SELECT NAME
    INTO l_destination_code
    FROM hr_organization_units_v      hou
        ,org_organization_definitions ood
    WHERE hou.organization_id = ood.organization_id
    AND ood.organization_code = p_destination_organization;
  
    SELECT COUNT(*)
    INTO l_count
    FROM hr_organization_units_v hou
    WHERE NAME = l_destination_code
    AND location_code = p_ship_to_location_ship;
  
    SELECT COUNT(*)
    INTO l_check
    FROM hr_organization_information_v hoi
        ,hr_organization_units_v       hou
    WHERE org_information1_meaning = 'Inventory Organization'
    AND hoi.organization_id = hou.organization_id
    AND hou.location_code = p_ship_to_location_ship;
  
    IF l_count > 0
       OR l_check = 0
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  EXCEPTION
    WHEN no_data_found THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
    WHEN OTHERS THEN
      l_destination_code := NULL;
      l_count            := NULL;
      l_check            := NULL;
      RETURN 'FALSE';
  END eqt_219;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate that Partially billed PO is not paid in full
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/12/2016  Sumana                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_220(p_payment_status_flag VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_payment_status_flag != 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_220;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate that fully billed PO is not aprtiallt paid
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/12/2016  Sumana                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_221(p_payment_status_flag VARCHAR2) RETURN VARCHAR2 IS
  
  
  BEGIN
  
    IF p_payment_status_flag != 'P'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_221;




  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate that fully billed PO is not aprtiallt paid
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/12/2016  Sumana                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_222(p_payment_status_flag VARCHAR2) RETURN VARCHAR2 IS
  
  
  BEGIN
  
    IF p_payment_status_flag != 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_222;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate that fully billed PO is not aprtiallt paid
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/12/2016  Sumana                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_223(p_payment_status_flag VARCHAR2) RETURN VARCHAR2 IS
  
  
  BEGIN
  
    IF p_payment_status_flag != 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_223;



  -- --------------------------------------------------------------------------------------------
  -- Purpose: EQT RULE to validate that fully billed PO is not aprtiallt paid
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/12/2016  Sumana                  Initial build
  -----------------------------------------------------------------------------------------------


  FUNCTION eqt_224(p_payment_status_flag VARCHAR2) RETURN VARCHAR2 IS
  
  
  BEGIN
  
    IF p_payment_status_flag != 'Y'
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  
  END eqt_224;





END xxs3_dq_util_pkg;
/
