create or replace package body xxgl_utils_pkg IS
  ---------------------------------------------------------------------------------------------------------------------------
  --     1.1  15/01/14  Ofer Suad       CR -1228 Add function to support location segment in disco reports
  --     1.2  11/03/15  Ofer Suad       CHG0034796- Add translation according to monthly average rates
  --     1.3  10/05/16  Ofer Suad       CHG0037996- Function get product line for Misclenious transactions
  --     1.4  01/03/17  Ofer Suad       CHG0040189- add function XXAP_GET_ITEM_PL ,
  --                                                Use SLA to define product line segment for IPV PPV and WIP variances .
  --     1.5  13/06/17  Yuval Tal       CHG0040954 -modify xxinv_get_item_pl  add accounting event code
  --     1.6  01/07/18  Ofer Suad       CHG0042557- SLA for Recycling variance  and return from NonAsset Subinventory
  --     1.7  02/09/19  Bellona B.      CHG0046386-	Add new conversion rate type - AOP
  ----------------------------------------------------------------------------------------------------------------------------

  --Global Variables
  g_gl_app_short_name VARCHAR2(5) := NULL;
  g_seg_delimiter     VARCHAR2(1) := NULL;
  g_seg_num           NUMBER := NULL;
  g_chart_of_acc_id   NUMBER := NULL;

  FUNCTION get_coa_id_from_inv_org(p_inv_org_id NUMBER,
                                   x_org_id     OUT NUMBER) RETURN NUMBER IS

    l_coa_id NUMBER;

  BEGIN

    SELECT ood.chart_of_accounts_id, ood.operating_unit
      INTO l_coa_id, x_org_id
      FROM org_organization_definitions ood
     WHERE ood.organization_id = p_inv_org_id;

    RETURN l_coa_id;

  EXCEPTION
    WHEN OTHERS THEN

      RETURN - 1;

  END get_coa_id_from_inv_org;

  FUNCTION get_coa_id_from_ou(p_org_id NUMBER) RETURN NUMBER IS

    l_coa_id NUMBER;

  BEGIN

    SELECT l.chart_of_accounts_id
      INTO l_coa_id
      FROM hr_operating_units ou, gl_ledgers l
     WHERE ou.organization_id = p_org_id
       AND ou.set_of_books_id = l.ledger_id;

    RETURN l_coa_id;

  EXCEPTION
    WHEN OTHERS THEN

      RETURN - 1;

  END get_coa_id_from_ou;

  PROCEDURE init_account_params(p_chart_of_acc_id NUMBER) IS

  BEGIN

    g_chart_of_acc_id := p_chart_of_acc_id;

    SELECT fap.application_short_name, fifs.concatenated_segment_delimiter
      INTO g_gl_app_short_name, g_seg_delimiter
      FROM fnd_application        fap,
           fnd_id_flexs           fif,
           fnd_id_flex_structures fifs
     WHERE fif.application_id = fap.application_id
       AND fif.id_flex_code = 'GL#'
       AND fifs.application_id = fif.application_id
       AND fifs.id_flex_code = fif.id_flex_code
       AND fifs.id_flex_num = p_chart_of_acc_id;

  END init_account_params;

  PROCEDURE get_and_create_account(p_concat_segment      IN VARCHAR2,
                                   p_coa_id              IN VARCHAR2,
                                   p_app_short_name      IN VARCHAR2 DEFAULT NULL,
                                   x_code_combination_id OUT NUMBER,
                                   x_return_code         OUT VARCHAR2,
                                   x_err_msg             OUT VARCHAR2) IS

    segments fnd_flex_ext.segmentarray;

  BEGIN

    x_return_code := fnd_api.g_ret_sts_success;

    IF g_gl_app_short_name IS NULL OR g_seg_delimiter IS NULL OR
       nvl(g_chart_of_acc_id, -1) != p_coa_id THEN

      init_account_params(p_coa_id);

    END IF;

    g_seg_num := fnd_flex_ext.breakup_segments(p_concat_segment,
                                               g_seg_delimiter,
                                               segments);

    get_and_create_account(segments,
                           p_coa_id,
                           p_app_short_name,
                           x_code_combination_id,
                           x_return_code,
                           x_err_msg);

  EXCEPTION
    WHEN OTHERS THEN

      x_return_code := fnd_api.g_ret_sts_error;
      x_err_msg     := SQLERRM;

  END get_and_create_account;

  PROCEDURE get_and_create_account(segments              fnd_flex_ext.segmentarray,
                                   p_coa_id              IN VARCHAR2,
                                   p_app_short_name      IN VARCHAR2 DEFAULT NULL,
                                   x_code_combination_id OUT NUMBER,
                                   x_return_code         OUT VARCHAR2,
                                   x_err_msg             OUT VARCHAR2) IS

  BEGIN

    x_return_code := fnd_api.g_ret_sts_success;

    IF g_gl_app_short_name IS NULL OR g_seg_delimiter IS NULL OR
       nvl(g_chart_of_acc_id, -1) != p_coa_id THEN

      init_account_params(p_coa_id);

    END IF;

    /*     g_seg_num := fnd_flex_ext.breakup_segments(p_concat_segment,
                                                     g_seg_delimiter,
                                                     segments);
    */
    IF NOT
        fnd_flex_ext.get_combination_id(application_short_name => g_gl_app_short_name,
                                        key_flex_code          => 'GL#',
                                        structure_number       => p_coa_id,
                                        validation_date        => SYSDATE,
                                        n_segments             => segments.count,
                                        segments               => segments,
                                        combination_id         => x_code_combination_id) THEN

      x_return_code := fnd_api.g_ret_sts_unexp_error;
      x_err_msg     := 'Action failed.';

    END IF;

  EXCEPTION
    WHEN OTHERS THEN

      x_return_code := fnd_api.g_ret_sts_error;
      x_err_msg     := SQLERRM;

  END get_and_create_account;

  /* SAFE_BUILD_FORMAT_MASK- slower version of BUILD_FORMAT_MASK
  **                         without WNPS pragma restrictions.
  **
  ** This version of BUILD_FORMAT_MASK uses slower,
  ** non-caching profiles functions to do its defaulting.  It runs
  ** about half the speed of BUILD_FORMAT_MASK, but it can
  ** be used in situations, like views, that BUILD_FORMAT_MASK
  ** cannot be used due to pragma restrictions.
  ** Note, however, that if you pass values for the
  ** disp_grp_sep, neg_format, and pos_format parameters instead
  ** of letting them default to NULL, then this routine will
  ** not be any slower than BUILD_FORMAT_MASK
  */
  PROCEDURE safe_build_format_mask(format_mask   OUT NOCOPY VARCHAR2,
                                   field_length  IN NUMBER, /* maximum number of char in dest field */
                                   PRECISION     IN NUMBER, /* number of digits to right of decimal*/
                                   min_acct_unit IN NUMBER, /* minimum value by which amt can vary */
                                   disp_grp_sep  IN BOOLEAN DEFAULT NULL,
                                   /* NULL=from profile CURRENCY:THOUSANDS_SEPARATOR */
                                   neg_format IN VARCHAR2 DEFAULT NULL,
                                   /* '-XXX', 'XXX-', '<XXX>', '(XXX)' */
                                   /* NULL=from profile CURRENCY:NEGATVE_FORMAT */
                                   pos_format IN VARCHAR2 DEFAULT NULL,
                                   /* 'XXX', '+XXX', 'XXX-', */
                                   /* NULL=from profile CURRENCY:POSITIVE_FORMAT*/
                                   p_thousands_separator VARCHAR2 DEFAULT 'N') IS

    mask           VARCHAR2(100);
    whole_width    NUMBER; /* number of characters to left of decimal */
    decimal_width  NUMBER; /* width of decimal and numbers rt of dec */
    sign_width     NUMBER; /* width of pos/neg sign */
    profl_val      VARCHAR2(80);
    x_disp_grp_sep BOOLEAN;
    x_pos_format   VARCHAR2(30);
    x_neg_format   VARCHAR2(30);

  BEGIN

    /* process the arguments, defaulting in profile values if necessary*/

    IF (disp_grp_sep IS NULL) THEN
      profl_val := p_thousands_separator;
      IF (profl_val = 'Y') THEN
        x_disp_grp_sep := TRUE;
      ELSE
        x_disp_grp_sep := FALSE;
      END IF;
    ELSE
      x_disp_grp_sep := disp_grp_sep;
    END IF;

    /* Bug 5529158: FND_CURRENCY.BUILD_FORMAT_MASK MISMATCH IN FNDSQF.PLD AND
    * AFMLCURB.PLS
    *
    * FNDSQF.pld 115.1 was changed to enable support of the (XXX) Core number
    * formatting ability in Core 3 (4.5.7). This change was not made in the
    * PL/SQL package AFMLCURB.pls. Hence, there is an inconsistency between
    * FNDSQF.pld and AFMLCURB.pls with regards to handling (XXX).
    */

    -- if(neg_format is NULL) then
    --   profl_val := fnd_profile.value_specific('CURRENCY:NEGATIVE_FORMAT');
    --   if(profl_val = '0' or profl_val = '1' or profl_val = '2') then
    --      x_neg_format := '<XXX>';
    --   elsif (profl_val = '4') then  /* '4' gives trailing sign */
    --      x_neg_format := 'XXX-';
    --
    --   /* Found out that the default value being set is 'XXX-', not '-XXX',
    --    * which is documented to be the default value.
    --    */
    --
    --   else                          /* '3' or default gives leading sign */
    --      x_neg_format := '-XXX';
    --   end if;
    -- else
    --   x_neg_format := neg_format;
    -- end if;

    IF (neg_format IS NULL) THEN
      profl_val := fnd_profile.value_specific('CURRENCY:NEGATIVE_FORMAT');
      IF (profl_val = '0' /* (XXX) */
         OR profl_val = '1') THEN
        /* [XXX] */
        x_neg_format := '(XXX)'; -- Bug 5529158
      ELSIF (profl_val = '2') THEN
        /* <XXX> */
        x_neg_format := '<XXX>';
      ELSIF (profl_val = '4') THEN
        /* '4' gives trailing sign*/
        x_neg_format := 'XXX-';

        /* Found out that the default value being set is 'XXX-', not '-XXX',
        * which is documented to be the default value.
        */

      ELSE
        /* '3' or default gives leading sign */
        x_neg_format := '-XXX';
      END IF;
    ELSE
      x_neg_format := neg_format;
    END IF;

    IF (pos_format IS NULL) THEN
      profl_val := fnd_profile.value_specific('CURRENCY:POSITIVE_FORMAT');
      IF (profl_val = '1') THEN
        x_pos_format := '+XXX';
      ELSIF (profl_val = '2') THEN
        x_pos_format := 'XXX+';
      ELSE
        /* '0' or default gives no pos. */
        x_pos_format := 'XXX';
      END IF;
    ELSE
      x_pos_format := pos_format;
    END IF;

    /* NULL precision can mean that GET_INFO failed to find info for currency*/
    IF (PRECISION IS NULL) THEN
      format_mask := '';
      RETURN;
    END IF;

    IF (PRECISION > 0) THEN
      /* If there is a decimal portion */
      decimal_width := 1 + PRECISION;
    ELSE
      decimal_width := 0;
    END IF;

    /* Bug 2993411: FND_CURRENCY.GET_FORMAT_MASK:PL/SQL:NUMERIC OR VALUE
    * ERROR:STRING BUFFER
    *
    * When the profile option 'Currency: Negative Format' is set to 'XXX-', the    * string 'MI'is appended to the end of the format mask.  This addition
    * causes the string to be longer than the field_length.  So, along with
    * '<XXX>', 'XXX-' is also adjusted for proper sign_width to ensure that the    * resulting format mask does not exceed the desired field_length.
    */
    IF (x_neg_format = '<XXX>' OR x_neg_format = '(XXX)' -- Bug 5529158
       OR x_neg_format = 'XXX-') THEN
      sign_width := 2;
    ELSE
      sign_width := 1;
    END IF;

    /* Determine the length of the portion to the left of decimal.
    * This value has been adjusted by subtracting 1 to account for
    * the addition of the string 'FM' which prevents leading spaces.
    * Without the adjustment, the resulting format mask can be larger
    * than the allotted maximum length for format_mask.  This would
    * result in ORA-6502 PL/SQL: numeric or value error: character string
    * buffer too small.  See bug 1580374.
    */
    whole_width := field_length - decimal_width - sign_width - 1;

    IF (whole_width < 0) THEN
      format_mask := '';
      RETURN;
    END IF;

    /* build up the portion to the left of decimal, e.g. 99G999G990 */

    mask := '0' || mask; /* Start the format with 0 */

    IF (whole_width > 1) THEN

      FOR i IN 2 .. whole_width LOOP

        /* If there is a thousands separator, need to mark it. */
        IF (x_disp_grp_sep) AND (MOD(i, 4) = 0) THEN
          IF (i < whole_width - 1) THEN
            /* don't start with */
            mask := 'G' || mask; /* group separator */
          END IF;
          /* Else, add 9 to the format as long as we have not reached
          * the maximum length of whole numbers.  This was added due
          * to bug 1580374 to ensure that ORA-6502 is not obtained.
          */
        ELSIF (i <> whole_width) THEN
          mask := '9' || mask;
        END IF;

      END LOOP;

    END IF;

    /* build up the portion to the right of the decimal e.g. .0000 */
    IF (PRECISION > 0) THEN
      mask := mask || 'D';
      FOR i IN 1 .. PRECISION LOOP
        mask := mask || '0';
      END LOOP;
    END IF;

    /* Add the FM mask element to keep from getting leading spaces */
    mask := 'FM' || mask;

    /* Add the appropriate sign */

    /*
    Per bug 2708367, according to SQL Reference Manual. Chapter 2:"Basic
    Elements of Oracle SQL", in the table of "Number Format Elements", MI means
    "returns negative value with a trailing minus sign (-) and returns positive
    value with a trailing blank".  Therefore, the returned format mask is
    incorrect if the profile options CURRENCY:NEGATIVE_FORMAT is set to XXX- and
    CURRENCY:POSITIVE_FORMAT is set to XXX+.
    */

    IF (x_neg_format = 'XXX-' AND x_pos_format = 'XXX+') THEN
      mask := mask || 'S';
    ELSIF (x_neg_format = 'XXX-' AND x_pos_format <> 'XXX+') THEN
      mask := mask || 'MI';
    ELSIF (x_neg_format = '<XXX>') THEN
      mask := mask || 'PR';
    ELSIF (x_neg_format = '(XXX)') THEN
      -- Bug 5529158: This is being made
      mask := mask || 'PT'; -- consistent with FNDSQF.pld
    ELSIF (x_pos_format = '+XXX') THEN
      mask := 'S' || mask;
    END IF;

    format_mask := mask;

  END safe_build_format_mask;

  FUNCTION safe_get_format_mask(currency_code         IN VARCHAR2,
                                field_length          IN NUMBER,
                                p_thousands_separator VARCHAR2 DEFAULT 'N',
                                p_percision           IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    return_mask   VARCHAR2(100);
    PRECISION     NUMBER; /* number of digits to right of decimal*/
    ext_precision NUMBER; /* precision where more precision is needed*/
    min_acct_unit NUMBER; /* minimum value by which amt can vary */

  BEGIN

    return_mask := NULL; /* initialize return_mask */

    /* Check whether field_length exceeds maximum length of return_mask
    or if currency_code is NULL. */
    IF (field_length > 100) OR (currency_code IS NULL) THEN
      RETURN return_mask;
    END IF;

    /* Get the precision information for a currency code */
    fnd_currency.get_info(currency_code,
                          PRECISION,
                          ext_precision,
                          min_acct_unit);

    /*** po_wf_req_notification.format_currency_no_precesion ***/

    /* Create the format mask for the given currency value */
    safe_build_format_mask(format_mask           => return_mask,
                           field_length          => field_length,
                           PRECISION             => nvl(p_percision,
                                                        PRECISION),
                           min_acct_unit         => min_acct_unit,
                           disp_grp_sep          => NULL,
                           neg_format            => NULL,
                           pos_format            => NULL,
                           p_thousands_separator => p_thousands_separator);

    RETURN return_mask;

  END safe_get_format_mask;

  FUNCTION format_mask(p_num_value           IN NUMBER,
                       currency_code         IN VARCHAR2,
                       field_length          IN NUMBER,
                       p_thousands_separator IN VARCHAR2 DEFAULT 'N',
                       p_percision           IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS

  BEGIN

    RETURN to_char(p_num_value,
                   safe_get_format_mask(currency_code,
                                        field_length,
                                        p_thousands_separator,
                                        p_percision));

  END format_mask;

  FUNCTION get_flex_value_description(p_flex_value_id IN VARCHAR)
    RETURN VARCHAR2 IS

    v_flex_description VARCHAR2(240);

  BEGIN
    SELECT ffv.description
      INTO v_flex_description
      FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
     WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
       AND fvs.flex_value_set_name = 'XXGL_DEPARTMENT_SEG'
       AND ffv.flex_value = p_flex_value_id;

    RETURN v_flex_description;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_flex_value_description;

  --created by daniel katz on 17-nov-09 to get dff description according to value set id and value
  FUNCTION get_dff_value_description(p_dff_value_set_id IN NUMBER,
                                     p_dff_value        IN VARCHAR)
    RETURN VARCHAR2 IS

    v_dff_description VARCHAR2(240);

  BEGIN
    SELECT ffv.description
      INTO v_dff_description
      FROM fnd_flex_values_vl ffv
     WHERE ffv.flex_value_set_id = p_dff_value_set_id
       AND ffv.flex_value = p_dff_value;

    RETURN v_dff_description;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_dff_value_description;

  --------------------------------------------------------------------
  --  name:            get_flex_Project_description
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2010
  --------------------------------------------------------------------
  --  purpose :        Function that return the project desc
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_flex_project_description(p_flex_value_id IN VARCHAR)
    RETURN VARCHAR2 IS

    v_flex_description VARCHAR2(240);

  BEGIN
    SELECT ffv.description
      INTO v_flex_description
      FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
     WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
       AND fvs.flex_value_set_name = 'XXGL_PROJECT_SEG'
       AND ffv.flex_value = p_flex_value_id;

    RETURN v_flex_description;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_flex_project_description;

  FUNCTION set_session_cc_id_from_seg(p_cc_segments IN VARCHAR2)
    RETURN VARCHAR2 IS

    l_code_combination_id NUMBER;
  BEGIN

    BEGIN

      SELECT code_combination_id
        INTO l_code_combination_id
        FROM gl_summary_templates gst, gl_code_combinations_kfv gcc
       WHERE gst.template_id = gcc.template_id
         AND gst.ledger_id = fnd_profile.value('GL_SET_OF_BKS_ID')
         AND gcc.concatenated_segments = p_cc_segments;

    EXCEPTION
      WHEN no_data_found THEN

        SELECT code_combination_id
          INTO l_code_combination_id
          FROM gl_code_combinations_kfv gcc
         WHERE gcc.concatenated_segments = p_cc_segments;

    END;

    g_session_cc_id := l_code_combination_id;

    RETURN '1';

  EXCEPTION
    WHEN OTHERS THEN
      RETURN '0';
  END set_session_cc_id_from_seg;

  FUNCTION get_session_cc_id_from_seg RETURN NUMBER IS
  BEGIN
    RETURN g_session_cc_id;
  END get_session_cc_id_from_seg;
  --------------------------------------------------------------------
  --  name:            replace_cc_segment
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   15/01/2014
  --------------------------------------------------------------------
  --  purpose :        Function to support replacing location segment by subledger accoutning
  --------------------------------------------------------------------
  FUNCTION replace_cc_segment(p_inv_dist_id NUMBER, p_segemt VARCHAR2)
    RETURN VARCHAR2 IS
    l_ret_segemt gl_code_combinations_kfv.concatenated_segments%TYPE;

  BEGIN
    SELECT CASE upper(p_segemt)
             WHEN 'SEGMENT1' THEN
              gcc.segment1
             WHEN 'SEGMENT2' THEN
              gcc.segment2
             WHEN 'SEGMENT3' THEN
              gcc.segment3
             WHEN 'SEGMENT4' THEN
              gcc.segment4
             WHEN 'SEGMENT5' THEN
              gcc.segment5
             WHEN 'SEGMENT6' THEN
              gcc.segment6
             WHEN 'SEGMENT7' THEN
              gcc.segment7
             WHEN 'SEGMENT8' THEN
              gcc.segment8
             WHEN 'SEGMENT9' THEN
              gcc.segment9
             WHEN 'SEGMENT10' THEN
              gcc.segment10
             WHEN 'ALL' THEN
              gcc.concatenated_segments
           END CASE
      INTO l_ret_segemt
      FROM xla_distribution_links   d,
           xla_ae_lines             l,
           gl_code_combinations_kfv gcc,
           gl_ledgers               gl
     WHERE d.source_distribution_id_num_1 = p_inv_dist_id
       AND d.application_id = 222
       AND d.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
       AND d.ae_header_id = l.ae_header_id
       AND d.ae_line_num = l.ae_line_num
       AND gl.ledger_id = l.ledger_id
       AND gl.ledger_category_code = 'PRIMARY'
       AND gcc.code_combination_id = l.code_combination_id;
    RETURN l_ret_segemt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END replace_cc_segment;
  -------------------------------------------------------------------
  --  name:            get_cust_location_segment
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   15/01/2014
  --------------------------------------------------------------------
  --  purpose :        Function to get location segment by subledger accoutning
  --------------------------------------------------------------------
  FUNCTION get_cust_location_segment(p_cust_state VARCHAR2,
                                     p_site_seg   VARCHAR2) RETURN VARCHAR2 IS
    l_new_location_seg xla_mapping_set_values.value_constant%TYPE;
  BEGIN

    SELECT xmsv.value_constant
      INTO l_new_location_seg
      FROM xla_mapping_sets_fvl xms, xla_mapping_set_values xmsv
     WHERE xms.mapping_set_code = xmsv.mapping_set_code
       AND xmsv.input_value_constant = p_cust_state
       AND xms.mapping_set_code = 'SSUS LOCATION MAPPING'
       AND SYSDATE BETWEEN xmsv.effective_date_from AND
           nvl(xmsv.effective_date_to, SYSDATE + 1);
    RETURN l_new_location_seg;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_site_seg;

  END;
  -------------------------------------------------------------------
  -- CHG0034796
  --  name:            set_avg_conversion_rate-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   11/03/2015
  --------------------------------------------------------------------
  --  purpose :       Function to set array of AVG conversion rate
  
  --  ver   Date    Creator    Description
  --  1.0  XX/XX/XX  XXXXX     	XXXXXXXXX
  --  1.1  02/09/19  Bellona B. CHG0046386-	Add new conversion rate type - AOP
  --------------------------------------------------------------------
  FUNCTION set_avg_conversion_rate(p_from_period VARCHAR2,
                                   p_to_period   VARCHAR2) RETURN NUMBER IS
    CURSOR c_ledger_currencies IS
      SELECT DISTINCT gl.currency_code
        FROM gl_ledgers gl
       WHERE gl.ledger_category_code = 'PRIMARY'
         AND gl.currency_code != 'USD';
    CURSOR c_rates(p_urrency VARCHAR2) IS
      SELECT SUM(gr.conversion_rate) / COUNT(gr.conversion_rate) rate,
             gp.period_name,
             gr.from_currency
        FROM gl_daily_rates gr,
             gl_periods     gp_start,
             gl_periods     gp_end,
             gl_periods     gp
       WHERE gp_start.period_name = p_from_period
         AND gp_end.period_name = p_to_period
         AND gr.from_currency = p_urrency
         AND gr.to_currency = 'USD'
         AND gr.conversion_date <= trunc(SYSDATE)
         AND gp_start.period_set_name = 'OBJET_CALENDAR'
         AND gp_start.adjustment_period_flag = 'N'
         AND gp_end.period_set_name = 'OBJET_CALENDAR'
         AND gp_end.adjustment_period_flag = 'N'
         AND gp.period_set_name = 'OBJET_CALENDAR'
		 AND gr.conversion_type='Corporate' --added as part of CHG0046386
         AND gp.adjustment_period_flag = 'N'
         AND gr.conversion_date BETWEEN gp.start_date + 1 AND
             gp.end_date + 1
         AND gr.conversion_date BETWEEN gp_start.start_date + 1 AND
             gp_end.end_date + 1
       GROUP BY gp.period_name, gr.from_currency;

  BEGIN

    g_avg_period_rate.delete;
    FOR j IN c_ledger_currencies LOOP
      g_avg_rate.delete;
      FOR i IN c_rates(j.currency_code) LOOP
        g_avg_rate(i.period_name) := i.rate;

      END LOOP;
      g_avg_period_rate(j.currency_code) := g_avg_rate;
    END LOOP;
    RETURN 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;
  -------------------------------------------------------------------
  -- CHG0034796
  --  name:            get_avg_conversion_rate-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   11/03/2015
  --------------------------------------------------------------------
  --  purpose :       Function to get period  AVG conversion rate
  --------------------------------------------------------------------
  FUNCTION get_avg_conversion_rate(p_period        VARCHAR2,
                                   p_func_currency VARCHAR2) RETURN NUMBER IS
    l_avg_rate g_rate_type;
  BEGIN
    IF p_func_currency = 'USD' THEN
      RETURN 1;
    ELSE
      l_avg_rate := g_avg_period_rate(p_func_currency);
    END IF;
    RETURN l_avg_rate(p_period);
  END;
  -------------------------------------------------------------------
  -- CHG0037996
  --  name:            XXINV_GET_ITEM_PL-
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   10/05/2016
  --------------------------------------------------------------------------
  --  purpose :       Function get product line for Misclenious transactions
  -------------------------------------------------------------------------
  -- Ver  Date        Name          Description
  -- 1.2  13/06/17    Yuval Tal       CHG0040954 -modify xxinv_get_item_pl  add accounting event code
  -- 1.3  01/07/18    Ofer Suad       CHG0042557- SLA for Recycling variance  and return from NonAsset Subinventory

  FUNCTION xxinv_get_item_pl(p_event_id NUMBER, p_defualt_cogs NUMBER)
    RETURN NUMBER IS
    l_pl_account         VARCHAR2(25);
    l_flex_seg           fnd_flex_ext.segmentarray;
    l_ok                 BOOLEAN;
    l_return_ccid        NUMBER;
    l_account_type       gl_code_combinations.account_type%TYPE;
    l_chart_of_acc_id    NUMBER;
    l_app_short_name     fnd_application.application_short_name%TYPE;
    num_segments         INTEGER;
    x_return_code        VARCHAR2(250);
    x_err_msg            VARCHAR2(250);
    l_mtt_pl_flag        VARCHAR2(15);
    l_seg_num            NUMBER;
    l_ic_segment         VARCHAR2(15); --CHG0040189
    l_ic_seg_num         NUMBER; --CHG0040189
    l_comp_seg_num       NUMBER; --CHG0040189
    l_trx_source_line_id NUMBER; --CHG0040189

    l_account_seg_num NUMBER; --CHG0042557
    l_account         VARCHAR2(25); --CHG0042557
    l_item            mtl_system_items_b.segment1%Type; --CHG0042557
    l_event_type      xla_events.event_type_code%Type; --CHG0042557
    l_Recycling_flag  VARCHAR2(1); --CHG0042557
    l_subinv_code MTL_SECONDARY_INVENTORIES.Secondary_Inventory_Name%Type;--CHG0042557
    l_org_id number;
    l_trans_type_id number;
    l_trans_id number;
    l_asset_inventory number;


  BEGIN

    SELECT segment5,
           attribute4,
           trx_source_line_id,
           event_type_code,--CHG0042557
           segment1,--CHG0042557
           subinventory_code,--CHG0042557
           organization_id,--CHG0042557
           transaction_type_id,--CHG0042557
           transaction_id--CHG0042557
      INTO l_pl_account,
           l_mtt_pl_flag,
           l_trx_source_line_id, --CHG0040189 move coa to gcc query
           l_event_type,--CHG0042557
           l_item,--CHG0042557
           l_subinv_code,--CHG0042557
           l_org_id,--CHG0042557
           l_trans_type_id,--CHG0042557
           l_trans_id--CHG0042557
      FROM (SELECT gcc.segment5,
                   nvl(mtt.attribute4, 'N') attribute4,
                   mmt.trx_source_line_id trx_source_line_id, --CHG0040189 move coa to gcc query
                   e.event_type_code,
                   mb.segment1,
                   mmt.subinventory_code,mmt.organization_id,
                   mmt.transaction_type_id,
                   mmt.transaction_id
              FROM xla_events                   e,
                   xla_transaction_entities_upg u,
                   mtl_material_transactions    mmt,
                   mtl_system_items_b           mb,
                   gl_code_combinations         gcc,
                   mtl_transaction_types        mtt
             WHERE e.event_id = p_event_id
               AND u.entity_id = e.entity_id
               AND mmt.transaction_id = u.source_id_int_1
               AND mb.inventory_item_id = mmt.inventory_item_id
               AND mb.organization_id = mmt.organization_id
               AND gcc.code_combination_id = mb.cost_of_sales_account
               AND mtt.transaction_type_id = mmt.transaction_type_id
               AND u.entity_code = 'MTL_ACCOUNTING_EVENTS' -- CHG0040954-  Add Accounting event
            UNION ALL
            SELECT gcc.segment5, 'Y', NULL, e.event_type_code, mb.segment1,null,null,null,null
              FROM xla_events                   e,
                   xla_transaction_entities_upg u,
                   wip_transactions             wt,
                   wip_entities                 we,
                   mtl_system_items_b           mb,
                   gl_code_combinations         gcc
             WHERE e.event_id = p_event_id
               AND u.entity_id = e.entity_id
               AND wt.transaction_id = u.source_id_int_1
               AND we.wip_entity_id = wt.wip_entity_id
               AND mb.inventory_item_id = we.primary_item_id
               AND mb.organization_id = wt.organization_id
               AND gcc.code_combination_id = mb.cost_of_sales_account
               AND u.entity_code = 'WIP_ACCOUNTING_EVENTS' -- CHG0040954-  Add Accounting event
            );

    SELECT gcc.account_type,
           gcc.chart_of_accounts_id, --CHG0040189 move coa to gcc query
           gcc.segment3--CHG0042557
      INTO l_account_type,
           l_chart_of_acc_id, --CHG0040189 move coa to gcc query
           l_account--CHG0042557
      FROM gl_code_combinations gcc
     WHERE gcc.code_combination_id = p_defualt_cogs;

    SELECT fap.application_short_name
      INTO l_app_short_name
      FROM fnd_application        fap,
           fnd_id_flexs           fif,
           fnd_id_flex_structures fifs
     WHERE fif.application_id = fap.application_id
       AND fif.id_flex_code = 'GL#'
       AND fifs.application_id = fif.application_id
       AND fifs.id_flex_code = fif.id_flex_code
       AND fifs.id_flex_num = l_chart_of_acc_id;

    l_ok := fnd_flex_ext.get_segments(l_app_short_name,
                                      'GL#',
                                      l_chart_of_acc_id,
                                      p_defualt_cogs,
                                      num_segments,
                                      l_flex_seg);
    SELECT fif.segment_num
      INTO l_seg_num
      FROM fnd_id_flex_segments_vl fif
     WHERE fif.application_id = 101
       AND fif.id_flex_num = l_chart_of_acc_id
       AND fif.id_flex_code = 'GL#'
       AND upper(fif.segment_name) IN ('PRODUCT', 'PRODUCT LINE');
    --CHG0040189 get Intercomapny Segment
    SELECT fif.segment_num
      INTO l_ic_seg_num
      FROM fnd_id_flex_segments_vl fif
     WHERE fif.application_id = 101
       AND fif.id_flex_num = l_chart_of_acc_id
       AND fif.id_flex_code = 'GL#'
       AND upper(fif.segment_name) = 'INTERCOMPANY';

    SELECT fif.segment_num
      INTO l_comp_seg_num
      FROM fnd_id_flex_segments_vl fif
     WHERE fif.application_id = 101
       AND fif.id_flex_num = l_chart_of_acc_id
       AND fif.id_flex_code = 'GL#'
       AND upper(fif.segment_name) = 'COMPANY';

    BEGIN
      SELECT CONSTANT
        INTO l_flex_seg(l_ic_seg_num)
        FROM oe_order_lines_all          ol,
             ra_account_defaults_all     rad,
             ra_account_default_segments rads
       WHERE ol.line_id = l_trx_source_line_id
         AND rad.gl_default_id = rads.gl_default_id
         AND rad.org_id = ol.org_id
         AND TYPE = 'REV'
         AND segment_num = 1
         AND CONSTANT <> l_flex_seg(l_comp_seg_num);

    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    -- end CHG0040189 get Intercomapny Segment

    l_flex_seg(l_seg_num) := l_pl_account;
    --CHG0042557
    l_Recycling_flag := 'N';
    begin
      select 'Y'
        into l_Recycling_flag
        from Fnd_Flex_Value_Sets ffvs, FND_FLEX_VALUES_VL ffvv
       where ffvs.flex_value_set_name = 'XXINV_RECYCLING_ITEMS'
         and ffvs.flex_value_set_id = ffvv.FLEX_VALUE_SET_ID
         and ffvv.ENABLED_FLAG = 'Y'
         and ffvv.FLEX_VALUE = l_item
         and l_event_type = 'JOB_CLOSE_VARIANCE';

      SELECT fif.segment_num
        INTO l_account_seg_num
        FROM fnd_id_flex_segments_vl fif
       WHERE fif.application_id = 101
         AND fif.id_flex_num = l_chart_of_acc_id
         AND fif.id_flex_code = 'GL#'
         AND upper(fif.segment_name) = 'ACCOUNT';

      select flv.MEANING
        into l_flex_seg(l_account_seg_num)
        from FND_LOOKUP_VALUES_VL flv
       where flv.LOOKUP_TYPE = 'XXINV_RECYCLING_SLA_ACCOUTS'
       and flv.ENABLED_FLAG='Y'
         and flv.LOOKUP_CODE = l_account;
    exception
      when no_data_found then
        null;
    end;
  ---   Internal return from NA
  if l_trans_type_id=fnd_profile.VALUE('XXINV_INTENAL_SHIP_TRANS_ID')  then ---- Profile
  begin

  select mts.expense_account
  into l_asset_inventory
  from mtl_material_transactions     mmt,
       org_organization_definitions  odf,
       oe_order_lines_all            oll,
       oe_order_headers_all          h,
       MTL_INTERCOMPANY_PARAMETERS_V msnv,
       MTL_SECONDARY_INVENTORIES     mts
 where mmt.transaction_id =l_trans_id
   and odf.ORGANIZATION_ID = mmt.organization_id
   and oll.line_id = mmt.trx_source_line_id
   and h.header_id = oll.header_id
   and msnv.SHIP_ORGANIZATION_ID = odf.OPERATING_UNIT
   and h.sold_to_org_id = msnv.CUSTOMER_ID
   and mts.secondary_inventory_name = mmt.subinventory_code
   and mts.organization_id = odf.ORGANIZATION_ID
   and mts.asset_inventory = 2;


/*select mts.expense_account
into l_asset_inventory
  from MTL_SECONDARY_INVENTORIES mts
 where mts.secondary_inventory_name = l_subinv_code
   and mts.organization_id = l_org_id
   and mts.asset_inventory=2;*/

   select mta.reference_account
   into l_return_ccid
   from mtl_transaction_accounts mta
   where mta.transaction_id=l_trans_id
   and mta.organization_id=l_org_id
   and mta.reference_account<> l_asset_inventory;

    l_ok := fnd_flex_ext.get_segments(l_app_short_name,
                                      'GL#',
                                      l_chart_of_acc_id,
                                      l_return_ccid,
                                      num_segments,
                                      l_flex_seg);


  exception
    when others then
      null;
  end;
  end if;
   --   end CHG0042557

    IF l_ok <> FALSE THEN
      xxgl_utils_pkg.get_and_create_account(l_flex_seg,
                                            l_chart_of_acc_id,
                                            l_app_short_name,
                                            l_return_ccid,
                                            x_return_code,
                                            x_err_msg);
    END IF;

    IF l_ok = FALSE OR x_return_code != fnd_api.g_ret_sts_success OR
       l_account_type <> 'E' OR l_mtt_pl_flag <> 'Y' THEN
      --  Only for expense Account
      l_return_ccid := p_defualt_cogs;
    END IF;
    RETURN l_return_ccid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_defualt_cogs;

  END xxinv_get_item_pl;

  -------------------------------------------------------------------
  -- CHG0040189
  --  name:            XXAP_GET_ITEM_PL-

  --  Revision:        1.4
  --  creation date:   01/03/2017
  --------------------------------------------------------------------------
  --  purpose :       Function get product line for Payables transactions
  -------------------------------------------------------------------------
  FUNCTION xxap_get_item_pl(p_inv_dist_id NUMBER, p_defualt_account NUMBER)
    RETURN NUMBER IS
    l_pl_account            VARCHAR2(25);
    l_flex_seg              fnd_flex_ext.segmentarray;
    l_ok                    BOOLEAN;
    l_return_ccid           NUMBER;
    l_account_type          gl_code_combinations.account_type%TYPE;
    l_chart_of_acc_id       NUMBER;
    l_app_short_name        fnd_application.application_short_name%TYPE;
    num_segments            INTEGER;
    x_return_code           VARCHAR2(250);
    x_err_msg               VARCHAR2(250);
    l_mtt_pl_flag           VARCHAR2(15);
    l_seg_num               NUMBER;
    l_line_type_lookup_code VARCHAR2(250);
    l_base_amount           NUMBER;
    l_defualt_account       NUMBER;

    l_destination_type_code po_distributions_all.destination_type_code%TYPE;
  BEGIN
    l_defualt_account := p_defualt_account;

    SELECT gcc.segment5,
           aid.line_type_lookup_code,
           aid.base_amount,
           pda.destination_type_code
      INTO l_pl_account,
           l_line_type_lookup_code,
           l_base_amount,
           l_destination_type_code
      FROM ap_invoice_distributions_all aid,
           po_distributions_all         pda,
           po_lines_all                 pll,
           mtl_system_items_b           mb,
           gl_code_combinations         gcc
     WHERE aid.invoice_distribution_id = p_inv_dist_id
       AND pda.po_distribution_id = aid.po_distribution_id
       AND pll.po_line_id = pda.po_line_id
       AND mb.inventory_item_id = pll.item_id
       AND mb.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND gcc.code_combination_id = mb.cost_of_sales_account;

    IF l_line_type_lookup_code = 'ERV' AND
       l_destination_type_code <> 'EXPENSE' THEN
      IF l_base_amount > 0 THEN
        SELECT rate_var_gain_ccid
          INTO l_defualt_account
          FROM financials_system_parameters;

      ELSE
        SELECT rate_var_loss_ccid
          INTO l_defualt_account
          FROM financials_system_parameters;
      END IF;

    END IF;

    SELECT gcc.account_type, gcc.chart_of_accounts_id
      INTO l_account_type, l_chart_of_acc_id
      FROM gl_code_combinations gcc
     WHERE gcc.code_combination_id = l_defualt_account;

    SELECT fap.application_short_name
      INTO l_app_short_name
      FROM fnd_application        fap,
           fnd_id_flexs           fif,
           fnd_id_flex_structures fifs
     WHERE fif.application_id = fap.application_id
       AND fif.id_flex_code = 'GL#'
       AND fifs.application_id = fif.application_id
       AND fifs.id_flex_code = fif.id_flex_code
       AND fifs.id_flex_num = l_chart_of_acc_id;

    l_ok := fnd_flex_ext.get_segments(l_app_short_name,
                                      'GL#',
                                      l_chart_of_acc_id,
                                      l_defualt_account,
                                      num_segments,
                                      l_flex_seg);
    SELECT fif.segment_num
      INTO l_seg_num
      FROM fnd_id_flex_segments_vl fif
     WHERE fif.application_id = 101
       AND fif.id_flex_num = l_chart_of_acc_id
       AND fif.id_flex_code = 'GL#'
       AND upper(fif.segment_name) IN ('PRODUCT', 'PRODUCT LINE');

    l_flex_seg(l_seg_num) := l_pl_account;

    IF l_ok <> FALSE THEN
      xxgl_utils_pkg.get_and_create_account(l_flex_seg,
                                            l_chart_of_acc_id,
                                            l_app_short_name,
                                            l_return_ccid,
                                            x_return_code,
                                            x_err_msg);
    END IF;

    IF l_ok = FALSE OR x_return_code != fnd_api.g_ret_sts_success OR
       l_account_type <> 'E' THEN
      --  Only for expense Account
      l_return_ccid := l_defualt_account;
    END IF;
    RETURN l_return_ccid;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_defualt_account;
  END;

END xxgl_utils_pkg;
/