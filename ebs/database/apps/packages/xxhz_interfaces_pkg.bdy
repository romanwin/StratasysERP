create or replace package body xxhz_interfaces_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0031514 Customer support SF --> Oracle interfaces project
  --  name:               XXHZ_INTERFACES_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        Handle all HZ interfaces
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   13/10/2014    Dalit A. RAviv  CHG0033449 SF Creating account relationship
  --                                      add function - Handle_SF_account_relation
  --  1.2   13/01/2015    Michal Tzvik    CHG0033182:
  --                                      New function:      main_process_locations
  --                                      Update procedures: set_apps_initialize, interface_status, upd_success_log, validate_locations
  --  1.3  12/02/2015     Dalit A. Raviv  CHG0034398 - procedure handle_sf_account_relation
  --                                      correct account relationship between owner and end-customer
  --                                      create_cust_site_use_api, handle_sf_account_relation
  --  1.4  03/03/2015     Dalit A. Raviv  CHG0033183 - procedures fill_missing_site_info, validate_sites,
  --                                      add handle for upload with numbers/names and not Id's
  --                                      modifications to update_cust_account_site_api, create_cust_site_use_api
  --                                      new procedure handle_sites_uploads
  --  1.5  20/05/2015     Michal Tzvik    CHG0034610- Upload Customer credit data from Atradius
  --                                      Update:
  --                                      PROCEDURE validate_accounts - Run different validations for new or update accounts
  --                                      PROCEDURE create_account_api - Add fields
  --                                      PROCEDURE update_account_api - bug fix
  --
  --                                      New:
  --                                      PROCEDURE update_cust_profile_amt_api
  --
  --  1.6  05/05/2015    Dalit A. Raviv   CHG0035283 - Inactivate Customer Sites via existing API
  --                                      new procedure set_Inactivate_Sites
  --  1.7  12/10/2015    Diptasurjya      CHG0036474 - Add customer account mass update API to load data from csv
  --                                      to TCA tables for ACCOUNT, PARTY and Classification update/create
  --  1.8 11/10/2018     Suad Ofer        CHG0043940 Add fileds to Customer update
  --  1.9 04.03.19       Lingaraj         INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --  2.0 23/07/2019     Ofer Suad        CHG0046162 - Mass create of customer site fail – missing party site id
  --------------------------------------------------------------------

  g_class_code   VARCHAR2(30) := NULL;
  g_user_id      NUMBER := NULL;
  g_resp_id      NUMBER := NULL;
  g_resp_appl_id NUMBER := NULL;
  -- 1.4 03/03/2015 Dalit A. Raviv CHG0033183
  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id; --31423801 --
  g_email_address VARCHAR2(150) := NULL;

  TYPE t_location_rec IS RECORD(
    address1          VARCHAR2(240),
    address2          VARCHAR2(240),
    address3          VARCHAR2(240),
    address4          VARCHAR2(240),
    state             VARCHAR2(60),
    postal_code       VARCHAR2(60),
    county            VARCHAR2(60),
    country           VARCHAR2(60), -- fnd_territories_tl.territory_code (territory_short_name)
    city              VARCHAR2(60),
    created_by_module VARCHAR2(150),
    entity            VARCHAR2(20),
    interface_id      NUMBER);

  -- 1.4 03/03/2015      Dalit A. Raviv CHG0033183
  -- 1.5   12/04/2015    Diptasurjya     CHG0036474 - Added new parameter p_interface_entity
  --                      Chatterjee      to handle different report structure for account
  PROCEDURE enter_report_data(p_interface_id     IN NUMBER,
		      p_interface_entity IN VARCHAR2 DEFAULT NULL);


  --------------------------------------------------------------------
  --  name:               is_number
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/31/2015
  --  Description:        CHG0036474 - check if a value is number
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/31/2015    Diptasurjya Chatterjee  CHG0036474 - initial build
  --------------------------------------------------------------------
  FUNCTION is_number (p_string IN VARCHAR2)
     RETURN INT
  IS
     v_new_num NUMBER;
  BEGIN
     v_new_num := TO_NUMBER(p_string);
     RETURN 1;
  EXCEPTION
  WHEN VALUE_ERROR THEN
     RETURN 0;
  END is_number;

  --------------------------------------------------------------------
  --  name:               validate_value_with_valueset
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/31/2015
  --  Description:        CHG0036474 - This procedure will validate a passed value against
  --                      passed valueset id.
  --                      This procedure will validate for table and independent
  --                      value sets only, for other valueset types please add
  --                      logic here or build your own validation logic
  --                      If a match is found in the value set, the storage
  --                      value i.e. the value to be saved in base table
  --                      will be sent as OUT parameter, otherwise error status
  --                      along with status message NO_DATA_FOUND will be sent as OUT parameter
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/31/2015    Diptasurjya Chatterjee  CHG0036474 - initial build
  --------------------------------------------------------------------
  procedure validate_value_with_valueset(p_value_set_id IN NUMBER,
                                         p_vset_validation_type IN VARCHAR2,
                                         p_value IN varchar2,
                                         x_status OUT varchar2,
                                         x_status_message OUT varchar2,
                                         x_storage_value OUT varchar2) IS
    l_storage_value varchar2(2000);
    l_additional_where varchar2(2000);

    l_value_column_name varchar2(240);
    l_value_col_type varchar2(1);
    l_id_column_name varchar2(240);
    l_id_col_type varchar2(1);
    l_meaning_column_name varchar2(240);
    l_meaning_col_type varchar2(1);

    l_select VARCHAR2(4000);
    l_mapping_code VARCHAR2(2000);
    l_success NUMBER;

    l_vset_value varchar2(2000);
    l_vset_value_id varchar2(2000);
  begin
    if p_vset_validation_type = 'I' then
      l_value_column_name := 'FLEX_VALUE';
      l_value_col_type := 'C';
      l_id_column_name := 'FLEX_VALUE';
      l_id_col_type := 'C';
      l_meaning_column_name := 'DESCRIPTION';
      l_meaning_col_type := 'C';
    else
      select value_column_name,
             value_column_type,
             id_column_name,
             id_column_type,
             meaning_column_name,
             meaning_column_type
        into l_value_column_name,l_value_col_type,
             l_id_column_name,l_id_col_type,
             l_meaning_column_name,l_meaning_col_type
        from fnd_flex_validation_tables
       where flex_value_set_id = p_value_set_id;


    end if;


    l_additional_where := l_additional_where||'AND (';
    if l_value_col_type in ('C','V') then
      l_additional_where := l_additional_where||l_value_column_name||' = '''||p_value||'''';
    elsif l_value_col_type = 'N' then
      l_additional_where := l_additional_where||l_value_column_name||' = '||p_value;
    end if;

    if l_meaning_column_name is not null then
      l_additional_where := l_additional_where||' OR ';
      if l_meaning_col_type in ('C','V') then
        l_additional_where := l_additional_where||l_meaning_column_name||' = '''||p_value||'''';
      elsif l_meaning_col_type = 'N' then
        l_additional_where := l_additional_where||l_meaning_column_name||' = '||p_value;
      end if;
    end if;

    if l_id_column_name is not null and is_number(p_value) = 1 then
      l_additional_where := l_additional_where||' OR ';
      if l_id_col_type in ('C','V') then
        l_additional_where := l_additional_where||l_id_column_name||' = '''||p_value||'''';
      elsif l_id_col_type = 'N' then
        l_additional_where := l_additional_where||l_id_column_name||' = '||p_value;
      end if;
    end if;

    l_additional_where := l_additional_where||')';

    if p_vset_validation_type = 'F' then
      fnd_flex_val_api.get_table_vset_select(p_value_set_id => p_value_set_id,
                                             p_inc_user_where_clause => 'Y',
                                             p_inc_meaning_col => 'N',
                                             x_select => l_select,
                                             x_mapping_code => l_mapping_code,
                                             x_success => l_success);
    elsif p_vset_validation_type = 'I' then
      fnd_flex_val_api.get_independent_vset_select(p_value_set_id => p_value_set_id,
                                         --p_inc_user_where_clause => 'Y',
                                         p_inc_meaning_col => 'N',
                                         x_select => l_select,
                                         x_mapping_code => l_mapping_code,
                                         x_success => l_success);
    end if;

    if l_success = 0 then
      l_select := l_select||chr(10)||l_additional_where;

      fnd_file.put_line(fnd_file.LOG,l_select);

      begin
        if l_id_column_name is not null then
          EXECUTE IMMEDIATE l_select INTO l_vset_value,l_vset_value_id;
        else
          EXECUTE IMMEDIATE l_select INTO l_vset_value;
          l_vset_value_id := l_vset_value;
        end if;

        x_storage_value := l_vset_value_id;
        x_status := '0';
        x_status_message := null;
      exception when no_data_found then
        x_storage_value := null;
        x_status := '1';
        x_status_message := 'NO_DATA_FOUND';
      end;
    else
      x_status := '1';
      x_status_message := 'Error while validating DFF values. validate_value_with_valueset: form select query';
    end if;
  exception when others then
    x_status := '1';
    x_status_message := 'Unexpected error while validating DFF values. validate_value_with_valueset: '||sqlerrm;
  end validate_value_with_valueset;


  --------------------------------------------------------------------
  --  name:               validate_dff_values
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/31/2015
  --  Description:        CHG0036474 - This is a generic procedure and can be used for validating any DFF segment values
  --                      Validate DFF segments values against their assigned value sets.
  --                      If assigned value set is table based or independent this procedure
  --                      will call validate_value_with_valueset to generate value set query dynamically
  --                      and validate passed segment value against the query
  --                      For Other value sets the value passed will be validated
  --                      against other attributes of value set like data format, length,
  --                      precision, max and min values etc
  --                      In case no value set is assigned, value will be passed as-is
  --                      Date type values will be converted to canonical form
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/31/2015    Diptasurjya Chatterjee  CHG0036474 - initial build
  --------------------------------------------------------------------
  procedure validate_dff_values (p_dff_name IN varchar2,
                                 p_dff_column IN varchar2,
                                 p_dff_context_code IN varchar2,
                                 p_segment_value IN varchar2,
                                 x_status OUT varchar2,
                                 x_status_message OUT varchar2,
                                 x_storage_value OUT varchar2) IS
    l_dff_name varchar2(200);
    l_dff_title varchar2(240);
    l_segment_enabled varchar2(1);
    l_col_user_name varchar2(240);
    l_value_set_name VARCHAR2(60);
    l_value_set_id number;
    l_format_type varchar2(1);
    l_max_size number;
    l_num_precision number;
    l_alpha_flag varchar2(1);
    l_uppercase_flag varchar2(1);
    l_min_val number;
    l_max_value number;
    l_numeric_mode varchar2(1);
    l_validation_type varchar2(1);

    l_storage_value varchar2(2000);
    l_display_value varchar2(2000);
    l_success boolean;
  begin
    /*if p_dff_entity = 'PARTY' then
      l_dff_name := 'HZ_PARTIES';
    elsif p_dff_entity = 'ACCOUNT' then
      l_dff_name := 'RA_CUSTOMERS_HZ';
    end if;*/
    select fdcr.TITLE
      into l_dff_title
      from fnd_descriptive_flexs_vl fdcr
     where fdcr.DESCRIPTIVE_FLEXFIELD_NAME=p_dff_name;

    begin
      select *
        into l_segment_enabled,l_col_user_name,l_value_set_name,l_value_set_id,l_format_type,l_max_size,l_num_precision,
             l_alpha_flag,l_uppercase_flag,l_min_val,l_max_value,l_numeric_mode,l_validation_type
        from (select a.enabled_flag,a.FORM_LEFT_PROMPT,
             b.flex_value_set_name,
             b.flex_value_set_id,
             b.format_type,
             b.maximum_size,
             b.number_precision,
             b.alphanumeric_allowed_flag,
             b.uppercase_only_flag,
             b.minimum_value,
             b.maximum_value,
             b.numeric_mode_enabled_flag,
             b.validation_type
        from fnd_descr_flex_col_usage_vl a,
             fnd_flex_value_sets b
       where a.descriptive_flexfield_name = p_dff_name
         and a.application_column_name = p_dff_column
         and a.descriptive_flex_context_code = 'Global Data Elements'
         and a.flex_value_set_id = b.flex_value_set_id
      union
      select a.enabled_flag,a.FORM_LEFT_PROMPT,
             b.flex_value_set_name,
             b.flex_value_set_id,
             b.format_type,
             b.maximum_size,
             b.number_precision,
             b.alphanumeric_allowed_flag,
             b.uppercase_only_flag,
             b.minimum_value,
             b.maximum_value,
             b.numeric_mode_enabled_flag,
             b.validation_type
        from fnd_descr_flex_col_usage_vl a,
             fnd_flex_value_sets b
       where a.descriptive_flexfield_name = p_dff_name
         and a.application_column_name = p_dff_column
         and a.descriptive_flex_context_code = p_dff_context_code
         and a.flex_value_set_id = b.flex_value_set_id);
    exception when no_data_found then
      x_status := '0';
      x_status_message := null;
      x_storage_value := p_segment_value;
      return;
    end;

    if l_segment_enabled <> 'Y' then
      x_status := '1';
      x_status_message := 'DFF = '||l_dff_title||', Segment = '||l_col_user_name||' ('||p_dff_column||'), is disabled.';
      return;
    else
      fnd_file.PUT_LINE(fnd_file.LOG,'Segment: '||p_dff_column||' Validation: '||l_validation_type);
      if l_validation_type in ('F','I') then
        fnd_file.PUT_LINE(fnd_file.LOG,'Before valueset validation');
        validate_value_with_valueset(p_value_set_id         => l_value_set_id,
                                     p_vset_validation_type => l_validation_type,
                                     p_value                => p_segment_value,
                                     x_status               => x_status,
                                     x_status_message       => x_status_message,
                                     x_storage_value        => x_storage_value);
        if x_status = '1' and x_status_message = 'NO_DATA_FOUND' then
          x_status := '1';
          x_status_message := 'DFF = '||l_dff_title||', Segment = '||l_col_user_name||' ('||p_dff_column||'), Value = '''||p_segment_value||''' is not valid';
        end if;
      else
        fnd_flex_val_util.validate_value(p_value             => p_segment_value,
                                         --p_is_displayed      => ,
                                         p_vset_name         => l_value_set_name,
                                         p_vset_format       => l_format_type,
                                         p_max_length        => l_max_size,
                                         p_precision         => l_num_precision,
                                         p_alpha_allowed     => l_alpha_flag,
                                         p_uppercase_only    => l_uppercase_flag,
                                         p_zero_fill         => l_numeric_mode,
                                         p_min_value         => l_min_val,
                                         p_max_value         => l_max_value,
                                         x_storage_value     => l_storage_value,
                                         x_display_value     => l_display_value,
                                         x_success           => l_success);
        if l_success then
          x_status := '0';
          x_status_message := null;
          fnd_file.PUT_LINE(fnd_file.LOG,'Format: '||l_format_type);
          if l_format_type in ('D','T','X','Z','Y','I') then
            x_storage_value := fnd_date.date_to_canonical(to_date(p_segment_value,'dd-MON-rrrr'));
          else
            x_storage_value := p_segment_value;
          end if;
        else
          x_status := '1';
          if l_format_type in ('D','T','X','Z','Y','I') then
            x_status_message := 'DFF = '||l_dff_title||', Segment = '||l_col_user_name||' ('||p_dff_column||'), Value = '''||p_segment_value||''' should be of format DD-MON-YYYY';
          else
            x_status_message := 'DFF = '||l_dff_title||', Segment = '||l_col_user_name||' ('||p_dff_column||'), Value = '''||p_segment_value||''' is not valid';
          end if;
        end if;
      end if;
    end if;
  exception when others then
    x_status := '1';
    x_status_message := 'Unexpected error occurred while validating DFF ('||l_dff_title||') segment values';
  end validate_dff_values;

  --------------------------------------------------------------------
  --  name:               validate_accounts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        validate required fields at account level
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   21/04/2015    Michal Tzvik    CHG0034610 - Run different validations for new or update accounts
  --  1.2   12/04/2015    Diptasurjya     CHG0036474 - Added new validations for
  --                      Chatterjee      customer account update cases
  --------------------------------------------------------------------
  --Lookup - XXSERVICE_COUNTRIES_SECURITY
  PROCEDURE validate_accounts(errbuf    OUT VARCHAR2,
		      retcode   OUT VARCHAR2,
		      p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    l_message VARCHAR2(500) := NULL;

    l_sales_channel_code     VARCHAR2(80) := NULL;
    l_customer_category_code VARCHAR2(80) := NULL;
    l_pricelist_id           NUMBER := NULL;
    l_payterm_id             NUMBER := NULL;

    l_party_dff_name  varchar2(240) := 'HZ_PARTIES';
    l_account_dff_name varchar2(240) := 'RA_CUSTOMERS_HZ';
    l_profile_amt_dff_name varchar2(240) := 'AR_CUSTOMER_PROFILE_AMOUNTS_HZ';

    l_status varchar2(1);
    l_status_message varchar2(2000);
    l_storage_value varchar(2000);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- TO ADD HANDLE WITH MESSAGES

    IF p_acc_rec.cust_account_id IS NULL THEN
      --21/04/2015    Michal Tzvik    CHG0034610
      -- check sales_chanel_code
      IF p_acc_rec.sales_channel_code IS NULL THEN
        IF l_message IS NULL THEN
          l_message := 'Missing Sales Channel';
        ELSE
          l_message := l_message || ', Missing Sales Channel';
        END IF;
        retcode := 1;

        -- CUSTOMER, DISTRIBUTOR, END CUSTOMER
      END IF;

      IF p_acc_rec.category_code IS NULL THEN
        IF l_message IS NULL THEN
          l_message := 'Missing Category Code';
        ELSE
          l_message := l_message || ', Missing Category Code';
        END IF;
        retcode := 1;
        -- DIRECT, INDIRECT
      END IF;

      IF p_acc_rec.industry IS NULL THEN
        IF l_message IS NULL THEN
          l_message := 'Missing Industry info';
        ELSE
          l_message := l_message || ', Missing Industry info';
        END IF;
        retcode := 1;
      ELSE
        BEGIN
          SELECT lookup_code
          INTO   g_class_code
          FROM   ar_lookups
          WHERE  lookup_type = 'Objet Business Type'
          AND    upper(description) =
	     upper(ltrim(rtrim(p_acc_rec.industry)));
        EXCEPTION
          WHEN OTHERS THEN
	IF l_message IS NULL THEN
	  l_message := 'Industry info is incorrect';
	ELSE
	  l_message := l_message || ', Industry info is incorrect';
	END IF;
	g_class_code := NULL;
	retcode      := 1;
        END;
      END IF;

      IF p_acc_rec.party_attribute3 IS NULL THEN
        IF l_message IS NULL THEN
          l_message := 'Missing Operating Unit (org_id att3)';
        ELSE
          l_message := l_message ||
	           ', Missing Operating Unit (org_id att3)';
        END IF;
        retcode := 1;
      END IF;

      errbuf := l_message;
      /* CHG0036474 - Dipta - Change starts*/
    ELSE
      /* Industry validation*/
      IF p_acc_rec.industry IS NOT NULL THEN
        BEGIN
          SELECT lookup_code
          INTO   g_class_code
          FROM   ar_lookups
          WHERE  lookup_type = 'Objet Business Type'
          AND    upper(description) =
	     upper(ltrim(rtrim(p_acc_rec.industry)));
        EXCEPTION
          WHEN OTHERS THEN
	IF l_message IS NULL THEN
	  l_message := 'Industry info is incorrect';
	ELSE
	  l_message := l_message || ', Industry info is incorrect';
	END IF;
	g_class_code := NULL;
	retcode      := 1;
        END;
      ELSE
        g_class_code := NULL;
      END IF;

      /* Sales Channel validation*/
      IF p_acc_rec.sales_channel_code IS NOT NULL AND
         upper(p_acc_rec.sales_channel_code) <> 'NULL' THEN
        BEGIN
          SELECT lookup_code
          INTO   l_sales_channel_code
          FROM   fnd_lookup_values_vl
          WHERE  lookup_type = 'SALES_CHANNEL'
          AND    enabled_flag = 'Y'
          AND    view_application_id = 660
          AND    SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
	     nvl(end_date_active, SYSDATE)
          AND    (meaning = p_acc_rec.sales_channel_code OR
	    lookup_code = p_acc_rec.sales_channel_code);

          /* Update Interface table with code - in case meaning is provided in csv */
          --update xxhz_account_interface set sales_channel_code = l_sales_channel_code where interface_id = p_acc_rec.interface_id;

          p_acc_rec.sales_channel_code := l_sales_channel_code;
        EXCEPTION
          WHEN OTHERS THEN
            l_message := l_message || ', Sales Channel code incorrect.';
            retcode   := 1;
        END;
      ELSIF upper(p_acc_rec.sales_channel_code) = 'NULL' THEN
        --l_message := l_message ||', Sales Channel cannot be removed.';

        p_acc_rec.sales_channel_code := fnd_api.g_miss_char;
      END IF;

      /* Customer category validation */
      IF p_acc_rec.category_code IS NOT NULL AND
         upper(p_acc_rec.category_code) <> 'NULL' THEN
        BEGIN
          SELECT lookup_code
          INTO   l_customer_category_code
          FROM   fnd_lookup_values_vl
          WHERE  lookup_type = 'CUSTOMER_CATEGORY'
          AND    enabled_flag = 'Y'
          AND    view_application_id = 222
          AND    SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
	     nvl(end_date_active, SYSDATE)
          AND    (meaning = p_acc_rec.category_code OR
	    lookup_code = p_acc_rec.category_code);

          /* Update Interface table with code - in case meaning is provided in csv */
          --update xxhz_account_interface set category_code = l_customer_category_code where interface_id = p_acc_rec.interface_id;

          p_acc_rec.category_code := l_customer_category_code;
        EXCEPTION
          WHEN OTHERS THEN
	l_message := l_message || ', Customer Category code incorrect.';
	retcode   := 1;
        END;
      ELSIF upper(p_acc_rec.category_code) = 'NULL' THEN
        --l_message := l_message ||', Customer Category cannot be removed.';

        p_acc_rec.category_code := fnd_api.g_miss_char;
      END IF;

      /* Pricelist validation */
      IF p_acc_rec.price_list_name IS NOT NULL AND
         upper(p_acc_rec.price_list_name) <> 'NULL' THEN
        BEGIN
          SELECT pl.list_header_id
          INTO   l_pricelist_id
          FROM   qp_list_headers_vl pl
          WHERE  SYSDATE BETWEEN nvl(pl.start_date_active, SYSDATE) AND
	     nvl(pl.end_date_active, SYSDATE)
          AND    pl.list_type_code IN ('PRL')
          AND    pl.name = p_acc_rec.price_list_name;

          /*UPDATE xxhz_account_interface
          SET    price_list_id = l_pricelist_id
          WHERE  interface_id = p_acc_rec.interface_id;*/

          p_acc_rec.price_list_id := l_pricelist_id;
        EXCEPTION
          WHEN OTHERS THEN
	l_message := l_message || 'Pricelist name is incorrect';
	retcode   := 1;
        END;
      ELSIF upper(p_acc_rec.price_list_name) = 'NULL' THEN
        p_acc_rec.price_list_id := fnd_api.g_miss_num;
      END IF;

      /* Payment Term validation */
      IF p_acc_rec.payment_term IS NOT NULL AND
         upper(p_acc_rec.payment_term) <> 'NULL' THEN
        BEGIN
          SELECT term_id
          INTO   l_payterm_id
          FROM   ra_terms
          WHERE  trunc(SYSDATE) BETWEEN start_date_active AND
	     nvl(end_date_active, trunc(SYSDATE))
          AND    NAME = p_acc_rec.payment_term;

          /*UPDATE xxhz_account_interface
          SET    payment_term_id = l_payterm_id
          WHERE  interface_id = p_acc_rec.interface_id;*/

          p_acc_rec.payment_term_id := l_payterm_id;
        EXCEPTION
          WHEN OTHERS THEN
	l_message := l_message || ', Payment term is incorrect.';
	retcode   := 1;
        END;
      ELSIF upper(p_acc_rec.payment_term) = 'NULL' THEN
        p_acc_rec.payment_term_id := fnd_api.g_miss_num;
      END IF;

      IF p_acc_rec.classification_status IS NOT NULL THEN
        IF p_acc_rec.classification_status NOT IN ('A', 'I') THEN
          l_message := l_message ||
	           ', Status value must be A (active) or I (inactive)';
          retcode   := 1;
        END IF;
      END IF;

      IF upper(p_acc_rec.organization_name_phonetic) = 'NULL' THEN
        p_acc_rec.organization_name_phonetic := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.party_attribute_category) = 'NULL' THEN
        p_acc_rec.party_attribute_category := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.party_attribute1) = 'NULL' THEN
        p_acc_rec.party_attribute1 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute1 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE1',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute1,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute1);
        l_message := l_message || l_status_message;
        if l_status = '1' then
          retcode := l_status;
        end if;
      END IF;

      IF upper(p_acc_rec.party_attribute2) = 'NULL' THEN
        p_acc_rec.party_attribute2 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute2 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE2',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute2,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute2);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute3) = 'NULL' THEN
        p_acc_rec.party_attribute3 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute3 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE3',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute3,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute3);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute4) = 'NULL' THEN
        p_acc_rec.party_attribute4 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute4 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE4',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute4,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute4);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute5) = 'NULL' THEN
        p_acc_rec.party_attribute5 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute5 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE5',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute5,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute5);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute6) = 'NULL' THEN
        p_acc_rec.party_attribute6 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute6 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE6',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute6,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute6);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute7) = 'NULL' THEN
        p_acc_rec.party_attribute7 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute7 is not null then
        fnd_file.put_line(fnd_file.log,' ATTRIBUTE7 before' || p_acc_rec.party_attribute7);
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE7',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute7,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute7);
        fnd_file.put_line(fnd_file.log,' ATTRIBUTE7 before' || p_acc_rec.party_attribute7);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute8) = 'NULL' THEN
        p_acc_rec.party_attribute8 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute8 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE8',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute8,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute8);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute9) = 'NULL' THEN
        p_acc_rec.party_attribute9 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute9 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE9',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute9,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute9);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute10) = 'NULL' THEN
        p_acc_rec.party_attribute10 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute10 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE10',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute10,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute10);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute11) = 'NULL' THEN
        p_acc_rec.party_attribute11 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute11 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE11',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute11,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute11);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute12) = 'NULL' THEN
        p_acc_rec.party_attribute12 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute12 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE12',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute12,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute12);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute13) = 'NULL' THEN
        p_acc_rec.party_attribute13 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute13 is not null then
        fnd_file.put_line(fnd_file.log,' ATTRIBUTE13 before' || p_acc_rec.party_attribute13);
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE13',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute13,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute13);
        fnd_file.put_line(fnd_file.log,' ATTRIBUTE13 after' || p_acc_rec.party_attribute13);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute14) = 'NULL' THEN
        p_acc_rec.party_attribute14 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute14 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE14',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute14,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute14);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute15) = 'NULL' THEN
        p_acc_rec.party_attribute15 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute15 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE15',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute15,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute15);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute16) = 'NULL' THEN
        p_acc_rec.party_attribute16 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute16 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE16',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute16,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute16);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute17) = 'NULL' THEN
        p_acc_rec.party_attribute17 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute17 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE17',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute17,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute17);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute18) = 'NULL' THEN
        p_acc_rec.party_attribute18 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute18 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE18',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute18,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute18);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute19) = 'NULL' THEN
        p_acc_rec.party_attribute19 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute19 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE19',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute19,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute19);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.party_attribute20) = 'NULL' THEN
        p_acc_rec.party_attribute20 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.party_attribute20 is not null then
        validate_dff_values(l_party_dff_name,
                            'ATTRIBUTE20',
                            p_acc_rec.party_attribute_category,
                            p_acc_rec.party_attribute20,
                            l_status,
                            l_status_message,
                            p_acc_rec.party_attribute20);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute_category) = 'NULL' THEN
        p_acc_rec.attribute_category := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.attribute1) = 'NULL' THEN
        p_acc_rec.attribute1 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute1 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE1',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute1,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute1);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute2) = 'NULL' THEN
        p_acc_rec.attribute2 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute2 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE2',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute2,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute2);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute3) = 'NULL' THEN
        p_acc_rec.attribute3 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute3 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE3',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute3,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute3);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute4) = 'NULL' THEN
        p_acc_rec.attribute4 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute4 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE4',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute4,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute4);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute5) = 'NULL' THEN
        p_acc_rec.attribute5 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute5 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE5',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute5,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute5);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute6) = 'NULL' THEN
        p_acc_rec.attribute6 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute6 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE6',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute6,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute6);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute7) = 'NULL' THEN
        p_acc_rec.attribute7 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute7 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE7',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute7,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute7);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute8) = 'NULL' THEN
        p_acc_rec.attribute8 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute8 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE8',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute8,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute8);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute9) = 'NULL' THEN
        p_acc_rec.attribute9 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute9 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE9',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute9,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute9);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute10) = 'NULL' THEN
        p_acc_rec.attribute10 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute10 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE10',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute10,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute10);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute11) = 'NULL' THEN
        p_acc_rec.attribute11 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute11 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE11',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute11,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute11);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute12) = 'NULL' THEN
        p_acc_rec.attribute12 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute12 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE12',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute12,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute12);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute13) = 'NULL' THEN
        p_acc_rec.attribute13 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute13 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE13',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute13,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute13);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute14) = 'NULL' THEN
        p_acc_rec.attribute14 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute14 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE14',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute14,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute14);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute15) = 'NULL' THEN
        p_acc_rec.attribute15 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute15 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE15',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute15,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute15);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute16) = 'NULL' THEN
        p_acc_rec.attribute16 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute16 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE16',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute16,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute16);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute17) = 'NULL' THEN
        p_acc_rec.attribute17 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute17 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE17',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute17,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute17);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute18) = 'NULL' THEN
        p_acc_rec.attribute18 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute18 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE18',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute18,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute18);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute19) = 'NULL' THEN
        p_acc_rec.attribute19 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute19 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE19',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute19,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute19);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.attribute20) = 'NULL' THEN
        p_acc_rec.attribute20 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.attribute20 is not null then
        validate_dff_values(l_account_dff_name,
                            'ATTRIBUTE20',
                            p_acc_rec.attribute_category,
                            p_acc_rec.attribute20,
                            l_status,
                            l_status_message,
                            p_acc_rec.attribute20);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.duns_number) = 'NULL' THEN
        p_acc_rec.duns_number := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.jgzz_fiscal_code) = 'NULL' THEN
        p_acc_rec.jgzz_fiscal_code := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.tax_reference) = 'NULL' THEN
        p_acc_rec.tax_reference := fnd_api.g_miss_char;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute1) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute1 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute1 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE1',
                            null,
                            p_acc_rec.profile_amt_attribute1,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute1);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute2) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute2 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute2 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE2',
                            null,
                            p_acc_rec.profile_amt_attribute2,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute2);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute3) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute3 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute3 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE3',
                            null,
                            p_acc_rec.profile_amt_attribute3,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute3);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute4) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute4 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute4 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE4',
                            null,
                            p_acc_rec.profile_amt_attribute4,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute4);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute5) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute5 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute5 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE5',
                            null,
                            p_acc_rec.profile_amt_attribute5,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute5);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute6) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute6 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute6 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE6',
                            null,
                            p_acc_rec.profile_amt_attribute6,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute6);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute7) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute7 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute7 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE7',
                            null,
                            p_acc_rec.profile_amt_attribute7,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute7);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute8) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute8 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute8 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE8',
                            null,
                            p_acc_rec.profile_amt_attribute8,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute8);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute9) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute9 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute9 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE9',
                            null,
                            p_acc_rec.profile_amt_attribute9,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute9);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      IF upper(p_acc_rec.profile_amt_attribute10) = 'NULL' THEN
        p_acc_rec.profile_amt_attribute10 := fnd_api.g_miss_char;
      ELSIF p_acc_rec.profile_amt_attribute10 is not null then
        validate_dff_values(l_profile_amt_dff_name,
                            'ATTRIBUTE10',
                            null,
                            p_acc_rec.profile_amt_attribute10,
                            l_status,
                            l_status_message,
                            p_acc_rec.profile_amt_attribute10);
        if l_status = '1' then
          retcode := l_status;
        end if;
        l_message := l_message || l_status_message;
      END IF;

      /* CHG0036474 - Dipta - Change ends*/
    END IF; --21/04/2015    Michal Tzvik    CHG0034610
    -- validate attribute3 will be required

    /* ????????????????????
    select ffv.flex_value           ou_id, ffvt.description
    --into   l_org_id
    from   fnd_flex_values          ffv,
           fnd_flex_value_sets      ffvs,
           fnd_flex_values_tl       ffvt
    where  ffv.flex_value_set_id    = ffvs.flex_value_set_id
    and    ffvs.flex_value_set_name = 'XXOBJT_SF_SALES_TERRITORY'
    and    ffv.flex_value_id        = ffvt.flex_value_id
    and    ffvt.language            = 'US'
    */

    errbuf := regexp_replace(l_message,'^( ,){1}',''); -- yuval CHG0036474

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'validate_accounts - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END validate_accounts;

  --------------------------------------------------------------------
  --  name:               validate_sites
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        validate required fields at site level
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --  1.1   03/03/2015    Dalit A. Raviv  CHG0033183 - add handle for upload with numbers and not Id's
  --------------------------------------------------------------------
  PROCEDURE validate_sites(errbuf     OUT VARCHAR2,
		   retcode    OUT VARCHAR2,
		   p_site_rec IN OUT xxhz_site_interface%ROWTYPE) IS

    l_message        VARCHAR2(500) := NULL;
    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(30) := NULL;
    l_count          NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    -- check connect to account.
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183 add condition
    IF p_site_rec.cust_account_id IS NULL AND
       p_site_rec.parent_interface_id IS NULL AND
       p_site_rec.account_number IS NULL THEN
      IF l_message IS NULL THEN
        l_message := 'Missing Connection to account record';
      ELSE
        l_message := l_message || ', Missing Connection to account record';
      END IF;
      retcode := 1;
    END IF;
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- chaeck value is valid
    l_count := 0;
    IF p_site_rec.account_number IS NOT NULL THEN
      SELECT COUNT(cust_account_id)
      INTO   l_count
      FROM   hz_cust_accounts hcc
      WHERE  hcc.account_number = p_site_rec.account_number;

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'Account number is not valid';
        ELSE
          l_message := l_message || ', Account number is not valid';
        END IF;
        retcode := 1;
      END IF;
    END IF;

    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- Check value is valid
    IF p_site_rec.org_id IS NULL AND p_site_rec.org_name IS NULL THEN
      IF l_message IS NULL THEN
        l_message := 'Missing operating unit';
      ELSE
        l_message := l_message || ', Missing operating unit';
      END IF;
      retcode := 1;
    END IF;
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- chack value is valid
    IF p_site_rec.org_name IS NOT NULL THEN
      BEGIN
        SELECT ou.organization_id
        INTO   p_site_rec.org_id
        FROM   hr_operating_units ou
        WHERE  ou.name = p_site_rec.org_name;
      EXCEPTION
        WHEN OTHERS THEN
          IF l_message IS NULL THEN
	l_message := 'Organization name is not valid';
          ELSE
	l_message := l_message || ', Organization name is not valid';
          END IF;
          retcode := 1;
      END;
    END IF;
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- chack value is valid
    IF p_site_rec.primary_salesrep_name IS NOT NULL THEN
      l_count := 0;
      SELECT COUNT(t.salesrep_id)
      INTO   l_count
      FROM   jtf_rs_resource_extns_vl rs,
	 jtf.jtf_rs_salesreps     t
      WHERE  rs.resource_id = t.resource_id
      AND    rs.resource_name = p_site_rec.primary_salesrep_name
      AND    t.org_id = p_site_rec.org_id
      AND    (t.end_date_active IS NULL OR t.end_date_active > SYSDATE);

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'Salesrep name is not valid';
        ELSE
          l_message := l_message || ', Salesrep name is not valid';
        END IF;
        retcode := 1;
      END IF;
    END IF;

    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- chack value is valid
    IF p_site_rec.agent_name IS NOT NULL THEN
      l_count := 0;
      -- for attribute11 no need to get only active salesreps.
      SELECT COUNT(t.salesrep_id)
      INTO   l_count
      FROM   jtf_rs_resource_extns_vl rs,
	 jtf.jtf_rs_salesreps     t
      WHERE  rs.resource_id = t.resource_id
      AND    rs.resource_name = p_site_rec.agent_name
      AND    t.org_id = p_site_rec.org_id;

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'Agent name is not valid';
        ELSE
          l_message := l_message || ', Agent name is not valid';
        END IF;
        retcode := 1;
      END IF;
    END IF;
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- chack value is valid
    l_count := 0;
    IF p_site_rec.party_site_number IS NOT NULL AND
       p_site_rec.party_site_id IS NULL THEN
      SELECT COUNT(hps.party_site_id)
      INTO   l_count
      FROM   hz_cust_acct_sites_all hcas,
	 hz_cust_site_uses_all  hcsu,
	 hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps
      WHERE  hp.party_id = hps.party_id
      AND    hp.party_id = hca.party_id
      AND    hcas.party_site_id = hps.party_site_id
      AND    hcas.cust_account_id = hca.cust_account_id
      AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
      AND    hca.cust_account_id = hcas.cust_account_id
      AND    hca.account_number = p_site_rec.account_number
      AND    hps.party_site_number = p_site_rec.party_site_number
      AND    hcsu.site_use_code = CASE
	   WHEN p_site_rec.site_use_code = 'Bill To' THEN
	    'BILL_TO'
	   WHEN p_site_rec.site_use_code = 'Ship To' THEN
	    'SHIP_TO'
	   WHEN p_site_rec.site_use_code = 'Bill To/Ship To' THEN
	    'BILL_TO'
	   ELSE
	    p_site_rec.site_use_code
	 END
      AND    hcsu.org_id = p_site_rec.org_id
      AND    hcsu.status = 'A'
      AND    hca.status = 'A';

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'There is no active site use for this party site';
        ELSE
          l_message := l_message ||
	           ', There is no active site use for this party site';
        END IF;
        retcode := 1;
      END IF;
    END IF;

    -- Handle GL fields
    IF p_site_rec.gl_conc_rec IS NOT NULL THEN
      l_count := 0;
      SELECT COUNT(gl.code_combination_id)
      INTO   l_count
      FROM   gl_code_combinations_kfv gl
      WHERE  gl.concatenated_segments = p_site_rec.gl_conc_rec;

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'GL CCI is not valid for gl_conc_rec';
        ELSE
          l_message := l_message || ', GL CCI is not valid for gl_conc_rec';
        END IF;
        retcode := 1;
      END IF;
    END IF;

    IF p_site_rec.gl_conc_rev IS NOT NULL THEN
      l_count := 0;
      SELECT COUNT(gl.code_combination_id)
      INTO   l_count
      FROM   gl_code_combinations_kfv gl
      WHERE  gl.concatenated_segments = p_site_rec.gl_conc_rev;
      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'GL CCI is not valid for gl_conc_rev';
        ELSE
          l_message := l_message || ', GL CCI is not valid for gl_conc_rev';
        END IF;
        retcode := 1;
      END IF;
    END IF;

    IF p_site_rec.gl_conc_unearned IS NOT NULL THEN
      l_count := 0;
      SELECT COUNT(gl.code_combination_id)
      INTO   l_count
      FROM   gl_code_combinations_kfv gl
      WHERE  gl.concatenated_segments = p_site_rec.gl_conc_unearned;

      IF l_count = 0 THEN
        IF l_message IS NULL THEN
          l_message := 'GL CCI is not valid for gl_conc_unearned';
        ELSE
          l_message := l_message ||
	           ', GL CCI is not valid for gl_conc_unearned';
        END IF;
        retcode := 1;
      END IF;
    END IF;
    -- end 1.1 03/03/2015 CHG0033183

    -- check country is valid
    IF p_site_rec.country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_site_rec.country);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
	SELECT territory_code
	INTO   l_territory_code
	FROM   fnd_territories_vl t
	WHERE  upper(t.territory_code) = upper(p_site_rec.country);
          EXCEPTION
	WHEN OTHERS THEN
	  retcode := 1;
	  IF l_message IS NULL THEN
	    l_message := 'Invalid territory: ' || p_site_rec.country;
	  ELSE
	    l_message := l_message || 'Invalid territory: ' ||
		     p_site_rec.country;
	  END IF;
          END;
      END;
    END IF;

    IF p_site_rec.state IS NOT NULL AND nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_site_rec.state);
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 1;
          IF l_message IS NULL THEN
	l_message := 'Invalid US State: ' || p_site_rec.state;
          ELSE
	l_message := l_message || 'Invalid US State: ' ||
		 p_site_rec.state;
          END IF;
      END;
    END IF;
    errbuf := l_message;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'validate_sites - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END validate_sites;

  --------------------------------------------------------------------
  --  name:               validate_locations
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/01/2015
  --  Description:        validate required fields at location level
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/01/2015    Michal Tzvik    CHG0033182 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_locations(errbuf         OUT VARCHAR2,
		       retcode        OUT VARCHAR2,
		       p_location_rec IN OUT xxhz_locations_interface%ROWTYPE) IS
    l_message  VARCHAR2(500) := NULL;
    l_is_valid VARCHAR2(1);
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    -- check if location_id exists in Oracle
    IF p_location_rec.location_id IS NOT NULL THEN
      SELECT nvl(MAX('Y'), 'N')
      INTO   l_is_valid
      FROM   hz_locations hl
      WHERE  hl.location_id = p_location_rec.location_id;

      IF l_is_valid = 'N' THEN
        l_message := 'Location id ' || p_location_rec.location_id ||
	         ' is not valid.';
        retcode   := 1;
      END IF;
    END IF;

    errbuf := l_message;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'validate_locations - Failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END validate_locations;

  --------------------------------------------------------------------
  --  name:               validate_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        validate required fields at site level
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE validate_contacts(errbuf        OUT VARCHAR2,
		      retcode       OUT VARCHAR2,
		      p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    l_prefix         VARCHAR2(100) := NULL;
    l_message        VARCHAR2(500) := NULL;
    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(30) := NULL;
    l_title          VARCHAR2(30) := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- TO ADD HANDLE WITH MESSAGES

    IF p_contact_rec.person_pre_name_adjunct IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_prefix
        FROM   ar_lookups al
        WHERE  al.lookup_type = 'CONTACT_TITLE'
        AND    upper(al.meaning) =
	   upper(p_contact_rec.person_pre_name_adjunct); --'Mrs.'
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 1;
          IF l_message IS NULL THEN
	l_message := 'Invalid Person Prefix: ' ||
		 p_contact_rec.person_pre_name_adjunct;
          ELSE
	l_message := l_message || 'Invalid Person Prefix: ' ||
		 p_contact_rec.person_pre_name_adjunct;
          END IF;
      END;
      errbuf := l_message;
    END IF;

    -- check country is valid
    IF p_contact_rec.country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_contact_rec.country);
      EXCEPTION
        WHEN OTHERS THEN

          BEGIN
	SELECT territory_code
	INTO   l_territory_code
	FROM   fnd_territories_vl t
	WHERE  upper(t.territory_code) = upper(p_contact_rec.country);
          EXCEPTION
	WHEN OTHERS THEN
	  retcode := 1;
	  IF l_message IS NULL THEN
	    l_message := 'Invalid territory: ' || p_contact_rec.country;
	  ELSE
	    l_message := l_message || 'Invalid territory: ' ||
		     p_contact_rec.country;
	  END IF;
          END;
      END;
    END IF;

    IF p_contact_rec.state IS NOT NULL AND
       nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_contact_rec.state);
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 1;
          IF l_message IS NULL THEN
	l_message := 'Invalid US State: ' || p_contact_rec.state;
          ELSE
	l_message := l_message || 'Invalid US State: ' ||
		 p_contact_rec.state;
          END IF;
      END;
    END IF;

    -- Job title
    IF p_contact_rec.job_title IS NOT NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_title
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'RESPONSIBILITY'
        AND    flv.language = 'US'
        AND    flv.enabled_flag = 'Y'
        AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
        AND    upper(flv.meaning) = upper(p_contact_rec.job_title);
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 1;
          IF l_message IS NULL THEN
	l_message := 'Invalid Job Title: ' || p_contact_rec.state;
          ELSE
	l_message := l_message || 'Invalid Job Title: ' ||
		 p_contact_rec.state;
          END IF;
      END;
    END IF;

    errbuf := l_message;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'validate_contacts - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END validate_contacts;

  --------------------------------------------------------------------
  --  name:               reset_log_msg
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      18/03/2014
  --  Description:        reset log message before start to work,
  --                      this will be useful for the second run after error.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE reset_log_msg(p_interface_id IN NUMBER,
		  p_entity       IN VARCHAR2) IS
    --  PRAGMA AUTONOMOUS_TRANSACTION;  -- yuval
  BEGIN
    IF p_entity = 'ACCOUNT' THEN
      UPDATE xxhz_account_interface a
      SET    a.log_message = NULL
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'SITE' THEN
      UPDATE xxhz_site_interface a
      SET    a.log_message = NULL
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'CONTACT' THEN
      UPDATE xxhz_contact_interface a
      SET    a.log_message = NULL
      WHERE  a.interface_id = p_interface_id;
    END IF;
    COMMIT;
    -- EXCEPTION  --yuval
    --   WHEN OTHERS THEN
    --   NULL;
  END reset_log_msg;

  --------------------------------------------------------------------
  --  name:               upd_log
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        update interface table with Log message and status
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   18/01/2015    Michal Tzvik    CHG0033182: add entity LOCATION
  --------------------------------------------------------------------
  PROCEDURE upd_log(p_err_desc     IN VARCHAR2,
	        p_status       IN VARCHAR2,
	        p_interface_id IN NUMBER,
	        p_entity       IN VARCHAR2) IS
     PRAGMA AUTONOMOUS_TRANSACTION; --  yuval CHG0036474
  BEGIN
    IF p_entity = 'ACCOUNT' THEN
      UPDATE xxhz_account_interface a
      SET    a.log_message      = a.log_message || ' ' || p_err_desc,
	 a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'SITE' THEN
      UPDATE xxhz_site_interface a
      SET    a.log_message      = a.log_message || ' ' || p_err_desc,
	 a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'CONTACT' THEN
      UPDATE xxhz_contact_interface a
      SET    a.log_message      = a.log_message || ' ' || p_err_desc,
	 a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
      -- 1.1 Michal Tzvik 18.01.2015: Start
    ELSIF p_entity = 'LOCATION' THEN
      UPDATE xxhz_locations_interface a
      SET    a.log_message      = a.log_message || ' ' || p_err_desc,
	 a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
      -- 1.1 Michal Tzvik 18.01.2015: End
    END IF;
    COMMIT;
    -- EXCEPTION  -- yuval CHG0036474
    --   WHEN OTHERS THEN -- yuval CHG0036474
    --    NULL; -- yuval CHG0036474
  END upd_log;

  --------------------------------------------------------------------
  --  name:               interface_status
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      30/04/2014
  --  Description:        update interface table with status to in-process
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30/04/2014    Dalit A. Raviv  initial build
  --  1.1   13/01/2015    Michal Tzvik    CHG0033182: Handle 'LOCATION' entity
  --------------------------------------------------------------------
  PROCEDURE interface_status(p_status       IN VARCHAR2,
		     p_interface_id IN NUMBER,
		     p_entity       IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    IF p_entity = 'ACCOUNT' THEN
      UPDATE xxhz_account_interface a
      SET    a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'SITE' THEN
      UPDATE xxhz_site_interface a
      SET    a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
    ELSIF p_entity = 'CONTACT' THEN
      UPDATE xxhz_contact_interface a
      SET    a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
      -- 1.1   13/01/2015    Michal Tzvik: Start
    ELSIF p_entity = 'LOCATION' THEN
      UPDATE xxhz_locations_interface a
      SET    a.interface_status = p_status,
	 a.last_update_date = SYSDATE
      WHERE  a.interface_id = p_interface_id;
      -- 1.1   13/01/2015    Michal Tzvik: End
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END interface_status;

  --------------------------------------------------------------------
  --  name:               upd_log
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        update interface table with Log message and status
  --                      change status to success and fill all id's that created durint the program
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   13/01/2014    Michal Tzvik    CHG0033182: Add parameter p_location_rec
  --------------------------------------------------------------------
  PROCEDURE upd_success_log(p_status       IN VARCHAR2,
		    p_entity       IN VARCHAR2,
		    p_acc_rec      IN xxhz_account_interface%ROWTYPE,
		    p_site_rec     IN xxhz_site_interface%ROWTYPE,
		    p_contact_rec  IN xxhz_contact_interface%ROWTYPE,
		    p_location_rec IN xxhz_locations_interface%ROWTYPE DEFAULT NULL --  1.1   13/01/2014    Michal Tzvik
		    ) IS
  BEGIN
    IF p_entity = 'ACCOUNT' THEN
      UPDATE xxhz_account_interface a
      SET    a.interface_status        = p_status,
	 a.last_update_date        = SYSDATE,
	 a.account_name            = nvl(p_acc_rec.account_name,
			         a.account_name),
	 a.party_id                = p_acc_rec.party_id,
	 a.cust_account_id         = p_acc_rec.cust_account_id,
	 a.account_number          = nvl(p_acc_rec.account_number,
			         a.account_number),
	 a.phone_contact_point_id  = nvl(p_acc_rec.phone_contact_point_id,
			         a.phone_contact_point_id),
	 a.fax_contact_point_id    = nvl(p_acc_rec.fax_contact_point_id,
			         a.fax_contact_point_id),
	 a.mobile_contact_point_id = nvl(p_acc_rec.mobile_contact_point_id,
			         a.mobile_contact_point_id),
	 a.web_contact_point_id    = nvl(p_acc_rec.web_contact_point_id,
			         a.web_contact_point_id),
	 a.email_contact_point_id  = nvl(p_acc_rec.email_contact_point_id,
			         a.email_contact_point_id)
      WHERE  a.interface_id = p_acc_rec.interface_id;
    ELSIF p_entity = 'SITE' THEN
      UPDATE xxhz_site_interface a
      SET    a.interface_status  = p_status,
	 a.last_update_date  = SYSDATE,
	 a.cust_account_id   = nvl(p_site_rec.cust_account_id,
			   a.cust_account_id),
	 a.party_site_id     = nvl(p_site_rec.party_site_id,
			   a.party_site_id),
	 a.location_id       = nvl(p_site_rec.location_id, a.location_id),
	 a.cust_acct_site_id = nvl(p_site_rec.cust_acct_site_id,
			   a.cust_acct_site_id),
	 a.bill_site_use_id  = nvl(p_site_rec.bill_site_use_id,
			   a.bill_site_use_id),
	 a.ship_site_use_id  = nvl(p_site_rec.ship_site_use_id,
			   a.ship_site_use_id)
      WHERE  a.interface_id = p_site_rec.interface_id;
    ELSIF p_entity = 'CONTACT' THEN
      UPDATE xxhz_contact_interface a
      SET    a.interface_status        = p_status,
	 a.last_update_date        = SYSDATE,
	 a.cust_account_id         = nvl(p_contact_rec.cust_account_id,
			         a.cust_account_id),
	 a.cust_acct_site_id       = nvl(p_contact_rec.cust_acct_site_id,
			         a.cust_acct_site_id),
	 a.location_id             = nvl(p_contact_rec.location_id,
			         a.location_id),
	 a.person_party_id         = nvl(p_contact_rec.person_party_id,
			         a.person_party_id),
	 a.party_site_id           = nvl(p_contact_rec.party_site_id,
			         a.party_site_id),
	 a.contact_party_id        = nvl(p_contact_rec.contact_party_id,
			         a.contact_party_id),
	 a.cust_account_role_id    = nvl(p_contact_rec.cust_account_role_id,
			         a.cust_account_role_id),
	 a.phone_contact_point_id  = nvl(p_contact_rec.phone_contact_point_id,
			         a.phone_contact_point_id),
	 a.fax_contact_point_id    = nvl(p_contact_rec.fax_contact_point_id,
			         a.fax_contact_point_id),
	 a.mobile_contact_point_id = nvl(p_contact_rec.mobile_contact_point_id,
			         a.mobile_contact_point_id),
	 a.email_contact_point_id  = nvl(p_contact_rec.email_contact_point_id,
			         a.email_contact_point_id),
	 a.web_contact_point_id    = nvl(p_contact_rec.web_contact_point_id,
			         a.web_contact_point_id)
      WHERE  a.interface_id = p_contact_rec.interface_id;
      --  1.1   13/01/2014    Michal Tzvik: Start
    ELSIF p_entity = 'LOCATION' THEN
      UPDATE xxhz_locations_interface a
      SET    a.interface_status = p_status,
	 a.last_update_date = SYSDATE,
	 a.location_id      = nvl(p_location_rec.location_id,
			  a.location_id)
      WHERE  a.interface_id = p_location_rec.interface_id;
      --  1.1   13/01/2014    Michal Tzvik: End
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(' sqlerrm ' || substr(SQLERRM, 1, 240));
      fnd_file.put_line(fnd_file.log,
		' sqlerrm ' || substr(SQLERRM, 1, 240));
  END upd_success_log;

  --------------------------------------------------------------------
  --  name:               fill_missing_acc_info
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        fill missing information to the record, this info
  --                      will be use later in the program
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE fill_missing_acc_info(p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    l_account_number  VARCHAR2(30);
    l_account_name    VARCHAR2(240);
    l_party_id        NUMBER;
    l_cust_account_id NUMBER;
  BEGIN
    -- the interface can get cust_account_id, but some interfaces can send the account_number
    IF p_acc_rec.cust_account_id IS NOT NULL THEN
      SELECT hca.account_number,
	 hca.account_name,
	 hca.party_id
      INTO   l_account_number,
	 l_account_name,
	 l_party_id
      FROM   hz_cust_accounts hca
      WHERE  hca.cust_account_id = p_acc_rec.cust_account_id;

      p_acc_rec.account_number := l_account_number;
      p_acc_rec.account_name   := l_account_name;
      p_acc_rec.party_id       := l_party_id;
    ELSIF p_acc_rec.account_number IS NOT NULL AND
          p_acc_rec.cust_account_id IS NULL THEN
      SELECT hca.cust_account_id,
	 hca.account_name,
	 hca.party_id
      INTO   l_cust_account_id,
	 l_account_name,
	 l_party_id
      FROM   hz_cust_accounts hca
      WHERE  hca.account_number = p_acc_rec.account_number;

      p_acc_rec.cust_account_id := l_cust_account_id;
      p_acc_rec.account_name    := l_account_name;
      p_acc_rec.party_id        := l_party_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END fill_missing_acc_info;

  --------------------------------------------------------------------
  --  name:               fill_missing_site_info
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        fill missing information to the record, this info
  --                      will be use later in the program
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --  1.1   03/03/2015    Dalit A. Raviv  CHG0033183 - add handle for upload
  --                                      with numbers/names and not Id's
  --------------------------------------------------------------------
  PROCEDURE fill_missing_site_info(p_site_rec IN OUT xxhz_site_interface%ROWTYPE) IS

    l_site_use_id  NUMBER;
    l_primary_flag VARCHAR2(1);
    l_status       VARCHAR2(1);
  BEGIN

    IF p_site_rec.cust_account_id IS NULL AND
       p_site_rec.parent_interface_id IS NOT NULL THEN
      SELECT a.cust_account_id,
	 a.party_id
      INTO   p_site_rec.cust_account_id,
	 p_site_rec.party_id
      FROM   xxhz_account_interface a
      WHERE  a.interface_id = p_site_rec.parent_interface_id;

    END IF;
    -- 1.1 03/03/2015 Dalit A. Raviv CHG0033183
    -- Handle Accout and Party
    IF p_site_rec.cust_account_id IS NULL AND
       p_site_rec.account_number IS NOT NULL THEN
      SELECT cust_account_id,
	 hcc.party_id
      INTO   p_site_rec.cust_account_id,
	 p_site_rec.party_id
      FROM   hz_cust_accounts hcc
      WHERE  hcc.account_number = p_site_rec.account_number;
    END IF;
    -- Handle Organization name
    IF p_site_rec.org_name IS NOT NULL AND p_site_rec.org_id IS NULL THEN
      SELECT ou.organization_id
      INTO   p_site_rec.org_id
      FROM   hr_operating_units ou
      WHERE  ou.name = p_site_rec.org_name;
    END IF;
    -- Handel Selerep
    IF p_site_rec.primary_salesrep_name IS NOT NULL AND
       p_site_rec.primary_salesrep_id IS NULL THEN
      SELECT t.salesrep_id
      INTO   p_site_rec.primary_salesrep_id
      FROM   jtf_rs_resource_extns_vl rs,
	 jtf.jtf_rs_salesreps     t
      WHERE  rs.resource_id = t.resource_id
      AND    rs.resource_name = p_site_rec.primary_salesrep_name
      AND    t.org_id = p_site_rec.org_id;
    END IF;
    -- Handle site attribuet11 - Agent
    IF p_site_rec.agent_name IS NOT NULL THEN
      SELECT t.salesrep_id
      INTO   p_site_rec.site_attribute11
      FROM   jtf_rs_resource_extns_vl rs,
	 jtf.jtf_rs_salesreps     t
      WHERE  rs.resource_id = t.resource_id
      AND    rs.resource_name = p_site_rec.agent_name
      AND    t.org_id = p_site_rec.org_id;

      p_site_rec.site_attribute_category := 'SHIP_TO';

    END IF;
    -- Handle party_site_id
    IF p_site_rec.party_site_number IS NOT NULL AND
       p_site_rec.party_site_id IS NULL AND
       p_site_rec.site_use_code <> 'Bill To/Ship To' THEN
      BEGIN
        -- p_site_rec.cust_acct_site_id
        SELECT hps.party_site_id,
	   hps.location_id,
	   hcsu.cust_acct_site_id,
	   hcsu.site_use_id,
	   hcsu.primary_flag,
	   hcsu.status
        INTO   p_site_rec.party_site_id,
	   p_site_rec.location_id,
	   p_site_rec.cust_acct_site_id,
	   l_site_use_id,
	   l_primary_flag,
	   l_status
        FROM   hz_cust_acct_sites_all hcas,
	   hz_cust_site_uses_all  hcsu,
	   hz_cust_accounts       hca,
	   hz_parties             hp,
	   hz_party_sites         hps
        WHERE  hp.party_id = hps.party_id
        AND    hp.party_id = hca.party_id
        AND    hcas.party_site_id = hps.party_site_id
        AND    hcas.cust_account_id = hca.cust_account_id
        AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
        AND    hca.cust_account_id = hcas.cust_account_id
        AND    hca.account_number = p_site_rec.account_number
        AND    hps.party_site_number = p_site_rec.party_site_number
        AND    hcsu.site_use_code = CASE
	     WHEN p_site_rec.site_use_code = 'Bill To' THEN
	      'BILL_TO'
	     WHEN p_site_rec.site_use_code = 'Ship To' THEN
	      'SHIP_TO'
	     ELSE
	      p_site_rec.site_use_code
	   END
        AND    hcsu.org_id = p_site_rec.org_id
        AND    hcsu.status = 'A'
        AND    hca.status = 'A';

        IF p_site_rec.site_use_code IN ('Bill To', 'BILL_TO') THEN
          p_site_rec.bill_site_use_id := l_site_use_id;
        ELSIF p_site_rec.site_use_code IN ('Ship To', 'SHIP_TO') THEN
          p_site_rec.ship_site_use_id := l_site_use_id;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;
    -- Handle GL fields
    IF p_site_rec.gl_id_rec IS NULL AND p_site_rec.gl_conc_rec IS NOT NULL THEN
      BEGIN
        SELECT gl.code_combination_id
        INTO   p_site_rec.gl_id_rec
        FROM   gl_code_combinations_kfv gl
        WHERE  gl.concatenated_segments = p_site_rec.gl_conc_rec;

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    IF p_site_rec.gl_id_rev IS NULL AND p_site_rec.gl_conc_rev IS NOT NULL THEN
      BEGIN
        SELECT gl.code_combination_id
        INTO   p_site_rec.gl_id_rev
        FROM   gl_code_combinations_kfv gl
        WHERE  gl.concatenated_segments = p_site_rec.gl_conc_rev;

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    IF p_site_rec.gl_id_unearned IS NULL AND
       p_site_rec.gl_conc_unearned IS NOT NULL THEN
      BEGIN
        SELECT gl.code_combination_id
        INTO   p_site_rec.gl_id_unearned
        FROM   gl_code_combinations_kfv gl
        WHERE  gl.concatenated_segments = p_site_rec.gl_conc_unearned;

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- Update table with the id's
    UPDATE xxhz_site_interface site
    SET    cust_account_id     = nvl(p_site_rec.cust_account_id,
			 cust_account_id),
           party_id            = nvl(p_site_rec.party_id, party_id),
           org_id              = nvl(p_site_rec.org_id, org_id),
           primary_salesrep_id = nvl(p_site_rec.primary_salesrep_id,
			 primary_salesrep_id),
           site_attribute11    = nvl(p_site_rec.site_attribute11,
			 site_attribute11),
           party_site_id       = nvl(p_site_rec.party_site_id, party_site_id),
           location_id         = nvl(p_site_rec.location_id, location_id),
           gl_id_rec           = nvl(p_site_rec.gl_id_rec, gl_id_rec),
           gl_id_rev           = nvl(p_site_rec.gl_id_rec, gl_id_rev),
           gl_id_unearned      = nvl(p_site_rec.gl_id_unearned,
			 gl_id_unearned),
           cust_acct_site_id   = nvl(p_site_rec.cust_acct_site_id,
			 cust_acct_site_id),
           ship_site_use_id    = nvl(p_site_rec.ship_site_use_id,
			 ship_site_use_id),
           bill_site_use_id    = nvl(p_site_rec.bill_site_use_id,
			 bill_site_use_id),
           uses_status         = nvl(p_site_rec.uses_status, l_status),
           /*primary_flag_bill   = case when p_site_rec.primary_flag_bill is null
                                           and p_site_rec.site_use_code in ('BILL_TO','Bill To') then
                                        l_primary_flag
                                      else
                                        nvl(p_site_rec.primary_flag_bill,primary_flag_bill)
                                 end,
           primary_flag_ship   = case when p_site_rec.primary_flag_ship is null
                                           and p_site_rec.site_use_code in ('SHIP_TO','Ship To') then
                                        l_primary_flag
                                      else
                                        nvl(p_site_rec.primary_flag_ship, primary_flag_ship)
                                 end,   */
           site_use_code = CASE
		     WHEN p_site_rec.site_use_code = 'BILL_TO' THEN
		      'Bill To'
		     WHEN p_site_rec.site_use_code = 'SHIP_TO' THEN
		      'Ship To'
		     ELSE
		      site.site_use_code
		   END
    WHERE  interface_id = p_site_rec.interface_id;
    COMMIT;

    IF p_site_rec.site_use_code = 'BILL_TO' THEN
      p_site_rec.site_use_code := 'Bill To';
      --if p_site_rec.primary_flag_bill is null then
      --  p_site_rec.primary_flag_bill := l_primary_flag
      -- end if
    ELSIF p_site_rec.site_use_code = 'SHIP_TO' THEN
      p_site_rec.site_use_code := 'Ship To';
      --if p_site_rec.primary_flag_ship is null then
      --  p_site_rec.primary_flag_ship := l_primary_flag
      --end if
    END IF;

    IF p_site_rec.uses_status IS NULL THEN
      p_site_rec.uses_status := l_status;
    END IF;
    -- end 1.1

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END fill_missing_site_info;

  --------------------------------------------------------------------
  --  name:               fill_missing_contact_info
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        fill missing information to the record, this info
  --                      will be use later in the program
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE fill_missing_contact_info(p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

  BEGIN

    IF p_contact_rec.cust_account_id IS NULL AND
       p_contact_rec.parent_interface_id IS NOT NULL THEN

      SELECT a.cust_account_id
      INTO   p_contact_rec.cust_account_id
      FROM   xxhz_account_interface a
      WHERE  a.interface_id = p_contact_rec.parent_interface_id;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END fill_missing_contact_info;

  --------------------------------------------------------------------
  --  name:               set_apps_initialize
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      13/04/2014
  --  Description:        set apps initialize by the source of interface
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/04/2014    Dalit A. Raviv  initial build
  --  1.2   13/01/2015    Michal Tzvik    CHG0033182: use globals for apps_initialize
  --                                      if exception occur.
  --------------------------------------------------------------------
  PROCEDURE set_apps_initialize(p_interface_source IN VARCHAR2,
		        errbuf             OUT VARCHAR2,
		        retcode            OUT VARCHAR2) IS
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    SELECT v.attribute1,
           v.attribute2,
           v.attribute3 --,lookup_code, v.meaning, v.description
    INTO   l_user_id,
           l_resp_id,
           l_resp_appl_id
    FROM   fnd_lookup_values v
    WHERE  v.lookup_type = 'HZ_CREATED_BY_MODULES'
    AND    v.language = 'US'
    AND    v.lookup_code = p_interface_source; -- 'SALESFORCE'

    fnd_global.apps_initialize(user_id      => l_user_id, -- 4290  SALESFORCE
		       resp_id      => l_resp_id, -- 51137 CRM Service Super User Objet
		       resp_appl_id => l_resp_appl_id); -- 514   Support (obsolete)

    g_user_id      := l_user_id;
    g_resp_id      := l_resp_id;
    g_resp_appl_id := l_resp_appl_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- 1.2   13/01/2015    Michal Tzvik: use globals for apps_initialize
      --errbuf  := 'Need to define interface source at lookup - XXHZ_CREATED_BY_MODULES (AR setup)'
      --retcode := 1
      IF p_interface_source IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
		  'Interface source ''' || p_interface_source ||
		  ''' is not defined at lookup - XXHZ_CREATED_BY_MODULES (AR setup)');
      END IF;
      g_user_id      := fnd_global.user_id;
      g_resp_id      := fnd_global.resp_id;
      g_resp_appl_id := fnd_global.resp_appl_id;

      IF g_user_id IS NULL THEN
        errbuf  := 'Error: failed to set globals for apps_initialize.';
        retcode := 1;
      ELSE
        fnd_global.apps_initialize(user_id      => g_user_id,
		           resp_id      => g_resp_id,
		           resp_appl_id => g_resp_appl_id);
      END IF;
  END set_apps_initialize;

  --------------------------------------------------------------------
  --  name:               update_cust_profile_amt_api
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/04/2015
  --  Description:        CHG0034610- Upload Customer credit data from Atradius
  --                      Update customer profile amount by API
  --                      Profile amount is been created automatically when
  --                      creating customer due to setup.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.2   19/04/2015    Michal Tzvik    CHG0034610- Initial Build
  --------------------------------------------------------------------
  PROCEDURE update_cust_profile_amt_api(errbuf    OUT VARCHAR2,
			    retcode   OUT VARCHAR2,
			    p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS
    p_cpamt_rec hz_customer_profile_v2pub.cust_profile_amt_rec_type;

    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    --x_cust_acct_profile_amt_id NUMBER
    l_object_version_number    NUMBER;
    l_cust_acct_profile_amt_id NUMBER;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    begin
      SELECT hcpa.cust_acct_profile_amt_id,
             hcpa.object_version_number
      INTO   l_cust_acct_profile_amt_id,
             l_object_version_number
      FROM   hz_cust_profile_amts hcpa
      WHERE  hcpa.cust_account_id = p_acc_rec.cust_account_id
      AND    hcpa.site_use_id IS NULL
      AND    hcpa.currency_code = 'USD';
    exception
    when no_data_found then
      retcode := 1;
      errbuf := 'Customer Profile amount for currency USD does not exist for customer';
      return;
    end;

    p_cpamt_rec.cust_acct_profile_amt_id := l_cust_acct_profile_amt_id;
    --  p_cpamt_rec.cust_account_id         := p_acc_rec.cust_account_id
    -- p_cpamt_rec.cust_account_profile_id := p_cust_account_profile_id
    p_cpamt_rec.attribute1  := p_acc_rec.profile_amt_attribute1;
    p_cpamt_rec.attribute2  := p_acc_rec.profile_amt_attribute2;
    p_cpamt_rec.attribute3  := p_acc_rec.profile_amt_attribute3;
    p_cpamt_rec.attribute4  := p_acc_rec.profile_amt_attribute4;
    p_cpamt_rec.attribute5  := p_acc_rec.profile_amt_attribute5;
    p_cpamt_rec.attribute6  := p_acc_rec.profile_amt_attribute6;
    p_cpamt_rec.attribute7  := p_acc_rec.profile_amt_attribute7;
    p_cpamt_rec.attribute8  := p_acc_rec.profile_amt_attribute8;
    p_cpamt_rec.attribute9  := p_acc_rec.profile_amt_attribute9;
    p_cpamt_rec.attribute10 := p_acc_rec.profile_amt_attribute10;

    -- if you want to create the amounts at site level use this line
    -- p_cpamt_rec.site_use_id := p_site_use_id;

    --hz_customer_profile_v2pub.create_cust_profile_amt(p_init_msg_list => 'T',
    --p_check_foreign_key => 'T',
    --p_cust_profile_amt_rec => p_cpamt_rec,
    --x_cust_acct_profile_amt_id => x_cust_acct_profile_amt_id,
    --x_return_status => l_return_status,
    --x_msg_count => l_msg_count,
    --x_msg_data => l_data)

    hz_customer_profile_v2pub.update_cust_profile_amt(p_init_msg_list => 'T',

				      p_cust_profile_amt_rec => p_cpamt_rec,

				      p_object_version_number => l_object_version_number,

				      x_return_status => l_return_status,

				      x_msg_count => l_msg_count,

				      x_msg_data => l_data);
    /*
    dbms_output.put_line('***************************')
    dbms_output.put_line('Output information ....')
    dbms_output.put_line('x_cust_acct_profile_amt_id: '||x_cust_acct_profile_amt_id)
    dbms_output.put_line('x_return_status: '||x_return_status)
    dbms_output.put_line('x_msg_count: '||x_msg_count)
    dbms_output.put_line('x_msg_data: '||x_msg_data)
    dbms_output.put_line('***************************')

     IF x_msg_count >1 THEN
      FOR I IN 1..x_msg_count
       LOOP
        dbms_output.put_line(I||'. '||SubStr(FND_MSG_PUB.Get(p_encoded =&gt; FND_API.G_FALSE ), 1, 255))
      END LOOP
     END IF*/

    -----------
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E update profile amount for cust_account_id: ' ||
	     p_acc_rec.cust_account_id || ' - ' || l_msg_data;
      retcode := '1';
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    END IF;
    -----------
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'update_cust_profile_amt failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_cust_profile_amt_api;

  --------------------------------------------------------------------
  --  name:               update_cust_profile_api
  --  create by:          Diptasurjya Chatterjee
  --  Revision:           1.0
  --  creation date:      12/07/2015
  --  Description:        CHG0036474- Update Customer profile info
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/07/2015    Diptasurjya     CHG0036474- Initial Build
  --------------------------------------------------------------------
  PROCEDURE update_cust_profile_api(errbuf    OUT VARCHAR2,
			retcode   OUT VARCHAR2,
			p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS
    p_cprofile_rec hz_customer_profile_v2pub.customer_profile_rec_type;

    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    --x_cust_acct_profile_amt_id NUMBER
    l_object_version_number NUMBER;
    l_cust_acct_profile_id  NUMBER;

    my_exc EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    begin
      SELECT hcp.cust_account_profile_id,
             hcp.object_version_number
      INTO   l_cust_acct_profile_id,
             l_object_version_number
      FROM   hz_customer_profiles hcp
      WHERE  hcp.cust_account_id = p_acc_rec.cust_account_id
      AND    hcp.site_use_id IS NULL;
    exception when no_data_found then
      RAISE my_exc;
    end;

    IF l_cust_acct_profile_id IS NULL THEN
      RAISE my_exc;
    ELSE
      p_cprofile_rec.cust_account_profile_id := l_cust_acct_profile_id;
      p_cprofile_rec.standard_terms          := p_acc_rec.payment_term_id;

      hz_customer_profile_v2pub.update_customer_profile(p_init_msg_list         => 'T',
				        p_customer_profile_rec  => p_cprofile_rec,
				        p_object_version_number => l_object_version_number,
				        x_return_status         => l_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);

      -----------
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf  := 'E update profile for cust_account_id: ' ||
	       p_acc_rec.cust_account_id || ' - ' || l_msg_data;
        retcode := '1';
        fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);

          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
        END LOOP;
      END IF;
      -----------
    END IF;
  EXCEPTION
    WHEN my_exc THEN
      errbuf  := 'Customer account profile does not exist for Account ID :' ||
	     p_acc_rec.cust_account_id;
      retcode := 1;
    WHEN OTHERS THEN
      errbuf  := 'update_cust_profile_api failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_cust_profile_api;

  --------------------------------------------------------------------
  --  name:               create_account_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        1) fill variables info
  --                      2) activate oracle api to create the account
  --                      3) commit and rollback will handle by the call procedure
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   16/02/2015    Dalit A. Raviv  CHG0034398 - add the ability to create account from exists party
  --  1.2   19/04/2015    Michal Tzvik    CHG0034610- Upload Customer credit data from Atradius
  --------------------------------------------------------------------
  PROCEDURE create_account_api(errbuf    OUT VARCHAR2,
		       retcode   OUT VARCHAR2,
		       p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;

    l_cust_account_id NUMBER;
    l_account_number  VARCHAR2(30);
    l_party_id        NUMBER;
    l_party_number    VARCHAR2(30);
    l_profile_id      NUMBER;
    l_return_status   VARCHAR2(1);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_data            VARCHAR2(2000);
    l_msg_index_out   NUMBER;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    t_cust_account_rec.account_name               := p_acc_rec.account_name;
    t_cust_account_rec.date_type_preference       := 'ARRIVAL';
    t_cust_account_rec.account_number             := p_acc_rec.account_number;
    t_cust_account_rec.sales_channel_code         := p_acc_rec.sales_channel_code; -- CUSTOMER, DISTRIBUTOR, END CUSTOMER
    t_cust_account_rec.created_by_module          := p_acc_rec.interface_source; -- 'SALESFORCE'
    t_cust_account_rec.attribute4                 := p_acc_rec.attribute4;
    t_cust_account_rec.attribute_category         := p_acc_rec.attribute_category;
    t_cust_account_rec.attribute1                 := p_acc_rec.attribute1;
    t_cust_account_rec.attribute2                 := p_acc_rec.attribute2;
    t_cust_account_rec.attribute3                 := p_acc_rec.attribute3;
    t_cust_account_rec.attribute4                 := p_acc_rec.attribute4;
    t_cust_account_rec.attribute5                 := p_acc_rec.attribute5;
    t_cust_account_rec.attribute6                 := p_acc_rec.attribute6;
    t_cust_account_rec.attribute7                 := p_acc_rec.attribute7;
    t_cust_account_rec.attribute8                 := p_acc_rec.attribute8;
    t_cust_account_rec.attribute9                 := p_acc_rec.attribute9;
    t_cust_account_rec.attribute10                := p_acc_rec.attribute10;
    t_cust_account_rec.attribute11                := p_acc_rec.attribute11;
    t_cust_account_rec.attribute12                := p_acc_rec.attribute12;
    t_cust_account_rec.attribute13                := p_acc_rec.attribute13;
    t_cust_account_rec.attribute14                := p_acc_rec.attribute14;
    t_cust_account_rec.attribute15                := p_acc_rec.attribute15;
    t_cust_account_rec.attribute16                := p_acc_rec.attribute16;
    t_cust_account_rec.attribute17                := p_acc_rec.attribute17;
    t_cust_account_rec.attribute18                := p_acc_rec.attribute18;
    t_cust_account_rec.attribute19                := p_acc_rec.attribute19;
    t_cust_account_rec.attribute20                := p_acc_rec.attribute20;
    t_cust_account_rec.status                     := nvl(p_acc_rec.status,
				         'A');
    t_organization_rec.organization_name          := p_acc_rec.account_name;
    t_organization_rec.created_by_module          := p_acc_rec.interface_source; -- 'SALESFORCE'
    t_organization_rec.organization_name_phonetic := p_acc_rec.organization_name_phonetic;
    t_organization_rec.organization_type          := 'ORGANIZATION';
    t_organization_rec.party_rec.category_code    := p_acc_rec.category_code; -- DIRECT, INDIRECT
    -- Dalit A. Raviv 16/02/2015 CHG0034398
    IF p_acc_rec.party_id IS NOT NULL THEN
      t_organization_rec.party_rec.party_id := p_acc_rec.party_id;
    END IF;
    --
    t_organization_rec.party_rec.attribute_category := p_acc_rec.party_attribute_category;
    t_organization_rec.party_rec.attribute1         := p_acc_rec.party_attribute1;
    t_organization_rec.party_rec.attribute2         := p_acc_rec.party_attribute2;
    t_organization_rec.party_rec.attribute3         := p_acc_rec.party_attribute3; -- l_org_id
    t_organization_rec.party_rec.attribute4         := p_acc_rec.party_attribute4;
    t_organization_rec.party_rec.attribute5         := p_acc_rec.party_attribute5;
    t_organization_rec.party_rec.attribute6         := p_acc_rec.party_attribute6;
    t_organization_rec.party_rec.attribute7         := p_acc_rec.party_attribute7;
    t_organization_rec.party_rec.attribute8         := p_acc_rec.party_attribute8;
    t_organization_rec.party_rec.attribute9         := p_acc_rec.party_attribute9;
    t_organization_rec.party_rec.attribute10        := p_acc_rec.party_attribute10;
    t_organization_rec.party_rec.attribute11        := p_acc_rec.party_attribute11;
    t_organization_rec.party_rec.attribute12        := p_acc_rec.party_attribute12;
    t_organization_rec.party_rec.attribute13        := p_acc_rec.party_attribute13;
    t_organization_rec.party_rec.attribute14        := p_acc_rec.party_attribute14;
    t_organization_rec.party_rec.attribute15        := p_acc_rec.party_attribute15;
    t_organization_rec.party_rec.attribute16        := p_acc_rec.party_attribute16;
    t_organization_rec.party_rec.attribute17        := p_acc_rec.party_attribute17;
    t_organization_rec.party_rec.attribute18        := p_acc_rec.party_attribute18;
    t_organization_rec.party_rec.attribute19        := p_acc_rec.party_attribute19;
    t_organization_rec.party_rec.attribute20        := p_acc_rec.party_attribute20;
    -- Michal Tzvik 19.04.2015 CHG0034610
    t_organization_rec.tax_reference    := p_acc_rec.tax_reference;
    t_organization_rec.jgzz_fiscal_code := p_acc_rec.jgzz_fiscal_code;

    hz_cust_account_v2pub.create_cust_account(p_init_msg_list => 'T',

			          p_cust_account_rec => t_cust_account_rec,

			          p_organization_rec => t_organization_rec,

			          p_customer_profile_rec => t_customer_profile_rec,

			          p_create_profile_amt => 'F',

			          x_cust_account_id => l_cust_account_id, -- o nocopy n

			          x_account_number => l_account_number, -- o nocopy v

			          x_party_id => l_party_id, -- o nocopy n

			          x_party_number => l_party_number, -- o nocopy v

			          x_profile_id => l_profile_id, -- o nocopy n

			          x_return_status => l_return_status, -- o nocopy v

			          x_msg_count => l_msg_count, -- o nocopy n

			          x_msg_data => l_msg_data); -- o nocopy v

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create account: ' || t_cust_account_rec.account_number ||
	     ' - ' || l_msg_data;
      retcode := '1';
      fnd_file.put_line(fnd_file.log,
		'Customer creation failed: ' ||
		t_cust_account_rec.account_name || ' - ' ||
		t_cust_account_rec.account_number);
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;

    ELSE
      -- enter to record, the API returned values
      p_acc_rec.cust_account_id := l_cust_account_id;
      p_acc_rec.account_number  := l_account_number;
      p_acc_rec.party_id        := l_party_id;

      errbuf  := NULL;
      retcode := 0;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'create_account_api failed - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_account_api;

  --------------------------------------------------------------------
  --  name:               update_account_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        1) fill variables info
  --                      2) activate oracle api to update the account
  --                      3) commit and rollback will handle by the call procedure
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   26/04/2015    Michal Tzvik    CHG0034610 - Bug fix: replace fnd_api.g_miss_char with application value
  --  1.2 11/10/2018     Suad Ofer        CHG0043940 Add fileds to Customer update
  --------------------------------------------------------------------
  PROCEDURE update_account_api(errbuf    OUT VARCHAR2,
		       retcode   OUT VARCHAR2,
		       p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    t_cust_account_rec hz_cust_account_v2pub.cust_account_rec_type;
    -- t_organization_rec hz_party_v2pub.organization_rec_type
    l_acc_rec hz_cust_accounts%ROWTYPE;

    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    my_exception EXCEPTION;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    BEGIN
      SELECT *
      INTO   l_acc_rec
      FROM   hz_cust_accounts acc
      WHERE  acc.cust_account_id = p_acc_rec.cust_account_id;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'update_account_api - can not find record in database - ' ||
	       p_acc_rec.cust_account_id;
        retcode := 1;
        RAISE my_exception;
    END;

    t_cust_account_rec.cust_account_id := p_acc_rec.cust_account_id;
    t_cust_account_rec.account_number  := p_acc_rec.account_number; --  1.1 Michal Tzvik: Remove G_MISS: nvl(p_acc_rec.account_number , fnd_api.g_miss_char)
    IF p_acc_rec.status IS NOT NULL AND
       nvl(p_acc_rec.status, fnd_api.g_miss_char) <>
       nvl(l_acc_rec.status, fnd_api.g_miss_char) THEN
      t_cust_account_rec.status_update_date := SYSDATE;
    END IF;
    --  1.1 Michal Tzvik: Remove G_MISS
    t_cust_account_rec.status             := p_acc_rec.status; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.sales_channel_code := p_acc_rec.sales_channel_code; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.account_name       := p_acc_rec.account_name; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.customer_type      := p_acc_rec.customer_type;--CHG0043940 Add fileds to Customer update
    /* CHG0036474 - Dipta - Add price list */
    t_cust_account_rec.price_list_id := p_acc_rec.price_list_id;
    /* CHG0036474 - End */

    t_cust_account_rec.attribute_category := p_acc_rec.attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute1         := p_acc_rec.attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute2         := p_acc_rec.attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute3         := p_acc_rec.attribute3; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute4         := p_acc_rec.attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute5         := p_acc_rec.attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute6         := p_acc_rec.attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute7         := p_acc_rec.attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute8         := p_acc_rec.attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute9         := p_acc_rec.attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute10        := p_acc_rec.attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute11        := p_acc_rec.attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute12        := p_acc_rec.attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute13        := p_acc_rec.attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute14        := p_acc_rec.attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute15        := p_acc_rec.attribute15; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute16        := p_acc_rec.attribute16; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute17        := p_acc_rec.attribute17; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute18        := p_acc_rec.attribute18; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute19        := p_acc_rec.attribute19; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_account_rec.attribute20        := p_acc_rec.attribute20; -- remove nvl(... , fnd_api.g_miss_char)

    hz_cust_account_v2pub.update_cust_account(p_init_msg_list => fnd_api.g_true,

			          p_cust_account_rec => t_cust_account_rec,

			          p_object_version_number => l_acc_rec.object_version_number,

			          x_return_status => l_return_status,

			          x_msg_count => l_msg_count,

			          x_msg_data => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      errbuf  := 'E update account: ' || t_cust_account_rec.account_number ||
	     ' - ' || l_msg_data;
      retcode := '1';
      fnd_file.put_line(fnd_file.log,
		'Customer update failed: ' ||
		t_cust_account_rec.account_name || ' - ' ||
		t_cust_account_rec.account_number);
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'update_account_api failed - ' || substr(SQLERRM, 1, 240);
      retcode := 1;

  END update_account_api;

  --------------------------------------------------------------------
  --  name:               update_party_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        1) fill variables info
  --                      2) activate oracle api to update the account
  --                      3) commit and rollback will handle by the call procedure
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   21/04/2015    Michal Tzvik    CHG0034610 - Add fields to API record. Remove G_MISS
  --  1.2   20/12/2015    Diptasurjya     CHG0036474 - Add additional condition for
  --                                      duns_number
  --------------------------------------------------------------------
  PROCEDURE update_party_api(errbuf    OUT VARCHAR2,
		     retcode   OUT VARCHAR2,
		     p_entity  IN VARCHAR2,
		     p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    t_organization_rec hz_party_v2pub.organization_rec_type;
    --t_party_rec            hz_party_v2pub.party_rec_type

    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER := NULL;
    l_msg_data      VARCHAR2(2000) := NULL;
    l_data          VARCHAR2(2000) := NULL;
    l_msg_index_out NUMBER;

    --l_organization_rec     apps.hz_party_v2pub.organization_rec_type
    --l_party_ovn  NUMBER
    l_profile_id NUMBER;

    my_exception EXCEPTION;

    -- 22/04/201 Michal Tzvik CHG0034610
    l_party_rec hz_parties%ROWTYPE;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;
  fnd_file.put_line(fnd_file.log, 'DUNS Number : ' ||p_acc_rec.duns_number);
    BEGIN
      -- 22/04/201 Michal Tzvik CHG0034610: use l_party_rec instead of l_party_ovn
      SELECT * --object_version_number
      INTO   l_party_rec --l_party_ovn
      FROM   hz_parties
      WHERE  party_id = p_acc_rec.party_id;
    EXCEPTION
      WHEN OTHERS THEN
        NULL; --l_party_ovn := NULL
    END;

    t_organization_rec.party_rec.party_id := p_acc_rec.party_id;
    -- 1.1 Michal tzvik: remove G_MISS
    t_organization_rec.party_rec.category_code      := p_acc_rec.category_code; -- DIRECT, INDIRECT -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute_category := p_acc_rec.party_attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute1         := p_acc_rec.party_attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute2         := p_acc_rec.party_attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute3         := p_acc_rec.party_attribute3; -- l_org_id;-- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute4         := p_acc_rec.party_attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute5         := p_acc_rec.party_attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute6         := p_acc_rec.party_attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute7         := p_acc_rec.party_attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute8         := p_acc_rec.party_attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute9         := p_acc_rec.party_attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute10        := p_acc_rec.party_attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute11        := p_acc_rec.party_attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute12        := p_acc_rec.party_attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute13        := p_acc_rec.party_attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute14        := p_acc_rec.party_attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute15        := p_acc_rec.party_attribute15; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute16        := p_acc_rec.party_attribute16; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute17        := p_acc_rec.party_attribute17; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute18        := p_acc_rec.party_attribute18; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute19        := p_acc_rec.party_attribute19; -- remove nvl(... , fnd_api.g_miss_char)
    t_organization_rec.party_rec.attribute20        := p_acc_rec.party_attribute20; -- remove nvl(... , fnd_api.g_miss_char)
    -- 21/04/2015 Michal Tzvik CHG0034610
    t_organization_rec.jgzz_fiscal_code := p_acc_rec.jgzz_fiscal_code;
    t_organization_rec.tax_reference    := p_acc_rec.tax_reference;
    --

    if p_acc_rec.duns_number is null then -- CHG0036474 - Dipta
      t_organization_rec.duns_number_c := nvl(p_acc_rec.tax_reference,
                l_party_rec.duns_number_c); -- !!! CHG0036474 - Dipta - Why?
    else -- CHG0036474 - Dipta start
      t_organization_rec.duns_number_c := p_acc_rec.duns_number;
    end if;
    --
    t_organization_rec.organization_name_phonetic := p_acc_rec.organization_name_phonetic;
    -- CHG0036474 - Dipta end

    apps.hz_party_v2pub.update_organization(p_init_msg_list => apps.fnd_api.g_true,

			        p_organization_rec => t_organization_rec,

			        p_party_object_version_number => l_party_rec.object_version_number, -- 22/04/2015 Michal tzvik CHG0034610: replace l_party_ovn,

			        x_profile_id => l_profile_id,

			        x_return_status => l_return_status,

			        x_msg_count => l_msg_count,

			        x_msg_data => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      errbuf  := 'E update party id: ' || p_acc_rec.party_id || ' - ' ||
	     l_msg_data;
      retcode := '1';
      fnd_file.put_line(fnd_file.log,
		'party update failed, party id: ' ||
		p_acc_rec.party_id);
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_party_api - entity - ' || p_entity ||
	     ' interface_id ' || p_acc_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;

  END update_party_api;

  --------------------------------------------------------------------
  --  name:               handle_account_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/04/2014
  --  Description:        Procedure that Handle create/update account
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/04/2014    Dalit A. Raviv  initial build
  --  1.1   22/04/2015    Michal Tzvik    CHG0034610 -  Upload Customer credit data
  --  1.2   20/12/2015    Diptasurjya     CHG0036474 - Add additional condition for
  --                                      tax_reference org known as and duns_number
  --------------------------------------------------------------------
  PROCEDURE handle_account_api(errbuf    OUT VARCHAR2,
		       retcode   OUT VARCHAR2,
		       p_entity  IN VARCHAR2,
		       p_acc_rec IN OUT xxhz_account_interface%ROWTYPE) IS

    l_err_desc  VARCHAR2(500) := NULL;
    l_err_code  VARCHAR2(100) := NULL;
    l_party_rec hz_parties%ROWTYPE;

    my_exc EXCEPTION;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    IF p_acc_rec.cust_account_id IS NULL THEN
      create_account_api(errbuf    => l_err_desc, -- o v
		 retcode   => l_err_code, -- o v
		 p_acc_rec => p_acc_rec); -- i/o xxhz_account_interface%rowtype

      -- to add handle of error -> update interface table
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
        upd_log(p_err_desc     => l_err_desc, -- i v
	    p_status       => 'ERROR', -- i v
	    p_interface_id => p_acc_rec.interface_id, -- i n
	    p_entity       => 'ACCOUNT'); -- i v
        RAISE my_exc;
      END IF;
    ELSE
      -- need to update the account and then the party
      update_account_api(errbuf    => l_err_desc, -- o v
		 retcode   => l_err_code, -- o v
		 p_acc_rec => p_acc_rec -- i/o xxhz_account_interface%rowtype
		 );

     fnd_file.put_line(fnd_file.log, 'Error Code : ' ||l_err_code);

      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
        upd_log(p_err_desc     => l_err_desc, -- i v
	    p_status       => 'ERROR', -- i v
	    p_interface_id => p_acc_rec.interface_id, -- i n
	    p_entity       => 'ACCOUNT'); -- i v

        RAISE my_exc;
      ELSE
        SELECT *
        INTO   l_party_rec
        FROM   hz_parties hp
        WHERE  hp.party_id = p_acc_rec.party_id;

        IF ((p_acc_rec.party_attribute1 IS NOT NULL AND
           p_acc_rec.party_attribute1 <>
           nvl(l_party_rec.attribute1, 'DR')) OR
           (p_acc_rec.party_attribute2 IS NOT NULL AND
           p_acc_rec.party_attribute2 <>
           nvl(l_party_rec.attribute2, 'DR')) OR
           (p_acc_rec.party_attribute3 IS NOT NULL AND
           p_acc_rec.party_attribute3 <>
           nvl(l_party_rec.attribute3, 'DR')) OR
           (p_acc_rec.party_attribute4 IS NOT NULL AND
           p_acc_rec.party_attribute4 <>
           nvl(l_party_rec.attribute4, 'DR')) OR
           (p_acc_rec.party_attribute5 IS NOT NULL AND
           p_acc_rec.party_attribute5 <>
           nvl(l_party_rec.attribute5, 'DR')) OR
           (p_acc_rec.party_attribute6 IS NOT NULL AND
           p_acc_rec.party_attribute6 <>
           nvl(l_party_rec.attribute6, 'DR')) OR
           (p_acc_rec.party_attribute7 IS NOT NULL AND
           p_acc_rec.party_attribute7 <>
           nvl(l_party_rec.attribute7, 'DR')) OR
           (p_acc_rec.party_attribute8 IS NOT NULL AND
           p_acc_rec.party_attribute8 <>
           nvl(l_party_rec.attribute8, 'DR')) OR
           (p_acc_rec.party_attribute9 IS NOT NULL AND
           p_acc_rec.party_attribute9 <>
           nvl(l_party_rec.attribute9, 'DR')) OR
           (p_acc_rec.party_attribute10 IS NOT NULL AND
           p_acc_rec.party_attribute10 <>
           nvl(l_party_rec.attribute10, 'DR')) OR
           (p_acc_rec.party_attribute11 IS NOT NULL AND
           p_acc_rec.party_attribute11 <>
           nvl(l_party_rec.attribute11, 'DR')) OR
           (p_acc_rec.party_attribute12 IS NOT NULL AND
           p_acc_rec.party_attribute12 <>
           nvl(l_party_rec.attribute12, 'DR')) OR
           (p_acc_rec.party_attribute13 IS NOT NULL AND
           p_acc_rec.party_attribute13 <>
           nvl(l_party_rec.attribute13, 'DR')) OR
           (p_acc_rec.party_attribute14 IS NOT NULL AND
           p_acc_rec.party_attribute14 <>
           nvl(l_party_rec.attribute14, 'DR')) OR
           (p_acc_rec.party_attribute15 IS NOT NULL AND
           p_acc_rec.party_attribute15 <>
           nvl(l_party_rec.attribute15, 'DR')) OR
           (p_acc_rec.party_attribute16 IS NOT NULL AND
           p_acc_rec.party_attribute16 <>
           nvl(l_party_rec.attribute16, 'DR')) OR
           (p_acc_rec.party_attribute17 IS NOT NULL AND
           p_acc_rec.party_attribute17 <>
           nvl(l_party_rec.attribute17, 'DR')) OR
           (p_acc_rec.party_attribute18 IS NOT NULL AND
           p_acc_rec.party_attribute18 <>
           nvl(l_party_rec.attribute18, 'DR')) OR
           (p_acc_rec.party_attribute19 IS NOT NULL AND
           p_acc_rec.party_attribute19 <>
           nvl(l_party_rec.attribute19, 'DR')) OR
           (p_acc_rec.party_attribute20 IS NOT NULL AND
           p_acc_rec.party_attribute20 <>
           nvl(l_party_rec.attribute20, 'DR'))
           -- 21.04.2015 Michal Tzvik CHG0034610: Add conditions
           OR (p_acc_rec.jgzz_fiscal_code IS NOT NULL AND
           p_acc_rec.jgzz_fiscal_code <>
           nvl(l_party_rec.jgzz_fiscal_code, '1')) OR
           (p_acc_rec.tax_reference IS NOT NULL AND
           p_acc_rec.tax_reference <> nvl(l_party_rec.tax_reference, '1')) OR
           (p_acc_rec.organization_name_phonetic IS NOT NULL AND
           p_acc_rec.organization_name_phonetic <> nvl(l_party_rec.organization_name_phonetic, '1')) OR
           (p_acc_rec.CATEGORY_CODE IS NOT NULL AND
           p_acc_rec.CATEGORY_CODE <> nvl(l_party_rec.CATEGORY_CODE, '1')) OR
           (p_acc_rec.duns_number IS NOT NULL/* AND
           lpad(p_acc_rec.duns_number,9,'0') <> nvl(l_existing_duns, '1')*/)) THEN

          update_party_api(errbuf    => l_err_desc, -- o v
		   retcode   => l_err_code, -- o v
		   p_entity  => 'Update Party', -- i v
		   p_acc_rec => p_acc_rec); -- i/o xxhz_account_interface%rowtype

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v

	RAISE my_exc;
          END IF;
        END IF; -- update party

        -- CHG0036474 - Dipta - handle customer profile updates
        fnd_file.put_line(fnd_file.log, 'Payment Term ID : ' ||p_acc_rec.payment_term_id);
        if p_acc_rec.payment_term_id IS NOT NULL then
          update_cust_profile_api(errbuf    => l_err_desc,
              retcode   => l_err_code,
              p_acc_rec => p_acc_rec);

          IF l_err_code <> 0 THEN
            errbuf  := l_err_desc;
            retcode := 2;
            upd_log(p_err_desc     => l_err_desc, -- i v
                    p_status       => 'ERROR', -- i v
                    p_interface_id => p_acc_rec.interface_id, -- i n
                    p_entity       => 'ACCOUNT'); -- i v

            RAISE my_exc;
          END IF;
        end if;
        -- CHG0036474 - End

        -- 21.04.2015 Michal Tzvik CHG0034610: Update profile amount
        --ELSE
        if p_acc_rec.profile_amt_attribute1 IS NOT NULL
          or p_acc_rec.profile_amt_attribute2 IS NOT NULL
          or p_acc_rec.profile_amt_attribute3 IS NOT NULL
          or p_acc_rec.profile_amt_attribute4 IS NOT NULL
          or p_acc_rec.profile_amt_attribute5 IS NOT NULL
          or p_acc_rec.profile_amt_attribute6 IS NOT NULL
          or p_acc_rec.profile_amt_attribute7 IS NOT NULL
          or p_acc_rec.profile_amt_attribute8 IS NOT NULL
          or p_acc_rec.profile_amt_attribute9 IS NOT NULL
          or p_acc_rec.profile_amt_attribute10 IS NOT NULL then
          update_cust_profile_amt_api(errbuf => l_err_desc, -- o v
  			                              retcode => l_err_code, -- o v
  			                              p_acc_rec => p_acc_rec); -- i/o xxhz_account_interface%rowtype

          IF l_err_code <> 0 THEN
            errbuf  := l_err_desc;
            retcode := 2;
            upd_log(p_err_desc     => l_err_desc, -- i v
                    p_status       => 'ERROR', -- i v
                    p_interface_id => p_acc_rec.interface_id, -- i n
                    p_entity       => 'ACCOUNT'); -- i v

            RAISE my_exc;
          END IF;
        end if;
      END IF; -- update account
    END IF; -- create/update

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_account_api - entity - ' || p_entity ||
	     ' interface_id ' || p_acc_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END handle_account_api;

  --------------------------------------------------------------------
  --  name:            handle_api_status_return
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle API return error/ success
  --                   only for  contacts
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_api_status_return(p_return_status IN VARCHAR2,
			 p_msg_count     IN NUMBER,
			 p_msg_data      IN VARCHAR2,
			 p_entity        IN VARCHAR2,
			 p_err_code      OUT VARCHAR2,
			 p_err_msg       OUT VARCHAR2) IS
    l_data          VARCHAR2(2500) := NULL;
    l_msg_index_out NUMBER;

  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    IF p_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed to create - ' || p_entity || ' - ' || p_msg_data ||
	       ' - ';
      fnd_file.put_line(fnd_file.log, 'x_msg_data - ' || p_msg_data);
      fnd_file.put_line(fnd_file.log, 'Failed to create - ' || p_entity);
      IF p_msg_count > 1 THEN
        FOR i IN 1 .. p_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);

          dbms_output.put_line('l_data - ' || l_data);
          fnd_file.put_line(fnd_file.log, 'l_msg_data - ' || l_data);
          p_err_msg := substr(p_err_msg || ' - ' || l_data, 1, 500);
        END LOOP;
      END IF;

      fnd_file.put_line(fnd_file.log, 'l_msg_data - ' || p_err_msg);
      p_err_code := 1;

    END IF; --l_return_status
  END handle_api_status_return;

  --------------------------------------------------------------------
  --  name:               create_code_assignment_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      18/03/2014
  --  Description:        Procedure that call create code assignment API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_code_assignment_api(errbuf               OUT VARCHAR2,
			   retcode              OUT VARCHAR2,
			   p_entity             IN VARCHAR2,
			   p_acc_rec            IN OUT xxhz_account_interface%ROWTYPE,
			   p_code_assignment_id OUT NUMBER) IS

    l_code_assignment_id  NUMBER := NULL;
    l_return_status       VARCHAR2(1);
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(2000);
    l_data                VARCHAR2(2000);
    l_msg_index_out       NUMBER;
    t_code_assignment_rec hz_classification_v2pub.code_assignment_rec_type;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    t_code_assignment_rec.owner_table_name      := 'HZ_PARTIES';
    t_code_assignment_rec.owner_table_id        := p_acc_rec.party_id;
    t_code_assignment_rec.class_category        := 'Objet Business Type';
    t_code_assignment_rec.class_code            := g_class_code;
    t_code_assignment_rec.primary_flag          := 'N';
    t_code_assignment_rec.content_source_type   := 'USER_ENTERED';
    t_code_assignment_rec.start_date_active     := SYSDATE;
    t_code_assignment_rec.status                := 'A';
    t_code_assignment_rec.created_by_module     := p_acc_rec.interface_source; --'SALESFORCE'
    t_code_assignment_rec.actual_content_source := 'USER_ENTERED';

    hz_classification_v2pub.create_code_assignment(p_init_msg_list       => fnd_api.g_true,
				   p_code_assignment_rec => t_code_assignment_rec,
				   x_return_status       => l_return_status,
				   x_msg_count           => l_msg_count,
				   x_msg_data            => l_msg_data,
				   x_code_assignment_id  => l_code_assignment_id);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      retcode := 1;
      errbuf  := 'E create code assignment: ' || l_msg_data;

      fnd_file.put_line(fnd_file.log,
		'Creation of code assignment ' || g_class_code ||
		' for Customer number ' || p_acc_rec.account_number ||
		' is failed.');
      fnd_file.put_line(fnd_file.log,
		'x_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
      -- update interface line with error only because the account did created.
      errbuf := substr(errbuf, 1, 500);

    ELSE
      fnd_file.put_line(fnd_file.log,
		'l_code_assignment_id ' || l_code_assignment_id);
      p_code_assignment_id := l_code_assignment_id;
    END IF; -- api return status
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_code_assignment_api - entity - ' ||
	     p_entity || ' interface_id ' || p_acc_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;

  END create_code_assignment_api;

  --------------------------------------------------------------------
  --  name:               update_code_assignment_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/04/2014
  --  Description:        Procedure that call update code assignment API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/04/2014    Dalit A. Raviv  initial build
  --  1.1   12/10/2015    Diptasurjya     CHG0036474 - Change codes to handle code assignment updates
  --------------------------------------------------------------------
  PROCEDURE update_code_assignment_api(errbuf               OUT VARCHAR2,
			   retcode              OUT VARCHAR2,
			   p_entity             IN VARCHAR2,
			   p_acc_rec            IN OUT xxhz_account_interface%ROWTYPE,
			   p_code_assignment_id OUT NUMBER) IS

    l_code_assignment_id  NUMBER := NULL;
    l_return_status       VARCHAR2(1);
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(2000);
    l_data                VARCHAR2(2000);
    l_msg_index_out       NUMBER;
    t_code_assignment_rec hz_classification_v2pub.code_assignment_rec_type;
    l_ovn                 NUMBER;
    --l_code_assignment_id  number

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;
    BEGIN
      SELECT a.object_version_number,
	 a.code_assignment_id
      INTO   l_ovn,
	 l_code_assignment_id
      FROM   hz_code_assignments a
      WHERE  a.owner_table_id = p_acc_rec.party_id
      AND    a.class_code = g_class_code -- CHG0036474 - Dipta
      AND    SYSDATE BETWEEN a.start_date_active AND
	 nvl(a.end_date_active, SYSDATE); -- CHG0036474 - Dipta
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    fnd_file.put_line(fnd_file.log,
	          'Inside assignment update: ' || l_ovn || ' ' ||
	          l_code_assignment_id);
    IF l_ovn IS NOT NULL THEN
      -- CHG0036474 - Dipta
      t_code_assignment_rec.code_assignment_id := l_code_assignment_id;
      t_code_assignment_rec.owner_table_id     := p_acc_rec.party_id;
      /* CHG0036474 - Dipta */
      IF p_acc_rec.classification_status = 'I' THEN
        t_code_assignment_rec.end_date_active := SYSDATE;
      END IF;
      t_code_assignment_rec.status := nvl(p_acc_rec.classification_status,
			      'A');
      /* CHG0036474 - Dipta */
      --  t_code_assignment_rec.created_by_module     := p_acc_rec.interface_source; --'SALESFORCE'
      --  t_code_assignment_rec.actual_content_source := 'USER_ENTERED'

      hz_classification_v2pub.update_code_assignment(p_init_msg_list         => fnd_api.g_true,
				     p_code_assignment_rec   => t_code_assignment_rec,
				     p_object_version_number => l_ovn, -- i/o n
				     x_return_status         => l_return_status, -- o v
				     x_msg_count             => l_msg_count, -- o n
				     x_msg_data              => l_msg_data); -- o v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        retcode := 1;
        errbuf  := 'E update code assignment: ' || l_msg_data;

        fnd_file.put_line(fnd_file.log,
		  'Update of assignment ' || g_class_code ||
		  ' for Customer number ' ||
		  p_acc_rec.account_number || ' is failed.');
        fnd_file.put_line(fnd_file.log,
		  'x_msg_count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);

          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
        END LOOP;
        -- update interface line with error only because the account did created.
        errbuf := substr(errbuf, 1, 500);
      ELSE
        p_code_assignment_id := l_code_assignment_id;
      END IF; -- api return status
    ELSE
      -- CHG0036474 - Dipta
      errbuf  := 'Gen EXC - update_code_assignment_api - entity - ' ||
	     p_entity || ' interface_id ' || p_acc_rec.interface_id ||
	     ' - No active assignments as of this date found';
      retcode := 1;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_code_assignment_api - entity - ' ||
	     p_entity || ' interface_id ' || p_acc_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;

  END update_code_assignment_api;

  --------------------------------------------------------------------
  --  name:               handle_account_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/04/2014
  --  Description:        Procedure that Handle create/update account
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_code_assignment(errbuf               OUT VARCHAR2,
		           retcode              OUT VARCHAR2,
		           p_entity             IN VARCHAR2,
		           p_acc_rec            IN OUT xxhz_account_interface%ROWTYPE,
		           p_code_assignment_id OUT NUMBER) IS

    l_err_desc           VARCHAR2(500) := NULL;
    l_err_code           VARCHAR2(100) := NULL;
    l_code_assignment_id NUMBER := NULL;
    l_exist              VARCHAR2(10) := 'N';
    --l_class_code         varchar2(100) := null

    my_exc EXCEPTION;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    BEGIN
      SELECT 'Y'
      INTO   l_exist
      FROM   hz_code_assignments a
      WHERE  a.owner_table_id = p_acc_rec.party_id
      AND    a.class_code = g_class_code
      AND    a.class_category = 'Objet Business Type'
      AND    SYSDATE BETWEEN a.start_date_active AND
	 nvl(a.end_date_active, SYSDATE); -- CHG0036474 - Dipta
    EXCEPTION
      WHEN OTHERS THEN
        l_exist := 'N';
    END;

    fnd_file.put_line(fnd_file.log,
	          'Exists: ' || l_exist || ' ' || g_class_code);

    IF l_exist = 'N' AND g_class_code IS NOT NULL THEN
      create_code_assignment_api(errbuf               => l_err_desc, -- o v
		         retcode              => l_err_code, -- o v
		         p_entity             => 'Create Code Assignment', -- i v
		         p_acc_rec            => p_acc_rec, -- i/o xxhz_account_interface%rowtype
		         p_code_assignment_id => l_code_assignment_id);

      -- to add handle of error -> update interface table
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
        upd_log(p_err_desc     => l_err_desc, -- i v
	    p_status       => 'ERROR', -- i v
	    p_interface_id => p_acc_rec.interface_id, -- i n
	    p_entity       => 'ACCOUNT'); -- i v
        RAISE my_exc;
      ELSE
        p_code_assignment_id := l_code_assignment_id;
      END IF;
    ELSIF l_exist = 'Y' AND g_class_code IS NOT NULL THEN
      update_code_assignment_api(errbuf               => l_err_desc, -- o v
		         retcode              => l_err_code, -- o v
		         p_entity             => 'Update Code Assignment', -- i v
		         p_acc_rec            => p_acc_rec, -- i/o xxhz_account_interface%rowtype
		         p_code_assignment_id => l_code_assignment_id);
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
        upd_log(p_err_desc     => l_err_desc, -- i v
	    p_status       => 'ERROR', -- i v
	    p_interface_id => p_acc_rec.interface_id, -- i n
	    p_entity       => 'ACCOUNT'); -- i v

        RAISE my_exc;
      ELSE
        p_code_assignment_id := l_code_assignment_id;
      END IF;
    END IF; -- create/update

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_code_assignment - entity - ' || p_entity ||
	     ' interface_id ' || p_acc_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END handle_code_assignment;

  --------------------------------------------------------------------
  --  name:               create_email_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will create email contact points
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_email_contact_point_api(errbuf               OUT VARCHAR2,
			       retcode              OUT VARCHAR2,
			       p_party_id           IN NUMBER,
			       p_contact_point_type IN VARCHAR2,
			       p_email_format       IN VARCHAR2,
			       p_interface_source   IN VARCHAR2,
			       p_primary_flag       IN VARCHAR2,
			       p_status             IN VARCHAR2,
			       p_email_address      IN VARCHAR2,
			       p_entity             IN VARCHAR2,
			       p_interface_id       IN NUMBER,
			       p_contact_point_id   OUT NUMBER) IS

    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;

    my_exception EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_contact_point_rec.owner_table_name := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id   := p_party_id;
    l_contact_point_rec.primary_flag     := p_primary_flag;
    l_contact_point_rec.status           := nvl(p_status, 'A');

    l_contact_point_rec.created_by_module  := p_interface_source; -- 'SALESFORCE'
    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'EMAIL'
    l_email_rec.email_format               := p_email_format; -- 'MAILTEXT'
    l_email_rec.email_address              := p_email_address;

    hz_contact_point_v2pub.create_email_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				      p_contact_point_rec => l_contact_point_rec,
				      p_email_rec         => l_email_rec,
				      x_contact_point_id  => l_contact_point_id, -- o n
				      x_return_status     => l_return_status, -- o v
				      x_msg_count         => l_msg_count, -- o n
				      x_msg_data          => l_msg_data); -- o v

    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => 'EMAIL', -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg || ' - party_id ' || p_party_id ||
	     ' interface_id ' || p_interface_id || chr(10);
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		'Email contact point id ' || l_contact_point_id);
      p_contact_point_id := l_contact_point_id;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_url_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;

  END create_email_contact_point_api;

  --------------------------------------------------------------------
  --  name:               update_email_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will create email contact points
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal Tzvik    CHG0034610 - Remove g_miss
  --------------------------------------------------------------------
  PROCEDURE update_email_contact_point_api(errbuf               OUT VARCHAR2,
			       retcode              OUT VARCHAR2,
			       p_party_id           IN NUMBER,
			       p_contact_point_type IN VARCHAR2,
			       p_email_format       IN VARCHAR2,
			       p_primary_flag       IN VARCHAR2,
			       p_status             IN VARCHAR2,
			       p_email_address      IN VARCHAR2,
			       p_entity             IN VARCHAR2,
			       p_interface_id       IN NUMBER,
			       p_contact_point_id   IN NUMBER) IS

    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;
    l_ovn               NUMBER;

    my_exception EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    --l_contact_point_rec.owner_table_name   := 'HZ_PARTIES'
    --l_contact_point_rec.owner_table_id     := p_party_id
    l_contact_point_rec.contact_point_id := p_contact_point_id;
    -- 1.1 Michal Tzvik Remove G_MISS
    l_contact_point_rec.primary_flag := p_primary_flag; -- remove nvl(... , fnd_api.g_miss_char)
    l_contact_point_rec.status       := nvl(p_status, 'A');

    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'EMAIL'
    l_email_rec.email_format               := p_email_format; -- 'MAILTEXT'
    l_email_rec.email_address              := p_email_address; -- remove nvl(... , fnd_api.g_miss_char)

    BEGIN
      SELECT p.object_version_number
      INTO   l_ovn
      FROM   hz_contact_points p
      WHERE  p.contact_point_id = p_contact_point_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_ovn := NULL;
    END;

    hz_contact_point_v2pub.update_email_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				      p_contact_point_rec     => l_contact_point_rec,
				      p_email_rec             => l_email_rec,
				      p_object_version_number => l_ovn, -- i n
				      x_return_status         => l_return_status, -- o v
				      x_msg_count             => l_msg_count, -- o n
				      x_msg_data              => l_msg_data); -- o v

    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => 'EMAIL', -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg || ' - party_id ' || p_party_id ||
	     ' interface_id ' || p_interface_id || chr(10);
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		'Email contact point id ' || l_contact_point_id);
      --p_contact_point_id := l_contact_point_id
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_url_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;

  END update_email_contact_point_api;

  --------------------------------------------------------------------
  --  name:               create_url_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will create url contact points
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_url_contact_point_api(errbuf               OUT VARCHAR2,
			     retcode              OUT VARCHAR2,
			     p_party_id           IN NUMBER,
			     p_contact_point_type IN VARCHAR2,
			     p_interface_source   IN VARCHAR2,
			     p_status             IN VARCHAR2,
			     p_primary_flag       IN VARCHAR2,
			     p_web_type           IN VARCHAR2,
			     p_url                IN VARCHAR2,
			     p_entity             IN VARCHAR2,
			     p_interface_id       IN NUMBER,
			     p_contact_point_id   OUT NUMBER) IS

    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_web_rec           hz_contact_point_v2pub.web_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;

    my_exception EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_contact_point_rec.owner_table_name  := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id    := p_party_id;
    l_contact_point_rec.primary_flag      := p_primary_flag;
    l_contact_point_rec.created_by_module := p_interface_source; -- 'SALESFORCE'

    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'WEB'
    l_contact_point_rec.status             := nvl(p_status, 'A'); -- nvl(p_acc_rec.web_status,'A')
    l_web_rec.web_type                     := p_web_type; -- 'HTML' -- this is an undefined value no validation
    l_web_rec.url                          := p_url;

    hz_contact_point_v2pub.create_web_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				    p_contact_point_rec => l_contact_point_rec,
				    p_web_rec           => l_web_rec,
				    x_contact_point_id  => l_contact_point_id, -- o n
				    x_return_status     => l_return_status, -- o v
				    x_msg_count         => l_msg_count, -- o n
				    x_msg_data          => l_msg_data); -- o v
    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => p_contact_point_type, -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg || ' - party_id ' || p_party_id ||
	     ' interface_id ' || p_interface_id || chr(10);
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		p_entity || ' contact point id ' ||
		l_contact_point_id);
      p_contact_point_id := l_contact_point_id;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_url_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;

  END create_url_contact_point_api;

  --------------------------------------------------------------------
  --  name:               updatee_url_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will update url contact points
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal Tzvik    CHG0034610 - Remove g_miss
  --------------------------------------------------------------------
  PROCEDURE update_url_contact_point_api(errbuf               OUT VARCHAR2,
			     retcode              OUT VARCHAR2,
			     p_party_id           IN NUMBER,
			     p_contact_point_type IN VARCHAR2,
			     p_status             IN VARCHAR2,
			     p_primary_flag       IN VARCHAR2,
			     p_web_type           IN VARCHAR2,
			     p_url                IN VARCHAR2,
			     p_entity             IN VARCHAR2,
			     p_interface_id       IN NUMBER,
			     p_contact_point_id   IN NUMBER) IS

    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_web_rec           hz_contact_point_v2pub.web_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;
    l_ovn               NUMBER;

    my_exception EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    --l_contact_point_rec.owner_table_name  := 'HZ_PARTIES'
    --l_contact_point_rec.owner_table_id    := p_party_id
    l_contact_point_rec.contact_point_id := p_contact_point_id;
    -- 1.1 Michal Tzvik: Remove G_MISS
    l_contact_point_rec.primary_flag       := p_primary_flag; -- remove nvl(... , fnd_api.g_miss_char)
    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'WEB'
    l_contact_point_rec.status             := nvl(p_status, 'A'); -- nvl(p_acc_rec.web_status,'A')
    l_web_rec.web_type                     := p_web_type; -- 'HTML' -- this is an undefined value no validation-- remove nvl(... , fnd_api.g_miss_char)
    l_web_rec.url                          := p_url; -- remove nvl(... , fnd_api.g_miss_char)

    BEGIN
      SELECT p.object_version_number
      INTO   l_ovn
      FROM   hz_contact_points p
      WHERE  p.contact_point_id = p_contact_point_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_ovn := NULL;
    END;

    hz_contact_point_v2pub.update_web_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				    p_contact_point_rec     => l_contact_point_rec,
				    p_web_rec               => l_web_rec,
				    p_object_version_number => l_ovn, -- i/o n
				    x_return_status         => l_return_status, -- o v
				    x_msg_count             => l_msg_count, -- o n
				    x_msg_data              => l_msg_data); -- o v
    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => p_contact_point_type, -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg || ' - party_id ' || p_party_id ||
	     ' interface_id ' || p_interface_id || chr(10);
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		p_entity || ' contact point id ' ||
		l_contact_point_id);
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_url_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;

  END update_url_contact_point_api;

  --------------------------------------------------------------------
  --  name:               create_phone_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will create phone type of contact points
  --                      PHONE, MOBILE, FAX
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_phone_contact_point_api(errbuf               OUT VARCHAR2,
			       retcode              OUT VARCHAR2,
			       p_party_id           IN NUMBER,
			       p_contact_point_type IN VARCHAR2,
			       p_phone_line_type    IN VARCHAR2,
			       p_interface_source   IN VARCHAR2,
			       p_status             IN VARCHAR2,
			       p_primary_flag       IN VARCHAR2,
			       p_concate_number     IN VARCHAR2,
			       p_area_code          IN VARCHAR2,
			       p_country_code       IN VARCHAR2,
			       p_number             IN VARCHAR2,
			       p_extension          IN VARCHAR2,
			       p_entity             IN VARCHAR2,
			       p_interface_id       IN NUMBER,
			       p_contact_point_id   OUT NUMBER) IS

    -- contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;

    my_exception EXCEPTION;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    -- each point type have different variable that creates the point
    l_contact_point_rec.owner_table_name   := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id     := p_party_id; -- p_acc_rec.party_id
    l_contact_point_rec.created_by_module  := p_interface_source; -- p_acc_rec.interface_source --'SALESFORCE'
    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'PHONE'
    l_contact_point_rec.status             := nvl(p_status, 'A'); -- nvl(p_acc_rec.phone_status,'A')
    l_phone_rec.phone_line_type            := p_phone_line_type; -- 'GEN'
    l_contact_point_rec.primary_flag       := p_primary_flag; -- nvl(p_acc_rec.phone_primary_flag,'Y')

    l_phone_rec.phone_number       := p_number; -- p_acc_rec.phone_number
    l_phone_rec.phone_area_code    := p_area_code; -- p_acc_rec.phone_area_code
    l_phone_rec.phone_country_code := p_country_code; -- p_acc_rec.phone_country_code
    l_phone_rec.phone_extension    := p_extension; -- p_acc_rec.phone_extension
    l_phone_rec.raw_phone_number   := p_concate_number; -- p_acc_rec.phone

    hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				      p_contact_point_rec => l_contact_point_rec,
				      p_phone_rec         => l_phone_rec,
				      x_contact_point_id  => l_contact_point_id, -- o n
				      x_return_status     => l_return_status, -- o v
				      x_msg_count         => l_msg_count, -- o n
				      x_msg_data          => l_msg_data); -- o v
    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => p_contact_point_type || ', ' ||
				p_phone_line_type, -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg;
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		p_entity || ' contact point id ' ||
		l_contact_point_id);
      --p_acc_rec.phone_contact_point_id := l_contact_point_id
      p_contact_point_id := l_contact_point_id;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_phone_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_phone_contact_point_api;

  --------------------------------------------------------------------
  --  name:               update_phone_contact_point_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/04/2014
  --  Description:        Procedure that will update phone type of contact points
  --                      PHONE, MOBILE, FAX
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/04/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal Tzvik    CHG0034610: Remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_phone_contact_point_api(errbuf               OUT VARCHAR2,
			       retcode              OUT VARCHAR2,
			       p_party_id           IN NUMBER,
			       p_contact_point_type IN VARCHAR2,
			       p_phone_line_type    IN VARCHAR2,
			       p_status             IN VARCHAR2,
			       p_primary_flag       IN VARCHAR2,
			       p_concate_number     IN VARCHAR2,
			       p_area_code          IN VARCHAR2,
			       p_country_code       IN VARCHAR2,
			       p_number             IN VARCHAR2,
			       p_extension          IN VARCHAR2,
			       p_entity             IN VARCHAR2,
			       p_interface_id       IN NUMBER,
			       p_contact_point_id   IN NUMBER) IS

    -- contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(500) := NULL;
    l_ovn               NUMBER := NULL;

    my_exception EXCEPTION;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    -- each point type have different variable that creates the point
    --l_contact_point_rec.owner_table_name   := 'HZ_PARTIES'
    --l_contact_point_rec.owner_table_id     := p_party_id           -- p_acc_rec.party_id;

    -- 1.1 Michal Tzvik: Remove G_MISS
    l_contact_point_rec.contact_point_id   := p_contact_point_id;
    l_contact_point_rec.contact_point_type := p_contact_point_type; -- 'PHONE'
    l_contact_point_rec.status             := nvl(p_status, 'A'); -- nvl(p_acc_rec.phone_status,'A')
    l_phone_rec.phone_line_type            := p_phone_line_type; -- 'GEN'
    l_contact_point_rec.primary_flag       := p_primary_flag; -- remove nvl(... , fnd_api.g_miss_char)

    l_phone_rec.phone_number       := p_number; -- p_acc_rec.phone_number-- remove nvl(... , fnd_api.g_miss_char)
    l_phone_rec.phone_area_code    := p_area_code; -- p_acc_rec.phone_area_code-- remove nvl(... , fnd_api.g_miss_char)
    l_phone_rec.phone_country_code := p_country_code; -- p_acc_rec.phone_country_code-- remove nvl(... , fnd_api.g_miss_char)
    l_phone_rec.phone_extension    := p_extension; -- p_acc_rec.phone_extension-- remove nvl(... , fnd_api.g_miss_char)
    l_phone_rec.raw_phone_number   := p_concate_number; -- p_acc_rec.phone-- remove nvl(... , fnd_api.g_miss_char)

    BEGIN
      SELECT p.object_version_number
      INTO   l_ovn
      FROM   hz_contact_points p
      WHERE  p.contact_point_id = p_contact_point_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_ovn := NULL;
    END;

    hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				      p_contact_point_rec     => l_contact_point_rec,
				      p_phone_rec             => l_phone_rec,
				      p_object_version_number => l_ovn,
				      x_return_status         => l_return_status, -- o v
				      x_msg_count             => l_msg_count, -- o n
				      x_msg_data              => l_msg_data); -- o v
    l_err_code := 0;
    l_err_msg  := NULL;
    handle_api_status_return(p_return_status => l_return_status, -- i v
		     p_msg_count     => l_msg_count, -- i n
		     p_msg_data      => l_msg_data, -- i v
		     p_entity        => p_contact_point_type || ', ' ||
				p_phone_line_type, -- i v
		     p_err_code      => l_err_code, -- o v
		     p_err_msg       => l_err_msg); -- o v
    IF l_err_code = 1 THEN
      errbuf  := l_err_msg || ' - party_id ' || p_party_id ||
	     ' interface_id ' || p_interface_id || chr(10);
      retcode := 1;
      RAISE my_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
		p_entity || ' contact point id ' ||
		l_contact_point_id);
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_phone_contact_point_api - entity - ' ||
	     p_entity || ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_phone_contact_point_api;

  --------------------------------------------------------------------
  --  name:               handle_contact_point
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      31/03/2014
  --  Description:        Procedure that will handle all types of contact point create/upd
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_contact_point(errbuf        OUT VARCHAR2,
		         retcode       OUT VARCHAR2,
		         p_entity      IN VARCHAR2,
		         p_acc_rec     IN xxhz_account_interface%ROWTYPE,
		         p_contact_rec IN xxhz_contact_interface%ROWTYPE,
		         --p_cust_account_role_id  in  number,
		         p_source            IN VARCHAR2,
		         p_phone_contact_id  OUT NUMBER,
		         p_fax_contact_id    OUT NUMBER,
		         p_mobile_contact_id OUT NUMBER,
		         p_web_contact_id    OUT NUMBER,
		         p_email_contact_id  OUT NUMBER) IS

    l_err_desc         VARCHAR2(500) := NULL;
    l_err_code         VARCHAR2(100) := NULL;
    l_contact_point_id NUMBER := NULL;

    my_exc EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    IF p_source = 'ACCOUNT' THEN
      IF (p_acc_rec.fax IS NOT NULL OR p_acc_rec.fax_number IS NOT NULL) AND
         p_acc_rec.fax_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_acc_rec.party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'FAX', -- i v
			   p_interface_source   => p_acc_rec.interface_source, -- i v
			   p_status             => nvl(p_acc_rec.fax_status,
					       'A'), -- i v
			   p_primary_flag       => nvl(p_acc_rec.fax_primary_flag,
					       'Y'), -- i v
			   p_concate_number     => p_acc_rec.fax, -- i v
			   p_area_code          => p_acc_rec.fax_area_code, -- i v
			   p_country_code       => p_acc_rec.fax_country_code, -- i v
			   p_number             => p_acc_rec.fax_number, -- i v
			   p_extension          => NULL, -- i v
			   p_entity             => 'Create Fax', -- i v
			   p_interface_id       => p_acc_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_fax_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_acc_rec.fax_contact_point_id IS NOT NULL THEN
        IF (p_acc_rec.fax_status IS NOT NULL OR
           p_acc_rec.fax_primary_flag IS NOT NULL OR
           p_acc_rec.fax IS NOT NULL OR
           p_acc_rec.fax_area_code IS NOT NULL OR
           p_acc_rec.fax_country_code IS NOT NULL OR
           p_acc_rec.fax_number IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_acc_rec.party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'FAX', -- i v
			     p_status             => p_acc_rec.fax_status, -- i v
			     p_primary_flag       => p_acc_rec.fax_primary_flag, -- i v
			     p_concate_number     => p_acc_rec.fax, -- i v
			     p_area_code          => p_acc_rec.fax_area_code, -- i v
			     p_country_code       => p_acc_rec.fax_country_code, -- i v
			     p_number             => p_acc_rec.fax_number, -- i v
			     p_extension          => NULL, -- i v
			     p_entity             => 'Update Fax', -- i v
			     p_interface_id       => p_acc_rec.interface_id, -- i n
			     p_contact_point_id   => p_acc_rec.fax_contact_point_id -- o n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v
	RAISE my_exc;
          ELSE
	p_fax_contact_id := p_acc_rec.fax_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Fax

      IF (p_acc_rec.mobile IS NOT NULL OR
         p_acc_rec.mobile_number IS NOT NULL) AND
         p_acc_rec.mobile_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_acc_rec.party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'MOBILE', -- i v
			   p_interface_source   => p_acc_rec.interface_source, -- i v
			   p_status             => nvl(p_acc_rec.mobile_status,
					       'A'), -- i v
			   p_primary_flag       => nvl(p_acc_rec.mobile_primary_flag,
					       'Y'), -- i v
			   p_concate_number     => p_acc_rec.mobile, -- i v
			   p_area_code          => p_acc_rec.mobile_area_code, -- i v
			   p_country_code       => p_acc_rec.mobile_country_code, -- i v
			   p_number             => p_acc_rec.mobile_number, -- i v
			   p_extension          => NULL, -- i v
			   p_entity             => 'Create Mobile', -- i v
			   p_interface_id       => p_acc_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_mobile_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_acc_rec.mobile_contact_point_id IS NOT NULL THEN
        IF (p_acc_rec.mobile_status IS NOT NULL OR
           p_acc_rec.mobile_primary_flag IS NOT NULL OR
           p_acc_rec.mobile IS NOT NULL OR
           p_acc_rec.mobile_area_code IS NOT NULL OR
           p_acc_rec.mobile_country_code IS NOT NULL OR
           p_acc_rec.mobile_number IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_acc_rec.party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'MOBILE', -- i v
			     p_status             => p_acc_rec.mobile_status, -- i v
			     p_primary_flag       => p_acc_rec.mobile_primary_flag, -- i v
			     p_concate_number     => p_acc_rec.mobile, -- i v
			     p_area_code          => p_acc_rec.mobile_area_code, -- i v
			     p_country_code       => p_acc_rec.mobile_country_code, -- i v
			     p_number             => p_acc_rec.mobile_number, -- i v
			     p_extension          => NULL, -- i v
			     p_entity             => 'Update Mobile', -- i v
			     p_interface_id       => p_acc_rec.interface_id, -- i n
			     p_contact_point_id   => p_acc_rec.mobile_contact_point_id -- o n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v
	RAISE my_exc;
          ELSE
	p_mobile_contact_id := p_acc_rec.mobile_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Mobile

      IF (p_acc_rec.phone IS NOT NULL OR p_acc_rec.phone_number IS NOT NULL) AND
         p_acc_rec.phone_contact_point_id IS NULL THEN
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_acc_rec.party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'GEN', -- i v
			   p_interface_source   => p_acc_rec.interface_source, -- i v
			   p_status             => nvl(p_acc_rec.phone_status,
					       'A'), -- i v
			   p_primary_flag       => nvl(p_acc_rec.phone_primary_flag,
					       'Y'), -- i v
			   p_concate_number     => p_acc_rec.phone, -- i v
			   p_area_code          => p_acc_rec.phone_area_code, -- i v
			   p_country_code       => p_acc_rec.phone_country_code, -- i v
			   p_number             => p_acc_rec.phone_number, -- i v
			   p_extension          => p_acc_rec.phone_extension, -- i v
			   p_entity             => 'Create Phone', -- i v
			   p_interface_id       => p_acc_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_phone_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_acc_rec.phone_contact_point_id IS NOT NULL THEN
        IF (p_acc_rec.phone_primary_flag IS NOT NULL OR
           p_acc_rec.phone_status IS NOT NULL OR
           p_acc_rec.phone IS NOT NULL OR
           p_acc_rec.phone_area_code IS NOT NULL OR
           p_acc_rec.phone_country_code IS NOT NULL OR
           p_acc_rec.phone_number IS NOT NULL OR
           p_acc_rec.phone_extension IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_acc_rec.party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'GEN', -- i v
			     p_status             => p_acc_rec.phone_status, -- i v
			     p_primary_flag       => p_acc_rec.phone_primary_flag, -- i v
			     p_concate_number     => p_acc_rec.phone, -- i v
			     p_area_code          => p_acc_rec.phone_area_code, -- i v
			     p_country_code       => p_acc_rec.phone_country_code, -- i v
			     p_number             => p_acc_rec.phone_number, -- i v
			     p_extension          => p_acc_rec.phone_extension, -- i v
			     p_entity             => 'Update Phone', -- i v
			     p_interface_id       => p_acc_rec.interface_id, -- i n
			     p_contact_point_id   => p_acc_rec.phone_contact_point_id -- i n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v
	RAISE my_exc;
          ELSE
	p_phone_contact_id := p_acc_rec.phone_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Phone

      IF p_acc_rec.email_address IS NOT NULL AND
         p_acc_rec.email_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;

        create_email_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_acc_rec.party_id, -- i n
			   p_contact_point_type => 'EMAIL', -- i v
			   p_email_format       => 'MAILTEXT', -- i v
			   p_interface_source   => p_acc_rec.interface_source, -- i v
			   p_primary_flag       => nvl(p_acc_rec.email_primary_flag,
					       'Y'), -- i v
			   p_status             => nvl(p_acc_rec.email_status,
					       'A'), -- i v
			   p_email_address      => p_acc_rec.email_address, -- i v
			   p_entity             => 'Create Email', -- i v
			   p_interface_id       => p_acc_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_email_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_acc_rec.email_contact_point_id IS NOT NULL THEN
        -- check if there is any change to update
        IF p_acc_rec.email_address IS NOT NULL OR
           p_acc_rec.email_status IS NOT NULL OR
           p_acc_rec.email_primary_flag IS NOT NULL THEN

          update_email_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_acc_rec.party_id, -- i n
			     p_contact_point_type => 'EMAIL', -- i v
			     p_email_format       => 'MAILTEXT', -- i v
			     p_primary_flag       => p_acc_rec.email_primary_flag, -- i v
			     p_status             => p_acc_rec.email_status, -- i v
			     p_email_address      => p_acc_rec.email_address, -- i v
			     p_entity             => 'Update Email', -- i v
			     p_interface_id       => p_acc_rec.interface_id, -- i n
			     p_contact_point_id   => p_acc_rec.email_contact_point_id -- i n
			     );
          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v
	RAISE my_exc;
          ELSE
	p_email_contact_id := p_acc_rec.email_contact_point_id;
          END IF;
        END IF; -- check any change to upd
      END IF; -- Case Email

      IF p_acc_rec.url IS NOT NULL AND
         p_acc_rec.web_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;

        create_url_contact_point_api(errbuf               => l_err_desc, -- o v
			 retcode              => l_err_code, -- o v
			 p_party_id           => p_acc_rec.party_id, -- i n
			 p_contact_point_type => 'WEB', -- i v
			 p_interface_source   => p_acc_rec.interface_source, -- i v
			 p_status             => nvl(p_acc_rec.web_status,
					     'A'), -- i v
			 p_primary_flag       => nvl(p_acc_rec.web_primary_flag,
					     'Y'), -- i v
			 p_web_type           => 'HTML', -- i v
			 p_url                => p_acc_rec.url, -- i v
			 p_entity             => 'Create Url', -- i v
			 p_interface_id       => p_acc_rec.interface_id, -- i n
			 p_contact_point_id   => l_contact_point_id -- o n
			 );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_web_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_acc_rec.web_contact_point_id IS NOT NULL THEN
        IF p_acc_rec.web_status IS NOT NULL OR
           p_acc_rec.web_primary_flag IS NOT NULL OR
           p_acc_rec.url IS NOT NULL THEN

          update_url_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_acc_rec.party_id, -- i n
			   p_contact_point_type => 'WEB', -- i v
			   p_status             => p_acc_rec.web_status, -- i v
			   p_primary_flag       => p_acc_rec.web_primary_flag, -- i v
			   p_web_type           => 'HTML', -- i v
			   p_url                => p_acc_rec.url, -- i v
			   p_entity             => 'Update Url', -- i v
			   p_interface_id       => p_acc_rec.interface_id, -- i n
			   p_contact_point_id   => p_acc_rec.web_contact_point_id -- i n
			   );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_acc_rec.interface_id, -- i n
	        p_entity       => 'ACCOUNT'); -- i v
	RAISE my_exc;
          ELSE
	p_web_contact_id := p_acc_rec.web_contact_point_id;
          END IF;
        END IF; -- check for update
      END IF; -- Case url

    ELSIF p_source = 'CONTACT' THEN
      IF (p_contact_rec.fax IS NOT NULL OR
         p_contact_rec.fax_number IS NOT NULL) AND
         p_contact_rec.fax_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_contact_rec.contact_party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'FAX', -- i v
			   p_interface_source   => p_contact_rec.interface_source, -- i v
			   p_status             => nvl(p_contact_rec.fax_status,
					       'A'), -- i v
			   p_primary_flag       => nvl(p_contact_rec.fax_primary_flag,
					       'Y'), -- i v
			   p_concate_number     => p_contact_rec.fax, -- i v
			   p_area_code          => p_contact_rec.fax_area_code, -- i v
			   p_country_code       => p_contact_rec.fax_country_code, -- i v
			   p_number             => p_contact_rec.fax_number, -- i v
			   p_extension          => NULL, -- i v
			   p_entity             => 'Create Fax', -- i v
			   p_interface_id       => p_contact_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_contact_rec.interface_id, -- i n
	      p_entity       => 'CONTACT'); -- i v
          RAISE my_exc;
        ELSE
          p_fax_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_contact_rec.fax_contact_point_id IS NOT NULL THEN
        IF (p_contact_rec.fax_status IS NOT NULL OR
           p_contact_rec.fax_primary_flag IS NOT NULL OR
           p_contact_rec.fax IS NOT NULL OR
           p_contact_rec.fax_area_code IS NOT NULL OR
           p_contact_rec.fax_country_code IS NOT NULL OR
           p_contact_rec.fax_number IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_contact_rec.contact_party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'FAX', -- i v
			     p_status             => p_contact_rec.fax_status, -- i v
			     p_primary_flag       => p_contact_rec.fax_primary_flag, -- i v
			     p_concate_number     => p_contact_rec.fax, -- i v
			     p_area_code          => p_contact_rec.fax_area_code, -- i v
			     p_country_code       => p_contact_rec.fax_country_code, -- i v
			     p_number             => p_contact_rec.fax_number, -- i v
			     p_extension          => NULL, -- i v
			     p_entity             => 'Update Fax', -- i v
			     p_interface_id       => p_contact_rec.interface_id, -- i n
			     p_contact_point_id   => p_contact_rec.fax_contact_point_id -- o n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_contact_rec.interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	RAISE my_exc;
          ELSE
	p_fax_contact_id := p_contact_rec.fax_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Fax

      IF (p_contact_rec.mobile IS NOT NULL OR
         p_contact_rec.mobile_number IS NOT NULL) AND
         p_contact_rec.mobile_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_contact_rec.contact_party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'MOBILE', -- i v
			   p_interface_source   => p_contact_rec.interface_source, -- i v
			   p_status             => p_contact_rec.mobile_status, -- i v
			   p_primary_flag       => p_contact_rec.mobile_primary_flag, -- i v
			   p_concate_number     => p_contact_rec.mobile, -- i v
			   p_area_code          => p_contact_rec.mobile_area_code, -- i v
			   p_country_code       => p_contact_rec.mobile_country_code, -- i v
			   p_number             => p_contact_rec.mobile_number, -- i v
			   p_extension          => NULL, -- i v
			   p_entity             => 'Create Mobile', -- i v
			   p_interface_id       => p_contact_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_contact_rec.interface_id, -- i n
	      p_entity       => 'CONTACT'); -- i v
          RAISE my_exc;
        ELSE
          p_mobile_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_contact_rec.mobile_contact_point_id IS NOT NULL THEN
        IF (p_contact_rec.mobile_status IS NOT NULL OR
           p_contact_rec.mobile_primary_flag IS NOT NULL OR
           p_contact_rec.mobile IS NOT NULL OR
           p_contact_rec.mobile_area_code IS NOT NULL OR
           p_contact_rec.mobile_country_code IS NOT NULL OR
           p_contact_rec.mobile_number IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_contact_rec.contact_party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'MOBILE', -- i v
			     p_status             => p_contact_rec.mobile_status, -- i v
			     p_primary_flag       => p_contact_rec.mobile_primary_flag, -- i v
			     p_concate_number     => p_contact_rec.mobile, -- i v
			     p_area_code          => p_contact_rec.mobile_area_code, -- i v
			     p_country_code       => p_contact_rec.mobile_country_code, -- i v
			     p_number             => p_contact_rec.mobile_number, -- i v
			     p_extension          => NULL, -- i v
			     p_entity             => 'Update Mobile', -- i v
			     p_interface_id       => p_contact_rec.interface_id, -- i n
			     p_contact_point_id   => p_contact_rec.mobile_contact_point_id -- o n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_contact_rec.interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	RAISE my_exc;
          ELSE
	p_mobile_contact_id := p_contact_rec.mobile_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Mobile

      IF (p_contact_rec.phone IS NOT NULL OR
         p_contact_rec.phone_number IS NOT NULL) AND
         p_contact_rec.phone_contact_point_id IS NULL THEN
        create_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_contact_rec.contact_party_id, -- i n
			   p_contact_point_type => 'PHONE', -- i v
			   p_phone_line_type    => 'GEN', -- i v
			   p_interface_source   => p_contact_rec.interface_source, -- i v
			   p_status             => nvl(p_contact_rec.phone_status,
					       'A'), -- i v
			   p_primary_flag       => nvl(p_contact_rec.phone_primary_flag,
					       'Y'), -- i v
			   p_concate_number     => p_contact_rec.phone, -- i v
			   p_area_code          => p_contact_rec.phone_area_code, -- i v
			   p_country_code       => p_contact_rec.phone_country_code, -- i v
			   p_number             => p_contact_rec.phone_number, -- i v
			   p_extension          => p_contact_rec.phone_extension, -- i v
			   p_entity             => 'Create Phone', -- i v
			   p_interface_id       => p_contact_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_acc_rec.interface_id, -- i n
	      p_entity       => 'ACCOUNT'); -- i v
          RAISE my_exc;
        ELSE
          p_phone_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_contact_rec.phone_contact_point_id IS NOT NULL THEN
        IF (p_contact_rec.phone_primary_flag IS NOT NULL OR
           p_contact_rec.phone_status IS NOT NULL OR
           p_contact_rec.phone IS NOT NULL OR
           p_contact_rec.phone_area_code IS NOT NULL OR
           p_contact_rec.phone_country_code IS NOT NULL OR
           p_contact_rec.phone_number IS NOT NULL OR
           p_contact_rec.phone_extension IS NOT NULL) THEN
          update_phone_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_contact_rec.contact_party_id, -- i n
			     p_contact_point_type => 'PHONE', -- i v
			     p_phone_line_type    => 'GEN', -- i v
			     p_status             => p_contact_rec.phone_status, -- i v
			     p_primary_flag       => p_contact_rec.phone_primary_flag, -- i v
			     p_concate_number     => p_contact_rec.phone, -- i v
			     p_area_code          => p_contact_rec.phone_area_code, -- i v
			     p_country_code       => p_contact_rec.phone_country_code, -- i v
			     p_number             => p_contact_rec.phone_number, -- i v
			     p_extension          => p_contact_rec.phone_extension, -- i v
			     p_entity             => 'Update Phone', -- i v
			     p_interface_id       => p_contact_rec.interface_id, -- i n
			     p_contact_point_id   => p_contact_rec.phone_contact_point_id -- i n
			     );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_contact_rec.interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	RAISE my_exc;
          ELSE
	p_phone_contact_id := p_contact_rec.phone_contact_point_id;
          END IF;
        END IF; -- data to update
      END IF; -- Caes Phone

      IF p_contact_rec.email_address IS NOT NULL AND
         p_contact_rec.email_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;

        create_email_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_contact_rec.contact_party_id, -- i n
			   p_contact_point_type => 'EMAIL', -- i v
			   p_email_format       => 'MAILTEXT', -- i v
			   p_interface_source   => p_contact_rec.interface_source, -- i v
			   p_primary_flag       => nvl(p_contact_rec.email_primary_flag,
					       'Y'), -- i v
			   p_status             => nvl(p_contact_rec.email_status,
					       'A'), -- i v
			   p_email_address      => p_contact_rec.email_address, -- i v
			   p_entity             => 'Create Email', -- i v
			   p_interface_id       => p_contact_rec.interface_id, -- i n
			   p_contact_point_id   => l_contact_point_id -- o n
			   );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_contact_rec.interface_id, -- i n
	      p_entity       => 'CONTACT'); -- i v
          RAISE my_exc;
        ELSE
          p_email_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_contact_rec.email_contact_point_id IS NOT NULL THEN
        -- check if there is any change to update
        IF p_contact_rec.email_address IS NOT NULL OR
           p_contact_rec.email_status IS NOT NULL OR
           p_contact_rec.email_primary_flag IS NOT NULL THEN

          update_email_contact_point_api(errbuf               => l_err_desc, -- o v
			     retcode              => l_err_code, -- o v
			     p_party_id           => p_contact_rec.contact_party_id, -- i n
			     p_contact_point_type => 'EMAIL', -- i v
			     p_email_format       => 'MAILTEXT', -- i v
			     p_primary_flag       => p_contact_rec.email_primary_flag, -- i v
			     p_status             => p_contact_rec.email_status, -- i v
			     p_email_address      => p_contact_rec.email_address, -- i v
			     p_entity             => 'Update Email', -- i v
			     p_interface_id       => p_contact_rec.interface_id, -- i n
			     p_contact_point_id   => p_contact_rec.email_contact_point_id -- i n
			     );
          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_contact_rec.interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	RAISE my_exc;
          ELSE
	p_email_contact_id := p_contact_rec.email_contact_point_id;
          END IF;
        END IF; -- check any change to upd
      END IF; -- Case Email
      IF p_contact_rec.web_url IS NOT NULL AND
         p_contact_rec.web_contact_point_id IS NULL THEN
        l_contact_point_id := NULL;
        l_err_desc         := NULL;
        l_err_code         := NULL;

        create_url_contact_point_api(errbuf               => l_err_desc, -- o v
			 retcode              => l_err_code, -- o v
			 p_party_id           => p_contact_rec.contact_party_id, -- i n
			 p_contact_point_type => 'WEB', -- i v
			 p_interface_source   => p_contact_rec.interface_source, -- i v
			 p_status             => nvl(p_contact_rec.web_status,
					     'A'), -- i v
			 p_primary_flag       => nvl(p_acc_rec.web_primary_flag,
					     'Y'), -- i v
			 p_web_type           => 'HTML', -- i v
			 p_url                => p_contact_rec.web_url, -- i v
			 p_entity             => 'Create Url', -- i v
			 p_interface_id       => p_contact_rec.interface_id, -- i n
			 p_contact_point_id   => l_contact_point_id -- o n
			 );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => p_contact_rec.interface_id, -- i n
	      p_entity       => 'CONTACT'); -- i v
          RAISE my_exc;
        ELSE
          p_web_contact_id := l_contact_point_id;
        END IF;
      ELSIF p_contact_rec.web_contact_point_id IS NOT NULL THEN
        IF p_contact_rec.web_status IS NOT NULL OR
           p_contact_rec.web_primary_flag IS NOT NULL OR
           p_contact_rec.web_url IS NOT NULL THEN

          update_url_contact_point_api(errbuf               => l_err_desc, -- o v
			   retcode              => l_err_code, -- o v
			   p_party_id           => p_contact_rec.contact_party_id, -- i n
			   p_contact_point_type => 'WEB', -- i v
			   p_status             => p_contact_rec.web_status, -- i v
			   p_primary_flag       => p_contact_rec.web_primary_flag, -- i v
			   p_web_type           => 'HTML', -- i v
			   p_url                => p_contact_rec.web_url, -- i v
			   p_entity             => 'Update Url', -- i v
			   p_interface_id       => p_contact_rec.interface_id, -- i n
			   p_contact_point_id   => p_contact_rec.web_contact_point_id -- i n
			   );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_contact_rec.interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	RAISE my_exc;
          ELSE
	p_web_contact_id := p_contact_rec.web_contact_point_id;
          END IF;
        END IF; -- check for update
      END IF; -- Case url
    END IF; -- Account or Contact

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_contact_point - entity - ' || p_entity ||
	     ' interface_id ' ||
	     nvl(p_acc_rec.interface_id, p_contact_rec.interface_id) ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END handle_contact_point;

  --------------------------------------------------------------------
  --  name:               handle_accounts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        Procedure that will handle account per interface record
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_accounts(errbuf         OUT VARCHAR2,
		    retcode        OUT VARCHAR2,
		    p_interface_id IN NUMBER) IS

    CURSOR get_account_c IS
      SELECT *
      FROM   xxhz_account_interface acc
      WHERE  acc.interface_id = p_interface_id;

    l_acc_rec            xxhz_account_interface%ROWTYPE;
    l_phone_contact_id   NUMBER;
    l_fax_contact_id     NUMBER;
    l_mobile_contact_id  NUMBER;
    l_web_contact_id     NUMBER;
    l_email_contact_id   NUMBER;
    l_code_assignment_id NUMBER;

    l_err_desc VARCHAR2(500);
    l_err_code VARCHAR2(100);

    my_exc EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    --fnd_global.apps_initialize(user_id      => 4290,  -- SALESFORCE
    --                           resp_id      => 51137, -- CRM Service Super User Objet
    --                           resp_appl_id => 514)  -- Support (obsolete)

    -- 1) reset log_message, good for running second time.
    reset_log_msg(p_interface_id, 'ACCOUNT');
    COMMIT; -- yuval CHG0036474
    -- 2) get the row from interface
    FOR get_account_r IN get_account_c LOOP
      l_acc_rec := get_account_r;
    END LOOP;
    -- 3) validation
    validate_accounts(errbuf    => l_err_desc, -- o v
	          retcode   => l_err_code, -- o v
	          p_acc_rec => l_acc_rec); -- i xxhz_account_interface%rowtype

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'ACCOUNT'); -- i v

      RAISE my_exc;
    END IF;

    -- 4) fill needed id's
    --if l_acc_rec.cust_account_id is not null or l_acc_rec.account_number is not null then
    fill_missing_acc_info(l_acc_rec);
    --end if;
    -- 5) Handle account api
    handle_account_api(errbuf    => l_err_desc, -- o v
	           retcode   => l_err_code, -- o v
	           p_entity  => 'Account', -- i v
	           p_acc_rec => l_acc_rec -- i/o xxhz_account_interface%rowtype
	           );
    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'ACCOUNT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;

    -- 5) Handle code assignment api (industry - class code) -- ?????????????????????????? not sure it is correct????
    handle_code_assignment(errbuf               => l_err_desc, -- o v
		   retcode              => l_err_code, -- o v
		   p_entity             => 'Code Assignment', -- i v
		   p_acc_rec            => l_acc_rec, -- i/o xxhz_account_interface%rowtype
		   p_code_assignment_id => l_code_assignment_id);
    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'ACCOUNT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;

    -- 6) Handle contact points
    handle_contact_point(errbuf        => l_err_desc, -- o v
		 retcode       => l_err_code, -- o v
		 p_entity      => 'Contact Point', -- i v
		 p_acc_rec     => l_acc_rec, -- i/o xxhz_account_interface%rowtype
		 p_contact_rec => NULL, -- i/o xxhz_contact_interface%rowtype
		 --p_cust_account_role_id => null,                -- i n  this param is used for the contact only.
		 p_source            => 'ACCOUNT', -- i v
		 p_phone_contact_id  => l_phone_contact_id, -- o n
		 p_fax_contact_id    => l_fax_contact_id, -- o n
		 p_mobile_contact_id => l_mobile_contact_id, -- o n
		 p_web_contact_id    => l_web_contact_id, -- o n
		 p_email_contact_id  => l_email_contact_id -- o n
		 );
    -- update interface row with err
    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'ACCOUNT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    ELSE
      -- update interface row with success
      l_acc_rec.phone_contact_point_id  := l_phone_contact_id;
      l_acc_rec.fax_contact_point_id    := l_fax_contact_id;
      l_acc_rec.mobile_contact_point_id := l_mobile_contact_id;
      l_acc_rec.web_contact_point_id    := l_web_contact_id;
      l_acc_rec.email_contact_point_id  := l_email_contact_id;

      upd_success_log(p_status      => 'SUCCESS', -- i v
	          p_entity      => 'ACCOUNT', -- i v
	          p_acc_rec     => l_acc_rec, -- i xxhz_account_interface%rowtype,
	          p_site_rec    => NULL, -- i xxhz_site_interface%rowtype,
	          p_contact_rec => NULL -- i xxhz_contact_interface%rowtype,
	          );

      COMMIT;
    END IF; -- contact point

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      ROLLBACK; -- yuval CHG0036474
      errbuf  := 'Gen EXC - handle_accounts - interface_id ' ||
	     p_interface_id || ' - ' || substr(SQLERRM, 1, 240) || ' ' ||
	     l_err_desc; -- yuval CHG0036474
      retcode := 2;

  END handle_accounts;

  --------------------------------------------------------------------
  --  name:            create_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_location_api(errbuf              OUT VARCHAR2,
		        retcode             OUT VARCHAR2,
		        p_address1          IN VARCHAR2,
		        p_address2          IN VARCHAR2,
		        p_address3          IN VARCHAR2,
		        p_address4          IN VARCHAR2,
		        p_state             IN VARCHAR2,
		        p_postal_code       IN VARCHAR2,
		        p_county            IN VARCHAR2,
		        p_country           IN VARCHAR2, -- fnd_territories_tl.territory_code (territory_short_name)
		        p_city              IN VARCHAR2,
		        p_created_by_module IN VARCHAR2,
		        p_entity            IN VARCHAR2,
		        p_interface_id      IN NUMBER,
		        p_location_id       OUT NUMBER) IS

    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(150) := NULL;
    t_location_rec   hz_location_v2pub.location_rec_type;
    l_location_id    NUMBER;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;

    my_exc EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
	SELECT territory_code
	INTO   l_territory_code
	FROM   fnd_territories_vl t
	WHERE  upper(t.territory_code) = upper(p_country);
          EXCEPTION
	WHEN OTHERS THEN
	  errbuf  := 'create_location_api - Invalid territory :' ||
		 p_country;
	  retcode := 1;
	  RAISE my_exc;
          END;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;

    IF p_state IS NOT NULL AND nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_state);

      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'create_location_api - Invalid state :' || p_state;
          retcode := 1;
          RAISE my_exc;
      END;
    ELSE
      l_state := p_state;
    END IF;

    t_location_rec.country           := l_territory_code;
    t_location_rec.address1          := p_address1;
    t_location_rec.address2          := p_address2;
    t_location_rec.address3          := p_address3;
    t_location_rec.address4          := p_address4;
    t_location_rec.city              := p_city;
    t_location_rec.postal_code       := p_postal_code;
    t_location_rec.state             := l_state;
    t_location_rec.county            := p_county;
    t_location_rec.created_by_module := p_created_by_module; --'SALESFORCE';

    hz_location_v2pub.create_location(p_init_msg_list => 'T',
			  p_location_rec  => t_location_rec,
			  x_location_id   => l_location_id,
			  x_return_status => l_return_status,
			  x_msg_count     => l_msg_count,
			  x_msg_data      => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'Failed create location: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Failed create location:');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 500));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      p_location_id := l_location_id;
    END IF; -- Status if

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_location_api - entity -' || p_entity ||
	     ' interface id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 200);
      retcode := 1;
  END create_location_api;

  --------------------------------------------------------------------
  --  name:            update_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that call update location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/03/2014  Dalit A. Raviv    initial build
  --  1.1  12/01/2015  Michal Tzvik      CHG0033182: Allow update when country is not provided
  --  1.1  03/03/2015  Dalit A. Raviv    CHG0033183 - add if all fields are null do not update.
  --------------------------------------------------------------------
  PROCEDURE update_location_api(errbuf              OUT VARCHAR2,
		        retcode             OUT VARCHAR2,
		        p_address1          IN VARCHAR2,
		        p_address2          IN VARCHAR2,
		        p_address3          IN VARCHAR2,
		        p_address4          IN VARCHAR2,
		        p_state             IN VARCHAR2,
		        p_postal_code       IN VARCHAR2,
		        p_county            IN VARCHAR2,
		        p_country           IN VARCHAR2, -- fnd_territories_tl.territory_code (territory_short_name)
		        p_city              IN VARCHAR2,
		        p_entity            IN VARCHAR2,
		        p_interface_id      IN NUMBER,
		        p_created_by_module IN VARCHAR2,
		        p_location_id       IN NUMBER) IS

    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(150) := NULL;
    t_location_rec   hz_location_v2pub.location_rec_type;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;
    l_ovn            NUMBER := NULL;
    l_update         VARCHAR2(10) := NULL;

    my_exc EXCEPTION;

    l_location_rec hz_locations%ROWTYPE; -- CHG0033182 Michal Tzvik 12/01/2015
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
	SELECT territory_code
	INTO   l_territory_code
	FROM   fnd_territories_vl t
	WHERE  upper(t.territory_code) = upper(p_country);
          EXCEPTION
	WHEN OTHERS THEN
	  errbuf  := 'update_location_api - Invalid territory :' ||
		 p_country;
	  retcode := 1;
	  RAISE my_exc;
          END;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;

    IF p_state IS NOT NULL AND nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_state);

      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'update_location_api - Invalid state :' || p_state;
          retcode := 1;
          RAISE my_exc;
      END;
    ELSE
      l_state := p_state;
    END IF;

    BEGIN
      SELECT hl.object_version_number
      INTO   l_ovn
      FROM   hz_locations hl
      WHERE  hl.location_id = p_location_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_ovn := NULL;
    END;

    -- CHG0033182 Michal Tzvik 12/01/2015
    SELECT *
    INTO   l_location_rec
    FROM   hz_locations hl
    WHERE  hl.location_id = p_location_id;

    -- check update address when source is SALESFORCE
    -- if DB record, address1 is full with data, and address2-4 are null
    -- do update. only for salesforce source
    IF p_created_by_module = 'SALESFORCE' THEN
      BEGIN
        SELECT 'Y'
        INTO   l_update
        FROM   hz_locations hl
        WHERE  hl.address1 IS NOT NULL
        AND    hl.address2 IS NULL
        AND    hl.address3 IS NULL
        AND    hl.address4 IS NULL
        AND    hl.location_id = p_location_id; -- CHG0033182 Michal Tzvik 12.01.2015

      EXCEPTION
        WHEN OTHERS THEN
          l_update := 'N';
      END;
    ELSE
      l_update := 'Y';
    END IF;

    /*
    if p_address1 is null and p_address2 is null and p_address3 is null and
       p_address4 is null and p_state is null and p_postal_code is null and
       p_county is null and p_country is null and p_city is null then
      l_update := 'N';
    end if;*/
    -- 1.1 03/03/2015 Dalit A. Raviv  CHG0033183 - add nvl to all fields.
    IF l_update = 'Y' THEN
      t_location_rec.location_id := p_location_id;
      t_location_rec.country     := nvl(l_territory_code,
			    l_location_rec.country);
      t_location_rec.address1    := nvl(p_address1, l_location_rec.address1);
      t_location_rec.address2    := nvl(p_address2, l_location_rec.address2);
      t_location_rec.address3    := nvl(p_address3, l_location_rec.address3);
      t_location_rec.address4    := nvl(p_address4, l_location_rec.address4);
      t_location_rec.city        := nvl(p_city, l_location_rec.city);
      t_location_rec.postal_code := nvl(p_postal_code,
			    l_location_rec.postal_code);
      t_location_rec.state       := nvl(l_state, l_location_rec.state);
      t_location_rec.county      := nvl(p_county, l_location_rec.county);
      t_location_rec.country     := nvl(p_country, l_location_rec.country); -- CHG0033182 Michal Tzvik 12.01.2015

      hz_location_v2pub.update_location(p_init_msg_list         => 'T', -- i v
			    p_location_rec          => t_location_rec,
			    p_object_version_number => l_ovn, -- i / o nocopy n
			    x_return_status         => l_return_status, -- o nocopy v
			    x_msg_count             => l_msg_count, -- o nocopy n
			    x_msg_data              => l_msg_data); -- o nocopy v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf  := 'Failed update location: ' || l_msg_data;
        retcode := 1;
        fnd_file.put_line(fnd_file.log, 'Failed update location:');
        fnd_file.put_line(fnd_file.log,
		  'l_msg_data = ' || substr(l_msg_data, 1, 500));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

          errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
        END LOOP;
      END IF; -- Status if
    END IF; -- l_update
  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_location_api - entity -' || p_entity ||
	     ' interface id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 200);
      retcode := 1;
  END update_location_api;

  --------------------------------------------------------------------
  --  name:               handle_location
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update location
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_location(errbuf              OUT VARCHAR2,
		    retcode             OUT VARCHAR2,
		    p_address1          IN VARCHAR2,
		    p_address2          IN VARCHAR2,
		    p_address3          IN VARCHAR2,
		    p_address4          IN VARCHAR2,
		    p_state             IN VARCHAR2,
		    p_postal_code       IN VARCHAR2,
		    p_county            IN VARCHAR2,
		    p_country           IN VARCHAR2, -- fnd_territories_tl.territory_code (territory_short_name)
		    p_city              IN VARCHAR2,
		    p_created_by_module IN VARCHAR2,
		    p_entity            IN VARCHAR2,
		    p_interface_id      IN NUMBER,
		    p_location_id       IN OUT NUMBER) IS

    l_err_desc VARCHAR2(500) := NULL;
    l_err_code VARCHAR2(100) := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- Caes of update
    IF p_location_id IS NOT NULL THEN
      update_location_api(errbuf              => l_err_desc, -- o v
		  retcode             => l_err_code, -- o v
		  p_address1          => p_address1, -- i v
		  p_address2          => p_address2, -- i v
		  p_address3          => p_address3, -- i v
		  p_address4          => p_address4, -- i v
		  p_state             => p_state, -- i v
		  p_postal_code       => p_postal_code, -- i v
		  p_county            => p_county, -- i v
		  p_country           => p_country, -- i v
		  p_city              => p_city, -- i v
		  p_entity            => 'Update Location', -- i v
		  p_interface_id      => p_interface_id, -- i n
		  p_created_by_module => p_created_by_module, -- i v
		  p_location_id       => p_location_id); -- i n
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF; -- update location
      -- case of create
    ELSE
      -- check if any details exists at interface
      IF (p_address1 IS NOT NULL OR p_address2 IS NOT NULL OR
         p_address3 IS NOT NULL OR p_address4 IS NOT NULL OR
         p_state IS NOT NULL OR p_postal_code IS NOT NULL OR
         p_county IS NOT NULL OR p_country IS NOT NULL OR
         p_city IS NOT NULL) THEN

        -- check location with exact details do not exists in db
        -- if yes i do not want to create another i will only connect it.
        BEGIN
          SELECT hl.location_id
          INTO   p_location_id
          FROM   hz_locations hl
          WHERE  hl.address1 = nvl(p_address1, hl.address1)
          AND    hl.address2 = nvl(p_address2, hl.address2)
          AND    hl.address3 = nvl(p_address3, hl.address3)
          AND    hl.address4 = nvl(p_address4, hl.address4)
          AND    hl.state = nvl(p_state, hl.state)
          AND    hl.postal_code = nvl(p_postal_code, hl.postal_code)
          AND    hl.county = nvl(p_county, hl.county)
          AND    hl.country = nvl(p_country, hl.country)
          AND    hl.city = nvl(p_city, hl.city);

        EXCEPTION
          WHEN OTHERS THEN
	create_location_api(errbuf              => l_err_desc, -- o v
		        retcode             => l_err_code, -- o v
		        p_address1          => p_address1, -- i v
		        p_address2          => p_address2, -- i v
		        p_address3          => p_address3, -- i v
		        p_address4          => p_address4, -- i v
		        p_state             => p_state, -- i v
		        p_postal_code       => p_postal_code, -- i v
		        p_county            => p_county, -- i v
		        p_country           => p_country, -- i v
		        p_city              => p_city, -- i v
		        p_created_by_module => p_created_by_module, -- i v
		        p_entity            => 'Create Location', -- i v
		        p_interface_id      => p_interface_id, -- i n
		        p_location_id       => p_location_id); -- o n
	IF l_err_code <> 0 THEN
	  errbuf  := l_err_desc;
	  retcode := 2;
	ELSE
	  errbuf  := NULL;
	  retcode := 0;
	END IF;
        END;
      END IF; -- fields are not null
    END IF; -- location is not null

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_location - entity -' || p_entity ||
	     ' interface id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 200);
      retcode := 1;
  END handle_location;

  --------------------------------------------------------------------
  --  name:               create_party_site_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        Procedure that call create party site API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_party_site_api(errbuf               OUT VARCHAR2,
		          retcode              OUT VARCHAR2,
		          p_party_site_id      OUT NUMBER,
		          p_entity             IN VARCHAR2,
		          p_interface_id       IN NUMBER,
		          p_location_id        IN NUMBER,
		          p_party_id           IN NUMBER, -- use for contact
		          p_cust_account_id    IN NUMBER, -- use for site
		          p_party_site_number  IN VARCHAR2,
		          p_interface_source   IN VARCHAR2,
		          p_status             IN VARCHAR2,
		          p_attribute_category IN VARCHAR2,
		          p_attribute1         IN VARCHAR2,
		          p_attribute2         IN VARCHAR2,
		          p_attribute3         IN VARCHAR2,
		          p_attribute4         IN VARCHAR2,
		          p_attribute5         IN VARCHAR2,
		          p_attribute6         IN VARCHAR2,
		          p_attribute7         IN VARCHAR2,
		          p_attribute8         IN VARCHAR2,
		          p_attribute9         IN VARCHAR2,
		          p_attribute10        IN VARCHAR2,
		          p_attribute11        IN VARCHAR2,
		          p_attribute12        IN VARCHAR2,
		          p_attribute13        IN VARCHAR2,
		          p_attribute14        IN VARCHAR2,
		          p_attribute15        IN VARCHAR2,
		          p_attribute16        IN VARCHAR2,
		          p_attribute17        IN VARCHAR2,
		          p_attribute18        IN VARCHAR2,
		          p_attribute19        IN VARCHAR2,
		          p_attribute20        IN VARCHAR2) IS

    t_party_site_rec    hz_party_site_v2pub.party_site_rec_type;
    l_party_id          NUMBER := NULL;
    l_party_site_number NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2500);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
    l_party_name        VARCHAR2(360) := NULL;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    --  Get party id, party name
    IF p_party_id IS NULL THEN
      SELECT hca.party_id,
	 hp.party_name
      INTO   l_party_id,
	 l_party_name
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.cust_account_id = p_cust_account_id
      AND    hca.party_id = hp.party_id;
    ELSE
      l_party_id := p_party_id;
      SELECT hp.party_name
      INTO   l_party_name
      FROM   hz_parties hp
      WHERE  hp.party_id = l_party_id;
    END IF;

    -- Note: if profile "HZ: Generate Party Site Number" is set to Y the API will fail because
    -- we supplied party_site_number. in this case for conversions we need to change the profile value to N
    t_party_site_rec.party_id           := l_party_id;
    t_party_site_rec.location_id        := p_location_id;
    t_party_site_rec.created_by_module  := p_interface_source; --'SALESFORCE';
    t_party_site_rec.party_site_name    := l_party_name;
    t_party_site_rec.party_site_number  := p_party_site_number; -- NOTE
    t_party_site_rec.status             := nvl(p_status, 'A');
    t_party_site_rec.attribute_category := p_attribute_category;
    t_party_site_rec.attribute1         := p_attribute1;
    t_party_site_rec.attribute2         := p_attribute2;
    t_party_site_rec.attribute3         := p_attribute3;
    t_party_site_rec.attribute4         := p_attribute4;
    t_party_site_rec.attribute5         := p_attribute5;
    t_party_site_rec.attribute6         := p_attribute6;
    t_party_site_rec.attribute7         := p_attribute7;
    t_party_site_rec.attribute8         := p_attribute8;
    t_party_site_rec.attribute9         := p_attribute9;
    t_party_site_rec.attribute10        := p_attribute10;
    t_party_site_rec.attribute11        := p_attribute11;
    t_party_site_rec.attribute12        := p_attribute12;
    t_party_site_rec.attribute13        := p_attribute13;
    t_party_site_rec.attribute14        := p_attribute14;
    t_party_site_rec.attribute15        := p_attribute15;
    t_party_site_rec.attribute16        := p_attribute16;
    t_party_site_rec.attribute17        := p_attribute17;
    t_party_site_rec.attribute18        := p_attribute18;
    t_party_site_rec.attribute19        := p_attribute19;
    t_party_site_rec.attribute20        := p_attribute20;

    hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
			      p_party_site_rec    => t_party_site_rec,
			      x_party_site_id     => l_party_site_id,
			      x_party_site_number => l_party_site_number,
			      x_return_status     => l_return_status,
			      x_msg_count         => l_msg_count,
			      x_msg_data          => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create party site: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Creation Party Site Failed ');
      fnd_file.put_line(fnd_file.log,
		'l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
      p_party_site_id := -99;
    ELSE
      p_party_site_id := l_party_site_id;
    END IF; --  party status
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_party_site_api - entity - ' || p_entity ||
	     ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_party_site_api;

  --------------------------------------------------------------------
  --  name:               update_party_site_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      20/03/2014
  --  Description:        Procedure that call update party site API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/03/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal Tzvik    CHG0034610: REmove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_party_site_api(errbuf          OUT VARCHAR2,
		          retcode         OUT VARCHAR2,
		          p_party_site_id IN NUMBER, -- YUVAL
		          p_entity        IN VARCHAR2,
		          --p_cust_acct_site_id  IN NUMBER,
		          p_party_site_number IN VARCHAR2,
		          p_interface_id      IN NUMBER,
		          p_location_id       IN NUMBER,
		          --p_party_id           IN NUMBER,
		          p_status             IN VARCHAR2,
		          p_attribute_category IN VARCHAR2,
		          p_attribute1         IN VARCHAR2,
		          p_attribute2         IN VARCHAR2,
		          p_attribute3         IN VARCHAR2,
		          p_attribute4         IN VARCHAR2,
		          p_attribute5         IN VARCHAR2,
		          p_attribute6         IN VARCHAR2,
		          p_attribute7         IN VARCHAR2,
		          p_attribute8         IN VARCHAR2,
		          p_attribute9         IN VARCHAR2,
		          p_attribute10        IN VARCHAR2,
		          p_attribute11        IN VARCHAR2,
		          p_attribute12        IN VARCHAR2,
		          p_attribute13        IN VARCHAR2,
		          p_attribute14        IN VARCHAR2,
		          p_attribute15        IN VARCHAR2,
		          p_attribute16        IN VARCHAR2,
		          p_attribute17        IN VARCHAR2,
		          p_attribute18        IN VARCHAR2,
		          p_attribute19        IN VARCHAR2,
		          p_attribute20        IN VARCHAR2) IS

    t_party_site_rec hz_party_site_v2pub.party_site_rec_type;
    l_party_id       NUMBER := NULL;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;
    l_ovn            NUMBER;
    l_party_site_id  NUMBER;
    l_status         VARCHAR2(1);
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    -- get party_site details YUVAL
    SELECT p.object_version_number,
           p.party_id,
           p.party_site_id,
           p.status
    INTO   l_ovn,
           l_party_id,
           l_party_site_id,
           l_status
    FROM   hz_party_sites p
    WHERE  p.party_site_id = p_party_site_id;

    /*  BEGIN
      -- case site
      SELECT p.object_version_number, p.party_id, p.party_site_id
        INTO l_ovn, l_party_id, l_party_site_id
        FROM hz_party_sites p, hz_cust_acct_sites_all s
       WHERE s.party_site_id = p.party_site_id
         AND s.cust_acct_site_id = p_cust_acct_site_id
    EXCEPTION
      WHEN OTHERS THEN
        -- case contact
        BEGIN
          SELECT p.object_version_number, p.party_id, p.party_site_id
            INTO l_ovn, l_party_id, l_party_site_id
            FROM hz_party_sites p
           WHERE p.party_id = p_party_id
        EXCEPTION
          WHEN OTHERS THEN
            l_party_site_id := NULL
        END
    END*/

    -- 1.1 Michal Tzvik: Remove G_MISS
    t_party_site_rec.party_site_id := p_party_site_id; --l_party_site_id-- yuval
    t_party_site_rec.status        := nvl(p_status, l_status); -- Dalit A. Raviv 04/03/2015
    t_party_site_rec.party_id      := l_party_id; -- remove nvl(... , fnd_api.g_miss_num)
    IF p_party_site_number IS NOT NULL THEN
      t_party_site_rec.party_site_number := p_party_site_number;
    END IF;
    t_party_site_rec.location_id        := p_location_id; -- remove nvl(... , fnd_api.g_miss_num)
    t_party_site_rec.attribute_category := p_attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute1         := p_attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute2         := p_attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute3         := p_attribute3; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute4         := p_attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute5         := p_attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute6         := p_attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute7         := p_attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute8         := p_attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute9         := p_attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute10        := p_attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute11        := p_attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute12        := p_attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute13        := p_attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute14        := p_attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute15        := p_attribute15; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute16        := p_attribute16; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute17        := p_attribute17; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute18        := p_attribute18; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute19        := p_attribute19; -- remove nvl(... , fnd_api.g_miss_char)
    t_party_site_rec.attribute20        := p_attribute20; -- remove nvl(... , fnd_api.g_miss_char)

    hz_party_site_v2pub.update_party_site(p_init_msg_list         => 'T',
			      p_party_site_rec        => t_party_site_rec,
			      p_object_version_number => l_ovn,
			      x_return_status         => l_return_status,
			      x_msg_count             => l_msg_count,
			      x_msg_data              => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E update party site: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Update Party Site Failed ');
      fnd_file.put_line(fnd_file.log,
		'l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      NULL; -- p_party_site_id := l_party_site_id-- YUVAL
    END IF; --  party status
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_party_site_api - entity - ' || p_entity ||
	     ' interface_id ' || p_interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_party_site_api;

  --------------------------------------------------------------------
  --  name:               handle_party_site
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update party site
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build    
  --  1.1   23/07/2019    Ofer Suad       CHG0046162 - Mass create of customer site fail – missing party site id
  --------------------------------------------------------------------
  PROCEDURE handle_party_site(errbuf          OUT VARCHAR2,
		      retcode         OUT VARCHAR2,
		      p_party_site_id OUT NUMBER,
		      p_location_id   IN NUMBER,
		      p_entity        IN VARCHAR2,
		      p_party_id      IN NUMBER,
		      p_site_rec      IN xxhz_site_interface%ROWTYPE,
		      p_contact_rec   IN xxhz_contact_interface%ROWTYPE,
		      p_source        IN VARCHAR2) IS

    l_err_desc      VARCHAR2(500) := NULL;
    l_err_code      VARCHAR2(100) := 0;
    l_party_site_id NUMBER := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- case create
    IF p_source = 'SITE' THEN
      -- IF p_site_rec.cust_acct_site_id IS NULL THEN -- YUVAL
      IF p_site_rec.party_site_id IS NULL THEN
        --l_party_site_id
        -- create party site
        create_party_site_api(errbuf               => l_err_desc, -- o v
		      retcode              => l_err_code, -- o v
		      p_party_site_id      => l_party_site_id, -- o n
		      p_entity             => 'Create Party Site', -- i v
		      p_interface_id       => p_site_rec.interface_id, -- i n
		      p_location_id        => p_location_id, -- i n
		      p_party_id           => p_party_id, -- i n
		      p_cust_account_id    => p_site_rec.cust_account_id, -- i n
		      p_party_site_number  => p_site_rec.party_site_number, -- i v
		      p_interface_source   => p_site_rec.interface_source, -- i v
		      p_status             => p_site_rec.site_status, -- i v
		      p_attribute_category => p_site_rec.site_attribute_category, -- i v
		      p_attribute1         => p_site_rec.site_attribute1, -- i v
		      p_attribute2         => p_site_rec.site_attribute2, -- i v
		      p_attribute3         => p_site_rec.site_attribute3, -- i v
		      p_attribute4         => p_site_rec.site_attribute4, -- i v
		      p_attribute5         => p_site_rec.site_attribute5, -- i v
		      p_attribute6         => p_site_rec.site_attribute6, -- i v
		      p_attribute7         => p_site_rec.site_attribute7, -- i v
		      p_attribute8         => p_site_rec.site_attribute8, -- i v
		      p_attribute9         => p_site_rec.site_attribute9, -- i v
		      p_attribute10        => p_site_rec.site_attribute10, -- i v
		      p_attribute11        => p_site_rec.site_attribute11, -- i v
		      p_attribute12        => p_site_rec.site_attribute12, -- i v
		      p_attribute13        => p_site_rec.site_attribute13, -- i v
		      p_attribute14        => p_site_rec.site_attribute14, -- i v
		      p_attribute15        => p_site_rec.site_attribute15, -- i v
		      p_attribute16        => p_site_rec.site_attribute16, -- i v
		      p_attribute17        => p_site_rec.site_attribute17, -- i v
		      p_attribute18        => p_site_rec.site_attribute18, -- i v
		      p_attribute19        => p_site_rec.site_attribute19, -- i v
		      p_attribute20        => p_site_rec.site_attribute20 -- i v
		      );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;

        ELSE
        --commented below line as part of CHG0046162  
        --p_party_site_id := p_site_rec.party_site_id; --l_party_site_id-- YUVAL 
          p_party_site_id := nvl(p_site_rec.party_site_id,l_party_site_id);  --added as part of CHG0046162 
          --l_site_rec.party_site_id := l_party_site_id
        END IF;
        -- case update
      ELSE
        update_party_site_api(errbuf          => l_err_desc, -- o v
		      retcode         => l_err_code, -- o v
		      p_party_site_id => p_site_rec.party_site_id, -- YUVAL  l_party_site_id, -- o n
		      p_entity        => 'Update Party Site', -- i v
		      --p_cust_acct_site_id => p_site_rec.cust_acct_site_id, -- i n
		      p_party_site_number => p_site_rec.party_site_number, -- i v
		      p_interface_id      => p_site_rec.interface_id, -- i n
		      p_location_id       => p_location_id, -- i n
		      --p_party_id => p_party_id, -- i n
		      p_status             => p_site_rec.site_status, -- i v
		      p_attribute_category => p_site_rec.site_attribute_category, -- i v
		      p_attribute1         => p_site_rec.site_attribute1, -- i v
		      p_attribute2         => p_site_rec.site_attribute2, -- i v
		      p_attribute3         => p_site_rec.site_attribute3, -- i v
		      p_attribute4         => p_site_rec.site_attribute4, -- i v
		      p_attribute5         => p_site_rec.site_attribute5, -- i v
		      p_attribute6         => p_site_rec.site_attribute6, -- i v
		      p_attribute7         => p_site_rec.site_attribute7, -- i v
		      p_attribute8         => p_site_rec.site_attribute8, -- i v
		      p_attribute9         => p_site_rec.site_attribute9, -- i v
		      p_attribute10        => p_site_rec.site_attribute10, -- i v
		      p_attribute11        => p_site_rec.site_attribute11, -- i v
		      p_attribute12        => p_site_rec.site_attribute12, -- i v
		      p_attribute13        => p_site_rec.site_attribute13, -- i v
		      p_attribute14        => p_site_rec.site_attribute14, -- i v
		      p_attribute15        => p_site_rec.site_attribute15, -- i v
		      p_attribute16        => p_site_rec.site_attribute16, -- i v
		      p_attribute17        => p_site_rec.site_attribute17, -- i v
		      p_attribute18        => p_site_rec.site_attribute18, -- i v
		      p_attribute19        => p_site_rec.site_attribute19, -- i v
		      p_attribute20        => p_site_rec.site_attribute20 -- i v
		      );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
        ELSE
          -- NULL  p_party_site_id := l_party_site_id -- YUVAL
          p_party_site_id := p_site_rec.party_site_id;
        END IF;
      END IF; -- check create or update
    ELSIF p_source = 'CONTACT' THEN
      IF p_contact_rec.party_site_id /*cust_acct_site_id yuval */
         IS NULL THEN
        IF p_location_id IS NOT NULL THEN
          -- create party site
          create_party_site_api(errbuf               => l_err_desc, -- o v
		        retcode              => l_err_code, -- o v
		        p_party_site_id      => l_party_site_id, -- o n
		        p_entity             => 'Create Party Site', -- i v
		        p_interface_id       => p_contact_rec.interface_id, -- i n
		        p_location_id        => p_location_id, -- i n
		        p_party_id           => p_party_id, -- i n
		        p_cust_account_id    => p_contact_rec.cust_account_id, -- i n
		        p_party_site_number  => p_contact_rec.party_site_number, -- i v
		        p_interface_source   => p_contact_rec.interface_source, -- i v
		        p_status             => NULL, -- i v
		        p_attribute_category => NULL, -- i v
		        p_attribute1         => NULL, -- i v
		        p_attribute2         => NULL, -- i v
		        p_attribute3         => NULL, -- i v
		        p_attribute4         => NULL, -- i v
		        p_attribute5         => NULL, -- i v
		        p_attribute6         => NULL, -- i v
		        p_attribute7         => NULL, -- i v
		        p_attribute8         => NULL, -- i v
		        p_attribute9         => NULL, -- i v
		        p_attribute10        => NULL, -- i v
		        p_attribute11        => NULL, -- i v
		        p_attribute12        => NULL, -- i v
		        p_attribute13        => NULL, -- i v
		        p_attribute14        => NULL, -- i v
		        p_attribute15        => NULL, -- i v
		        p_attribute16        => NULL, -- i v
		        p_attribute17        => NULL, -- i v
		        p_attribute18        => NULL, -- i v
		        p_attribute19        => NULL, -- i v
		        p_attribute20        => NULL -- i v
		        );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
          ELSE
	--p_contact_rec.party_site_id := l_party_site_id
	p_party_site_id := l_party_site_id;
          END IF;
        END IF;
        -- case update
      ELSE
        update_party_site_api(errbuf          => l_err_desc, -- o v
		      retcode         => l_err_code, -- o v
		      p_party_site_id => p_contact_rec.party_site_id, -- yuval l_party_site_id, -- o n
		      p_entity        => 'Update Party Site', -- i v
		      --p_cust_acct_site_id => p_contact_rec.cust_acct_site_id, -- i n
		      p_party_site_number => p_contact_rec.party_site_number, -- i v
		      p_interface_id      => p_contact_rec.interface_id, -- i n
		      p_location_id       => p_location_id, -- i n
		      --p_party_id => p_party_id, -- i n
		      p_status             => NULL, -- i v
		      p_attribute_category => NULL, -- i v
		      p_attribute1         => NULL, -- i v
		      p_attribute2         => NULL, -- i v
		      p_attribute3         => NULL, -- i v
		      p_attribute4         => NULL, -- i v
		      p_attribute5         => NULL, -- i v
		      p_attribute6         => NULL, -- i v
		      p_attribute7         => NULL, -- i v
		      p_attribute8         => NULL, -- i v
		      p_attribute9         => NULL, -- i v
		      p_attribute10        => NULL, -- i v
		      p_attribute11        => NULL, -- i v
		      p_attribute12        => NULL, -- i v
		      p_attribute13        => NULL, -- i v
		      p_attribute14        => NULL, -- i v
		      p_attribute15        => NULL, -- i v
		      p_attribute16        => NULL, -- i v
		      p_attribute17        => NULL, -- i v
		      p_attribute18        => NULL, -- i v
		      p_attribute19        => NULL, -- i v
		      p_attribute20        => NULL -- i v
		      );

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
        ELSE
          p_party_site_id := p_contact_rec.party_site_id /*l_party_site_id yuval*/
           ;
        END IF;
      END IF; -- check create or update
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_party_site - entity - ' || p_entity ||
	     ' interface_id ' || p_site_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END handle_party_site;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create cust account site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_site_api(errbuf              OUT VARCHAR2,
			     retcode             OUT VARCHAR2,
			     p_cust_acct_site_id OUT NUMBER,
			     p_org_id            OUT NUMBER,
			     p_party_name        OUT VARCHAR2,
			     p_entity            IN VARCHAR2,
			     p_site_rec          IN xxhz_site_interface%ROWTYPE) IS

    t_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    l_party_id           NUMBER := NULL;
    --l_org_id             number := null
    l_cust_acct_site_id NUMBER := NULL;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2500);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
    l_party_name        VARCHAR2(360) := NULL;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    --- org_id will come from att3 of hz_party
    SELECT hca.party_id, /*hp.attribute3, */
           hp.party_name
    INTO   l_party_id, /*l_org_id,*/
           l_party_name
    FROM   hz_cust_accounts hca,
           hz_parties       hp
    WHERE  hca.cust_account_id = p_site_rec.cust_account_id
    AND    hp.party_id = hca.party_id;

    t_cust_acct_site_rec.cust_account_id    := p_site_rec.cust_account_id;
    t_cust_acct_site_rec.party_site_id      := p_site_rec.party_site_id;
    t_cust_acct_site_rec.created_by_module  := p_site_rec.interface_source; --'SALESFORCE'
    t_cust_acct_site_rec.org_id             := p_site_rec.org_id; /*l_org_id*/ -- Dalit 06/04/2014
    t_cust_acct_site_rec.status             := p_site_rec.site_status;
    t_cust_acct_site_rec.attribute_category := p_site_rec.site_attribute_category;
    t_cust_acct_site_rec.attribute1         := p_site_rec.site_attribute1;
    t_cust_acct_site_rec.attribute2         := p_site_rec.site_attribute2;
    t_cust_acct_site_rec.attribute3         := p_site_rec.site_attribute3;
    t_cust_acct_site_rec.attribute4         := p_site_rec.site_attribute4;
    t_cust_acct_site_rec.attribute5         := p_site_rec.site_attribute5;
    t_cust_acct_site_rec.attribute6         := p_site_rec.site_attribute6;
    t_cust_acct_site_rec.attribute7         := p_site_rec.site_attribute7;
    t_cust_acct_site_rec.attribute8         := p_site_rec.site_attribute8;
    t_cust_acct_site_rec.attribute9         := p_site_rec.site_attribute9;
    t_cust_acct_site_rec.attribute10        := p_site_rec.site_attribute10;
    t_cust_acct_site_rec.attribute11        := p_site_rec.site_attribute11;
    t_cust_acct_site_rec.attribute12        := p_site_rec.site_attribute12;
    t_cust_acct_site_rec.attribute13        := p_site_rec.site_attribute13;
    t_cust_acct_site_rec.attribute14        := p_site_rec.site_attribute14;
    t_cust_acct_site_rec.attribute15        := p_site_rec.site_attribute15;
    t_cust_acct_site_rec.attribute16        := p_site_rec.site_attribute16;
    t_cust_acct_site_rec.attribute17        := p_site_rec.site_attribute17;
    t_cust_acct_site_rec.attribute18        := p_site_rec.site_attribute18;
    t_cust_acct_site_rec.attribute19        := p_site_rec.site_attribute19;
    t_cust_acct_site_rec.attribute20        := p_site_rec.site_attribute20;

    mo_global.set_org_access(p_org_id_char     => p_site_rec.org_id /*l_org_id*/,
		     p_sp_id_char      => NULL,
		     p_appl_short_name => 'AR');

    hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => 'T',
				     p_cust_acct_site_rec => t_cust_acct_site_rec,
				     x_cust_acct_site_id  => l_cust_acct_site_id,
				     x_return_status      => l_return_status,
				     x_msg_count          => l_msg_count,
				     x_msg_data           => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create site account: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
		'Creation of Customer Account Site Failed ');
      fnd_file.put_line(fnd_file.log,
		' l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, ' l_Msg_Data  = ' || l_msg_data);
      p_cust_acct_site_id := -99;
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      retcode             := 0;
      errbuf              := NULL;
      p_cust_acct_site_id := l_cust_acct_site_id;
      p_org_id            := p_site_rec.org_id /*l_org_id*/
       ;
      p_party_name        := l_party_name;

    END IF; -- customer site status
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - create_cust_account_site_api - entity - ' ||
	     p_entity || ' interface_id ' || p_site_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_cust_account_site_api;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create cust account site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/03/2014  Dalit A. Raviv    initial build
  --  1.1  04/03/2015  Dalit A. Raviv    CHG0033183 add nvl to status field.
  --  1.2  30/04/2015  Michal Tzvik      CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_cust_account_site_api(errbuf       OUT VARCHAR2,
			     retcode      OUT VARCHAR2,
			     p_org_id     OUT NUMBER,
			     p_party_name OUT VARCHAR2,
			     p_entity     IN VARCHAR2,
			     p_site_rec   IN xxhz_site_interface%ROWTYPE) IS

    t_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    l_org_id             NUMBER := NULL;
    l_ovn                NUMBER := NULL;
    l_return_status      VARCHAR2(1);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2500);
    l_data               VARCHAR2(2000);
    l_msg_index_out      NUMBER;
    l_status             VARCHAR2(1);

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    SELECT s.object_version_number,
           s.org_id,
           s.status
    INTO   l_ovn,
           l_org_id,
           l_status
    FROM   hz_cust_acct_sites_all s
    WHERE  s.cust_acct_site_id = p_site_rec.cust_acct_site_id;

    t_cust_acct_site_rec.cust_acct_site_id := p_site_rec.cust_acct_site_id;
    t_cust_acct_site_rec.cust_account_id   := p_site_rec.cust_account_id;
    t_cust_acct_site_rec.party_site_id     := p_site_rec.party_site_id;
    -- 1.2 Michal Tzvik: remove G_MISS
    t_cust_acct_site_rec.status             := p_site_rec.site_status; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute_category := p_site_rec.site_attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute1         := p_site_rec.site_attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute2         := p_site_rec.site_attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute3         := p_site_rec.site_attribute3; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute4         := p_site_rec.site_attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute5         := p_site_rec.site_attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute6         := p_site_rec.site_attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute7         := p_site_rec.site_attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute8         := p_site_rec.site_attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute9         := p_site_rec.site_attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute10        := p_site_rec.site_attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute11        := p_site_rec.site_attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute12        := p_site_rec.site_attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute13        := p_site_rec.site_attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute14        := p_site_rec.site_attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute15        := p_site_rec.site_attribute15; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute16        := p_site_rec.site_attribute16; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute17        := p_site_rec.site_attribute17; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute18        := p_site_rec.site_attribute18; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute19        := p_site_rec.site_attribute19; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_acct_site_rec.attribute20        := p_site_rec.site_attribute20; -- remove nvl(... , fnd_api.g_miss_char)

    mo_global.set_org_access(p_org_id_char     => l_org_id,
		     p_sp_id_char      => NULL,
		     p_appl_short_name => 'AR');

    hz_cust_account_site_v2pub.update_cust_acct_site(p_init_msg_list         => 'T',
				     p_cust_acct_site_rec    => t_cust_acct_site_rec,
				     p_object_version_number => l_ovn,
				     x_return_status         => l_return_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      errbuf  := 'E update site account: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
		'Update Customer Account Site Failed ');
      fnd_file.put_line(fnd_file.log,
		' l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, ' l_Msg_Data  = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      retcode  := 0;
      errbuf   := NULL;
      p_org_id := l_org_id;
      BEGIN
        SELECT party_name
        INTO   p_party_name
        FROM   hz_cust_accounts hca,
	   hz_parties       hp
        WHERE  hca.party_id = hp.party_id
        AND    hca.cust_account_id = p_site_rec.cust_account_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;

    END IF; -- customer site status
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - update_cust_account_site_api - entity - ' ||
	     p_entity || ' interface_id ' || p_site_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_cust_account_site_api;

  --------------------------------------------------------------------
  --  name:               handle_cust_account_site
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update cust account site
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_cust_account_site(errbuf              OUT VARCHAR2,
			 retcode             OUT VARCHAR2,
			 p_cust_acct_site_id OUT NUMBER,
			 p_org_id            OUT NUMBER,
			 p_party_name        OUT VARCHAR2,
			 p_entity            IN VARCHAR2,
			 p_site_rec          IN xxhz_site_interface%ROWTYPE) IS

    l_err_desc VARCHAR2(500) := NULL;
    l_err_code VARCHAR2(100) := 0;
  BEGIN
    retcode := 0;
    errbuf  := NULL;

    IF p_site_rec.cust_acct_site_id IS NULL THEN
      create_cust_account_site_api(errbuf              => l_err_desc, -- o v
		           retcode             => l_err_code, -- o v
		           p_cust_acct_site_id => p_cust_acct_site_id, -- o n
		           p_org_id            => p_org_id, -- o n
		           p_party_name        => p_party_name, -- o v
		           p_entity            => 'Create Cust Account Site', -- i v
		           p_site_rec          => p_site_rec -- i xxhz_site_interface%rowtype
		           );

      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
    ELSE
      update_cust_account_site_api(errbuf       => l_err_desc, -- o v
		           retcode      => l_err_code, -- o v
		           p_org_id     => p_org_id, -- o n
		           p_party_name => p_party_name, -- o v
		           p_entity     => 'Update Cust Account Site', -- i v
		           p_site_rec   => p_site_rec -- i xxhz_site_interface%rowtype
		           );
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      ELSE
        p_cust_acct_site_id := p_site_rec.cust_acct_site_id;
      END IF;
    END IF; -- create/update
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_cust_account_site - entity - ' ||
	     p_entity || ' interface_id ' || p_site_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END handle_cust_account_site;

  --------------------------------------------------------------------
  --  name:            create_cust_site_use_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust site use
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/03/2014  Dalit A. Raviv    initial build
  --  1.1  16/02/2015  Dalit A. Raviv    CHG0034398 - t_cust_site_use_rec.location
  --                                     change the length to 24 from 32 (it failed on var length)
  --  1.2  04/03/2015  Dalit A. Raviv    CHG0033183 -  add the ability to insert GL data
  --------------------------------------------------------------------
  PROCEDURE create_cust_site_use_api(errbuf             OUT VARCHAR2,
			 retcode            OUT VARCHAR2,
			 p_ship_site_use_id OUT NUMBER,
			 p_bill_site_use_id OUT NUMBER,
			 p_org_id           IN NUMBER,
			 p_party_name       IN VARCHAR2,
			 p_entity           IN VARCHAR2,
			 p_site_rec         IN xxhz_site_interface%ROWTYPE) IS

    t_cust_site_use_rec    hz_cust_account_site_v2pub.cust_site_use_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_data                 VARCHAR2(1000);
    l_msg_index_out        NUMBER;
    l_bill_site_use_id     NUMBER := NULL;
    l_ship_site_use_id     NUMBER := NULL;
    l_err_msg              VARCHAR2(2500) := NULL;
    l_flag                 VARCHAR2(2) := 'N';
    l_location_s           NUMBER := 0;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    SELECT xxobjt_sf2oa_location_id_s.nextval
    INTO   l_location_s
    FROM   dual;
    -- Create an account site use
    t_cust_site_use_rec.cust_acct_site_id   := p_site_rec.cust_acct_site_id;
    t_cust_site_use_rec.org_id              := p_org_id;
    t_cust_site_use_rec.created_by_module   := p_site_rec.interface_source; --'SALESFORCE'
    t_cust_site_use_rec.location            := substr(p_party_name, 1, 24) ||
			           ' - ' || l_location_s; -- CHG0034398
    t_cust_site_use_rec.status              := p_site_rec.uses_status;
    t_cust_site_use_rec.payment_term_id     := p_site_rec.payment_term_id;
    t_cust_site_use_rec.price_list_id       := p_site_rec.price_list_id;
    t_cust_site_use_rec.primary_salesrep_id := p_site_rec.primary_salesrep_id;
    t_cust_site_use_rec.fob_point           := p_site_rec.fob_point;
    t_cust_site_use_rec.freight_term        := p_site_rec.freight_term;
    t_cust_site_use_rec.attribute_category  := p_site_rec.uses_attribute_category;
    t_cust_site_use_rec.attribute1          := p_site_rec.uses_attribute1;
    t_cust_site_use_rec.attribute2          := p_site_rec.uses_attribute2;
    t_cust_site_use_rec.attribute3          := p_site_rec.uses_attribute3;
    t_cust_site_use_rec.attribute4          := p_site_rec.uses_attribute4;
    t_cust_site_use_rec.attribute5          := p_site_rec.uses_attribute5;
    t_cust_site_use_rec.attribute6          := p_site_rec.uses_attribute6;
    t_cust_site_use_rec.attribute7          := p_site_rec.uses_attribute7;
    t_cust_site_use_rec.attribute8          := p_site_rec.uses_attribute8;
    t_cust_site_use_rec.attribute9          := p_site_rec.uses_attribute9;
    t_cust_site_use_rec.attribute10         := p_site_rec.uses_attribute10;
    t_cust_site_use_rec.attribute11         := p_site_rec.uses_attribute11;
    t_cust_site_use_rec.attribute12         := p_site_rec.uses_attribute12;
    t_cust_site_use_rec.attribute13         := p_site_rec.uses_attribute13;
    t_cust_site_use_rec.attribute14         := p_site_rec.uses_attribute14;
    t_cust_site_use_rec.attribute15         := p_site_rec.uses_attribute15;
    t_cust_site_use_rec.attribute16         := p_site_rec.uses_attribute16;
    t_cust_site_use_rec.attribute17         := p_site_rec.uses_attribute17;
    t_cust_site_use_rec.attribute18         := p_site_rec.uses_attribute18;
    t_cust_site_use_rec.attribute19         := p_site_rec.uses_attribute19;
    t_cust_site_use_rec.attribute20         := p_site_rec.uses_attribute20;

    -- 1.2 04/03/2015 Dalit A. Raviv CHG0033183
    t_cust_site_use_rec.gl_id_rec      := p_site_rec.gl_id_rec;
    t_cust_site_use_rec.gl_id_rev      := p_site_rec.gl_id_rev;
    t_cust_site_use_rec.gl_id_unearned := p_site_rec.gl_id_unearned;
    --

    IF p_site_rec.site_use_code <> 'Ship To' THEN
      -- will be BillTo or BillTo/ShipTo
      t_cust_site_use_rec.primary_flag  := p_site_rec.primary_flag_bill;
      t_cust_site_use_rec.site_use_code := 'BILL_TO';
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_bill_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);

      fnd_file.put_line(fnd_file.log,
		'BILL_TO - l_bill_site_use_id  = ' ||
		l_bill_site_use_id);
    END IF;

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create cust site use: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
		'E create cust site use: p_cust_acct_site_id - ' ||
		p_site_rec.cust_acct_site_id);
      fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        l_err_msg := substr(errbuf || ' - ' || l_data, 1, 500);
        fnd_file.put_line(fnd_file.log,
		  'BILL_TO l_msg_data  = ' || l_msg_data);
      END LOOP;
      --p_ship_site_use_id := null;
      p_bill_site_use_id := NULL;

    ELSE
      l_flag := 'Y';
      --p_ship_site_use_id := l_ship_site_use_id
      p_bill_site_use_id := l_bill_site_use_id;
    END IF;

    IF p_site_rec.site_use_code <> 'Bill To' THEN
      -- will be ShipTo or BillTo/ShipTo
      t_cust_site_use_rec.primary_flag  := p_site_rec.primary_flag_ship;
      t_cust_site_use_rec.site_use_code := 'SHIP_TO';
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_ship_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);

    END IF;

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create cust site use: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
		'E create cust site use: p_cust_acct_site_id - ' ||
		p_site_rec.cust_acct_site_id);
      fnd_file.put_line(fnd_file.log,
		'SHIP_TO l_msg_data  = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        l_err_msg := substr(errbuf || ' - ' || l_data, 1, 500);
        fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_err_msg);
      END LOOP;
      IF l_flag = 'Y' THEN
        errbuf := substr(l_err_msg, 1, 500);
      ELSE
        errbuf := substr(errbuf || chr(10) || l_err_msg, 1, 500);
      END IF;

      p_ship_site_use_id := NULL;
    ELSE
      retcode            := 0;
      errbuf             := NULL;
      p_ship_site_use_id := l_ship_site_use_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - create_cust_site_use_api - entity - ' ||
	     p_entity || ' interface_id ' || p_site_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);

  END create_cust_site_use_api;

  --------------------------------------------------------------------
  --  name:            update_cust_site_use_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that update cust site use
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/03/2014  Dalit A. Raviv    initial build
  --  1.1  04/03/2015  Dalit A. Raviv    CHG0033183 - add the ability to update GL data
  --  1.2  30/04/2015  Michal Tzvik      CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_cust_site_use_api(errbuf     OUT VARCHAR2,
			 retcode    OUT VARCHAR2,
			 p_entity   IN VARCHAR2,
			 p_site_rec IN xxhz_site_interface%ROWTYPE) IS

    t_cust_site_use_rec hz_cust_account_site_v2pub.cust_site_use_rec_type;
    l_return_status     VARCHAR2(2000);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_data              VARCHAR2(1000);
    l_msg_index_out     NUMBER;
    l_err_msg           VARCHAR2(2500) := NULL;
    l_flag              VARCHAR2(2) := 'N';
    --l_location_s            number         := 0
    --l_org_id                number
    l_ovn NUMBER;
    -- 1.1 04/03/2015 Dalit A. Raviv CHG0033183
    l_status       VARCHAR2(1);
    l_primary_flag VARCHAR2(1);

    my_exc EXCEPTION;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    --select xxobjt_sf2oa_location_id_s.nextval into l_location_s from dual
    -- Create an account site use
    t_cust_site_use_rec.cust_acct_site_id := p_site_rec.cust_acct_site_id;
    --t_cust_site_use_rec.org_id              := l_org_id
    -- 1.2 Michal Tzvik: remove G_MISS
    t_cust_site_use_rec.payment_term_id     := p_site_rec.payment_term_id; -- remove nvl(... , fnd_api.g_miss_num)
    t_cust_site_use_rec.price_list_id       := p_site_rec.price_list_id; -- remove nvl(... , fnd_api.g_miss_num)
    t_cust_site_use_rec.primary_salesrep_id := p_site_rec.primary_salesrep_id; -- remove nvl(... , fnd_api.g_miss_num)
    t_cust_site_use_rec.fob_point           := p_site_rec.fob_point; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.freight_term        := p_site_rec.freight_term; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute_category  := p_site_rec.uses_attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute1          := p_site_rec.uses_attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute2          := p_site_rec.uses_attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute3          := p_site_rec.uses_attribute3; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute4          := p_site_rec.uses_attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute5          := p_site_rec.uses_attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute6          := p_site_rec.uses_attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute7          := p_site_rec.uses_attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute8          := p_site_rec.uses_attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute9          := p_site_rec.uses_attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute10         := p_site_rec.uses_attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute11         := p_site_rec.uses_attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute12         := p_site_rec.uses_attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute13         := p_site_rec.uses_attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute14         := p_site_rec.uses_attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute15         := p_site_rec.uses_attribute15; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute16         := p_site_rec.uses_attribute16; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute17         := p_site_rec.uses_attribute17; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute18         := p_site_rec.uses_attribute18; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute19         := p_site_rec.uses_attribute19; -- remove nvl(... , fnd_api.g_miss_char)
    t_cust_site_use_rec.attribute20         := p_site_rec.uses_attribute20; -- remove nvl(... , fnd_api.g_miss_char)

    -- 1.2 04/03/2015 Dalit A. Raviv CHG0033183
    IF p_site_rec.gl_id_rec IS NOT NULL THEN
      t_cust_site_use_rec.gl_id_rec := p_site_rec.gl_id_rec;
    END IF;
    IF p_site_rec.gl_id_rev IS NOT NULL THEN
      t_cust_site_use_rec.gl_id_rev := p_site_rec.gl_id_rev;
    END IF;
    IF p_site_rec.gl_id_unearned IS NOT NULL THEN
      t_cust_site_use_rec.gl_id_unearned := p_site_rec.gl_id_unearned;
    END IF;
    --

    IF p_site_rec.site_use_code <> 'Ship To' AND
       p_site_rec.bill_site_use_id IS NOT NULL THEN
      -- will be BillTo or BillTo/ShipTo
      BEGIN
        -- 1.1 04/03/2015 Dalit A. Raviv CHG0033183
        SELECT su.object_version_number,
	   su.status,
	   su.primary_flag
        INTO   l_ovn,
	   l_status,
	   l_primary_flag
        FROM   hz_cust_site_uses_all su
        WHERE  su.site_use_id = p_site_rec.bill_site_use_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_ovn := NULL;
      END;
      t_cust_site_use_rec.status        := p_site_rec.uses_status; -- fnd_api.g_miss_char
      t_cust_site_use_rec.primary_flag  := nvl(p_site_rec.primary_flag_bill,
			           l_primary_flag); -- fnd_api.g_miss_char
      t_cust_site_use_rec.site_use_code := 'BILL_TO';
      t_cust_site_use_rec.site_use_id   := p_site_rec.bill_site_use_id;

      hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
				      p_cust_site_use_rec     => t_cust_site_use_rec,
				      p_object_version_number => l_ovn,
				      x_return_status         => l_return_status,
				      x_msg_count             => l_msg_count,
				      x_msg_data              => l_msg_data);

      --fnd_file.put_line(fnd_file.log, 'BILL_TO - bill_site_use_id  = ' || p_site_rec.bill_site_use_id)
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf  := 'E update cust site use: ' || l_msg_data;
        retcode := 1;
        fnd_file.put_line(fnd_file.log,
		  'E update cust site use: p_cust_acct_site_id - ' ||
		  p_site_rec.cust_acct_site_id);
        fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          l_err_msg := substr(errbuf || ' - ' || l_data, 1, 500);
          fnd_file.put_line(fnd_file.log,
		    'BILL_TO l_msg_data  = ' || l_msg_data);
        END LOOP;
      ELSE
        l_flag := 'Y';
      END IF; -- create bill to
    END IF;

    IF p_site_rec.site_use_code <> 'Bill To' AND
       p_site_rec.ship_site_use_id IS NOT NULL THEN
      -- will be ShipTo or BillTo/ShipTo
      BEGIN
        -- 1.1 04/03/2015 Dalit A. Raviv CHG0033183
        SELECT su.object_version_number,
	   su.status,
	   su.primary_flag
        INTO   l_ovn,
	   l_status,
	   l_primary_flag
        FROM   hz_cust_site_uses su
        WHERE  su.site_use_id = p_site_rec.ship_site_use_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_ovn := NULL;
      END;
      -- 1.2  Michal Tzvik: remove nvl
      t_cust_site_use_rec.status        := p_site_rec.uses_status; -- remove nvl(... , fnd_api.g_miss_char)
      t_cust_site_use_rec.primary_flag  := p_site_rec.primary_flag_ship; -- remove nvl(... , fnd_api.g_miss_char)
      t_cust_site_use_rec.site_use_code := 'SHIP_TO';
      t_cust_site_use_rec.site_use_id   := p_site_rec.ship_site_use_id;

      hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
				      p_cust_site_use_rec     => t_cust_site_use_rec,
				      p_object_version_number => l_ovn,
				      x_return_status         => l_return_status,
				      x_msg_count             => l_msg_count,
				      x_msg_data              => l_msg_data);

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf  := 'E update cust site use: ' || l_msg_data;
        retcode := 1;
        fnd_file.put_line(fnd_file.log,
		  'E update cust site use: p_cust_acct_site_id - ' ||
		  p_site_rec.cust_acct_site_id);
        fnd_file.put_line(fnd_file.log,
		  'SHIP_TO l_msg_data  = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          l_err_msg := substr(errbuf || ' - ' || l_data, 1, 500);
          fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_err_msg);
        END LOOP;

      END IF; -- create ship to
      IF l_flag = 'Y' THEN
        errbuf := substr(l_err_msg, 1, 500);
      ELSE
        errbuf := substr(errbuf || ' - ' || l_err_msg, 1, 500);
      END IF;
    END IF;

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - update_cust_site_use_api - entity - ' ||
	     p_entity || ' interface_id ' || p_site_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);

  END update_cust_site_use_api;

  --------------------------------------------------------------------
  --  name:               handle_cust_account_site
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update cust account site
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_cust_site_use(errbuf             OUT VARCHAR2,
		         retcode            OUT VARCHAR2,
		         p_org_id           OUT NUMBER,
		         p_party_name       IN VARCHAR2,
		         p_ship_site_use_id OUT NUMBER,
		         p_bill_site_use_id OUT NUMBER,
		         p_entity           IN VARCHAR2,
		         p_site_rec         IN xxhz_site_interface%ROWTYPE) IS

    l_err_desc VARCHAR2(500) := NULL;
    l_err_code VARCHAR2(100) := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- case update
    IF p_site_rec.ship_site_use_id IS NOT NULL OR
       p_site_rec.bill_site_use_id IS NOT NULL THEN
      update_cust_site_use_api(errbuf     => l_err_desc, -- o v
		       retcode    => l_err_code, -- o v
		       p_entity   => 'Update Cust Site Use', -- i v
		       p_site_rec => p_site_rec -- i xxhz_site_interface%rowtype
		       );
      p_ship_site_use_id := p_site_rec.ship_site_use_id;
      p_bill_site_use_id := p_site_rec.bill_site_use_id;
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
      -- case insert
    ELSE
      IF (p_site_rec.uses_status IS NOT NULL OR
         p_site_rec.payment_term_id IS NOT NULL OR
         p_site_rec.price_list_id IS NOT NULL OR
         p_site_rec.primary_salesrep_id IS NOT NULL OR
         p_site_rec.fob_point IS NOT NULL OR
         p_site_rec.freight_term IS NOT NULL) THEN
        create_cust_site_use_api(errbuf             => l_err_desc, -- o v
		         retcode            => l_err_code, -- o v
		         p_ship_site_use_id => p_ship_site_use_id, -- o n
		         p_bill_site_use_id => p_bill_site_use_id, -- o n
		         p_org_id           => p_org_id, -- o n
		         p_party_name       => p_party_name, -- i v
		         p_entity           => 'Create Cust Site Use', -- i v
		         p_site_rec         => p_site_rec -- i xxhz_site_interface%rowtype
		         );
        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
        END IF;
      END IF;
    END IF; -- create/update

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - handle_cust_site_use - entity - ' || p_entity ||
	     ' interface_id ' || p_site_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
  END handle_cust_site_use;

  --------------------------------------------------------------------
  --  name:               handle_sites
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        Procedure that will handle site per interface record
  --                      each procedure handle the case of create or update
  --                      Handle_location          -> create/update
  --                      Handle_party_site        -> create/update
  --                      Handle_cust_account_site -> create/update
  --                      Handle_cust_site_use     -> create/update
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sites(errbuf         OUT VARCHAR2,
		 retcode        OUT VARCHAR2,
		 p_interface_id IN NUMBER) IS

    CURSOR get_site_c IS
      SELECT *
      FROM   xxhz_site_interface acc
      WHERE  acc.interface_id = p_interface_id;

    l_site_rec          xxhz_site_interface%ROWTYPE;
    l_location_id       NUMBER;
    l_party_site_id     NUMBER;
    l_cust_acct_site_id NUMBER;
    l_org_id            NUMBER;
    l_party_name        VARCHAR2(360);
    l_ship_site_use_id  NUMBER;
    l_bill_site_use_id  NUMBER;

    l_err_desc VARCHAR2(500);
    l_err_code VARCHAR2(100);

    my_exc EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    --fnd_global.apps_initialize(user_id      => 4290,  -- SALESFORCE
    --                           resp_id      => 51137, -- CRM Service Super User Objet
    --                           resp_appl_id => 514);  -- Support (obsolete)

    -- 1) reset log_message, good for running second time.
    reset_log_msg(p_interface_id, 'SITE');

    --1) get the row from interface
    FOR get_site_r IN get_site_c LOOP
      l_site_rec := get_site_r;
    END LOOP;
    --2) validation
    validate_sites(errbuf     => l_err_desc, -- o v
	       retcode    => l_err_code, -- o v
	       p_site_rec => l_site_rec); -- i/o xxhz_site_interface%rowtype

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'SITE'); -- i v

      RAISE my_exc;
    END IF;

    -- 3) fill missing info
    fill_missing_site_info(p_site_rec => l_site_rec); -- i/o xxhz_site_interface%rowtype
    -----------------------------
    -- create or update of location
    l_location_id := l_site_rec.location_id;

    handle_location(errbuf              => l_err_desc, -- o v
	        retcode             => l_err_code, -- o v
	        p_address1          => nvl(l_site_rec.address1,
			           l_site_rec.site_address), -- i v
	        p_address2          => l_site_rec.address2, -- i v
	        p_address3          => l_site_rec.address3, -- i v
	        p_address4          => l_site_rec.address4, -- i v
	        p_state             => l_site_rec.state, -- i v
	        p_postal_code       => l_site_rec.postal_code, -- i v
	        p_county            => l_site_rec.county, -- i v
	        p_country           => l_site_rec.country, -- i v
	        p_city              => l_site_rec.city, -- i v
	        p_created_by_module => l_site_rec.interface_source, -- i v
	        p_entity            => 'Handle Location', -- i v
	        p_interface_id      => l_site_rec.interface_id, -- i n
	        p_location_id       => l_location_id); -- o n

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'SITE'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;

    IF l_site_rec.location_id IS NULL THEN
      l_site_rec.location_id := l_location_id;
    END IF;
    -- connect location to party site
    handle_party_site(errbuf          => l_err_desc, -- o v
	          retcode         => l_err_code, -- o v
	          p_party_site_id => l_party_site_id, -- o n
	          p_location_id   => l_location_id, -- i n
	          p_entity        => 'Handle Party Site', -- i v
	          p_party_id      => NULL, -- i n
	          p_site_rec      => l_site_rec, -- i record
	          p_contact_rec   => NULL,
	          p_source        => 'SITE' -- i v
	          );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'SITE'); -- i v
      ROLLBACK;
      RAISE my_exc;
    ELSE
      l_site_rec.party_site_id := l_party_site_id;
    END IF;

    --if l_site_rec.party_site_id is null then
    --  l_site_rec.party_site_id := l_party_site_id
    --end if
    -- Handle cust account site
    handle_cust_account_site(errbuf              => l_err_desc, -- o v
		     retcode             => l_err_code, -- o v
		     p_cust_acct_site_id => l_cust_acct_site_id, -- o n
		     p_org_id            => l_org_id, -- o n
		     p_party_name        => l_party_name, -- o v
		     p_entity            => 'Handle Cust Account Site', -- i v
		     p_site_rec          => l_site_rec -- i record
		     );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'SITE'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;
    -- handle cust site use
    IF l_site_rec.cust_acct_site_id IS NULL THEN
      l_site_rec.cust_acct_site_id := l_cust_acct_site_id;
    END IF;

    handle_cust_site_use(errbuf             => l_err_desc, -- o v
		 retcode            => l_err_code, -- o v
		 p_ship_site_use_id => l_ship_site_use_id, -- o n
		 p_bill_site_use_id => l_bill_site_use_id, -- o n
		 p_org_id           => l_org_id, -- o n
		 p_party_name       => l_party_name, -- o v
		 p_entity           => 'Handle Cust Site Use', -- i v
		 p_site_rec         => l_site_rec -- i xxhz_site_interface%rowtype
		 );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'SITE'); -- i v
      ROLLBACK;
      RAISE my_exc;
    ELSE
      -- these are the fields that need to update back to interface record.
      l_site_rec.bill_site_use_id := l_bill_site_use_id;
      l_site_rec.ship_site_use_id := l_ship_site_use_id;
      COMMIT;
      upd_success_log(p_status      => 'SUCCESS', -- i v
	          p_entity      => 'SITE', -- i v
	          p_acc_rec     => NULL, -- i xxhz_account_interface%rowtype
	          p_site_rec    => l_site_rec, -- i xxhz_site_interface%rowtype
	          p_contact_rec => NULL -- i xxhz_contact_interface%rowtype
	          );
    END IF; -- cust site use

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'handle_sites - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_sites;

  --------------------------------------------------------------------
  --  name:               create_person_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that create HZ person
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_person_api(errbuf            OUT VARCHAR2,
		      retcode           OUT VARCHAR2,
		      p_entity          IN VARCHAR2,
		      p_contact_rec     IN xxhz_contact_interface%ROWTYPE,
		      p_person_party_id OUT NUMBER) IS

    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_party_id      NUMBER;
    x_party_number  VARCHAR2(2000);
    x_profile_id    NUMBER;
    l_prefix        VARCHAR2(150) := NULL;
  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    -- Create contact as person. If OK Continue to RelationShip
    l_upd_person.person_first_name := p_contact_rec.person_first_name;
    l_upd_person.person_last_name  := p_contact_rec.person_last_name;
    l_upd_person.created_by_module := p_contact_rec.interface_source; -- SALESFORCE
    l_upd_person.party_rec.status  := nvl(p_contact_rec.person_status, 'A');
    --l_upd_person.person_title      := p_sf_Salutation;
    IF p_contact_rec.person_pre_name_adjunct IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_prefix
        FROM   ar_lookups al
        WHERE  al.lookup_type = 'CONTACT_TITLE'
        AND    al.meaning = p_contact_rec.person_pre_name_adjunct; --'Mrs.'

        l_upd_person.person_pre_name_adjunct := l_prefix;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    hz_party_v2pub.create_person(l_success,
		         l_upd_person,
		         x_party_id,
		         x_party_number,
		         x_profile_id,
		         l_return_status,
		         l_msg_count,
		         l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'Failed create Contact: ' || l_msg_data;
      retcode := 1;

      fnd_file.put_line(fnd_file.log, 'Failed create Contact:');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;

    ELSE
      p_person_party_id := x_party_id;
    END IF; -- status if

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - create_person_api - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_person_api - ' ||
		   substr(SQLERRM, 1, 240));

  END create_person_api;

  --------------------------------------------------------------------
  --  name:               create_person_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that create HZ person
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal tzvik    CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_person_api(errbuf        OUT VARCHAR2,
		      retcode       OUT VARCHAR2,
		      p_entity      IN VARCHAR2,
		      p_contact_rec IN xxhz_contact_interface%ROWTYPE) IS

    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_profile_id    NUMBER;
    l_ovn           NUMBER := NULL;
    l_prefix        VARCHAR2(150) := NULL;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    BEGIN
      SELECT hp.object_version_number
      INTO   l_ovn
      FROM   hz_parties hp
      WHERE  hp.party_id = p_contact_rec.person_party_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_ovn := NULL;
    END;

    -- Create contact as person. If OK Continue to RelationShip
    -- 1.1 Michal Tzvik: remove G_MISS
    l_upd_person.person_first_name  := p_contact_rec.person_first_name; -- remove nvl(... , fnd_api.g_miss_char)
    l_upd_person.person_last_name   := p_contact_rec.person_last_name; -- remove nvl(... , fnd_api.g_miss_char)
    l_upd_person.party_rec.status   := p_contact_rec.person_status; -- remove nvl(... , fnd_api.g_miss_char)
    l_upd_person.party_rec.party_id := p_contact_rec.person_party_id;
    --l_upd_person.person_title       := p_sf_Salutation

    IF p_contact_rec.person_pre_name_adjunct IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_prefix
        FROM   ar_lookups al
        WHERE  al.lookup_type = 'CONTACT_TITLE'
        AND    upper(al.meaning) =
	   upper(p_contact_rec.person_pre_name_adjunct); --'Mrs.'

        l_upd_person.person_pre_name_adjunct := l_prefix;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    hz_party_v2pub.update_person(p_init_msg_list               => l_success, -- i v 'T'
		         p_person_rec                  => l_upd_person, -- i PERSON_REC_TYPE
		         p_party_object_version_number => l_ovn, -- i / o nocopy n
		         x_profile_id                  => x_profile_id, -- o nocopy n
		         x_return_status               => l_return_status, -- o nocopy v
		         x_msg_count                   => l_msg_count, -- o nocopy n
		         x_msg_data                    => l_msg_data -- o nocopy v
		         );

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E update Contact: ' || p_contact_rec.person_party_id ||
	     ' - ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Failed Update Contact -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    END IF; -- status if

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - update_person_api - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_person_api - ' ||
		   substr(SQLERRM, 1, 240));

  END update_person_api;

  --------------------------------------------------------------------
  --  name:               handle_person
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update cust account site
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_person(errbuf        OUT VARCHAR2,
		  retcode       OUT VARCHAR2,
		  p_entity      IN VARCHAR2,
		  p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE --,
		  --p_person_party_id   out number
		  ) IS

    l_person_party_id NUMBER;
    l_err_desc        VARCHAR2(500);
    l_err_code        VARCHAR2(100);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    IF p_contact_rec.person_party_id IS NULL THEN
      create_person_api(errbuf            => l_err_desc, -- o v
		retcode           => l_err_code, -- o v
		p_entity          => 'Create Person', -- i v
		p_contact_rec     => p_contact_rec, -- i xxhz_contact_interface%rowtype
		p_person_party_id => l_person_party_id -- o n
		);
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      ELSE
        p_contact_rec.person_party_id := l_person_party_id;
      END IF;
      -- case of update
    ELSE
      update_person_api(errbuf        => l_err_desc, -- o v
		retcode       => l_err_code, -- o v
		p_entity      => 'Update Person', -- i v
		p_contact_rec => p_contact_rec -- i xxhz_contact_interface%rowtype
		);
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
    END IF; -- create or update

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen EXC - handle_cust_site_use - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_person;

  --------------------------------------------------------------------
  --  name:               create_org_contact_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create org contact
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE create_org_contact_api(errbuf             OUT VARCHAR2,
		           retcode            OUT VARCHAR2,
		           p_entity           IN VARCHAR2,
		           p_contact_rec      IN OUT xxhz_contact_interface%ROWTYPE,
		           p_subject_id       IN NUMBER,
		           p_subject_type     IN VARCHAR2,
		           p_object_id        IN NUMBER,
		           p_object_type      IN VARCHAR2,
		           p_relation_code    IN VARCHAR2,
		           p_relation_type    IN VARCHAR2,
		           p_object_tble_name IN VARCHAR2,
		           p_contact_party_id OUT NUMBER,
		           p_party_number     OUT NUMBER) IS

    l_success         VARCHAR2(1) := 'T';
    p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    x_party_rel_id    NUMBER;
    x_party_id        NUMBER;
    x_party_number    VARCHAR2(2000);
    x_org_contact_id  NUMBER;
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_title           VARCHAR2(150) := NULL;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_return_status  := NULL;
    l_msg_count      := NULL;
    l_msg_data       := NULL;
    x_org_contact_id := NULL;
    x_party_id       := NULL;
    x_party_number   := NULL;

    IF p_contact_rec.job_title IS NOT NULL AND
       p_contact_rec.job_title_code IS NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_title
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'RESPONSIBILITY'
        AND    flv.language = 'US'
        AND    flv.enabled_flag = 'Y'
        AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
        AND    upper(flv.meaning) = upper(p_contact_rec.job_title);

        p_org_contact_rec.job_title_code := l_title; --p_title
        p_org_contact_rec.job_title      := p_contact_rec.job_title; --p_title
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    ELSIF p_contact_rec.job_title_code IS NOT NULL THEN
      p_org_contact_rec.job_title_code := p_contact_rec.job_title_code;
      p_org_contact_rec.job_title      := p_contact_rec.job_title; --p_title
    END IF; -- p_title

    p_org_contact_rec.created_by_module := p_contact_rec.interface_source; --'SALESFORCE'

    p_org_contact_rec.party_rel_rec.subject_id         := p_subject_id;
    p_org_contact_rec.party_rel_rec.subject_type       := p_subject_type;
    p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
    p_org_contact_rec.party_rel_rec.object_id          := p_object_id;
    p_org_contact_rec.party_rel_rec.object_type        := p_object_type;
    p_org_contact_rec.party_rel_rec.object_table_name  := p_object_tble_name;
    p_org_contact_rec.party_rel_rec.relationship_code  := p_relation_code;
    p_org_contact_rec.party_rel_rec.relationship_type  := p_relation_type;
    p_org_contact_rec.party_rel_rec.start_date         := SYSDATE;
    p_org_contact_rec.party_rel_rec.status             := nvl(p_contact_rec.org_contact_status,
					  'A');

    hz_party_contact_v2pub.create_org_contact(l_success,
			          p_org_contact_rec,
			          x_org_contact_id,
			          x_party_rel_id,
			          x_party_id,
			          x_party_number,
			          l_return_status,
			          l_msg_count,
			          l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create org contact: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'E Creation org contact - ');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      p_contact_party_id := x_party_id;
      p_party_number     := x_party_number;
    END IF; -- status if
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - create_org_contact_api - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);

  END create_org_contact_api;

  --------------------------------------------------------------------
  --  name:               update_org_contact_api
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle update org contact
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --  1.1   30/04/2015    Michal Tzvik    CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_org_contact_api(errbuf        OUT VARCHAR2,
		           retcode       OUT VARCHAR2,
		           p_entity      IN VARCHAR2,
		           p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    CURSOR get_contact_c(p_cust_account_role_id IN NUMBER) IS
      SELECT hcar.party_id contact_party_id,
	 --hps.location_id            location_id,
	 hr.subject_id person_party_id, -- person party id
	 hr.object_id hz_party_id, -- party_id (cust account)
	 hp.person_first_name person_first_name,
	 hp.person_last_name person_last_name,
	 hp.person_pre_name_adjunct,
	 hp.object_version_number hp_ovn, --
	 nvl(hoc.job_title_code, 'DAR') job_title_code,
	 hoc.org_contact_id org_contact_id,
	 hoc.object_version_number hoc_ovn, --
	 hr.relationship_id relationship_id,
	 hr.object_version_number rel_ovn, --
	 (SELECT hp.object_version_number
	  FROM   hz_parties hp
	  WHERE  hp.party_id = hr.subject_id) person_ovn
      FROM   hz_cust_account_roles hcar,
	 --hz_party_sites            hps,
	 hz_relationships hr,
	 hz_parties       hp,
	 hz_org_contacts  hoc
      WHERE  hcar.cust_account_role_id = p_cust_account_role_id --668045
	--and    hps.party_id(+)           = hcar.party_id -- contact_party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.party_id = hcar.party_id -- contact_party_id
      AND    hp.party_id = hr.subject_id -- person_party_id
      AND    hoc.party_relationship_id = hr.relationship_id;

    l_success         VARCHAR2(1) := 'T';
    l_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_cont_ovn        NUMBER := NULL;
    l_rel_ovn         NUMBER := NULL;
    l_party_ovn       NUMBER := NULL;
    l_org_contact_id  NUMBER := NULL;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_return_status := NULL;
    l_msg_count     := NULL;
    l_msg_data      := NULL;

    IF p_contact_rec.job_title_code IS NOT NULL OR
       p_contact_rec.job_title IS NOT NULL THEN
      -- 1.1 Michal Tzvik: Remove G_MISS
      l_org_contact_rec.job_title_code := p_contact_rec.job_title_code; -- remove nvl(... , fnd_api.g_miss_char)
      l_org_contact_rec.job_title      := p_contact_rec.job_title; -- remove nvl(... , fnd_api.g_miss_char)

      FOR get_contact_r IN get_contact_c(p_contact_rec.cust_account_role_id) LOOP
        l_cont_ovn                       := get_contact_r.hoc_ovn; -- p_cont_ovn
        l_rel_ovn                        := get_contact_r.rel_ovn; -- p_rel_ovn
        l_party_ovn                      := get_contact_r.hp_ovn; -- p_party_ovn
        l_org_contact_rec.org_contact_id := get_contact_r.org_contact_id; -- p_org_contact_id
        l_org_contact_id                 := get_contact_r.org_contact_id; -- p_org_contact_id
      END LOOP;
      hz_party_contact_v2pub.update_org_contact(p_init_msg_list               => l_success, -- i v
				p_org_contact_rec             => l_org_contact_rec, -- i   ORG_CONTACT_REC_TYPE
				p_cont_object_version_number  => l_cont_ovn, -- i/o nocopy n
				p_rel_object_version_number   => l_rel_ovn, -- i/o nocopy n
				p_party_object_version_number => l_party_ovn, -- i/o nocopy n
				x_return_status               => l_return_status, -- o   nocopy v
				x_msg_count                   => l_msg_count, -- o   nocopy n
				x_msg_data                    => l_msg_data); -- o   nocopy v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        errbuf  := 'E Update org contact: org_contact_id - ' ||
	       l_org_contact_id || ' - ' || l_msg_data;
        retcode := 1;
        fnd_file.put_line(fnd_file.log, 'E Update org contact -');
        fnd_file.put_line(fnd_file.log,
		  'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
        END LOOP;
        retcode := 1;
      END IF; -- status if
    END IF; -- exists data
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - update_org_contact_api - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_org_contact_api - ' ||
		   substr(SQLERRM, 1, 240));

  END update_org_contact_api;

  --------------------------------------------------------------------
  --  name:               handle_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update contacts
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_org_contact(errbuf        OUT VARCHAR2,
		       retcode       OUT VARCHAR2,
		       p_entity      IN VARCHAR2,
		       p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    --l_org_id           number
    l_party_id         NUMBER;
    l_err_desc         VARCHAR2(500);
    l_err_code         VARCHAR2(100);
    l_contact_party_id NUMBER;
    l_party_number     NUMBER;

    my_exception EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    BEGIN
      SELECT hp.party_id
      INTO   l_party_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hca.cust_account_id = p_contact_rec.cust_account_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_party_id := NULL;
    END;

    IF p_contact_rec.cust_account_role_id IS NULL THEN
      create_org_contact_api(errbuf             => l_err_code, -- o v
		     retcode            => l_err_desc, -- o v
		     p_entity           => 'Create Org Contact', -- i v
		     p_contact_rec      => p_contact_rec, -- i/o xxhz_contact_interface%rowtype
		     p_subject_id       => p_contact_rec.person_party_id, -- i n (party id that just created for the person)
		     p_subject_type     => 'PERSON', -- i v
		     p_object_id        => l_party_id, -- i n (account party id)
		     p_object_type      => 'ORGANIZATION', -- i v
		     p_relation_code    => 'CONTACT_OF', -- i v
		     p_relation_type    => 'CONTACT', -- i v
		     p_object_tble_name => 'HZ_PARTIES', -- i v
		     p_contact_party_id => l_contact_party_id, -- o n
		     p_party_number     => l_party_number); -- o n

      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      ELSE
        p_contact_rec.contact_party_id := l_contact_party_id;
      END IF;

    ELSE
      update_org_contact_api(errbuf        => l_err_code, -- o v
		     retcode       => l_err_desc, -- o v
		     p_entity      => 'Update Org Contact', -- i v
		     p_contact_rec => p_contact_rec); -- i/o xxhz_contact_interface%rowtype

      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
    END IF;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - handle_org_contact - entity - ' || p_entity ||
	     ' interface_id ' || p_contact_rec.interface_id || ' - ' ||
	     substr(SQLERRM, 1, 240);
  END handle_org_contact;

  --------------------------------------------------------------------
  --  name:            create_cust_account_role_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_role_api(errbuf        OUT VARCHAR2,
			     retcode       OUT VARCHAR2,
			     p_entity      IN VARCHAR2,
			     p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    l_success              VARCHAR2(1) := 'T';
    x_cust_account_role_id NUMBER(10);
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_index_out        NUMBER;
    l_data                 VARCHAR2(2000);
    l_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_cr_cust_acc_role_rec.party_id           := p_contact_rec.contact_party_id;
    l_cr_cust_acc_role_rec.cust_account_id    := p_contact_rec.cust_account_id;
    l_cr_cust_acc_role_rec.primary_flag       := 'N';
    l_cr_cust_acc_role_rec.role_type          := 'CONTACT';
    l_cr_cust_acc_role_rec.created_by_module  := p_contact_rec.interface_source; --'SALESFORCE'
    l_cr_cust_acc_role_rec.attribute_category := p_contact_rec.attribute_category;
    l_cr_cust_acc_role_rec.attribute1         := p_contact_rec.attribute1;
    l_cr_cust_acc_role_rec.attribute2         := p_contact_rec.attribute2;
    l_cr_cust_acc_role_rec.attribute3         := p_contact_rec.attribute3;
    l_cr_cust_acc_role_rec.attribute4         := p_contact_rec.attribute4;
    l_cr_cust_acc_role_rec.attribute5         := p_contact_rec.attribute5;
    l_cr_cust_acc_role_rec.attribute6         := p_contact_rec.attribute6;
    l_cr_cust_acc_role_rec.attribute7         := p_contact_rec.attribute7;
    l_cr_cust_acc_role_rec.attribute8         := p_contact_rec.attribute8;
    l_cr_cust_acc_role_rec.attribute9         := p_contact_rec.attribute9;
    l_cr_cust_acc_role_rec.attribute10        := p_contact_rec.attribute10;
    l_cr_cust_acc_role_rec.attribute11        := p_contact_rec.attribute11;
    l_cr_cust_acc_role_rec.attribute12        := p_contact_rec.attribute12;
    l_cr_cust_acc_role_rec.attribute13        := p_contact_rec.attribute13;
    l_cr_cust_acc_role_rec.attribute14        := p_contact_rec.attribute14;
    l_cr_cust_acc_role_rec.attribute15        := p_contact_rec.attribute15;

    hz_cust_account_role_v2pub.create_cust_account_role(l_success,
				        l_cr_cust_acc_role_rec,
				        x_cust_account_role_id,
				        l_return_status,
				        l_msg_count,
				        l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E create cust account role: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
		'Creation of cust account role Failed -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 500));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    ELSE
      p_contact_rec.cust_account_role_id := x_cust_account_role_id;
    END IF; -- Status if

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - create_cust_account_role_api - entity - ' ||
	     p_entity || ' interface_id ' || p_contact_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_cust_account_role_api - ' ||
		   substr(SQLERRM, 1, 240));
  END create_cust_account_role_api;

  --------------------------------------------------------------------
  --  name:            update_cust_account_role_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that update cust account role
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/03/2014  Dalit A. Raviv    initial build
  --  1.1  30/04/2015  Michal Tzvik      CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_cust_account_role_api(errbuf        OUT VARCHAR2,
			     retcode       OUT VARCHAR2,
			     p_entity      IN VARCHAR2,
			     p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    l_success              VARCHAR2(1) := 'T';
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_index_out        NUMBER;
    l_data                 VARCHAR2(2000);
    l_ovn                  NUMBER;
    l_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;

  BEGIN
    fnd_msg_pub.initialize;
    errbuf  := NULL;
    retcode := 0;

    l_cr_cust_acc_role_rec.cust_account_role_id := p_contact_rec.cust_account_role_id;
    --l_cr_cust_acc_role_rec.party_id             := p_contact_rec.contact_party_id
    l_cr_cust_acc_role_rec.cust_account_id := p_contact_rec.cust_account_id;
    l_cr_cust_acc_role_rec.primary_flag    := 'N';
    l_cr_cust_acc_role_rec.role_type       := 'CONTACT';
    -- 1.1 Michal Tzvik: Remove G_MISS
    l_cr_cust_acc_role_rec.attribute_category := p_contact_rec.attribute_category; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute1         := p_contact_rec.attribute1; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute2         := p_contact_rec.attribute2; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute3         := p_contact_rec.attribute3; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute4         := p_contact_rec.attribute4; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute5         := p_contact_rec.attribute5; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute6         := p_contact_rec.attribute6; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute7         := p_contact_rec.attribute7; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute8         := p_contact_rec.attribute8; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute9         := p_contact_rec.attribute9; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute10        := p_contact_rec.attribute10; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute11        := p_contact_rec.attribute11; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute12        := p_contact_rec.attribute12; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute13        := p_contact_rec.attribute13; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute14        := p_contact_rec.attribute14; -- remove nvl(... , fnd_api.g_miss_char)
    l_cr_cust_acc_role_rec.attribute15        := p_contact_rec.attribute15; -- remove nvl(... , fnd_api.g_miss_char)

    BEGIN
      SELECT hcar.object_version_number
      INTO   l_ovn
      FROM   hz_cust_account_roles hcar
      WHERE  hcar.cust_account_role_id = p_contact_rec.cust_account_role_id;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    hz_cust_account_role_v2pub.update_cust_account_role(l_success,
				        l_cr_cust_acc_role_rec,
				        l_ovn,
				        l_return_status,
				        l_msg_count,
				        l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      errbuf  := 'E Update cust account role: ' || l_msg_data;
      retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Update cust account role Failed -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 500));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        errbuf := substr(errbuf || ' - ' || l_data, 1, 500);
      END LOOP;
    END IF; -- Status if

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - update_cust_account_role_api - entity - ' ||
	     p_entity || ' interface_id ' || p_contact_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_cust_account_role_api - ' ||
		   substr(SQLERRM, 1, 240));
  END update_cust_account_role_api;

  --------------------------------------------------------------------
  --  name:               handle_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update contacts
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_cust_account_role(errbuf        OUT VARCHAR2,
			 retcode       OUT VARCHAR2,
			 p_entity      IN VARCHAR2,
			 p_contact_rec IN OUT xxhz_contact_interface%ROWTYPE) IS

    l_err_desc VARCHAR2(500);
    l_err_code VARCHAR2(100);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    IF p_contact_rec.cust_account_role_id IS NULL THEN
      create_cust_account_role_api(errbuf        => l_err_desc, -- o v
		           retcode       => l_err_code, -- o v
		           p_entity      => 'Create Cust Account Role', -- i v
		           p_contact_rec => p_contact_rec -- i/o xxhz_contact_interface%rowtype
		           );

      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
    ELSE
      NULL;
      update_cust_account_role_api(errbuf        => l_err_desc, -- o v
		           retcode       => l_err_code, -- o v
		           p_entity      => 'Update Cust Account Role', -- i v
		           p_contact_rec => p_contact_rec -- i/o xxhz_contact_interface%rowtype
		           );
      IF l_err_code <> 0 THEN
        errbuf  := l_err_desc;
        retcode := 2;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - handle_cust_account_role - entity - ' ||
	     p_entity || ' interface_id ' || p_contact_rec.interface_id ||
	     ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - handle_cust_account_role - ' ||
		   substr(SQLERRM, 1, 240));
  END handle_cust_account_role;

  --------------------------------------------------------------------
  --  name:               handle_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update contacts
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_contacts(errbuf         OUT VARCHAR2,
		    retcode        OUT VARCHAR2,
		    p_interface_id IN NUMBER) IS

    CURSOR get_contact_c IS
      SELECT *
      FROM   xxhz_contact_interface acc
      WHERE  acc.interface_id = p_interface_id;

    l_contact_rec       xxhz_contact_interface%ROWTYPE;
    l_err_desc          VARCHAR2(500);
    l_err_code          VARCHAR2(100);
    l_location_id       NUMBER;
    l_party_site_id     NUMBER;
    l_phone_contact_id  NUMBER;
    l_fax_contact_id    NUMBER;
    l_mobile_contact_id NUMBER;
    l_web_contact_id    NUMBER;
    l_email_contact_id  NUMBER;
    l_exists            VARCHAR2(10) := 'N';

    my_exc EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    --fnd_global.apps_initialize(user_id      => 4290,  -- SALESFORCE
    --                           resp_id      => 51137, -- CRM Service Super User Objet
    --                           resp_appl_id => 514)  -- Support (obsolete)

    -- 1) reset log_message, good for running second time.
    reset_log_msg(p_interface_id, 'CONTACT');

    --1) get the row from interface
    FOR get_contact_r IN get_contact_c LOOP
      l_contact_rec := get_contact_r;
    END LOOP;

    --2) validation
    validate_contacts(errbuf        => l_err_desc, -- o v
	          retcode       => l_err_code, -- o v
	          p_contact_rec => l_contact_rec -- i/o xxhz_contact_interface%rowtype
	          );
    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v

      RAISE my_exc;
    END IF;

    -- 3) fill missing info
    fill_missing_contact_info(p_contact_rec => l_contact_rec); -- i/o xxhz_contact_interface%rowtype

    -- 4) handle person
    handle_person(errbuf        => l_err_desc, -- o v
	      retcode       => l_err_code, -- o v
	      p_entity      => 'Handle HZ Person', -- i v
	      p_contact_rec => l_contact_rec -- i/o xxhz_contact_interface%rowtype
	      );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;
    -- 5) Handle location
    --if l_contact_rec.location_id is not null or (l_contact_rec.location_id is null and l_contact_rec.address1 is not null) then ????
    l_location_id := l_contact_rec.location_id;
    handle_location(errbuf              => l_err_desc, -- o v
	        retcode             => l_err_code, -- o v
	        p_address1          => l_contact_rec.address1, -- i v
	        p_address2          => l_contact_rec.address2, -- i v
	        p_address3          => l_contact_rec.address3, -- i v
	        p_address4          => l_contact_rec.address4, -- i v
	        p_state             => l_contact_rec.state, -- i v
	        p_postal_code       => l_contact_rec.postal_code, -- i v
	        p_county            => l_contact_rec.county, -- i v
	        p_country           => l_contact_rec.country, -- i v
	        p_city              => l_contact_rec.city, -- i v
	        p_created_by_module => l_contact_rec.interface_source, -- i v
	        p_entity            => 'Location', -- i v
	        p_interface_id      => l_contact_rec.interface_id, -- i n
	        p_location_id       => l_location_id); -- i/o n

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;

    --if l_contact_rec.location_id is null then
    l_contact_rec.location_id := l_location_id;
    --end if;

    -- 6) handle org contact
    handle_org_contact(errbuf        => l_err_desc, -- o v
	           retcode       => l_err_code, -- o v
	           p_entity      => 'Handle Org Contact', -- i v
	           p_contact_rec => l_contact_rec -- i/o xxhz_contact_interface%rowtype
	           );
    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;

    -- 7) handle party site
    IF l_contact_rec.location_id IS NOT NULL THEN
      -- case of update location create second time connection to party site.
      -- this is not good. i added this check to see if this location allready connect to this party site
      -- so no need to connect it again in update mode
      BEGIN
        SELECT 'Y' --x.party_site_id
        INTO   l_exists
        FROM   hz_cust_account_roles cust_roles,
	   hz_party_sites        x,
	   hz_locations          l
        WHERE  x.party_id = cust_roles.party_id --7167045
        AND    l.location_id = x.location_id
        AND    cust_roles.role_type = 'CONTACT'
        AND    cust_roles.cust_acct_site_id IS NULL
        AND    cust_roles.cust_account_role_id =
	   l_contact_rec.cust_account_role_id
        AND    x.location_id = l_contact_rec.location_id
        AND    rownum = 1;
      EXCEPTION
        WHEN OTHERS THEN
          handle_party_site(errbuf          => l_err_desc, -- o v
		    retcode         => l_err_code, -- o v
		    p_party_site_id => l_party_site_id, -- o n
		    p_location_id   => l_location_id, -- i n
		    p_entity        => 'Handle Party Site', -- i v
		    p_party_id      => l_contact_rec.person_party_id, -- i n   l_contact_rec.contact_party_id
		    p_site_rec      => NULL, -- i record
		    p_contact_rec   => l_contact_rec, -- i record
		    p_source        => 'CONTACT' -- i v
		    );

          IF l_err_code <> 0 THEN
	errbuf  := l_err_desc;
	retcode := 2;
	upd_log(p_err_desc     => l_err_desc, -- i v
	        p_status       => 'ERROR', -- i v
	        p_interface_id => p_interface_id, -- i n
	        p_entity       => 'CONTACT'); -- i v
	ROLLBACK;
	RAISE my_exc;
          ELSE
	l_contact_rec.party_site_id := l_party_site_id;

          END IF; -- handle party site
      END;
    END IF; -- location id is not null

    -- 8) handle cust account role
    handle_cust_account_role(errbuf        => l_err_desc, -- o v
		     retcode       => l_err_code, -- o v
		     p_entity      => 'Handle cust account role', -- i v
		     p_contact_rec => l_contact_rec -- i/o xxhz_contact_interface%rowtype
		     );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    END IF;
    -- 9) handle contact point
    handle_contact_point(errbuf        => l_err_desc, -- o v
		 retcode       => l_err_code, -- o v
		 p_entity      => 'Handle Contact Point', -- i v
		 p_acc_rec     => NULL, -- i xxhz_account_interface%rowtype
		 p_contact_rec => l_contact_rec, -- i/o xxhz_contact_interface%rowtype
		 --p_cust_account_role_id  => l_contact_rec.cust_account_role_id, -- i n
		 p_source            => 'CONTACT', -- i v
		 p_phone_contact_id  => l_phone_contact_id, -- o n
		 p_fax_contact_id    => l_fax_contact_id, -- o n
		 p_mobile_contact_id => l_mobile_contact_id, -- o n
		 p_web_contact_id    => l_web_contact_id, -- o n
		 p_email_contact_id  => l_email_contact_id -- o n
		 );

    IF l_err_code <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      upd_log(p_err_desc     => l_err_desc, -- i v
	  p_status       => 'ERROR', -- i v
	  p_interface_id => p_interface_id, -- i n
	  p_entity       => 'CONTACT'); -- i v
      ROLLBACK;
      RAISE my_exc;
    ELSE
      -- success
      COMMIT;
      l_contact_rec.phone_contact_point_id  := l_phone_contact_id;
      l_contact_rec.fax_contact_point_id    := l_fax_contact_id;
      l_contact_rec.mobile_contact_point_id := l_mobile_contact_id;
      l_contact_rec.web_contact_point_id    := l_web_contact_id;
      l_contact_rec.email_contact_point_id  := l_email_contact_id;
      upd_success_log(p_status      => 'SUCCESS', -- i v
	          p_entity      => 'CONTACT', -- i v
	          p_acc_rec     => NULL, -- i xxhz_account_interface%rowtype
	          p_site_rec    => NULL, -- i xxhz_site_interface%rowtype
	          p_contact_rec => l_contact_rec -- i xxhz_contact_interface%rowtype
	          );
    END IF;

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'handle_contacts - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_contacts;

  --------------------------------------------------------------------
  --  name:               main_Sf_Interface
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      22/04/2014
  --  Description:        Procedure that will
  --                      insert record to account interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/04/2014    Dalit A. Raviv  initial build
  --  1.1   19/04/2015    Michal Tzvik    CHG0034610- Upload Customer credit data from Atradius
  --------------------------------------------------------------------
  PROCEDURE insert_into_account_int(errbuf    OUT VARCHAR2,
			retcode   OUT VARCHAR2,
			p_acc_rec IN xxhz_account_interface%ROWTYPE) IS

  BEGIN
    errbuf  := NULL;
    retcode := 0;
    INSERT INTO xxhz_account_interface
      (interface_id, -- n
       batch_id,
       interface_source, -- v50
       interface_status, -- v50
       log_message, -- v500
       reference_source_id, -- v200
       account_name, -- v360
       account_number, -- v30
       cust_account_id,
       party_id,
       org_id,
       sales_channel_code, -- v80
       category_code, -- v80
       status, -- v1
       industry, -- v4000
       organization_name_phonetic, -- v320
       party_attribute_category, -- v30
       -- v150
       party_attribute1,
       party_attribute2,
       party_attribute3,
       party_attribute4,
       party_attribute5,
       party_attribute6,
       party_attribute7,
       party_attribute8,
       party_attribute9,
       party_attribute10,
       party_attribute11,
       party_attribute12,
       party_attribute13,
       party_attribute14,
       party_attribute15,
       party_attribute16,
       party_attribute17,
       party_attribute18,
       party_attribute19,
       party_attribute20,
       attribute_category, -- v30
       -- v150
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       attribute16,
       attribute17,
       attribute18,
       attribute19,
       attribute20,
       phone_contact_point_id,
       phone, -- v150
       phone_area_code, -- v10
       phone_country_code, -- v10
       phone_number, -- v40
       phone_extension, -- v20
       phone_status, -- v30
       phone_primary_flag, -- v1
       fax_contact_point_id,
       fax, -- v150
       fax_area_code, -- v10
       fax_country_code, -- v10
       fax_number, -- v40
       fax_status, -- v30
       fax_primary_flag, -- v1
       mobile_contact_point_id,
       mobile, -- v150
       mobile_area_code, -- v10
       mobile_country_code, -- v10
       mobile_number, -- v40
       mobile_status, -- v30
       mobile_primary_flag, -- v1
       web_contact_point_id,
       web_status, -- v30
       web_primary_flag, -- v1
       url, -- v2000
       email_contact_point_id,
       email_address, -- v2000
       email_status, -- v30
       email_primary_flag, -- v1
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by,
       -- CHG0034610 Michal Tzvik   19.04.2015
       duns_number,
       jgzz_fiscal_code,
       tax_reference,
       profile_amt_attribute1,
       profile_amt_attribute2,
       profile_amt_attribute3,
       profile_amt_attribute4,
       profile_amt_attribute5,
       profile_amt_attribute6,
       profile_amt_attribute7,
       profile_amt_attribute8,
       profile_amt_attribute9,
       profile_amt_attribute10)
    VALUES
      (xxhz_account_interface_s.nextval,
       p_acc_rec.batch_id,
       p_acc_rec.interface_source,
       p_acc_rec.interface_status,
       p_acc_rec.log_message,
       p_acc_rec.reference_source_id,
       p_acc_rec.account_name,
       p_acc_rec.account_number,
       p_acc_rec.cust_account_id,
       p_acc_rec.party_id,
       p_acc_rec.org_id,
       p_acc_rec.sales_channel_code,
       p_acc_rec.category_code,
       p_acc_rec.status,
       p_acc_rec.industry,
       p_acc_rec.organization_name_phonetic,
       p_acc_rec.party_attribute_category,
       p_acc_rec.party_attribute1,
       p_acc_rec.party_attribute2,
       p_acc_rec.party_attribute3,
       p_acc_rec.party_attribute4,
       p_acc_rec.party_attribute5,
       p_acc_rec.party_attribute6,
       p_acc_rec.party_attribute7,
       p_acc_rec.party_attribute8,
       p_acc_rec.party_attribute9,
       p_acc_rec.party_attribute10,
       p_acc_rec.party_attribute11,
       p_acc_rec.party_attribute12,
       p_acc_rec.party_attribute13,
       p_acc_rec.party_attribute14,
       p_acc_rec.party_attribute15,
       p_acc_rec.party_attribute16,
       p_acc_rec.party_attribute17,
       p_acc_rec.party_attribute18,
       p_acc_rec.party_attribute19,
       p_acc_rec.party_attribute20,
       p_acc_rec.attribute_category,
       p_acc_rec.attribute1,
       p_acc_rec.attribute2,
       p_acc_rec.attribute3,
       p_acc_rec.attribute4,
       p_acc_rec.attribute5,
       p_acc_rec.attribute6,
       p_acc_rec.attribute7,
       p_acc_rec.attribute8,
       p_acc_rec.attribute9,
       p_acc_rec.attribute10,
       p_acc_rec.attribute11,
       p_acc_rec.attribute12,
       p_acc_rec.attribute13,
       p_acc_rec.attribute14,
       p_acc_rec.attribute15,
       p_acc_rec.attribute16,
       p_acc_rec.attribute17,
       p_acc_rec.attribute18,
       p_acc_rec.attribute19,
       p_acc_rec.attribute20,
       p_acc_rec.phone_contact_point_id,
       p_acc_rec.phone,
       p_acc_rec.phone_area_code,
       p_acc_rec.phone_country_code,
       p_acc_rec.phone_number,
       p_acc_rec.phone_extension,
       p_acc_rec.phone_status,
       p_acc_rec.phone_primary_flag,
       p_acc_rec.fax_contact_point_id,
       p_acc_rec.fax,
       p_acc_rec.fax_area_code,
       p_acc_rec.fax_country_code,
       p_acc_rec.fax_number,
       p_acc_rec.fax_status,
       p_acc_rec.fax_primary_flag,
       p_acc_rec.mobile_contact_point_id,
       p_acc_rec.mobile,
       p_acc_rec.mobile_area_code,
       p_acc_rec.mobile_country_code,
       p_acc_rec.mobile_number,
       p_acc_rec.mobile_status,
       p_acc_rec.mobile_primary_flag,
       p_acc_rec.web_contact_point_id,
       p_acc_rec.web_status,
       p_acc_rec.web_primary_flag,
       p_acc_rec.url,
       p_acc_rec.email_contact_point_id,
       p_acc_rec.email_address,
       p_acc_rec.email_status,
       p_acc_rec.email_primary_flag,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id,
       -- CHG0034610 Michal Tzvik   19.04.2015
       p_acc_rec.duns_number,
       p_acc_rec.jgzz_fiscal_code,
       p_acc_rec.tax_reference,
       p_acc_rec.profile_amt_attribute1,
       p_acc_rec.profile_amt_attribute2,
       p_acc_rec.profile_amt_attribute3,
       p_acc_rec.profile_amt_attribute4,
       p_acc_rec.profile_amt_attribute5,
       p_acc_rec.profile_amt_attribute6,
       p_acc_rec.profile_amt_attribute7,
       p_acc_rec.profile_amt_attribute8,
       p_acc_rec.profile_amt_attribute9,
       p_acc_rec.profile_amt_attribute10);
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed to insert - xxhz_account_interface - ' ||
	     p_acc_rec.interface_source || ' - ' ||
	     p_acc_rec.cust_account_id;
      retcode := 1;
  END insert_into_account_int;

  --------------------------------------------------------------------
  --  name:               insert_into_site_int
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      24/04/2014
  --  Description:        Procedure that will
  --                      insert record to site interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_site_int(errbuf     OUT VARCHAR2,
		         retcode    OUT VARCHAR2,
		         p_site_rec IN xxhz_site_interface%ROWTYPE) IS

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    INSERT INTO xxhz_site_interface
      (interface_id, -- n
       batch_id, -- n
       parent_interface_id, -- n
       interface_source, -- n
       interface_status, -- v
       log_message, -- v
       reference_source_id, -- v(200) sf_site_id
       -- site info.
       cust_acct_site_id, -- n      cust_acct_site -- if null insert else update
       cust_account_id, -- n      cust_acct_site -- if null then err site must have account relate to
       party_site_id, -- n      hz_party_sites
       party_site_number, -- v      hz_party_sites
       ship_site_use_id, -- n      hz_cust_site_uses_all
       bill_site_use_id, -- n      hz_cust_site_uses_all
       site_use_code, -- v(30)  hz_cust_site_uses_all
       primary_flag_bill, -- v(1)   hz_cust_site_uses_all
       primary_flag_ship, -- v(1)   hz_cust_site_uses_all
       site_status, -- v(1)   cust_acct_site            -- default a
       uses_status, -- v(1)   hz_cust_site_uses_all     -- default a
       payment_term_id, -- n      hz_cust_site_uses_all
       price_list_id, -- n      hz_cust_site_uses_all
       primary_salesrep_id, -- n      hz_cust_site_uses_all
       fob_point, -- v(30)  hz_cust_site_uses_all
       freight_term, -- v(30)  hz_cust_site_uses_all
       site_address, -- v(500) hz_locations
       address1, -- v(240) hz_locations
       address2, -- v(240) hz_locations
       address3, -- v(240) hz_locations
       address4, -- v(240) hz_locations
       state, -- v(60)  hz_locations
       postal_code, -- v(60)  hz_locations
       county, -- v(60)  hz_locations
       country, -- v(30)  hz_locations -> fnd_territories_tl.territory_code (territory_short_name)
       city, -- v(30)  hz_locations
       location_id, -- n      hz_locations
       location, -- v(40)  hz_locations
       org_id, -- n      hz_cust_site_uses_all     --- validation must be required
       site_attribute_category, -- v(30)
       -- v(150)
       site_attribute1,
       site_attribute2,
       site_attribute3,
       site_attribute4,
       site_attribute5,
       site_attribute6,
       site_attribute7,
       site_attribute8,
       site_attribute9,
       site_attribute10,
       site_attribute11,
       site_attribute12,
       site_attribute13,
       site_attribute14,
       site_attribute15,
       site_attribute16,
       site_attribute17,
       site_attribute18,
       site_attribute19,
       site_attribute20,
       uses_attribute_category, -- v(30)
       uses_attribute1,
       uses_attribute2,
       uses_attribute3,
       uses_attribute4,
       uses_attribute5,
       uses_attribute6,
       uses_attribute7,
       uses_attribute8,
       uses_attribute9,
       uses_attribute10,
       uses_attribute11,
       uses_attribute12,
       uses_attribute13,
       uses_attribute14,
       uses_attribute15,
       uses_attribute16,
       uses_attribute17,
       uses_attribute18,
       uses_attribute19,
       uses_attribute20,
       last_update_date, -- d
       last_updated_by, -- n
       last_update_login, -- n
       creation_date, -- d
       created_by) -- n
    VALUES
      (xxhz_site_interface_s.nextval,
       p_site_rec.batch_id,
       p_site_rec.parent_interface_id,
       p_site_rec.interface_source,
       p_site_rec.interface_status,
       p_site_rec.log_message,
       p_site_rec.reference_source_id,
       p_site_rec.cust_acct_site_id,
       p_site_rec.cust_account_id,
       p_site_rec.party_site_id,
       p_site_rec.party_site_number,
       p_site_rec.ship_site_use_id,
       p_site_rec.bill_site_use_id,
       p_site_rec.site_use_code,
       p_site_rec.primary_flag_bill,
       p_site_rec.primary_flag_ship,
       p_site_rec.site_status,
       p_site_rec.uses_status,
       p_site_rec.payment_term_id,
       p_site_rec.price_list_id,
       p_site_rec.primary_salesrep_id,
       p_site_rec.fob_point,
       p_site_rec.freight_term,
       p_site_rec.site_address,
       p_site_rec.address1,
       p_site_rec.address2,
       p_site_rec.address3,
       p_site_rec.address4,
       p_site_rec.state,
       p_site_rec.postal_code,
       p_site_rec.county,
       p_site_rec.country,
       p_site_rec.city,
       p_site_rec.location_id,
       p_site_rec.location,
       p_site_rec.org_id,
       p_site_rec.site_attribute_category,
       p_site_rec.site_attribute1,
       p_site_rec.site_attribute2,
       p_site_rec.site_attribute3,
       p_site_rec.site_attribute4,
       p_site_rec.site_attribute5,
       p_site_rec.site_attribute6,
       p_site_rec.site_attribute7,
       p_site_rec.site_attribute8,
       p_site_rec.site_attribute9,
       p_site_rec.site_attribute10,
       p_site_rec.site_attribute11,
       p_site_rec.site_attribute12,
       p_site_rec.site_attribute13,
       p_site_rec.site_attribute14,
       p_site_rec.site_attribute15,
       p_site_rec.site_attribute16,
       p_site_rec.site_attribute17,
       p_site_rec.site_attribute18,
       p_site_rec.site_attribute19,
       p_site_rec.site_attribute20,
       p_site_rec.uses_attribute_category,
       p_site_rec.uses_attribute1,
       p_site_rec.uses_attribute2,
       p_site_rec.uses_attribute3,
       p_site_rec.uses_attribute4,
       p_site_rec.uses_attribute5,
       p_site_rec.uses_attribute6,
       p_site_rec.uses_attribute7,
       p_site_rec.uses_attribute8,
       p_site_rec.uses_attribute9,
       p_site_rec.uses_attribute10,
       p_site_rec.uses_attribute11,
       p_site_rec.uses_attribute12,
       p_site_rec.uses_attribute13,
       p_site_rec.uses_attribute14,
       p_site_rec.uses_attribute15,
       p_site_rec.uses_attribute16,
       p_site_rec.uses_attribute17,
       p_site_rec.uses_attribute18,
       p_site_rec.uses_attribute19,
       p_site_rec.uses_attribute20,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed to insert - xxhz_site_interface - ' ||
	     p_site_rec.interface_source || ' - ' ||
	     p_site_rec.cust_acct_site_id;
      retcode := 1;
  END;

  --------------------------------------------------------------------
  --  name:               insert_into_site_int
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      24/04/2014
  --  Description:        Procedure that will
  --                      insert record to site interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_contact_int(errbuf        OUT VARCHAR2,
			retcode       OUT VARCHAR2,
			p_contact_rec IN xxhz_contact_interface%ROWTYPE) IS

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    INSERT INTO xxhz_contact_interface
      (interface_id,
       batch_id,
       parent_interface_id,
       interface_source, -- v50
       interface_status, -- v50
       log_message, -- v500
       reference_source_id, -- v200
       cust_account_role_id,
       cust_account_id,
       contact_party_id,
       cust_acct_site_id,
       person_party_id,
       person_last_name, -- v150
       person_first_name, -- v150
       person_pre_name_adjunct, -- v30
       person_status, -- v1
       contact_number, -- v30
       party_site_number, -- v30
       party_site_id,
       location_id,
       country, -- v60
       address1, -- v240
       address2, -- v240
       address3, -- v240
       address4, -- v240
       city, -- v60
       postal_code, -- v60
       state, -- v60
       county, -- v60
       job_title, -- v100
       job_title_code, -- v30
       org_contact_status, -- v1
       phone_contact_point_id,
       phone, -- v150
       phone_area_code, -- v10
       phone_country_code, -- v10
       phone_number, -- v40
       phone_extension, -- v20
       phone_status, -- v30
       phone_primary_flag, -- v1
       fax_contact_point_id,
       fax, -- v150
       fax_area_code, -- v10
       fax_country_code, -- v10
       fax_number, -- v40
       fax_status, -- v30
       fax_primary_flag, -- v1
       mobile_contact_point_id,
       mobile, -- v150
       mobile_area_code, -- v10
       mobile_country_code, -- v10
       mobile_number, -- v40
       mobile_status, -- v30
       mobile_primary_flag, -- v1
       web_contact_point_id,
       web_url, -- v2000
       web_status, -- v30
       web_primary_flag, -- v1
       email_contact_point_id,
       email_address, -- v2000
       email_status, -- v30
       email_primary_flag, -- v1
       org_id,
       attribute_category, -- v30
       -- v150
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (xxhz_contact_interface_s.nextval,
       p_contact_rec.batch_id,
       p_contact_rec.parent_interface_id,
       p_contact_rec.interface_source,
       p_contact_rec.interface_status,
       p_contact_rec.log_message,
       p_contact_rec.reference_source_id,
       p_contact_rec.cust_account_role_id,
       p_contact_rec.cust_account_id,
       p_contact_rec.contact_party_id,
       p_contact_rec.cust_acct_site_id,
       p_contact_rec.person_party_id,
       p_contact_rec.person_last_name,
       p_contact_rec.person_first_name,
       p_contact_rec.person_pre_name_adjunct,
       p_contact_rec.person_status,
       p_contact_rec.contact_number,
       p_contact_rec.party_site_number,
       p_contact_rec.party_site_id,
       p_contact_rec.location_id,
       p_contact_rec.country,
       p_contact_rec.address1,
       p_contact_rec.address2,
       p_contact_rec.address3,
       p_contact_rec.address4,
       p_contact_rec.city,
       p_contact_rec.postal_code,
       p_contact_rec.state,
       p_contact_rec.county,
       p_contact_rec.job_title,
       p_contact_rec.job_title_code,
       p_contact_rec.org_contact_status,
       p_contact_rec.phone_contact_point_id,
       p_contact_rec.phone,
       p_contact_rec.phone_area_code,
       p_contact_rec.phone_country_code,
       p_contact_rec.phone_number,
       p_contact_rec.phone_extension,
       p_contact_rec.phone_status,
       p_contact_rec.phone_primary_flag,
       p_contact_rec.fax_contact_point_id,
       p_contact_rec.fax,
       p_contact_rec.fax_area_code,
       p_contact_rec.fax_country_code,
       p_contact_rec.fax_number,
       p_contact_rec.fax_status,
       p_contact_rec.fax_primary_flag,
       p_contact_rec.mobile_contact_point_id,
       p_contact_rec.mobile,
       p_contact_rec.mobile_area_code,
       p_contact_rec.mobile_country_code,
       p_contact_rec.mobile_number,
       p_contact_rec.mobile_status,
       p_contact_rec.mobile_primary_flag,
       p_contact_rec.web_contact_point_id,
       p_contact_rec.web_url,
       p_contact_rec.web_status,
       p_contact_rec.web_primary_flag,
       p_contact_rec.email_contact_point_id,
       p_contact_rec.email_address,
       p_contact_rec.email_status,
       p_contact_rec.email_primary_flag,
       p_contact_rec.org_id,
       p_contact_rec.attribute_category,
       --1 - ww_global_main_contact, 2 - site_main_contact, 3 - gam_contact, 4 - contact_type
       p_contact_rec.attribute1,
       p_contact_rec.attribute2,
       p_contact_rec.attribute3,
       p_contact_rec.attribute4,
       p_contact_rec.attribute5,
       p_contact_rec.attribute6,
       p_contact_rec.attribute7,
       p_contact_rec.attribute8,
       p_contact_rec.attribute9,
       p_contact_rec.attribute10,
       p_contact_rec.attribute11,
       p_contact_rec.attribute12,
       p_contact_rec.attribute13,
       p_contact_rec.attribute14,
       p_contact_rec.attribute15,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed to insert - xxhz_contact_interface - ' ||
	     p_contact_rec.interface_source || ' - ' ||
	     p_contact_rec.cust_account_role_id;
      retcode := 1;

  END insert_into_contact_int;

  --------------------------------------------------------------------
  --  name:               main_process_Accounts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/04/2014
  --  Description:        Procedure that will
  --                      1) Handle sites -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2014    Dalit A. Raviv  initial build
  --  1.1   21/04/2015    Michal Tzvik    CHG0034610 - Add parameter p_source
  --  1.2   04.03.19      Lingaraj       INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  PROCEDURE main_process_accounts(errbuf   OUT VARCHAR2,
		          retcode  OUT VARCHAR2,
		          p_source IN VARCHAR2) IS

    -- population
    CURSOR account_int_c IS
      SELECT *
      FROM   xxhz_account_interface s
      WHERE  s.interface_status = 'NEW'
      AND    (p_source IS NULL OR s.interface_source = p_source)
      ORDER  BY s.interface_source;

    l_err_desc  VARCHAR2(500);
    l_err_code  VARCHAR2(100);
    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_source    VARCHAR2(50) := 'DAR';

    my_exc EXCEPTION;

  BEGIN
    -- 1) process interfaces records
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log,
	          'Process records from account interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Process records from account interface');
    FOR account_int_r IN account_int_c LOOP
      IF l_source <> account_int_r.interface_source THEN
        l_source   := account_int_r.interface_source;
        l_err_desc := NULL;
        l_err_code := 0;
        -- 1) set apps initialize
        set_apps_initialize(p_interface_source => 'SALESFORCE', -- i v
		    errbuf             => l_err_desc, -- o v
		    retcode            => l_err_code); -- o v

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          fnd_file.put_line(fnd_file.log,
		    'Problem set apps initialize to source ' ||
		    account_int_r.interface_source);
          dbms_output.put_line('Problem set apps initialize to source ' ||
		       account_int_r.interface_source);
          RAISE my_exc;
        END IF;
      END IF;

      interface_status(p_status       => 'IN_PROCESS', -- i v
	           p_interface_id => account_int_r.interface_id, -- i n
	           p_entity       => 'ACCOUNT'); -- i v

      l_err_desc := NULL;
      l_err_code := 0;
      handle_accounts(errbuf         => l_err_desc, -- o v
	          retcode        => l_err_code, -- o v
	          p_interface_id => account_int_r.interface_id); -- i n

      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
        dbms_output.put_line('Err - ' || l_err_desc);
      /*  INC0148774 Commented
      ELSE
        -- 2) enter record to oa2sf interface
        l_oa2sf_rec.source_id   := account_int_r.cust_account_id;
        l_oa2sf_rec.source_name := 'ACCOUNT';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        COMMIT;
      */
      END IF; -- handle account return with error
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'main_process_accounts - Failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END main_process_accounts;

  --------------------------------------------------------------------
  --  name:               main_process_sites
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      27/04/2014
  --  Description:        Procedure that will
  --                      1) Handle sites -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/04/2014    Dalit A. Raviv  initial build
  --  1.1 04.03.19        Lingaraj         INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  PROCEDURE main_process_sites(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2) IS

    -- population
    CURSOR site_int_c IS
      SELECT *
      FROM   xxhz_site_interface s
      WHERE  s.interface_status = 'NEW'
      --and    s.interface_id = 11 -- this is only for test
      ORDER  BY s.interface_source;

    l_err_desc  VARCHAR2(500);
    l_err_code  VARCHAR2(100);
    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_source    VARCHAR2(50) := 'DAR';

    my_exc EXCEPTION;

  BEGIN

    -- 1) process interfaces records
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log, 'Process records from site interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Process records from site interface');
    FOR site_int_r IN site_int_c LOOP

      IF l_source <> site_int_r.interface_source THEN
        l_source   := site_int_r.interface_source;
        l_err_desc := NULL;
        l_err_code := 0;
        -- 1) set apps initialize
        set_apps_initialize(p_interface_source => 'SALESFORCE', -- i v
		    errbuf             => l_err_desc, -- o v
		    retcode            => l_err_code); -- o v

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          fnd_file.put_line(fnd_file.log,
		    'Problem set apps initialize to source ' ||
		    site_int_r.interface_source);
          dbms_output.put_line('Problem set apps initialize to source ' ||
		       site_int_r.interface_source);
          RAISE my_exc;
        END IF;
      END IF;

      interface_status(p_status       => 'IN_PROCESS', -- i v
	           p_interface_id => site_int_r.interface_id, -- i n
	           p_entity       => 'SITE'); -- i v  'ACCOUNT'  'CONTACT'

      l_err_desc := NULL;
      l_err_code := 0;
      handle_sites(errbuf         => l_err_desc, -- o v
	       retcode        => l_err_code, -- o v
	       p_interface_id => site_int_r.interface_id); -- i n

      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
        dbms_output.put_line('Err - ' || l_err_desc);
      /*  INC0148774 Commented
      ELSE
        -- 2) enter record to oa2sf interface
        l_oa2sf_rec.source_id   := site_int_r.cust_acct_site_id;
        l_oa2sf_rec.source_name := 'SITE';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        COMMIT;
      */
      END IF; -- handle site return with error
    END LOOP; -- interface

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'main_process_sites - Failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END main_process_sites;

  --------------------------------------------------------------------
  --  name:               main_process_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      27/04/2014
  --  Description:        Procedure that will
  --                      1) Handle contacts -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/04/2014    Dalit A. Raviv  initial build
  --  1.1   04.03.19      Lingaraj       INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  PROCEDURE main_process_contacts(errbuf  OUT VARCHAR2,
		          retcode OUT VARCHAR2) IS
    -- Population
    CURSOR contact_int_c IS
      SELECT *
      FROM   xxhz_contact_interface s
      WHERE  s.interface_status = 'NEW'
      --and    s.interface_id             = 2 -- for debug
      ORDER  BY s.interface_source;

    l_err_desc  VARCHAR2(500);
    l_err_code  VARCHAR2(100);
    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_source    VARCHAR2(50) := 'DAR';

    my_exc EXCEPTION;

  BEGIN

    -- 1) process interfaces records
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log,
	          'Process records from contact interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Process records from contact interface');
    FOR contact_int_r IN contact_int_c LOOP
      IF l_source <> contact_int_r.interface_source THEN
        l_source   := contact_int_r.interface_source;
        l_err_desc := NULL;
        l_err_code := 0;
        -- 1) set apps initialize
        set_apps_initialize(p_interface_source => 'SALESFORCE', -- i v
		    errbuf             => l_err_desc, -- o v
		    retcode            => l_err_code); -- o v

        IF l_err_code <> 0 THEN
          errbuf  := l_err_desc;
          retcode := 2;
          fnd_file.put_line(fnd_file.log,
		    'Problem set apps initialize to source ' ||
		    contact_int_r.interface_source);
          dbms_output.put_line('Problem set apps initialize to source ' ||
		       contact_int_r.interface_source);
          RAISE my_exc;
        END IF;
      END IF;

      interface_status(p_status       => 'IN_PROCESS', -- i v
	           p_interface_id => contact_int_r.interface_id, -- i n
	           p_entity       => 'CONTACT'); -- i v  'ACCOUNT'

      l_err_desc := NULL;
      l_err_code := 0;
      handle_contacts(errbuf         => l_err_desc, -- o v
	          retcode        => l_err_code, -- o v
	          p_interface_id => contact_int_r.interface_id); -- i n

      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
        dbms_output.put_line('Err - ' || l_err_desc);
      /*  INC0148774 Commented
      ELSE
        -- 2) enter record to oa2sf interface
        l_oa2sf_rec.source_id   := contact_int_r.cust_account_role_id;
        l_oa2sf_rec.source_name := 'CONTACT';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        COMMIT;
      */
      END IF; -- handle site return with error
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'main_process_contacts - Failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END main_process_contacts;
  --------------------------------------------------------------------
  --  name:               main_process_locations
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      13/01/2015
  --  Description:        Handle locations
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/01/2015    Michal Tzvik    CHG0033182: initial build
  --------------------------------------------------------------------
  PROCEDURE main_process_locations(errbuf   OUT VARCHAR2,
		           retcode  OUT VARCHAR2,
		           p_source IN VARCHAR2) IS
    -- Population
    CURSOR loc_int_c(p_source VARCHAR2) IS
      SELECT *
      FROM   xxhz_locations_interface s
      WHERE  s.interface_status = 'NEW'
      AND    (p_source IS NULL OR s.interface_source = p_source)
      ORDER  BY s.interface_source;

    l_err_desc VARCHAR2(500);
    l_err_code VARCHAR2(100);
    l_source   VARCHAR2(50) := 'DAR';

    l_location_id NUMBER;
    my_exc EXCEPTION;
  BEGIN
    -- 1) process interfaces records
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log,
	          'Process records from location interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Process records from location interface');
    FOR loc_int_r IN loc_int_c(p_source) LOOP
      BEGIN
        SAVEPOINT process_location;
        IF l_source <> loc_int_r.interface_source THEN
          l_source   := loc_int_r.interface_source;
          l_err_desc := NULL;
          l_err_code := 0;
          -- 1) set apps initialize
          set_apps_initialize(p_interface_source => loc_int_r.interface_source, -- i v
		      errbuf             => l_err_desc, -- o v
		      retcode            => l_err_code); -- o v

          IF l_err_code <> 0 THEN
	l_err_desc := 'Problem set apps initialize to source ' ||
		  loc_int_r.interface_source;

	-- errbuf  := l_err_desc
	--  retcode := 2
	-- fnd_file.put_line(fnd_file.log, 'Problem set apps initialize to source ' ||
	--                    loc_int_r.interface_source)
	-- dbms_output.put_line('Problem set apps initialize to source ' ||
	--                      loc_int_r.interface_source)

	RAISE my_exc;
          END IF;
        END IF;

        interface_status(p_status       => 'IN_PROCESS', -- i v
		 p_interface_id => loc_int_r.interface_id, -- i n
		 p_entity       => 'LOCATION'); -- i v

        l_err_desc    := NULL;
        l_err_code    := 0;
        l_location_id := loc_int_r.location_id;

        validate_locations(errbuf         => l_err_desc, -- o v
		   retcode        => l_err_code, -- o v
		   p_location_rec => loc_int_r);
        IF l_err_code <> '0' THEN
          l_err_desc := 'Validation failed: ' || l_err_desc; /*
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        retcode := 2;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        fnd_file.put_line(fnd_file.log, 'Validation failed: ' || l_err_desc);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        dbms_output.put_line('Validation failed: ' || l_err_desc);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        upd_log(p_err_desc => l_err_desc, -- i v
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_status => 'ERROR', -- i v
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_interface_id => loc_int_r.interface_id, -- i n
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_entity => 'LOCATION'); -- i v*/
          RAISE my_exc;
        END IF;

        handle_location(errbuf              => l_err_desc, -- o v
		retcode             => l_err_code, -- o v
		p_address1          => loc_int_r.address1, -- i v
		p_address2          => loc_int_r.address2, -- i v
		p_address3          => loc_int_r.address3, -- i v
		p_address4          => loc_int_r.address4, -- i v
		p_state             => loc_int_r.state, -- i v
		p_postal_code       => loc_int_r.postal_code, -- i v
		p_county            => loc_int_r.county, -- i v
		p_country           => loc_int_r.country, -- i v
		p_city              => loc_int_r.city, -- i v
		p_created_by_module => loc_int_r.interface_source, -- i v
		p_entity            => 'Location', -- i v
		p_interface_id      => loc_int_r.interface_id, -- i n
		p_location_id       => l_location_id); -- i/o n

        IF l_err_code <> 0 THEN
          -- errbuf  := l_err_desc
          --retcode := 2
          --ROLLBACK
          --upd_log(p_err_desc => l_err_desc, -- i v
          --        p_status => 'ERROR', -- i v
          --       p_interface_id => loc_int_r.interface_id, -- i n
          --       p_entity => 'LOCATION')-- i v
          RAISE my_exc;
        ELSE
          loc_int_r.location_id := l_location_id;
          COMMIT;
          upd_success_log(p_status       => 'SUCCESS', -- i v
		  p_entity       => 'LOCATION', -- i v
		  p_acc_rec      => NULL, -- i xxhz_account_interface%rowtype
		  p_site_rec     => NULL, -- i xxhz_site_interface%rowtype
		  p_contact_rec  => NULL, -- i xxhz_contact_interface%rowtype
		  p_location_rec => loc_int_r -- i xxhz_location_interface%rowtype
		  );

        END IF; -- handle location return with error
      EXCEPTION
        WHEN my_exc THEN
          errbuf  := l_err_desc;
          retcode := 2;
          ROLLBACK TO process_location;
          upd_log(p_err_desc     => l_err_desc, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => loc_int_r.interface_id, -- i n
	      p_entity       => 'LOCATION'); -- i v
        WHEN OTHERS THEN
          errbuf  := 'Unexpected error in main_process_locations';
          retcode := 2;
          ROLLBACK TO process_location;
          upd_log(p_err_desc     => SQLERRM, -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => loc_int_r.interface_id, -- i n
	      p_entity       => 'LOCATION'); -- i v
      END;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'main_process_locations - Failed - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;

  END main_process_locations;
  --------------------------------------------------------------------
  --  name:               main_Sf_Interface
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      13/04/2014
  --  Description:        Procedure that will
  --                      1) look at BI database for cahnges that done in salesforce.
  --                      2) all diff record that found will enter row to interface tables (account, site, contact)
  --                      3) when success enter record to xxobjt_oa2sf_interface table to
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE main_sf_interface(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2) IS

    -- Get data from BI schema.
    CURSOR get_acc_c IS
      SELECT a.id reference_source_id, -- to check if this field is number or varchar !!!!!!!!!!!!!!!!!!!!!
	 a.name account_name, --
	 a.oracle_account_number__c account_number, --
	 a.oe_id__c oracle_account_id, -- cust_account_id
	 a.id /*account_id2__c*/ sf_account_id, -- attribute4 at hz_cust_accounts
	 a.sales_channel__c sales_channel, -- sales_channel_code
	 a.industry industry, -- industry
	 a.serv_phoneticname__c organization_name_phonetic, -- organization_name_phonetic
	 decode(a.serv_kamcustomer__c, 'False', 'N', 'Y') kam_customer, -- party_attribute8
	 decode(a.serv_vipcustomer__c, 'False', 'N', 'Y') vip_customer, -- party_attribute7
	 decode(a.serv_global_account_del__c, 'False', 'N', 'Y') global_account, -- party_attribute5 ??? ????
	 to_char(a.serv_gaprogramdate_del__c, 'DD-MON-YYYY hh24:mi:ss') ga_program_date, -- party_attribute4 ??? ????
	 a.oracle_status__c status, -- Status
	 --
	 a.fax     fax,
	 a.phone   phone,
	 a.website web_url,
	 --
	 ou.org_id__c operating_unit_id -- Oracle operating unit id
      --
      -- * party_id
      -- * org_id         (party_attribute3)  customer_operating_unit form view
      -- * category_code
      -- * phone_contact_point_id fax_contact_point_id mobile_contact_point_id web_contact_point_id email_contact_point_id
      -- * sales_territory_c,-- ????? -- AP   -> sales_territory exist in view but do not exist at interface table and not in API
      --    for what do we need this info???
      -- * customer_operating_unit ??
      --
      FROM   xxsf_account                a, -- this is a synonym to ACCOUNT@SOURCE_SF (BI DB)
	 xxsf_serv_operating_unit__c ou
      WHERE  a.is_dirty__c = 1 -- SF sign the record when it updated
      AND    a.oe_id__c IS NOT NULL -- If there is a value it is update.
      AND    a.serv_operating_unit__c = ou.id(+);

    CURSOR get_site_c IS
      SELECT s.id reference_source_id, -- serv_sf_id__c
	 s.name location, -- site name
	 s.account__c sf_account_id, -- (hz_cust_accounts.attribute4) need to convert to oracle account_id
	 a.oe_id__c cust_account_id,
	 decode(s.primary_billing_address__c, 1, 'Y', 'N') primary_bill_to, -- true/false
	 decode(s.primary_shipping_address__c, 1, 'Y', 'N') primary_ship_to, -- true/false
	 s.address__c site_address, -- site_address  (concat of address1-4)
	 s.city__c site_city, -- city
	 s.state_region__c state, -- state
	 s.country__c site_country, -- country
	 s.oe_id__c oracle_site_id, -- cust_acct_site_id      (hz_cust_acct_sites_all .cust_acct_site_id)
	 s.zipcode_postal_code__c site_postal_code, -- postal_code
	 s.county__c site_county, -- county
	 s.site_usage__c site_usage, -- site_use_code -> bill to/ship to, ship to, bill to
	 decode(s.status__c, 'Active', 'A', 'I') site_status, -- ?????
	 --s.status__c                    uses_status,     -- ????? active/inactive -- !!!!!! WHAT IS THE DIFFERENCE
	 s.serv_salesperson_id__c      primary_salesrep_id, -- hold id by number
	 pt.oe_id__c                   payment_term_id,
	 b.oe_id__c                    sf_price_list_id,
	 ou.org_id__c                  operating_unit_id, -- Oracle operating unit id
	 s.serv_oe_location_id__c      location_id, --
	 s.serv_oe_party_site_id__c    party_site_id, --
	 s.serv_oe_bill_site_use_id__c bill_site_use_id,
	 s.serv_oe_ship_site_use_id__c ship_site_use_id,
	 s.lastmodifieddate,
	 s.lastmodifiedbyid
      FROM   xxsf_sites__c               s, -- this is a synonym to SITES__C@SOURCE_SF (BI DB)
	 xxsf_serv_operating_unit__c ou,
	 xxsf_serv_payment_term__c   pt,
	 xxsf_pricebook2             b,
	 xxsf_account                a
      WHERE  s.serv_operating_unit__c = ou.id(+)
      AND    s.serv_payment_term__c = pt.id(+)
      AND    s.serv_price_list__c = b.id(+)
      AND    s.is_dirty__c = 1 -- SF sign the record when it updated
      AND    s.oe_id__c IS NOT NULL -- If there is a value it is update.
      AND    s.serv_oe_location_id__c IS NOT NULL -- If there is a value it is update.
      AND    a.id = s.account__c;
    --and    s.lastmodifieddate > sysdate - 6/24 -- for test
    -- and s.serv_oe_location_id__c is not null

    CURSOR get_contact_c IS
      SELECT c.id       reference_source_id,
	 a.oe_id__c cust_account_id,
	 --contact_party_id,                 -- ????????
	 --cust_acct_site_id,                -- ????????
	 REPLACE(c.lastname, 'xxxxx') person_last_name,
	 c.firstname person_first_name,
	 c.salutation person_pre_name_adjunct, -- Prefix
	 c.name, --????
	 REPLACE(c.phone, 'xxxxx') phone,
	 c.fax fax,
	 c.mobilephone mobile,
	 c.email email_address,
	 c.title,
	 c.title__c job_title,
	 c.oracle_contact_id__c contact_id, -- the same value as oe_id__c
	 c.oe_id__c cust_account_role_id, -- contact_id
	 c.address_1__c address1,
	 --address2,
	 --address3,
	 --address4,
	 c.country__c             country,
	 c.city__c                city,
	 c.zipcode_postal_code__c postal_code,
	 c.state_region__c        state,
	 --c.county__c county, yuval
	 decode(c.serv_active__c, 'Active', 'A', 'I') org_contact_status,
	 decode(c.serv_active__c, 'Active', 'A', 'I') person_status,
	 c.serv_gamcontact__c attribute3, -- ??? gam_contact
	 c.serv_sitemaincontact__c attribute2, -- ??? site_main_contact
	 c.serv_ww_global_main_contact__c attribute1, -- ??? ww_global_main_contact
	 --nvl(cust_cont.attribute4, 'Sales') Contact_type,  ??? the name at SF ????
	 c.serv_fdm_contact_id__c,
	 c.serv_oe_person_party_id__c     person_party_id,
	 c.serv_oe_location_id__c         location_id,
	 c.serv_oe_party_site_id__c       party_site_id,
	 c.serv_oe_contact_party_id__c    contact_party_id,
	 c.serv_oe_phone_contact_point_id phone_contact_point_id,
	 c.serv_oe_fax_contact_point_id__ fax_contact_point_id,
	 c.serv_oe_web_contact_point_id__ web_contact_point_id,
	 c.serv_oe_mobile_contact_point_i mobile_contact_point_id,
	 c.serv_oe_email_contact_point_id email_contact_point_id,
	 c.isdirty__c
      FROM   xxsf_contact c, -- this is a synonym to CONTACT@SOURCE_SF (BI DB)
	 xxsf_account a
      WHERE  isdirty__c = 1 -- SF sign the record when it updated
      AND    c.oe_id__c IS NOT NULL -- If there is a value it is update.
      AND    a.id = c.accountid;
    --and    c.lastmodifieddate > sysdate - 6/24 -- for test
    --and rownum <3
    --;
    --select id
    --from   XXSF_CONTACT c;  --  this is a synonym to CONTACT@SOURCE_SF (BI DB)

    l_err_desc     VARCHAR2(500);
    l_err_code     VARCHAR2(100);
    l_site_rec     xxhz_site_interface%ROWTYPE;
    l_contact_rec  xxhz_contact_interface%ROWTYPE;
    l_acc_rec      xxhz_account_interface%ROWTYPE;
    l_interface_id NUMBER;
    l_exists       VARCHAR2(10);

    my_exc EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- 1) set apps initialize
    set_apps_initialize(p_interface_source => 'SALESFORCE', -- i v
		errbuf             => l_err_desc, -- o v
		retcode            => l_err_code); -- o v

    IF retcode <> 0 THEN
      errbuf  := l_err_desc;
      retcode := 2;
      RAISE my_exc;
    END IF;

    -- 2) enter records to interfaces
    -- ***** No need to use batch id when insert into

    -- Handle account
    -- check account_id is not null + one of the contact point is not null (phone etc)
    /*    fnd_file.put_line(fnd_file.log,'----')
        fnd_file.put_line(fnd_file.log,'Insert records to Account interface')
        dbms_output.put_line('----')
        dbms_output.put_line('Insert records to Account interface')
        for get_acc_r in get_acc_c loop
          l_err_desc := null
          l_err_code := 0
          l_acc_rec.interface_source    := 'SALESFORCE'
          l_acc_rec.interface_status    := 'NEW'
          l_acc_rec.cust_account_id     := get_acc_r.oracle_account_id-- cust_account_id
          l_acc_rec.reference_source_id := get_acc_r.reference_source_id
          l_acc_rec.account_name        := get_acc_r.account_name
          l_acc_rec.account_number      := get_acc_r.account_number
          l_acc_rec.cust_account_id     := get_acc_r.oracle_account_id
          l_acc_rec.attribute4          := get_acc_r.sf_account_id
          l_acc_rec.sales_channel_code  := get_acc_r.sales_channel
          l_acc_rec.industry            := get_acc_r.industry
          l_acc_rec.organization_name_phonetic := get_acc_r.organization_name_phonetic
          l_acc_rec.party_attribute8    := get_acc_r.kam_customer
          l_acc_rec.party_attribute7    := get_acc_r.vip_customer
          l_acc_rec.party_attribute5    := get_acc_r.global_account
          l_acc_rec.party_attribute4    := get_acc_r.ga_program_date
          l_acc_rec.status              := get_acc_r.status
          l_acc_rec.fax                 := get_acc_r.fax
          l_acc_rec.phone               := get_acc_r.phone
          l_acc_rec.url                 := get_acc_r.web_url
          l_acc_rec.org_id              := get_acc_r.operating_unit_id
          l_acc_rec.party_attribute3    := get_acc_r.operating_unit_id

          insert_into_account_int (errbuf         => l_err_desc, -- o v
                                   retcode        => l_err_code, -- o v
                                   p_acc_rec      => l_acc_rec) -- i xxhz_account_interface%rowtype

          if l_err_code <> 0 then
            fnd_file.put_line(fnd_file.log,'Err - '||l_err_desc)
            dbms_output.put_line('Err - '||l_err_desc)
          end if
        end loop
    */

    -- Handle Site
    -- Check account_id is not null, location is not null??
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log, 'Insert records to Site interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Insert records to Site interface');
    FOR get_site_r IN get_site_c LOOP

      BEGIN
        l_interface_id := NULL;
        l_exists       := 'N';

        SELECT s.interface_id,
	   'Y'
        INTO   l_interface_id,
	   l_exists
        FROM   xxhz_site_interface s
        WHERE  s.cust_acct_site_id = get_site_r.oracle_site_id
        AND    s.interface_status = 'NEW'
        AND    s.interface_source = 'SALESFORCE';

      EXCEPTION
        WHEN OTHERS THEN
          l_exists := 'N';
      END;
      IF l_exists = 'Y' THEN
        BEGIN
          DELETE xxhz_site_interface s
          WHERE  s.interface_id = l_interface_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
	NULL;
        END;
      END IF;
      l_err_desc                     := NULL;
      l_err_code                     := 0;
      l_site_rec.interface_source    := 'SALESFORCE';
      l_site_rec.interface_status    := 'NEW';
      l_site_rec.reference_source_id := get_site_r.reference_source_id;
      l_site_rec.cust_account_id     := get_site_r.cust_account_id;
      l_site_rec.primary_flag_bill   := get_site_r.primary_bill_to;
      l_site_rec.primary_flag_ship   := get_site_r.primary_ship_to;
      l_site_rec.site_address        := get_site_r.site_address; --(concat of address1-4)
      -- address1, address2, address3, address4
      l_site_rec.city                := get_site_r.site_city;
      l_site_rec.state               := get_site_r.state;
      l_site_rec.country             := get_site_r.site_country;
      l_site_rec.cust_acct_site_id   := get_site_r.oracle_site_id;
      l_site_rec.postal_code         := get_site_r.site_postal_code;
      l_site_rec.county              := get_site_r.site_county;
      l_site_rec.site_use_code       := get_site_r.site_usage;
      l_site_rec.site_status         := get_site_r.site_status;
      l_site_rec.uses_status         := get_site_r.site_status; -- ???????? not sure it is correct.
      l_site_rec.primary_salesrep_id := get_site_r.primary_salesrep_id;
      l_site_rec.payment_term_id     := get_site_r.payment_term_id;
      l_site_rec.price_list_id       := get_site_r.sf_price_list_id;
      l_site_rec.org_id              := get_site_r.operating_unit_id;
      l_site_rec.location_id         := get_site_r.location_id;
      l_site_rec.party_site_id       := get_site_r.party_site_id;
      l_site_rec.bill_site_use_id    := get_site_r.bill_site_use_id;
      l_site_rec.ship_site_use_id    := get_site_r.ship_site_use_id;
      insert_into_site_int(errbuf     => l_err_desc, -- o v
		   retcode    => l_err_code, -- o v
		   p_site_rec => l_site_rec); -- i xxhz_site_interface%rowtype
      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
        dbms_output.put_line('Err - ' || l_err_desc);
      END IF;

    END LOOP; -- info from BI

    -- Handle Contact
    -- Check site_id + account_id is not null + one of the contact point is not null (phone etc)
    fnd_file.put_line(fnd_file.log, '----');
    fnd_file.put_line(fnd_file.log, 'Insert records to Contact interface');
    dbms_output.put_line('----');
    dbms_output.put_line('Insert records to Contact interface');
    FOR get_contact_r IN get_contact_c LOOP
      BEGIN
        l_interface_id := NULL;
        l_exists       := 'N';

        SELECT s.interface_id,
	   'Y'
        INTO   l_interface_id,
	   l_exists
        FROM   xxhz_contact_interface s
        WHERE  s.cust_account_role_id = get_contact_r.cust_account_role_id
        AND    s.interface_status = 'NEW'
        AND    s.interface_source = 'SALESFORCE';

      EXCEPTION
        WHEN OTHERS THEN
          l_exists := 'N';
      END;
      IF l_exists = 'Y' THEN
        BEGIN
          DELETE xxhz_contact_interface s
          WHERE  s.interface_id = l_interface_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
	NULL;
        END;
      END IF;

      l_err_desc := NULL;
      l_err_code := 0;
      --l_contact_rec
      l_contact_rec.interface_source     := 'SALESFORCE';
      l_contact_rec.interface_status     := 'NEW';
      l_contact_rec.reference_source_id  := get_contact_r.reference_source_id;
      l_contact_rec.cust_account_role_id := get_contact_r.cust_account_role_id;
      l_contact_rec.contact_party_id     := get_contact_r.contact_party_id;
      l_contact_rec.cust_account_id      := get_contact_r.cust_account_id;
      --l_contact_rec.cust_acct_site_id     := get_contact_r.
      l_contact_rec.person_party_id         := get_contact_r.person_party_id;
      l_contact_rec.person_last_name        := get_contact_r.person_last_name;
      l_contact_rec.person_first_name       := get_contact_r.person_first_name;
      l_contact_rec.person_pre_name_adjunct := get_contact_r.person_pre_name_adjunct;
      l_contact_rec.person_status           := get_contact_r.person_status;
      l_contact_rec.org_contact_status      := get_contact_r.org_contact_status;
      l_contact_rec.party_site_id           := get_contact_r.party_site_id;
      l_contact_rec.location_id             := get_contact_r.location_id;
      l_contact_rec.country                 := get_contact_r.country;
      l_contact_rec.address1                := get_contact_r.address1;
      l_contact_rec.city                    := get_contact_r.city;
      l_contact_rec.postal_code             := get_contact_r.postal_code;
      l_contact_rec.state                   := get_contact_r.state;
      --   l_contact_rec.county                  := get_contact_r.county
      l_contact_rec.job_title := get_contact_r.job_title;
      --l_contact_rec.org_contact_status
      l_contact_rec.phone_contact_point_id  := get_contact_r.phone_contact_point_id;
      l_contact_rec.phone                   := get_contact_r.phone;
      l_contact_rec.fax_contact_point_id    := get_contact_r.fax_contact_point_id;
      l_contact_rec.fax                     := get_contact_r.fax;
      l_contact_rec.mobile_contact_point_id := get_contact_r.mobile_contact_point_id;
      l_contact_rec.mobile                  := get_contact_r.mobile;
      l_contact_rec.email_contact_point_id  := get_contact_r.email_contact_point_id;
      l_contact_rec.email_address           := get_contact_r.email_address;
      l_contact_rec.attribute1              := get_contact_r.attribute1; -- gam_contact
      l_contact_rec.attribute2              := get_contact_r.attribute2; -- site_main_contact
      l_contact_rec.attribute3              := get_contact_r.attribute3; -- ww_global_main_contact

      insert_into_contact_int(errbuf        => l_err_desc, -- o v
		      retcode       => l_err_code, -- o v
		      p_contact_rec => l_contact_rec); -- i xxhz_contact_interface%rowtype

      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
        dbms_output.put_line('Err - ' || l_err_desc);
      END IF;
    END LOOP;

  EXCEPTION
    WHEN my_exc THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'main_Sf_Interface - Failed - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END main_sf_interface;

  --------------------------------------------------------------------
  --  name:            Handle_SF_account_relation
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/10/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle create/ update account relationship
  --                   CHG0033449 SF Creating account relationship
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2014  Dalit A. Raviv    initial build
  --  1.1  12/02/2015  Dalit A. Raviv    CHG0034398 - correct account relationship between owner and end-customer
  --------------------------------------------------------------------
  PROCEDURE handle_sf_account_relation(errbuf      OUT VARCHAR2,
			   retcode     OUT VARCHAR2,
			   p_days_back IN NUMBER) IS

    -- Get population
    CURSOR pop_c IS
      SELECT DISTINCT csi.owner_account_id        owner_account_id,
	          csi.account_end_customer_id end_cust_account_id,
	          ou.name
      FROM   xxsf_csi_item_instances     csi,
	 xxsf_account                acc, -- xxsf_test.account acc,
	 xxsf_serv_operating_unit__c ou -- xxsf_test.serv_operating_unit__c ou
      WHERE  csi.owner_account_id != csi.account_end_customer_id
      AND    acc.serv_operating_unit__c = ou.id
      AND    csi.owner_account_id = acc.oe_id__c
      AND    csi.last_update_date >= trunc(SYSDATE) - p_days_back;

    l_user_id            NUMBER;
    l_org_id             NUMBER;
    l_prev_org_id        NUMBER;
    l_count              NUMBER;
    l_ovn                NUMBER;
    l_rel_type           VARCHAR2(30);
    l_created_by_module  VARCHAR2(150);
    l_cust_acc_relate_id NUMBER;
    l_status             VARCHAR2(20);
    l_return_status      VARCHAR2(2000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2000);
    l_data               VARCHAR2(2000);
    l_msg_index_out      NUMBER;
    l_create             VARCHAR2(2);
    l_update             VARCHAR2(2);

    l_cust_acct_relate_rec hz_cust_account_v2pub.cust_acct_relate_rec_type;

  BEGIN
    errbuf     := NULL;
    retcode    := 0;
    l_msg_data := NULL;

    -- Initialization Fields
    SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = 'SCHEDULER';
    -- resp_id 50623 = Implementation
    fnd_global.apps_initialize(user_id      => l_user_id,
		       resp_id      => 50623,
		       resp_appl_id => 660);
    l_prev_org_id := NULL;
    FOR pop_r IN pop_c LOOP
      l_count              := 0;
      l_ovn                := NULL;
      l_rel_type           := NULL;
      l_created_by_module  := NULL;
      l_cust_acc_relate_id := NULL;
      l_status             := NULL;
      l_org_id             := NULL;

      l_create := NULL;
      l_update := NULL;

      l_cust_acct_relate_rec := NULL;
      -- Get organization_id
      BEGIN
        SELECT organization_id
        INTO   l_org_id
        FROM   hr_operating_units
        WHERE  NAME = pop_r.name;

        IF l_org_id <> nvl(l_prev_org_id, -1) THEN
          l_prev_org_id := l_org_id;
          mo_global.set_org_access(p_org_id_char     => l_org_id,
		           p_sp_id_char      => NULL,
		           p_appl_short_name => 'AR');
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_msg_data := 'Invalid operating unit';
          fnd_file.put_line(fnd_file.log, 'ERR - ' || l_msg_data);
      END;

      -- Check Accounts are active -
      -- Both accounts need to be active at oracle in order to create/upd the relation
      -- if one of them is not active do nothing
      SELECT COUNT(1)
      INTO   l_count
      FROM   hz_cust_accounts hca
      WHERE  hca.status = 'A'
      AND    hca.cust_account_id IN
	 (pop_r.owner_account_id, pop_r.end_cust_account_id);

      IF l_count = 2 THEN
        -- the 2 accounts are active
        -- Check if there is an active relationship
        -- IF yes do nothing
        -- if no data found check if there is inactive rel
        -- IF Yes - Update to Active
        -- If No data found - Create new relation
        --begin
        BEGIN
          SELECT t.object_version_number,
	     relationship_type,
	     created_by_module,
	     cust_acct_relate_id,
	     status
          INTO   l_ovn,
	     l_rel_type,
	     l_created_by_module,
	     l_cust_acc_relate_id,
	     l_status
          FROM   ar.hz_cust_acct_relate_all t
          WHERE  cust_account_id = pop_r.end_cust_account_id --pop_r.owner_account_id    Dalit 12/02/2015
          AND    related_cust_account_id = pop_r.owner_account_id --pop_r.end_cust_account_id Dalit 12/02/2015
          AND    ship_to_flag = 'Y'
          AND    t.org_id = l_org_id;

        EXCEPTION
          WHEN no_data_found THEN
	l_create := 'Y';
	l_update := 'N';
          WHEN too_many_rows THEN
	BEGIN
	  SELECT t.object_version_number,
	         relationship_type,
	         created_by_module,
	         cust_acct_relate_id,
	         status
	  INTO   l_ovn,
	         l_rel_type,
	         l_created_by_module,
	         l_cust_acc_relate_id,
	         l_status
	  FROM   ar.hz_cust_acct_relate_all t
	  WHERE  cust_account_id = pop_r.end_cust_account_id --pop_r.owner_account_id    Dalit 12/02/2015
	  AND    related_cust_account_id = pop_r.owner_account_id --pop_r.end_cust_account_id Dalit 12/02/2015
	  AND    ship_to_flag = 'Y'
	  AND    status = 'A'
	  AND    t.org_id = l_org_id
	  AND    rownum = 1;

	  l_create := 'N';
	  l_update := 'N';
	EXCEPTION
	  WHEN no_data_found THEN
	    l_update := 'Y';
	    l_create := 'N';

	  WHEN OTHERS THEN
	    fnd_file.put_line(fnd_file.log,
		          'Gen exception: ' || 'cust account ' ||
		          pop_r.owner_account_id ||
		          ' Related Cust Account ' ||
		          pop_r.end_cust_account_id || ' Err: ' ||
		          substr(SQLERRM, 1, 240));
	    errbuf  := 'Gen Exception';
	    retcode := 2;
	END;
        END;
        --if l_status = 'I' then
        IF nvl(l_update, 'N') = 'Y' THEN
          -- update
          l_cust_acct_relate_rec.cust_account_id         := pop_r.end_cust_account_id; -- Dalit 12/02/2015
          l_cust_acct_relate_rec.related_cust_account_id := pop_r.owner_account_id; -- Dalit 12/02/2015
          l_cust_acct_relate_rec.relationship_type       := l_rel_type;
          l_cust_acct_relate_rec.created_by_module       := l_created_by_module;
          l_cust_acct_relate_rec.cust_acct_relate_id     := l_cust_acc_relate_id;
          l_cust_acct_relate_rec.status                  := 'A';
          hz_cust_account_v2pub.update_cust_acct_relate(p_init_msg_list         => fnd_api.g_true,
				        p_cust_acct_relate_rec  => l_cust_acct_relate_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);

          IF l_return_status = fnd_api.g_ret_sts_success THEN
	COMMIT;
	fnd_file.put_line(fnd_file.log,
		      'S - Update of Customer Relationship: ' ||
		      'Cust account ' || pop_r.owner_account_id ||
		      ' Related Cust Account ' ||
		      pop_r.end_cust_account_id);
          ELSE
	fnd_file.put_line(fnd_file.log,
		      'E - Update Customer Relationship: ' ||
		      'Cust account ' || pop_r.owner_account_id ||
		      ' Related Cust Account ' ||
		      pop_r.end_cust_account_id || ' Err: ' ||
		      l_msg_data);
	ROLLBACK;
	FOR i IN 1 .. l_msg_count LOOP
	  l_msg_data := fnd_msg_pub.get(p_msg_index => i,
			        p_encoded   => 'F');
	  fnd_file.put_line(fnd_file.log, i || ') ' || l_msg_data);
	END LOOP;
          END IF; -- l return
        ELSIF nvl(l_create, 'N') = 'Y' THEN
          -- create
          l_cust_acct_relate_rec.cust_account_id          := pop_r.end_cust_account_id; -- Dalit 12/02/2015
          l_cust_acct_relate_rec.related_cust_account_id  := pop_r.owner_account_id; -- Dalit 12/02/2015
          l_cust_acct_relate_rec.relationship_type        := 'ALL';
          l_cust_acct_relate_rec.created_by_module        := 'ONT_UI_ADD_CUSTOMER';
          l_cust_acct_relate_rec.comments                 := NULL;
          l_cust_acct_relate_rec.bill_to_flag             := 'N';
          l_cust_acct_relate_rec.ship_to_flag             := 'Y';
          l_cust_acct_relate_rec.customer_reciprocal_flag := 'N';

          hz_cust_account_v2pub.create_cust_acct_relate(p_init_msg_list        => 'T',
				        p_cust_acct_relate_rec => l_cust_acct_relate_rec,
				        x_return_status        => l_return_status,
				        x_msg_count            => l_msg_count,
				        x_msg_data             => l_msg_data);

          IF l_return_status <> fnd_api.g_ret_sts_success THEN
	FOR i IN 1 .. l_msg_count LOOP
	  fnd_msg_pub.get(p_msg_index     => i,
		      p_data          => l_data,
		      p_encoded       => fnd_api.g_false,
		      p_msg_index_out => l_msg_index_out);
	  l_msg_data := l_msg_data || l_data;
	END LOOP;

	fnd_file.put_line(fnd_file.log,
		      'E - Create Customer Relationship: ' ||
		      'Cust account ' || pop_r.owner_account_id ||
		      ' Related Cust Account ' ||
		      pop_r.end_cust_account_id || ' Err: ' ||
		      l_msg_data);
	ROLLBACK;
          ELSE
	fnd_file.put_line(fnd_file.log,
		      'S - Create Customer Relationship: ' ||
		      'Cust account ' || pop_r.owner_account_id ||
		      ' Related Cust Account ' ||
		      pop_r.end_cust_account_id);
	COMMIT;
          END IF;
        END IF; -- update/ create
      END IF; -- 2 accounts are active
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_sf_account_relation;

  --------------------------------------------------------------------
  --  name:            handle_sites_uploads
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2015
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update site for FIN usages
  --                   CHG0033183
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sites_uploads(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_table_name    IN VARCHAR2, -- XXHZ_SITE_INTERFACE
		         p_template_name IN VARCHAR2, -- SALESREP_AGENT
		         p_file_name     IN VARCHAR2, -- xxx.csv
		         p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		         p_source        IN VARCHAR2,
		         p_upload        IN VARCHAR2, -- Y/N
		         p_send_mail     IN VARCHAR2) IS

    -- population
    CURSOR c_site_pop IS
      SELECT *
      FROM   xxhz_site_interface s
      WHERE  s.interface_status = 'NEW'
	--and    s.interface_source = 'FIN_CSV'
      AND    batch_id = g_request_id
      --and    s.interface_id = 11 -- this is only for test
      ORDER  BY 1;

    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);

    -- send logs in mail
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_return_status          VARCHAR2(1);
    l_records_exist          VARCHAR2(10) := 'N';

    stop_processing EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- 1) upload data from csv to interface table (XXHZ_SITE_INTERFACE)
    fnd_file.put_line(fnd_file.log,
	          'Upload data from csv file, Directory: ' ||
	          p_directory || ' template: ' || p_template_name ||
	          ' file: ' || p_file_name);
    IF p_upload = 'Y' THEN
      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
			         retcode                => l_retcode,
			         p_table_name           => p_table_name,
			         p_template_name        => p_template_name,
			         p_file_name            => p_file_name,
			         p_directory            => p_directory,
			         p_expected_num_of_rows => NULL);

      IF l_retcode <> '0' THEN
        l_error_message := l_errbuf;
        RAISE stop_processing;
      END IF;
    END IF;
    IF p_send_mail = 'Y' THEN
      --2) Insert report header row
      l_error_message                          := NULL;
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
      l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
      l_xxssys_generic_rpt_rec.col1            := 'Account Name';
      l_xxssys_generic_rpt_rec.col2            := 'Account Number';
      l_xxssys_generic_rpt_rec.col3            := 'Site use code';
      l_xxssys_generic_rpt_rec.col4            := 'Site number';
      l_xxssys_generic_rpt_rec.col5            := 'OU';
      l_xxssys_generic_rpt_rec.col6            := 'Interface Id';
      l_xxssys_generic_rpt_rec.col7            := 'Interface Status';
      l_xxssys_generic_rpt_rec.col_msg         := 'Message';

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				    x_return_status          => l_return_status,
				    x_return_message         => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR RPT PROMPTS' || l_error_message);
        fnd_file.put_line(fnd_file.log,
		  'ERR RPT PROMPTS' || l_error_message);
      END IF;
    END IF;
    -- 3) Call handle sites procedure to process the data entered
    l_errbuf  := NULL;
    l_retcode := 0;
    set_apps_initialize(p_interface_source => p_source, -- i v
		errbuf             => l_errbuf, -- o v
		retcode            => l_retcode); -- o v
    FOR r_site_pop IN c_site_pop LOOP
      l_records_exist := 'Y';
      interface_status(p_status       => 'IN_PROCESS', -- i v
	           p_interface_id => r_site_pop.interface_id, -- i n
	           p_entity       => 'SITE'); -- i v

      l_errbuf  := NULL;
      l_retcode := 0;
      xxhz_interfaces_pkg.handle_sites(errbuf         => l_errbuf, -- o v
			   retcode        => l_retcode, -- o v
			   p_interface_id => r_site_pop.interface_id); -- i n

      IF p_send_mail = 'Y' THEN
        enter_report_data(r_site_pop.interface_id);
      END IF;
    END LOOP;
    -- 4) send report by mail
    IF l_records_exist = 'Y' AND p_send_mail = 'Y' THEN
      -- Submit output report to be emailed out, if records were processed
      l_error_message := NULL;
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
			        p_request_id         => g_request_id,
			        p_l_report_title     => '''' ||
					        'Summary of update customer SalesRep and Agent' || '''',
			        p_l_email_subject    => '''' ||
					        'Summary of update customer SalesRep and Agent' || '''',
			        p_l_file_name        => '''' ||
					        'CustomerUpdate' || '''',
			        p_l_purge_table_flag => 'Y',
			        x_return_status      => l_return_status,
			        x_return_message     => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR Submit report ' || l_error_message);
        fnd_file.put_line(fnd_file.log,
		  'ERR Submit report' || l_error_message);
      END IF;
    END IF; -- send mail report

  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 2;
      errbuf  := 'Unexpected error';

  END handle_sites_uploads;

  --------------------------------------------------------------------
  --  name:            handle_sites_uploads
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   12/04/2015
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update site for FIN usages
  --                   CHG0036474
  --------------------------------------------------------------------
  --  ver  date        name                      desc
  --  1.0  12/04/2015  Diptasurjya Chatterjee    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_account_uploads(errbuf          OUT VARCHAR2,
		           retcode         OUT VARCHAR2,
		           p_table_name    IN VARCHAR2, -- XXHZ_ACCOUNT_INTERFACE
		           p_template_name IN VARCHAR2, -- XXHZ_ACCOUNT
		           p_file_name     IN VARCHAR2, -- xxx.csv
		           p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		           p_source        IN VARCHAR2,
		           p_upload        IN VARCHAR2, -- Y/N
		           p_send_mail     IN VARCHAR2) IS

    -- population
    CURSOR cur_account IS
      SELECT interface_id,
	 account_number,
	 cust_account_id,
   ACCOUNT_NAME
      FROM   xxhz_account_interface s
      WHERE  s.interface_status = 'NEW'
      AND    batch_id = g_request_id
      ORDER  BY 1;

    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);
    --l_acc_rec       customer_rec;
    -- send logs in mail
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_return_status          VARCHAR2(100);
    l_records_exist          VARCHAR2(10) := 'N';
    l_call_prof_flag         VARCHAR2(1) := 'Y';

    l_cust_account_id NUMBER := 0;

    l_too_many_error_exists varchar2(1) := 'N';
    l_api_call_error_exists varchar2(1) := 'N';

    stop_processing EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- 1) upload data from csv to interface table (XXHZ_ACCOUNT_INTERFACE)
    fnd_file.put_line(fnd_file.log,
	          'Upload data from csv file, Directory: ' ||
	          p_directory || ' template: ' || p_template_name ||
	          ' file: ' || p_file_name);
    IF p_upload = 'Y' THEN
      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
			         retcode                => l_retcode,
			         p_table_name           => p_table_name,
			         p_template_name        => p_template_name,
			         p_file_name            => p_file_name,
			         p_directory            => p_directory,
			         p_expected_num_of_rows => NULL);

      IF l_retcode <> '0' THEN
        l_error_message := l_errbuf;
        fnd_file.put_line(fnd_file.output,
		  'Data Loader faced exceptions while loading data from CSV.' ||
		  l_error_message);
        RAISE stop_processing;
      END IF;
    END IF;

    IF p_send_mail = 'Y' THEN
      --2) Insert report header row
      l_error_message                          := NULL;
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
      l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
      l_xxssys_generic_rpt_rec.col1            := 'Account Number';
      l_xxssys_generic_rpt_rec.col2            := 'Account Name';
      l_xxssys_generic_rpt_rec.col3            := 'Interface Id';
      l_xxssys_generic_rpt_rec.col4            := 'Interface Status';
      l_xxssys_generic_rpt_rec.col_msg         := 'Message';

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				    x_return_status          => l_return_status,
				    x_return_message         => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR RPT PROMPTS' || l_error_message);
        fnd_file.put_line(fnd_file.log,
		  'ERR RPT PROMPTS' || l_error_message);
      END IF;
    END IF;

    -- 3) Call handle account procedure to process the data entered
    l_errbuf  := NULL;
    l_retcode := 0;

    set_apps_initialize(p_interface_source => p_source, -- i v
		errbuf             => l_errbuf, -- o v
		retcode            => l_retcode); -- o v

    FOR rec_cur_account IN cur_account LOOP
      l_cust_account_id := 0;
      l_records_exist   := 'Y';
      interface_status(p_status       => 'IN_PROCESS', -- i v
	           p_interface_id => rec_cur_account.interface_id, -- i n
	           p_entity       => 'ACCOUNT'); -- i v

      l_errbuf  := NULL;
      l_retcode := 0;

      IF rec_cur_account.account_number IS NOT NULL AND
         rec_cur_account.cust_account_id IS NULL THEN
        fnd_file.put_line(fnd_file.log, 'Inside Cust Account update: Account Number provided: ' || rec_cur_account.account_number);

        BEGIN
          SELECT cust_account_id
          INTO   l_cust_account_id
          FROM   hz_cust_accounts hca
          WHERE  hca.account_number = rec_cur_account.account_number;
        EXCEPTION
          WHEN no_data_found THEN
	l_cust_account_id := 0;
        END;

        IF l_cust_account_id = 0 THEN
          upd_log(p_err_desc     => 'Customer Account number is incorrect', -- i v
	      p_status       => 'ERROR', -- i v
	      p_interface_id => rec_cur_account.interface_id, -- i n
	      p_entity       => 'ACCOUNT');
          continue;
        ELSE
          UPDATE xxhz_account_interface
          SET    cust_account_id = l_cust_account_id
          WHERE  interface_id = rec_cur_account.interface_id;

          COMMIT;
        END IF;
      ELSIF rec_cur_account.ACCOUNT_NAME is not null and
            rec_cur_account.cust_account_id IS NULL THEN
        fnd_file.put_line(fnd_file.log, 'Inside Cust Account update: Customer Name provided: ' || rec_cur_account.ACCOUNT_NAME);

        BEGIN
          SELECT hca.cust_account_id
          INTO   l_cust_account_id
          FROM   hz_cust_accounts hca,
                 hz_parties hp
          WHERE  hca.party_id = hp.party_id
            AND  hp.party_name = rec_cur_account.ACCOUNT_NAME;
        EXCEPTION
        WHEN too_many_rows then
          upd_log(p_err_desc     => 'Multiple accounts exists for provided customer name. Please provide the account number also', -- i v
                  p_status       => 'ERROR', -- i v
                  p_interface_id => rec_cur_account.interface_id, -- i n
                  p_entity       => 'ACCOUNT');
          l_too_many_error_exists := 'Y';
          continue;
        WHEN no_data_found THEN
	        l_cust_account_id := 0;
        END;

        IF l_cust_account_id = 0 THEN
          upd_log(p_err_desc     => 'Customer Account number is incorrect', -- i v
                  p_status       => 'ERROR', -- i v
                  p_interface_id => rec_cur_account.interface_id, -- i n
                  p_entity       => 'ACCOUNT');
          continue;
        ELSE
          UPDATE xxhz_account_interface
          SET    cust_account_id = l_cust_account_id
          WHERE  interface_id = rec_cur_account.interface_id;

          COMMIT;
        END IF;
      END IF;

      fnd_file.put_line(fnd_file.log, 'After Cust Account update');

      l_errbuf  := NULL;
      l_retcode := 0;

      xxhz_interfaces_pkg.handle_accounts(errbuf         => l_errbuf, -- o v
			      retcode        => l_retcode, -- o v
			      p_interface_id => rec_cur_account.interface_id); -- i n

      if l_retcode in (1,2) then
        l_api_call_error_exists := 'Y';
      end if;
      fnd_file.put_line(fnd_file.log, 'After cust account API call');

      IF p_send_mail = 'Y' THEN
        enter_report_data(rec_cur_account.interface_id, 'ACCOUNT');
      END IF;
    END LOOP;

    /* generate summary report in OUTPUT file */
    fnd_file.put_line(fnd_file.output, '**** Processing Summary ****');
    fnd_file.put_line(fnd_file.output, '----------------------------');
    fnd_file.put_line(fnd_file.output,
	          rpad('Interface ID', 15, ' ') ||
	          rpad('Account Number', 20, ' ') ||
	          rpad('Account Name', 20, ' ') ||
	          rpad('Processing Status', 20, ' ') ||
	          'Processing Message');
    fnd_file.put_line(fnd_file.output,
	          rpad('-', 15, '-') || rpad('-', 20, '-') ||
	          rpad('-', 20, '-') || rpad('-', 20, '-') ||
	          rpad('-', 30, '-'));
    FOR rep_rec IN (SELECT interface_id,
		   account_number,
		   account_name,
		   interface_status,
		   log_message
	        FROM   xxhz_account_interface
	        WHERE  batch_id = g_request_id
	        ORDER  BY 1) LOOP
      fnd_file.put_line(fnd_file.output,
		rpad(rep_rec.interface_id, 15, ' ') ||
		rpad(rep_rec.account_number, 20, ' ') ||
		rpad(nvl(rep_rec.account_name,'-'), 20, ' ') ||
		rpad(rep_rec.interface_status, 20, ' ') ||
		rep_rec.log_message);
    END LOOP;
    /* END - generate summary report in OUTPUT file */

    -- 4) send report by mail
    IF l_records_exist = 'Y' AND p_send_mail = 'Y' THEN
      -- Submit output report to be emailed out, if records were processed
      l_error_message := NULL;
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
			        p_request_id         => g_request_id,
			        p_l_report_title     => '''' ||
					        'Summary of update customer account and party' || '''',
			        p_l_email_subject    => '''' ||
					        'Summary of update customer account and party' || '''',
			        p_l_file_name        => '''' ||
					        'CustomerUpdate' || '''',
			        p_l_purge_table_flag => 'Y',
			        x_return_status      => l_return_status,
			        x_return_message     => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR Submit report ' || l_error_message);
        fnd_file.put_line(fnd_file.log,
		  'ERR Submit report' || l_error_message);
      END IF;
    END IF; -- send mail report

    if l_too_many_error_exists = 'Y' or l_api_call_error_exists = 'Y' then
      retcode := 2;
      errbuf  := 'ERROR';
    else
      retcode := l_retcode;
      errbuf  := l_errbuf;
    end if;
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 2;
      errbuf  := 'Unexpected error';

  END handle_account_uploads;

  --------------------------------------------------------------------
  --  name:               enter_report_data
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      03/03/2015
  --  Description:        Procedure that enter data to tmp table for report use
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   03/03/2015    Dalit A. Raviv  initial build
  --  1.1   12/04/2015    Diptasurjya     CHG0036474 - Added new parameter p_interface_entity
  --                      Chatterjee      to handle different report structure for account
  --------------------------------------------------------------------
  PROCEDURE enter_report_data(p_interface_id     IN NUMBER,
		      p_interface_entity IN VARCHAR2 DEFAULT NULL) IS
    CURSOR c_pop IS
      SELECT *
      FROM   xxhz_site_interface site
      WHERE  site.interface_id = p_interface_id;

    CURSOR c_acct IS
      SELECT *
      FROM   xxhz_account_interface acct
      WHERE  acct.interface_id = p_interface_id;

    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_return_status          VARCHAR2(1);
    l_msg                    VARCHAR2(500);
    l_account_name           VARCHAR2(240);
  BEGIN
    IF p_interface_entity = 'ACCOUNT' THEN
      FOR r_acct IN c_acct LOOP
        IF g_email_address IS NULL THEN
          -- get email address
          BEGIN
	SELECT p.email_address
	INTO   g_email_address
	FROM   fnd_user         fu,
	       per_all_people_f p
	WHERE  fu.employee_id = p.person_id
	AND    SYSDATE BETWEEN p.effective_start_date AND
	       p.effective_end_date
	AND    fu.user_id = r_acct.created_by;
          EXCEPTION
	WHEN OTHERS THEN
	  SELECT p.email_address
	  INTO   g_email_address
	  FROM   fnd_user         fu,
	         per_all_people_f p
	  WHERE  fu.employee_id = p.person_id
	  AND    fu.user_name = 'SYSADMIN';
          END;
        END IF;

        BEGIN
          SELECT hca.account_name
          INTO   l_account_name
          FROM   hz_cust_accounts hca
          WHERE  hca.account_number = r_acct.account_number;
        EXCEPTION
          WHEN OTHERS THEN
	l_account_name := NULL;
        END;

        -- Set output report detail rows
        l_xxssys_generic_rpt_rec.request_id      := g_request_id;
        l_xxssys_generic_rpt_rec.header_row_flag := 'N';
        l_xxssys_generic_rpt_rec.email_to        := g_email_address;
        l_xxssys_generic_rpt_rec.col1            := r_acct.account_number;
        l_xxssys_generic_rpt_rec.col2            := l_account_name;
        l_xxssys_generic_rpt_rec.col3            := r_acct.interface_id;
        l_xxssys_generic_rpt_rec.col4            := r_acct.interface_status;
        l_xxssys_generic_rpt_rec.col_msg         := r_acct.log_message;

        --
        xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				      x_return_status          => l_return_status,
				      x_return_message         => l_msg);

        IF l_return_status <> 'S' THEN
          dbms_output.put_line('ERR RPT ' || l_msg);
        END IF;
      END LOOP;
    ELSE
      FOR r_pop IN c_pop LOOP
        IF g_email_address IS NULL THEN
          -- get email address
          BEGIN
	SELECT p.email_address
	INTO   g_email_address
	FROM   fnd_user         fu,
	       per_all_people_f p
	WHERE  fu.employee_id = p.person_id
	AND    SYSDATE BETWEEN p.effective_start_date AND
	       p.effective_end_date
	AND    fu.user_id = r_pop.created_by;
          EXCEPTION
	WHEN OTHERS THEN
	  SELECT p.email_address
	  INTO   g_email_address
	  FROM   fnd_user         fu,
	         per_all_people_f p
	  WHERE  fu.employee_id = p.person_id
	  AND    fu.user_name = 'SYSADMIN';
          END;
        END IF;

        BEGIN
          SELECT hca.account_name
          INTO   l_account_name
          FROM   hz_cust_accounts hca
          WHERE  hca.account_number = r_pop.account_number;
        EXCEPTION
          WHEN OTHERS THEN
	l_account_name := NULL;
        END;

        -- Set output report detail rows
        l_xxssys_generic_rpt_rec.request_id      := g_request_id;
        l_xxssys_generic_rpt_rec.header_row_flag := 'N';
        l_xxssys_generic_rpt_rec.email_to        := g_email_address;
        l_xxssys_generic_rpt_rec.col1            := l_account_name;
        l_xxssys_generic_rpt_rec.col2            := r_pop.account_number;
        l_xxssys_generic_rpt_rec.col3            := r_pop.site_use_code;
        l_xxssys_generic_rpt_rec.col4            := r_pop.party_site_number; --
        l_xxssys_generic_rpt_rec.col5            := r_pop.org_name;
        l_xxssys_generic_rpt_rec.col6            := r_pop.interface_id;
        l_xxssys_generic_rpt_rec.col7            := r_pop.interface_status;
        l_xxssys_generic_rpt_rec.col_msg         := r_pop.log_message;

        --
        xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				      x_return_status          => l_return_status,
				      x_return_message         => l_msg);

        IF l_return_status <> 'S' THEN
          dbms_output.put_line('ERR RPT ' || l_msg);
        END IF;
      END LOOP;
    END IF;

  END enter_report_data;

  --------------------------------------------------------------------
  --  name:            set_Inactivate_Sites
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035283 Inactivate Customer Sites via existing API
  --                   Procedure that update site to inactive
  --                   will cal from concurrent program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/05/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_inactivate_sites(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_table_name    IN VARCHAR2, -- XXHZ_SITE_INTERFACE
		         p_template_name IN VARCHAR2, -- SITE_INACTIVE
		         p_file_name     IN VARCHAR2, -- xxx.csv
		         p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		         p_upload        IN VARCHAR2 -- Y/N
		         ) IS

    -- population
    CURSOR c_site_pop(p_request_id IN NUMBER) IS
      SELECT *
      FROM   xxhz_site_interface s
      WHERE  s.interface_status = 'NEW'
      AND    batch_id = p_request_id --l_request_id
      --and    s.interface_id = 11 -- this is only for test
      ORDER  BY 1;

    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);
    l_request_id    NUMBER;
    l_site_rec      xxhz_site_interface%ROWTYPE;
    l_org_id        NUMBER;
    l_party_name    VARCHAR2(360);
    l_count         NUMBER := 0;
    l_flag          VARCHAR2(10) := 'N';
    l_count_all     NUMBER := 0;
    l_count_e       NUMBER := 0;
    l_counts        NUMBER := 0;

    stop_processing EXCEPTION;
  BEGIN
    -- 1) upload data from csv to interface table (XXHZ_SITE_INTERFACE)
    fnd_file.put_line(fnd_file.output,
	          'Upload data from csv file, Directory: ' ||
	          p_directory || ' template: ' || p_template_name ||
	          ' file: ' || p_file_name);
    IF p_upload = 'Y' THEN
      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
			         retcode                => l_retcode,
			         p_table_name           => p_table_name,
			         p_template_name        => p_template_name,
			         p_file_name            => p_file_name,
			         p_directory            => p_directory,
			         p_expected_num_of_rows => NULL);

      IF l_retcode <> '0' THEN
        l_error_message := l_errbuf;
        RAISE stop_processing;
      END IF;
    END IF;

    l_request_id := fnd_global.conc_request_id;

    -- 3) Call handle sites procedure to process the data entered
    l_errbuf  := NULL;
    l_retcode := 0;

    fnd_global.apps_initialize(user_id      => fnd_global.user_id,
		       resp_id      => fnd_global.resp_id,
		       resp_appl_id => fnd_global.resp_appl_id);

    print_out(rpad('----------------------------  ', 30) || '|' ||
	  rpad('--------------------------------------  ', 40));
    print_out(rpad('Cust account site id', 30) || '|' ||
	  rpad('Message', 40));
    print_out(rpad('----------------------------  ', 30) || '|' ||
	  rpad('--------------------------------------  ', 40));

    FOR r_site_pop IN c_site_pop(l_request_id) LOOP
      l_site_rec := r_site_pop;
      --fnd_file.put_line(fnd_file.output, '-----------------------');
      --fnd_file.put_line(fnd_file.output, 'Cust account site id - ' ||
      --                   l_site_rec.cust_acct_site_id);

      l_count_all := l_count_all + 1;
      l_count     := 0;
      l_flag      := 'N';

      -- Check Site is not inactive allready
      SELECT COUNT(1)
      INTO   l_count
      FROM   hz_cust_acct_sites_all s
      WHERE  s.cust_acct_site_id = l_site_rec.cust_acct_site_id
      AND    s.status = 'I';
      IF l_count > 0 THEN
        -- ERR - Site is already inactive
        fnd_message.set_name('XXOBJT', 'XXAR_INACTIVESITES_INACTIVE');
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      fnd_message.get);
        --fnd_file.put_line(fnd_file.output, fnd_message.get);
        l_flag  := 'Y';
        retcode := 1;
      END IF;

      l_count := 0;
      -- Check Open AR exist
      SELECT COUNT(1)
      INTO   l_count
      FROM   hz_cust_site_uses_all    hu,
	 ra_customer_trx_all      rt,
	 ar_payment_schedules_all aps
      WHERE  hu.cust_acct_site_id = l_site_rec.cust_acct_site_id --267586--315711
      AND    hu.site_use_code = 'BILL_TO'
      AND    hu.status = 'A'
      AND    rt.bill_to_site_use_id = hu.site_use_id
      AND    aps.customer_trx_id = rt.customer_trx_id
      AND    aps.amount_due_remaining <> 0;
      IF l_count > 0 THEN
        -- 'ERR - Site has open AR Balance'
        fnd_message.set_name('XXOBJT', 'XXAR_INACTIVESITES_AR');
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      fnd_message.get);
        --fnd_file.put_line(fnd_file.output, fnd_message.get)
        l_flag  := 'Y';
        retcode := 1;
      END IF;

      l_count := 0;
      -- Check Open SO exists
      SELECT COUNT(1)
      INTO   l_count
      FROM   hz_cust_site_uses_all hu,
	 oe_order_headers_all  oh,
	 oe_order_lines_all    ol
      WHERE  hu.cust_acct_site_id = l_site_rec.cust_acct_site_id --267586--315711
      AND    hu.site_use_code = 'BILL_TO'
      AND    hu.status = 'A'
      AND    oh.invoice_to_org_id = hu.site_use_id
      AND    ol.header_id = oh.header_id
	--AND    ol.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
      AND    ol.flow_status_code IN
	 (SELECT fv.flex_value
	   FROM   fnd_flex_values_vl  fv,
	          fnd_flex_value_sets fvs
	   WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
	   AND    fvs.flex_value_set_name =
	          'XXAR_INACTIVE_SITES_EXCLUDE_CODES'
	   AND    fv.enabled_flag = 'Y'
	   AND    trunc(SYSDATE) BETWEEN
	          nvl(fv.start_date_active, SYSDATE - 1) AND
	          nvl(fv.end_date_active, SYSDATE + 1));

      IF l_count > 0 THEN
        -- ERR - Site has open SO Bill
        fnd_message.set_name('XXOBJT', 'XXAR_INACTIVESITES_SO_BILL');
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      fnd_message.get);
        --fnd_file.put_line(fnd_file.output, fnd_message.get)
        l_flag  := 'Y';
        retcode := 1;
      END IF;

      l_count := 0;
      SELECT COUNT(1)
      INTO   l_count
      FROM   hz_cust_site_uses_all hu,
	 oe_order_headers_all  oh,
	 oe_order_lines_all    ol
      WHERE  hu.cust_acct_site_id = l_site_rec.cust_acct_site_id --267586--315711
      AND    hu.site_use_code = 'SHIP_TO'
      AND    hu.status = 'A'
      AND    oh.ship_to_org_id = hu.site_use_id
      AND    ol.header_id = oh.header_id
	--AND    ol.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
      AND    ol.flow_status_code IN
	 (SELECT fv.flex_value
	   FROM   fnd_flex_values_vl  fv,
	          fnd_flex_value_sets fvs
	   WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
	   AND    fvs.flex_value_set_name =
	          'XXAR_INACTIVE_SITES_EXCLUDE_CODES'
	   AND    fv.enabled_flag = 'Y'
	   AND    trunc(SYSDATE) BETWEEN
	          nvl(fv.start_date_active, SYSDATE - 1) AND
	          nvl(fv.end_date_active, SYSDATE + 1));

      IF l_count > 0 THEN
        -- ERR - Site has open SO Ship
        fnd_message.set_name('XXOBJT', 'XXAR_INACTIVESITES_SO_SHIP');
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      fnd_message.get);
        --fnd_file.put_line(fnd_file.output, fnd_message.get)
        l_flag  := 'Y';
        retcode := 1;
      END IF;
      -- do not call the API if did not pass validation
      IF l_flag = 'Y' THEN
        l_count_e := l_count_e + 1;

        UPDATE xxhz_site_interface a
        SET    a.interface_status = 'ERROR',
	   a.log_message      = 'Site is Inactive or have Open AR balance or have open SO',
	   a.last_update_date = SYSDATE
        WHERE  a.interface_id = r_site_pop.interface_id;
        COMMIT;
        continue;
      END IF;

      xxhz_interfaces_pkg.update_cust_account_site_api(errbuf       => l_errbuf, -- o v
				       retcode      => l_retcode, -- o v
				       p_org_id     => l_org_id, -- o n
				       p_party_name => l_party_name, -- o v
				       p_entity     => 'Inactive Site', -- i v
				       p_site_rec   => l_site_rec); -- i xxhz_site_interface%ROWTYPE

      IF nvl(l_retcode, 0) <> 0 THEN
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      'API ERR - ' || l_errbuf);
        --fnd_file.put_line(fnd_file.output, 'ERR - ' || l_errbuf)
        errbuf    := 'Some Sites did not update to Inactive';
        retcode   := 1;
        l_count_e := l_count_e + 1;

        ROLLBACK;
        UPDATE xxhz_site_interface a
        SET    a.interface_status = 'ERROR',
	   a.log_message      = l_errbuf,
	   a.last_update_date = SYSDATE
        WHERE  a.interface_id = r_site_pop.interface_id;
        COMMIT;
      ELSE
        print_out(rpad(l_site_rec.cust_acct_site_id, 30) || '|' ||
	      'Success ' || l_errbuf);
        --fnd_file.put_line(fnd_file.output, 'Success ' || l_errbuf)
        l_counts := l_counts + 1;
        UPDATE xxhz_site_interface a
        SET    a.interface_status = 'SUCCESS',
	   a.last_update_date = SYSDATE
        WHERE  a.interface_id = r_site_pop.interface_id;
        COMMIT;
      END IF;
    END LOOP;

    print_out('--------------------------------------');
    print_out('Process  ' || l_count_all || ' records');
    print_out('Success  ' || l_counts || ' records');
    print_out('Failures ' || l_count_e || ' records');
    print_out('--------------------------------------');

  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.output, l_error_message);
      print_out(l_error_message);
      retcode := 2;
      errbuf  := 'Unexpected error';
  END set_inactivate_sites;

  --------------------------------------------------------------------
  --  name:            print_out
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035283
  --                   Print message to output
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0035283
  --------------------------------------------------------------------
  PROCEDURE print_out(p_print_msg VARCHAR2) IS
  BEGIN
    fnd_file.put_line(fnd_file.output, p_print_msg);
  END print_out;
  ---------------------------------------------------
  PROCEDURE insert_test_records IS

  BEGIN
    INSERT INTO xxhz_account_interface t
      (t.interface_id,
       t.batch_id,
       t.interface_source,
       t.interface_status,
       t.account_name,
       t.account_number,
       t.sales_channel_code,
       t.category_code,
       t.status,
       t.industry,
       t.party_attribute3,
       t.phone_area_code,
       t.phone_number,
       t.phone_extension,
       t.phone_status,
       t.phone_primary_flag,
       t.email_address)
    VALUES
      (2,
       2,
       'SALESFORCE',
       'NEW',
       'Dalit test 03-4',
       '987654456789',
       'DIRECT',
       'CUSTOMER',
       'A',
       'EDUCATION',
       81,
       '08',
       '987456321',
       '123456',
       'A',
       'Y',
       'kjhgfdsertyyu');

    INSERT INTO xxhz_site_interface t
      (t.interface_id,
       t.batch_id,
       t.parent_interface_id,
       interface_source,
       interface_status,
       site_use_code,
       primary_flag_bill,
       primary_flag_ship,
       site_status,
       uses_status,
       address1,
       address2,
       address3,
       address4,
       state,
       postal_code,
       county,
       country,
       city,
       org_id)
    VALUES
      (2,
       2,
       2,
       'SALESFORCE',
       'NEW',
       'Bill To/Ship To',
       'Y',
       'Y',
       'A',
       'A',
       'Hess',
       '7',
       NULL,
       NULL,
       NULL,
       '76346',
       NULL,
       'ISRAEL',
       'Rehovot',
       81);

    INSERT INTO xxhz_contact_interface t
      (interface_id,
       batch_id,
       parent_interface_id,
       interface_source,
       interface_status,
       person_last_name,
       person_first_name,
       person_status,
       country,
       address1,
       city,
       postal_code,
       org_contact_status,
       phone_area_code,
       phone_number,
       phone_extension,
       phone_status,
       phone_primary_flag,
       fax_area_code,
       fax_number,
       fax_status,
       fax_primary_flag,
       web_url,
       web_status,
       web_primary_flag,
       email_address,
       email_status,
       email_primary_flag)
    VALUES
      (2,
       2,
       2,
       'SALESFORCE',
       'NEW',
       'Raviv',
       'Dalit',
       'A',
       'ISRAEL',
       'vvvvvvv',
       'Rehovot',
       '76346',
       'A',
       '08',
       '123456789',
       '123',
       'A',
       'Y',
       '08',
       '987987987',
       'A',
       'Y',
       'www.ynet.com',
       'A',
       'Y',
       'vvvvv@gmail.com',
       'A',
       'Y');

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(' Err - ' || substr(SQLERRM, 1, 240));
  END insert_test_records;

----------------------------------------------------------------------
-- interface_source should come from this list
--SELECT lookup_code, v.meaning, v.description, v.attribute1
--FROM   fnd_lookup_values v
--where  v.lookup_type     = 'HZ_CREATED_BY_MODULES'
--and    v.language        = 'US'
-----------------------------------------------------------------------
--------------------------------------------------------------------
  --  name:            handle_contact_uploads
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   22/10/2018
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update Contact
  --                   CHG0043940
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/10/2018  Ofer Suad         CHG0043940 Add fileds to Customer update
--------------------------------------------------------------------
PROCEDURE handle_contact_uploads(errbuf          OUT VARCHAR2,
             retcode         OUT VARCHAR2,
             p_table_name    IN VARCHAR2, -- XXHZ_CONTACT_INTERFACE
             p_template_name IN VARCHAR2, --
             p_file_name     IN VARCHAR2, -- xxx.csv
             p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
             p_source        IN VARCHAR2,
             p_upload        IN VARCHAR2, -- Y/N
             p_send_mail     IN VARCHAR2) IS

    -- population
    CURSOR c_contact_pop IS
      SELECT *
      FROM   XXHZ_CONTACT_INTERFACE s
      WHERE  s.interface_status = 'NEW'
      AND    batch_id = g_request_id
         ORDER  BY 1;

    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);

    -- send logs in mail
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_return_status          VARCHAR2(1);
    l_records_exist          VARCHAR2(10) := 'N';

    stop_processing EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- 1) upload data from csv to interface table (XXHZ_SITE_INTERFACE)
    fnd_file.put_line(fnd_file.log,
            'Upload data from csv file, Directory: ' ||
            p_directory || ' template: ' || p_template_name ||
            ' file: ' || p_file_name);
    IF p_upload = 'Y' THEN
      xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
               retcode                => l_retcode,
               p_table_name           => p_table_name,
               p_template_name        => p_template_name,
               p_file_name            => p_file_name,
               p_directory            => p_directory,
               p_expected_num_of_rows => NULL);

      IF l_retcode <> '0' THEN
        l_error_message := l_errbuf;
        RAISE stop_processing;
      END IF;
    END IF;
    IF p_send_mail = 'Y' THEN
      --2) Insert report header row
      l_error_message                          := NULL;
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
      l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
      l_xxssys_generic_rpt_rec.col1            := 'Account Name';
      l_xxssys_generic_rpt_rec.col2            := 'Account Number';
      l_xxssys_generic_rpt_rec.col3            := 'Site use code';
      l_xxssys_generic_rpt_rec.col4            := 'Site number';
      l_xxssys_generic_rpt_rec.col5            := 'OU';
      l_xxssys_generic_rpt_rec.col6            := 'Interface Id';
      l_xxssys_generic_rpt_rec.col7            := 'Interface Status';
      l_xxssys_generic_rpt_rec.col_msg         := 'Message';

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
            x_return_status          => l_return_status,
            x_return_message         => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR RPT PROMPTS' || l_error_message);
        fnd_file.put_line(fnd_file.log,
      'ERR RPT PROMPTS' || l_error_message);
      END IF;
    END IF;
    -- 3) Call handle sites procedure to process the data entered
    l_errbuf  := NULL;
    l_retcode := 0;
    set_apps_initialize(p_interface_source => p_source, -- i v
    errbuf             => l_errbuf, -- o v
    retcode            => l_retcode); -- o v
    FOR r_contact_pop IN c_contact_pop LOOP
      l_records_exist := 'Y';
      interface_status(p_status       => 'IN_PROCESS', -- i v
             p_interface_id => r_contact_pop.interface_id, -- i n
             p_entity       => 'Contact'); -- i v

      l_errbuf  := NULL;
      l_retcode := 0;
      xxhz_interfaces_pkg.handle_contacts(errbuf         => l_errbuf, -- o v
         retcode        => l_retcode, -- o v
         p_interface_id => r_contact_pop.interface_id); -- i n

      IF p_send_mail = 'Y' THEN
        enter_report_data(r_contact_pop.interface_id);
      END IF;
    END LOOP;
    -- 4) send report by mail
    IF l_records_exist = 'Y' AND p_send_mail = 'Y' THEN
      -- Submit output report to be emailed out, if records were processed
      l_error_message := NULL;
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
              p_request_id         => g_request_id,
              p_l_report_title     => '''' ||
                  'Summary of update Customer Contact' || '''',
              p_l_email_subject    => '''' ||
                  'Summary of update Customer Contact' || '''',
              p_l_file_name        => '''' ||
                  'ContactUpdate' || '''',
              p_l_purge_table_flag => 'Y',
              x_return_status      => l_return_status,
              x_return_message     => l_error_message);

      IF l_return_status <> 'S' THEN
        dbms_output.put_line('ERR Submit report ' || l_error_message);
        fnd_file.put_line(fnd_file.log,
      'ERR Submit report' || l_error_message);
      END IF;
    END IF; -- send mail report

  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 2;
      errbuf  := 'Unexpected error';

  END handle_contact_uploads;

END xxhz_interfaces_pkg;
/