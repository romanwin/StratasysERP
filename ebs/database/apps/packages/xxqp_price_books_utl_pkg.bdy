CREATE OR REPLACE PACKAGE BODY xxqp_price_books_utl_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0033893 - Price Books Automation
  --  name:               xxqp_price_books_utl_pkg
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15/03/2015
  --  Description:        Price book utilities for setup form and excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --  1.1   23/07/2015    Michal Tzvik    CHG0035863 -  CURSOR c_product_hierarchy: change logic for product_type_l1,product_type_l2, product_type_l3
  --  1.2   12/05/2017    Diptasurjya     CHG0040353 - Apply changes on PB generation based on new PL update setup logic.
  --                                      Currently all the items which are assigned to PB category must have a price.
  --                                      The new requirement is to have the ability to exclude items in a price book or in a price book column
  --------------------------------------------------------------------
  c_master_organization CONSTANT NUMBER := 91;
  c_sysdate             CONSTANT DATE := SYSDATE;

  report_error EXCEPTION;

  -- Price book full hierarchy
  CURSOR c_product_hierarchy(p_inventory_item_id NUMBER) IS
    SELECT nvl(ffvv1.description, ffvv1.flex_value) product_type_l1, --  1.1   Michal Tzvik    CHG0035863
           nvl(ffvv2.description, ffvv2.flex_value) product_type_l2, --  1.1   Michal Tzvik    CHG0035863
           nvl(ffvv3.description, ffvv3.flex_value) product_type_l3, --  1.1   Michal Tzvik    CHG0035863
           /*ffvnh2.parent_flex_value product_type_l1,
           ffvnh3.parent_flex_value product_type_l2,
           ffvv3.flex_value product_type_l3,*/
           ffvd1.html_comment description_l1,
           ffvd1.image_file_name image_l1,
           xxobjt_fnd_attachments.get_short_text_attached(p_function_name => 'FND_FNDFFMSV',
				          p_entity_name   => 'FND_FLEX_VALUES',
				          p_category_name => NULL,
				          p_entity_id1    => ffvs.flex_value_set_id,
				          p_entity_id2    => ffvv1.flex_value_id) long_desc_l1,
           ffvd2.html_comment description_l2,
           ffvd2.image_file_name image_l2,
           xxobjt_fnd_attachments.get_short_text_attached(p_function_name => 'FND_FNDFFMSV',
				          p_entity_name   => 'FND_FLEX_VALUES',
				          p_category_name => NULL,
				          p_entity_id1    => ffvs.flex_value_set_id,
				          p_entity_id2    => ffvv2.flex_value_id) long_desc_l2,
           ffvd3.html_comment description_l3,
           ffvd3.image_file_name image_l3,
           ffvv1.flex_value,
           ffvv1.attribute1,
           ffvv1.attribute2
    FROM   fnd_flex_value_sets           ffvs,
           fnd_flex_values_vl            ffvv1,
           fnd_flex_values_dfv           ffvd1,
           fnd_flex_values_vl            ffvv2,
           fnd_flex_value_norm_hierarchy ffvnh2,
           fnd_flex_values_dfv           ffvd2,
           fnd_flex_values_vl            ffvv3,
           fnd_flex_value_norm_hierarchy ffvnh3,
           fnd_flex_values_dfv           ffvd3,
           mtl_item_categories           mic,
           mtl_category_sets_tl          mcsb,
           mtl_categories_b              mcb
    WHERE  ffvs.flex_value_set_name = 'XXCS_PB_PRODUCT_FAMILY'
    AND    ffvv3.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvd3.row_id(+) = ffvv3.row_id
    AND    ffvv2.flex_value(+) = ffvnh3.parent_flex_value
    AND    ffvv2.flex_value_set_id(+) = ffvnh3.flex_value_set_id
    AND    ffvnh2.flex_value_set_id(+) = ffvv2.flex_value_set_id
    AND    ffvv2.flex_value BETWEEN ffvnh2.child_flex_value_low(+) AND
           ffvnh2.child_flex_value_high(+)
    AND    ffvd2.row_id(+) = ffvv2.row_id
    AND    ffvnh3.flex_value_set_id(+) = ffvv3.flex_value_set_id
    AND    ffvv3.flex_value BETWEEN ffvnh3.child_flex_value_low(+) AND
           ffvnh3.child_flex_value_high(+)
    AND    ffvv1.flex_value_set_id(+) = ffvnh2.flex_value_set_id
    AND    ffvv1.flex_value(+) = ffvnh2.parent_flex_value
    AND    ffvd1.row_id(+) = ffvv1.row_id
    AND    ffvv3.flex_value = mcb.segment1
    AND    mic.organization_id = c_master_organization
    AND    mic.category_set_id = mcsb.category_set_id
    AND    mcsb.category_set_name = 'CS Price Book Product Type'
    AND    mcsb.language = 'US'
    AND    mcb.category_id = mic.category_id
    AND    mic.inventory_item_id = p_inventory_item_id;

  --------------------------------------------------------------------
  --  name:               log_message
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        Print message to log file or dbms_output
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE log_message(p_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_msg);
    END IF;

  END log_message;

  --------------------------------------------------------------------
  --  name:               get_price_list_name
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get price list name of given p_price_list_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_price_list_name(p_price_list_id NUMBER) RETURN VARCHAR2 IS
    l_pl_name qp_list_headers_all.name%TYPE;
  BEGIN

    SELECT qlh.name
    INTO   l_pl_name
    FROM   qp_list_headers_all qlh
    WHERE  qlh.list_type_code = 'PRL'
    AND    qlh.list_header_id = p_price_list_id;

    RETURN l_pl_name;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_price_list_name;

  --------------------------------------------------------------------
  --  name:               get_price_list_id
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get price_list_id of given p_price_list_name
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_price_list_id(p_price_list_name NUMBER) RETURN VARCHAR2 IS
    l_pl_name qp_list_headers_all.name%TYPE;
  BEGIN

    SELECT qlh.list_header_id
    INTO   l_pl_name
    FROM   qp_list_headers_all qlh
    WHERE  qlh.list_type_code = 'PRL'
    AND    qlh.name = p_price_list_name;

    RETURN l_pl_name;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_price_list_id;

  --------------------------------------------------------------------
  --  name:               get_price_book_name
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get price book name of given p_price_book_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_price_book_name(p_price_book_id NUMBER) RETURN VARCHAR2 IS
    l_name VARCHAR2(30);
  BEGIN

    SELECT xpb.name
    INTO   l_name
    FROM   xxqp_price_books xpb
    WHERE  xpb.price_book_id = p_price_book_id;

    RETURN l_name;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_price_book_name;

  --------------------------------------------------------------------
  --  name:               get_ver_status_name
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get pb version status name of given p_status_code
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_ver_status_name(p_status_code VARCHAR2) RETURN VARCHAR2 IS
    l_status fnd_flex_values_vl.description%TYPE;
  BEGIN

    SELECT ffvv.description
    INTO   l_status
    FROM   fnd_flex_values_vl  ffvv,
           fnd_flex_value_sets ffvs
    WHERE  ffvv.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvs.flex_value_set_name = 'XXQP_PRICE_BOOK_VERSION_STATUS'
    AND    ffvv.flex_value = p_status_code
    AND    ffvv.enabled_flag = 'Y';

    RETURN l_status;

  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        SELECT ffvv.description
        INTO   l_status
        FROM   fnd_flex_values_vl  ffvv,
	   fnd_flex_value_sets ffvs
        WHERE  ffvv.flex_value_set_id = ffvs.flex_value_set_id
        AND    ffvs.flex_value_set_name = 'XXQP_PRICE_BOOK_VERSION_STATUS'
        AND    ffvv.flex_value = p_status_code;

        RETURN l_status;

      EXCEPTION
        WHEN no_data_found THEN
          RETURN NULL;
      END;
  END get_ver_status_name;

  --------------------------------------------------------------------
  --  name:               get_current_version_status
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get status code of current (latest) pb version
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_current_version_status(p_price_book_id NUMBER) RETURN VARCHAR2 IS

    l_rslt VARCHAR2(30);
  BEGIN
    SELECT status_code
    INTO   l_rslt
    FROM   (SELECT xpbv.status_code
	FROM   xxqp_price_books_versions xpbv
	WHERE  xpbv.price_book_id = p_price_book_id
	ORDER  BY xpbv.version_num DESC)
    WHERE  rownum = 1;

    RETURN l_rslt;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_current_version_status;

  --------------------------------------------------------------------
  --  name:               get_version_status
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get status code of given pb version
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_version_status(p_price_book_version_id NUMBER) RETURN VARCHAR2 IS
    l_status xxqp_price_books_versions.status_code%TYPE;
  BEGIN
    SELECT xpbv.status_code
    INTO   l_status
    FROM   xxqp_price_books_versions xpbv
    WHERE  xpbv.price_book_version_id = p_price_book_version_id;

    RETURN l_status;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_version_status;

  --------------------------------------------------------------------
  --  name:               get_factor_category_desc
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get description of category
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_factor_category_desc(p_category_name VARCHAR2) RETURN VARCHAR2 IS
    l_category_desc fnd_flex_values_vl.description%TYPE;
  BEGIN
    SELECT t.description
    INTO   l_category_desc
    FROM   fnd_flex_values_vl  t,
           fnd_flex_value_sets vs
    WHERE  t.flex_value_set_id = vs.flex_value_set_id
    AND    vs.flex_value_set_name = 'XXOM_PL_UPD_CATEGORY'
    AND    t.enabled_flag = 'Y'
    AND    t.attribute1 = 'CS'
    AND    t.flex_value = p_category_name;

    RETURN l_category_desc;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_factor_category_desc;
  ----------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               get_simulation_price
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get price from pl simulation
  --  Parameters:         p_price_book_version_id
  --                      p_price_reference - there are 3 pl fields for pb version.
  --                                          this parameter indicates which of them to refer.
  --                      p_inventory_item_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_simulation_price(p_price_book_version_id NUMBER,
		        p_price_reference       NUMBER,
		        p_inventory_item_id     NUMBER) RETURN NUMBER IS

    l_price NUMBER;
  BEGIN
    log_message('get_simulation_price: p_price_book_version_id = ' ||
	    p_price_book_version_id || ' p_price_reference: ' ||
	    p_price_reference || ' p_inventory_item_id: ' ||
	    p_inventory_item_id);
    SELECT new_price
    INTO   l_price
    FROM   (SELECT first_value(xpus.new_price) over(PARTITION BY inventory_item_id ORDER BY xpus.creation_date DESC) new_price
	FROM   xxom_pl_upd_simulation    xpus,
	       xxqp_price_books_versions xpbv,
         xxom_pl_upd_rule_header   xph
	WHERE  xpbv.price_book_version_id = p_price_book_version_id
	AND    xpus.list_header_id =
	       decode(p_price_reference,
		   1,
		   xpbv.price_list_id_1,
		   2,
		   xpbv.price_list_id_2,
		   3,
		   xpbv.price_list_id_3)
	       AND    nvl(xpus.save_ind, 'N') = 'N'
         AND xpus.rule_id = xph.rule_id
         AND xph.source_code <> 'MRKT'
	AND    xpus.inventory_item_id = p_inventory_item_id)
    WHERE  rownum = 1;

    RETURN l_price;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_simulation_price;

  ----------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               get_simulation_exclusion
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  customization code: CHG0040353 - Price Books Adjustment to handle PL Update customization
  --  creation date:      28/04/2017
  --  Description:        get exclude flag from pl simulation
  --  Parameters:         p_price_book_version_id
  --                      p_price_reference - there are 3 pl fields for pb version.
  --                                          this parameter indicates which of them to refer.
  --                      p_inventory_item_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2017    Diptasurjya     initial build
  --------------------------------------------------------------------
  FUNCTION get_simulation_exclusion(p_price_book_version_id NUMBER,
		        p_price_reference       NUMBER,
		        p_inventory_item_id     NUMBER) RETURN VARCHAR2 IS

    l_exclude varchar2(1);
  BEGIN
    log_message('get_simulation_exclusion: p_price_book_version_id = ' ||
	    p_price_book_version_id || ' p_price_reference: ' ||
	    p_price_reference || ' p_inventory_item_id: ' ||
	    p_inventory_item_id);
      
    SELECT exclude_flag
    INTO   l_exclude
    FROM   (SELECT first_value(nvl(xpus.excluded_flag,'N')) over(PARTITION BY inventory_item_id ORDER BY xpus.creation_date DESC) exclude_flag
	FROM   xxom_pl_upd_simulation    xpus,
	       xxqp_price_books_versions xpbv,
         xxom_pl_upd_rule_header   xph
	WHERE  xpbv.price_book_version_id = p_price_book_version_id
	AND    xpus.list_header_id =
	       decode(p_price_reference,
		   1,
		   xpbv.price_list_id_1,
		   2,
		   xpbv.price_list_id_2,
		   3,
		   xpbv.price_list_id_3)
	       AND    nvl(xpus.save_ind, 'N') = 'N'
         AND xpus.rule_id = xph.rule_id
         AND xph.source_code <> 'MRKT'
	AND    xpus.inventory_item_id = p_inventory_item_id)
    WHERE  rownum = 1;

    RETURN l_exclude;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_simulation_exclusion;

  --------------------------------------------------------------------
  --  name:               get_active_price
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get price from price list
  --  Parameters:         p_price_book_version_id
  --                      p_price_reference - there are 3 pl fields for pb version.
  --                                          this parameter indicates which of them to refer.
  --                      p_inventory_item_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --  SAAR Comment: use Select instead of cursor. If you keep the cursor you do not need "EXCEPTION"
  --------------------------------------------------------------------
  FUNCTION get_active_price(p_price_book_version_id NUMBER,
		    p_price_reference       NUMBER,
		    p_inventory_item_id     NUMBER) RETURN NUMBER IS

    CURSOR c_master_pl IS
      SELECT qll.operand cur_price
      FROM   xxqp_price_books_versions xpbv,
	 qp_list_lines_v           qll
      WHERE  xpbv.price_book_version_id = p_price_book_version_id
      AND    qll.product_attr_value = to_char(p_inventory_item_id)
      AND    qll.list_header_id =
	 decode(p_price_reference,
	         1,
	         xpbv.price_list_id_1,
	         2,
	         xpbv.price_list_id_2,
	         3,
	         xpbv.price_list_id_3)
      AND    trunc(xpbv.effective_date) BETWEEN
	 nvl(qll.start_date_active, xpbv.effective_date - 1) AND
	 nvl(qll.end_date_active, xpbv.effective_date + 1);

    l_price NUMBER;

  BEGIN
    log_message('get_active_price: p_price_book_version_id = ' ||
	    p_price_book_version_id || ' p_price_reference: ' ||
	    p_price_reference || ' p_inventory_item_id: ' ||
	    p_inventory_item_id);

    OPEN c_master_pl;
    FETCH c_master_pl
      INTO l_price;
    CLOSE c_master_pl;

    RETURN l_price;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_active_price;

  --------------------------------------------------------------------
  --  name:               is_item_valid
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get condition sql and value for item
  --                      execute code and return valid/invalid for manipulation
  --                      see setup in valueset XXOM_PL_UPD_CATEGORY
  --                      (Original code is in xxqp_utils_pkg)
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE is_item_valid(p_err_code          OUT NUMBER,
		  p_err_msg           OUT VARCHAR2,
		  x_out_is_valid      OUT NUMBER,
		  p_condition_sql     VARCHAR2,
		  p_value             VARCHAR2,
		  p_inventory_item_id NUMBER) IS
  BEGIN
    p_err_code := 0;
    IF p_condition_sql IS NULL THEN
      x_out_is_valid := 1;
      p_err_msg      := 'No validation sql exists for item.';
      RETURN;
    END IF;
    EXECUTE IMMEDIATE p_condition_sql
      INTO x_out_is_valid
      USING p_inventory_item_id, p_value;

    IF x_out_is_valid = 1 THEN
      p_err_msg := 'Sql validation for item failed.';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Dynamic condition failed :' || SQLERRM;
  END;

  --------------------------------------------------------------------
  --  name:               check_excluded_item
  --  create by:          Diptasurjya
  --  $Revision:          1.0
  --  customization code: CHG0040353 - Price Books Adjustment to handle PL Update customization
  --  creation date:      28/04/2017
  --  Description:        This procedure will check if an item is defined as an exclusion in
  --                      the mentioned pricelist
  --  Parameters:         p_inventory_item_id
  --                      p_price_ref
  --                      p_price_book_version_id
  --                      p_source_type
  --                      x_is_item_valid -    1- valid exclusion present  0 - not valid
  --                      x_err_code -     1 -err 0 valid
  --                      x_err_msg
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2017    Diptasurjya     initial build
  --------------------------------------------------------------------
  procedure check_excluded_item (p_inventory_item_id IN number,
                                 p_price_ref IN number,
                                 p_price_book_version_id IN number,
                                 p_source_type IN varchar2,
                                 x_is_item_valid OUT number,
                                 x_err_code OUT number,
                                 x_err_msg OUT varchar2)
  is
    l_rule_id number := 0;

    l_out_item_valid number;
    l_out_actual_factor number;
    l_out_traget_price number;
    l_out_new_price number;
    l_excl_exists varchar2(1);
    l_exclude varchar2(1);
    l_excl_err_code number;
    l_excl_err_msg varchar2(2000);
  begin
    log_message('In Exclusion check');
    if p_price_ref = 1 then
      begin
        select xprh.rule_id
          into l_rule_id
          from xxqp_price_books_versions xpbv,
               xxom_pl_upd_rule_header xprh
         where xpbv.price_book_version_id = p_price_book_version_id
           and xpbv.price_list_id_1 = xprh.list_header_id;
      exception when no_data_found then
        null;
      end;
    elsif p_price_ref = 2 then
      begin
        select xprh.rule_id
          into l_rule_id
          from xxqp_price_books_versions xpbv,
               xxom_pl_upd_rule_header xprh
         where xpbv.price_book_version_id = p_price_book_version_id
           and xpbv.price_list_id_2 = xprh.list_header_id;
      exception when no_data_found then
        null;
      end;
    else
      begin
        select xprh.rule_id
          into l_rule_id
          from xxqp_price_books_versions xpbv,
               xxom_pl_upd_rule_header xprh
         where xpbv.price_book_version_id = p_price_book_version_id
           and xpbv.price_list_id_3 = xprh.list_header_id;
      exception when no_data_found then
        null;
      end;
    end if;

    log_message('Rule ID: '||l_rule_id);

    if p_source_type = 'SIMULATION'
    then
      begin
        log_message('Sim Exclusion');
        l_exclude := get_simulation_exclusion(p_price_book_version_id,
             p_price_ref,
             p_inventory_item_id);
        log_message('Exclude flag: '||l_exclude);
        l_excl_err_code := 0;
        l_out_item_valid := 1;
      exception when others then
        l_excl_err_code := 1;
        l_out_item_valid := 0;
        l_excl_err_msg := 'ERROR: While fetching simulation exclusion. '||SQLERRM;
      end;
    else
      xxqp_utils_pkg.handle_exclusion(p_inventory_item_id,
                       l_rule_id,
                       l_out_item_valid,
                       l_out_actual_factor,
                       l_out_traget_price,
                       l_out_new_price,
                       l_excl_exists,
                       l_exclude,
                       l_excl_err_code,
                       l_excl_err_msg);
    end if;



    if l_excl_err_code <> 1 and l_out_item_valid = 1 and l_exclude = 'Y' then
      x_is_item_valid := 1;
      x_err_code := 0;
      x_err_msg := null;
    else
      x_is_item_valid := 0;
      if l_excl_err_code = 1 then
        x_err_code := 1;
        x_err_msg := l_excl_err_msg;
      else
        x_err_code := 0;
        x_err_msg := null;
      end if;
    end if;

  exception when others then
    x_err_code := 1;
    x_err_msg := 'ERROR: '||sqlerrm;
  end;

  --------------------------------------------------------------------
  --  name:               handle_item
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        get condition sql and value for item
  --                      execute code and return valid/invalid for manipulation
  --                      see setup in valueset XXOM_PL_UPD_CATEGORY
  --                      (Original code is in xxqp_utils_pkg)
  --  Parameters:         p_source_type - indicates run mode. values: SIMULATION, ACTIVE_SIMULATION, RELEASE
  --                      p_inventory_item_id
  --                      p_price_book_version_id
  --                      x_out_item_valid-    1- valid  0 - not valid
  --                      x_out_price_1-  base price 1 for manipulation
  --                      x_out_price_2-  base price 2 for manipulation
  --                      x_out_price_3-  base price 3 for manipulation
  --                      x_err_code-     1 -err 0 valid
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --  1.1   28/04/2017    Diptasurjya     CHG0040353 - Adjust CS price book
  --                                      to support PL customization changes
  --------------------------------------------------------------------
  PROCEDURE handle_item(p_source_type           VARCHAR2,
		p_inventory_item_id     NUMBER,
		p_price_book_version_id NUMBER,
		x_out_item_valid        OUT NUMBER,
		x_out_price_1           OUT NUMBER,
		x_out_price_2           OUT NUMBER,
		x_out_price_3           OUT NUMBER,
		x_err_code              OUT NUMBER,
		x_err_msg               OUT VARCHAR2) IS

    CURSOR c_factors(p_price_book_version_id NUMBER,
	         p_price_reference       NUMBER) IS
      SELECT xpbf.category_code,
	 xpbf.factor_value,
	 xpbf.category_value,
	 xpbf.price_reference,
	 xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
					 xpbf.category_code,
					 'ATTRIBUTE3') condition_sql
      FROM   xxqp_price_books_factors xpbf
      WHERE  xpbf.price_book_version_id = p_price_book_version_id
      AND    xpbf.price_reference = p_price_reference
      ORDER  BY xpbf.price_reference;

    l_item_excluded         number;  -- 	CHG0040353
    l_item_excluded_pl_1    number;  -- 	CHG0040353
    l_item_excluded_pl_2    number;  -- 	CHG0040353
    l_item_excluded_pl_3    number;  -- 	CHG0040353

    l_excl_err_code    number;          -- 	CHG0040353
    l_excl_err_msg     varchar2(2000);  --	CHG0040353

    l_item_is_valid    NUMBER;
    l_note             VARCHAR2(2000);
    l_simulation_price NUMBER;
    l_err_msg          VARCHAR2(500);
    l_err_code         NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';

    -- Do the same logic for 3 price fields
    FOR price_ref IN 1 .. 3 LOOP
      --x_out_price_1 := null;
      --x_out_price_2 := null;
      --x_out_price_3 := null;
      --l_item_excluded_pl_1 := null;
      --l_item_excluded_pl_2 := null;
      --l_item_excluded_pl_3 := null;
      
      log_message('Handle Item: '||price_ref);
      
      IF p_source_type = 'SIMULATION' THEN
        l_simulation_price := get_simulation_price(p_price_book_version_id,
				   price_ref,
				   p_inventory_item_id);

        log_message('Sim Price: '||l_simulation_price);
      ELSE
        -- p_source_type in (ACTIVE_SIMULATION, RELEASE)
        l_simulation_price := get_active_price(p_price_book_version_id,
			           price_ref,
			           p_inventory_item_id);
      END IF;

      --dbms_output.put_line('TEST : '||l_simulation_price);

      -- Start - CHG0040353
      check_excluded_item(p_inventory_item_id,
                          price_ref,
                          p_price_book_version_id,
                          p_source_type,
                          l_item_excluded,
                          l_excl_err_code,
                          l_excl_err_msg);

      if l_excl_err_code = 1 then
        x_err_code       := l_excl_err_code;
        x_err_msg        := l_excl_err_msg;
        x_out_item_valid := 1;
        x_out_price_1    := NULL;
        x_out_price_2    := NULL;
        x_out_price_3    := NULL;
        return;
      end if;


      if price_ref = 1 then
        l_item_excluded_pl_1 := l_item_excluded;
      elsif price_ref = 2 then
        l_item_excluded_pl_2 := l_item_excluded;
      else
        l_item_excluded_pl_3 := l_item_excluded;
      end if;
      -- End - CHG0040353
      
      log_message('For 1: '||l_item_excluded_pl_1);
      log_message('For 2: '||l_item_excluded_pl_2);
      log_message('For 3: '||l_item_excluded_pl_3);
      
      IF l_simulation_price IS not NULL THEN     -- CHG0040353 - Made not null
        --x_err_code := 1;     --  CHG0040353
        --x_err_msg  := x_err_msg || 'No price found for price ' || price_ref || '. '; -- CHG0040353
      --ELSE  -- CHG0040353
        FOR i IN c_factors(p_price_book_version_id, price_ref) LOOP

          is_item_valid(l_err_code,
                        l_err_msg,
                        l_item_is_valid,
                        i.condition_sql,
                        i.category_value,
                        p_inventory_item_id);

          IF l_err_code = 1 THEN
            x_out_item_valid   := 1;
            l_simulation_price := NULL;
            x_err_msg          := x_err_msg || l_err_msg;
            RETURN;
          ELSIF l_item_is_valid = 1 THEN
	l_note             := l_err_msg || '; ' || l_note ||
		          i.category_value || ' ' || i.factor_value || ',';
	l_simulation_price := ceil(l_simulation_price * i.factor_value);
          END IF;
          x_out_item_valid := greatest(nvl(x_out_item_valid, 0),
			   l_item_is_valid);

        END LOOP;
      END IF;
      log_message('p_inventory_item_id: ' || p_inventory_item_id ||
	      ', price_ref: ' || price_ref || ', l_simulation_price: ' ||
	      l_simulation_price);

      CASE price_ref
        WHEN 1 THEN
          x_out_price_1 := l_simulation_price;
        WHEN 2 THEN
          x_out_price_2 := l_simulation_price;
        WHEN 3 THEN
          x_out_price_3 := l_simulation_price;
      END CASE;
      
      log_message('For 1: '||x_out_price_1);
      log_message('For 2: '||x_out_price_2);
      log_message('For 3: '||x_out_price_3);
    END LOOP;
/*
    if (x_out_price_1 is null and l_item_excluded_pl_1 = 1) and
       (x_out_price_2 is null and l_item_excluded_pl_2 = 1) and
       (x_out_price_3 is null and l_item_excluded_pl_3 = 1) then

    end if;*/

    if (x_out_price_1 is null and l_item_excluded_pl_1 = 0)  then
      x_out_item_valid := 1;
      --x_out_price_1    := NULL;
      --x_out_price_2    := NULL;
      --x_out_price_3    := NULL;
      x_err_code       := 1;
      x_err_msg        := x_err_msg||'ERROR: No price found for price 1. ';
    end if;

    if (x_out_price_2 is null and l_item_excluded_pl_2 = 0)  then
      x_out_item_valid := 1;
      --x_out_price_1    := NULL;
      --x_out_price_2    := NULL;
      --x_out_price_3    := NULL;
      x_err_code       := 1;
      x_err_msg        := x_err_msg||'ERROR: No price found for price 2. ';
    end if;

    if (x_out_price_3 is null and l_item_excluded_pl_3 = 0)  then
      x_out_item_valid := 1;
      --x_out_price_1    := NULL;
      --x_out_price_2    := NULL;
      --x_out_price_3    := NULL;
      x_err_code       := 1;
      x_err_msg        := x_err_msg||'ERROR: No price found for price 3. ';
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      x_out_item_valid := 1;
      x_out_price_1    := NULL;
      x_out_price_2    := NULL;
      x_out_price_3    := NULL;
      x_err_code       := 1;
      x_err_msg        := SQLERRM;
  END handle_item;

  --------------------------------------------------------------------
  --  name:               generate_simulation
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        calculate price for each relevant item
  --                      and populate table xxqp_price_books_lines
  --  Parameters:         p_price_book_version_id
  --                      p_source_type - indicates run mode. values: SIMULATION, ACTIVE_SIMULATION, RELEASE
  --                      p_inventory_item_id
  --                      p_price_book_version_id
  --                      x_err_code-     1 -err 0 valid
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --  1.1   28/04/2017    Diptasurjya     CHG0040353 - Adjust CS price book
  --                                      to support PL customization changes
  --------------------------------------------------------------------
  PROCEDURE generate_simulation(p_price_book_version_id VARCHAR2,
		        p_source_type           VARCHAR2,
		        x_err_code              OUT NUMBER,
		        x_err_msg               OUT VARCHAR2) IS

    CURSOR c_items IS
      SELECT mic.inventory_item_id
      FROM   mtl_item_categories  mic,
	 mtl_category_sets_tl mcsb
      WHERE  mic.organization_id = c_master_organization
      AND    mic.category_set_id = mcsb.category_set_id
      AND    mcsb.category_set_name = 'CS Price Book Product Type'
      AND    mcsb.language = 'US'
      --and    mic.inventory_item_id = 1013414
      --and    mic.inventory_item_id in (1101761)
      GROUP  BY mic.inventory_item_id;

    l_simulation_price_1 NUMBER;
    l_simulation_price_2 NUMBER;
    l_simulation_price_3 NUMBER;
    l_out_item_valid     NUMBER;
    l_out_err_code       NUMBER;
    l_out_err_mesg       VARCHAR2(500);
    l_version_rec        xxqp_price_books_versions%ROWTYPE;
    l_price_book_line_id NUMBER;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';

    SELECT *
    INTO   l_version_rec
    FROM   xxqp_price_books_versions xpbv
    WHERE  xpbv.price_book_version_id = p_price_book_version_id;

    --Delete previous simulation for the same version
    DELETE FROM xxqp_price_books_lines xpbl
    WHERE  xpbl.source_type = c_src_simulation
    AND    xpbl.price_book_version_id = p_price_book_version_id;

    FOR r_item IN c_items LOOP

      log_message('---------------------------------------');
      log_message('inventory_item_id: ' || r_item.inventory_item_id);
      -- Initiate variables
      l_simulation_price_1 := NULL;
      l_simulation_price_2 := NULL;
      l_simulation_price_3 := NULL;

      -- Get new_price from mass update simulation
      handle_item(p_source_type,
	      r_item.inventory_item_id,
	      p_price_book_version_id,
	      l_out_item_valid,
	      l_simulation_price_1,
	      l_simulation_price_2,
	      l_simulation_price_3,
	      l_out_err_code,
	      l_out_err_mesg);

      IF l_out_err_code = 1 THEN
        log_message('Error: ' || l_out_err_mesg);
      END IF;

      -- Start CHG0040353
      IF l_out_err_code <> 1 and l_simulation_price_1 is null and l_simulation_price_2 is null and l_simulation_price_3 is null then
        continue;
      end if;
      -- End CHG0040353

      -- create simulation record
      FOR r_hierarchy IN c_product_hierarchy(r_item.inventory_item_id) LOOP

        IF r_hierarchy.product_type_l1 IS NULL OR
           r_hierarchy.product_type_l2 IS NULL THEN
          l_out_err_mesg := l_out_err_mesg || ' Invalid hierarchy.';
        END IF;

        SELECT xxqp_price_books_lines_s.nextval
        INTO   l_price_book_line_id
        FROM   dual;

        INSERT INTO xxqp_price_books_lines
          (price_book_line_id,
           price_book_id,
           price_book_version_id,
           source_type,
           product_type_l1,
           description_l1,
           image_l1,
           product_type_l2,
           description_l2,
           image_l2,
           product_type_l3,
           description_l3,
           image_l3,
           inventory_item_id,
           reseller_price,
           customer_price,
           third_party_price,
           err_msg,
           request_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           long_desc_l1,
           long_desc_l2)
        VALUES
          (l_price_book_line_id, --price_book_line_id,
           l_version_rec.price_book_id, --price_book_id,
           p_price_book_version_id, --price_book_version_id,
           c_src_simulation, --source_type,
           r_hierarchy.product_type_l1, --product_type_l1,
           r_hierarchy.description_l1,
           r_hierarchy.image_l1,
           r_hierarchy.product_type_l2, --product_type_l2,
           r_hierarchy.description_l2,
           r_hierarchy.image_l2,
           r_hierarchy.product_type_l3, --product_type_l3,
           r_hierarchy.description_l3,
           r_hierarchy.image_l3,
           r_item.inventory_item_id, --inventory_item_id,
           l_simulation_price_1, --reseller_price,
           l_simulation_price_2, --customer_price,
           l_simulation_price_3, --third_party_price,
           l_out_err_mesg, --err_msg,
           fnd_global.conc_request_id, --request_id,
           c_sysdate, --last_update_date,
           fnd_global.user_id, --last_updated_by,
           c_sysdate, --creation_date,
           fnd_global.user_id, --created_by,
           fnd_global.login_id, --last_update_login
           r_hierarchy.long_desc_l1,
           r_hierarchy.long_desc_l2);

      END LOOP;
    END LOOP;

    UPDATE xxqp_price_books_versions xpbf
    SET    xpbf.pl_simulation_request_id = fnd_global.conc_request_id,
           xpbf.last_updated_by          = fnd_global.user_id,
           xpbf.last_update_date         = c_sysdate,
           xpbf.last_update_login        = fnd_global.login_id
    WHERE  xpbf.price_book_version_id = p_price_book_version_id;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Error in generate_simulation: ' || SQLERRM;
  END generate_simulation;

  --------------------------------------------------------------------
  --  name:               submit_price_book_report
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        Submit concurrent 'XXQP: Price Book Report'
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE submit_price_book_report(p_price_book_version_id VARCHAR2,
			 p_generation_id         NUMBER DEFAULT NULL,
			 x_request_id            OUT NUMBER,
			 x_err_code              OUT NUMBER,
			 x_err_msg               OUT VARCHAR2) IS

    x_return_bool BOOLEAN;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';

    -- apps_initialize is needed in order to avoid failure of running this procedure from setup form.
    -- Sometimes it fails, and the following statement prevent it.
    fnd_global.apps_initialize(fnd_global.user_id,
		       fnd_global.resp_id,
		       fnd_global.resp_appl_id);

    IF p_price_book_version_id IS NULL THEN
      x_err_code := 1;
      x_err_msg  := 'Parameter p_price_book_version_id is required.';
      log_message(x_err_msg);
      RETURN;
    END IF;

    log_message('Submit concurrent ''XXQP: Price Book Report'' with p_price_book_version_id = ' ||
	    p_price_book_version_id);

    x_return_bool := fnd_request.add_layout(template_appl_name => 'XXOBJT',

			        template_code => 'XXQP_PRICE_BOOK_REPORT',

			        template_language => 'en',

			        template_territory => 'US',

			        output_format => 'EXCEL');
    IF NOT x_return_bool THEN
      x_err_code := 1;
      x_err_msg  := 'Failed to add layout.';
      log_message(x_err_msg);
      RETURN;
    END IF;

    x_request_id := fnd_request.submit_request('XXOBJT',

			           'XXQP_PRICE_BOOK_REPORT',

			           NULL,
			           NULL,
			           FALSE,

			           p_price_book_version_id,

			           p_generation_id);

    IF x_request_id > 0 THEN
      log_message('Concurrent ''XXQP: Price Book Report'' was submitted successfully (request_id=' ||
	      x_request_id || ')');
      COMMIT;

    ELSE
      x_err_code := 1;
      x_err_msg  := 'Failed to submit request.';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := SQLERRM;

  END submit_price_book_report;

  --------------------------------------------------------------------
  --  name:               run_simulation
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        1. Call generate_simulation in order to populate table
  --                      2. Submit concurrent 'XXQP: Price Book Report'
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE run_simulation(errbuf  OUT VARCHAR2,
		   retcode OUT VARCHAR2,
		   --x_request_id            OUT NUMBER,
		   p_price_book_version_id VARCHAR2,
		   p_source_type           VARCHAR2) IS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(1000);
  BEGIN
    retcode := '0';
    errbuf  := '';
    --generate_simulation
    generate_simulation(p_price_book_version_id,
		p_source_type,
		l_err_code,
		l_err_msg);

    IF l_err_code = 1 THEN
      retcode := '1';
      errbuf  := 'Failed to generate simulation: ' || l_err_msg || ';';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := errbuf || 'Error in run_simulation: ' || SQLERRM;
  END run_simulation;
  /*
  --------------------------------------------------------------------
  --  name:               get_homepage_text
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      04/05/2015
  --  Description:        get text for HTML home page
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_homepage_text(p_price_book_version_id VARCHAR2)
    RETURN VARCHAR2 IS
    l_effective VARCHAR2(25);
    msg         VARCHAR2(250);
  BEGIN
    SELECT to_char(xpbv.effective_date, 'Mon/YYYY')
    INTO   l_effective
    FROM   xxqp_price_books_versions xpbv
    WHERE  xpbv.price_book_version_id = p_price_book_version_id;

    fnd_message.set_name('XXOBJT', 'XXQP_PRICE_BOOK_HTML_HOME');
    fnd_message.set_token('EFFECTIVE', l_effective);
    msg := fnd_message.get;

    RETURN msg;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Failed to get html home page text: ' ||
                         SQLERRM);
      RETURN NULL;
  END get_homepage_text;*/

  --------------------------------------------------------------------
  --  name:               beforereport
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        beforereport trigger for 'XXQP: Price Book Report'
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION beforereport RETURN BOOLEAN IS
  BEGIN
    IF p_generation_id IS NULL THEN
      lp_generation := 'and 1=1';

    ELSE
      lp_generation := 'and (product_type_l1,product_type_l2,product_type_l3) in
	         (select product_type_l1,product_type_l2,product_type_l3
	          from xxqp_price_book_hier_gen
	          where generation_id = ' ||
	           to_char(p_generation_id) || ') ';
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, SQLERRM);
      RETURN FALSE;
  END beforereport;

  --------------------------------------------------------------------
  --  name:               afterreport
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        beforereport trigger for 'XXQP: Price Book Report'
  --                      Delete records of current generation_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION afterreport RETURN BOOLEAN IS
  BEGIN
    -- Delete records of current generation_id
    IF p_generation_id IS NOT NULL AND
       nvl(fnd_profile.value('XXQP_PB_DEBUG_MODE'), 'N') = 'N' THEN
      DELETE FROM xxqp_price_book_hier_gen
      WHERE  generation_id = p_generation_id;
      COMMIT;
    END IF;

    RETURN TRUE;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, SQLERRM);
      RETURN FALSE;
  END afterreport;

END xxqp_price_books_utl_pkg;
/
