CREATE OR REPLACE PACKAGE BODY xxoe_reseller_order_rel_pkg AS

   g_log                      VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
   g_log_module               VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
   g_log_program_unit         VARCHAR2(100);

   g_duplicate_ct             NUMBER := 0;
   g_no_serial_ct             NUMBER := 0;
   g_return_ct                NUMBER := 0;
   g_invoice_only_ct          NUMBER := 0;
   g_loaded_ct                NUMBER := 0;
   g_no_reseller_ct           NUMBER := 0;
   g_return_error_ct          NUMBER := 0;
   g_pl_error_ct              NUMBER := 0;
   g_no_trx_ct                NUMBER := 0;

-- ---------------------------------------------------------------------------------------------
-- Name: XXOE_RESELLER_ORDER_REL_PKG
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This is a multi-purpose package used for pre-processing commissions for resellers.  Its
--          functionality is as follows
--
--          1. We've created a custom table called xxoe_reseller_order_rel table.  This table is
--             used to store invoiced order lines down to the serial number level.  Our intent is
--             to store only System items.  Based on the system items for a paticular reseller, we
--             determine commission percentages for standard materials order for those systems, since
--             reseller is not stored on the standard materials orders.  We've also built a form
--             top of this table, so that the users essentially have the ability to split commissions
--             (XXOERESELLORDRREL) on one line between multiple resellers, which is not possible in
--             Oracle.  See the design doc for full details.
--
--          2. Additionally, this package is used by the XXCN_RESELLER_STATEMENT XML Publisher report's
--             before and after report's triggers.  see before_report and after_report functions for
--             full details.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- 1.1  08/28/2014  MMAZANET    CHG0031576.  This was changed to accomodate commissions calculation.
--                              See the following procedure descriptions for further explanation.
--
--                              end_date_records
--                              process_return_credit_inv_only
--                              insert_xxoe_reseller_order_rel
--                              validate_resell_order_rel
--                              ins_xxoe_reseller_order_rel
--                              ins_xxoe_resell_order_rel_pub
--                              ins_xxoe_resell_order_rel_bulk
--                              upd_xxoe_resell_order_rel_pub
--                              upd_xxoe_reseller_order_rel
--
-- 1.2  09/24/2015  MMAZANET    Essentially re-wrote how systems are brought into the
--                              xxoe_reseller_order_rel table.  Initially, there were two methods
--                              for bringing data in.
--
--                              First, we automatically pulled in "system" data from OM.  Now,
--                              however, users have requested that they first export the data
--                              from OM (by running the XXOE_COMM_SYSTEM_PRE_LOAD XML report),
--                              make any necessary changes (there are only specific fields the user
--                              can change, then load the data into xxoe_resell_order_rel.  The
--                              loading of the data takes place in load_systems.
--
--                              Second, we had many iterations for a bulk load where users could
--                              manually enter system records.  I've gotten rid of that functionality
--                              and now manual records through the load_systems procedure as well.
--
--                              Finally, users also requested a way to extract existing data
--                              (by running the XXOE_COMM_SYSTEM_PRE_LOAD XML report) in
--                              xxoe_resell_order_rel, update it (there are only specific fields the user
--                              can change), and reload it.  That will as well be handled by
--                              load_systems.
--
-- 1.3  06/23/2016  DCHATTERJEE CHG0038832 - 1. Add new parameter p_load_type to procedure sync_interface_table and
--                                              In case of EXISTING load update the INVOICE_DATE and SERIAL_NUMBER
--                                              fields in the interface with data from the existing record
--                                           2. Modify procedure load_systems to handle update of existing records
-- 1.4  10/06/2017  DCHATTERJEE CHG0041334 - Add function get_reseller_stmt_msg to retrieve message for
--                              split system transactions between reseller and channel partner
-- 1.5  03/21/2019  Diptasurjya CHG0041777 - New Serial extract changes in before_system_report
-- 1.6  30/10/2019  Diptasurjya INC0173468 - validate_reseller_order_rel - Do not validate for commissions category if item is null
-- 1.7  12/04/2020  DCHATTERJEE CHG0047344 - New Logo and item commission category creation change
-- ---------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0034820.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg  VARCHAR2)
  IS
  BEGIN
    IF g_log = 'Y' AND 'xxoe.commissions_systems.xxoe_reseller_order_rel_pkg.'||g_log_program_unit LIKE LOWER(g_log_module) THEN
      fnd_file.put_line(fnd_file.log,p_msg);
    END IF;
  END write_log;

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to fnd_log_messages if 'FND: Debug Log Enabled' is set to Yes
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG00XXXXX.
-- ---------------------------------------------------------------------------------------------
PROCEDURE write_log_db(p_msg  VARCHAR2)
IS
BEGIN
  IF g_log = 'Y' AND 'xxoe.commissions_systems.xxoe_reseller_order_rel_pkg.'||g_log_program_unit LIKE LOWER(g_log_module) THEN
    fnd_log.STRING(
      log_level => fnd_log.LEVEL_UNEXPECTED,
      module    => 'xxoe.commissions_systems.xxoe_reseller_order_rel_pkg',
      message   => p_msg
    );
  END IF;
END write_log_db;


-- ---------------------------------------------------------------------------------------------
-- Purpose: Handles bursting for XXOERESELLORDRREL XML Pub report.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0034820.
-- ---------------------------------------------------------------------------------------------
   FUNCTION after_report
   RETURN BOOLEAN
   IS l_burst_request_id NUMBER;
   BEGIN
      write_log('START AFTER_REPORT');
      write_log('P_SEND_EMAIL: '||P_SEND_EMAIL);

      IF P_SEND_EMAIL = 'Y' THEN
         l_burst_request_id := fnd_request.submit_request (
                              application          => 'XDO',
                              program              => 'XDOBURSTREP',
                              argument1            => 'Y',
                              argument2            => FND_GLOBAL.CONC_REQUEST_ID
                           );
         IF l_burst_request_id IS NOT NULL THEN
            xxobjt_utl_debug_pkg.end_proc;
            RETURN TRUE;
         ELSE
            write_log('Bursting was unsuccessful');
            write_log('END AFTER_REPORT');
            RETURN FALSE;
         END IF;
      ELSE
         write_log('END AFTER_REPORT');
         RETURN TRUE;
      END IF;
   END after_report;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This is called from the before_report trigger on the XXOERESELLORDRREL XML
--          Publisher report.  This assists in getting current receivables by calling the
--          ar_get_customer_balance_pkg.ar_get_customer_balance package to populate the
--          ar_customer_balance_itf table, which is then queried in the XXOERESELLORDRREL XML
--          report
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- ---------------------------------------------------------------------------------------------
   FUNCTION before_report
   RETURN BOOLEAN
   IS
      CURSOR c_cn_recs
      IS
         SELECT DISTINCT
            hca.account_number
         ,  pv.vendor_name
               FROM
                  xxcn_reseller                 xr
               ,  xxcn_reseller_to_customer     xrc
               ,  cn_commission_headers_all     ccha
               ,  jtf_rs_salesreps              jrs
               ,  jtf_rs_resource_extns         jrre
               ,  ap_supplier_sites_all         assa
               ,  po_vendors                    pv
               ,  hz_cust_accounts_all          hca
               ,  hz_parties                    hp
               --,  ar_customer_balance_itf       acbi
               WHERE ccha.direct_salesrep_id       = jrs.salesrep_id
               AND   jrs.resource_id               = jrre.resource_id
               AND   jrre.category                 = 'SUPPLIER_CONTACT'
               AND   jrre.address_id               = assa.vendor_site_id
               AND   assa.vendor_id                = pv.vendor_id
               AND   pv.party_id                   = xr.reseller_id
               AND   xr.reseller_id                = xrc.reseller_id
               AND   SYSDATE                       BETWEEN NVL(xrc.start_date,TO_DATE('01011900','DDMMYYYY'))
                                                      AND NVL(xrc.end_date,TO_DATE('31124712','DDMMYYYY'))
               AND   xrc.customer_party_id         = hp.party_id
               AND   hp.party_id                   = hca.party_id;

      l_conc_request_id    NUMBER;
      l_set_of_books_id    ar_system_parameters.set_of_books_id%TYPE;
      l_location           VARCHAR2(100);
   BEGIN
      write_log('START BEFORE_REPORT');

      l_location        := 'Getting l_conc_request_id';
      l_conc_request_id := fnd_global.conc_request_id;
      write_log('l_conc_request_id: '||l_conc_request_id);

      l_location        := 'Getting l_set_of_books_id';

      SELECT set_of_books_id
      INTO l_set_of_books_id
      FROM ar_system_parameters_all
      WHERE org_id = fnd_global.org_id;

      write_log('l_set_of_books_id: '||l_set_of_books_id);
      write_log('fnd_global.org_id: '||fnd_global.org_id);

      -- ar_get_customer_balance would not populate ar_customer_balance_itf table without
      -- setting policy context
      mo_global.set_policy_context('S',fnd_global.org_id);

      FOR rec IN c_cn_recs LOOP
         l_location        := 'Getting open balance for customer '||rec.account_number;
         write_log('account_number: '||rec.account_number);

         BEGIN
            -- populate ar_customer_balance_itf table with request_id as the key
            ar_get_customer_balance_pkg.ar_get_customer_balance(
               p_request_id                     => l_conc_request_id
            ,  p_set_of_books_id                => l_set_of_books_id
            ,  p_as_of_date                     => SYSDATE
            ,  p_customer_name_from             => NULL
            ,  p_customer_name_to               => NULL
            ,  p_customer_number_low            => rec.account_number
            ,  p_customer_number_high           => rec.account_number
            ,  p_currency                       => P_CURRENCY
            ,  p_min_invoice_balance            => TO_NUMBER(NULL)
            ,  p_min_open_balance               => TO_NUMBER(NULL)
            ,  p_account_credits                => P_INCLUDE_ON_ACCOUNT_CREDITS
            ,  p_account_receipts               => P_INCLUDE_ON_ACCOUNT_RECEIPTS
            ,  p_unapp_receipts                 => P_INCLUDE_ON_UNAPPLIED_RCPTS
            ,  p_uncleared_receipts             => P_INCLUDE_ON_UNCLEARED_RCPTS
            ,  p_ref_no                         => NULL
            ,  p_debug_flag                     => P_DEBUG_GET_AR_BAL
            ,  p_trace_flag                     => P_TRACE_GET_AR_BAL
            );

         -- Program throws exception when no data is available for a customer.  I do
         -- not want to raise an error in this case, so exception is set to NULL.
         EXCEPTION
            WHEN OTHERS THEN
               write_log('No data available for customer');
               NULL;
         END;
      END LOOP;

      write_log('END BEFORE_REPORT');
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_error := 'Error occurred '||l_location||': '||SQLERRM;
         write_log(p_error);
         RETURN TRUE;
   END before_report;

------------------------------------------------------------------------------------------------
-- ***************** Code Below For Loading SYSTEM records *************************************
------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------
-- Purpose: Called from XXOE_COMM_SYSTEM_PRE_LOAD.xml XML data source for loading interface
--          table prior to generating csv, in the event that the p_type = 'NEW_ORDER_DELIVERY'.
--          This table is loaded, then XXOE_COMM_SYSTEM_PRE_LOAD.xml reports off of this table.
--          The report includes the interface_id, can be saved as a csv, and can be reloaded
--          by running the XX: Commissions OE System Load concurrent program.  This will load
--          records from csv and link them back to the records loaded below on the interfac_id.
--          I do this to avoid having to show all of the ID fields in the report.
--
--          If p_type = 'EXISTING', then this function simply returns TRUE.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/14/2015  MMAZANET    Initial Creation for CHG0034820.
-- 1.1  03/21/2019  Diptasurjya CHG0041777 - New Serial extract changes
-- ---------------------------------------------------------------------------------------------
  FUNCTION before_system_report
  RETURN BOOLEAN
  IS
  BEGIN
    write_log_db('START INS_XXOE_RESELLER_ORD_REL_INTF');
    write_log_db('P_AR_DATE_FROM: '||P_AR_DATE_FROM);
    write_log_db('P_AR_DATE_TO: '||P_AR_DATE_TO);
    write_log_db('P_ORGANIZATION_ID: '||P_ORGANIZATION_ID);
    write_log_db('P_TYPE: '||P_TYPE);

    -- No load should take place when the report is of this type
    IF p_type = 'EXISTING' THEN
      RETURN TRUE;
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxoe_reseller_order_rel_intf';

    write_log_db('INSERTING INTO ins_xxoe_reseller_ord_rel_intf...');

    INSERT INTO xxoe_reseller_order_rel_intf(
      interface_id,
      load_status,
      reseller_order_rel_id,
      order_line_id,
      customer_trx_line_id,
      invoice_date,
      order_number,
      order_line_number,
      --order_line_type_category,    -- come back to -- CHG0041777 commented
      delivery_detail_id,
      serial_number,
      ship_to_cust_account_id,
      reseller_id,
      inventory_item_id,
      revenue_pct,
      org_id,
      start_date,
      source_id,
      source_name,
      notes,
      order_source_reference,
      batch_name,
      force_update,
      process_flag,
      request_id
    )
    -- Materializing this view using WITH clause dramatically improves performance
    WITH ra AS(
      SELECT /*+ MATERIALIZE */
        xrnv.*
      FROM xxar_revenue_nash_v               xrnv
      WHERE xrnv.trx_date      BETWEEN fnd_date.canonical_to_date(P_AR_DATE_FROM) AND fnd_date.canonical_to_date(P_AR_DATE_TO)
    )
    SELECT
      xxobjt.xxoe_reseller_order_rel_intf_s.NEXTVAL     interface_id,
      'PENDING'                                         load_status,
      NULL                                              reseller_order_rel_id,
      ool.line_id                                       order_line_id,
      xrnv.customer_trx_line_id                         customer_trx_line_id,
      xrnv.trx_date                                     customer_trx_date,
      ooh.order_number                                  order_number,
      ool.line_number                                   order_line_number,
      --flvv_order_type.lookup_type                       order_line_type_category, -- CHG0041777 commented
      wsn.delivery_detail_id                            delivery_detail_id,
      wsn.fm_serial_number                              serial_number,
      hca_ship.cust_account_id                          ship_to_cust_account_id,
      TO_NUMBER(ooh.attribute10)                        reseller_id,
      ool.inventory_item_id                             inventory_item_id,
      100                                               revenue_pct,
      P_ORGANIZATION_ID                                 org_id,
      SYSDATE                                           start_date,
      wsn.delivery_detail_id                            source_id,
      'ORDER_DELIVERY'                                  source_name,
      NULL                                              notes,
      ooh_ref.order_number                              order_source_reference,
      TO_CHAR(FND_GLOBAL.CONC_REQUEST_ID)               batch_name,
      'N'                                               process_flag,
      'N'                                               force_update,
      FND_GLOBAL.CONC_REQUEST_ID                        request_id
    FROM
      ra                              xrnv,
    /* item... */
     (SELECT
        msib.inventory_item_id          item_id,
        msib.segment1                   item_number,
        msib.description                item_description,
        msib.organization_id            item_org_id
      FROM
        mtl_system_items_b              msib,
        mtl_parameters                  mp,
        fnd_lookup_values_vl            flvv
      WHERE msib.organization_id    = mp.organization_id
      AND   msib.organization_id    = mp.master_organization_id
      -- Join to exclude certain items
      AND   msib.item_type                      = flvv.lookup_code
      AND   flvv.lookup_type                    = 'ITEM_TYPE'
      AND   flvv.enabled_flag                   = 'Y'
      AND   NOT EXISTS                         (SELECT null -- item exclusions
                                                FROM fnd_lookup_values_vl   flvv_item_type_excl
                                                WHERE flvv_item_type_excl.lookup_type  = 'XXCN_SYS_ITEM_EXCLUSION'
                                                AND   flvv_item_type_excl.enabled_flag = 'Y'
                                                AND   flvv_item_type_excl.description  = flvv.meaning)
     )                                  item,
    /* ...item */
    -- Get order info
      oe_order_headers_all             ooh,
      oe_transaction_types_tl          ottt_line,
      oe_transaction_types_tl          ottt_header,
      oe_order_lines_all               ool,
      oe_order_headers_all             ooh_ref,
    -- Get reseller
      jtf_rs_resource_extns            jrre,
    -- Get shipping/serial number
      wsh_delivery_details             wdd,
      wsh_delivery_assignments         wdda,
      wsh_new_deliveries               wd,
      wsh_serial_numbers               wsn,
    -- get reseller off order
      fnd_descr_flex_col_usage_vl      fdfcuv,
      fnd_flex_value_sets              ffvs,
      --fnd_lookup_values_vl             flvv_order_type,
    -- Get customer info
      hz_cust_accounts_all             hca,
      hz_parties                       hp,
    -- Get Ship To
      hz_parties                      hp_ship,
      hz_cust_accounts_all            hca_ship,
      hz_cust_site_uses_all           hcsua_ship,
      hz_cust_acct_sites_all          hcasa_ship
    -- Join to nash revenue
    WHERE xrnv.order_line_id                  = TO_CHAR(nvl(ool.link_to_line_id,ool.line_id))  -- CHG0041777 check for link_to_line_id also to handle PTO invoicing
    AND   ool.inventory_item_id               = item.item_id
    -- Get order info
    AND   ooh.header_id                       = ool.header_id
    AND   ool.source_document_id              = ooh_ref.header_id (+)
    AND   ooh.order_type_id                   = ottt_header.transaction_type_id
    AND   ottt_header.language                = userenv('LANG')
    -- Join to get only specific header types
                                                -- Order type and line type are concatenated together in the description
                                                -- field by ~
    --AND   ottt_header.name                    = SUBSTR(flvv_order_type.description,1,INSTR(flvv_order_type.description,'~')-1) -- CHG0041777 commented
    AND   ool.line_type_id                    = ottt_line.transaction_type_id
    AND   ottt_line.language                  = userenv('LANG')
    -- Join to get only specific line types
                                                -- Order type and line type are concatenated together in the description
                                                -- field by ~
    --AND   ottt_line.name                      = SUBSTR(flvv_order_type.description,INSTR(flvv_order_type.description,'~')+1,LENGTH(flvv_order_type.description)) -- CHG0041777 commented
    --AND   flvv_order_type.lookup_type         IN ('XXCN_SYS_ORDER_CREDIT','XXCN_SYS_ORDER_STANDARD','XXCN_SYS_INVOICE_ONLY') -- CHG0041777 commented
    --AND   flvv_order_type.enabled_flag        = 'Y' -- CHG0041777 commented
    -- Join to reseller
    AND   TO_NUMBER(ooh.attribute10)          = jrre.resource_id (+)
    AND   'SUPPLIER_CONTACT'                  = jrre.category (+)
    -- Join to shipping for serial numbers
    AND   ool.line_id                         = wdd.source_line_id (+)
    AND   'OE'                                = wdd.source_code (+)
    AND   wdd.delivery_detail_id              = wsn.delivery_detail_id (+)
    AND   wdd.delivery_detail_id              = wdda.delivery_detail_id (+)
    AND   wdda.delivery_id                    = wd.delivery_id (+)
    -- Join to get any order contexts using ATTRIBUTE10 for reseller
    AND   ottt_header.name                    = fdfcuv.descriptive_flex_context_code (+)
    AND   'OE_HEADER_ATTRIBUTES'              = fdfcuv.descriptive_flexfield_name (+)
    AND   'ATTRIBUTE10'                       = fdfcuv.application_column_name (+)
    AND   fdfcuv.flex_value_set_id            = ffvs.flex_value_set_id (+)
    AND   'XXCRM_RESELLER_RESOURCE_NAME'      = ffvs.flex_value_set_name (+)
    -- Get ship to info
    AND   ooh.ship_to_org_id                  = hcsua_ship.site_use_id (+)
    AND   hcsua_ship.cust_acct_site_id        = hcasa_ship.cust_acct_site_id(+)
    AND   hcasa_ship.cust_account_id          = hca_ship.cust_account_id (+)
    AND   hca_ship.party_id                   = hp_ship.party_id (+)
    -- Get sold to info
    AND   ooh.sold_to_org_id                  = hca.cust_account_id
    AND   hca.party_id                        = hp.party_id;

    write_log_db(SQL%ROWCOUNT||' records inserted into ins_xxoe_reseller_ord_rel_intf.');

    write_log_db('END INS_XXOE_RESELLER_ORD_REL_INTF');
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      --p_error := 'Error occurred '||l_location||': '||SQLERRM;
      write_log_db('Error occurred in before_system_report: '||SQLERRM);
      RETURN FALSE;
  END before_system_report;

-- ---------------------------------------------------------------------------------------------
-- Currently OBSOLETE, but if return/credit functionality is reimplemented, this may
-- be valuable.
--
-- Purpose: End dates matching serial number records on xxoe_reseller_order_rel.
--          Currently OBSOLETE, but if return/credit functionality is reimplemented, this may
--          be valuable.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042. (still in process)
-- ---------------------------------------------------------------------------------------------
  PROCEDURE end_date_records(
    p_credit_serial_number  IN    VARCHAR2,
    p_return_credit_row     IN    g_reseller_order_rel_type,
    x_return_status         OUT   VARCHAR2,
    x_return_msg            OUT   VARCHAR2
  )
  IS
    -- Record(s) which return is against
    CURSOR c_return_credit
    IS
      SELECT
        xror.serial_number,
        ooh.order_number,
        xror.order_line_id,
        ool.line_number,
        xror.reseller_order_rel_id
      FROM
        xxoe_reseller_order_rel    xror,
        oe_order_headers_all       ooh,        oe_order_lines_all         ool
      WHERE xror.serial_number               = p_credit_serial_number
      AND   xror.order_line_type_category    = 'XXCN_SYS_ORDER_STANDARD'
      AND   xror.order_line_id               = ool.line_id
      AND   ool.header_id                    = ooh.header_id
      FOR UPDATE OF xror.end_date NOWAIT;

    e_no_match           EXCEPTION;
    e_lock               EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_lock, -54);

    l_count                    NUMBER := 0;
    l_return_credit_row        g_reseller_order_rel_type;
    l_reseller_order_rel_id    xxoe_reseller_order_rel.reseller_order_rel_id%TYPE;
  BEGIN
    write_log('START END_DATE_RECORDS');

    FOR rec IN c_return_credit LOOP
      l_reseller_order_rel_id := rec.reseller_order_rel_id;
      write_log('End dating xxoe_reseller_order_rel.reseller_order_rel_id '||rec.reseller_order_rel_id);

      l_count := l_count + 1;

      l_return_credit_row.system_rec.reseller_order_rel_id := rec.reseller_order_rel_id;
      l_return_credit_row.system_rec.order_line_id         := rec.order_line_id;
      l_return_credit_row.system_rec.serial_number         := rec.serial_number;
      l_return_credit_row.system_rec.order_number          := rec.order_number;
      l_return_credit_row.system_rec.order_line_number     := rec.line_number;

      UPDATE xxoe_reseller_order_rel
      SET
         end_date          = SYSDATE
      ,  last_updated_by   = TO_NUMBER(fnd_profile.value('USER_ID'))
      ,  last_update_date  = SYSDATE
      ,  last_update_login = TO_NUMBER(fnd_profile.value('LOGIN_ID'))
      WHERE CURRENT OF c_return_credit;

    END LOOP;

    -- If no matching serial number found
    IF l_count = 0 THEN
      RAISE e_no_match;
    END IF;

    x_return_status := 'S';
    write_log('END END_DATE_RECORDS');
  EXCEPTION
    WHEN e_no_match THEN
      x_return_status   := 'E';
      x_return_msg      := 'Error: No matching record found for return/credit';
      write_log(x_return_msg);
    WHEN e_lock THEN
      x_return_status   := 'E';
      x_return_msg      := 'Error: Record Locked ';
      write_log(x_return_msg);
    WHEN OTHERS THEN
      x_return_status   := 'E';
      x_return_msg      := 'Error: in end_date_records '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      write_log(x_return_msg);
  END end_date_records;


-- ---------------------------------------------------------------------------------------------
-- Currently OBSOLETE, but if return/credit functionality is reimplemented, this may
-- be valuable.
--
-- Purpose: This procedure is used to process credits and invoice only orders.  Essentially, when a
--          credit comes in, we need to look for the original order (by serial number) and end date
--          that item so we don't account for it twice on the xxoe_reseller_order_rel table.
--
--          For invoice only orders, we need to find the serial number attached to the original
--          order, and pull the serial number from that order.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042 (still in process)
-- ---------------------------------------------------------------------------------------------
  PROCEDURE process_return_credit_inv_only(
   p_return_credit_row  IN    g_reseller_order_rel_type,
   x_serial_number      OUT   VARCHAR2,
   x_return_status      OUT   VARCHAR2,
   x_return_msg         OUT   VARCHAR2
  )
  IS
     CURSOR c_returns
     IS
        SELECT
           wsn.fm_serial_number    serial_number
        ,  ool.line_id             order_line_id
        FROM
           oe_order_lines_all               ool
        ,  oe_order_lines_all               ool_src
        ,  wsh_delivery_details             wdd
        ,  wsh_serial_numbers               wsn
        WHERE ool_src.line_id                     = wdd.source_line_id
        AND   'OE'                                = wdd.source_code
        AND   wdd.delivery_detail_id              = wsn.delivery_detail_id
        AND   ool.source_document_line_id         = ool_src.line_id
        AND   ool.line_id                         = p_return_credit_row.system_rec.order_line_id;

     --l_credited_row  xxoe_reseller_order_rel.reseller_order_rel_id%TYPE;
     e_error        EXCEPTION;
     l_count        NUMBER := 0;
  BEGIN
     write_log('START PROCESS_RETURN_CREDIT_INV_ONLY');
     write_log('*** Begin processing credit/invoice only for order line id '||p_return_credit_row.system_rec.order_line_id||' ***');
     write_log(''||p_return_credit_row.system_rec.order_line_id||' ***');

     --IF p_return_credit_row.system_rec.order_line_type_category = 'XXCN_SYS_ORDER_RETURN' THEN
        FOR rec IN c_returns LOOP

           IF p_return_credit_row.system_rec.order_line_type_category = 'XXCN_SYS_ORDER_CREDIT' THEN
              --credited_row.order_line_id := rec.order_line_id;
              --credited_row.serial_number := rec.serial_number;
              write_log('Serial Number of records to End Date '||rec.serial_number);
              l_count := l_count + 1;
              end_date_records(
                p_credit_serial_number          => rec.serial_number,
                p_return_credit_row             => p_return_credit_row,
                x_return_status                 => x_return_status,
                x_return_msg                    => x_return_msg
              );
           ELSIF p_return_credit_row.system_rec.order_line_type_category = 'XXCN_SYS_INVOICE_ONLY' THEN
              x_serial_number   := rec.serial_number;
              x_return_status   := 'S';
           END IF;

           IF x_return_status <> 'S' THEN
              RAISE e_error;
           END IF;
        END LOOP;
        IF l_count = 0 THEN
           x_return_msg := 'Error: No Source doc was defined for credit/return/invoice only.';
           RAISE e_error;
        END IF;
     x_return_status := 'S';
     write_log('END PROCESS_RETURN_CREDIT_INV_ONLY');
  EXCEPTION
     WHEN e_error THEN
        x_return_status   := 'E';
        --x_return_msg      := 'Error: in process_return_credit '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log(x_return_msg);
     WHEN OTHERS THEN
        x_return_status   := 'E';
        x_return_msg      := 'Error: in process_return_credit '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log(x_return_msg);
  END process_return_credit_inv_only;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Inserts records into xxoe_reseller_order_rel table.
--          NOTE: All inserts should be done by calling the ins_xxoe_resell_order_rel_pub
--          procedure which performs validations.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE insert_xxoe_reseller_order_rel(
    p_xxoe_reseller_order_rel     IN OUT   g_reseller_order_rel_type,
    x_return_message              OUT      VARCHAR2,
    x_return_status               OUT      VARCHAR2
  )
  IS
     l_request_id            NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
     l_reseller_order_rel_id xxoe_reseller_order_rel.reseller_order_rel_id%TYPE;
  BEGIN
     write_log('START INSERT_XXOE_RESELLER_ORDER_REL');

     SELECT xxoe_reseller_order_rel_s.NEXTVAL
     INTO l_reseller_order_rel_id
     FROM DUAL;

     p_xxoe_reseller_order_rel.system_rec.reseller_order_rel_id := l_reseller_order_rel_id;

     write_log('l_reseller_order_rel_id: '||l_reseller_order_rel_id);

     -- Load xxoe_reseller_order_rel
     INSERT INTO xxoe_reseller_order_rel(
        reseller_order_rel_id
     ,  related_reseller_order_rel_id
     ,  order_line_id
     ,  customer_trx_line_id
     ,  order_line_type_category
     ,  invoice_date
     ,  delivery_detail_id
     ,  ship_to_cust_account_id
     ,  reseller_id
     ,  inventory_item_id
     ,  serial_number
     ,  revenue_pct
     ,  org_id
     ,  start_date
     ,  end_date
     ,  source_name
     ,  source_id
     ,  notes
     ,  request_id
     ,  manual_entry_flag
     ,  creation_action
     ,  creation_date
     ,  created_by
     ,  last_update_date
     ,  last_updated_by
     ,  last_update_login
     )
     VALUES(
        p_xxoe_reseller_order_rel.system_rec.reseller_order_rel_id
     ,  p_xxoe_reseller_order_rel.system_rec.related_reseller_order_rel_id
     ,  p_xxoe_reseller_order_rel.system_rec.order_line_id
     ,  p_xxoe_reseller_order_rel.system_rec.customer_trx_line_id
     ,  p_xxoe_reseller_order_rel.system_rec.order_line_type_category
     ,  p_xxoe_reseller_order_rel.system_rec.invoice_date
     ,  p_xxoe_reseller_order_rel.system_rec.delivery_detail_id
     ,  p_xxoe_reseller_order_rel.system_rec.ship_to_cust_account_id
     ,  p_xxoe_reseller_order_rel.system_rec.reseller_id
     ,  p_xxoe_reseller_order_rel.system_rec.inventory_item_id
     ,  p_xxoe_reseller_order_rel.system_rec.serial_number
     ,  p_xxoe_reseller_order_rel.system_rec.revenue_pct
     ,  p_xxoe_reseller_order_rel.system_rec.org_id
     ,  NVL(p_xxoe_reseller_order_rel.system_rec.start_date,SYSDATE)
     ,  p_xxoe_reseller_order_rel.system_rec.end_date
     ,  TRIM(p_xxoe_reseller_order_rel.system_rec.source_name)
     ,  p_xxoe_reseller_order_rel.system_rec.source_id
     ,  p_xxoe_reseller_order_rel.system_rec.notes
     ,  l_request_id
     ,  NULL
     ,  p_xxoe_reseller_order_rel.system_rec.creation_action
     ,  SYSDATE
     ,  TO_NUMBER(fnd_profile.value('USER_ID'))
     ,  SYSDATE
     ,  TO_NUMBER(fnd_profile.value('USER_ID'))
     ,  TO_NUMBER(fnd_profile.value('LOGIN_ID'))
     );

     x_return_status      := 'S';
     write_log('END INSERT_XXOE_RESELLER_ORDER_REL');
  EXCEPTION
     WHEN OTHERS THEN
        x_return_message             := 'ERROR occurred in insert_xxoe_reseller_order_rel: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        x_return_status   := 'E';
        write_log(x_return_message);
  END insert_xxoe_reseller_order_rel;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Tests for a revenue_pct exceeding 100 for the same serial number.  Serial numbers
--          can be split into two lines and essentially duplicated, as long as the revenue_pct
--          equals 100. It's important to note that this is checking for records that are active
--          during the same period with the same serial number.  We do not want to consider
--          records end-dated prior to load record's start_date.  Also, since we are not allowing
--          future dating (start_date in the future), we do not need to consider records in the future.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/15/2015  MMAZANET    CHG0034820.  Added date constraint in c_duplicates so inactive systems are not
--                              factored.  Also removed obsolete code.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE is_duplicate_serial_number(
    p_load                  IN    g_reseller_order_rel_type,
    x_duplicate_serial_flag OUT   VARCHAR2,
    x_return_message        OUT   VARCHAR2,
    x_return_status         OUT   VARCHAR2
  )
  IS
     CURSOR c_duplicates
     IS
        SELECT
           ooh.order_number,
           ool.line_number,
           xror.source_name,
           xror.source_id,
           SUM(revenue_pct) OVER (PARTITION BY serial_number)  rev_pct_total
        FROM
           xxoe_reseller_order_rel    xror,
           oe_order_headers_all       ooh,
           oe_order_lines_all         ool
        WHERE xror.order_line_id               = ool.line_id (+)
        AND   ool.header_id                    = ooh.header_id (+)
        AND   xror.order_line_type_category    IN ('XXCN_SYS_ORDER_STANDARD','MANUAL','MANUAL_SHIP_ACCOUNT')
        AND   xror.serial_number               = p_load.system_rec.serial_number
        -- CHG0034820
        -- Check for matching system serial numbers on active records.  End-dated are inactive
        AND   p_load.system_rec.start_date     < NVL(xror.end_date,'31-DEC-4712')
        -- Exclude update record from this list as it is factored in below
        AND   xror.reseller_order_rel_id       <> NVL(p_load.system_rec.reseller_order_rel_id,-9);


     l_existing_record_flag VARCHAR2(1) := 'N';
  BEGIN
     write_log('START IS_DUPLICATE_SERIAL_NUMBER');
     write_log('p_serial_number: '||p_load.system_rec.serial_number);
     write_log('p_revenue_pct: '||NVL(p_load.system_rec.revenue_pct,0));

     IF p_load.system_rec.source_name IN ('ORDER_DELIVERY','MANUAL_SHIP_ACCOUNT') THEN
       FOR rec IN c_duplicates LOOP
         write_log('rev_pct_total: '||TO_CHAR(rec.rev_pct_total + NVL(p_load.system_rec.revenue_pct,0)));
         -- If record exists
         l_existing_record_flag := 'Y';
         -- Check the total revenue in DB with the revenue for the current load record to ensure it equals 100
         IF (rec.rev_pct_total + NVL(p_load.system_rec.revenue_pct,0)) <> 100 THEN
            x_return_message := x_return_message||'Error: Duplicate Serial Number '||p_load.system_rec.serial_number||' Revenue PCT Total: '||TO_CHAR(rec.rev_pct_total + NVL(p_load.system_rec.revenue_pct,0)
                                ||' already exists for timeframe.  NOTE - If start date is null, invoice date is used');
            write_log('x_return_message: '||SUBSTR(x_return_message,1,500));
            EXIT;
         END IF;
       END LOOP;
     END IF;

     -- If no matching records exist in c_duplicate cursors, check total for serial number for the load
     IF l_existing_record_flag = 'N' THEN
        IF p_load.total_revenue_pct <> 100 THEN
           x_return_message := 'Error: Revenue total must be 100 percent';
           write_log('x_return_message: '||SUBSTR(x_return_message,1,500));
        END IF;
     END IF;

     IF x_return_message IS NOT NULL THEN
        x_duplicate_serial_flag := 'Y';
        x_return_message                   := x_return_message;
     ELSE
        x_duplicate_serial_flag := 'N';
     END IF;

     x_return_status   := 'S';
     write_log('END IS_DUPLICATE_SERIAL_NUMBER');
  EXCEPTION
     WHEN OTHERS THEN
        x_return_message             := 'Error occurred in is_duplicate_serial_number: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log(x_return_message);
        x_return_status   := 'E';
  END is_duplicate_serial_number;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This is intended to validate dates for records being inserted/updated
--          in xxoe_reseller_order_rel table
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/16/2015  MMAZANET    CHG0034820.  Changed for new system load method
-- ---------------------------------------------------------------------------------------------
   PROCEDURE validate_dates(
     p_load            IN   g_reseller_order_rel_type,
     x_return_message  OUT  VARCHAR2,
     x_return_status   OUT  VARCHAR2
   )
   IS
      e_skip                     EXCEPTION;
   BEGIN
      write_log('START VALIDATE_RESELL_ORDER_REL');

      IF p_load.system_rec.start_date > SYSDATE THEN
        x_return_message  := 'Error: Start Date Can not be in the future';
        RAISE e_skip;
      END IF;

      IF p_load.system_rec.end_date > SYSDATE THEN
        x_return_message  := 'Error: End Date Can not be in the future';
        RAISE e_skip;
      END IF;

      IF NVL(p_load.system_rec.end_date,'31-DEC-4712') <= p_load.system_rec.start_date THEN
        x_return_message  := 'Error: Start Date must be before End Date';
        RAISE e_skip;
      END IF;

      x_return_status := fnd_api.g_ret_sts_success;
      write_log('END VALIDATE_DATES');
   EXCEPTION
      WHEN e_skip THEN
         write_log(x_return_message);
         x_return_status := 'E';
      WHEN OTHERS THEN
         write_log('Error occurred in validate_dates: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
         x_return_status := 'E';
   END validate_dates;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This is intended to validate records we are adding to the xxoe_reseller_order_rel table
--
-- Parameters: p_load
--                Brings in all incoming fields for validation.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/16/2015  MMAZANET    CHG0034820.  Changed for new system load method
-- 1.2  05/15/2019  Diptasurjya CHG0041777 - validate for presence of commissions category assignment
-- 1.3  30/10/2019  Diptasurjya INC0173468 - Do not validate for commissions category if item is null
-- ---------------------------------------------------------------------------------------------
   PROCEDURE validate_resell_order_rel(
     p_load            IN   g_reseller_order_rel_type,
     p_load_type       IN   VARCHAR2,
     x_return_message  OUT  VARCHAR2,
     x_return_status   OUT  VARCHAR2
   )
   IS
     e_skip                     EXCEPTION;
     e_error                    EXCEPTION;

     l_duplicate_serial_flag    VARCHAR2(1);
     l_return_status            VARCHAR2(1);
     l_return_message           VARCHAR2(500);
     l_source_id                NUMBER;

     l_item_comm_category       varchar2(1000);  -- CHG0041777 add

     l_dummy                    VARCHAR2(250);
   BEGIN
      write_log('START VALIDATE_RESELL_ORDER_REL');
      -- initialize
      l_duplicate_serial_flag := 'N';

      -- Check For invoice_date
      IF p_load.system_rec.invoice_date IS NULL THEN
        x_return_message  := 'Error: No Invoice Date';
        RAISE e_error;
      END IF;

      IF p_load.system_rec.reseller_id IS NULL THEN
        x_return_message  := 'Error: No Reseller';
        RAISE e_error;
      END IF;

      validate_dates(
        p_load            => p_load,
        x_return_message  => x_return_message,
        x_return_status   => l_return_status
      );

      write_log('validate_dates return status: '||l_return_status);

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      IF p_load.system_rec.serial_number IS NULL THEN
        x_return_message  := 'Error: No Serial Number';
        g_no_serial_ct    := g_no_serial_ct + 1;
        RAISE e_error;
      END IF;

      is_duplicate_serial_number(
        p_load                  => p_load,
        x_duplicate_serial_flag => l_duplicate_serial_flag,
        x_return_status         => l_return_status,
        x_return_message        => x_return_message
      );


      IF l_duplicate_serial_flag = 'Y' THEN
         g_duplicate_ct    := g_duplicate_ct + 1;
         RAISE e_error;
      END IF;

      IF l_return_status <> 'S' THEN
         RAISE e_error;
      END IF;



      -- CHG0041777 - start validate presence of commissions category assignment
      if p_load.system_rec.inventory_item_id is not null then -- INC0173468 check this validation for non-null item ID only
        begin
          SELECT micv.CATEGORY_CONCAT_SEGS
            INTO l_item_comm_category
            FROM
              mtl_item_categories_v   micv
            WHERE micv.category_set_name  = 'Commissions'
            AND   micv.organization_id    = xxinv_utils_pkg.get_master_organization_id
            AND   micv.inventory_item_id  = p_load.system_rec.inventory_item_id;
        exception when no_data_found then
          x_return_message := 'Error: Item does not have a valid commissions category assigned.';
          RAISE e_error;
        end;
      end if;
      -- CHG0041777 end

      -- Validations above apply to INSERTS/UPDATES
      IF p_load_type = 'EXISTING' THEN
        RAISE e_skip;
      END IF;
      -- Validations below only apply to INSERTS

      BEGIN
         SELECT lookup_code
         INTO l_dummy
         FROM fnd_lookup_values_vl
         WHERE lookup_type    = 'XXCN_SYS_SOURCES'
         AND   lookup_code    = p_load.system_rec.source_name
         AND   enabled_flag   = 'Y';

         l_dummy := NULL;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            x_return_message := 'Error: Source is invalid.  See XXCN_SYS_SOURCES lookup for valid sources.';
            RAISE e_error;
         WHEN OTHERS THEN
            x_return_message := 'Error Validating source_name: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
            RAISE e_error;
      END;

      IF p_load.total_revenue_pct <> 100 THEN
         x_return_message  := 'Error: Total revenue_pct of records to load must equal 100 percent';
         g_no_trx_ct       := g_no_trx_ct + 1;
         RAISE e_error;
      END IF;

      -- Check For customer_trx_line_id
      IF p_load.system_rec.order_line_type_category = 'XXCN_SYS_ORDER_STANDARD'
         AND p_load.system_rec.customer_trx_line_id IS NULL THEN
         x_return_message   := 'Error: No customer_trx_line_id';
         g_no_trx_ct        := g_no_trx_ct + 1;
         RAISE e_error;
      END IF;

      -- Checks the total revenue, which is by serial number, in the load file.  This can't exceed
      -- 100.  It could be less in the case we have an existing record in the DB < 100.
      IF NVL(p_load.total_revenue_pct,0) > 100 THEN
        x_return_message  := 'Error: Revenue Percent can not exceed 100';
        g_duplicate_ct    := g_duplicate_ct + 1;
        RAISE e_error;
      END IF;

      x_return_status := fnd_api.g_ret_sts_success;
      write_log('END VALIDATE_RESELL_ORDER_REL');
   EXCEPTION
     WHEN e_skip THEN
       x_return_status := fnd_api.g_ret_sts_success;
     WHEN e_error THEN
       write_log(x_return_message);
       x_return_status := fnd_api.g_ret_sts_error;
     WHEN OTHERS THEN
       write_log('Error occurred in validate_resell_order_rel: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
       x_return_status := fnd_api.g_ret_sts_error;
   END validate_resell_order_rel;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure is only called for new ORDER_DELIVERY (OM Sourced systems) records.
--          System data is initially loaded into xxoe_reseller_order_rel_intf when before_system_report
--          is called from XXOE_COMM_SYSTEM_PRE_LOAD XML report.  Users can take the output of that
--          report, modify select existing fields, save as a csv, and reload with the 'XX: Commissions
--          OE System Load' program.  The csv contains interface_id, which allows us to link from
--          what's in the csv to the records in xxoe_reseller_order_rel_intf.  Records loaded through
--          the csv contain a process_flag = 'C'.  We loop through these records looking for a matching
--          record in the interface table.  When we find one, the UPDATE in the code below is executed.
--          Notice that the process_flag for the record in xxoe_reseller_order_rel_intf is set to 'Y'.
--          This indicates to the load_systems procedure that this record is eligible for processing
--          for insert into xxoe_reseller_order_rel table.  Basically, if the record in
--          xxoe_reseller_order_rel_intf was not uploaded through the csv, it will not be processed.
--
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name          Description
-- 1.0  03/10/2015  MMAZANET      CHG0034820. Initial Creation
-- 1.1  06/23/2016  DCHATTERJEE   CHG0038832 - Add new parameter p_load_type
--                                             In case of EXISTING load update the INVOICE_DATE and
--                                             SERIAL_NUMBER fields in the interface with data from the existing record.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE sync_interface_table(
    p_load_type       IN VARCHAR2,  -- CHG0038832 - Dipta added new parameter
    p_batch_name      IN VARCHAR2,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2
  )
  IS
    -- Look for any records loaded through the load_system program which will have a process_status = 'C'
    CURSOR c_chg
    IS
      SELECT
        interface_id,
        reseller_name,
        ship_to_cust_account_number,
        invoice_date,
        revenue_pct,
        start_date,
        end_date,
        notes
      FROM
        xxoe_reseller_order_rel_intf
      WHERE process_flag        = 'C';


  BEGIN
    write_log('START SYNC_INTERFACE_TABLE');
    write_log('p_batch_name: '||p_batch_name);

    IF nvl(p_load_type,'N') <> 'EXISTING' then -- CHG0038832 - Dipta
      FOR rec IN c_chg LOOP
        write_log('interface_id: '||rec.interface_id);
        write_log('ship_to_cust_account_number: '||rec.ship_to_cust_account_number);
        write_log('reseller_name: '||rec.reseller_name);

        -- Update any records in the interface that match the records from the c_chg cursor
        UPDATE xxoe_reseller_order_rel_intf  xrori
        SET
          xrori.ship_to_cust_account_number   = rec.ship_to_cust_account_number,
          -- If ship to customer has changed, ship_to_cust_chg_flag is set to Y
          -- so we know to look up the new ship_to_cust_account_id
          xrori.ship_to_cust_chg_flag         = DECODE(rec.ship_to_cust_account_number
                                                , NULL, 'N'
                                                , xrori.ship_to_cust_account_number, 'N'
                                                , 'Y'),
          xrori.reseller_name                 = rec.reseller_name,
          -- If reseller has changed, reseller_chg_flag is set to Y
          -- so we know to look up the new reseller_id
          xrori.reseller_chg_flag             = DECODE(rec.reseller_name
                                                , NULL, 'N'
                                                , xrori.reseller_name, 'N'
                                                , 'Y'),
          -- If invoice date is changed, then set to the new value, otherwise keep the
          -- original value
          xrori.invoice_date                  = DECODE(rec.invoice_date
                                                , NULL, xrori.invoice_date
                                                , rec.invoice_date),
          xrori.revenue_pct                   = rec.revenue_pct,
          xrori.start_date                    = rec.start_date,
          xrori.end_date                      = rec.end_date,
          xrori.notes                         = rec.notes,
          xrori.process_flag                  = 'Y'
        WHERE xrori.interface_id            = rec.interface_id
        AND   NVL(xrori.process_flag,'N')   = 'N'
        AND   xrori.batch_name              = p_batch_name;
      END LOOP;
    END IF;                                 -- CHG0038832 - Dipta

    /* CHG0038832 - Start Dipta */
    if p_load_type = 'EXISTING' then
      update xxoe_reseller_order_rel_intf roint
         set roint.INVOICE_DATE =
      (SELECT ro.INVOICE_DATE
        from xxoe_reseller_order_rel ro
       where roint.interface_id = ro.reseller_order_rel_id)
       where roint.batch_name = p_batch_name
         and roint.INVOICE_DATE is null;

      update xxoe_reseller_order_rel_intf roint
         set roint.Serial_Number =
      (SELECT ro.Serial_Number
        from xxoe_reseller_order_rel ro
       where roint.interface_id = ro.reseller_order_rel_id)
       where roint.batch_name = p_batch_name
         and roint.Serial_Number is null;
    end if;
    /* CHG0038832 - End Dipta */

    x_return_status := fnd_api.g_ret_sts_success;

    write_log('END SYNC_INTERFACE_TABLE');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status   := fnd_api.g_ret_sts_error;
      x_return_message  := 'Error occurred in sync_interface_table: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
  END sync_interface_table;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Loads xxoe_reseller_order_rel_intf from csv
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  03/10/2015  MMAZANET    CHG0034820. Initial Creation
-- ---------------------------------------------------------------------------------------------
  PROCEDURE load_interface_table(
     p_load_type     IN  VARCHAR2,
     p_file_location IN  VARCHAR2,
     p_file_name     IN  VARCHAR2,
     x_return_status OUT VARCHAR2,
     x_return_msg    OUT VARCHAR2
  )
  IS
    l_retcode NUMBER;
  BEGIN
    write_log('p_load_type: '||p_load_type);
    write_log('p_file_name: '||p_file_name);
    write_log('p_file_location: '||p_file_location);

    xxobjt_table_loader_util_pkg.load_file(
      errbuf                  => x_return_msg,
      retcode                 => l_retcode,
      p_table_name            => 'XXOE_RESELLER_ORDER_REL_INTF',
      p_template_name         => p_load_type,
      p_file_name             => p_file_name,
      p_directory             => p_file_location,
      p_expected_num_of_rows  => TO_NUMBER(NULL)
    );

    IF l_retcode <> 0 THEN
      x_return_status := fnd_api.g_ret_sts_error;
    ELSE
      x_return_status := fnd_api.g_ret_sts_success;
    END IF;
  END load_interface_table;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure finds the Oracle ID based on the p_type and p_value.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  03/10/2015  MMAZANET    CHG0034820. Initial Creation
-- ---------------------------------------------------------------------------------------------
  PROCEDURE find_id(
    p_type            IN VARCHAR2,
    p_value           IN VARCHAR2,
    x_id              OUT NUMBER,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2
  )
  IS
  BEGIN
    write_log('START FIND_ID');
    write_log('p_type: '||p_type);
    write_log('p_value: '||p_value);

    IF p_type = 'RESELLER' THEN
      SELECT resource_id
      INTO x_id
      FROM jtf_rs_resource_extns
      WHERE source_name = p_value
      AND   category    = 'SUPPLIER_CONTACT'
      AND   SYSDATE     BETWEEN NVL(start_date_active,'01-JAN-1900')
                          AND NVL(end_date_active,'31-DEC-4712');
    END IF;

    IF p_type = 'SHIP_TO_ACCOUNT' THEN
      SELECT cust_account_id
      INTO x_id
      FROM hz_cust_accounts_all
      WHERE account_number = p_value;
    END IF;

    IF p_type = 'ITEM' THEN
      SELECT msib.inventory_item_id
      INTO x_id
      FROM
        mtl_system_items_b      msib,
        mtl_parameters          mp,
        mtl_item_categories_v   micv
      WHERE msib.segment1                       = p_value
      AND   msib.organization_id                = mp.organization_id
      AND   msib.organization_id                = mp.master_organization_id
      AND   msib.inventory_item_id              = micv.inventory_item_id
      AND   msib.organization_id                = micv.organization_id
      AND   micv.category_set_name              = 'Commissions';
    END IF;

    write_log('x_id: '||x_id);

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END FIND_ID');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      x_return_status   := fnd_api.g_ret_sts_error;
      x_return_message  := 'Error: ID could not be located for '||p_type||' '||p_value;
      write_log(x_return_message);
    WHEN OTHERS THEN
      x_return_status   := fnd_api.g_ret_sts_error;
      x_return_message  := 'Error occurred in is_duplicate_serial_number: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      write_log(x_return_message);
  END find_id;

-- ---------------------------------------------------------------------------------------------
-- Purpose    :
--
-- Parameters :
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/22/2015  MMAZANET    Initial Creation for CHG0034820.
-- 1.1  04/30/2019  DCHATTERJEE CHG0041777 - replace junk character 49824 with space and modifiy ID fetch calls
-- ---------------------------------------------------------------------------------------------
  PROCEDURE get_ids(
    p_load            IN OUT  g_reseller_order_rel_type,
    x_chg_flag        OUT VARCHAR2,
    x_return_message  OUT VARCHAR2,
    x_return_status   OUT VARCHAR2
  )
  IS
    e_error   EXCEPTION;
  BEGIN
    write_log('BEGIN CHECK_FOR_CHANGES');
    write_log('update_flag: '||p_load.update_flag);

    -- Initialize x_chg_flag
    x_chg_flag  := 'N';

    -- If a record comes in for update, and the reseller or ship to are
    -- populated, we make it eligible for update by flipping the
    -- chg_flags to 'Y'.  This does not apply to new 'ORDER_DELIVERY' records
    -- sourced records, as their chg_flags are set to 'Y' in the sync_interface_table
    -- procedure.
    IF p_load.update_flag = 'Y'
      AND p_load.system_rec.reseller_name IS NOT NULL
    THEN
      p_load.system_rec.reseller_chg_flag := 'Y';
    END IF;

    IF p_load.update_flag = 'Y'
      AND p_load.system_rec.ship_to_cust_account_number IS NOT NULL
    THEN
      p_load.system_rec.ship_to_cust_chg_flag := 'Y';
    END IF;

    write_log('reseller_chg_flag: '||p_load.system_rec.reseller_chg_flag);
    write_log('ship_to_cust_chg_flag: '||p_load.system_rec.ship_to_cust_chg_flag);

    -- Get IDs if necessary
    IF p_load.system_rec.reseller_chg_flag = 'Y'
      -- Should always be called when creating new records
      OR (/*p_load.system_rec.source_name = 'MANUAL_SHIP_ACCOUNT'  -- CHG0041777 remove specific source check
      AND */p_load.update_flag = 'N' and p_load.system_rec.reseller_name is not null)  -- CHG0041777 only if reseller is not null
    THEN
      find_id(
        p_type            => 'RESELLER',
        p_value           => REPLACE(p_load.system_rec.reseller_name, chr(160),chr(32)),  -- CHG0041777 remove chr(160) with chr(32)
        x_id              => p_load.system_rec.reseller_id,
        x_return_status   => x_return_status,
        x_return_message  => x_return_message
      );

      write_log('reseller_id: '||p_load.system_rec.reseller_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      x_chg_flag := 'Y';
    END IF;

    IF p_load.system_rec.ship_to_cust_chg_flag = 'Y'
      -- Should always be called when creating new records
      OR (/*p_load.system_rec.source_name = 'MANUAL_SHIP_ACCOUNT'  -- CHG0041777 remove specific source check
      AND */p_load.update_flag = 'N' and p_load.system_rec.ship_to_cust_account_number is not null)  -- CHG0041777 only if cust account is not null
    THEN
      find_id(
        p_type            => 'SHIP_TO_ACCOUNT',
        p_value           => p_load.system_rec.ship_to_cust_account_number,
        x_id              => p_load.system_rec.ship_to_cust_account_id,
        x_return_status   => x_return_status,
        x_return_message  => x_return_message
      );

      write_log('ship_to_account_id: '||p_load.system_rec.ship_to_cust_account_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      x_chg_flag := 'Y';
    END IF;

    -- Should always be called when creating new records.  This doesn't get called
    -- for updates because users are not allowed to update items.
    IF /*p_load.system_rec.source_name = 'MANUAL_SHIP_ACCOUNT' -- CHG0041777 remove specific source check
      AND */p_load.update_flag = 'N' and p_load.system_rec.inventory_item_number is not null  -- CHG0041777 only if item is not null
    THEN
      find_id(
        p_type            => 'ITEM',
        p_value           => p_load.system_rec.inventory_item_number,
        x_id              => p_load.system_rec.inventory_item_id,
        x_return_status   => x_return_status,
        x_return_message  => x_return_message
      );

      write_log('inventory_item_id: '||p_load.system_rec.inventory_item_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      x_chg_flag := 'Y';
    END IF;

    write_log('x_chg_flag: '||x_chg_flag);

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END CHECK_FOR_CHANGES');
  EXCEPTION
    WHEN e_error THEN
      x_return_status   := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status   := fnd_api.g_ret_sts_error;
      x_return_message  := 'Error occurred in is_duplicate_serial_number: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      write_log(x_return_message);
  END get_ids;

-- ---------------------------------------------------------------------------------------------
-- Purpose: The following fields are true updates where we simply update the current record...
--            start_date, end_date, and notes
--          However, updating revenue_pct, reseller_id, ship_to_cust_account_id, and invoice
--          date are a little different because we want to store history when these are changed.
--          When any of these fields are populated, we end_date the existing record one day before
--          the start date of the new record.  Next, we set the process_flag of the current record
--          to 'N'.  When control returns to load_systems procedure, a new record will be created
--          with the new values.  We now have an inactive record with the old values and a new
--          record with the new values.  The new record will also have it's related_reseller_order_rel_id
--          set to the reseller_order_rel_id of the old record.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE handle_update(
    p_load                     IN OUT g_reseller_order_rel_type,
    p_from_form                IN VARCHAR2 DEFAULT 'N',
    x_return_message           OUT VARCHAR2,
    x_return_status            OUT VARCHAR2
  )
  IS

    -- Used to detect if record is currently locked
    CURSOR c_systems
    IS
       SELECT
         reseller_order_rel_id
       FROM xxoe_reseller_order_rel
       WHERE reseller_order_rel_id = p_load.system_rec.reseller_order_rel_id
       FOR UPDATE OF
          last_update_date
       ,  last_updated_by
       NOWAIT;


    CURSOR c_og_system
    IS
      SELECT
        *
      FROM xxoe_reseller_order_rel  xror
      WHERE reseller_order_rel_id = p_load.system_rec.reseller_order_rel_id
      ;

    load_rec          g_reseller_order_rel_type;
    e_skip            EXCEPTION;
    e_resource_busy   EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_resource_busy, -54);

  BEGIN
    write_log('START HANDLE_UPDATE');
    write_log('updating record reseller_order_rel_id: '||p_load.system_rec.reseller_order_rel_id);
    write_log('p_from_form: '||p_from_form);

    -- When called from the form, validate the dates here.  If not called from the form, validate
    -- dates is called from load_systems.
    IF p_from_form = 'Y' THEN
      validate_dates(
        p_load            => p_load,
        x_return_message  => x_return_message,
        x_return_status   => x_return_status
      );

      write_log('validate_dates return status: '||x_return_status);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_skip;
      END IF;
    END IF;

    FOR rec_og IN c_og_system LOOP

      -- End date and notes are not required, so if the user is setting from a value to NULL, we need
      -- some special handling
      IF p_load.system_rec.end_date IS NULL
        AND rec_og.end_date IS NOT NULL
      THEN
        write_log('Updating END_DATE to NULL');
        -- This date signals to the UPDATE below to set end_date to NULL
        load_rec.system_rec.end_date  := TO_DATE('05-DEC-2015','DD-MON-YYYY');
      END IF;

      IF p_load.system_rec.notes IS NULL
        AND rec_og.notes IS NOT NULL
      THEN
        write_log('Updating NOTES to NULL');
        -- This signals to the UPDATE below to set notes to NULL
        load_rec.system_rec.notes := '~';
      END IF;

      -- The following values aren't set from the form.
      IF p_from_form = 'N'
      -- If any of the values below have changed, we want to end date the existing record,
      -- and send back a new record to be loaded with new values
        AND(p_load.system_rec.revenue_pct <> rec_og.revenue_pct
        OR  p_load.system_rec.reseller_id <> rec_og.reseller_id
        OR  p_load.system_rec.ship_to_cust_account_id <> rec_og.ship_to_cust_account_id
        OR  p_load.system_rec.invoice_date <> rec_og.invoice_date)
      THEN
        write_log('Assigning old values to new record...');
        -- Set related id to original end-dated record for reference
        load_rec.system_rec.related_reseller_order_rel_id   := rec_og.reseller_order_rel_id;

        -- Set changed values for new record.
        load_rec.system_rec.reseller_id                     := NVL(p_load.system_rec.reseller_id,rec_og.reseller_id);
        load_rec.system_rec.revenue_pct                     := NVL(p_load.system_rec.revenue_pct,rec_og.revenue_pct);
        load_rec.system_rec.ship_to_cust_account_id         := NVL(p_load.system_rec.ship_to_cust_account_id,rec_og.ship_to_cust_account_id);
        load_rec.system_rec.invoice_date                    := NVL(p_load.system_rec.invoice_date,rec_og.invoice_date);

        -- These values always set based on what users put in file
        load_rec.system_rec.start_date                      := NVL(p_load.system_rec.start_date,SYSDATE);
        load_rec.system_rec.end_date                        := p_load.system_rec.end_date;

        -- Copy existing values from old record into new record.  These don't get updated ever
        load_rec.system_rec.order_line_id                   := rec_og.order_line_id;
        load_rec.system_rec.order_line_type_category        := rec_og.order_line_type_category;
        load_rec.system_rec.delivery_detail_id              := rec_og.delivery_detail_id;
        load_rec.system_rec.serial_number                   := rec_og.serial_number;
        load_rec.system_rec.customer_trx_line_id            := rec_og.customer_trx_line_id;
        load_rec.system_rec.inventory_item_id               := rec_og.inventory_item_id;
        load_rec.system_rec.org_id                          := rec_og.org_id;
        load_rec.system_rec.source_id                       := rec_og.source_id;
        load_rec.system_rec.source_name                     := rec_og.source_name;

        -- Set creation_action
        load_rec.system_rec.creation_action                 := 'CREATED FROM PREVIOUS RECORD';

        -- End date current system one day previous to start date of new system.  p_load gets sent back
        -- to load_systems.
        p_load.system_rec.end_date                          := load_rec.system_rec.start_date - 1;
        write_log('End date record end_date: '||p_load.system_rec.end_date);

        -- Indicates that this record needs to be created when control returns to the
        -- calling procedure load_systems.
        load_rec.update_flag                                := 'N';
      END IF;
    END LOOP;

    -- Update values of current record
    FOR rec IN c_systems LOOP
       write_log('start_date: '||p_load.system_rec.start_date||' '||load_rec.update_flag);
       UPDATE xxoe_reseller_order_rel
       SET
       -- If load_rec.update_flag = 'Y' then this is strictly an UPDATE as opposed to the old record being end-dated
       -- and a new record created.  No DECODE is around end_date because we update that field on update of
       -- reseller, ship_to, revenue_pct, and invoice_date.  We may also simply inactivate a record by setting
       -- end date.  Otherwise, if we aren't doing anything with it, we leave it alone (set equal to existing value)
          start_date                 = DECODE(load_rec.update_flag,'N',start_date,p_load.system_rec.start_date)
       ,  end_date                   = DECODE(load_rec.system_rec.end_date,TO_DATE('31-DEC-4712','DD-MON-YYYY'), TO_DATE(NULL), NVL(p_load.system_rec.end_date, end_date))
       ,  notes                      = DECODE(load_rec.update_flag,'N',notes,DECODE(load_rec.system_rec.notes,'~',NULL,p_load.system_rec.notes))
       ,  last_update_date           = SYSDATE
       ,  last_updated_by            = TO_NUMBER(fnd_profile.value('USER_ID'))
       ,  last_update_login          = TO_NUMBER(fnd_profile.value('LOGIN_ID'))
       WHERE CURRENT OF c_systems;
    END LOOP;

    -- Load p_load with values for creation of new record, if new record is necessary.
    p_load  := load_rec;

    write_log('p_load.update_flag: '||p_load.update_flag);

    x_return_status   := fnd_api.g_ret_sts_success;
    write_log('END HANDLE_UPDATE');
  EXCEPTION
     WHEN e_resource_busy THEN
        x_return_message := 'Error: Record on XXOE_RESELLER_ORDER_REL is locked by another user.';
        write_log(x_return_message);
        x_return_status := fnd_api.g_ret_sts_error;
     WHEN e_skip THEN
        write_log(x_return_message);
        x_return_status   := fnd_api.g_ret_sts_error;
     WHEN OTHERS THEN
        x_return_message             := 'Unexpected Error in upd_xxoe_resell_order_rel_pub: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log(x_return_message);
        x_return_status   := fnd_api.g_ret_sts_error;
  END handle_update;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This is called from the
--          'XX: Commissions Populate XXOE_RESELLER_ORDER_REL Table' concurrent request
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- 1.1  07/10/2014  MMAZANET    CHG0031576.  Rebuilt based on change of requirements
-- 1.2  03/17/2015  MMAZANET    CHG0034820.  Added assignment to total_rev_pct, which is used
--                              in validate_resell_order_rel.
-- 1.3  06/23/2016  DCHATTERJEE CHG0038832 - Modify existing install base update code.
-- 1.4  04/30/2019  DCHATTERJEE CHG0041777 - throw error if no interface records exist for a given batch
-- ---------------------------------------------------------------------------------------------
  PROCEDURE load_systems(
    errbuff         OUT VARCHAR2,
    retcode         OUT NUMBER,
    p_load_type     IN VARCHAR2,
    p_batch_name    IN VARCHAR2,
    p_file_location IN VARCHAR2,
    p_file_name     IN VARCHAR2
  )
  IS
    CURSOR c_load
    IS
      SELECT
        xrori.interface_id                                interface_id,
        xrori.ship_to_cust_account_id                     ship_to_cust_account_id,
        xrori.ship_to_cust_account_number                 ship_to_cust_account_number,
        xrori.ship_to_cust_chg_flag                       ship_to_cust_chg_flag,
        xrori.order_line_id                               order_line_id,
        ooh.order_number                                  order_number,
        ool.line_number                                   order_line_number,
        xrori.order_line_type_category                    order_line_type_category,
        xrori.start_date                                  start_date,
        xrori.end_date                                    end_date,
        xrori.invoice_date                                invoice_date,
        xrori.delivery_detail_id                          delivery_detail_id,
        xrori.serial_number                               serial_number,
        xrori.customer_trx_line_id                        customer_trx_line_id,
        xrori.reseller_id                                 reseller_id,
        xrori.reseller_name                               reseller_name,
        xrori.reseller_chg_flag                           reseller_chg_flag,
        xrori.inventory_item_number                       inventory_item_number,
        xrori.inventory_item_id                           inventory_item_id,
        xrori.revenue_pct                                 revenue_pct,
        xrori.org_id                                      org_id,
        TO_CHAR(xrori.source_id)                          source_id,
        --'ORDER_DELIVERY'                                  source_name,
        xrori.order_source_reference                      order_source_reference,
        SUM(xrori.revenue_pct) OVER (PARTITION BY xrori.serial_number) total_revenue_pct,
        xrori.rowid                                       row_id
      FROM
        xxoe_reseller_order_rel_intf        xrori,
        oe_order_headers_all                ooh,
        oe_order_lines_all                  ool,
        ra_customer_trx_lines_all           rctl,
        ra_customer_trx_all                 rct
      WHERE xrori.order_line_id         = ool.line_id (+)
      AND   ool.header_id               = ooh.header_id (+)
      AND   xrori.customer_trx_line_id  = rctl.customer_trx_line_id (+)
      AND   rctl.customer_trx_id        = rct.customer_trx_id (+)
      AND   xrori.process_flag          = 'Y'
      AND   xrori.load_status           IN ('PENDING','E')
      AND   xrori.batch_name            = p_batch_name
      ;

    l_xxssys_generic_rpt_rec  xxssys_generic_rpt%ROWTYPE;
    l_request_id              NUMBER                        := FND_GLOBAL.CONC_REQUEST_ID;
    l_return_message          VARCHAR2(2000);
    l_return_status           VARCHAR2(1);
    l_error_flag              VARCHAR2(1) := 'N';
    l_row_error_flag          VARCHAR2(1);
    l_chg_flag                VARCHAR2(1) := 'N';

    l_creation_action         xxoe_reseller_order_rel.creation_action%TYPE;
    l_notes                   xxoe_reseller_order_rel.notes%TYPE;
    l_action                  VARCHAR2(15);

    l_file_location           VARCHAR2(250);

    l_success_ct              NUMBER := 0;
    l_error_ct                NUMBER := 0;
    l_skip_ct                 NUMBER := 0;

    e_skip                    EXCEPTION;
    e_error                   EXCEPTION;

    load_rec                  g_reseller_order_rel_type;

    l_intf_rec_cnt            NUMBER;   -- CHG0041777 added
  BEGIN
    write_log('START LOAD_OE_SYSTEMS');
    write_log('p_load_type: '||p_load_type);

    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id         := l_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag    := 'Y';
    l_xxssys_generic_rpt_rec.col1               := 'Order Number';
    l_xxssys_generic_rpt_rec.col2               := 'Order Line Number';
    l_xxssys_generic_rpt_rec.col3               := 'Serial Number';
    l_xxssys_generic_rpt_rec.col4               := 'Reseller Name';

    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(
      p_xxssys_generic_rpt_rec      => l_xxssys_generic_rpt_rec,
      x_return_status               => l_return_status,
      x_return_message              => l_return_message
    );

    IF l_return_status <> 'S' THEN
      RAISE e_error;
    END IF;

    -- Initialize interface table based on load type
    IF p_load_type = 'ORDER_DELIVERY' THEN
      -- CHG0041777 start
      select count(1)
        into l_intf_rec_cnt
        from xxobjt.xxoe_reseller_order_rel_intf
       where batch_name  = p_batch_name
         and process_flag = 'N'
         AND load_status = 'PENDING';

      if l_intf_rec_cnt = 0 then
        l_return_message := 'ERROR: The record set for batch '||p_batch_name||' has become stale. Please run program XX: Commissions System Extract again to extract new delivery serial information before proceeding';

        raise e_error;
      end if;

      -- CHG0041777 end


      -- Delete any changed records that may have been previously loaded.
      DELETE FROM xxobjt.xxoe_reseller_order_rel_intf
      WHERE process_flag = 'C';

      -- Reset process flag for error records for re-processing
      UPDATE xxoe_reseller_order_rel_intf
      SET
        process_flag    = 'N'
      WHERE load_status = 'E'
      AND   batch_name  = p_batch_name;
    ELSE
      -- Clear interface table
      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxoe_reseller_order_rel_intf';
    END IF;

    -- Get Oracle directory location
    BEGIN
      SELECT directory_path
      INTO l_file_location
      FROM dba_directories
      WHERE UPPER(directory_name) = p_file_location;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_return_message := 'No directory set up for '||p_file_location;
        RAISE e_error;
    END;

    -- Load csv file into xxoe_reseller_order_rel_intf
    load_interface_table(
      p_load_type     => p_load_type,
      p_file_location => l_file_location,
      p_file_name     => p_file_name,
      x_return_status => l_return_status,
      x_return_msg    => l_return_message
    );

    write_log('load_interface_table return status: '||l_return_status);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- For ORDER_DELIVERY LOAD TYPE, most information is pre-loaded into interface table when user extracts data, then synched based
    -- on users csv loaded a
    IF p_load_type = 'ORDER_DELIVERY' THEN
      sync_interface_table(
        p_load_type       => p_load_type,   -- CHG0038832 - Dipta
        p_batch_name      => p_batch_name,
        x_return_status   => l_return_status,
        x_return_message  => l_return_message
      );

      write_log('sync_interface_table return status: '||l_return_status);

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    ELSIF p_load_type = 'EXISTING'
    THEN
      sync_interface_table(
        p_load_type       => p_load_type,   -- CHG0038832 - Dipta
        p_batch_name      => p_batch_name,
        x_return_status   => l_return_status,
        x_return_message  => l_return_message
      );

      write_log('sync_interface_table return status: '||l_return_status);

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END IF;

    -- loop through interface records
    FOR rec IN c_load LOOP
      -- Initialize values
      load_rec              := NULL;
      l_row_error_flag      := 'N';
      l_chg_flag            := 'N';
      load_rec.update_flag  := 'N';

      BEGIN
        write_log('*** BEGIN PROCESSING INTERFACE_ID/RESELLER_ORDER_REL_ID '||rec.interface_id||' ***');
        write_log('*** Start LOOP for serial number '||rec.serial_number||' ***');

        -- **********************************************************************************
        -- Initialize values based on type of record coming in.
        -- **********************************************************************************

        -- interface_id column will hold reseller_order_rel_id for non-ORDER_DELIVERY records
        IF p_load_type = 'ORDER_DELIVERY' THEN
          -- On Creation of new ORDER_DELIVERY records, we need to have a value for start_date
          load_rec.system_rec.start_date                := NVL(rec.start_date,rec.invoice_date);
          l_creation_action                             := 'OM LOAD';
          load_rec.system_rec.order_line_type_category  := p_load_type; -- rec.order_line_type_category; -- CHG0038832 make constant value
        ELSIF p_load_type = 'EXISTING' THEN
          -- For existing records, reseller_order_rel_id is in the interface_id column.
          load_rec.system_rec.reseller_order_rel_id     := rec.interface_id;
          l_creation_action                             := 'MANUAL UPDATE';

          /* CHG0038832 - Start Dipta */
          select SERIAL_NUMBER,
                 INVOICE_DATE,
                 decode(rec.reseller_name, null, reseller_id, null),
                 decode(rec.start_date, null, start_date, null)
            into load_rec.system_rec.serial_number,
                 load_rec.system_rec.invoice_date,
                 load_rec.system_rec.reseller_id,
                 load_rec.system_rec.start_date
            from xxoe_reseller_order_rel
           where reseller_order_rel_id = rec.interface_id;

          write_log('reseller ID: '||load_rec.system_rec.reseller_id);
          /* CHG0038832 - End Dipta */

          IF rec.reseller_name IS NULL
            AND rec.ship_to_cust_account_number IS NULL
            AND rec.invoice_date  IS NULL
            AND rec.start_date IS NULL
            AND rec.end_date IS NULL
          THEN
            RAISE e_skip;
          END IF;

        ELSIF p_load_type = 'MANUAL_SHIP_ACCOUNT' THEN
          l_creation_action                             := 'MANUAL CREATION';
          load_rec.system_rec.order_line_type_category  := p_load_type;
        END IF;

        -- If the reseller_order_rel_id is populated, it's because we're doing an update to an existing
        -- record in xxoe_reseller_order_rel, so we want to set the update_flag correctly.  Otherwise,
        -- we have new records.
        IF load_rec.system_rec.reseller_order_rel_id IS NOT NULL THEN
          load_rec.update_flag := 'Y';
        ELSE
          load_rec.update_flag            := 'N';
          load_rec.system_rec.source_name := p_load_type;
          -- On Creation of all new records, we need to have a value for start_date
          load_rec.system_rec.start_date  := NVL(rec.start_date,rec.invoice_date);
        END IF;

        write_log('update_flag: '||load_rec.update_flag);
        write_log('rec.reseller_chg_flag: '||rec.reseller_chg_flag);
        write_log('rec.ship_to_cust_chg_flag: '||rec.ship_to_cust_chg_flag);

        -- Set record values
        load_rec.system_rec.order_line_id                   := rec.order_line_id;

        load_rec.system_rec.end_date                        := rec.end_date;
        load_rec.system_rec.delivery_detail_id              := rec.delivery_detail_id;
        /* CHG0038832 - Start Dipta */
        if p_load_type <> 'EXISTING' then
          load_rec.system_rec.invoice_date                    := rec.invoice_date;
          load_rec.system_rec.serial_number                   := rec.serial_number;
          load_rec.system_rec.reseller_id                     := rec.reseller_id;
        end if;
        /* CHG0038832 - End Dipta */

        load_rec.system_rec.customer_trx_line_id            := rec.customer_trx_line_id;
        load_rec.system_rec.reseller_name                   := rec.reseller_name;
        load_rec.system_rec.reseller_chg_flag               := rec.reseller_chg_flag;
        load_rec.system_rec.inventory_item_number           := rec.inventory_item_number;
        load_rec.system_rec.inventory_item_id               := rec.inventory_item_id;
        load_rec.system_rec.ship_to_cust_account_number     := rec.ship_to_cust_account_number;
        load_rec.system_rec.ship_to_cust_account_id         := rec.ship_to_cust_account_id;
        load_rec.system_rec.ship_to_cust_chg_flag           := rec.ship_to_cust_chg_flag;
        load_rec.system_rec.revenue_pct                     := rec.revenue_pct;
        load_rec.total_revenue_pct                          := rec.total_revenue_pct;
        load_rec.system_rec.org_id                          := rec.org_id;
        load_rec.system_rec.source_id                       := rec.source_id;
        load_rec.system_rec.order_source_reference          := rec.order_source_reference;
        load_rec.system_rec.creation_action                 := l_creation_action;

        -- Get IDs for reseller and ship to customer, if the values are changing from the
        -- original values.  Additionally, get the inventory_item_id, if the record is
        -- a MANUAL_SHIP_ACCOUNT, since users will only enter an item number.
        get_ids(
          p_load            => load_rec,
          x_chg_flag        => l_chg_flag,
          x_return_message  => l_return_message,
          x_return_status   => l_return_status
        );

        write_log('get_ids return_status: '||l_return_status);

        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          RAISE e_error;
        END IF;

        -- Call validation routine
        validate_resell_order_rel(
          p_load            => load_rec,
          p_load_type       => p_load_type,
          x_return_message  => l_return_message,
          x_return_status   => l_return_status
        );

        write_log('validate_resell_order_rel return_status: '||l_return_status);

        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          RAISE e_error;
        END IF;

        /* The following block of code was used for returns/credits, which users will handle manually for now.
           However, they may request for this to be re-implemented in the future when users have a handle on
           the process for returns/credits

        -- Build table of return/credit records.  After we have loaded xxoe_reseller_order_rel,
        -- We'll circle back and process return/credits/invoice only l_records.  This ensures we don't
        -- have some records corresponding in the CURSOR above and some in the table from a previous load.
        write_log('order_line_type_category: '||load_rec.system_rec.order_line_type_category);

        IF load_rec.system_rec.order_line_type_category = 'XXCN_SYS_ORDER_CREDIT' THEN


           g_return_ct                               := g_return_ct + 1;
           l_credit_bill_only_ct                     := l_credit_bill_only_ct + 1;
           l_return_credit.extend;
           l_return_credit(l_credit_bill_only_ct)    := l_load;

        -- Invoice/Bill only records may have special handling to find the serial number, similar to credits
        -- If their serial number is null we insert them into the l_return_credit collection table, then
        -- try to find the serial number on their referenced order.  Otherwise we process them just as
        -- we do standard orders
        ELSIF l_load.order_line_type_category = 'XXCN_SYS_INVOICE_ONLY'
           AND l_load.serial_number IS NULL
        THEN
           g_invoice_only_ct                      := g_invoice_only_ct + 1;
           l_credit_bill_only_ct                  := l_credit_bill_only_ct + 1;
           l_return_credit.extend;
           l_return_credit(l_credit_bill_only_ct) := l_load;
        */

        write_log('order_line_type_category: '||load_rec.system_rec.order_line_type_category);
        write_log('update_flag: '||load_rec.update_flag);

        -- Credit records are handled separately, so they are excluded here
        IF load_rec.system_rec.order_line_type_category NOT IN ('XXCN_SYS_ORDER_CREDIT','XXCN_SYS_INVOICE_ONLY')
          -- Updates won't have order_line_type_category populated
          OR p_load_type = 'EXISTING'
        THEN
          -- If we're updating an existing record in xxoe_reseller_order_rel, depending on the field we're updating,
          -- we may need to end date the current record, then insert a new record, in which case load_rec will come
          -- back with update_flag = 'N' and program will proceed to insert_xxoe_reseller_order_rel.  See handle_update
          -- for further details.
          IF load_rec.update_flag = 'Y' THEN
            -- Update Routine
            handle_update(
              p_load            => load_rec,
              x_return_message  => l_return_message,
              x_return_status   => l_return_status
              );

            write_log('handle_update return status: '||l_return_status);

            IF l_return_status <> 'S' THEN
              RAISE e_error;
            END IF;

            -- Call validation routine again, when we are creating a new record on update.
            IF load_rec.update_flag = 'N' THEN
              -- Call validation routine
              validate_resell_order_rel(
                p_load            => load_rec,
                p_load_type       => p_load_type,
                x_return_message  => l_return_message,
                x_return_status   => l_return_status
              );

              write_log('validate_resell_order_rel return_status: '||l_return_status);

              IF l_return_status <> fnd_api.g_ret_sts_success THEN
                RAISE e_error;
              END IF;
            END IF;
          END IF;

          IF load_rec.update_flag = 'N' THEN
            -- insert new record into xxoe_reseller_order_rel
            insert_xxoe_reseller_order_rel(
              p_xxoe_reseller_order_rel   => load_rec,
              x_return_message            => l_return_message,
              x_return_status             => l_return_status
            );

            write_log('insert_xxoe_reseller_order_rel return status: '||l_return_status);

            IF l_return_status <> 'S' THEN
               RAISE e_error;
            ELSE
               l_success_ct := l_success_ct + 1;
            END IF;
          END IF;
        END IF;

      EXCEPTION
        -- Skip processing
        WHEN e_skip THEN
          l_return_status := 'S';
          l_skip_ct       := l_skip_ct;
          NULL;
        -- Error from block above
        WHEN e_error THEN
          IF l_return_status <> fnd_api.g_ret_sts_success THEN
             l_row_error_flag := 'Y';
          END IF;
        WHEN OTHERS THEN
          l_row_error_flag := 'Y';
          l_return_message := 'Error: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      END;

      -- Update interface table with results
      UPDATE xxoe_reseller_order_rel_intf
      SET
         reseller_order_rel_id = load_rec.system_rec.reseller_order_rel_id
      ,  load_status           = l_return_status
      ,  load_message          = l_return_message
      WHERE rowid = rec.row_id;

      -- Insert details for reporting
      IF l_row_error_flag = 'Y' THEN
        -- Tells prgram at least one row has errored.
        l_error_flag                                := 'Y';

        l_error_ct                                  := l_error_ct + 1;

        l_xxssys_generic_rpt_rec.request_id         := l_request_id;
        l_xxssys_generic_rpt_rec.header_row_flag    := 'N';
        l_xxssys_generic_rpt_rec.col1               := rec.order_number;
        l_xxssys_generic_rpt_rec.col2               := rec.order_line_number;
        l_xxssys_generic_rpt_rec.col3               := rec.serial_number;
        l_xxssys_generic_rpt_rec.col4               := rec.reseller_name;
        l_xxssys_generic_rpt_rec.col_msg            := l_return_message;

        xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(
          p_xxssys_generic_rpt_rec      => l_xxssys_generic_rpt_rec,
          x_return_status               => l_return_status,
          x_return_message              => l_return_message
        );

        IF l_return_status <> 'S' THEN
          RAISE e_error;
        END IF;

      END IF;
    END LOOP;

      /*The following block of code was used for returns/credits, which users will handle manually for now.
        However, they may request for this to be re-implemented in the future when users have a handle on
        the process for returns/credits

      -- Process return/credit/invoice only records
      write_log('Return Count: '||l_return_credit.COUNT);
      FOR i IN  1.. l_return_credit.COUNT
      LOOP
         BEGIN
            process_return_credit_inv_only(
               p_return_credit_row  => l_return_credit(i)
            ,  x_serial_number      => l_serial_number
            ,  x_return_status      => l_return_status
            ,  x_return_msg         => l_return_message
            );

            IF l_return_status <> 'S' THEN
               RAISE e_skip;
            ELSE
               write_log('Line type category: '||l_load.system_rec.order_line_type_category);
               write_log('Serial Number: '||l_serial_number);
               IF l_load.system_rec.order_line_type_category = 'XXCN_SYS_INVOICE_ONLY' THEN
                  l_return_credit(i).system_rec.serial_number := l_serial_number;
               END IF;

               insert_xxoe_reseller_order_rel(
                  p_xxoe_reseller_order_rel  => l_return_credit(i)
               ,  x_return_message           => l_return_message
               ,  x_return_status            => l_return_status
               );

               IF l_return_status <> 'S' THEN
                  RAISE e_skip;
               ELSE
                  g_loaded_ct := g_loaded_ct + 1;
               END IF;
            END IF;
         EXCEPTION
            WHEN e_skip THEN
               l_error_flag := 'Y';
               g_return_error_ct := g_return_error_ct + 1;
               report_row(l_return_credit(i),l_return_message);
            WHEN OTHERS THEN
               l_error_flag := 'Y';
               g_return_error_ct := g_return_error_ct + 1;
               report_row(l_return_credit(i),'Error processing return/credit: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
         END;
      END LOOP;
    */

    -- Kick off error report if necessary
    IF l_error_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.output,'Please see next request for Error Report.');

      xxssys_generic_rpt_pkg.submit_request(
        p_burst_flag                => 'N',
        p_request_id                => l_request_id,
        x_return_status             => l_return_status,
        x_return_message            => l_return_message
      );

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;

      -- Warning
      retcode := 1;
    END IF;


    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'Record Totals');
    fnd_file.put_line(fnd_file.output,'***************************');
    fnd_file.put_line(fnd_file.output,'Success Records: '||l_success_ct);
    fnd_file.put_line(fnd_file.output,'Error Records:   '||l_error_ct);

    write_log('END LOAD_SYSTEMS');
  EXCEPTION
    WHEN e_error THEN
      fnd_file.put_line(fnd_file.output,l_return_message);
      retcode := 2;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Error occurred in load_systems'||DBMS_UTILITY.FORMAT_ERROR_STACK);
      write_log(DBMS_UTILITY.FORMAT_ERROR_STACK);
      retcode := 2;
  END load_systems;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Public procedure to insert records into the xxoe_reseller_order_rel table.  This is
--          called from the XXOERESELLORDRREL.fmb form and bulk loading process.  If records
--          are manually inserted, this procedure should be called.
-- Parameters: p_load
--                g_reseller_order_rel_type record
--             p_validate_all
--                This is used by ins_xxoe_resell_order_rel_bulk procedure to do more extensive
--                lookups based on values sent in.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE ins_xxoe_resell_order_rel_pub(
    p_load                     IN OUT  g_reseller_order_rel_type,
    p_validate_all             IN      VARCHAR2  DEFAULT 'N',
    x_return_message           OUT     VARCHAR2,
    x_return_status            OUT     VARCHAR2
  )
  IS
    l_action  VARCHAR2(1);

    e_skip    EXCEPTION;
    l_load    g_reseller_order_rel_type;
  BEGIN
     write_log('START INS_XXOE_RESELL_ORDER_REL_PUB');
     write_log('p_validate_all: '||p_validate_all);

     l_load := p_load;

     write_log('return_status from check_for_existing_record: '||x_return_status);

     IF x_return_status <> 'S' THEN
       RAISE e_skip;
     END IF;

     -- Go through validations of new record
     validate_resell_order_rel(
       p_load           => l_load,
       p_load_type      => 'NA',
       x_return_message => x_return_message,
       x_return_status  => x_return_status
     );

     write_log('return_status from validate_resell_order_rel: '||x_return_status);

     IF x_return_status <> 'S' THEN
        RAISE e_skip;
     END IF;

     insert_xxoe_reseller_order_rel(
        p_xxoe_reseller_order_rel  => l_load
     ,  x_return_message           => x_return_message
     ,  x_return_status            => x_return_status
     );

     write_log('return_status from insert_xxoe_reseller_order_rel: '||x_return_status);

     -- This will include the reseller_order_rel_id of the new record.
     p_load := l_load;

     IF x_return_status <> 'S' THEN
        RAISE e_skip;
     END IF;

     x_return_status   := 'S';
     write_log('END INS_XXOE_RESELL_ORDER_REL_PUB');

  EXCEPTION
     WHEN e_skip THEN
        x_return_status   := 'E';
        write_log(x_return_message);
     WHEN OTHERS THEN
        x_return_status   := 'E';
        x_return_message             := 'Unexpected Error in ins_xxoe_resell_order_rel_pub: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log(x_return_message);
  END ins_xxoe_resell_order_rel_pub;

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Function to retrieve message from FND message XXCN_RESELLER_STMT_SPLIT_TEXT
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  10/06/2017  DCHATTERJEE    CHG0041334 - Initial build
  -- ---------------------------------------------------------------------------------------------

  FUNCTION get_reseller_stmt_msg return varchar2 is
    l_message varchar2(400);
  begin
    fnd_message.SET_NAME('XXOBJT','XXCN_RESELLER_STMT_SPLIT_TEXT');
    l_message := fnd_message.GET;

    return l_message;
  end get_reseller_stmt_msg;

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to create item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE create_item_comm_cat_assn(p_category_id IN number,
                                     p_category_set_id IN number,
                                     p_inventory_item_id IN number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2) is

    l_return_status      VARCHAR2(1) := NULL;
    l_msg_count          NUMBER      := 0;
    l_msg_data           VARCHAR2(2000);
    l_errorcode          VARCHAR2(1000);
    l_cat_set_id         NUMBER;
  begin
    select category_set_id
      into l_cat_set_id
      from mtl_category_sets
     where category_set_name = 'Commissions';  
    
    if l_cat_set_id <> p_category_set_id then
      x_return_status := 'E';
      x_status_message := 'ERROR: XXE01_INV_CATSET_INS: Error encountered while creating item commission category assignment. Please contact IT.';
      return;
    end if;
    
    INV_ITEM_CATEGORY_PUB.CREATE_CATEGORY_ASSIGNMENT
        (  p_api_version        => 1.0,
           p_init_msg_list      => FND_API.G_TRUE,
           p_commit             => FND_API.G_FALSE,
           x_return_status      => l_return_status,
           x_errorcode          => l_errorcode,
           x_msg_count          => l_msg_count,
           x_msg_data           => l_msg_data,
           p_category_id        => p_category_id,
           p_category_set_id    => p_category_set_id,
           p_inventory_item_id  => p_inventory_item_id,
           p_organization_id    => p_organization_id);

    IF l_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
      x_return_status := 'S';
      x_status_message := 'Item Commission category association created successfully!';
    ELSE
      ROLLBACK;
      FOR i IN 1 .. l_msg_count
      LOOP
        l_msg_data := oe_msg_pub.get( p_msg_index => i, p_encoded => 'F');
      END LOOP;

      x_return_status := 'E';
      x_status_message := 'ERROR: '||l_msg_data;
    END IF;
  exception when others then
    x_return_status := 'E';
    x_status_message := 'ERROR: '||substr(sqlerrm,1,1900);
  end create_item_comm_cat_assn;

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to update item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE update_item_comm_cat_assn(p_category_id IN number,
                                     p_category_set_id IN number,
                                     p_inventory_item_id IN number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2) is

    l_return_status      VARCHAR2(1) := NULL;
    l_msg_count          NUMBER      := 0;
    l_msg_data           VARCHAR2(2000);
    l_errorcode          VARCHAR2(1000);

    l_old_category_id    NUMBER;
  begin
    select mic.category_id
      into l_old_category_id
      from mtl_item_categories mic
     where mic.inventory_item_id = p_inventory_item_id
       and mic.category_set_id = p_category_set_id
       and mic.organization_id = p_organization_id;

    INV_ITEM_CATEGORY_PUB.Update_Category_Assignment
        (  p_api_version        => 1.0,
           p_init_msg_list      => FND_API.G_TRUE,
           p_commit             => FND_API.G_FALSE,
           x_return_status      => l_return_status,
           x_errorcode          => l_errorcode,
           x_msg_count          => l_msg_count,
           x_msg_data           => l_msg_data,
           p_category_id        => p_category_id,
           p_old_category_id    => l_old_category_id,
           p_category_set_id    => p_category_set_id,
           p_inventory_item_id  => p_inventory_item_id,
           p_organization_id    => p_organization_id);

    IF l_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
      x_return_status := 'S';
      x_status_message := 'Item Commission category association updated successfully!';
    ELSE
      ROLLBACK;
      FOR i IN 1 .. l_msg_count
      LOOP
        l_msg_data := oe_msg_pub.get( p_msg_index => i, p_encoded => 'F');
      END LOOP;

      x_return_status := 'E';
      x_status_message := 'ERROR: '||l_msg_data;
    END IF;
  exception when no_data_found then
    x_return_status := 'E';
    x_status_message := 'ERROR: Existing item category association not found';
   when others then
    x_return_status := 'E';
    x_status_message := 'ERROR: '||substr(sqlerrm,1,1900);
  end update_item_comm_cat_assn;

  -- ---------------------------------------------------------------------------------------------
  -- Purpose: Procedure to delete item commission category assignment
  -- Parameters:
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name           Description
  -- 1.0  12/04/2020  DCHATTERJEE    CHG0047344 - Initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE delete_item_comm_cat_assn(p_category_id IN number,
                                     p_category_set_id IN number,
                                     p_inventory_item_id IN number,
                                     p_organization_id IN NUMBER,
                                     x_return_status OUT varchar2,
                                     x_status_message OUT varchar2) is

    l_return_status      VARCHAR2(1) := NULL;
    l_msg_count          NUMBER      := 0;
    l_msg_data           VARCHAR2(2000);
    l_errorcode          VARCHAR2(1000);
    l_cat_set_id         NUMBER;
  begin
    select category_set_id
      into l_cat_set_id
      from mtl_category_sets
     where category_set_name = 'Commissions';  
    
    if l_cat_set_id <> p_category_set_id then
      x_return_status := 'E';
      x_status_message := 'ERROR: XXE01_INV_CATSET_DEL: Error encountered while removing item commission category assignment. Please contact IT.';
      return;
    end if;
    
    INV_ITEM_CATEGORY_PUB.Delete_Category_Assignment
        (  p_api_version        => 1.0,
           p_init_msg_list      => FND_API.G_TRUE,
           p_commit             => FND_API.G_FALSE,
           x_return_status      => l_return_status,
           x_errorcode          => l_errorcode,
           x_msg_count          => l_msg_count,
           x_msg_data           => l_msg_data,
           p_category_id        => p_category_id,
           p_category_set_id    => p_category_set_id,
           p_inventory_item_id  => p_inventory_item_id,
           p_organization_id    => p_organization_id);

    IF l_return_status = fnd_api.g_ret_sts_success THEN
      COMMIT;
      x_return_status := 'S';
      x_status_message := 'Item Commission category association deleted successfully!';
    ELSE
      ROLLBACK;
      FOR i IN 1 .. l_msg_count
      LOOP
        l_msg_data := oe_msg_pub.get( p_msg_index => i, p_encoded => 'F');
      END LOOP;

      x_return_status := 'E';
      x_status_message := 'ERROR: '||l_msg_data;
    END IF;
  exception when others then
    x_return_status := 'E';
    x_status_message := 'ERROR: '||substr(sqlerrm,1,1900);
  end delete_item_comm_cat_assn;

END xxoe_reseller_order_rel_pkg;
/
