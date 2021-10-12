CREATE OR REPLACE PACKAGE BODY xxs3_data_transform_util_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: Package Body for legacy to S3 data transformation
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name              Description
-- 1.0  16/05/2016  TCS               Initial build
-----------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Get the Region Name against Company
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION get_company_region(p_legacy_company_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_region VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT region
        INTO l_region
        FROM xxobjt.xxs3_companies_transform
       WHERE legacy_company = p_legacy_company_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_region := NULL;
    END;
    IF l_region IS NULL OR l_region LIKE '%not applicable%' THEN
      l_region := 'Invalid CoA Region';
    END IF;
    RETURN l_region;
  END get_company_region;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Account transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_account_transform(p_legacy_account_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_account_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_account
        INTO l_transform_account_val
        FROM xxs3_account_transform
       WHERE legacy_account = p_legacy_account_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_account_val := NULL;
    END;
    IF ((l_transform_account_val IS NULL) OR
       (NOT regexp_like(l_transform_account_val, '^[[:digit:]]+$') AND
       l_transform_account_val NOT LIKE '%N/A%')) THEN
      l_transform_account_val := 'Invalid CoA Account';
    ELSIF l_transform_account_val LIKE '%N/A%' THEN
      l_transform_account_val := 'Account Removed in S3';
    END IF;
    RETURN l_transform_account_val;
  END coa_account_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Company transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -- 1.1  20/06/2016  TCS                           Introduced additional mapping attribute
  --                                                (SEGMENT10) for company code 40, 41
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_company_transform(p_legacy_company_val  IN VARCHAR2,
                                 p_legacy_division_val IN VARCHAR2,
                                 p_region_val          IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_company_val VARCHAR2(250);
    l_legacy_division_val   VARCHAR2(250);
  BEGIN
    IF p_legacy_company_val IN (40, 41) THEN
      IF p_legacy_division_val NOT IN ('201', '202', '203') THEN
        l_legacy_division_val := 'Not in (201,202,203)';
      ELSE
        l_legacy_division_val := p_legacy_division_val;
      END IF;
      BEGIN
        SELECT s3_company
          INTO l_transform_company_val
          FROM xxobjt.xxs3_companies_transform
         WHERE legacy_company = p_legacy_company_val
           AND decode(segment10,
                      'not applicable',
                      l_legacy_division_val,
                      segment10) = l_legacy_division_val
           AND region = p_region_val;
      EXCEPTION
        WHEN OTHERS THEN
          l_transform_company_val := NULL;
      END;
    ELSE
      BEGIN
        SELECT s3_company
          INTO l_transform_company_val
          FROM xxobjt.xxs3_companies_transform
         WHERE legacy_company = p_legacy_company_val;
      EXCEPTION
        WHEN OTHERS THEN
          l_transform_company_val := NULL;
      END;
    END IF;
    IF ((l_transform_company_val IS NULL) OR
       (NOT regexp_like(l_transform_company_val, '^[[:digit:]]+$') AND
       l_transform_company_val NOT LIKE '%N/A%')) THEN
      l_transform_company_val := 'Invalid CoA Company';
    ELSIF l_transform_company_val LIKE '%N/A%' THEN
      l_transform_company_val := 'Invalid Company Code';
    END IF;
    RETURN l_transform_company_val;
  END coa_company_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Sales and COGS Account for other than
  --          Company 34, 37, 44, 46.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_sc_transform(p_legacy_location_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_sc_transform
       WHERE legacy_location = p_legacy_location_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$'))) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_sc_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Sales and COGS Account for
  --          Company 34, 37, 44, 46.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_sc_spcl_transform(p_legacy_company_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_sc_transform
       WHERE legacy_company = p_legacy_company_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$'))) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_sc_spcl_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Expense Account of APJ,EMEA,LATAM Region
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_exp_others_transform(p_legacy_location_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_expense_transform
       WHERE legacy_location = p_legacy_location_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_exp_others_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Expense Account of NA Region for other than
  --          Company 34, 37, 44, 46.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_exp_na_transform(p_legacy_company_val    IN VARCHAR2,
                                   p_legacy_department_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_expense_transform
       WHERE legacy_company = p_legacy_company_val
         AND legacy_department = p_legacy_department_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_exp_na_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Expense Account of NA Region for
  --          Company 34, 37, 44, 46.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_exp_na_spcl_transform(p_legacy_company_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_expense_transform
       WHERE legacy_company = p_legacy_company_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_exp_na_spcl_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for US Open GL Balanaces
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_open_gl_transform(p_legacy_acct_val    IN VARCHAR2,
                                    p_legacy_intercompany_val IN VARCHAR2,
                                    p_legacy_company_value   IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);

  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_us_gl_bal_transform
       WHERE legacy_acct_from <= to_number(p_legacy_acct_val)
         AND legacy_acct_to >= to_number(p_legacy_acct_val)
         AND legacy_intercomp_from <= to_number(p_legacy_intercompany_val)
         AND legacy_intercomp_to >= to_number(p_legacy_intercompany_val)
         AND company_code = p_legacy_company_value;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_open_gl_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Open PO of NA Region for other than
  --          Company 34, 37, 44, 46.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_open_po_na_transform(p_legacy_company_val    IN VARCHAR2,
                                   p_legacy_department_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_us_po_transform
       WHERE legacy_company = p_legacy_company_val
         AND legacy_department = p_legacy_department_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_open_po_na_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Open PO of NA Region for
  --          Company 34, 37, 44, 46,33
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_po_na_spcl_transform(p_legacy_company_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_us_po_transform
       WHERE legacy_company = p_legacy_company_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    ELSIF l_transform_bu_val LIKE '%Invalid%' THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_po_na_spcl_transform;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: Business Unit transformation for Expense Account of APJ,EMEA,LATAM Region
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_bu_po_others_transform(p_legacy_location_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_bu_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_business_unit
        INTO l_transform_bu_val
        FROM xxobjt.xxs3_bu_us_po_transform
       WHERE legacy_location = p_legacy_location_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_bu_val := NULL;
    END;
    IF ((l_transform_bu_val IS NULL) OR
       (NOT regexp_like(l_transform_bu_val, '^[[:digit:]]+$') AND
       l_transform_bu_val NOT LIKE '%N/A%')) THEN
      l_transform_bu_val := 'Invalid CoA Business Unit';
    ELSIF l_transform_bu_val LIKE '%N/A%' THEN
      l_transform_bu_val := 'Business Unit Removed in S3';
    END IF;
    RETURN l_transform_bu_val;
  END coa_bu_po_others_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Department transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_department_transform(p_legacy_department_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_department_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT department
        INTO l_transform_department_val
        FROM xxobjt.xxs3_department_transform
       WHERE legacy_department = p_legacy_department_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_department_val := NULL;
    END;
    IF ((l_transform_department_val IS NULL) OR
       (NOT regexp_like(l_transform_department_val, '^[[:digit:]]+$')) AND
       l_transform_department_val NOT LIKE '%N/A%') THEN
      l_transform_department_val := 'Invalid CoA Department';
    ELSIF l_transform_department_val LIKE '%N/A%' THEN
      l_transform_department_val := 'Department Removed in S3';
    END IF;
    RETURN l_transform_department_val;
  END coa_department_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Product Line transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_prod_line_sc_transform(p_legacy_item_number IN VARCHAR2)
    RETURN VARCHAR IS
    l_transform_product_line_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_product_line
        INTO l_transform_product_line_val
        FROM xxobjt.xxs3_productlines_transform
       WHERE legacy_item_number = p_legacy_item_number;

    EXCEPTION
      WHEN OTHERS THEN
        l_transform_product_line_val := NULL;
    END;
    IF ((l_transform_product_line_val IS NULL) OR
       (NOT regexp_like(l_transform_product_line_val, '^[[:digit:]]+$'))) THEN
      l_transform_product_line_val := 'Invalid CoA Product Line';
    END IF;
    RETURN l_transform_product_line_val;
  END coa_prod_line_sc_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Location transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  FUNCTION coa_location_transform(p_legacy_location_val IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_location_val VARCHAR2(250);
  BEGIN
    BEGIN
      SELECT s3_location
        INTO l_transform_location_val
        FROM xxobjt.xxs3_location_transform
       WHERE legacy_location = p_legacy_location_val;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_location_val := NULL;
    END;
    IF ((l_transform_location_val IS NULL) OR
       (NOT regexp_like(l_transform_location_val, '^[[:digit:]]+$'))) THEN
      l_transform_location_val := 'Invalid CoA Location';
    END IF;
    RETURN l_transform_location_val;
  END coa_location_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Intercompany transformation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION coa_intercompany_transform(p_legacy_intercompany_val IN VARCHAR2,
                                      p_legacy_division_val     IN VARCHAR2,
                                      p_region_val              IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_transform_intercomp_val VARCHAR2(250);
    l_legacy_division_val     VARCHAR2(25);
  BEGIN
    IF p_legacy_intercompany_val IN (40, 41) THEN
      IF p_legacy_division_val NOT IN ('201', '202', '203') THEN
        l_legacy_division_val := 'Not in (201,202,203)';
      ELSE
        l_legacy_division_val := p_legacy_division_val;
      END IF;
      BEGIN
        SELECT s3_intercompany
          INTO l_transform_intercomp_val
          FROM xxobjt.xxs3_intercompany_transform
         WHERE legacy_intercompany = p_legacy_intercompany_val
           AND decode(segment10,
                      'not applicable',
                      l_legacy_division_val,
                      segment10) = l_legacy_division_val
           AND region = p_region_val;

      EXCEPTION
        WHEN OTHERS THEN
          l_transform_intercomp_val := NULL;
      END;
    ELSE
      BEGIN
        SELECT s3_intercompany
          INTO l_transform_intercomp_val
          FROM xxobjt.xxs3_intercompany_transform
         WHERE legacy_intercompany = p_legacy_intercompany_val;
      EXCEPTION
        WHEN OTHERS THEN
          l_transform_intercomp_val := NULL;
      END;
    END IF;
    IF ((l_transform_intercomp_val IS NULL) OR
       (NOT regexp_like(l_transform_intercomp_val, '^[[:digit:]]+$') AND
       l_transform_intercomp_val NOT LIKE '%N/A%')) THEN
      l_transform_intercomp_val := 'Invalid CoA Intercompany';
    ELSIF l_transform_intercomp_val LIKE '%N/A%' THEN
      l_transform_intercomp_val := 'Invalid Company Code';
    END IF;
    RETURN l_transform_intercomp_val;
  END coa_intercompany_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure. This returns the concatenated GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_transform(p_field_name              IN VARCHAR2,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2, -- Output error code
                          p_err_msg                 OUT VARCHAR2) --Output Message VARCHAR2(4000)
   AS

    l_company_val       VARCHAR2(250);
    l_business_unit_val VARCHAR2(250);
    l_department_val    VARCHAR2(250);
    l_account_val       VARCHAR2(250);
    l_product_line_val  VARCHAR2(250);
    l_location_val      VARCHAR2(250);
    l_future_val        VARCHAR2(250);
    l_intercompany_val  VARCHAR2(250);
    l_acc_first_digit   VARCHAR2(1);
    l_account_type      VARCHAR2(100);
    l_region_name       VARCHAR2(100);

  BEGIN
    IF p_legacy_account_val IS NOT NULL THEN
      SELECT substr(p_legacy_account_val, 1, 1)
        INTO l_acc_first_digit
        FROM dual;
      IF l_acc_first_digit = '4' THEN
        l_account_type := 'Sales Account';
      ELSIF l_acc_first_digit = '5' THEN
        l_account_type := 'COGS';
      ELSIF l_acc_first_digit = '6' THEN
        l_account_type := 'Expense Account';
      ELSIF l_acc_first_digit IN ('1', '2', '3') THEN
        l_account_type := 'Balance Sheet Account';
      ELSIF l_acc_first_digit = '7' THEN
        l_account_type := 'Other Income Expense';
      ELSIF l_acc_first_digit = '8' THEN
        l_account_type := 'Tax Related Accounts';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);
      --Future Transform
      l_future_val := '000';

      --Account Transform
      l_account_val := coa_account_transform(p_legacy_account_val);
      IF l_account_val IN ('Invalid CoA Account', 'Account Removed in S3') THEN
        p_err_msg := p_err_msg || l_account_val || ' ,';
      END IF;

      --Company Transform
      IF p_legacy_company_val IS NOT NULL THEN
        l_company_val := coa_company_transform(p_legacy_company_val,
                                               p_legacy_division_val,
                                               l_region_name);
        IF l_company_val LIKE 'Invalid%Company%' THEN
          p_err_msg := p_err_msg || l_company_val || ' ,';
        END IF;
      ELSE
        p_err_msg := 'Invalid CoA Company';
      END IF;
      --Business Unit Transform

      IF l_region_name = 'US' THEN
        l_region_name := 'NA';
      END IF;
      IF l_region_name = 'Invalid CoA Region' THEN
        p_err_msg := p_err_msg || l_region_name || ',';
      END IF;
      IF l_account_type IN ('Sales Account', 'COGS') THEN
        IF l_region_name IN ('APJ', 'EMEA', 'LATAM', 'NA') THEN
          IF p_legacy_company_val NOT IN ('34', '37', '44', '46') THEN
            l_business_unit_val := coa_bu_sc_transform(p_legacy_location_val);
          ELSE
            l_business_unit_val := coa_bu_sc_spcl_transform(p_legacy_company_val);
          END IF;
          IF l_business_unit_val = 'Invalid CoA Business Unit' THEN
            p_err_msg := p_err_msg || l_business_unit_val || ' ,';
          END IF;
        ELSE
          p_err_msg := p_err_msg || l_region_name || ',';
        END IF;
      ELSIF l_account_type = 'Expense Account' THEN
        IF l_region_name = 'NA' THEN
          IF p_legacy_company_val NOT IN ('34', '37', '44', '46') THEN
            l_business_unit_val := coa_bu_exp_na_transform(p_legacy_company_val,
                                                           p_legacy_department_val);
          ELSE
            l_business_unit_val := coa_bu_exp_na_spcl_transform(p_legacy_company_val);
          END IF;
        ELSIF l_region_name IN ('APJ', 'EMEA', 'LATAM') THEN
          l_business_unit_val := coa_bu_exp_others_transform(p_legacy_location_val);
        ELSE
          p_err_msg := p_err_msg || 'Invalid CoA Region' || ',';
        END IF;
        IF l_business_unit_val IN
           ('Invalid CoA Business Unit', 'Business Unit Removed in S3') THEN
          p_err_msg := p_err_msg || l_business_unit_val || ' ,';
        END IF;
      ELSIF l_account_type = 'Balance Sheet Account' THEN
        l_business_unit_val := '000';
      ELSIF l_account_type IN
            ('Other Income Expense', 'Tax Related Accounts') THEN
        l_business_unit_val := '890';
      END IF;

      --Department Transform
      IF p_legacy_department_val IS NOT NULL THEN
        IF l_account_type IN
           ('Balance Sheet Account', 'Sales Account', 'COGS',
            'Other Income Expense', 'Tax Related Accounts') THEN
          l_department_val := '0000';
        ELSIF l_account_type = 'Expense Account' THEN
          l_department_val := coa_department_transform(p_legacy_department_val);
          IF l_department_val IN
             ('Invalid CoA Department', 'Department Removed in S3') THEN
            p_err_msg := p_err_msg || l_department_val || ' ,';
          END IF;
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Department';
      END IF;

      --Product Line transform
      IF p_legacy_product_val IS NOT NULL THEN
        IF l_account_type IN ('Sales Account', 'COGS') THEN
          IF p_legacy_product_val != '000' THEN
            IF p_item_number IS NOT NULL THEN
              l_product_line_val := coa_prod_line_sc_transform(p_item_number);
              IF l_product_line_val = 'Invalid CoA Product Line' THEN
                p_err_msg := p_err_msg || l_product_line_val || ' ,';
              END IF;
            ELSE
              l_product_line_val := '9999';
            END IF;
          ELSIF p_legacy_product_val = '000' THEN
            l_product_line_val := '0000';
          END IF;
        ELSIF l_account_type IN
              ('Balance Sheet Account', 'Other Income Expense',
               'Tax Related Accounts', 'Expense Account') THEN
          l_product_line_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Product Line';
      END IF;

      --Location transform
      IF p_legacy_location_val IS NOT NULL THEN
        IF l_account_type = 'Sales Account' THEN
          l_location_val := coa_location_transform(p_legacy_location_val);
          IF l_location_val = 'Invalid CoA Location' THEN
            p_err_msg := p_err_msg || l_location_val || ' ,';
          END IF;
        ELSIF l_account_type IN
              ('Balance Sheet Account', 'Other Income Expense',
               'Tax Related Accounts', 'Expense Account', 'COGS') THEN
          l_location_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Location';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);

      --Intercompany transform
      IF p_legacy_intercompany_val IS NOT NULL THEN
        IF l_account_type IN
           ('Sales Account', 'Balance Sheet Account', 'COGS') THEN
          l_intercompany_val := coa_intercompany_transform(p_legacy_intercompany_val,
                                                           p_legacy_division_val,
                                                           l_region_name);
          IF l_intercompany_val LIKE '%Invalid%' THEN
            p_err_msg := p_err_msg || l_intercompany_val || ' ,';
          END IF;
        ELSIF l_account_type IN ('Expense Account', 'Other Income Expense',
               'Tax Related Accounts') THEN
          l_intercompany_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Intercompany';
      END IF;
    ELSE
      p_err_msg := p_err_msg || 'Invalid CoA Account';
    END IF;

    --If any value Invalid then return error message

    IF p_err_msg LIKE '%Invalid%' OR p_err_msg LIKE '%Removed in S3%' THEN
      p_err_code     := '2';
      p_err_msg      := substr('For ' || p_field_name || ': ' || p_err_msg,
                               1,
                               4000);
      p_s3_gl_string := NULL;
      RETURN;

    END IF;
    p_err_code     := '0';
    p_err_msg      := 'SUCCESS';

    --Return concatenated string if there are no errors
    p_s3_gl_string := l_company_val || '.' || l_business_unit_val || '.' ||
                      l_department_val || '.' || l_account_val || '.' ||
                      l_product_line_val || '.' || l_location_val || '.' ||
                      l_intercompany_val || '.' || l_future_val;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_s3_gl_string := NULL;
      p_err_code     := '2';
      p_err_msg      := substr('SQLERRM: ' || SQLERRM || ' Backtrace: ' ||
                               dbms_utility.format_error_backtrace,
                               1,
                               4000);
  END coa_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for item master. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  01/08/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_item_master_transform(p_field_name              IN VARCHAR2,
                                      p_s3_org_code             IN VARCHAR2,
                                      p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                                      p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                                      p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                                      p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                                      p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                                      p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                                      p_legacy_division_val     IN VARCHAR2,
                                      p_item_number             IN VARCHAR2 DEFAULT NULL,
                                      p_s3_gl_string            OUT VARCHAR2,
                                      p_err_code                OUT VARCHAR2, -- Output error code
                                      p_err_msg                 OUT VARCHAR2) --Output Message VARCHAR2(4000)
   AS

    l_company_val       VARCHAR2(250);
    l_business_unit_val VARCHAR2(250);
    l_department_val    VARCHAR2(250);
    l_account_val       VARCHAR2(250);
    l_product_line_val  VARCHAR2(250);
    l_location_val      VARCHAR2(250);
    l_future_val        VARCHAR2(250);
    l_intercompany_val  VARCHAR2(250);
    l_acc_first_digit   VARCHAR2(1);
    l_account_type      VARCHAR2(100);
    l_region_name       VARCHAR2(100);

  BEGIN
    IF p_legacy_account_val IS NOT NULL THEN
      SELECT substr(p_legacy_account_val, 1, 1)
        INTO l_acc_first_digit
        FROM dual;
      IF l_acc_first_digit = '4' THEN
        l_account_type := 'Sales Account';
      ELSIF l_acc_first_digit = '5' THEN
        l_account_type := 'COGS';
      ELSIF l_acc_first_digit = '6' THEN
        l_account_type := 'Expense Account';
      ELSIF l_acc_first_digit IN ('1', '2', '3') THEN
        l_account_type := 'Balance Sheet Account';
      ELSIF l_acc_first_digit = '7' THEN
        l_account_type := 'Other Income Expense';
      ELSIF l_acc_first_digit = '8' THEN
        l_account_type := 'Tax Related Accounts';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);
      --Future Transform
      l_future_val := '000';

      --Account Transform
      l_account_val := coa_account_transform(p_legacy_account_val);
      IF l_account_val IN ('Invalid CoA Account', 'Account Removed in S3') THEN
        p_err_msg := p_err_msg || l_account_val || ' ,';
      END IF;

      --Company Transform
      IF p_legacy_company_val IS NOT NULL THEN
        l_company_val := coa_company_transform(p_legacy_company_val,
                                               p_legacy_division_val,
                                               l_region_name);
        IF l_company_val LIKE 'Invalid%Company%' THEN
          p_err_msg := p_err_msg || l_company_val || ' ,';
        END IF;
      ELSE
        p_err_msg := 'Invalid CoA Company';
      END IF;

      IF l_region_name = 'US' THEN
        l_region_name := 'NA';
      END IF;
      IF l_region_name = 'Invalid CoA Region' THEN
        p_err_msg := p_err_msg || l_region_name || ',';
      END IF;
      --Business Unit Transform
      IF l_account_type IN ('Sales Account', 'COGS') THEN
        IF p_s3_org_code in ('GIM', 'M01') THEN
          l_business_unit_val := '890';
        ELSIF p_s3_org_code IN ('T01', 'T02', 'T03', 'S02') THEN
          l_business_unit_val := '501';
        END IF;
      ELSIF l_account_type = 'Expense Account' THEN
        IF p_s3_org_code = 'GIM' THEN
          l_business_unit_val := '890';
        ELSE
          IF p_legacy_department_val = '000' THEN
            l_business_unit_val := '000';
          ELSE
            IF l_region_name = 'NA' THEN
              IF p_legacy_company_val NOT IN ('34', '37', '44', '46') THEN
                l_business_unit_val := coa_bu_exp_na_transform(p_legacy_company_val,
                                                               p_legacy_department_val);
              ELSE
                l_business_unit_val := coa_bu_exp_na_spcl_transform(p_legacy_company_val);
              END IF;
            ELSIF l_region_name IN ('APJ', 'EMEA', 'LATAM') THEN
              l_business_unit_val := coa_bu_exp_others_transform(p_legacy_location_val);
            ELSE
              p_err_msg := p_err_msg || 'Invalid CoA Region' || ',';
            END IF;
            IF l_business_unit_val IN
               ('Invalid CoA Business Unit', 'Business Unit Removed in S3') THEN
              p_err_msg := p_err_msg || l_business_unit_val || ' ,';
            END IF;
          END IF;
        END IF;
      END IF;

      --Department Transform
      IF p_legacy_department_val IS NOT NULL THEN
        IF p_legacy_department_val != '000' THEN
          IF l_account_type IN
             ('Balance Sheet Account', 'Sales Account', 'COGS',
              'Other Income Expense', 'Tax Related Accounts') THEN
            l_department_val := '0000';
          ELSIF l_account_type = 'Expense Account' THEN
            l_department_val := coa_department_transform(p_legacy_department_val);
            IF l_department_val IN
               ('Invalid CoA Department', 'Department Removed in S3') THEN
              p_err_msg := p_err_msg || l_department_val || ' ,';
            END IF;
          END IF;
        ELSIF p_legacy_department_val = '000' THEN
          l_department_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Department';
      END IF;

      --Product Line transform
      IF p_legacy_product_val IS NOT NULL THEN
        IF l_account_type IN ('Sales Account', 'COGS') THEN
          IF p_legacy_product_val != '000' THEN
            IF p_item_number IS NOT NULL THEN
              l_product_line_val := coa_prod_line_sc_transform(p_item_number);
              IF l_product_line_val = 'Invalid CoA Product Line' THEN
                p_err_msg := p_err_msg || l_product_line_val || ' ,';
              END IF;
            ELSE
              l_product_line_val := '9999';
            END IF;
          ELSIF p_legacy_product_val = '000' THEN
            l_product_line_val := '0000';
          END IF;
        ELSIF l_account_type IN
              ('Balance Sheet Account', 'Other Income Expense',
               'Tax Related Accounts', 'Expense Account') THEN
          l_product_line_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Product Line';
      END IF;

      --Location transform
      IF p_legacy_location_val IS NOT NULL THEN
        IF l_account_type = 'Sales Account' THEN
          l_location_val := coa_location_transform(p_legacy_location_val);
          IF l_location_val = 'Invalid CoA Location' THEN
            p_err_msg := p_err_msg || l_location_val || ' ,';
          END IF;
        ELSIF l_account_type IN
              ('Balance Sheet Account', 'Other Income Expense',
               'Tax Related Accounts', 'Expense Account', 'COGS') THEN
          l_location_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Location';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);

      --Intercompany transform
      IF p_legacy_intercompany_val IS NOT NULL THEN
        IF l_account_type IN
           ('Sales Account', 'Balance Sheet Account', 'COGS') THEN
          l_intercompany_val := coa_intercompany_transform(p_legacy_intercompany_val,
                                                           p_legacy_division_val,
                                                           l_region_name);
          IF l_intercompany_val LIKE '%Invalid%' THEN
            p_err_msg := p_err_msg || l_intercompany_val || ' ,';
          END IF;
        ELSIF l_account_type IN ('Expense Account', 'Other Income Expense',
               'Tax Related Accounts') THEN
          l_intercompany_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Intercompany';
      END IF;
    ELSE
      p_err_msg := p_err_msg || 'Invalid CoA Account';
    END IF;

    --If any value Invalid then return error message

    IF p_err_msg LIKE '%Invalid%' OR p_err_msg LIKE '%Removed in S3%' THEN
      p_err_code     := '2';
      p_err_msg      := substr('For ' || p_field_name || ': ' || p_err_msg,
                               1,
                               4000);
      p_s3_gl_string := NULL;
      RETURN;
    END IF;

    --Return concatenated string if there are no errors
    p_err_code     := '0';
    p_err_msg      := 'SUCCESS';
    p_s3_gl_string := l_company_val || '.' || l_business_unit_val || '.' ||
                      l_department_val || '.' || l_account_val || '.' ||
                      l_product_line_val || '.' || l_location_val || '.' ||
                      l_intercompany_val || '.' || l_future_val;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_s3_gl_string := NULL;
      p_err_code     := '2';
      p_err_msg      := substr('SQLERRM: ' || SQLERRM || ' Backtrace: ' ||
                               dbms_utility.format_error_backtrace,
                               1,
                               4000);
  END coa_item_master_transform;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for Open GL Balances. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_gl_balance_transform(p_field_name              IN VARCHAR2,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2, -- Output error code
                          p_err_msg                 OUT VARCHAR2) --Output Message VARCHAR2(4000)
   AS

    l_company_val       VARCHAR2(250);
    l_business_unit_val VARCHAR2(250);
    l_department_val    VARCHAR2(250);
    l_account_val       VARCHAR2(250);
    l_product_line_val  VARCHAR2(250);
    l_location_val      VARCHAR2(250);
    l_future_val        VARCHAR2(250);
    l_intercompany_val  VARCHAR2(250);
    l_acc_first_digit   VARCHAR2(1);
    l_account_type      VARCHAR2(100);
    l_region_name       VARCHAR2(100);

  BEGIN
    IF p_legacy_account_val IS NOT NULL THEN
      SELECT substr(p_legacy_account_val, 1, 1)
        INTO l_acc_first_digit
        FROM dual;
      IF l_acc_first_digit = '4' THEN
        l_account_type := 'Sales Account';
      ELSIF l_acc_first_digit = '5' THEN
        l_account_type := 'COGS';
      ELSIF l_acc_first_digit = '6' THEN
        l_account_type := 'Expense Account';
      ELSIF l_acc_first_digit IN ('1', '2', '3') THEN
        l_account_type := 'Balance Sheet Account';
      ELSIF l_acc_first_digit = '7' THEN
        l_account_type := 'Other Income Expense';
      ELSIF l_acc_first_digit = '8' THEN
        l_account_type := 'Tax Related Accounts';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);
      --Future Transform
      l_future_val := '000';

      --Account Transform
      l_account_val := coa_account_transform(p_legacy_account_val);
      IF l_account_val IN ('Invalid CoA Account', 'Account Removed in S3') THEN
        p_err_msg := p_err_msg || l_account_val || ' ,';
      END IF;

      --Company Transform
      IF p_legacy_company_val IS NOT NULL THEN
        l_company_val := coa_company_transform(p_legacy_company_val,
                                               p_legacy_division_val,
                                               l_region_name);
        IF l_company_val LIKE 'Invalid%Company%' THEN
          p_err_msg := p_err_msg || l_company_val || ' ,';
        END IF;
      ELSE
        p_err_msg := 'Invalid CoA Company';
      END IF;
      --Business Unit Transform

     IF p_legacy_account_val BETWEEN  '600000' AND '699999' AND p_legacy_company_val = '26' THEN
       --Refer BU PO mapping
       IF l_region_name = 'US' THEN
        l_region_name := 'NA';
       END IF;
      IF l_region_name = 'Invalid CoA Region' THEN
        p_err_msg := p_err_msg || l_region_name || ',';
      END IF;
        IF l_region_name = 'NA' THEN
          IF p_legacy_company_val NOT IN ('34', '37', '44', '46','33') THEN
            l_business_unit_val := coa_bu_open_po_na_transform(p_legacy_company_val,
                                                           p_legacy_department_val);
          ELSE
            l_business_unit_val := coa_bu_po_na_spcl_transform(p_legacy_company_val);
          END IF;
        ELSIF l_region_name IN ('APJ', 'EMEA', 'LATAM') THEN
          l_business_unit_val := coa_bu_po_others_transform(p_legacy_location_val);
        ELSE
          p_err_msg := p_err_msg || 'Invalid CoA Region' || ',';
        END IF;
        IF l_business_unit_val IN
           ('Invalid CoA Business Unit', 'Business Unit Removed in S3') THEN
          p_err_msg := p_err_msg || l_business_unit_val || ' ,';
        END IF;
       -- refer BU PO mapping
     ELSE
      l_business_unit_val := coa_bu_open_gl_transform(p_legacy_account_val,p_legacy_intercompany_val,p_legacy_company_val);
          IF l_business_unit_val = 'Invalid CoA Business Unit' THEN
            p_err_msg := p_err_msg || l_business_unit_val || ' ,';
          END IF;
     END IF;
      --Department Transform
      IF p_legacy_department_val IS NOT NULL THEN
        IF l_acc_first_digit = '6' THEN
         l_department_val := coa_department_transform(p_legacy_department_val);
          IF l_department_val IN
             ('Invalid CoA Department', 'Department Removed in S3') THEN
            p_err_msg := p_err_msg || l_department_val || ' ,';
          END IF;
        ELSE
         l_department_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Department';
      END IF;

      --Product Line transform
      IF p_legacy_product_val IS NOT NULL THEN
        IF l_acc_first_digit IN ('4','5') THEN
          IF p_legacy_product_val != '000' THEN
            IF p_item_number IS NOT NULL THEN
              l_product_line_val := coa_prod_line_sc_transform(p_item_number);
              IF l_product_line_val = 'Invalid CoA Product Line' THEN
                p_err_msg := p_err_msg || l_product_line_val || ' ,';
              END IF;
            ELSE
              l_product_line_val := '9999';
            END IF;
          ELSIF p_legacy_product_val = '000' THEN
            l_product_line_val := '0000';
          END IF;
        ELSE
          l_product_line_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Product Line';
      END IF;

      --Location transform
      IF p_legacy_location_val IS NOT NULL THEN
        IF l_acc_first_digit IN ('4','5') THEN
          l_location_val := coa_location_transform(p_legacy_location_val);
          IF l_location_val = 'Invalid CoA Location' THEN
            p_err_msg := p_err_msg || l_location_val || ' ,';
          END IF;
        ELSE
          l_location_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Location';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);

     --Intercompany transform
      IF p_legacy_intercompany_val IS NOT NULL THEN
          l_intercompany_val := coa_intercompany_transform(p_legacy_intercompany_val,
                                                           p_legacy_division_val,
                                                           l_region_name);
          IF l_intercompany_val LIKE '%Invalid%' THEN
            p_err_msg := p_err_msg || l_intercompany_val || ' ,';
          END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Intercompany';
      END IF;
    ELSE
      p_err_msg := p_err_msg || 'Invalid CoA Account';
    END IF;

    --If any value Invalid then return error message

    IF p_err_msg LIKE '%Invalid%' OR p_err_msg LIKE '%Removed in S3%' THEN
      p_err_code     := '2';
      p_err_msg      := substr('For ' || p_field_name || ': ' || p_err_msg,
                               1,
                               4000);
      p_s3_gl_string := NULL;
      RETURN;

    END IF;
    p_err_code     := '0';
    p_err_msg      := 'SUCCESS';

    --Return concatenated string if there are no errors
    p_s3_gl_string := l_company_val || '.' || l_business_unit_val || '.' ||
                      l_department_val || '.' || l_account_val || '.' ||
                      l_product_line_val || '.' || l_location_val || '.' ||
                      l_intercompany_val || '.' || l_future_val;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_s3_gl_string := NULL;
      p_err_code     := '2';
      p_err_msg      := substr('SQLERRM: ' || SQLERRM || ' Backtrace: ' ||
                               dbms_utility.format_error_backtrace,
                               1,
                               4000);
  END coa_gl_balance_transform;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for Open PO. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_open_po_transform(p_field_name              IN VARCHAR2,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2, -- Output error code
                          p_err_msg                 OUT VARCHAR2) --Output Message VARCHAR2(4000)
   AS

    l_company_val       VARCHAR2(250);
    l_business_unit_val VARCHAR2(250);
    l_department_val    VARCHAR2(250);
    l_account_val       VARCHAR2(250);
    l_product_line_val  VARCHAR2(250);
    l_location_val      VARCHAR2(250);
    l_future_val        VARCHAR2(250);
    l_intercompany_val  VARCHAR2(250);
    l_acc_first_digit   VARCHAR2(1);
    l_account_type      VARCHAR2(100);
    l_region_name       VARCHAR2(100);

  BEGIN
    IF p_legacy_account_val IS NOT NULL THEN
      SELECT substr(p_legacy_account_val, 1, 1)
        INTO l_acc_first_digit
        FROM dual;
      IF l_acc_first_digit = '4' THEN
        l_account_type := 'Sales Account';
      ELSIF l_acc_first_digit = '5' THEN
        l_account_type := 'COGS';
      ELSIF l_acc_first_digit = '6' THEN
        l_account_type := 'Expense Account';
      ELSIF l_acc_first_digit IN ('1', '2', '3') THEN
        l_account_type := 'Balance Sheet Account';
      ELSIF l_acc_first_digit = '7' THEN
        l_account_type := 'Other Income Expense';
      ELSIF l_acc_first_digit = '8' THEN
        l_account_type := 'Tax Related Accounts';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);
      --Future Transform
      l_future_val := '000';

      --Account Transform
      l_account_val := coa_account_transform(p_legacy_account_val);
      IF l_account_val IN ('Invalid CoA Account', 'Account Removed in S3') THEN
        p_err_msg := p_err_msg || l_account_val || ' ,';
      END IF;

      --Company Transform
      IF p_legacy_company_val IS NOT NULL THEN
        l_company_val := coa_company_transform(p_legacy_company_val,
                                               p_legacy_division_val,
                                               l_region_name);
        IF l_company_val LIKE 'Invalid%Company%' THEN
          p_err_msg := p_err_msg || l_company_val || ' ,';
        END IF;
      ELSE
        p_err_msg := 'Invalid CoA Company';
      END IF;
      --Business Unit Transform

      IF l_region_name = 'US' THEN
        l_region_name := 'NA';
      END IF;
      IF l_region_name = 'Invalid CoA Region' THEN
        p_err_msg := p_err_msg || l_region_name || ',';
      END IF;
        IF l_region_name = 'NA' THEN
          IF p_legacy_company_val NOT IN ('34', '37', '44', '46','33') THEN
            l_business_unit_val := coa_bu_open_po_na_transform(p_legacy_company_val,
                                                           p_legacy_department_val);
          ELSE
            l_business_unit_val := coa_bu_po_na_spcl_transform(p_legacy_company_val);
          END IF;
        ELSIF l_region_name IN ('APJ', 'EMEA', 'LATAM') THEN
          l_business_unit_val := coa_bu_po_others_transform(p_legacy_location_val);
        ELSE
          p_err_msg := p_err_msg || 'Invalid CoA Region' || ',';
        END IF;
        IF l_business_unit_val IN
           ('Invalid CoA Business Unit', 'Business Unit Removed in S3') THEN
          p_err_msg := p_err_msg || l_business_unit_val || ' ,';
        END IF;
      --END IF;

      --Department Transform
      IF p_legacy_department_val IS NOT NULL THEN
        IF l_acc_first_digit = '6' THEN
         l_department_val := coa_department_transform(p_legacy_department_val);
          IF l_department_val IN
             ('Invalid CoA Department', 'Department Removed in S3') THEN
            p_err_msg := p_err_msg || l_department_val || ' ,';
          END IF;
        ELSE
         l_department_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Department';
      END IF;

      --Product Line transform
      IF p_legacy_product_val IS NOT NULL THEN
        IF l_acc_first_digit IN ('4','5') THEN
          IF p_legacy_product_val != '000' THEN
            IF p_item_number IS NOT NULL THEN
              l_product_line_val := coa_prod_line_sc_transform(p_item_number);
              IF l_product_line_val = 'Invalid CoA Product Line' THEN
                p_err_msg := p_err_msg || l_product_line_val || ' ,';
              END IF;
            ELSE
              l_product_line_val := '9999';
            END IF;
          ELSIF p_legacy_product_val = '000' THEN
            l_product_line_val := '0000';
          END IF;
        ELSE
          l_product_line_val := '0000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Product Line';
      END IF;

      --Location transform
      IF p_legacy_location_val IS NOT NULL THEN
        IF l_acc_first_digit IN ('4','5') THEN
          l_location_val := coa_location_transform(p_legacy_location_val);
          IF l_location_val = 'Invalid CoA Location' THEN
            p_err_msg := p_err_msg || l_location_val || ' ,';
          END IF;
        ELSE
          l_location_val := '000';
        END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Location';
      END IF;
      l_region_name := get_company_region(p_legacy_company_val);

      --Intercompany transform
      IF p_legacy_intercompany_val IS NOT NULL THEN
          l_intercompany_val := coa_intercompany_transform(p_legacy_intercompany_val,
                                                           p_legacy_division_val,
                                                           l_region_name);
          IF l_intercompany_val LIKE '%Invalid%' THEN
            p_err_msg := p_err_msg || l_intercompany_val || ' ,';
          END IF;
      ELSE
        p_err_msg := p_err_msg || 'Invalid CoA Intercompany';
      END IF;
    ELSE
      p_err_msg := p_err_msg || 'Invalid CoA Account';
    END IF;

    --If any value Invalid then return error message

    IF p_err_msg LIKE '%Invalid%' OR p_err_msg LIKE '%Removed in S3%' THEN
      p_err_code     := '2';
      p_err_msg      := substr('For ' || p_field_name || ': ' || p_err_msg,
                               1,
                               4000);
      p_s3_gl_string := NULL;
      RETURN;

    END IF;
    p_err_code     := '0';
    p_err_msg      := 'SUCCESS';

    --Return concatenated string if there are no errors
    p_s3_gl_string := l_company_val || '.' || l_business_unit_val || '.' ||
                      l_department_val || '.' || l_account_val || '.' ||
                      l_product_line_val || '.' || l_location_val || '.' ||
                      l_intercompany_val || '.' || l_future_val;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_s3_gl_string := NULL;
      p_err_code     := '2';
      p_err_msg      := substr('SQLERRM: ' || SQLERRM || ' Backtrace: ' ||
                               dbms_utility.format_error_backtrace,
                               1,
                               4000);
  END coa_open_po_transform;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: .This procedure takes the S3 GL string as input and updates the S3 CoA segments in
  --           extract table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_update(p_gl_string               IN VARCHAR2,--concatenated GL string
                       p_stage_tab               IN VARCHAR2,-- staging table name
                       p_stage_primary_col       IN VARCHAR2,-- staging table primary column name
                       p_stage_primary_col_val   IN VARCHAR2,-- staging table primary column value
                       p_stage_company_col       IN VARCHAR2,-- s3_segment1
                       p_stage_business_unit_col IN VARCHAR2,--s3_segment2
                       p_stage_department_col    IN VARCHAR2,--s3_segment3
                       p_stage_account_col       IN VARCHAR2,--s3_segment4
                       p_stage_product_line_col  IN VARCHAR2,--s3_segment5
                       p_stage_location_col      IN VARCHAR2,--s3_segment6
                       p_stage_intercompany_col  IN VARCHAR2,--s3_segment7
                       p_stage_future_col        IN VARCHAR2,--s3_segment8
                       p_coa_err_msg             IN VARCHAR2,--error message during CoA transform
                       p_err_code                OUT VARCHAR2,
                       p_err_msg                 OUT VARCHAR2) AS

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
    IF p_coa_err_msg NOT LIKE '%SUCCESS%' THEN
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
                               l_dyn_statement || 'sqlerrm: ' || SQLERRM,
                               1,
                               4000);
      END;
      RETURN;
    ELSIF p_gl_string IS NOT NULL THEN
      SELECT substr(p_gl_string, 1, 3) INTO l_company_val FROM dual;
      SELECT substr(p_gl_string, 5, 3) INTO l_business_unit_val FROM dual;
      SELECT substr(p_gl_string, 9, 4) INTO l_department_val FROM dual;
      SELECT substr(p_gl_string, 14, 6) INTO l_account_val FROM dual;
      SELECT substr(p_gl_string, 21, 4) INTO l_product_line_val FROM dual;
      SELECT substr(p_gl_string, 26, 3) INTO l_location_val FROM dual;
      SELECT substr(p_gl_string, 30, 3) INTO l_intercompany_val FROM dual;
      SELECT substr(p_gl_string, 34, 3) INTO l_future_val FROM dual;

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

      --dbms_output.put_line(l_dyn_statement);
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
                               l_dyn_statement || 'sqlerrm: ' || SQLERRM,
                               1,
                               4000);
      END;
    END IF;
  END coa_update;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: Transformations for inventory stock Locator - Attribute2 parsing
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  29/07/2016 Paulami Ray                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE ptm_locator_attr2_parse(p_attribute2          IN VARCHAR2,
                                    p_att_org_code        OUT VARCHAR2,
                                    p_att_subinv          OUT VARCHAR2,
                                    p_att_concat_segments OUT VARCHAR2,
                                    p_att_row             OUT VARCHAR2,
                                    p_att_rack            OUT VARCHAR2,
                                    p_att_bin             OUT VARCHAR2,
                                    p_error_message       OUT VARCHAR2) IS

    l_slash_pos1          NUMBER := 0;
    l_slash_pos2          NUMBER := 0;
    l_dot_pos1            NUMBER := 0;
    l_dot_pos2            NUMBER := 0;
    l_get_org             VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);

  BEGIN

    IF (length(p_attribute2) - length(replace(p_attribute2, ' '))) >= 1 THEN

      p_error_message := 'Error in parsing Locator Name - Invalid format due to Spaces in Locator name';

    END IF;

    ------------------- get org, subinventory, segments----------
    l_slash_pos1 := INSTR(p_attribute2, '/');
    l_slash_pos2 := INSTR(p_attribute2, '/', 1, 2);

    IF (l_slash_pos1 = 0 OR l_slash_pos2 = 0) THEN

      p_error_message := 'Error in parsing Locator details - Incorrect format';

    ELSE

      l_get_org := SUBSTR(p_attribute2, 1, (l_slash_pos1 - 1));

      p_att_org_code := l_get_org;

    END IF;

    IF (l_slash_pos1 <> 0 AND l_slash_pos2 <> 0) THEN

      l_get_concat_segments := SUBSTR(p_attribute2, (l_slash_pos2 + 1));

      p_att_concat_segments := l_get_concat_segments;

      /*   DBMS_OUTPUT.PUT_LINE('l_get_concat_segments ' ||
      p_att_concat_segments);*/

      l_get_sub_inv_name := SUBSTR(p_attribute2,
                                   (l_slash_pos1 + 1),
                                   (l_slash_pos2 - l_slash_pos1 - 1));

      p_att_subinv := l_get_sub_inv_name;

      --  DBMS_OUTPUT.PUT_LINE('l_get_sub_inv_name ' || p_att_subinv);

    END IF;

    -------------------- get segment values-------------

    IF (l_get_concat_segments IS NOT NULL) THEN

      l_dot_pos1 := INSTR(l_get_concat_segments, '.');

      --   DBMS_OUTPUT.PUT_LINE('l_dot_pos1 ' || l_dot_pos1);

      IF l_dot_pos1 = 0 THEN

        p_error_message := 'Error in parsing Locator Name - Incorrect format';

      END IF;

      l_dot_pos2 := INSTR(l_get_concat_segments, '.', 1, 2);

      IF l_dot_pos2 = 0 THEN

        p_error_message := 'Error in parsing Locator Name - Incorrect format';

      END IF;

      --    DBMS_OUTPUT.PUT_LINE('l_dot_pos2 ' || l_dot_pos2);

      l_get_row := SUBSTR(l_get_concat_segments, 1, (l_dot_pos1 - 1));

      IF LENGTH(l_get_row) is null THEN

        p_error_message := 'Error in parsing Locator Name - Row not found';

      ELSE

        p_att_row := l_get_row;

      END IF;

      --  DBMS_OUTPUT.PUT_LINE('row ' || p_att_row);

      l_get_bin := SUBSTR(l_get_concat_segments, (l_dot_pos2 + 1));

      IF LENGTH(l_get_bin) is null THEN

        p_error_message := 'Error in parsing Locator Name - Bin not found';

      ELSE

        p_att_bin := l_get_bin;

      END IF;

      --  DBMS_OUTPUT.PUT_LINE('bin ' || p_att_bin);

      l_get_rack := SUBSTR(l_get_concat_segments,
                           (l_dot_pos1 + 1),
                           (l_dot_pos2 - l_dot_pos1 - 1));

      IF LENGTH(l_get_rack) is null THEN

        p_error_message := 'Error in parsing Locator Name - Rack not found';

      ELSE

        p_att_rack := l_get_rack;

      END IF;

      --   DBMS_OUTPUT.PUT_LINE('rack ' || p_att_rack);

    ELSE

      p_error_message := 'Locator not present';

    END IF;

  EXCEPTION

    WHEN OTHERS THEN
      p_error_message := 'Error in parsing Attribute2 details';

  END ptm_locator_attr2_parse;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generic Transformation function to derive the S3 value for a given legacy value
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/07/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  FUNCTION transform_function(p_mapping_type IN VARCHAR2,
                              p_legacy_val   IN VARCHAR2,
                              p_other_col    IN VARCHAR2) RETURN VARCHAR2 IS
    l_transform_val VARCHAR2(250) := 'N';
  BEGIN
    BEGIN
      IF p_other_col IS NOT NULL THEN
        SELECT s3_data
          INTO l_transform_val
          FROM xxobjt.xxs3_transform
         WHERE legacy_data = p_legacy_val
           AND mapping_type = p_mapping_type
           AND legacy_information = p_other_col;
      ELSE
        SELECT s3_data
          INTO l_transform_val
          FROM xxobjt.xxs3_transform
         WHERE legacy_data = p_legacy_val
           AND mapping_type = p_mapping_type;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_transform_val := 'E';
    END;
    IF (l_transform_val = 'E' ) THEN
      l_transform_val := 'Invalid Mapping';
    END IF;
    RETURN l_transform_val;
  END transform_function;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generic Transformation procedure which will call the transform_function procedure
  --          to derive the S3 transformed value for a legacy value and update the relevant column
  --          in staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/07/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE transform(p_mapping_type IN VARCHAR2,           --Mapping Type
                      p_stage_tab             IN VARCHAR2, --Staging Table Name
                      p_stage_primary_col     IN VARCHAR2, --Staging Table Primary Column Name
                      p_stage_primary_col_val IN VARCHAR2, --Staging Table Primary Column Value
                      p_legacy_val            IN VARCHAR2, --Legacy Value
                      p_stage_col             IN VARCHAR2, -- Staging Table Transformed Column Name
                      p_other_col             IN VARCHAR2 DEFAULT NULL,--Required for additional attributes required during transformation
                      p_err_code OUT VARCHAR2, -- Output error code
                      p_err_msg  OUT VARCHAR2) --Output Message
   AS
    l_dyn_statement    VARCHAR2(1000);
    l_transformed_val  VARCHAR2(250);
    l_stage_status_col VARCHAR2(30) := 'TRANSFORM_STATUS';
    l_stage_error_col  VARCHAR2(30) := 'TRANSFORM_ERROR';
    l_fail_status      VARCHAR2(10) := 'FAIL';
    l_pass_status      VARCHAR2(10) := 'PASS';
  BEGIN
    IF p_legacy_val IS NOT NULL THEN
      l_transformed_val := transform_function(p_mapping_type,
                                              p_legacy_val,
                                              p_other_col);
      IF l_transformed_val = 'Invalid Mapping' THEN
        p_err_msg := l_transformed_val || ' ,';
      END IF;
    END IF;
    --If any value Invalid then update staging table with error message
    IF p_err_msg LIKE '%Invalid%' THEN
      p_err_code      := '2';
      p_err_msg       := substr('For ' || p_stage_col || ': ' || p_err_msg,
                                1,
                                2000);
      l_dyn_statement := '';
      l_dyn_statement := 'update ' || p_stage_tab || ' set ' ||
                         l_stage_status_col || ' = ''' || l_fail_status ||
                         ''', ' || l_stage_error_col || ' = ' ||
                         l_stage_error_col || '|| ''' || p_err_msg ||
                         ''' where ' || p_stage_primary_col || ' = ' ||
                         p_stage_primary_col_val;

      /*'update ' || p_stage_tab || ' set ' || l_stage_status_col || ' = ''' ||
      l_fail_status || ''',' || l_stage_error_col || ' = ''' ||
      l_stage_error_col || '' || '' || p_err_msg || ''' where ' ||
      p_stage_primary_col || ' = ' || p_stage_primary_col_val;*/
      BEGIN
        EXECUTE IMMEDIATE l_dyn_statement;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          p_err_code := '2';
          p_err_msg  := substr('Error in dynamic statement ' ||
                               l_dyn_statement || 'sqlerrm: ' || SQLERRM,
                               1,
                               2000);
      END;
      RETURN;
    END IF;
    l_dyn_statement := '';
    --Dynamic update statement
    IF l_transformed_val IS NOT NULL THEN
      l_dyn_statement := 'update ' || p_stage_tab || ' set ' || p_stage_col ||
                         ' = ''' || l_transformed_val || ''',' ||
                         l_stage_status_col || ' = CASE WHEN ' ||
                         l_stage_error_col || ' IS NOT NULL THEN ''' ||
                         l_fail_status || ''' ELSE ''' || l_pass_status ||
                         ''' END  where ' || p_stage_primary_col || ' = ' ||
                         p_stage_primary_col_val;
    END IF;
    p_err_code := '0';
    p_err_msg  := 'SUCCESS';

    --dbms_output.put_line(l_dyn_statement);
    BEGIN
      EXECUTE IMMEDIATE l_dyn_statement;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        p_err_code := '2';
        p_err_msg  := substr('Error in dynamic statement ' ||
                             l_dyn_statement || 'sqlerrm: ' || SQLERRM,
                             1,
                             200);
    END;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_msg := substr('SQLERRM: ' || SQLERRM || ' Backtrace: ' ||
                          dbms_utility.format_error_backtrace,
                          1,
                          200);
  END transform;
END xxs3_data_transform_util_pkg;
/
