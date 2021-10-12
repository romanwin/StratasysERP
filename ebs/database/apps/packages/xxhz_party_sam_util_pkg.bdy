CREATE OR REPLACE PACKAGE BODY xxhz_party_sam_util_pkg AS
  --------------------------------------------------------------------
  --  name:            xxhz_party_sam_util_pkg
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   5/1/2015
  --------------------------------------------------------------------
  --  purpose : Utility package used by XXHZ_PARTY_SAM_RPT XML report
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------

g_log               VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
g_log_module        VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
g_request_id        NUMBER        := TO_NUMBER(fnd_global.conc_request_id);
g_log_program_unit  VARCHAR2(100);
g_program_unit      VARCHAR2(30);
g_pricing_error     VARCHAR2(25) := 'PRICING ERROR';

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  12/12/2014  MMAZANET    Initial Creation for CHG003877.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE write_log(p_msg  VARCHAR2)
   IS
   BEGIN
      IF g_log = 'Y' AND UPPER('xxhz.party_ga_util.xxhz_party_sam_util_pkg.'||g_log_program_unit) LIKE UPPER(g_log_module) THEN
        fnd_log.STRING(
          log_level => fnd_log.LEVEL_UNEXPECTED,
          module    => 'xxhz.party_ga_util.xxhz_party_sam_util_pkg.'||g_log_program_unit,
          message   => p_msg
        );
      END IF;
   END write_log;

  --------------------------------------------------------------------
  --  name:            get_ib_sam_basket
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   15/04/2015
  --------------------------------------------------------------------
  --  purpose : Basket amounts have been defined in a lookup type called
  --            'XXIB_BUCKET_VALUE'.  The basket amounts are defined based
  --            on the amount sent in.  The lookup looks like the following
  -- 
  --            Amount              Basket
  --            ------------------  ------
  --                       <249999       A
  --                 250000-749999       B
  --                750000-1249999       C
  --               1250000-1999999       D
  --                      >2000000       E
  --
  --            The function figures out the >, <, and between logic to
  --            see which bucket the p_amount falls into.
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------
  FUNCTION get_ib_sam_basket(p_amount  NUMBER)
  RETURN VARCHAR2
  IS  
    CURSOR c_basket
    IS
      SELECT 
        meaning     amount,
        lookup_code basket
      FROM fnd_lookup_values  flv
      WHERE lookup_type = 'XXIB_BUCKET_VALUE'
      AND   language    = USERENV('LANG')
      AND   enabled_flag= 'Y';
  
    l_basket VARCHAR2(2);
  BEGIN
    FOR rec IN c_basket LOOP
      IF INSTR(rec.amount,'>') = 1 AND p_amount > TO_NUMBER(REGEXP_REPLACE(rec.amount,'[^[:digit:]]')) THEN
        l_basket := rec.basket;
      ELSIF INSTR(rec.amount,'<') = 1 AND p_amount < TO_NUMBER(REGEXP_REPLACE(rec.amount,'[^[:digit:]]')) THEN
        l_basket := rec.basket;
      ELSIF INSTR(rec.amount,'-') > 1 THEN
                            -- Number before '-'                             -- Number after '-'
        IF p_amount BETWEEN TO_NUMBER(REGEXP_SUBSTR(rec.amount,'[^-]+',1,1)) AND TO_NUMBER(REGEXP_SUBSTR(rec.amount,'[^-]+',1,2)) THEN
          l_basket  := rec.basket;  
        END IF;
      END IF;
    END LOOP;
    IF l_basket IS NULL THEN 
      RETURN 'NA';
    ELSE RETURN l_basket;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN 
      RETURN 'NA';
  END get_ib_sam_basket;

  --------------------------------------------------------------------
  --  name:            get_ib_aging_factor         
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   15/04/2015
  --------------------------------------------------------------------
  --  purpose : This gives the depreciating factor of an install base
  --            item based on how far the install date is from the 
  --            SYSDATE.
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------
  FUNCTION get_ib_aging_factor(p_date DATE)
  RETURN NUMBER
  IS
    l_years   NUMBER;
    l_factor  NUMBER;
    CURSOR c_factor
    IS
      SELECT 
        TO_NUMBER(meaning)          factor,
        TO_NUMBER(REGEXP_REPLACE(lookup_code,'[^[:digit:]]'))
                                    years,
        MAX(TO_NUMBER(REGEXP_REPLACE(lookup_code,'[^[:digit:]]'))) OVER (PARTITION BY lookup_type)
                                    max_val,
        MIN(TO_NUMBER(REGEXP_REPLACE(lookup_code,'[^[:digit:]]'))) OVER (PARTITION BY lookup_type)
                                    min_val
      FROM fnd_lookup_values  
      WHERE lookup_type   = 'XXIB_AGING_VALUE'
      AND   language      = USERENV('LANG')
      AND   enabled_flag  = 'Y';
  BEGIN
    l_years := TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')) - TO_NUMBER(TO_CHAR(p_date,'YYYY'));
    
    FOR rec IN c_factor LOOP
      IF l_years = rec.years THEN
        RETURN rec.factor;
      ELSIF l_years > rec.max_val THEN 
        RETURN 0;
      ELSIF l_years < rec.min_val THEN 
        RETURN 1;
      END IF;
    END LOOP;
    
    RETURN 1;
  END get_ib_aging_factor;

  --------------------------------------------------------------------
  --  name:            get_price_item_by_price_list
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   15/04/2015
  --------------------------------------------------------------------
  --  purpose : Calls pricing engine to price item based on the item
  --            and the pricelist specified by the parameter.  The
  --            return value is a VARCHAR2 because if there is an
  --            error, the function will return 'PRICING ERROR'.
  --            You will need to turn on logging and check the log 
  --            for the exact error.  If no error occurs, the function
  --            will return the price as a character string.
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------
  FUNCTION price_item_by_price_list(
    p_inventory_item_id     IN NUMBER,
    p_price_list_id         IN NUMBER,
    p_price_list_curr_code  IN VARCHAR2
  )
  RETURN VARCHAR2
  IS PRAGMA AUTONOMOUS_TRANSACTION;
  
      l_adjusted_unit_price NUMBER;

      l_line_tbl                      qp_preq_grp.line_tbl_type;
      l_qual_tbl                      qp_preq_grp.qual_tbl_type;
      l_line_attr_tbl                 qp_preq_grp.line_attr_tbl_type;
      l_line_detail_tbl               qp_preq_grp.line_detail_tbl_type;
      l_line_detail_qual_tbl          qp_preq_grp.line_detail_qual_tbl_type;
      l_line_detail_attr_tbl          qp_preq_grp.line_detail_attr_tbl_type;
      l_related_lines_tbl             qp_preq_grp.related_lines_tbl_type;
      l_control_rec                   qp_preq_grp.control_record_type;
      x_line_tbl                      qp_preq_grp.line_tbl_type;
      x_line_qual                     qp_preq_grp.qual_tbl_type;
      x_line_attr_tbl                 qp_preq_grp.line_attr_tbl_type;
      x_line_detail_tbl               qp_preq_grp.line_detail_tbl_type;
      x_line_detail_qual_tbl          qp_preq_grp.line_detail_qual_tbl_type;
      x_line_detail_attr_tbl          qp_preq_grp.line_detail_attr_tbl_type;
      x_related_lines_tbl             qp_preq_grp.related_lines_tbl_type;
      x_return_status                 VARCHAR2(240);
      x_return_status_text            VARCHAR2(4000);
      qual_rec                        qp_preq_grp.qual_rec_type;
      line_attr_rec                   qp_preq_grp.line_attr_rec_type;
      line_rec                        qp_preq_grp.line_rec_type;

      l_pricing_contexts_tbl          qp_attr_mapping_pub.contexts_result_tbl_type;
      l_qualifier_contexts_tbl        qp_attr_mapping_pub.contexts_result_tbl_type;

      l_resp_id                       NUMBER;
      l_count                         NUMBER := 0;
      
      e_error                         EXCEPTION;
   BEGIN    
    g_log_program_unit := 'PRICE_ITEM_BY_PRICE_LIST'; 
    write_log('START '||g_log_program_unit);
    write_log('p_inventory_item_id: '||p_inventory_item_id);
    write_log('p_price_list_id: '||p_price_list_id);
    write_log('p_price_list_curr_code: '||p_price_list_curr_code);

      ---- Control Record
      l_control_rec.pricing_event             :='LINE';-- 'BATCH';
      l_control_rec.calculate_flag            := 'Y'; --QP_PREQ_GRP.G_SEARCH_N_CALCULATE;
      l_control_rec.simulation_flag           := 'N';

      l_control_rec.rounding_flag             := 'Q';
      l_control_rec.manual_discount_flag      := 'Y';
      l_control_rec.request_type_code         := 'ONT';
      l_control_rec.temp_table_insert_flag    := 'Y';
      l_control_rec.debug_flag                := 'N';

      ---- Line Records ---------
      line_rec.request_type_code              :='ONT';
      line_rec.line_id                        := 1; -- Order Line Id. This can be any thing for this script
      line_rec.line_Index                     :='1'; -- Request Line Index
      line_rec.line_type_code                 := 'LINE';--'LINE'; -- LINE or ORDER(Summary Line)
      line_rec.pricing_effective_date         := SYSDATE; -- Pricing as of what date ?
      line_rec.active_date_first              := SYSDATE; -- Can be Ordered Date or Ship Date
      line_rec.active_date_second             := SYSDATE; -- Can be Ordered Date or Ship Date
      line_rec.active_date_first_type         := 'NO TYPE';--'NO TYPE'; -- ORD/SHIP
      line_rec.active_date_second_type        := 'NO TYPE';--'NO TYPE'; -- ORD/SHIP
      line_rec.line_quantity                  := 1; -- Ordered Quantity
      line_rec.line_uom_code                  := 'EA'; -- Ordered UOM Code
      line_rec.currency_code                  := p_price_list_curr_code; -- Currency Code
      line_rec.price_flag                     := 'Y'; -- Price Flag can have 'Y' , 'N'(No pricing) , 'P'(Phase)
      l_line_tbl(1) := line_rec;

      ---- Line Attribute Record

      line_attr_rec.line_index                        := 1;
      line_attr_rec.pricing_context                   :='ITEM'; --
      line_attr_rec.pricing_attribute                 :='PRICING_ATTRIBUTE3';
      line_attr_rec.pricing_attr_value_from           :='ALL';
      line_attr_rec.validated_flag                    :='N';
      l_line_attr_tbl(1)                              := line_attr_rec;

      line_attr_rec.line_index                        := 1;
      line_attr_rec.pricing_context                   :='ITEM'; --
      line_attr_rec.pricing_attribute                 :='PRICING_ATTRIBUTE1';
      line_attr_rec.pricing_attr_value_from           := p_inventory_item_id;     -- Inventory item id
      line_attr_rec.validated_flag                    :='N';
      l_line_attr_tbl(2)                              := line_attr_rec;

      qual_rec.LINE_INDEX                             := 1; -- Attributes for the above line. Attributes are attached with the line index
      qual_rec.QUALIFIER_CONTEXT                      := 'MODLIST';
      qual_rec.QUALIFIER_ATTRIBUTE                    := 'QUALIFIER_ATTRIBUTE4';
      qual_rec.QUALIFIER_ATTR_VALUE_FROM              := p_price_list_id;                    -- PRICE LIST ID
      qual_rec.COMPARISON_OPERATOR_CODE               := '=';
      -- Flip to 'N' to look at other qualifiers
      qual_rec.VALIDATED_FLAG                         :='N';
      l_qual_tbl(1)                                   := qual_rec;
      
      qp_attr_mapping_pub.build_contexts(
         p_request_type_code         => 'ONT'
      ,  p_pricing_type              => 'L'
      ,  x_price_contexts_result_tbl => l_pricing_contexts_tbl
      ,  x_qual_contexts_result_tbl  => l_qualifier_contexts_tbl);

      qp_preq_pub.price_request(
         p_line_tbl                 => l_line_tbl
      ,  p_qual_tbl                 => l_qual_tbl
      ,  p_line_attr_tbl            => l_line_attr_tbl
      ,  p_line_detail_tbl          => l_line_detail_tbl
      ,  p_line_detail_qual_tbl     => l_line_detail_qual_tbl
      ,  p_line_detail_attr_tbl     => l_line_detail_attr_tbl
      ,  p_related_lines_tbl        => l_related_lines_tbl
      ,  p_control_rec              => l_control_rec
      ,  x_line_tbl                 => x_line_tbl
      ,  x_line_qual                => x_line_qual
      ,  x_line_attr_tbl            => x_line_attr_tbl
      ,  x_line_detail_tbl          => x_line_detail_tbl
      ,  x_line_detail_qual_tbl     => x_line_detail_qual_tbl
      ,  x_line_detail_attr_tbl     => x_line_detail_attr_tbl
      ,  x_related_lines_tbl        => x_related_lines_tbl
      ,  x_return_status            => x_return_status
      ,  x_return_status_text       => x_return_status_text);

      IF x_return_status <> 'S' THEN
        write_log('Pricing error: '||x_return_status_text);
        RAISE e_error;
      ELSE 
        COMMIT;
        RETURN TO_CHAR(x_line_tbl(1).adjusted_unit_price);
      END IF;
  EXCEPTION
    WHEN e_error THEN
      COMMIT;
      RETURN g_pricing_error;
    WHEN OTHERS THEN 
      write_log('Exception block for PRICE_ITEM_BY_PRICE_LIST: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      COMMIT;
      RETURN g_pricing_error;
  END price_item_by_price_list;

  --------------------------------------------------------------------
  --  name:            stage_sam_pricing_tbl      
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   15/04/2015
  --------------------------------------------------------------------
  --  purpose : Cycles through distinct list of item/price list and
  --            calculates the price of those items by calling 
  --            price_item_by_price_list.  It then updates the pricing
  --            fields on xxhz_party_sam_pricing
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------  
  PROCEDURE price_items(
    x_return_status   OUT VARCHAR2,
    x_return_msg      OUT VARCHAR2
  )
  IS
    -- Get unique list of items and price lists then update the price on
    -- xxhz_party_sam_pricing.
    CURSOR c_price
    IS
      SELECT DISTINCT 
        inventory_item_id,
        price_list_id,
        price_list_curr_code
      FROM xxhz_party_sam_pricing
      WHERE price_list_id IS NOT NULL;
      
    l_price       xxhz_party_sam_pricing.price%TYPE;
    l_price_usd   xxhz_party_sam_pricing.price_usd%TYPE;
  BEGIN
    g_program_unit  := 'PRICE_ITEMS';
    write_log('BEGIN '||g_program_unit);
    
    FOR rec IN c_price LOOP
      l_price := 0;
      write_log('rec.inventory_item_id: '||rec.inventory_item_id);
      write_log('rec.price_list_id: '||rec.price_list_id);
      
      l_price :=  price_item_by_price_list(
                    p_inventory_item_id     => rec.inventory_item_id,
                    p_price_list_id         => rec.price_list_id,
                    p_price_list_curr_code  => rec.price_list_curr_code
                  );
      
      write_log('l_price: '||l_price);
      
      IF l_price <> g_pricing_error THEN
        l_price_usd :=  gl_currency_api.convert_amount_sql(
                          rec.price_list_curr_code,
                          'USD',
                          SYSDATE,
                          'Corporate',
                          TO_NUMBER(l_price));
      ELSE
        l_price_usd := g_pricing_error;
      END IF;
      
      write_log('l_price_usd: '||l_price_usd);
      
      UPDATE xxhz_party_sam_pricing
      SET   
        price       = l_price,
        price_usd   = l_price_usd
      WHERE inventory_item_id = rec.inventory_item_id
      AND   price_list_id     = rec.price_list_id
      AND   request_id        = g_request_id;
    END LOOP;
  
    x_return_status := 'S';
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Exception in '||g_program_unit||': '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      write_log(x_return_msg);
  END price_items;

  --------------------------------------------------------------------
  --  name:            stage_sam_pricing_tbl      
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   15/04/2015
  --------------------------------------------------------------------
  --  purpose : Finds IB items for SAM child accounts.  It then finds
  --            an associated pricelist based on the 'XXIB_OU_TO_PRICELIST' 
  --            and calls price_items to price the IB items.  This is
  --            called from the beforeReport trigger on the 
  --            XXHZ_PARTY_SAM_RPT XML report
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  15/04/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------  
  FUNCTION stage_sam_pricing_tbl
  RETURN BOOLEAN
  IS
    l_return_status       VARCHAR2(1);
    l_return_msg          VARCHAR2(1000);
  BEGIN
    g_program_unit := 'STAGE_SAM_PRICING_TBL';
    write_log('START '||g_program_unit);
    
    INSERT INTO xxhz_party_sam_pricing(
      request_id,
      inventory_item_id,
      cust_account_id,
      contract_start_date,
      price_list_id,
      price,
      price_usd,
      price_list_curr_code
    )
    -- Query below will get all ga child parties IB items, install dates, and price lists
    -- This data will then be used to price the unique combinations of item and price_list_id
    -- in the price_items procedure.  Price will be updated on the xxhz_party_sam_pricing table
    -- above.  Then xxhz_party_sam_pricing will be joined to to calculate ib_value for the 
    -- XX: SAM Report.
    SELECT
      g_request_id,
      ib.inventory_item_id,
      ib.cust_account_id,
      ib.contract_start_date,
      pl.price_list_id,
      DECODE(pl.price_list_id,NULL,'PRE PRICING ERROR',NULL),
      DECODE(pl.price_list_id,NULL,'PRE PRICING ERROR',NULL),
      pl.currency_code
    FROM
    -- Get the unique IB records tied to ga child customers
    /* ib... */
     (SELECT DISTINCT
        xxobjt_oa2sf_interface_pkg.get_entity_oe_id('PRODUCT',product__c) 
                                              inventory_item_id,
        xpgv.cust_account_id                  cust_account_id,                 
        xibc.serial_number__c                 serial_number,
        xibc.service_contract_start_date__c   contract_start_date
      FROM 
        xxsf_install_base__c        xibc,
        xxhz_party_ga_v             xpgv
      WHERE xibc.account_oeid__c              = xpgv.cust_account_id
      AND   xibc.service_contract_status__c   = 'Active' 
     )               ib,
    /* ...ib */
    -- Get price lists for every ga child account.  Pricelist will come from primary BILL TO 
    -- site, if there is one, otherwise will come from account level.
    /* pl... */
     (SELECT DISTINCT 
        xpgv.cust_account_id            cust_account_id,
        qlh.list_header_id              price_list_id,
        qlh.currency_code               currency_code
      FROM
        xxhz_party_ga_v             xpgv,
        hz_parties                  hp,
        qp_list_headers             qlh,
        fnd_lookup_values           flv
      WHERE xpgv.parent_party_id        = hp.party_id
      AND   'XXIB_OU_TO_PRICELIST'      = flv.lookup_type
      AND   USERENV('LANG')             = flv.language
      AND   hp.attribute3               = flv.lookup_code
      AND   TO_NUMBER(flv.attribute1)   = qlh.list_header_id
     )                pl
    /* ...pl */
    WHERE ib.cust_account_id  = pl.cust_account_id (+);
    
    write_log(SQL%ROWCOUNT||' Rows INSERTED to XXHZ_PARTY_SAM_PRICING'); 
    
    -- Retrieve price for items
    price_items(
      x_return_status   => l_return_status,
      x_return_msg      => l_return_msg
    );
    
    write_log('price_items return status: '||l_return_status);
    
    IF l_return_status <> 'S' THEN 
      RETURN FALSE;
    END IF;
    
    write_log('END '||g_program_unit);
    RETURN TRUE;
  EXCEPTION 
    WHEN OTHERS THEN
      write_log('Exception in '||g_program_unit||': '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      RETURN FALSE;
  END stage_sam_pricing_tbl;

  --------------------------------------------------------------------
  --  name:            delete_sam_pricing_tbl      
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   04/15/2015
  --------------------------------------------------------------------
  --  purpose : This procedure is called from the afterReport trigger
  --            of the XXHZ_PARTY_SAM_RPT XML report.  This cleans up
  --            any records in the XXHZ_PARTY_SAM_PRICING table for the
  --            request_id of the report.  These records can be preserved
  --            for debugging purposes by setting the p_pricing_debug_flag
  --            to 'Y'.
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  04/15/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------  
  FUNCTION delete_sam_pricing_tbl
  RETURN BOOLEAN
  IS
  BEGIN
    g_program_unit := 'TRUNCATE_SAM_PRICING_TBL';
    
    write_log('START '||g_program_unit);
    
    -- For debugging purposes, may want to leave pricing records in xxhz_party_sam_pricing
    -- table.
    IF NVL(p_pricing_debug_flag,'N') = 'N' THEN 
      DELETE FROM xxobjt.xxhz_party_sam_pricing
      WHERE request_id = g_request_id;
      write_log(SQL%ROWCOUNT||' Records deleted');
    END IF;
    
    write_log('END '||g_program_unit);
    RETURN TRUE;
  EXCEPTION 
    WHEN OTHERS THEN
      write_log('Exception in '||g_program_unit||': '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      RETURN FALSE;
  END delete_sam_pricing_tbl;
  
  --------------------------------------------------------------------
  --  name:            truncate_sam_pricing_tbl      
  --  create by:       mmazanet
  --  Revision:        1.0
  --  creation date:   04/15/2015
  --------------------------------------------------------------------
  --  purpose : This will truncate all records for the xxhz_party_sam_pricing
  --            table, in the event that records were left in the table
  --            for debugging.  This is called from the 'XX: Customer 
  --            SAM Truncate IB Pricing Table'
  --------------------------------------------------------------------
  --  ver  date        name       desc
  --  1.0  04/15/2015  mmazanet   CHG0034062. initial build
  --------------------------------------------------------------------  
  PROCEDURE truncate_sam_pricing_tbl(
    x_errbuff     OUT VARCHAR2,
    x_retcode     OUT VARCHAR2
  ) 
  IS
  BEGIN
    g_program_unit := 'TRUNCATE_SAM_PRICING_TBL';    
    write_log('START '||g_program_unit);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxhz_party_sam_pricing';    
    fnd_file.put_line(fnd_file.output,'XXHZ_PARTY_SAM_PRICING successfully cleared.');
    write_log('END '||g_program_unit);
  EXCEPTION 
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Exception in '||g_program_unit||': '||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END truncate_sam_pricing_tbl;

END xxhz_party_sam_util_pkg;
/

SHOW ERRORS
